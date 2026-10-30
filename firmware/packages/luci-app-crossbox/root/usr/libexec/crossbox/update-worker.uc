#!/usr/bin/ucode
'use strict';

import { readfile, open, rename, unlink, stat, statvfs, mkdir, popen } from 'fs';
import { cursor } from 'uci';
import { repository, compatible, newer, release_asset, validate_manifest, validate_latest_manifest, validate_image } from 'crossbox.updates';

const dir = '/var/run/crossbox-update';
mkdir(dir, 0700);
const lock = open(dir + '/lock', 'a', 0600);
if (!lock || !lock.lock('xn')) exit(0);
const action = ARGV[0] ?? 'cycle';
if (index(['cycle', 'check', 'install'], action) < 0) die('Invalid update action');
const c = cursor();
function quote(s) { return "'" + replace(s, "'", "'\\''") + "'"; }
function run(command) {
    let pipe = popen(command + ' 2>&1', 'r');
    if (!pipe) die('Cannot start update helper');
    let output = pipe.read('all'), code = pipe.close();
    return { output, code };
}
function load(path) { try { return json(readfile(path) ?? ''); } catch (e) { return {}; } }
let state = load(dir + '/status.json');
let board = load('/etc/board.json');
try { board = json(run('/bin/ubus call system board').output); } catch (e) { board = {}; }
const current = match(readfile('/etc/crossbox-release') ?? '', /CROSSBOX_VERSION='([^']+)'/)?.[1] ?? '';
function automatic() { c.unload('crossbox_update'); return c.get('crossbox_update', 'settings', 'automatic') != '0'; }
function status(phase, extra) {
    state = { ...state, ...extra, phase, current, supported: compatible(board), automatic: automatic() };
    let file = open(dir + '/status.json.new', 'w', 0600), text = sprintf('%J', state);
    if (!file || file.write(text) != length(text) || !file.close() || !rename(dir + '/status.json.new', dir + '/status.json')) die('Cannot save update status');
}
function download(url, path, limit) {
    let result = run('/usr/bin/curl -sS -L --noproxy "*" --proto "=https" --proto-redir "=https" --connect-timeout 15 --max-time 300 --max-filesize ' + limit + ' -H "Accept: application/vnd.github+json" -H "User-Agent: CrossBox-Updater" -o ' + quote(path) + ' -w "%{http_code}" ' + quote(url));
    if (result.code) die('Release download failed; check Internet access and router time');
    return trim(result.output);
}
function verify(path, hash, size) {
    if (stat(path)?.size != size || split(trim(run('/usr/bin/sha256sum ' + quote(path)).output), /\s+/)[0] != hash) die('Downloaded file failed size or SHA-256 verification');
}
function available(update) {
    let same = state.available?.sha256 == update.sha256 && state.available?.tag == update.tag;
    let attempt = c.get('crossbox_update', 'settings', 'last_attempt');
    status('available', { checked_at: time(), available: update, install_at: same && state.install_at ? state.install_at : time() + 600, retry_blocked: attempt == update.version });
}
function check() {
    status('checking', { error: null });
    let http = download('https://api.github.com/repos/' + repository + '/releases/latest', dir + '/release.json', 1048576);
    if (http == '404') { status('no_release', { checked_at: time(), available: null, install_at: null }); return; }
    if (http == '403' || http == '429') {
        http = download('https://github.com/' + repository + '/releases/latest/download/crossbox-update.json', dir + '/manifest.json', 16384);
        if (http == '404') { status('no_release', { checked_at: time(), available: null, install_at: null }); return; }
        if (http != '200') die('GitHub release check failed (HTTP ' + http + ')');
        let manifest = load(dir + '/manifest.json');
        if (!newer(manifest.version, current)) { status('current', { checked_at: time(), available: null, install_at: null }); return; }
        available(validate_latest_manifest(manifest, current));
        return;
    }
    if (http != '200') die('GitHub release check failed (HTTP ' + http + ')');
    let release = load(dir + '/release.json');
    if (release.draft || release.prerelease || !newer(release.tag_name, current)) {
        status('current', { checked_at: time(), available: null, install_at: null }); return;
    }
    let asset = release_asset(release, 'crossbox-update.json');
    if (asset.size < 1 || asset.size > 16384) die('Invalid update manifest size');
    if (download(asset.browser_download_url, dir + '/manifest.json', 16384) != '200') die('Update manifest download failed');
    verify(dir + '/manifest.json', substr(asset.digest, 7), asset.size);
    let update = validate_manifest(release, load(dir + '/manifest.json'), current);
    available(update);
}
function install(manual) {
    // Re-read the published release at installation time; never flash a stale cache.
    if (!compatible(board)) die('Automatic firmware installation is unavailable on this hardware');
    check();
    if (!state.available) return;
    // A different release may have replaced the scheduled candidate during check().
    if (!manual && (!automatic() || state.retry_blocked || state.install_at > time())) return;
    let update = state.available, memory = match(readfile('/proc/meminfo') ?? '', /MemAvailable:\s+(\d+)/);
    let space = statvfs('/tmp');
    if (!memory || +memory[1] * 1024 < update.size + 67108864 || !space || space.bavail * space.frsize < update.size + 16777216) die('Insufficient free RAM or temporary storage for firmware update');
    status('downloading', { error: null });
    const image = dir + '/firmware.bin';
    if (download(update.url, image, update.size) != '200') die('Firmware download failed');
    verify(image, update.sha256, update.size);
    status('validating', {});
    if (run('/usr/bin/fwtool -q -i ' + quote(dir + '/image.json') + ' ' + quote(image)).code) die('Firmware metadata is missing or invalid');
    validate_image(load(dir + '/image.json'), update, board);
    if (run('/sbin/sysupgrade -T ' + quote(image)).code) die('Platform rejected this image; settings cannot be safely preserved');
    if (!manual && !automatic()) { status('available', {}); unlink(image); return; }
    // Record one attempt before reboot. A failed boot cannot cause an endless auto-flash loop.
    c.set('crossbox_update', 'settings', 'last_attempt', update.version);
    if (!c.commit('crossbox_update')) die('Cannot record firmware update attempt');
    status('installing', { started_at: time() });
    // Default sysupgrade preserves configuration. Never use -F, -n or compatibility overrides.
    let result = run('/sbin/sysupgrade ' + quote(image));
    if (result.code) die('Firmware installation failed');
    // procd owns the accepted upgrade now; keep the image available until reboot.
}
try {
    if (action == 'check') check();
    else if (action == 'install') install(true);
    else {
        if (!state.checked_at || time() - state.checked_at >= 21600 || time() < state.checked_at) check();
        if (state.phase == 'available' && compatible(board) && automatic() && !state.retry_blocked && state.install_at <= time()) install(false);
    }
} catch (e) {
    status('error', { error: split(e.message, '\n')[0] });
    unlink(dir + '/firmware.bin');
    warn('CrossBox updater: ' + state.error + '\n');
    exit(1);
}

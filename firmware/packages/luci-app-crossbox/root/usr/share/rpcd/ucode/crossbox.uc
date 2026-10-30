'use strict';

import { readfile, open, glob, popen, stat, mkdir, rename, unlink } from 'fs';
import { cursor } from 'uci';
import { read_sensors } from 'crossbox.telemetry';
import { urlencode, ENCODE_FULL } from 'lucihttp';
import { compatible } from 'crossbox.updates';

function quote(s) { return "'" + replace(s, "'", "'\\''") + "'"; }
function run(command) {
    let p = popen(command + ' 2>&1', 'r');
    if (!p) return { code: 1, output: 'Cannot execute service helper' };
    let output = p.read('all');
    let code = p.close();
    return { code, output };
}
function load(path, fallback) {
    try { return json(readfile(path) ?? ''); } catch (e) { return fallback; }
}
function running(name) {
    let result = run('/bin/ubus call service list ' + quote(sprintf('%J', { name })));
    try {
        let service = json(result.output);
        for (let key, instance in service[name]?.instances)
            if (instance.running) return true;
    } catch (e) {}
    return false;
}
function controller(path, method, body) {
    let token = trim(readfile('/etc/crossbox/controller.secret') ?? '');
    if (!length(token)) return { code: 1, output: '' };
    return run('/usr/bin/curl -fsS --max-time 7 --noproxy "*" -X ' + quote(method ?? 'GET') +
        ' -H ' + quote('Authorization: Bearer ' + token) +
        (body ? ' -H "Content-Type: application/json" --data-binary ' + quote(sprintf('%J', body)) : '') +
        ' ' + quote('http://127.0.0.1:9091' + path));
}
function vpn_status() {
    let active = running('crossbox-vpn');
    let group = {}, provider = {};
    if (active) {
        try { group = json(controller('/proxies/CrossBox').output); } catch (e) {}
        try { provider = json(controller('/providers/proxies/source').output); } catch (e) {}
    }
    let metadata = {};
    for (let proxy in load('/etc/crossbox/proxies.txt', {}).proxies ?? [])
        metadata[proxy.name] = { endpoint: proxy.server ? proxy.server + ':' + proxy.port : '', transport: proxy.network ?? '' };
    return {
        installed: !!stat('/usr/bin/mihomo'), running: active,
        selected: group.now, nodes: map(provider.proxies ?? [], p => ({
            name: p.name, type: p.type, alive: length(p.history ?? []) ? p.alive : null,
            delay: p.history?.[-1]?.delay ?? null, endpoint: metadata[p.name]?.endpoint ?? '', transport: metadata[p.name]?.transport ?? ''
        })),
        error: trim(readfile('/tmp/crossbox-vpn.error') ?? ''),
        mode: load('/etc/crossbox/vpn.json', {}).mode ?? 'proxy'
    };
}
function save(kind, text) {
    if (length(text) > 524288) return { error: 'Configuration exceeds 512 KiB' };
    let data;
    try { data = json(text); } catch (e) { return { error: 'Invalid JSON' }; }
    if (type(data) != 'object') return { error: 'Expected a configuration object' };
    let path = '/etc/crossbox/' + kind + '-request.json';
    // rpcd dispatches synchronous calls serially; the helper also owns a service lock.
    let f = run('/bin/mkdir -p /etc/crossbox; /bin/chmod 700 /etc/crossbox');
    if (f.code) return { error: 'Cannot create protected configuration directory' };
    unlink(path);
    let file = open(path, 'w', 0600);
    let encoded = sprintf('%J', data);
    if (!file) return { error: 'Cannot stage configuration' };
    let written = file.write(encoded);
    let closed = file.close();
    if (written != length(encoded) || !closed) { unlink(path); return { error: 'Cannot write configuration' }; }
    let result = run('/usr/libexec/crossbox/' + kind + '-apply');
    unlink(path);
    if (result.code) return { error: trim(result.output) || 'Configuration rejected. Previous configuration retained.' };
    return { ok: true };
}

function update_status() {
    let state = load('/var/run/crossbox-update/status.json', {}), c = cursor(), board = {};
    try { board = json(run('/bin/ubus call system board').output); } catch (e) {}
    let version = match(readfile('/etc/crossbox-release') ?? '', /CROSSBOX_VERSION='([^']+)'/);
    return { ...state, current: version?.[1] ?? '', supported: compatible(board), automatic: c.get('crossbox_update', 'settings', 'automatic') != '0' };
}
return { crossbox: {
    update_status: { call: update_status },
    update_action: { args: { action: '' }, call: function(r) {
        if (index(['check', 'install'], r.args.action) < 0) return { error: 'Invalid update action' };
        if (r.args.action == 'install' && !update_status().supported) return { error: 'Automatic firmware installation is unavailable on this hardware' };
        let result = run('/usr/bin/ucode /usr/libexec/crossbox/update-worker.uc ' + r.args.action + ' </dev/null >/dev/null 2>&1 &');
        return result.code ? { error: 'Cannot start updater' } : { ok: true };
    } },
    update_settings: { args: { automatic: true }, call: function(r) {
        if (type(r.args.automatic) != 'bool') return { error: 'Invalid update setting' };
        let c = cursor();
        if (!c.get('crossbox_update', 'settings')) c.section('crossbox_update', 'settings', 'settings');
        c.set('crossbox_update', 'settings', 'automatic', r.args.automatic ? '1' : '0');
        return c.commit('crossbox_update') ? { ok: true } : { error: 'Cannot save update settings' };
    } },

    diagnostic: { args: { action: '', host: '' }, call: function(r) {
        let host = r.args.host;
        if (!length(host) || length(host) > 253 || !match(host, /^[a-zA-Z0-9:][a-zA-Z0-9.:_-]*$/))
            return { error: 'Enter a hostname or IP address without a scheme or path' };
        let commands = {
            ping: '/bin/ping -c 4 -W 2 ',
            lookup: '/usr/bin/nslookup ',
            trace: '/bin/traceroute -m 8 -w 1 -q 1 -n '
        };
        if (!commands[r.args.action]) return { error: 'Unsupported diagnostic action' };
        let executable = split(commands[r.args.action], ' ')[0];
        if (!stat(executable)) return { error: 'Diagnostic tool is not installed' };
        let result = run('/usr/bin/timeout 12 ' + commands[r.args.action] + quote(host));
        return { code: result.code, output: substr(result.output, 0, 24000) };
    } },
    telemetry: { call: function() {
        let cpu = map(slice(split(trim(split(readfile('/proc/stat') ?? '', '\n')[0]), /\s+/), 1, 9), v => +v);
        let net = {};
        for (let line in slice(split(readfile('/proc/net/dev') ?? '', '\n'), 2)) {
            let f = split(trim(line), /[: ]+/);
            if (length(f) > 9 && f[0] != 'lo') net[f[0]] = { rx: +f[1], tx: +f[9] };
        }
        let sensors = read_sensors();
        let mem = {};
        for (let line in split(readfile('/proc/meminfo') ?? '', '\n')) {
            let m = match(line, /^(MemTotal|MemAvailable|MemFree|Buffers|Cached):\s+(\d+)/);
            if (m) mem[m[1]] = +m[2] * 1024;
        }
        let processor = match(readfile('/proc/cpuinfo') ?? '', /(model name|Hardware|Processor)\s*:\s*([^\n]+)/);
        let version = match(readfile('/etc/crossbox-release') ?? '', /CROSSBOX_VERSION='([^']+)'/);
        return { firmware: version ? 'CrossBox ' + version[1] : null, cpu, net, mem, sensors, processor: processor?.[2], uptime: +(split(readfile('/proc/uptime') ?? '0', ' ')[0]), timestamp: time() };
    } },
    vpn_status: { call: vpn_status },
    vpn_get: { call: function() { return { config: load('/etc/crossbox/vpn.json', { enabled: false, mode: 'proxy', profile: '', subscription: '', domains: [] }) }; } },
    vpn_save: { args: { data: '' }, call: function(r) { return save('vpn', r.args.data); } },
    vpn_select: { args: { name: '' }, call: function(r) {
        if (!length(r.args.name) || length(r.args.name) > 512) return { error: 'Invalid node name' };
        let result = controller('/proxies/CrossBox', 'PUT', { name: r.args.name });
        return result.code ? { error: 'Node selection failed' } : { ok: true };
    } },
    vpn_probe: { args: { name: '' }, call: function(r) {
        if (!length(r.args.name) || length(r.args.name) > 512) return { error: 'Invalid node name' };
        let provider;
        try { provider = json(controller('/providers/proxies/source').output); } catch (e) { return { error: 'VPN is not running' }; }
        if (!length(filter(provider.proxies ?? [], p => p.name == r.args.name))) return { error: 'Unknown server' };
        let result = controller('/providers/proxies/source/' + urlencode(r.args.name, ENCODE_FULL) + '/healthcheck?timeout=5000&expected=204&url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204');
        let reply = {};
        try { reply = json(result.output); } catch (e) {}
        return !result.code && reply.delay > 0 ? { ok: true, delay: reply.delay } : { error: 'Server did not pass the HTTPS check' };
    } },
    vpn_refresh: { call: function() {
        let result = run('umask 077; cp /etc/crossbox/vpn.json /etc/crossbox/vpn-request.json && /usr/libexec/crossbox/vpn-apply; result=$?; rm -f /etc/crossbox/vpn-request.json; exit "$result"');
        return result.code ? { error: 'Subscription refresh failed; check URL and service status' } : { ok: true };
    } },
    vpn_test: { call: function() {
        // Test the selected group directly. SOCKS requests obey routing rules and
        // could otherwise report a DIRECT success in selective-domain mode.
        let result = controller('/proxies/CrossBox/delay?timeout=5000&expected=204&url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204');
        let reply = {};
        try { reply = json(result.output); } catch (e) {}
        let ok = !result.code && type(reply.delay) == 'int' && reply.delay > 0;
        return { ok, result: ok ? reply.delay + ' ms' : '', error: ok ? null : 'Selected proxy could not reach the HTTPS connectivity endpoint' };
    } },
    zapret_status: { call: function() { return { installed: !!stat('/usr/bin/nfqws2'), running: running('crossbox-zapret'), error: trim(readfile('/tmp/crossbox-zapret.error') ?? '') }; } },
    zapret_get: { call: function() {
        let profiles = load('/usr/share/crossbox/zapret-presets.json', []);
        let first = profiles[0] ?? { domains: [], strategy: 'split', quic: false };
        let defaults = { enabled: false, domains: first.domains, strategy: first.strategy, quic: first.quic, profiles, active_profile: 0 };
        return { config: load('/etc/crossbox/zapret.json', defaults) };
    } },
    zapret_save: { args: { data: '' }, call: function(r) { return save('zapret', r.args.data); } },
    language: { args: { language: '' }, call: function(r) {
        if (r.args.language != 'ru' && r.args.language != 'en') return { error: 'Unsupported language' };
        let c = cursor(); c.set('luci', 'main', 'lang', r.args.language);
        let ok = c.commit('luci'); c.unload();
        return ok ? { ok: true } : { error: 'Could not save language' };
    } }
} };

'use strict';

export const repository = 'yhuikzdtguioaert/CrossBox';
export const device = 'tplink_archer-ax55-v1';
export const board_name = 'tplink,archer-ax55-v1';
export const target = 'qualcommax/ipq50xx';

function require_valid(ok, message) { if (!ok) die(message); }
export function newer(candidate, current) {
    let a = match(candidate ?? '', /^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/);
    let b = match(current ?? '', /^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$/);
    if (!a || !b) return false;
    for (let i = 1; i <= 3; i++) {
        if (+a[i] > +b[i]) return true;
        if (+a[i] < +b[i]) return false;
    }
    return !!b[4];
}
export function compatible(board) {
    return board?.board_name == board_name && board?.release?.target == target;
}
export function release_asset(release, name) {
    let assets = filter(release?.assets ?? [], a => a.name == name && a.state == 'uploaded');
    require_valid(length(assets) == 1, 'Release asset is missing or ambiguous: ' + name);
    let asset = assets[0];
    require_valid(match(asset.digest ?? '', /^sha256:[a-f0-9]{64}$/), 'Release asset has no SHA-256 digest');
    require_valid(asset.browser_download_url == 'https://github.com/' + repository + '/releases/download/' + release.tag_name + '/' + name, 'Unexpected release asset URL');
    return asset;
}
function manifest_fields(manifest, tag) {
    let version = replace(tag, /^v/, '');
    require_valid(manifest?.schema == 1 && manifest.version == version, 'Release version does not match manifest');
    require_valid(manifest.repository == repository && manifest.device == device && manifest.target == target && manifest.board_name == board_name, 'Manifest is for another device');
    let name = 'crossbox-' + version + '-qualcommax-ipq50xx-' + device + '-squashfs-sysupgrade.bin';
    require_valid(manifest.filename == name, 'Only the exact CrossBox sysupgrade image is accepted');
    require_valid(type(manifest.size) == 'int' && manifest.size >= 1048576 && manifest.size <= 67108864, 'Invalid firmware size');
    require_valid(match(manifest.sha256 ?? '', /^[a-f0-9]{64}$/), 'Invalid firmware digest');
    return { version, tag, filename: name, size: manifest.size, sha256: manifest.sha256, url: 'https://github.com/' + repository + '/releases/download/' + tag + '/' + name };
}
export function validate_manifest(release, manifest, current) {
    require_valid(!release.draft && !release.prerelease && newer(release.tag_name, current), 'Release is not a newer stable version');
    let update = manifest_fields(manifest, release.tag_name);
    let asset = release_asset(release, update.filename);
    require_valid(asset.size == update.size && asset.digest == 'sha256:' + update.sha256, 'Firmware digest or size does not match release metadata');
    return update;
}
export function validate_latest_manifest(manifest, current) {
    // The public latest/download endpoint avoids shared-IP REST API quotas.
    // Trust comes from verified HTTPS to this fixed repository, as for the REST API.
    require_valid(match(manifest?.version ?? '', /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/) && newer(manifest.version, current), 'Manifest is not a newer stable version');
    return manifest_fields(manifest, 'v' + manifest.version);
}
export function validate_image(metadata, update, board) {
    require_valid(compatible(board), 'Automatic firmware installation is unavailable on this hardware');
    require_valid(metadata?.version?.dist == 'CrossBox' && metadata.version.version == update.version && metadata.version.target == target, 'Image metadata does not match the CrossBox release');
    require_valid(index(metadata.supported_devices ?? [], board_name) >= 0, 'Image does not support this board');
    return true;
}

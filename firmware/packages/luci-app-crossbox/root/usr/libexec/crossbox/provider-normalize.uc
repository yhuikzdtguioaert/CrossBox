#!/usr/bin/ucode
'use strict';
import { readfile, writefile } from 'fs';

// Keep native Clash providers and URI subscriptions intact. Convert Xray/Happ
// outbound definitions only; never import their routing, listeners or scripts.
let text = readfile(ARGV[0]);
if (!length(text) || length(text) > 1048576) die('Empty or oversized subscription\n');
let data;
try { data = json(text); } catch (e) {}
if (!data || (type(data) == 'object' && !data.outbounds)) {
    if (!writefile(ARGV[1], text)) die('Cannot write provider\n');
    exit(0);
}
if (type(data) != 'array') data = [data];
let proxies = [], names = {}, seen = {};
function canonical(value) {
    if (type(value) == 'object') { let sorted = {}; for (let key in sort(keys(value))) sorted[key] = canonical(value[key]); return sorted; }
    if (type(value) == 'array') return map(value, canonical);
    return value;
}
function append_proxy(p, deduplicate) {
    // Only converted Xray entries are independent of native provider name references.
    if (deduplicate) {
        let identity = {};
        for (let key in keys(p)) if (key != 'name') identity[key] = p[key];
        let fingerprint = sprintf('%J', canonical(identity));
        if (seen[fingerprint]) return;
        seen[fingerprint] = true;
    }
    let original = p.name ?? p.type, candidate = original, suffix = 1;
    while (names[candidate]) candidate = original + ' (' + (++suffix) + ')';
    names[candidate] = true;
    p.name = candidate;
    push(proxies, p);
}
for (let config in data) {
    if (!config.outbounds && config.type && config.server) { append_proxy(config); continue; }
    for (let out in config.outbounds ?? []) {
        if (index(['freedom', 'blackhole', 'dns', 'loopback'], out.protocol) >= 0) continue;
        let s = out.settings ?? {}, stream = out.streamSettings ?? {};
        let server = s.vnext?.[0] ?? s.servers?.[0] ?? (out.protocol == 'hysteria' ? s : null);
        if (!server) die('Unsupported Xray outbound; import its Clash equivalent\n');
        let p = { name: config.remarks ?? out.tag ?? out.protocol, type: out.protocol, server: server.address, port: +server.port, udp: true };
        let user = server.users?.[0];
        if (out.protocol == 'vless' || out.protocol == 'vmess') {
            p.uuid = user.id;
            if (out.protocol == 'vmess') { p.alterId = +(user.alterId ?? 0); p.cipher = user.security ?? 'auto'; }
            else { if (user.flow) p.flow = user.flow; if (user.encryption && user.encryption != 'none') p.encryption = user.encryption; }
        }
        else if (out.protocol == 'hysteria') {
            if (s.version != 2 && stream.hysteriaSettings?.version != 2) die('Only Hysteria 2 Xray JSON is supported; use Clash for Hysteria 1\n');
            p.type = 'hysteria2'; p.password = stream.hysteriaSettings?.auth ?? s.auth;
        }
        else if (out.protocol == 'trojan') p.password = server.password;
        else if (out.protocol == 'shadowsocks') { p.type = 'ss'; p.cipher = server.method; p.password = server.password; }
        else if (out.protocol == 'socks' || out.protocol == 'http') {
            p.type = out.protocol == 'socks' ? 'socks5' : 'http';
            if (user) { p.username = user.user; p.password = user.pass; }
        }
        else die('Unsupported Xray protocol; import a native Clash provider\n');
        let network = stream.network ?? 'tcp';
        if (network != 'tcp' && network != 'raw' && network != 'hysteria') p.network = network == 'splithttp' ? 'xhttp' : network;
        if (network == 'ws') {
            let ws = stream.wsSettings ?? {};
            p['ws-opts'] = { path: ws.path ?? '/', headers: ws.headers ?? {} };
            // Current Xray gives the explicit host field precedence over headers.Host.
            if (ws.host) {
                for (let key in keys(p['ws-opts'].headers))
                    if (lc(key) == 'host') delete p['ws-opts'].headers[key];
                p['ws-opts'].headers.Host = ws.host;
            }
        }
        else if (network == 'grpc') p['grpc-opts'] = { 'grpc-service-name': stream.grpcSettings?.serviceName ?? '' };
        else if (network == 'http' || network == 'h2') { p.network = 'h2'; p['h2-opts'] = { path: stream.httpSettings?.path ?? '/', host: stream.httpSettings?.host ?? [] }; }
        else if (network == 'xhttp' || network == 'splithttp') {
            let x = stream.xhttpSettings ?? stream.splithttpSettings ?? {};
            p['xhttp-opts'] = { path: x.path ?? '/', host: x.host ?? '', mode: x.mode ?? 'auto' };
            // Reject unconverted extensions rather than silently ignoring security-sensitive settings.
            if (x.extra && length(keys(x.extra))) die('XHTTP extra settings require a native Clash provider\n');
        }
        else if (network != 'tcp' && network != 'raw' && network != 'hysteria') die('Unsupported Xray transport; use a native Clash provider\n');
        if (network == 'tcp' || network == 'raw') {
            let header = (stream.rawSettings ?? stream.tcpSettings)?.header;
            if (header && header.type && header.type != 'none')
                die('Xray TCP header camouflage requires a native Clash provider\n');
        }
        let security = stream.security ?? 'none';
        if (security == 'tls' || security == 'reality') {
            let tls = security == 'reality' ? stream.realitySettings : stream.tlsSettings;
            let pins = tls?.pinnedPeerCertSha256;
            if (pins && length(pins)) {
                let pin = type(pins) == 'array' && length(pins) == 1 ? pins[0] : pins;
                if (type(pin) != 'string' || !match(pin, /^[a-fA-F0-9]{64}$/))
                    die('Multiple or non-hex Xray certificate pins require a native Clash provider\n');
                p.fingerprint = lc(pin);
            }
            if (tls?.echConfigList || tls?.echForceQuery || length(tls?.verifyPeerCertInNames ?? []) || length(tls?.verifyPeerCertByName ?? []))
                die('Extended Xray TLS verification requires a native Clash provider\n');
            p.tls = true;
            p.servername = tls?.serverName ?? server.address;
            if (index(['hysteria2', 'trojan', 'socks5', 'http'], p.type) >= 0) p.sni = p.servername;
            p['client-fingerprint'] = tls?.fingerprint ?? 'chrome';
            p['skip-cert-verify'] = tls?.allowInsecure ?? false;
            if (tls?.alpn) p.alpn = tls.alpn;
            if (security == 'reality') p['reality-opts'] = { 'public-key': tls.publicKey ?? tls.password, 'short-id': tls.shortId ?? '' };
        }
        else if (security != 'none') die('Unsupported transport security\n');
        append_proxy(p, true);
    }
}
if (!length(proxies)) die('No supported proxy nodes found\n');
if (!writefile(ARGV[1], sprintf('%J', { proxies }))) die('Cannot write normalized provider\n');

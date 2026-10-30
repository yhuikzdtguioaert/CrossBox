#!/usr/bin/ucode
'use strict';
import { readfile, writefile } from 'fs';

let state;
try { state = json(readfile(ARGV[0])); } catch (e) { die('Invalid VPN configuration\n'); }
if (type(state) != 'object' || type(state.enabled) != 'bool' ||
    index(['proxy', 'all', 'domains'], state.mode) < 0 ||
    type(state.profile ?? '') != 'string' || type(state.subscription ?? '') != 'string' ||
    type(state.domains ?? []) != 'array') die('Invalid VPN fields\n');
if (length(state.profile ?? '') > 500000 || length(state.domains ?? []) > 2000)
    die('VPN configuration is too large\n');
let subscription = trim(state.subscription ?? '');
if (subscription && (!match(subscription, /^https:\/\/[^\s]+$/) || length(subscription) > 4096))
    die('Subscription URL must use HTTPS\n');
if (state.enabled && !subscription && !length(trim(state.profile ?? '')))
    die('Import a profile or subscription before enabling VPN\n');
let domains = [];
for (let domain in state.domains ?? []) {
    if (type(domain) != 'string' || length(domain) > 253 ||
        !match(domain, /^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/))
        die('Invalid domain; enter hostnames without schemes or paths\n');
    push(domains, lc(domain));
}
if (state.enabled && state.mode == 'domains' && !length(domains)) die('Selective routing needs at least one domain\n');
let base = ARGV[1];
let check = ARGV[2] == 'check';
let token = trim(readfile('/etc/crossbox/controller.secret') ?? '');
let provider = { type: 'file', path: base + '/proxies.txt', 'health-check': { enable: false } };
let rules = [
    'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve', 'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
    'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve', 'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
    'IP-CIDR,169.254.0.0/16,DIRECT,no-resolve', 'IP-CIDR6,::1/128,DIRECT,no-resolve',
    'IP-CIDR6,fc00::/7,DIRECT,no-resolve', 'IP-CIDR6,fe80::/10,DIRECT,no-resolve'
];
for (let domain in domains) push(rules, 'DOMAIN-SUFFIX,' + domain + ',CrossBox');
push(rules, state.mode == 'domains' ? 'MATCH,DIRECT' : 'MATCH,CrossBox');
let config = {
    'mixed-port': check ? 17890 : 7890, 'allow-lan': false, 'bind-address': '127.0.0.1',
    mode: 'rule', ipv6: true, 'log-level': 'warning', 'find-process-mode': 'off',
    'external-controller': check ? '127.0.0.1:19091' : '127.0.0.1:9091', secret: token,
    'unified-delay': true, 'tcp-concurrent': false, 'keep-alive-idle': 30, 'keep-alive-interval': 30,
    profile: { 'store-selected': !check, 'store-fake-ip': false },
    'proxy-providers': { source: provider },
    'proxy-groups': [{ name: 'CrossBox', type: 'select', use: ['source'] }],
    dns: {
        enable: true, listen: check ? '127.0.0.1:11053' : '127.0.0.1:1053', ipv6: true,
        'enhanced-mode': 'fake-ip', 'fake-ip-range': '198.18.0.1/16',
        'fake-ip-filter': ['*.lan', '*.local', 'localhost'],
        'default-nameserver': ['1.1.1.1', '9.9.9.9'],
        'proxy-server-nameserver': ['https://1.1.1.1/dns-query'],
        nameserver: ['https://1.1.1.1/dns-query', 'https://9.9.9.9/dns-query']
    },
    tun: {
        enable: !check && state.mode != 'proxy', device: 'cb-vpn', stack: 'system', mtu: 1500,
        'auto-route': true, 'auto-redirect': true, 'auto-detect-interface': true, 'strict-route': true,
        'dns-hijack': ['any:53', 'tcp://any:53'],
        'route-exclude-address': ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '169.254.0.0/16', '::1/128', 'fc00::/7', 'fe80::/10']
    }, rules
};
// A provider owns only proxy definitions. Subscription routing, listeners and scripts
// cannot replace the router's management configuration.
if (writefile(base + '/proxies.txt', state.profile ?? '') == null) die('Cannot write proxy provider\n');
if (!writefile(base + '/config.json', sprintf('%J', config))) die('Cannot write engine configuration\n');

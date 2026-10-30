#!/usr/bin/ucode
'use strict';
import { readfile, writefile } from 'fs';
let state;
try { state = json(readfile(ARGV[0])); } catch (e) { die('Invalid zapret configuration\n'); }
if (type(state) != 'object' || type(state.enabled) != 'bool' || type(state.domains) != 'array' ||
    index(['split', 'disorder'], state.strategy) < 0 || type(state.quic) != 'bool') die('Invalid zapret fields\n');
if (length(state.domains) > 2000) die('Too many domains\n');
let domains = [];
for (let domain in state.domains) {
    if (type(domain) != 'string' || length(domain) > 253 ||
        !match(domain, /^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$/))
        die('Invalid domain; use hostnames without schemes or paths\n');
    push(domains, lc(domain));
}
if (state.enabled && !length(domains)) die('Add domains before enabling zapret\n');
if (!writefile(ARGV[1], join('\n', domains) + '\n')) die('Cannot write host list\n');

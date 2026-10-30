#!/usr/bin/ucode
'use strict';
import { readfile, popen } from 'fs';
function quote(s) { return "'" + replace(s, "'", "'\\''") + "'"; }
let state = json(readfile(ARGV[0]));
let url = state.subscription ?? '';
let agent = state.user_agent ?? 'Happ/3.0.0';
let hwid = trim(readfile('/etc/crossbox/device.id') ?? '');
if (!match(hwid, /^[a-zA-Z0-9=-]{10,64}$/)) die('Device ID is missing; run CrossBox setup\n');
if (!match(url, /^https:\/\/[^\s]+$/) || length(url) > 4096) die('Subscription requires an HTTPS URL\n');
if (type(agent) != 'string' || length(agent) > 200 || match(agent, /[\r\n]/)) die('Invalid User-Agent\n');
// Credentials stay in protected state files. Curl errors and response bodies do
// not enter the system log or the RPC reply.
let board = popen('/bin/ubus call system board', 'r');
let info = {};
try { info = json(board?.read('all') ?? '{}'); } catch (e) {}
board?.close();
let headers = ' -H ' + quote('x-hwid: ' + hwid) + ' -H ' + quote('x-device-os: OpenWrt') +
    ' -H ' + quote('x-device-model: ' + (info.model ?? 'CrossBox')) +
    ' -H ' + quote('x-ver-os: ' + (info.release?.version ?? 'SNAPSHOT'));
let p = popen('/usr/bin/curl -fsS --proto "=https" --proto-redir "=https" -L --max-redirs 3 --connect-timeout 5 --max-time 15 --max-filesize 1048576 -A ' +
    quote(agent) + headers + ' -D ' + quote(ARGV[1] + '.headers') + ' --output ' + quote(ARGV[1]) + ' ' + quote(url) + ' 2>/dev/null');
p?.read('all');
if (!p || p.close()) die('Subscription request failed; check the URL and User-Agent\n');
let response = lc(readfile(ARGV[1] + '.headers') ?? '');
if (match(response, /x-hwid-(max-devices-reached|limit):[ \t]*true/))
    die('Subscription device limit reached. Remove an unused device in your provider account.\n');

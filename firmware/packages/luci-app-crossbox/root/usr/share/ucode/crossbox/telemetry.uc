'use strict';
import { readfile, glob } from 'fs';

// The argument enables fixture tests; the RPC always reads the real /sys tree.
export function read_sensors(root) {
    root = root ?? '/sys';
    let sensors = [];
    let paths = glob(root + '/class/thermal/thermal_zone*/temp');
    for (let path in glob(root + '/class/hwmon/hwmon*/temp*_input')) push(paths, path);
    for (let path in paths) {
        let text = trim(readfile(path) ?? '');
        if (!match(text, /^-?[0-9]+$/)) continue;
        let raw = +text;
        if (raw < -40000 || raw > 200000) continue;
        let hwmon = index(path, '/hwmon/') >= 0;
        let name = hwmon ? trim(readfile(replace(path, /temp[0-9]+_input$/, 'name')) ?? '') : trim(readfile(replace(path, /temp$/, 'type')) ?? '');
        let label = hwmon ? trim(readfile(replace(path, /_input$/, '_label')) ?? '') : '';
        push(sensors, { id: replace(path, root + '/', ''), name: label || name || 'Temperature', driver: name, celsius: raw / 1000.0 });
    }
    return sensors;
}

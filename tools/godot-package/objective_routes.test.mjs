import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options} from './options.mjs';
import {launchOptions} from '../godot-dev/launch_options.mjs';

const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));
const zones = ['meridian-exchange', 'verdant-reliquary', 'ember-crucible'];
const assault = ['tidal-citadel', 'sunscar-convoy'];

test('five locked objective pairs keep separate source-backed scenes and host options', () => {
  for (const [experience, mode, maps, scene, cap] of [
    ['zones', 'uplink', zones, 'res://zone_modes/demo.tscn', 900],
    ['zones', 'holdout', zones, 'res://zone_modes/demo.tscn', 900],
    ['assault', 'assault', assault, 'res://assault/demo.tscn', 9],
  ]) for (const map of maps) {
    const argv = [`--experience=${experience}`, `--map=${map}`, `--mode=${mode}`, '--bots=0', '--round-seconds=900', `--score-limit=${cap}`];
    const packaged = options(argv, catalog), dev = launchOptions(argv, catalog);
    assert.equal(packaged.scene, scene);
    assert.ok(dev.args.includes(scene));
    assert.deepEqual(packaged.userArgs, dev.sessionOptions);
    assert.equal(packaged.endpoint, null);
  }
});

test('objective aliases, wrong maps and out-of-range host config fail before scene launch', () => {
  for (const experience of ['zones', 'assault']) for (const arg of ['--round-seconds=59', '--round-seconds=901', '--round-seconds=60.5', '--score-limit=0', '--score-limit=901', '--bots=9']) {
    assert.throws(() => options([`--experience=${experience}`, arg], catalog), Error, arg);
    assert.throws(() => launchOptions([`--experience=${experience}`, arg], catalog), Error, arg);
  }
  for (const args of [
    ['--experience=zones', '--map=tidal-citadel', '--mode=uplink'],
    ['--experience=zones', '--map=sunscar-convoy', '--mode=holdout'],
    ['--experience=assault', '--map=meridian-exchange'],
    ['--experience=assault', '--map=tidal-citadel', '--mode=ctf'],
    ['--experience=objectives', '--map=tidal-citadel', '--mode=assault'],
    ['--experience=assault', '--score-limit=10'],
  ]) {
    assert.throws(() => options(args, catalog), Error, args.join(' '));
    assert.throws(() => launchOptions(args, catalog), Error, args.join(' '));
  }
});

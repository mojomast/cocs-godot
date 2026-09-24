import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options, EXPERIENCES, NATIVE_EXPERIENCES} from './options.mjs';

const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));
const nativeMaps = ['prism-foundry', 'aurora-basin', 'cinder-array'];

// The shared port/native-arena-launchers fixture describes the older standalone
// launcher (1..7 bots, no combat bot option). This package now owns its own
// reviewed local 1..24 roster and must test that contract directly instead of
// changing expectations for the independent standalone launcher.
test('package Native DM accepts real local 1..24 bot launches on reviewed arenas', () => {
  assert.equal(Object.keys(EXPERIENCES).length, 10);
  assert.equal(Object.keys(NATIVE_EXPERIENCES).length, 5);
  const defaults = options(['--experience=native-dm'], catalog);
  assert.deepEqual([defaults.map, defaults.mode, defaults.bots, defaults.roundSeconds],
    ['prism-foundry', 'deathmatch', 2, 180]);
  assert.equal(defaults.nativeArena, true);
  assert.equal(defaults.endpoint, null);
  for (const map of nativeMaps) for (const [bots, seconds] of [[1, 60], [8, 120], [24, 300]]) {
    assert.ok(!catalog.maps.some(entry => entry.id === map));
    const plan = options(['--experience', 'native-dm', '--map', map,
      '--mode=deathmatch', `--bots=${bots}`, '--round-seconds', String(seconds), '--smoke'], catalog);
    assert.equal(plan.scene, 'res://native_arenas/demo.tscn');
    assert.deepEqual(plan.userArgs, [`--map=${map}`, '--mode=deathmatch',
      `--bots=${bots}`, `--round-seconds=${seconds}`, '--smoke']);
  }
});

test('package Native DM rejects unreviewed options and malformed or excessive bot counts', () => {
  const rejected = [
    '--map=meridian-exchange', '--map=showcase', '--map=__proto__',
    '--mode=teamdeathmatch', '--mode=horde', '--endpoint=ws://127.0.0.1:12345',
    '--setup', '--play', '--native-trace', '--mute', '--debug-hud',
    '--time-limit=60', '--round-target=1', '--bots=-1', '--bots=0',
    '--bots=25', '--bots=1.5', '--bots=1e0', '--bots=NaN', '--bots=Infinity',
    '--round-seconds=59', '--round-seconds=301', '--round-seconds=180.0',
    '--unknown', '--', '--help',
  ];
  for (const arg of rejected) assert.throws(() => options(['--experience=native-dm', arg], catalog), Error, arg);
  for (const key of ['map', 'mode', 'bots', 'round-seconds']) {
    assert.throws(() => options(['--experience=native-dm', `--${key}`], catalog), Error, key);
    assert.throws(() => options(['--experience=native-dm', `--${key}=`], catalog), Error, key);
  }
  for (const args of [['--map=prism-foundry', '--map=aurora-basin'], ['--bots=2', '--bots=2'],
    ['--round-seconds=60', '--round-seconds=60'], ['--smoke', '--smoke']]) {
    assert.throws(() => options(['--experience=native-dm', ...args], catalog), Error, args.join(' '));
  }
  // The two source-owned combat families have their own 0..8 option; no
  // other scene inherits the native adapter's 24-seat capability.
  for (const experience of [...Object.keys(EXPERIENCES), ...Object.keys(NATIVE_EXPERIENCES)]) {
    if (!['combat', 'zones'].includes(experience)) {
      assert.throws(() => options([`--experience=${experience}`, '--bots=2'], catalog), Error, experience);
    }
    assert.throws(() => options([`--experience=${experience}`, '--round-seconds=120'], catalog), Error, experience);
  }
});

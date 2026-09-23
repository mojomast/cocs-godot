import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {launchOptions, NATIVE_ARENA_MAPS, IDENTITY_ARENA_MAPS} from './launch_options.mjs';
const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));

test('dev native-dm routes the three identity maps to the Deathmatch scene', () => {
  assert.deepEqual(IDENTITY_ARENA_MAPS, ['lacuna-court', 'vermilion-fold', 'nacre-engine']);
  assert.deepEqual(NATIVE_ARENA_MAPS, ['prism-foundry', 'aurora-basin', 'cinder-array', 'lacuna-court', 'vermilion-fold', 'nacre-engine']);
  for (const map of IDENTITY_ARENA_MAPS) {
    const plan = launchOptions(['--experience=native-dm', `--map=${map}`, '--smoke'], catalog);
    assert.equal(plan.experience, 'native-dm');
    assert.equal(plan.nativeArena, true);
    assert.equal(plan.map, map);
    assert.equal(plan.mode, 'deathmatch');
    assert.equal(plan.endpoint, null);
    assert.equal(plan.smoke, '--smoke');
    assert.deepEqual(plan.sessionOptions, [`--map=${map}`, '--mode=deathmatch', '--bots=2', '--round-seconds=180', '--smoke']);
    assert.deepEqual(plan.args, ['--headless', '--audio-driver', 'Dummy', '--path', 'godot', 'res://native_arenas/demo.tscn']);
    const interactive = launchOptions(['--experience=native-dm', `--map=${map}`, '--bots=1', '--round-seconds=60'], catalog);
    assert.deepEqual(interactive.args, ['--path', 'godot', 'res://native_arenas/demo.tscn']);
    assert.deepEqual(interactive.sessionOptions, [`--map=${map}`, '--mode=deathmatch', '--bots=1', '--round-seconds=60']);
  }
});
test('identity ids are rejected where they are not reviewed routes', () => {
  // Reviewed exception: Horde runs on Nacre Engine through its own identity scene.
  assert.doesNotThrow(() => launchOptions(['--experience=horde', '--map=nacre-engine'], catalog), 'horde nacre-engine');
  for (const map of ['lacuna-court', 'vermilion-fold']) {
    assert.throws(() => launchOptions(['--experience=horde', `--map=${map}`], catalog), Error, `horde ${map}`);
  }
  for (const map of ['lacuna-court', 'vermilion-fold', 'nacre-engine']) {
    for (const experience of ['lobby', 'zones', 'sports', 'objectives', 'lattice', 'combined-arms']) {
      assert.throws(() => launchOptions([`--experience=${experience}`, `--map=${map}`], catalog), Error, `${experience} ${map}`);
    }
  }
  for (const map of ['lacuna', 'Lacuna-Court', 'nacre-engine.json', '../lacuna-court', '__proto__', '']) {
    assert.throws(() => launchOptions(['--experience=native-dm', `--map=${map}`], catalog), Error, map);
  }
  for (const mode of ['domination', 'horde', 'ctf']) {
    assert.throws(() => launchOptions(['--experience=native-dm', '--map=lacuna-court', `--mode=${mode}`], catalog), Error, mode);
  }
  assert.throws(() => launchOptions(['--experience=native-dm', '--map=lacuna-court', '--endpoint=ws://127.0.0.1:1234'], catalog));
  assert.throws(() => launchOptions(['--experience=native-dm', '--map=lacuna-court', '--setup'], catalog));
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options, NATIVE_ARENA_MAPS, IDENTITY_ARENA_MAPS} from './options.mjs';
const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));

test('package native-dm routes the three identity maps to the Deathmatch scene', () => {
  assert.deepEqual(IDENTITY_ARENA_MAPS, ['lacuna-court', 'vermilion-fold', 'nacre-engine']);
  assert.deepEqual(NATIVE_ARENA_MAPS, ['prism-foundry', 'aurora-basin', 'cinder-array', 'lacuna-court', 'vermilion-fold', 'nacre-engine']);
  for (const map of IDENTITY_ARENA_MAPS) {
    const plan = options(['--experience=native-dm', `--map=${map}`, '--smoke'], catalog);
    assert.equal(plan.experience, 'native-dm');
    assert.equal(plan.nativeArena, true);
    assert.equal(plan.map, map);
    assert.equal(plan.mode, 'deathmatch');
    assert.equal(plan.endpoint, null);
    assert.equal(plan.scene, 'res://native_arenas/demo.tscn');
    assert.deepEqual(plan.userArgs, [`--map=${map}`, '--mode=deathmatch', '--bots=2', '--round-seconds=180', '--smoke']);
    const interactive = options(['--experience=native-dm', `--map=${map}`, '--bots=7', '--round-seconds=300'], catalog);
    assert.deepEqual(interactive.userArgs, [`--map=${map}`, '--mode=deathmatch', '--bots=7', '--round-seconds=300']);
  }
});
test('package identity ids are rejected where they are not reviewed routes', () => {
  for (const map of ['lacuna-court', 'vermilion-fold', 'nacre-engine']) {
    for (const experience of ['combat', 'lobby', 'horde', 'zones', 'sports', 'objectives', 'lattice', 'combined-arms', 'arms-race']) {
      assert.throws(() => options([`--experience=${experience}`, `--map=${map}`], catalog), Error, `${experience} ${map}`);
    }
  }
  for (const map of ['lacuna', 'Lacuna-Court', 'nacre-engine.json', '../lacuna-court', '__proto__', '']) {
    assert.throws(() => options(['--experience=native-dm', `--map=${map}`], catalog), Error, map);
  }
  assert.throws(() => options(['--experience=native-dm', '--map=lacuna-court', '--mode=domination'], catalog));
  assert.throws(() => options(['--experience=native-dm', '--map=lacuna-court', '--play'], catalog));
});
test('Windows menus present all six maps as Deathmatch', () => {
  const menu = readFileSync(new URL('./Native Deathmatch.cmd', import.meta.url), 'utf8');
  assert.match(menu, /Native Deathmatch/);
  assert.match(menu, /Local Deathmatch/);
  assert.match(menu, /choice \/c 1234560/);
  for (const map of NATIVE_ARENA_MAPS) assert.ok(menu.includes(`--map=${map}`), map);
  for (const label of ['Prism Foundry', 'Aurora Basin', 'Cinder Array', 'Lacuna Court', 'Vermilion Fold', 'Nacre Engine']) {
    assert.ok(menu.includes(label), label);
  }
  const demo = readFileSync(new URL('./Demo Menu.cmd', import.meta.url), 'utf8');
  assert.match(demo, /Native Deathmatch/);
  for (const name of ['Lacuna', 'Vermilion', 'Nacre']) assert.ok(demo.includes(name), name);
});

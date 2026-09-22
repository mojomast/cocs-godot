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
  // Reviewed exception: Horde runs on Nacre Engine through its own identity scene.
  const horde = options(['--experience=horde', '--map=nacre-engine'], catalog);
  assert.equal(horde.scene, 'res://native_arenas/identity_horde_demo.tscn');
  for (const map of ['lacuna-court', 'vermilion-fold']) {
    assert.throws(() => options(['--experience=horde', `--map=${map}`], catalog), Error, `horde ${map}`);
  }
  for (const map of ['lacuna-court', 'vermilion-fold', 'nacre-engine']) {
    for (const experience of ['combat', 'lobby', 'zones', 'sports', 'objectives', 'lattice', 'combined-arms', 'arms-race']) {
      assert.throws(() => options([`--experience=${experience}`, `--map=${map}`], catalog), Error, `${experience} ${map}`);
    }
  }
  for (const map of ['lacuna', 'Lacuna-Court', 'nacre-engine.json', '../lacuna-court', '__proto__', '']) {
    assert.throws(() => options(['--experience=native-dm', `--map=${map}`], catalog), Error, map);
  }
  assert.throws(() => options(['--experience=native-dm', '--map=lacuna-court', '--mode=domination'], catalog));
  assert.throws(() => options(['--experience=native-dm', '--map=lacuna-court', '--play'], catalog));
});
test('package identity-zones routes Domination on Vermilion Fold only', () => {
  const plan = options(['--experience=identity-zones', '--smoke'], catalog);
  assert.equal(plan.identityZone, true);
  assert.equal(plan.map, 'vermilion-fold');
  assert.equal(plan.mode, 'domination');
  assert.equal(plan.scene, 'res://native_arenas/identity_zone_demo.tscn');
  assert.deepEqual(plan.userArgs, ['--map=vermilion-fold', '--mode=domination', '--bots=2',
    '--round-seconds=120', '--score-limit=30', '--smoke']);
  // The reviewed bounds come from the scene and the authority, not from a wider guess.
  const relaxed = options(['--experience=identity-zones', '--bots=7', '--round-seconds=900', '--score-limit=900'], catalog);
  assert.deepEqual(relaxed.userArgs, ['--map=vermilion-fold', '--mode=domination', '--bots=7',
    '--round-seconds=900', '--score-limit=900']);
  // Solo practice is a reviewed bound on this route: zero bots, unlike native-dm.
  const solo = options(['--experience=identity-zones', '--bots=0'], catalog);
  assert.deepEqual(solo.userArgs, ['--map=vermilion-fold', '--mode=domination', '--bots=0',
    '--round-seconds=120', '--score-limit=30']);
  for (const argv of [['--map=lacuna-court'], ['--map=vermilion-fold', '--mode=koth'],
    ['--bots=8'], ['--round-seconds=59'], ['--score-limit=901'], ['--time-limit=60'], ['--round-target=5']]) {
    assert.throws(() => options(['--experience=identity-zones', ...argv], catalog), Error, argv.join(' '));
  }
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

test('menus expose Domination and the cheat panel as reviewed local routes', () => {
  const domination = readFileSync(new URL('./Domination.cmd', import.meta.url), 'utf8');
  assert.match(domination, /choice \/c 12340/);
  for (const option of ['--experience=identity-zones', '--bots=0', '--bots=6', '--round-seconds=120', '--score-limit=100']) {
    assert.ok(domination.includes(option), option);
  }
  const cheats = readFileSync(new URL('./Cheats.cmd', import.meta.url), 'utf8');
  assert.match(cheats, /set COCS_DEBUG=1/);
  for (const route of ['--experience=identity-zones', '--experience=native-dm', '--experience=horde']) {
    assert.ok(cheats.includes(route), route);
  }
  assert.ok(cheats.includes('F4'), 'god-mode key documented');
  const demo = readFileSync(new URL('./Demo Menu.cmd', import.meta.url), 'utf8');
  assert.match(demo, /choice \/c 123456789GDCX0/);
  for (const label of ['Domination', 'Cheats']) assert.ok(demo.includes(label), label);
  for (const file of ['Domination.cmd', 'Cheats.cmd']) assert.ok(demo.includes(file), file);
});

test('Linux launchers mirror the Windows entry points with the same routes', () => {
  const domination = readFileSync(new URL('./Domination.sh', import.meta.url), 'utf8');
  assert.match(domination, /--experience=identity-zones/);
  assert.match(domination, /exec node run\.mjs/);
  const cheats = readFileSync(new URL('./Cheats.sh', import.meta.url), 'utf8');
  assert.match(cheats, /export COCS_DEBUG=1/);
  assert.match(cheats, /--experience=identity-zones/);
  const build = readFileSync(new URL('./build.py', import.meta.url), 'utf8');
  for (const name of ['Domination.sh', 'Cheats.sh', 'Domination.cmd', 'Cheats.cmd']) {
    assert.ok(build.includes(`"${name}"`), name);
  }
});

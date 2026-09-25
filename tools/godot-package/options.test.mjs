import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options, EXPERIENCES, HORDE_OPERATORS, HORDE_HARNESSES} from './options.mjs';
import {CHARACTERS, HARNESSES, validLoadout} from '../../game/data.mjs';
const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));

test('Horde package route is local-only, fixed default and rejects ignored options', () => {
  for (const map of ['meridian-exchange','verdant-reliquary','ember-crucible']) {
    const plan = options(['--experience=horde',`--map=${map}`], catalog);
    assert.equal(plan.scene, 'res://horde/demo.tscn');
    assert.deepEqual(plan.userArgs, [`--map=${map}`,'--mode=horde']);
    assert.equal(plan.endpoint, null);
  }
  for (const arg of ['--map=tidal-citadel','--mode=deathmatch','--round-target=1','--endless','--upgrades','--endpoint=ws://127.0.0.1:1234','--time-limit=900','--setup','--play','--native-trace','--mute','--debug-hud','--horde-evidence']) {
    assert.throws(() => options(['--experience=horde',arg], catalog), Error, arg);
  }
  assert.throws(() => options(['--experience=horde'], {maps:[]}), /Unsupported/);
});

test('Horde package loadouts match pinned source and reach the scene', () => {
  assert.deepEqual(HORDE_OPERATORS, CHARACTERS.map(row => row.id));
  assert.deepEqual(HORDE_HARNESSES, HARNESSES.map(row => row.id));
  for (const character of HORDE_OPERATORS) for (const harness of HORDE_HARNESSES) {
    const argv = ['--experience=horde','--map=nacre-engine',`--operator=${character}`,`--harness=${harness}`];
    if (validLoadout(character,harness)) {
      const plan = options(argv, catalog);
      assert.equal(plan.scene,'res://native_arenas/identity_horde_demo.tscn');
      assert.ok(plan.userArgs.includes(`--operator=${character}`));
      assert.ok(plan.userArgs.includes(`--harness=${harness}`));
    } else assert.throws(() => options(argv,catalog), /operator\/harness/);
  }
  for (const invalid of ['--operator=invalid','--harness=invalid']) assert.throws(() => options(['--experience=horde',invalid],catalog));
  assert.throws(() => options(['--experience=native-dm','--operator=chatgpt'],catalog));
});

test('package scene routing covers all nine locked identities and preserves native capability subsets', () => {
  const covered = new Set();
  for (const [experience, value] of Object.entries(EXPERIENCES)) {
    for (const [map, modes] of Object.entries(value.maps)) {
      covered.add(map);
      for (const mode of modes) {
        const plan = options([`--experience=${experience}`, `--map=${map}`, `--mode=${mode}`], catalog);
        assert.equal(plan.scene, value.scene);
        assert.ok(plan.userArgs.includes(`--map=${map}`));
        assert.ok(plan.userArgs.includes(`--mode=${mode}`));
      }
    }
  }
  assert.deepEqual([...covered].sort(), catalog.maps.map(m => m.id).sort());
  // SPEC 8.4: no arguments boots the menu, never a match setup; explicit
  // combat keeps --setup, --play/--smoke keep never getting it.
  const boot = options([], catalog);
  assert.equal(boot.experience, 'menu');
  assert.equal(boot.scene, 'res://ui/main_menu.tscn');
  assert.equal(boot.nativeOnly, true);
  assert.equal(boot.endpoint, null);
  assert.deepEqual(boot.userArgs, []);
  assert.ok(!boot.userArgs.includes('--setup'));
  assert.ok(options(['--experience=combat'], catalog).userArgs.includes('--setup'));
  assert.ok(!options(['--play'], catalog).userArgs.includes('--setup'));
  assert.ok(options(['--smoke'], catalog).userArgs.includes('--session-smoke'));
  assert.ok(!options(['--smoke'], catalog).userArgs.includes('--setup'));
});

test('bad package arguments fail before opening an owned server; no silent scene/mode fallback', () => {
  for (const args of [
    ['--experience=__proto__'], ['--map=unknown'],
    ['--map=tidal-citadel'], ['--mode=ctf'], ['--mode=constructor'],
    ['--experience=sports','--mode=deathmatch'], ['--experience=lattice-world','--setup'],
    ['--experience=lattice','--mute'], ['--experience=objectives','--native-trace'],
    ['--experience=lattice','--play'],
    ['--experience=zones','--map=tidal-citadel','--mode=koth'],
    ['--experience=zones','--map=aurora-stadium'],
    ['--experience=combined-arms','--map=tidal-citadel'],
    ['--experience=combined-arms','--mode=payload'],
    ['--experience=arms-race','--map=ion-speedway'],
    ['--experience=arms-race','--mode=deathmatch'],
    ['--experience=arms-race','--time-limit=60'],
    ['--play','--setup'], ['--play','--play'], ['--map=a','--map=b'],
    ['--smoke','--setup'], ['--smoke','--play'], ['--smoke','--smoke'],
    ['--experience=horde','--smoke'], ['--experience=lobby','--smoke'],
    ['--experience'], ['--experience','--play'], ['--map='], ['--endpoint=ws://elsewhere'],
    ['--time-limit=60'], ['--experience=sports','--time-limit=59'],
    ['--experience=sports','--time-limit=901'], ['--experience=sports','--time-limit=60.5'],
    ['--experience=sports','--round-target=11'], ['--experience=sports','--round-target=0'],
    ['--experience=sports','--map=aurora-stadium','--round-target=16'],
    ['--experience=sports','--round-target=9007199254740993'], ['--session-smoke'],
  ]) assert.throws(() => options(args, catalog), undefined, JSON.stringify(args));
  assert.ok(options(['--experience=sports','--time-limit=900','--round-target=10'], catalog));
  assert.ok(options(['--experience=sports','--map=aurora-stadium','--round-target=15'], catalog));
});

test('menu, viewer and operator-preview are parameterless special cases', () => {
  for (const argv of [[], ['--experience=menu']]) {
    const plan = options(argv, catalog);
    assert.equal(plan.experience, 'menu');
    assert.equal(plan.scene, 'res://ui/main_menu.tscn');
    assert.equal(plan.nativeOnly, true);
    assert.equal(plan.endpoint, null);
    assert.deepEqual(plan.userArgs, []);
  }
  const viewer = options(['--experience=viewer'], catalog);
  assert.deepEqual(
    {experience:viewer.experience, scene:viewer.scene, nativeOnly:viewer.nativeOnly, endpoint:viewer.endpoint},
    {experience:'viewer', scene:'res://main.tscn', nativeOnly:true, endpoint:null});
  assert.deepEqual(viewer.userArgs, []);
  const preview = options(['--experience=operator-preview'], catalog);
  assert.deepEqual(
    {experience:preview.experience, scene:preview.scene, nativeOnly:preview.nativeOnly, endpoint:preview.endpoint},
    {experience:'operator-preview', scene:'res://player_models/preview.tscn', nativeOnly:true, endpoint:null});
  assert.deepEqual(preview.userArgs, []);
  // --smoke is the only flag allowed alongside; it reaches the child verbatim.
  for (const experience of ['menu', 'viewer', 'operator-preview']) {
    assert.deepEqual(options([`--experience=${experience}`, '--smoke'], catalog).userArgs, ['--smoke']);
    for (const arg of ['--map=meridian-exchange', '--mode=deathmatch', '--bots=2', '--round-seconds=60',
      '--score-limit=30', '--waves=10', '--time-limit=60', '--round-target=1',
      '--endpoint=ws://127.0.0.1:1234', '--setup', '--play', '--mute', '--debug-hud',
      '--native-trace', '--session-smoke', '--debug-panel']) {
      assert.throws(() => options([`--experience=${experience}`, arg], catalog), Error, `${experience} ${arg}`);
    }
    assert.throws(() => options([`--experience=${experience}`, '--debug-panel', '--smoke'], catalog), /not supported by/, `${experience} debug+smoke`);
  }
});

test('--debug-panel is accepted only by combat, horde, native-dm and identity-zones', () => {
  for (const argv of [
    ['--experience=combat', '--debug-panel'],
    ['--experience=combat', '--play', '--debug-panel'],
    ['--experience=horde', '--debug-panel'],
    ['--experience=horde', '--map=nacre-engine', '--debug-panel'],
    ['--experience=native-dm', '--debug-panel'],
    ['--experience=native-dm', '--map=nacre-engine', '--debug-panel', '--smoke'],
    ['--experience=identity-zones', '--debug-panel'],
    ['--experience=identity-zones', '--debug-panel', '--smoke'],
  ]) {
    assert.ok(options(argv, catalog).userArgs.includes('--debug-panel'), JSON.stringify(argv));
  }
  // Lobby: one clear rejection, endpoint or not. Debug never reaches it.
  assert.throws(() => options(['--experience=lobby', '--debug-panel'], catalog), /multiplayer lobby/);
  assert.throws(() => options(['--experience=lobby', '--endpoint=ws://127.0.0.1:1234', '--debug-panel'], catalog), /multiplayer lobby/);
  for (const experience of ['arms-race', 'zones', 'objectives', 'combined-arms', 'sports', 'lattice', 'lattice-world']) {
    assert.throws(() => options([`--experience=${experience}`, '--debug-panel'], catalog),
      /only available on local combat routes/, experience);
  }
  // Native-only labs keep rejecting it through their own flag guard.
  for (const experience of ['showcase', 'aurora-basin', 'cinder-array', 'particle-lab', 'shader-lab']) {
    assert.throws(() => options([`--experience=${experience}`, '--debug-panel'], catalog),
      /not supported by native-only/, experience);
  }
  // Duplicate detection still applies to the new flag.
  assert.throws(() => options(['--experience=combat', '--debug-panel', '--debug-panel'], catalog), /Duplicate/);
});

test('--waves is a horde-only reviewed 1..30 value, forwarded when supplied', () => {
  for (const waves of ['1', '10', '30']) {
    const plan = options(['--experience=horde', `--waves=${waves}`], catalog);
    assert.ok(plan.userArgs.includes(`--waves=${waves}`), waves);
  }
  // Omitting --waves keeps horde's userArgs byte-identical to the old default.
  assert.deepEqual(options(['--experience=horde'], catalog).userArgs,
    ['--map=meridian-exchange', '--mode=horde']);
  assert.deepEqual(options(['--experience=horde', '--map=nacre-engine'], catalog).userArgs,
    ['--map=nacre-engine', '--mode=horde']);
  for (const bad of ['0', '31', '-1', '1.5', 'abc', '']) {
    if (bad === '') continue; // --waves= dies earlier as a missing value
    assert.throws(() => options(['--experience=horde', `--waves=${bad}`], catalog),
      /--waves must be 1\.\.30/, bad);
  }
  for (const experience of ['combat', 'lobby', 'zones', 'sports', 'objectives',
    'lattice', 'lattice-world', 'combined-arms', 'arms-race']) {
    assert.throws(() => options([`--experience=${experience}`, '--waves=10'], catalog),
      /--waves requires horde/, experience);
  }
  assert.throws(() => options(['--experience=native-dm', '--waves=10'], catalog), /not supported by native-dm/);
  assert.throws(() => options(['--experience=identity-zones', '--waves=10'], catalog), /not supported by identity-zones/);
  assert.throws(() => options(['--experience=showcase', '--waves=10'], catalog), /not supported by native-only/);
  assert.throws(() => options(['--experience=menu', '--waves=10'], catalog), /not supported by menu/);
});

test('menu bot schemas match scene consumption and source bounds', () => {
  for (const experience of ['combat', 'zones']) for (const bots of [0, 2, 8]) {
    const plan = options([`--experience=${experience}`, `--bots=${bots}`], catalog);
    assert.ok(plan.userArgs.includes(`--bots=${bots}`));
  }
  for (const bad of ['-1', '9', '2.5', 'abc', '9007199254740993']) {
    assert.throws(() => options(['--experience=combat', `--bots=${bad}`], catalog), /--bots must be 0\.\.8/);
  }
  for (const experience of ['lobby','horde','arms-race','sports','objectives']) {
    assert.throws(() => options([`--experience=${experience}`, '--bots=2'], catalog), /--bots requires/);
  }
  assert.throws(() => options(['--experience=combat', '--bots=3', '--endpoint=ws://127.0.0.1:1234'], catalog), /requires --experience=lobby/);
});

test('diagnostics reach every route without enabling multiplayer cheats', () => {
  const routes = ['combat','lobby','native-dm','identity-zones','horde','zones',
    'arms-race','combined-arms','sports','objectives','lattice','lattice-world',
    'viewer','operator-preview','showcase','aurora-basin','cinder-array','particle-lab','shader-lab'];
  for (const experience of routes) {
    const plan = options([`--experience=${experience}`, '--diagnostics'], catalog);
    assert.ok(plan.userArgs.includes('--diagnostics'), experience);
    assert.ok(!plan.userArgs.includes('--debug-panel'), experience);
  }
  assert.throws(() => options(['--experience=lobby', '--diagnostics', '--debug-panel'], catalog), /multiplayer lobby/);
  assert.throws(() => options(['--experience=combat', '--debug-panel', '--endpoint=ws://127.0.0.1:1234'], catalog), /owned local/);
  assert.throws(() => options(['--experience=menu', '--diagnostics'], catalog), /not supported/);
});

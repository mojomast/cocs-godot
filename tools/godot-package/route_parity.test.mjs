// route-parity gate: routes.json <-> routes_meta <-> options() <-> launchers.
// Every claim here is bidirectional: the generated file must match a fresh
// generation, the declared schemas must survive the real options() validator,
// and the batch wrappers must only reach experiences the menu can render.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync, existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {options, EXPERIENCES, NATIVE_EXPERIENCES} from './options.mjs';
import {ROUTES as META_ROUTES, CATEGORIES as META_CATEGORIES} from './routes_meta.mjs';

const here = import.meta.dirname;
const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));
const registry = JSON.parse(readFileSync(new URL('../../godot/ui/routes.json', import.meta.url), 'utf8'));
const godotDir = fileURLToPath(new URL('../../godot/', import.meta.url));

const EXPECTED_IDS = [
  // play
  'combat', 'lobby',
  // native
  'native-dm', 'identity-zones', 'horde',
  // modes
  'arms-race', 'zones', 'objectives', 'combined-arms', 'sports', 'lattice', 'lattice-world',
  // lab
  'viewer', 'operator-preview', 'showcase', 'aurora-basin', 'cinder-array',
  'particle-lab', 'shader-lab',
  // cheats
  'cheats-native-dm', 'cheats-identity-zones', 'cheats-horde',
];
const CHEATS_EXPERIENCES = ['horde', 'native-dm', 'identity-zones'];
const experienceOf = routeId => routeId.startsWith('cheats-') ? routeId.slice(7) : routeId;

// ---- helpers: build argv exactly the way the menu emits it -----------------
const mapDefaultOf = route => route.params.find(param => param.key === 'map')?.default ?? null;
const valueFor = (route, param, map) => {
  if (param.values_by_map) return param.values_by_map[map][0]; // menu default = list[0]
  return String(param.default);
};
const argvWith = (route, overrides = {}) => {
  const map = overrides.map ?? mapDefaultOf(route);
  return [...route.flags,
    ...route.params.map(param => `--${param.key}=${overrides[param.key] ?? valueFor(route, param, map)}`)];
};

test('routes.json regeneration is idempotent (gen_routes --check)', () => {
  execFileSync(process.execPath, [join(here, 'gen_routes.mjs'), '--check'], {stdio: 'pipe'});
});

test('registry declares exactly the 22 SPEC routes and covers every experience', () => {
  assert.equal(registry.version, 1);
  assert.equal(registry.generated_by, 'tools/godot-package/gen_routes.mjs');
  assert.deepEqual(registry.categories, META_CATEGORIES);
  const ids = registry.routes.map(route => route.id);
  assert.equal(ids.length, 22);
  assert.deepEqual([...ids].sort(), [...EXPECTED_IDS].sort());
  // Menu order matches the hand-written metadata order.
  assert.deepEqual(ids, META_ROUTES.map(route => route.id));
  assert.equal(new Set(ids).size, 22, 'route ids must be unique');

  // Table counts stay 10/5 (SPEC 5.2: no count changes).
  assert.equal(Object.keys(EXPERIENCES).length, 10);
  assert.equal(Object.keys(NATIVE_EXPERIENCES).length, 5);
  for (const key of Object.keys(EXPERIENCES)) assert.ok(ids.includes(key), `EXPERIENCES.${key} uncovered`);
  for (const key of Object.keys(NATIVE_EXPERIENCES)) assert.ok(ids.includes(key), `NATIVE_EXPERIENCES.${key} uncovered`);
  for (const key of ['native-dm', 'identity-zones', 'viewer', 'operator-preview']) {
    assert.ok(ids.includes(key), `${key} uncovered`);
  }
  // cheats- variants exist only for the three local debug experiences.
  for (const id of ids.filter(id => id.startsWith('cheats-'))) {
    assert.ok(CHEATS_EXPERIENCES.includes(experienceOf(id)), `${id}: no cheats variant for this experience`);
  }
  for (const experience of CHEATS_EXPERIENCES) assert.ok(ids.includes(`cheats-${experience}`));
  // Structural conformance: every route resolves its category and non-empty copy.
  const categoryIds = new Set(registry.categories.map(category => category.id));
  for (const route of registry.routes) {
    assert.ok(categoryIds.has(route.category), `${route.id}: unknown category`);
    assert.equal(typeof route.label, 'string');
    assert.ok(route.label.length > 0 && route.description.length > 0, `${route.id}: copy`);
    assert.deepEqual(route.flags[0], `--experience=${experienceOf(route.id)}`);
  }
});

test('every route argv (defaults, min and max variants) parses through options()', () => {
  for (const route of registry.routes) {
    const mapDefault = mapDefaultOf(route);
    const cases = [[`defaults`, argvWith(route)]];
    for (const param of route.params) {
      assert.ok(['choice', 'range'].includes(param.kind), `${route.id}/${param.key}: kind`);
      if (param.kind === 'range') {
        cases.push([`${param.key}=min`, argvWith(route, {[param.key]: String(param.min)})]);
        // Per-map clamp wins over the global max (mirrors options() sports bounds).
        const max = param.max_by_map?.[mapDefault] ?? param.max;
        cases.push([`${param.key}=max`, argvWith(route, {[param.key]: String(max)})]);
        for (const [map, perMapMax] of Object.entries(param.max_by_map ?? {})) {
          cases.push([`${param.key}=max on ${map}`, argvWith(route, {map, [param.key]: String(perMapMax)})]);
        }
      } else if (param.key === 'map') {
        for (const map of param.values) cases.push([`map=${map}`, argvWith(route, {map})]);
      } else if (param.values_by_map) {
        assert.ok(mapDefault, `${route.id}/${param.key}: values_by_map needs a map default`);
        assert.equal(param.default, param.values_by_map[mapDefault][0],
          `${route.id}/${param.key}: default mode must be values_by_map[default map][0]`);
        for (const [map, modes] of Object.entries(param.values_by_map)) {
          assert.equal(modes.length, new Set(modes).size, `${route.id}/${param.key}: duplicates on ${map}`);
          // Default mode for EVERY map is list[0], exactly what options() picks.
          cases.push([`${param.key} default on ${map}`, argvWith(route, {map, [param.key]: modes[0]})]);
          cases.push([`${param.key} last on ${map}`, argvWith(route, {map, [param.key]: modes.at(-1)})]);
        }
      } else {
        cases.push([`${param.key}=first`, argvWith(route, {[param.key]: param.values[0]})]);
        cases.push([`${param.key}=last`, argvWith(route, {[param.key]: param.values.at(-1)})]);
        assert.ok(param.values.includes(param.default), `${route.id}/${param.key}: default outside values`);
      }
    }
    for (const [label, argv] of cases) {
      assert.doesNotThrow(() => options(argv, catalog), `${route.id} ${label}: ${argv.join(' ')}`);
    }
    // The plan's scene exists on disk for the default argv.
    const plan = options(argvWith(route), catalog);
    assert.ok(existsSync(join(godotDir, plan.scene.slice('res://'.length))),
      `${route.id}: missing ${plan.scene}`);
  }
});

test('batch wrappers only launch experiences the menu can reach', () => {
  const known = new Set(registry.routes.map(route => experienceOf(route.id)));
  // Play.cmd with no args boots the hub itself (`--experience=menu`); the menu is
  // reachable by definition even though it is not one of the playable routes.
  known.add('menu');
  const wrappers = readdirSync(here).filter(name => /\.(cmd|sh)$/.test(name));
  assert.ok(wrappers.length >= 6, `expected the reviewed wrappers, found ${wrappers.length}`);
  const found = new Set();
  for (const name of wrappers) {
    const text = readFileSync(join(here, name), 'utf8');
    for (const [, experience] of text.matchAll(/--experience=([a-z0-9-]+)/g)) found.add(experience);
  }
  assert.ok(found.size > 0, 'no --experience= targets found in wrappers');
  for (const experience of found) {
    assert.ok(known.has(experience), `${experience} in a wrapper but not in routes.json`);
  }
});

test('debug-panel flags: never lobby, only cheats rows in the registry', () => {
  const lobby = registry.routes.find(route => route.id === 'lobby');
  assert.ok(!lobby.flags.includes('--debug-panel'), 'lobby must never carry --debug-panel');
  for (const route of registry.routes) {
    const carries = route.flags.includes('--debug-panel');
    assert.equal(carries, route.id.startsWith('cheats-'), `${route.id}: --debug-panel placement`);
  }
});

test('optional diagnostics and cheats flags stay separate on every route', () => {
  for (const route of registry.routes) {
    assert.ok(route.toggles.some(t => t.key === 'diagnostics' && t.flag === '--diagnostics'), route.id);
    const cheatToggle = route.toggles.find(t => t.key === 'cheats');
    assert.equal(Boolean(cheatToggle), ['combat','horde','native-dm','identity-zones'].includes(route.id));
    const argv = [...argvWith(route), '--diagnostics', ...(cheatToggle ? ['--debug-panel'] : [])];
    assert.doesNotThrow(() => options(argv, catalog), route.id);
    if (route.id === 'lobby') assert.ok(!route.flags.includes('--debug-panel'));
  }
  const zones = registry.routes.find(route => route.id === 'zones');
  assert.deepEqual(zones.params.find(param => param.key === 'bots'),
    {key:'bots', kind:'range', label:'Bots', min:0, max:8, default:2, step:1});
});

test('build.py and export_presets.cfg ship ui/*.json through the include filter', () => {
  const filterOf = text => (text.match(/include_filter="([^"]*)/) ?? [, ''])[1];
  const build = readFileSync(join(here, 'build.py'), 'utf8');
  const presets = readFileSync(fileURLToPath(new URL('../../godot/export_presets.cfg', import.meta.url)), 'utf8');
  assert.ok(filterOf(build).split(',').includes('ui/*.json'), 'build.py include_filter lacks ui/*.json');
  assert.ok(filterOf(presets).split(',').includes('ui/*.json'), 'export_presets.cfg include_filter lacks ui/*.json');
});

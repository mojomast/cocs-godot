#!/usr/bin/env node
// Generates godot/ui/routes.json (schema version 1) from:
//   - tools/godot-package/options.mjs  (EXPERIENCES / NATIVE_EXPERIENCES / arenas)
//   - tools/godot-package/routes_meta.mjs (labels, descriptions, param schemas)
//   - port/contracts/map-selection.json (catalog display names)
//
// Usage:
//   node tools/godot-package/gen_routes.mjs                 write godot/ui/routes.json
//   node tools/godot-package/gen_routes.mjs --out=<path>    write <path>
//   node tools/godot-package/gen_routes.mjs --check         exit 1 if the committed
//                                                           file is stale (parity gate)
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import assert from 'node:assert/strict';
import {EXPERIENCES, NATIVE_EXPERIENCES, NATIVE_ARENA_MAPS} from './options.mjs';
import {CATEGORIES, MAP_NAMES, ROUTES} from './routes_meta.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const catalog = JSON.parse(readFileSync(
  new URL('../../port/contracts/map-selection.json', import.meta.url), 'utf8'));
const defaultOut = fileURLToPath(new URL('../../godot/ui/routes.json', import.meta.url));

// Options() experiences outside the two tables (special cases in options.mjs).
const SPECIAL_EXPERIENCES = ['native-dm', 'identity-zones', 'viewer', 'operator-preview'];
const KNOWN_EXPERIENCES = new Set([
  ...Object.keys(EXPERIENCES), ...Object.keys(NATIVE_EXPERIENCES), ...SPECIAL_EXPERIENCES,
]);

// Experience id of a route (cheats- prefix is presentation only).
const experienceOf = routeId => routeId.startsWith('cheats-') ? routeId.slice(7) : routeId;

// Flags are derived, never hand-written: `--experience=<id>`, plus `--play` for
// combat and `--debug-panel` for cheats rows (SPEC section 4).
const flagsOf = routeId => {
  const flags = [`--experience=${experienceOf(routeId)}`];
  if (routeId.startsWith('cheats-')) flags.push('--debug-panel');
  if (routeId === 'combat') flags.push('--play');
  return flags;
};

// Per-map mode lists merged from EXPERIENCES, including horde's identity
// entry (nacre-engine) — the same allowlist options() resolves at runtime.
const modesByMap = experience => {
  const selected = EXPERIENCES[experience];
  if (!selected) return null;
  const merged = {};
  for (const [map, modes] of Object.entries(selected.maps)) merged[map] = [...modes];
  for (const [map, entry] of Object.entries(selected.identity ?? {})) merged[map] = [...entry.modes];
  return merged;
};
const mapsByExperience = experience => EXPERIENCES[experience]
  ? [...Object.keys(EXPERIENCES[experience].maps), ...Object.keys(EXPERIENCES[experience].identity ?? {})]
  : null;

// Choice params are regenerated from the experience tables and cross-checked
// against routes_meta, so meta drift fails loudly instead of shipping.
const buildParams = route => {
  const experience = experienceOf(route.id);
  return route.params.map(param => {
    if (param.key === 'map') {
      const values = experience === 'native-dm' ? [...NATIVE_ARENA_MAPS] : mapsByExperience(experience);
      assert.ok(values, `${route.id}: map param without a known experience`);
      assert.deepEqual(values, param.values,
        `${route.id}: map values differ from the experience table`);
      return {...param, values};
    }
    if (param.key === 'mode' && param.values_by_map) {
      const derived = modesByMap(experience);
      assert.ok(derived, `${route.id}: values_by_map without a known experience`);
      assert.deepEqual(derived, param.values_by_map,
        `${route.id}: values_by_map differs from the experience table`);
      return {...param, values_by_map: derived};
    }
    if (param.key === 'mode') {
      // Plain ordered mode list (lattice): unique modes across the roster.
      const derived = [...new Set(Object.values(EXPERIENCES[experience].maps).flat())];
      assert.deepEqual(derived, param.values,
        `${route.id}: mode values differ from the experience table`);
      return {...param, values: derived};
    }
    return {...param}; // range params are authored against options() bounds
  });
};

const buildRegistry = () => {
  assert.equal(ROUTES.length, 22, 'SPEC section 4 fixes the route count at 22');
  assert.equal(new Set(ROUTES.map(route => route.id)).size, 22, 'route ids must be unique');
  const categoryIds = new Set(CATEGORIES.map(category => category.id));
  const mapIds = new Set(catalog.maps.map(map => map.id));

  const routes = ROUTES.map(route => {
    assert.ok(categoryIds.has(route.category), `${route.id}: unknown category ${route.category}`);
    assert.ok(typeof route.label === 'string' && route.label.length > 0, `${route.id}: label`);
    assert.ok(typeof route.description === 'string' && route.description.length > 0,
      `${route.id}: description`);
    const experience = experienceOf(route.id);
    assert.ok(KNOWN_EXPERIENCES.has(experience), `${route.id}: unknown experience ${experience}`);
    if (route.id.startsWith('cheats-')) {
      assert.ok(['horde', 'native-dm', 'identity-zones'].includes(experience),
        `${route.id}: cheats variants exist only for horde/native-dm/identity-zones`);
    }
    const params = buildParams(route);
    let mapDefault = null;
    for (const param of params) {
      assert.ok(['choice', 'range'].includes(param.kind), `${route.id}/${param.key}: kind`);
      if (param.key === 'map') mapDefault = param.default;
      if (param.kind === 'choice') {
        if (param.values_by_map) {
          assert.ok(!param.values, `${route.id}/${param.key}: values and values_by_map exclusive`);
          for (const [map, modes] of Object.entries(param.values_by_map)) {
            assert.deepEqual(modes, [...new Set(modes)],
              `${route.id}/${param.key}: duplicate modes within ${map}`);
          }
        } else {
          assert.ok(Array.isArray(param.values) && param.values.length > 0,
            `${route.id}/${param.key}: values required`);
          assert.ok(param.values.includes(param.default),
            `${route.id}/${param.key}: default outside values`);
        }
      } else {
        assert.ok(Number.isInteger(param.min) && Number.isInteger(param.max)
          && param.min <= param.max, `${route.id}/${param.key}: bounds`);
        assert.ok(param.default >= param.min && param.default <= param.max,
          `${route.id}/${param.key}: default outside bounds`);
        assert.ok(Number.isInteger(param.step) && param.step >= 1,
          `${route.id}/${param.key}: step`);
        for (const [map, max] of Object.entries(param.max_by_map ?? {})) {
          assert.ok(max >= param.min && max <= param.max,
            `${route.id}/${param.key}: max_by_map[${map}] outside min..max`);
        }
      }
    }
    // The menu emits the default mode for the default map: it must be the
    // runtime default options() picks (allowed[0]).
    const modeParam = params.find(param => param.key === 'mode');
    if (modeParam?.values_by_map) {
      assert.ok(mapDefault, `${route.id}: values_by_map needs a map param default`);
      assert.equal(modeParam.default, modeParam.values_by_map[mapDefault][0],
        `${route.id}: default mode must be values_by_map[default map][0]`);
    }
    // Stable key order: id, category, label, description, flags, params.
    return {id: route.id, category: route.category, label: route.label,
      description: route.description, flags: flagsOf(route.id), params};
  });

  // Maps block: catalog names first (catalog order), then the native arenas
  // (NATIVE_ARENA_MAPS order) resolved from MAP_NAMES.
  const maps = {};
  for (const entry of catalog.maps) {
    assert.ok(entry.name, `${entry.id}: catalog entry has no display name`);
    maps[entry.id] = {name: entry.name};
  }
  for (const id of NATIVE_ARENA_MAPS) {
    assert.ok(MAP_NAMES[id], `${id}: missing display name in routes_meta MAP_NAMES`);
    maps[id] = {name: MAP_NAMES[id]};
  }
  // Every map id a route can emit must resolve to a display name.
  for (const route of routes) for (const param of route.params) {
    const referenced = [
      ...(param.key === 'map' ? (param.values ?? []) : []),
      ...Object.keys(param.values_by_map ?? {}),
      ...Object.keys(param.max_by_map ?? {}),
    ];
    for (const id of referenced) {
      assert.ok(maps[id], `${route.id}/${param.key}: no display name for map ${id}`);
    }
  }

  return {
    version: 1,
    generated_by: 'tools/godot-package/gen_routes.mjs',
    categories: CATEGORIES.map(({id, label, description}) => ({id, label, description})),
    maps,
    routes,
  };
};

const registry = buildRegistry();
const json = JSON.stringify(registry, null, 2) + '\n';

const argv = process.argv.slice(2);
for (const arg of argv) {
  if (!arg.startsWith('--out=') && arg !== '--check') {
    console.error(`Unknown argument ${arg}. Usage: gen_routes.mjs [--out=<path>] [--check]`);
    process.exit(2);
  }
}
const outArg = argv.find(arg => arg.startsWith('--out='));
const outPath = outArg ? resolve(outArg.slice(6)) : defaultOut;

if (argv.includes('--check')) {
  let committed = null;
  try { committed = readFileSync(outPath, 'utf8'); } catch { committed = null; }
  if (committed !== json) {
    console.error(`${outPath} is stale or unreadable; run: node tools/godot-package/gen_routes.mjs`);
    process.exit(1);
  }
} else {
  mkdirSync(dirname(outPath), {recursive: true});
  writeFileSync(outPath, json);
  console.log(`wrote ${outPath} (${registry.routes.length} routes, version ${registry.version})`);
}

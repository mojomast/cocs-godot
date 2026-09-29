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
import {options, EXPERIENCES, NATIVE_EXPERIENCES, NATIVE_ARENA_MAPS} from './options.mjs';
import {CATEGORIES, MAP_NAMES, ROUTES} from './routes_meta.mjs';
import {candidateMaps, candidateModes, capabilityOf, capabilityShapeErrors} from './route_capabilities.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const catalog = JSON.parse(readFileSync(
  new URL('../../port/contracts/map-selection.json', import.meta.url), 'utf8'));
const defaultOut = fileURLToPath(new URL('../../godot/ui/routes.json', import.meta.url));

// Capability facts are derived once per experience by probing the authoritative
// options() parser, then reused by the cheats variant so the generated registry
// has a single owner. Maps/modes are candidate inputs only; membership is
// observed from actual plans (see route_capabilities.mjs).
const CAPABILITY_CANDIDATES = {
  maps: candidateMaps(catalog, [...NATIVE_ARENA_MAPS, ...Object.keys(EXPERIENCES.horde.identity ?? {})]),
  modes: candidateModes(EXPERIENCES),
};
const capabilityByExperience = new Map();
const capabilityFor = experience => {
  if (!capabilityByExperience.has(experience)) {
    capabilityByExperience.set(experience,
      capabilityOf(options, catalog, [`--experience=${experience}`], CAPABILITY_CANDIDATES));
  }
  return capabilityByExperience.get(experience);
};

// The menu's map/mode choices are table-derived while the capability is
// parser-derived: tie them together so a new choice cannot ship a capability the
// parser rejects, or hide a choice the parser already accepts.
const assertCapabilityMatchesParams = (routeId, params, capability) => {
  const shapeErrors = capabilityShapeErrors(capability, routeId);
  assert.equal(shapeErrors.length, 0, shapeErrors.join('; '));
  const mapParam = params.find(param => param.key === 'map');
  const modeParam = params.find(param => param.key === 'mode');
  const scope = capability.scope;
  if (mapParam) {
    assert.ok(Array.isArray(mapParam.values), `${routeId}: map param without values`);
    assert.deepEqual([...scope.maps].sort(), [...mapParam.values].sort(),
      `${routeId}: capability maps differ from the menu map choices`);
    assert.equal(capability.defaults.map, mapParam.default,
      `${routeId}: parser map default differs from the menu default`);
  }
  if (modeParam?.values_by_map) {
    assert.deepEqual(Object.keys(scope.modes_by_map).sort(),
      Object.keys(modeParam.values_by_map).sort(),
      `${routeId}: capability per-map modes differ from the menu mode choices`);
    for (const [map, modes] of Object.entries(modeParam.values_by_map)) {
      assert.deepEqual([...(scope.modes_by_map[map] ?? [])].sort(), [...modes].sort(),
        `${routeId}/${map}: capability modes differ from the menu mode choices`);
    }
    assert.equal(capability.defaults.mode, modeParam.default,
      `${routeId}: parser mode default differs from the menu default`);
  } else if (Array.isArray(modeParam?.values)) {
    const union = [...new Set(Object.values(scope.modes_by_map).flat())].sort();
    assert.deepEqual(union, [...modeParam.values].sort(),
      `${routeId}: capability modes differ from the menu mode choices`);
  }
};

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
  assert.equal(ROUTES.length, 23, 'original 22 destinations plus Assault');
  assert.equal(new Set(ROUTES.map(route => route.id)).size, 23, 'route ids must be unique');
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
    const toggles = [{key:'diagnostics', flag:'--diagnostics', label:'Diagnostics overlay (F11)', default:false}];
    if (route.category !== 'cheats' && ['combat', 'horde', 'native-dm', 'identity-zones'].includes(experience)) {
      toggles.push({key:'cheats', flag:'--debug-panel', label:'Local cheats (F3)', default:false});
    }
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
    // Capability facts come from actual parser plans; params must agree.
    const capability = capabilityFor(experience);
    assertCapabilityMatchesParams(route.id, params, capability);
    // Honesty guard: player copy must not claim authority the generated facts
    // deny, and must not deny an authority the route owns.
    if (capability.authority.offline) {
      assert.ok(!/owned|loopback|local authority/i.test(route.description),
        `${route.id}: offline route claims an authority it does not own`);
    } else {
      assert.ok(!/no authority/i.test(route.description),
        `${route.id}: route with authority claims "no authority"`);
    }
    // Stable key order: id, category, label, description, flags, params,
    // toggles, capability.
    return {id: route.id, category: route.category, label: route.label,
      description: route.description, flags: flagsOf(route.id), params, toggles, capability};
  });

  // Maps block: catalog names first (catalog order), then the native arenas
  // (NATIVE_ARENA_MAPS order) resolved from MAP_NAMES.
  const maps = {};
  for (const entry of catalog.maps) {
    assert.ok(entry.name, `${entry.id}: catalog entry has no display name`);
    maps[entry.id] = {name: entry.name};
  }
  for (const id of new Set([...NATIVE_ARENA_MAPS, ...Object.keys(EXPERIENCES.horde.identity ?? {})])) {
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

// Source-only generation + audit for the Parallax Observatory districts-v3 candidate.
// Runnable with `node`; no Blender, Godot, server, import or render.
import {mkdirSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {makeRecipe} from './recipe-v3.mjs';
import {auditPhysicalRoutes} from '../../../map_variety/navigation_audit.mjs';
import {loadPack, validateBindings, auditArena, writeCandidate, readJson, REPO_ROOT} from '../../../map_variety/variety_lib.mjs';

export const MAP_ID = 'parallax-observatory';
export const REVISION = 'districts-v3';
export const BINDINGS_PATH = 'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/variety_bindings.json';
export const OUT_DIR = `port/new-maps/${MAP_ID}/variety/${REVISION}`;

export function generate() {
  const bindings = readJson(BINDINGS_PATH);
  const pack = loadPack(bindings.pack);
  const validated = validateBindings(MAP_ID, bindings, pack);
  const arena = makeRecipe();
  const varietyRoutes = arena.routes.filter(r => (arena.verification?.varietyRouteIds ?? []).includes(r.id));
  const audit = auditArena(arena, {bindings, pack, clearance: 0.5, label: MAP_ID, routes: varietyRoutes, visualCongruence: false});
  const base = readJson('godot/multiplayer_worlds/generated/parallax-observatory.json');
  audit.physical = auditPhysicalRoutes(arena, {...base.arena, routes:base.routes});
  audit.failures.push(...audit.physical.failures.map(f=>JSON.stringify(f)));
  return {bindings, pack, validated, arena, audit};
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const {bindings, pack, validated, arena, audit} = generate();
  if (audit.failures.length) {
    console.error(audit.failures.join('\n'));
    process.exit(1);
  }
  const report = {
    id: MAP_ID, revision: REVISION,
    physicalRoutes: {routes:arena.routes.length, failures:audit.physical.failures, baselineDefects:audit.physical.baselineDefects, spacing:.25, capsuleRadius:.42, standingHeight:1.8},
    kitCollisionLineage: arena.art.kitCollisionLineage,
    geometryHash: audit.geometryHash, recipeHash: audit.authority.recipeHash,
    moth: {base: pack.base, baseSha256: pack.baseSha, overlay: pack.overlay, overlaySha256: pack.overlaySha},
    bindings: validated.names, connectivity: {nodes: audit.connectivity.nodes, connected: audit.connectivity.connected},
    routes: arena.routes.map(r => r.id), varietyRoutes: arena.verification.varietyRouteIds,
    preservedRoutes: arena.verification.preservedRoutes,
    varietyDistricts: arena.art.varietyDistricts,
    surfaces: arena.terrain.surfaces.length, walls: arena.terrain.walls.length, blocks: arena.blocks.length, overhead: arena.overhead.length,
    navNodes: arena.navNodes.length, kitDirectives: arena.art.kit.length, portals: arena.art.portals.length,
    preservation: {spawns: arena.spawns, objectiveZones: arena.objectiveZones, flagSpawns: arena.flagSpawns, teamSpawns: arena.teamSpawns, registeredModes: ['deathmatch', 'teamdeathmatch', 'ctf', 'koth', 'uplink', 'holdout']},
    status: 'source-candidate; Blender master/GLB and native acceptance pending',
  };
  const out = resolve(REPO_ROOT, OUT_DIR);
  mkdirSync(out, {recursive: true});
  const candidate = writeCandidate({mapId: MAP_ID, revision: REVISION, authority: audit.authority, bindings, pack, report: {connectivity: {nodes: audit.connectivity.nodes, connected: audit.connectivity.connected}, kit: report.kitDirectives, portals: report.portals}});
  writeFileSync(resolve(out, 'recipe.json'), JSON.stringify(arena) + '\n');
  writeFileSync(resolve(out, 'authority.json'), JSON.stringify(audit.authority) + '\n');
  writeFileSync(resolve(out, 'candidate.json'), JSON.stringify(candidate, null, 2) + '\n');
  writeFileSync(resolve(out, 'provenance.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({id: MAP_ID, geometryHash: audit.geometryHash, connectivity: {nodes: audit.connectivity.nodes, connected: audit.connectivity.connected}, kit: report.kitDirectives, materials: validated.names.length}, null, 2));
}

// Performance + envelope audit for the three identity maps.
//
// Reports, per map:
//   * generated envelope size, wall entry / segment counts, art triangles;
//   * cold and warm `createIdentityMatch` wall-clock (cold = first construction
//     after a fresh recipe load, warm = immediately repeated);
//   * a `navigation()` split (the source function whose wall scan dominated the
//     prototype's 2.9-14.8 s cold construction);
//   * bounded obstruction cost (2,000 fixed queries);
//   * the collision representation's own accounting (blocks vs polygon walls vs
//     movement-only fences) so the simplification cannot be mistaken for
//     missing collision.
//
// Honest scope: Node wall-clock on this host, single process, no GPU. These are
// load-time measurements, not frame-cadence or hardware acceptance.
import {performance} from 'node:perf_hooks';
import {readFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {cpus} from 'node:os';
import {createIdentityMatch, loadRecipe, CATALOG} from './match.mjs';
import {navigation, obstructed, floorAt} from '../../game/core.mjs';
import {terrainWallSegments, terrainTriangles, terrainWallTriangles} from '../../game/terrain.mjs';
import {collisionHash} from '../../game/spatial.mjs';
import {ensureTerrainBvh} from '../../game/terrain-bvh.mjs';

const TARGET_MS = 1500, CEILING_MS = 3000;

export function measure() {
  const report = {
    scope: 'Node wall-clock cold/warm build cost on this host; not GPU or frame-cadence acceptance',
    host: {node: process.version, cpus: cpus().length},
    targetMs: TARGET_MS, ceilingMs: CEILING_MS, maps: [], failures: [],
  };
  for (const id of Object.keys(CATALOG)) {
    const raw = readFileSync(new URL(`../../godot/identity_maps/generated/${id}.json`, import.meta.url), 'utf8');
    const parsedAt = performance.now();
    const recipe = JSON.parse(raw);
    const parseMs = performance.now() - parsedAt;
    const arena = recipe.arena;
    const segments = terrainWallSegments(arena.terrain);
    const wallTriangles = terrainWallTriangles(arena.terrain);
    const surfaceTriangles = terrainTriangles(arena.terrain);
    const bvhAt = performance.now();
    const bvh = ensureTerrainBvh(arena.terrain);
    const bvhMs = performance.now() - bvhAt;
    const navAt = performance.now();
    const nav = navigation(arena);
    const navMs = performance.now() - navAt;
    const hashAt = performance.now();
    const hash = collisionHash(arena);
    const hashMs = performance.now() - hashAt;
    const t0 = performance.now();
    const match = createIdentityMatch(id);
    const coldMs = performance.now() - t0;
    const t1 = performance.now();
    createIdentityMatch(id);
    const warmMs = performance.now() - t1;
    const obsAt = performance.now();
    let blocked = 0;
    for (let i = 0; i < 2000; i++) {
      const x = ((i * 37) % 56) - 28, z = ((i * 53) % 48) - 24;
      if (obstructed(x, 0.001, z, 0.65, arena)) blocked++;
    }
    const obstructMs = performance.now() - obsAt;
    const polygonWalls = arena.terrain.walls.filter(w => Array.isArray(w.vertices)).length;
    const fences = arena.terrain.walls.length - polygonWalls;
    const result = {
      id, jsonBytes: raw.length, parseMs: +parseMs.toFixed(2),
      blocks: arena.blocks.length, surfaces: arena.terrain.surfaces.length,
      polygonWalls, movementFences: fences, wallSegments: segments.length,
      wallTriangles: wallTriangles.length, surfaceTriangles: surfaceTriangles.length,
      artSurfaces: recipe.art.length, artTriangles: recipe.art.reduce((n, s) => n + s.triangles.length, 0),
      bvhTriangles: bvh.triangles, bvhMs: +bvhMs.toFixed(1), navNodes: nav.nodes.length,
      navEdges: nav.edges.reduce((n, e) => n + e.length, 0), navMs: +navMs.toFixed(1),
      collisionHashMs: +hashMs.toFixed(1), collisionHash: hash,
      coldMatchMs: +coldMs.toFixed(1), warmMatchMs: +warmMs.toFixed(1),
      obstruct2000Ms: +obstructMs.toFixed(1), obstruct2000Blocked: blocked,
      actorCount: match.actors.length,
      coldWithinTarget: coldMs <= TARGET_MS, coldWithinCeiling: coldMs <= CEILING_MS,
      textureBudgetBytesClaim: 'see godot/tests/identity_maps/contract.gd (Moth tiles only)',
    };
    if (!result.coldWithinCeiling) report.failures.push({id, kind: 'cold-ceiling', coldMatchMs: result.coldMatchMs, ceiling: CEILING_MS});
    if (!result.coldWithinTarget) report.failures.push({id, kind: 'cold-target', coldMatchMs: result.coldMatchMs, target: TARGET_MS});
    // The map must still answer a floor query everywhere it claims to be walkable.
    for (const [x, z] of [...arena.spawns, ...arena.pickups.map(p => p.slice(1)), ...arena.navNodes]) {
      if (floorAt(x, z, arena) === null) report.failures.push({id, kind: 'floor-missing', x, z});
    }
    report.maps.push(result);
  }
  report.passed = report.failures.length === 0;
  return report;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const report = measure();
  const out = new URL('./evidence/', import.meta.url);
  mkdirSync(out, {recursive: true});
  const name = `perf-${Date.now()}.json`;
  writeFileSync(new URL(name, out), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({passed: report.passed, failures: report.failures, evidence: name}, null, 2));
  for (const m of report.maps) console.log(`${m.id}: cold=${m.coldMatchMs}ms warm=${m.warmMatchMs}ms nav=${m.navMs}ms segments=${m.wallSegments} fences=${m.movementFences} artTri=${m.artTriangles}`);
  process.exitCode = report.passed ? 0 : 1;
}

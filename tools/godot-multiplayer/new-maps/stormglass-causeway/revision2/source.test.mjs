// Stormglass revision-2 bounded source acceptance. No engine, Blender or import.
// Proves the flat Puma road, barriers, race and navigation are untouched, that
// the new coastal relief is outside the road/barrier envelope, and that exactly
// `puma-race` remains registered.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {build} from './build.mjs';
import {ID, LAYOUT_REVISION, SCENIC_CLASSES} from './recipe.mjs';
import {canonical, WORLDS} from '../../../../../port/multiplayer-worlds/catalog.mjs';
import {floorAt} from '../../../../../game/core.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';

const {arena, data} = build();
const sha = s => createHash('sha256').update(s).digest('hex');
const runtime = JSON.parse(readFileSync(new URL('../../../../../godot/multiplayer_worlds/generated/stormglass-causeway.json', import.meta.url)));
const base = runtime.arena;

function distanceToCenterline(x, z) {
  let best = Infinity;
  for (let i = 0; i < arena.race.centerline.length; i++) {
    const a = arena.race.centerline[i], b = arena.race.centerline[(i + 1) % arena.race.centerline.length];
    const dx = b.x - a.x, dz = b.z - a.z, span = dx * dx + dz * dz;
    const t = span > 1e-9 ? Math.max(0, Math.min(1, ((x - a.x) * dx + (z - a.z) * dz) / span)) : 0;
    best = Math.min(best, Math.hypot(x - a.x - dx * t, z - a.z - dz * t));
  }
  return best;
}

test('deterministic revision identity and canonical geometry hash', () => {
  assert.deepEqual(build().data, data);
  assert.equal(data.geometryHash, sha(canonical(arena)));
  assert.equal(data.layoutRevision, LAYOUT_REVISION);
  assert.equal(data.id, ID);
  assert.notEqual(data.geometryHash, runtime.geometryHash);
});

test('the accepted road, barriers, race and terrain are byte-identical', () => {
  assert.deepEqual(arena.terrain, base.terrain);
  assert.deepEqual(arena.race, base.race);
  assert.deepEqual(arena.navNodes, base.navNodes);
  assert.deepEqual(arena.spawns, base.spawns);
  assert.equal(arena.metrics.roadWidth, 28);
  assert.equal(arena.metrics.roadRelief, 0);
});

test('the 28 m Puma road stays flat and supported at every gate', () => {
  for (const p of [...arena.race.centerline, ...arena.race.grid]) {
    assert.equal(floorAt(p.x, p.z, arena), 0);
    assert.equal(terrainSupportAt(p.x, p.z, arena.terrain, arena.terrain.maxSlope).y, 0);
  }
  assert.equal(arena.race.boundary.outer.length, arena.race.centerline.length);
  assert.equal(arena.race.boundary.inner.length, arena.race.centerline.length);
});

test('all scenic relief sits outside the 14 m barrier and never overlaps the road', () => {
  const scenery = arena.art.revision2.scenery;
  const anchors = Object.values(scenery).flat().filter(a => a && typeof a === 'object' && 'x' in a);
  assert.ok(anchors.length >= 25, 'scenic anchor count ' + anchors.length);
  for (const a of anchors) {
    if (a.cls === 'checkpoint-arch') {
      // Checkpoint arches span the existing gate overhead; keep the road clear.
      assert.equal(a.lateral, 0);
      assert.ok(a.clearHeight >= 9, a.id + ' arch clearance');
      continue;
    }
    const distance = distanceToCenterline(a.x, a.z);
    assert.ok(distance >= 16, `${a.id} only ${distance.toFixed(2)} m from the centerline`);
  }
  assert.equal(arena.art.revision2.nontraversal, true);
  assert.deepEqual(arena.art.revision2.scenicClasses, SCENIC_CLASSES);
});

test('scenic relief adds no walkable surface, wall, block or floor', () => {
  assert.equal(arena.terrain.surfaces.length, base.terrain.surfaces.length);
  assert.equal(arena.terrain.walls.length, base.terrain.walls.length);
  assert.equal(arena.blocks.length, base.blocks.length);
  assert.equal(arena.routes.length, base.routes.length);
});

test('exactly puma-race remains registered; no new mode', () => {
  assert.deepEqual(WORLDS[ID].modes, ['puma-race']);
  assert.deepEqual(arena.candidateModes, ['puma-race']);
  assert.deepEqual(arena.modeBindings, {});
  assert.ok(arena.race);
});

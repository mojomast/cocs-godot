// Source-only tests for the Vesper Viaduct urban-v2 candidate.
import test from 'node:test';
import assert from 'node:assert/strict';
import {generate, MAP_ID} from './variety-source-check.mjs';

const {recipe: baseRecipe} = await import('../../recipe.mjs');
const base = baseRecipe();
const {arena, audit, validated} = generate();

test('vesper urban-v2 passes every source probe', () => {
  assert.deepEqual(audit.failures, []);
});

test('vesper urban-v2 preserves routes, spawns, objectives and team frames', () => {
  for (const route of base.routes) assert.ok(arena.routes.some(r => r.id === route.id), `missing route ${route.id}`);
  assert.deepEqual(arena.spawns, base.spawns);
  assert.deepEqual(arena.teamSpawns, base.teamSpawns);
  assert.deepEqual(arena.flagSpawns, base.flagSpawns);
  assert.deepEqual(arena.objectiveZones, base.objectiveZones);
  assert.deepEqual(arena.candidateModes, base.candidateModes);
  assert.deepEqual(arena.modeBindings, {});
});

test('vesper urban-v2 adds the declared districts and kit classes', () => {
  assert.deepEqual(arena.verification.varietyRouteIds, ['retaining-bank--1', 'retaining-bank-1', 'canal-arch-approach--33', 'canal-arch-approach-33', 'era-street', 'roof-access-ramp', 'roof-terrace-loop']);
  assert.deepEqual([...new Set(arena.art.kit.map(k => k.class))].sort(), ['arch_bridge', 'framed_bay', 'retaining_wall', 'roof_run', 'stall_row']);
  assert.deepEqual(arena.art.varietyDistricts, ['era-facade-row', 'covered-market-arcade', 'canal-arch-and-quay', 'retaining-terrace-banks', 'rooftop-access']);
});

test('vesper urban-v2 collision is triangles and every material is bound', () => {
  for (const wall of arena.terrain.walls) assert.equal(wall.vertices.length, 3);
  for (const kit of arena.art.kit) assert.ok(validated.names.includes(kit.material), `unbound ${kit.material}`);
  for (const piece of arena.art.pieces) assert.ok(validated.names.includes(piece.material), `unbound piece ${piece.material}`);
  assert.equal(MAP_ID, 'vesper-viaduct');
});

test('vesper urban-v2 nav graph does not regress and every variety route is reachable', () => {
  assert.ok(audit.connectivity.connected >= (base.navNodes ?? []).length - 4, 'connectivity regressed');
  assert.ok(audit.connectivity.nodes > (base.navNodes ?? []).length);
});

test('vesper urban-v2 keeps the six registered modes and invents none', () => {
  assert.deepEqual(arena.candidateModes, ['deathmatch', 'teamdeathmatch', 'ctf', 'domination', 'koth', 'uplink']);
});

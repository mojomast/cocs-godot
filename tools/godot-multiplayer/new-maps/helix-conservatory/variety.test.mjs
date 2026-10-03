// Source-only tests for the Helix Conservatory revision-3 candidate.
// Runnable with `node --test`; no Blender, Godot, server or render.
import test from 'node:test';
import assert from 'node:assert/strict';
import {generate, MAP_ID} from './variety-source-check.mjs';
import {makeRecipe as base} from './recipe-v2.mjs';

const {arena, audit, validated} = generate();
const baseline = base();

test('helix revision 3 passes every source probe', () => {
  assert.deepEqual(audit.failures, []);
});

test('helix revision 3 preserves routes, spawns, objectives and team frames', () => {
  for (const route of baseline.routes) assert.ok(arena.routes.some(r => r.id === route.id), `missing route ${route.id}`);
  assert.deepEqual(arena.spawns, baseline.spawns);
  assert.deepEqual(arena.teamSpawns, baseline.teamSpawns);
  assert.deepEqual(arena.flagSpawns, baseline.flagSpawns);
  assert.deepEqual(arena.objectiveZones, baseline.objectiveZones);
  assert.deepEqual(arena.modeBindings, {});
});

test('helix revision 3 adds the declared variety routes and districts', () => {
  assert.deepEqual(arena.verification.varietyRouteIds, ['botanical-terrace-cross', 'grotto-loop', 'grotto-spur']);
  assert.deepEqual(arena.art.varietyDistricts, ['rock-grotto-arcade', 'stepped-botanical-banks', 'archive-bay-articulation', 'root-and-greenhouse-forms']);
  assert.deepEqual([...new Set(arena.art.kit.map(k => k.class))].sort(),
    ['curved_rib', 'facade_bays', 'fern_card', 'grotto_arch', 'pipe', 'root_form', 'stepped_terrace']);
});

test('helix revision 3 collision stays triangle walls and every material is bound', () => {
  assert.ok(arena.terrain.walls.length > baseline.terrain.walls.length, 'revision must add collision');
  for (const wall of arena.terrain.walls) assert.equal(wall.vertices.length, 3);
  for (const kit of arena.art.kit) assert.ok(validated.names.includes(kit.material), `unbound ${kit.material}`);
  assert.equal(MAP_ID, 'helix-conservatory');
});

test('helix revision 3 nav graph is fully connected under the source chord scale', () => {
  assert.equal(audit.connectivity.connected, audit.connectivity.nodes);
  assert.ok(audit.connectivity.nodes > baseline.navNodes.length);
});

test('helix revision 3 keeps registered modes and does not invent new ones', () => {
  assert.deepEqual(arena.candidateModes, baseline.candidateModes);
  assert.deepEqual(arena.candidateModes, ['deathmatch', 'teamdeathmatch', 'arsenal', 'juggernaut', 'ctf', 'domination', 'koth']);
});

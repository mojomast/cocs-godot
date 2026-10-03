// Source-only tests for the Parallax Observatory districts-v3 candidate.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {generate, MAP_ID} from './variety-source-check.mjs';

const base = JSON.parse(readFileSync(new URL('../../../../../../godot/multiplayer_worlds/generated/parallax-observatory.json', import.meta.url), 'utf8'));
const {arena, audit, validated} = generate();

test('parallax districts-v3 passes every source probe', () => {
  assert.deepEqual(audit.failures, []);
});

test('parallax districts-v3 preserves spawns, objectives, team frames and base routes', () => {
  assert.deepEqual(arena.spawns, base.arena.spawns);
  assert.deepEqual(arena.teamSpawns, base.arena.teamSpawns);
  assert.deepEqual(arena.flagSpawns, base.arena.flagSpawns);
  assert.deepEqual(arena.objectiveZones, base.arena.objectiveZones);
  assert.deepEqual(arena.verification.preservedRoutes, (base.routes ?? []).map(r => r.id));
  assert.equal(arena.modeBindings, undefined);
  assert.equal(arena.voidY, base.arena.voidY);
});

test('parallax districts-v3 adds the declared districts and kit', () => {
  assert.deepEqual(arena.verification.varietyRouteIds, ['court-approach', 'court-steps', 'lightwell-stair']);
  assert.deepEqual([...new Set(arena.art.kit.map(k => k.class))].sort(), ['instrument_dish', 'lightwell', 'scientific_room', 'stepped_terrace', 'tower']);
  assert.ok(arena.art.portals.length >= 3);
});

test('parallax districts-v3 collision is triangles and materials are bound', () => {
  for (const wall of arena.terrain.walls) assert.equal(wall.vertices.length, 3);
  for (const kit of arena.art.kit) assert.ok(validated.names.includes(kit.material), `unbound ${kit.material}`);
  assert.equal(MAP_ID, 'parallax-observatory');
});

test('parallax districts-v3 nav graph is fully connected', () => {
  assert.equal(audit.connectivity.connected, audit.connectivity.nodes);
  assert.ok(audit.connectivity.nodes > (base.arena.navNodes ?? []).length);
});

test('parallax districts-v3 does not invent modes', () => {
  assert.equal(arena.candidateModes, undefined);
});

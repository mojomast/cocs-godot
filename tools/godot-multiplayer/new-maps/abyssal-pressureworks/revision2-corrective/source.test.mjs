// Abyssal corrective bounded source checks. No engine, Blender or import.
// Proves the new authority layout, navigation and clearances are real, that the
// accepted runtime/profile is untouched, and that no walkable deck overlaps
// another at a different height.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {build} from './build.mjs';
import {ID, LAYOUT_REVISION, REPLACED_ROOF_HOSTS, OPENED_BAYS, SERVICE_CAVE} from './recipe.mjs';
import {navigation, floorAt, obstructed, rayWorld, moveActor} from '../../../../../game/core.mjs';
import {terrainSupportAt, terrainTriangles} from '../../../../../game/terrain.mjs';
import {canonical, WORLDS} from '../../../../../port/multiplayer-worlds/catalog.mjs';

const {arena, data} = build();
const sha = s => createHash('sha256').update(s).digest('hex');
const NEW_DECKS = [['service-terrace-sw', 6], ['service-terrace-se', 0], ['utility-pocket-se', -4]];
const runtime = JSON.parse(readFileSync(new URL('../../../../../godot/multiplayer_worlds/generated/abyssal-pressureworks.json', import.meta.url)));

test('deterministic revision identity and canonical geometry hash', () => {
  assert.deepEqual(build().data, data);
  assert.equal(data.geometryHash, sha(canonical(arena)));
  assert.equal(data.layoutRevision, LAYOUT_REVISION);
  assert.equal(data.id, ID);
  assert.match(data.geometryHash, /^[0-9a-f]{64}$/);
});

test('accepted runtime is untouched and the revision is a strict superset', () => {
  assert.equal(runtime.geometryHash, '32366a6c3df7f95f8d89281c5f83b24d9583cefeb4c0099790303d15349b53be');
  assert.notEqual(data.geometryHash, runtime.geometryHash);
  const hosts = new Set(REPLACED_ROOF_HOSTS.map(id => new RegExp('^' + id + '-(roof-facet-|crown)')));
  const missing = runtime.arena.terrain.surfaces.map(s => s.id)
    .filter(id => !arena.terrain.surfaces.some(s => s.id === id) && ![...hosts].some(r => r.test(id)));
  assert.deepEqual(missing, []);
  // Only the two reviewed low sills may disappear from the base wall set.
  const removedWalls = runtime.arena.terrain.walls.map(w => w.id)
    .filter(id => !arena.terrain.walls.some(w => w.id === id));
  assert.ok(removedWalls.length > 0 && removedWalls.every(id => OPENED_BAYS.some(p => id.startsWith(p))), JSON.stringify(removedWalls));
  assert.equal(arena.terrain.walls.some(w => w.id.startsWith('vessel-0-0-window-header')), true);
});

test('the six replaced vessel roofs are gone and recorded', () => {
  assert.equal(arena.art.revision2.replacedRoofHosts.length, 6);
  for (const host of REPLACED_ROOF_HOSTS) {
    assert.equal(arena.terrain.surfaces.some(s => s.id === host + '-crown' || s.id.startsWith(host + '-roof-facet-')), false, host);
  }
});

test('bounded playable additions resolve at their single authored height', () => {
  for (const [id, y] of NEW_DECKS) {
    const deck = arena.art.revision2.decks.find(d => d.id === id);
    assert.ok(deck, id);
    for (let x = deck.x - deck.w / 2 + 1; x <= deck.x + deck.w / 2 - 1; x += 2) {
      for (let z = deck.z - deck.d / 2 + 1; z <= deck.z + deck.d / 2 - 1; z += 2) {
        const support = terrainSupportAt(x, z, arena.terrain, arena.terrain.maxSlope);
        assert.ok(support, `${id} missing support at ${x},${z}`);
        assert.ok(Math.abs(support.y - y) < 0.05, `${id} height ${support.y} != ${y}`);
      }
    }
    assert.equal(obstructed(deck.x, y, deck.z, 0.52, arena), false, id + ' blocked');
    assert.ok(rayWorld({x: deck.x, y: y + 1.5, z: deck.z}, {x: 0, y: 1, z: 0}, 4, arena) > 3.9, id + ' overhead clearance');
  }
});

test('no two walkable decks overlap at different heights', () => {
  const walkable = terrainTriangles(arena.terrain).filter(t => t.normal[1] > 1e-6 && t.walkable !== false);
  for (let x = -118; x <= 118; x += 3) {
    for (let z = -112; z <= 108; z += 3) {
      const hits = [];
      for (const t of walkable) {
        const [a, b, c] = t.vertices;
        const den = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2]);
        if (Math.abs(den) < 1e-9) continue;
        const u = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / den;
        const v = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / den;
        if (u < -1e-9 || v < -1e-9 || 1 - u - v < -1e-9) continue;
        hits.push(u * a[1] + v * b[1] + (1 - u - v) * c[1]);
      }
      if (hits.length > 1) assert.ok(Math.max(...hits) - Math.min(...hits) < 0.5, `overlapping walkable decks at ${x},${z}`);
    }
  }
});

test('navigation stays one component and reaches every new deck', () => {
  const g = navigation(arena);
  assert.ok(g.nodes.length > 451);
  const seen = new Set([0]), q = [0];
  for (let i = 0; i < q.length; i++) for (const n of g.edges[q[i]]) if (!seen.has(n)) { seen.add(n); q.push(n); }
  assert.equal(seen.size, g.nodes.length, 'navigation graph disconnected');
  for (const [id] of NEW_DECKS) {
    const deck = arena.art.revision2.decks.find(d => d.id === id);
    assert.ok(g.nodes.some(n => Math.hypot(n.x - deck.x, n.z - deck.z) <= 3.5), 'no reachable nav node on ' + id);
  }
});

test('ordinary movement traverses both service terraces and the sunken pocket', () => {
  const sw = {x: -94, y: 6, z: -86, vx: 0, vy: 0, vz: 0, grounded: true, health: 100, character: 'chatgpt', harness: 'openclaw', powerups: {}};
  for (let i = 0; i < 260; i++) moveActor(sw, {z: -1}, 0.025, arena);
  assert.ok(sw.z < -92, 'walked through the observation bay onto service-terrace-sw (z=' + sw.z + ')');
  const se = {x: 91, y: 0, z: -74, vx: 0, vy: 0, vz: 0, grounded: true, health: 100, character: 'chatgpt', harness: 'openclaw', powerups: {}};
  for (let i = 0; i < 320; i++) moveActor(se, {z: -1}, 0.025, arena);
  assert.ok(se.z < -100 && se.y < -3, 'descended the utility ramp into the pocket (z=' + se.z + ', y=' + se.y + ')');
});

test('finite-radius capsules retain continuous terrace, ramp, spawn and objective space', () => {
  assert.equal(SERVICE_CAVE.version, 1);
  assert.deepEqual(SERVICE_CAVE.forms.map(f => f.retainedSide), ['south', 'east']);
  const radius = SERVICE_CAVE.bodyClearance;
  const anchors = [
    ...arena.spawns.map(([x, z]) => ({x, z})),
    ...Object.values(arena.teamSpawns).flat().map(([x, z]) => ({x, z})),
    ...Object.values(arena.flagSpawns),
    ...arena.objectiveZones
  ];
  const sweeps = [[-94, -86, -96], [91, -78, -90], [91, -95, -105]];
  for (const [x, fromZ, toZ] of sweeps) for (let z = fromZ; z >= toZ; z -= .25) anchors.push({x, z});
  for (const p of anchors) {
    const y = floorAt(p.x, p.z, arena);
    assert.ok(Number.isFinite(y), `unsupported capsule ${p.x},${p.z}`);
    assert.equal(obstructed(p.x, y, p.z, radius, arena), false, `blocked capsule ${p.x},${p.z}`);
  }
});

test('all six registered modes keep supported spawns, anchors and clear corridors', () => {
  assert.deepEqual(WORLDS[ID].modes, ['deathmatch', 'teamdeathmatch', 'ctf', 'koth', 'domination', 'holdout']);
  for (const [x, z] of arena.spawns) assert.ok(terrainSupportAt(x, z, arena.terrain, arena.terrain.maxSlope), 'spawn support ' + x + ',' + z);
  for (const pool of Object.values(arena.teamSpawns ?? {})) for (const [x, z] of pool) assert.ok(terrainSupportAt(x, z, arena.terrain, arena.terrain.maxSlope), 'team spawn ' + x + ',' + z);
  for (const p of Object.values(arena.flagSpawns ?? {})) assert.ok(terrainSupportAt(p.x, p.z, arena.terrain, arena.terrain.maxSlope), 'flag ' + p.x + ',' + p.z);
  for (const zone of arena.objectiveZones) {
    const support = terrainSupportAt(zone.x, zone.z, arena.terrain, arena.terrain.maxSlope);
    assert.ok(support && Math.abs(support.y - zone.y) < 0.15, 'objective ' + zone.id);
  }
  assert.equal(floorAt(-94, -68, arena), 6);
});

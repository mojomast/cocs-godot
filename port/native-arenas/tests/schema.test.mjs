import test from 'node:test';
import assert from 'node:assert/strict';
import {NATIVE_ARENA_IDS, IDENTITY_ARENA_IDS, DEATHMATCH_ARENA_IDS, ARENA_CATALOG, nativeArenaEntry} from '../catalog.mjs';
import {parseNativeArena, parseIdentityArena, parseArenaEnvelope, readNativeArena, canonicalArenaJSON, nativeArenaGeometryHash} from '../schema.mjs';
import {validateNativeConfig} from '../match.mjs';
import {syntheticArena, syntheticIdentityArena} from './fixtures.mjs';

test('only three native static asset paths; no source registry aliases', () => {
  assert.deepEqual(NATIVE_ARENA_IDS, ['prism-foundry', 'aurora-basin', 'cinder-array']);
  for (const id of ['exchange', '../../game/maps.mjs', '/etc/passwd', '__proto__', '', null]) {
    assert.throws(() => nativeArenaEntry(id)); assert.throws(() => readNativeArena(id));
  }
});
test('SYNTHETIC: each supported identity parses to an independent envelope', () => {
  for (const id of NATIVE_ARENA_IDS) {
    const data = syntheticArena(id), parsed = parseNativeArena(JSON.stringify(data), id);
    assert.deepEqual(parsed, data); assert.notEqual(parsed, data);
  }
});
test('strict deep generated-data validation rejects malformed/unsafe geometry', () => {
  const mutations = [
    d => d.schemaVersion = 2, d => d.id = 'exchange', d => d.arena.id = 'aurora-basin',
    d => d.geometryHash = 'no provenance', d => d.arena.bounds.minX = Infinity,
    d => d.arena.bounds.maxX = d.arena.bounds.minX, d => d.arena.spawns = [],
    d => d.arena.spawns[0][0] = 500, d => d.arena.spawns[0].push(9),
    d => d.arena.pickups[0][0] = 'shell-injection', d => d.arena.navNodes[0][0] = NaN,
    d => d.arena.terrain.maxSlope = null, d => d.arena.terrain.surfaces[0].walkable = 'yes',
    d => d.arena.terrain.surfaces[0].triangles[0] = [0, 0, 0],
    d => d.arena.terrain.surfaces[0].triangles[0] = [0, 1, 99],
    d => d.arena.terrain.surfaces[0].vertices[0][1] = '4',
    d => d.arena.terrain.surfaces[0].walkable = false,
    d => d.spawnPoints[0].y = 0, d => d.arena.path = '/etc/passwd',
    d => d.arena.botPolicy = 'cheat', d => d.arena.nextGen = true,
    d => d.routes.push({constructor:'unsafe'}), d => d.routes.push({bad:() => 1}),
    d => d.arena.blocks.push({x:0, z:0, w:-1, d:1, h:2}),
  ];
  for (const mutate of mutations) {
    const data = syntheticArena(); mutate(data); assert.throws(() => parseNativeArena(data), String(mutate));
  }
  assert.throws(() => parseNativeArena(syntheticArena(), 'aurora-basin'));
  assert.throws(() => parseNativeArena('{"__proto__":{}}'));
});
test('Deathmatch bounded local config defaults to three bots and rejects counts above 24', () => {
  const config = validateNativeConfig();
  assert.equal(config.mode, 'deathmatch'); assert.equal(config.botCount, 3);
  assert.equal(config.timeLimit, 180); assert.equal(config.fragLimit, 15);
  for (const value of [{mode:'horde'}, {mode:'ctf'}, {botCount:0}, {botCount:25},
    {botCount:'3'}, {fragLimit:1}, {timeLimit:59}, {timeLimit:901}, {difficulty:'elite'},
    {damage:20}, {humanCount:2}, {arena:syntheticArena().arena}, {botPolicy:()=>({})}]) {
    assert.throws(() => validateNativeConfig(value));
  }
});
test('geometryHash binds canonical arena content, independent of object key order', () => {
  assert.equal(canonicalArenaJSON({z:[2, {b:1, a:-0}], a:1e-8}), '{"a":1e-8,"z":[2,{"a":0,"b":1}]}');
  const data = syntheticArena();
  const reordered = Object.fromEntries(Object.entries(data.arena).reverse());
  assert.equal(nativeArenaGeometryHash(reordered), data.geometryHash);
  data.arena.name = data.name = 'Tampered valid name';
  assert.throws(() => parseNativeArena(data), /geometryHash/);
});
test('identity catalog adds exactly the three reviewed ids beside the native three', () => {
  assert.deepEqual(IDENTITY_ARENA_IDS, ['lacuna-court', 'vermilion-fold', 'nacre-engine']);
  assert.deepEqual(DEATHMATCH_ARENA_IDS, ['prism-foundry', 'aurora-basin', 'cinder-array',
    'lacuna-court', 'vermilion-fold', 'nacre-engine']);
  assert.equal(ARENA_CATALOG.length, 6);
  assert.ok(ARENA_CATALOG.every(entry => ['native', 'identity'].includes(entry.family)));
  for (const id of DEATHMATCH_ARENA_IDS) assert.equal(nativeArenaEntry(id).id, id);
  for (const id of ['lacuna-court.json', '../lacuna-court', 'Lacuna-Court', 'lacuna court', 'identity', '']) {
    assert.throws(() => nativeArenaEntry(id)); assert.throws(() => readNativeArena(id));
  }
});
test('SYNTHETIC: identity envelopes parse per family; the native parser never widens', () => {
  for (const id of IDENTITY_ARENA_IDS) {
    const data = syntheticIdentityArena(id);
    const parsed = parseIdentityArena(JSON.stringify(data), id);
    assert.deepEqual(parsed, data); assert.notEqual(parsed, data);
    assert.equal(parseArenaEnvelope(data, id).arena.id, id);
    assert.equal(parseArenaEnvelope(JSON.parse(JSON.stringify(data))).arena.id, id);
    // The lock-step native schema keeps its own envelope allowlist.
    assert.throws(() => parseNativeArena(data, id), /envelope/);
  }
  // Native maps still dispatch to the native parser through the family seam.
  const native = syntheticArena();
  assert.deepEqual(parseArenaEnvelope(native, 'prism-foundry'), native);
  assert.throws(() => parseIdentityArena(native, 'prism-foundry'), /not an identity map/);
  assert.throws(() => parseArenaEnvelope(syntheticIdentityArena(), 'vermilion-fold'), /ID mismatch/);
});
test('shipped Nacre cache plan and megahealth remain readable by native Deathmatch', () => {
  const data = readNativeArena('nacre-engine');
  assert.equal(data.arena.hordeCaches.length, 5);
  assert.ok(data.arena.pickups.some(([kind]) => kind === 'megahealth'));
  assert.deepEqual(data.arena.hordeCaches.map(({wave}) => wave), [1, 3, 5, 7, 9]);
  for (const mutate of [
    a => a.hordeCaches[0].pickupId = a.pickups.length,
    a => a.hordeCaches[1].wave = 0,
    a => a.hordeCaches[0].zone = 'unsafe\nzone',
    a => a.hordeCaches[0].unknown = true,
    a => a.hordeCaches[1].pickupId = a.hordeCaches[0].pickupId,
  ]) {
    const invalid = structuredClone(data);
    mutate(invalid.arena);
    invalid.geometryHash = nativeArenaGeometryHash(invalid.arena);
    assert.throws(() => parseIdentityArena(invalid, 'nacre-engine'));
  }
});
test('identity strict validation rejects malformed presentation/objective/team fields', () => {
  const mutations = [
    d => d.schemaVersion = 2, d => d.mode = 'ctf', d => d.mode = 'koth',
    d => d.palette[0] = 'not-a-color', d => d.palette[0] = 'abcd', d => d.palette[3] = '#aabbcc',
    d => d.palette.push('aabbcc'), d => delete d.art, d => d.art[0].walkable = 'no',
    d => d.art.push({id:'trim', material:'accent', walkable:false, vertices:[[0,0,0],[1,0,0],[0,1,0]], triangles:[[0,1,2]]}),
    d => d.art[0].triangles[0] = [0, 1, 9], d => d.cameras[0].at[1] = '8',
    d => d.cameras = [], d => d.cameras.push({id:'bad'}), d => d.landmarks[0].kind = '',
    d => d.landmarks[0].scale = [1, 0, 1], d => d.landmarks[0] = {kind:'beacon', x:0},
    d => d.grayboxHash = 'XYZ', d => d.geometryHash = '0'.repeat(64),
    d => d.routes[0].points[0].x = 999, d => d.spawnPoints[0].y = 5, d => d.spawnPoints.pop(),
    d => d.spawnPoints[0].w = 1, d => d.colliderSources = [{id:'x', kind:'nope', path:'p', walkable:true, low:[0,0,0], high:[1,1,1], vertexCount:3}],
    d => d.provenance = {godot:1}, d => d.arena.unknown = true, d => d.unknown = true,
    d => d.artNotes = [{id:'x', collision:'none', reason:1}], d => d.artNotes = 'notes',
    d => d.arena.spawns[0][0] = 500, d => d.arena.navNodes.push([NaN, 0]),
    d => d.arena.terrain.surfaces[0].triangles[0] = [0, 1, 99],
    d => d.arena.teamSpawns = {0:[[-14, 0],[-14, 12]], 1:[[14, 0]]},
    d => d.arena.teamSpawns = {west:[[-14, 0],[-14, 12]]},
    d => d.arena.teamSpawns = {0:[[-14, 0],[-14, 12]], 1:[[14, 0],[999, -12]]},
    d => d.arena.teamSpawns = {0:[[-14, 0],[-14, 12]], red:[[14, 0],[14, -12]]},
    d => d.arena.objectiveZones = [{x:0, z:0, radius:0.1}, {x:0, z:10}, {x:0, z:-10}],
    d => d.arena.objectiveZones = [{x:999, z:0}, {x:0, z:0}, {x:0, z:10}],
    d => d.arena.objectiveZones = [{x:0, z:0, y:'zero'}, {x:0, z:10}, {x:0, z:-10}],
  ];
  for (const mutate of mutations) {
    const data = syntheticIdentityArena('prism-foundry');
    mutate(data);
    data.geometryHash = nativeArenaGeometryHash(data.arena);
    assert.throws(() => parseIdentityArena(data), String(mutate));
  }
  // Empty navNodes is valid for identity maps and still invalid for native ones.
  const empty = syntheticIdentityArena();
  empty.arena.navNodes = [];
  empty.geometryHash = nativeArenaGeometryHash(empty.arena);
  assert.equal(parseIdentityArena(empty).arena.navNodes.length, 0);
  assert.throws(() => parseNativeArena({...syntheticArena(), arena:{...syntheticArena().arena, navNodes:[]}}), /navNodes/);
});
test('identity objective/team fields validate strictly when authored (vermilion-fold form)', () => {
  const data = syntheticIdentityArena('vermilion-fold');
  data.arena.navNodes = [];
  data.geometryHash = nativeArenaGeometryHash(data.arena);
  const parsed = parseIdentityArena(data, 'vermilion-fold');
  assert.equal(parsed.arena.objectiveZones.length, 3);
  assert.deepEqual(Object.keys(parsed.arena.teamSpawns).sort(), ['0', '1']);
  // Source teamPoints also consumes red/blue and west/east spellings.
  for (const keys of [['red', 'blue'], ['west', 'east']]) {
    const alias = syntheticIdentityArena('vermilion-fold');
    alias.arena.teamSpawns = {[keys[0]]:alias.arena.teamSpawns[0], [keys[1]]:alias.arena.teamSpawns[1]};
    alias.geometryHash = nativeArenaGeometryHash(alias.arena);
    assert.deepEqual(Object.keys(parseIdentityArena(alias).arena.teamSpawns).sort(), [...keys].sort());
  }
  for (const bad of [
    {0:[[-14, 0],[-14, 12]], 1:[[14, 0]]},
    {0:[[-14, 0],[-14, 12]], 1:[[14, 0],[999, -12]]},
    {0:[[-14, 0],[-14, 12]], 1:[[14, 0],[0, -1000]]},
    {0:[[-14, 0],[-14, 12]], 1:[[14, 0],[14, -12]], 2:[[0, 0],[1, 1]]},
    {0:[[-14, 0],[-14, 12]]},
  ]) {
    const alias = syntheticIdentityArena('vermilion-fold');
    alias.arena.teamSpawns = bad;
    alias.geometryHash = nativeArenaGeometryHash(alias.arena);
    assert.throws(() => parseIdentityArena(alias), 'bad team pool ' + JSON.stringify(bad));
  }
  for (const badZones of [
    [{x:0, z:-10}, {x:0, z:0}],
    [{x:0, z:-10, radius:3}, {x:0, z:0, radius:3}, {x:0, z:10, radius:99}],
    [{x:0, z:-10, y:'zero'}, {x:0, z:0}, {x:0, z:10}],
    [{x:0, z:-10}, {x:0, z:0}, {x:0, z:10}, {x:0, z:0}],
  ]) {
    const alias = syntheticIdentityArena('vermilion-fold');
    alias.arena.objectiveZones = badZones;
    alias.geometryHash = nativeArenaGeometryHash(alias.arena);
    assert.throws(() => parseIdentityArena(alias), 'bad zones');
  }
});

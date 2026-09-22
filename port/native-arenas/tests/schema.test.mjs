import test from 'node:test';
import assert from 'node:assert/strict';
import {NATIVE_ARENA_IDS, nativeArenaEntry} from '../catalog.mjs';
import {parseNativeArena, readNativeArena, canonicalArenaJSON, nativeArenaGeometryHash} from '../schema.mjs';
import {validateNativeConfig} from '../match.mjs';
import {syntheticArena} from './fixtures.mjs';

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
test('Deathmatch bounded config stays source-supported and defaults to three bots', () => {
  const config = validateNativeConfig();
  assert.equal(config.mode, 'deathmatch'); assert.equal(config.botCount, 3);
  assert.equal(config.timeLimit, 180); assert.equal(config.fragLimit, 15);
  for (const value of [{mode:'horde'}, {mode:'ctf'}, {botCount:0}, {botCount:8},
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

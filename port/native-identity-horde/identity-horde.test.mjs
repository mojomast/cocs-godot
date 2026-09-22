// Identity-family (Nacre Engine) Horde adapter tests.
//
// Scope: the reviewed static map/factory hook in port/native-horde/authority.mjs
// plus the real source Match it constructs. No synthetic arena fixtures are
// used for the identity claims: every geometry assertion reads the same
// generated recipe the shipped scene renders.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {RULES} from '../../game/data.mjs';
import {floorAt, obstructed} from '../../game/core.mjs';
import {ENEMY_TYPES, applyEnemyFields} from '../../game/enemy-types.mjs';
import {
  IDENTITY_MAPS, HORDE_MAPS, MAPS, canonicalArenaJSON, identityArenaHash,
  readIdentityMap, validateIdentityEnvelope, createHordeMatch, validateConfig, createAuthority,
} from '../native-horde/authority.mjs';
import {
  IDENTITY_HORDE_MAP, SOURCE_CAPSULE, NAV_PROBE_WIDTH,
  freeWidth, nacreArena, nacreMatch, navEdgeReport, approachReport, measureNacre, verdictFor,
} from './measure.mjs';

const ENVELOPE = JSON.parse(readFileSync(new URL('../../godot/identity_maps/generated/nacre-engine.json', import.meta.url), 'utf8'));

test('identity allowlist is a frozen static literal', () => {
  assert.deepEqual([...IDENTITY_MAPS], ['nacre-engine']);
  assert.ok(Object.isFrozen(IDENTITY_MAPS));
  assert.ok(Object.isFrozen(HORDE_MAPS));
  assert.deepEqual(HORDE_MAPS.slice(0, MAPS.length), MAPS);
  assert.equal(HORDE_MAPS.length, MAPS.length + 1);
});

test('host contract accepts the identity map and nothing path-like', () => {
  for (const mapId of HORDE_MAPS) {
    const config = validateConfig({mapId, config: {mode: 'horde', fragLimit: 2}});
    assert.equal(config.mode, 'horde');
    assert.equal(config.botCount, 0);
    assert.equal(config.fragLimit, 2);
  }
  for (const mapId of ['lacuna-court', 'vermilion-fold', 'nacre-engine.json', 'godot/identity_maps/generated/nacre-engine.json',
    '/etc/passwd', '../../godot/identity_maps/generated/nacre-engine.json', 'NACRE-ENGINE', 'nacre_engine', '']) {
    assert.throws(() => validateConfig({mapId, config: {mode: 'horde'}}), Error, mapId);
  }
  assert.throws(() => validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode: 'deathmatch'}}));
  assert.throws(() => validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode: 'horde', fragLimit: 31}}));
  assert.throws(() => validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode: 'horde', fragLimit: 0}}));
  assert.equal(validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode: 'horde'}}).fragLimit, 10, 'default ten waves');
});

test('readIdentityMap resolves only the allowlisted static recipe', () => {
  const arena = readIdentityMap(IDENTITY_HORDE_MAP);
  assert.equal(arena.id, 'nacre-engine');
  assert.equal(arena.mode, undefined, 'recipe metadata stays on the envelope');
  assert.equal(identityArenaHash(arena), ENVELOPE.geometryHash, 'recomputed canonical hash');
  assert.equal(identityArenaHash(arena), arena.geometryHash ?? identityArenaHash(arena));
  for (const mapId of ['lacuna-court', 'vermilion-fold', 'prism-foundry', 'meridian-exchange', '..', '']) {
    assert.throws(() => readIdentityMap(mapId), /not allowlisted/, mapId);
  }
});

test('a tampered envelope fails closed before any Match exists', () => {
  const clone = () => JSON.parse(JSON.stringify(ENVELOPE));
  assert.equal(validateIdentityEnvelope(clone(), IDENTITY_HORDE_MAP).id, 'nacre-engine', 'unmodified document accepted');
  const geometry = clone();
  geometry.arena.bounds.maxX += 1;
  assert.throws(() => validateIdentityEnvelope(geometry, IDENTITY_HORDE_MAP), /geometryHash does not match canonical arena/);
  const mode = clone();
  mode.mode = 'deathmatch';
  assert.throws(() => validateIdentityEnvelope(mode, IDENTITY_HORDE_MAP), /recipe mode is not horde/);
  const identity = clone();
  identity.arena.spawns[0] = [0, null];
  assert.throws(() => validateIdentityEnvelope(identity, IDENTITY_HORDE_MAP), /spawn (x|z)/);
  const wall = clone();
  wall.arena.terrain.walls[0] = {material: 'shell', a: {x: 0, y: 0}, b: {x: 1, y: 0, z: 0}};
  assert.throws(() => validateIdentityEnvelope(wall, IDENTITY_HORDE_MAP), /wall endpoint/);
  const schema = clone();
  schema.schemaVersion = 2;
  assert.throws(() => validateIdentityEnvelope(schema, IDENTITY_HORDE_MAP), /schemaVersion/);
  const size = clone();
  size.arena.navNodes = 'not-an-array';
  assert.throws(() => validateIdentityEnvelope(size, IDENTITY_HORDE_MAP), /navNodes/);
});

test('canonical hash is key-order independent and array-order sensitive', () => {
  assert.equal(canonicalArenaJSON({b: 1, a: [2, 3]}), '{"a":[2,3],"b":1}');
  assert.notEqual(canonicalArenaJSON({a: [1, 2]}), canonicalArenaJSON({a: [2, 1]}));
  const arena = nacreArena();
  assert.equal(identityArenaHash({...arena}), ENVELOPE.geometryHash);
  assert.notEqual(identityArenaHash({...arena, blocks: [...arena.blocks].reverse()}), ENVELOPE.geometryHash);
});

test('identity factory constructs an unchanged single-human source Match', () => {
  const config = validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode: 'horde', fragLimit: 1}});
  const match = createHordeMatch({mapId: IDENTITY_HORDE_MAP, config, random: () => 0.25});
  assert.equal(match.arena.id, 'nacre-engine');
  assert.equal(match.config.mode, 'horde');
  assert.equal(match.humanCount, 1);
  assert.equal(match.actors.length, 1);
  assert.equal(match.config.botCount, 0);
  assert.equal(match.snapshot().mapId, 'nacre-engine');
  assert.equal(match.snapshot().singleplayer.kind, 'horde');
  assert.equal(match.snapshot().singleplayer.waveTarget, 1);
  assert.ok(match.nav.length > 0, 'identity arena bakes a nav graph');
  assert.ok(match.spawns.length >= 2);
  const actor = match.actors[0];
  assert.notEqual(floorAt(actor.x, actor.z, match.arena), null);
  assert.equal(obstructed(actor.x, actor.y, actor.z, undefined, match.arena), false);
  for (const spawn of match.spawns) {
    assert.notEqual(floorAt(spawn.x, spawn.z, match.arena), null);
    assert.equal(obstructed(spawn.x, spawn.y, spawn.z, RULES.radius, match.arena), false);
  }
});

test('source maps keep the historical constructor through the same hook', () => {
  for (const mapId of MAPS) {
    const config = validateConfig({mapId, config: {mode: 'horde', fragLimit: 1}});
    const match = createHordeMatch({mapId, config, random: () => 0.25});
    assert.equal(match.arena.id, mapId);
    assert.equal(match.config.mode, 'horde');
    assert.equal(match.humanCount, 1);
  }
  assert.throws(() => createHordeMatch({mapId: 'not-a-map', config: validateConfig({mapId: MAPS[0], config: {mode: 'horde'}})}), /not allowlisted|Unsupported/);
  assert.throws(() => createHordeMatch({mapId: IDENTITY_HORDE_MAP, config: {mode: 'deathmatch', botCount: 0}}), /Normalized Horde config/);
  assert.throws(() => createHordeMatch({mapId: IDENTITY_HORDE_MAP, config: {mode: 'horde', botCount: 1}}), /Normalized Horde config/);
});

test('enemy collision uses the shared capsule, never the display scale', () => {
  assert.equal(RULES.radius, 0.42);
  assert.equal(RULES.height, 1.8);
  assert.equal(SOURCE_CAPSULE.neededWidth, 0.84);
  // The visible spread is large; none of it is a collision input.
  const husk = applyEnemyFields({id: 1, character: 'chatgpt', harness: 'openclaw'}, 'husk');
  const brute = applyEnemyFields({id: 2, character: 'deepseek', harness: 'openclaw'}, 'brute');
  assert.equal(husk.npcProfile.scale, ENEMY_TYPES.husk.scale);
  assert.equal(brute.npcProfile.scale, ENEMY_TYPES.brute.scale);
  assert.ok(brute.npcProfile.scale / husk.npcProfile.scale > 1.5, 'display scales genuinely differ');
  // The source's only capsule test takes a radius; there is no actor argument.
  const arena = nacreArena();
  const probe = {x: -26.07, z: -24}; // measured 0.68 m gap between two vault feet
  const measured = freeWidth(arena, probe.x, probe.z);
  assert.ok(measured.width < SOURCE_CAPSULE.neededWidth, `sub-capsule gap measured ${measured.width}`);
  const y = floorAt(probe.x, probe.z, arena);
  assert.equal(obstructed(probe.x, y, probe.z, RULES.radius, arena), true, 'source capsule blocked in the narrow gap');
  assert.equal(obstructed(probe.x, y, probe.z, RULES.radius * brute.npcProfile.scale, arena), true, 'scaled-up capsule also blocked');
  // If the display scale were the collision size, the husk (0.72) and the brute
  // (1.32) would disagree about this exact spot. The source instead applies one
  // radius to every actor, which is why Nacre's clearance must be measured
  // against 0.42 and not against a per-enemy display size.
  assert.equal(obstructed(probe.x, y, probe.z, RULES.radius * husk.npcProfile.scale, arena), false, 'smaller scaled probe would pass');
  // Display scale is not part of the movement signature at all: the capsule test
  // takes a radius, never an actor.
  assert.equal(obstructed.length, 3, 'obstructed(x,y,z) keeps its historical arity');
});

test('the baked nav graph is stricter than the enemy capsule', () => {
  const match = nacreMatch(1);
  const arena = nacreArena();
  assert.ok(match.nav.length >= 2);
  for (const node of match.nav) {
    const y = floorAt(node.x, node.z, arena);
    assert.notEqual(y, null);
    assert.equal(obstructed(node.x, y, node.z, 0.65, arena), false, 'nav node below the bake probe radius');
  }
  const report = navEdgeReport(match, arena);
  assert.ok(report.edges > 0);
  assert.equal(report.edgesBelowCapsule, 0, 'an accepted nav edge narrower than the enemy capsule');
  assert.ok(report.narrowestEdge.width >= NAV_PROBE_WIDTH - 1e-6,
    `narrowest accepted edge ${report.narrowestEdge.width} m`);
  assert.equal(verdictFor(report.narrowestEdge.width), 'passes-nav-probe');
  assert.equal(verdictFor(0.5), 'blocked-for-source-capsule');
  assert.equal(verdictFor(0.9), 'passes-capsule-only');
});

test('every authored spawn and approach reaches the arena centre on the graph', () => {
  const match = nacreMatch(1);
  const arena = nacreArena();
  const report = approachReport(match, arena);
  assert.equal(report.approaches.length, match.spawns.length);
  for (const approach of report.approaches) {
    assert.equal(approach.reachable, true, `unreachable spawn ${approach.spawn}`);
    assert.ok(approach.minWidth >= SOURCE_CAPSULE.neededWidth,
      `approach from ${approach.spawn} narrower than the capsule: ${approach.minWidth}`);
  }
  const measured = measureNacre();
  assert.equal(measured.capsule.radius, RULES.radius);
  assert.ok(measured.footprintScan.free > 0);
  assert.match(measured.displayScaleNote, /presentation-only/);
});

test('identity authority is loopback-only, single-client and bounded', async () => {
  const authority = createAuthority();
  try {
    await new Promise(resolve => authority.server.listen(0, '127.0.0.1', resolve));
    const port = authority.server.address().port;
    const health = await (await fetch(`http://127.0.0.1:${port}`)).json();
    assert.equal(health.service, 'cocs-local-horde');
    assert.equal(health.localOnly, true);
    assert.equal(health.port, port);
    assert.equal(authority.wss.clients.size, 0);
  } finally {
    await authority.close();
  }
  assert.equal(authority.server.listening, false);
});

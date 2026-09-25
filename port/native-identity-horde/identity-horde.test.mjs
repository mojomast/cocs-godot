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
  const cache = clone();
  cache.arena.hordeCaches[1].pickupId = cache.arena.hordeCaches[0].pickupId;
  cache.geometryHash = identityArenaHash(cache.arena);
  assert.throws(() => validateIdentityEnvelope(cache, IDENTITY_HORDE_MAP), /horde cache id/,
    'even a recomputed hash cannot turn duplicate weapon gates into a valid map');
  const start = clone();
  start.arena.teamSpawns[0] = [[Infinity, 0]];
  start.geometryHash = identityArenaHash(start.arena);
  assert.throws(() => validateIdentityEnvelope(start, IDENTITY_HORDE_MAP), /horde start x/);
});

test('canonical hash is key-order independent and array-order sensitive', () => {
  assert.equal(canonicalArenaJSON({b: 1, a: [2, 3]}), '{"a":[2,3],"b":1}');
  assert.notEqual(canonicalArenaJSON({a: [1, 2]}), canonicalArenaJSON({a: [2, 1]}));
  const arena = nacreArena();
  assert.equal(identityArenaHash({...arena}), ENVELOPE.geometryHash);
  assert.notEqual(identityArenaHash({...arena, blocks: [...arena.blocks].reverse()}), ENVELOPE.geometryHash);
});

test('identity factory constructs a single-human source Match with the authored Horde start', () => {
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
  assert.ok(match.arena.teamSpawns[0].some(([x,z]) => actor.x===x && actor.z===z),
    'human starts in the defended service bay, not in an enemy spawn');
  assert.ok(match.arena.teamSpawns[1].some(([x]) => x < 0));
  assert.ok(match.arena.teamSpawns[1].some(([x]) => x > 0));
  assert.notEqual(floorAt(actor.x, actor.z, match.arena), null);
  assert.equal(obstructed(actor.x, actor.y, actor.z, undefined, match.arena), false);
  for (const spawn of match.spawns) {
    assert.notEqual(floorAt(spawn.x, spawn.z, match.arena), null);
    assert.equal(obstructed(spawn.x, spawn.y, spawn.z, RULES.radius, match.arena), false);
  }
});

test('identity Horde seats every valid source operator and harness, including Claude lock', () => {
  const config = validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode:'horde', fragLimit:1}});
  for (const [character,harness] of [['grok','hermes'],['qwen','codex'],['claude','claudecode']]) {
    const match = createHordeMatch({mapId: IDENTITY_HORDE_MAP, config, character, harness, random:()=>0.25});
    assert.equal(match.actors[0].character,character);
    assert.equal(match.actors[0].harness,harness);
  }
  assert.throws(() => createHordeMatch({mapId:IDENTITY_HORDE_MAP,config,character:'claude',harness:'openclaw'}),/operator\/harness/);
});

test('held kick repeats on the pinned source melee cooldown without invented hits', () => {
  const config = validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode:'horde',fragLimit:1}});
  const match = createHordeMatch({mapId:IDENTITY_HORDE_MAP,config,random:()=>0.25});
  for(let tick=0;tick<90;tick++) match.step(1/60,{inputs:{0:{melee:true}}});
  const attacks=match.events.filter(event=>event.type==='melee'&&event.actor===0);
  assert.equal(attacks.length,3);
  assert.ok(attacks.every(event=>event.hit==null),'no target means no fabricated damage');
  for(let i=1;i<attacks.length;i++) assert.ok(attacks[i].time-attacks[i-1].time>=0.59,'source controls accepted kick cadence');
});

test('all Nacre supply stations have supported floor and reachable pickup clearance', () => {
  const match = nacreMatch();
  for (const pickup of match.pickups) {
    const y = floorAt(pickup.x,pickup.z,match.arena);
    assert.notEqual(y,null,`${pickup.kind} has floor`);
    assert.equal(obstructed(pickup.x,y,pickup.z,RULES.radius,match.arena),false,
      `${pickup.kind} is not placed inside cover`);
    assert.ok(match.nav.some(node => Math.hypot(node.x-pickup.x,node.z-pickup.z)<4),
      `${pickup.kind} is close to a source navigable route`);
  }
});

test('source wave transitions open real Nacre weapons in order; all ten waves can complete', {timeout:120000}, () => {
  const config = validateConfig({mapId:IDENTITY_HORDE_MAP,config:{mode:'horde',fragLimit:10}});
  const match = createHordeMatch({mapId:IDENTITY_HORDE_MAP,config,random:()=>0.25});
  const caches = match.arena.hordeCaches;
  const item = entry => match.pickups.find(p => p.id === entry.pickupId);
  assert.equal(item(caches[0]).wait,0,'starting scattergun is available during the first intermission');
  for (const entry of caches.slice(1)) assert.ok(item(entry).wait>1e8,`${entry.zone} weapon starts hidden`);
  const opened=[]; let lastEvent=0, lastWave=0;
  const player=match.actors[0];
  // Bounded *unit* stimulus: skip combat by landing source damage, never forge
  // source wave state or directly unlock a cache. This is not a natural-play claim.
  player.protection=1e9;
  // Place the survivor at the West Workshop cache to exercise ordinary source
  // proximity collection before and after the wave-3 authority opens it.
  player.x=item(caches[1]).x;player.z=item(caches[1]).z;
  player.y=floorAt(player.x,player.z,match.arena);
  player.lastValid={x:player.x,y:player.y,z:player.z};
  match.step(0.1,{});
  assert.equal(player.ammo[4],0,'locked plasma cannot be collected by proximity');
  assert.equal(match.stats.pickups,0,'no early cache pickup event');
  for (let tick=0;tick<2400 && !match.over;tick++) {
    if (match.modeState.phase==='wave') for (const npc of match.actors.filter(a=>a.isNpc && a.health>0)) {
      npc.protection=0;
      match.damage(npc,1e6,player);
    }
    match.step(0.1,{});
    for (const event of match.events) if (event.id>lastEvent) {
      if (event.type==='horde-cache-open') opened.push({wave:event.wave,kind:event.kind,pickupId:event.pickupId});
      lastEvent=Math.max(lastEvent,event.id);
    }
    const wave=match.modeState.wave;
    if (wave>lastWave) {
      for (const entry of caches) {
        assert.equal(item(entry).wait>1e8,wave<entry.wave,`${entry.zone} visibility on wave ${wave}`);
      }
      lastWave=wave;
    }
  }
  assert.equal(match.over,true,'bounded ten-wave source run finishes');
  assert.equal(match.modeState.phase,'won');
  assert.equal(lastWave,10);
  assert.ok(player.ammo[4]>0,'after wave 3, the real source pickup grants plasma ammo');
  assert.ok(match.stats.pickups>=1,'source pickup event occurs after release');
  assert.deepEqual(opened,caches.slice(1).map(entry=>({wave:entry.wave,
    kind:match.arena.pickups[entry.pickupId][0],pickupId:entry.pickupId})),
    'one authority event per opening, no early release or duplicate on later waves');
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

// Source-backed Domination contract for Vermilion Fold.
//
// Part 1 pins the factory: the identity envelope's strict objectiveZones and
// teamSpawns reach the source Match BEFORE nav/objective/actors initialize, the
// scoped accessor refuses any second assignment, and the route's launch config
// is the ordinary source rule set.
//
// Part 2 is the deterministic rules acceptance with two real local seats (one
// per team, zero bots): capture, contest, neutralize/lose, recover, hold
// scoring from both teams, the score-limit results and a clean restart. Every
// assertion reads source state.
import test from 'node:test';
import assert from 'node:assert/strict';
import {floorAt, obstructed} from '../../../game/core.mjs';
import {MAPS, getMap} from '../../../game/maps.mjs';
import {readNativeArena, nativeArenaGeometryHash} from '../../native-arenas/schema.mjs';
import {IDENTITY_ARENA_IDS, nativeArenaEntry} from '../../native-arenas/catalog.mjs';
import {IDENTITY_ZONE_IDS, IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE, identityZoneAllowed, identityZoneEntry} from '../catalog.mjs';
import {createIdentityZoneMatch, identityTeamPool, validateIdentityZoneConfig} from '../match.mjs';
import {controlsToward, followRoute, hold, routeBetween, seededRandom, stepUntil} from '../fixtures.mjs';

const MAP = IDENTITY_ZONE_MAP_ID;

test('identity zone allowlist pins one reviewed map/mode pair and its identity entry', () => {
  assert.equal(IDENTITY_ZONE_MAP_ID, 'vermilion-fold');
  assert.equal(IDENTITY_ZONE_MODE, 'domination');
  assert.equal(identityZoneAllowed(MAP, 'domination'), true);
  assert.equal(identityZoneAllowed(MAP, 'deathmatch'), false);
  assert.equal(identityZoneAllowed('lacuna-court', 'domination'), false);
  assert.equal(identityZoneAllowed('prism-foundry', 'domination'), false);
  assert.throws(() => identityZoneEntry('lacuna-court'), /Unsupported identity zone map/);
  assert.throws(() => identityZoneEntry('prism-foundry'), /Unsupported identity zone map/);
  const entry = identityZoneEntry(MAP);
  assert.equal(entry.family, 'identity');
  assert.equal(entry.mode, 'domination');
  assert.equal(entry.path, nativeArenaEntry(MAP).path);
  assert.ok(IDENTITY_ARENA_IDS.includes(entry.id));
});

test('identity zone config accepts only ordinary source domination rules', () => {
  const config = validateIdentityZoneConfig({});
  assert.equal(config.mode, 'domination');
  assert.equal(config.botCount, 2);
  assert.equal(config.timeLimit, 300);
  assert.equal(config.fragLimit, 100);
  for (const bad of [{mode:'deathmatch'}, {mode:'koth'}, {mode:'horde'}]) {
    assert.throws(() => validateIdentityZoneConfig(bad), /domination only/);
  }
  for (const bad of [{botCount:-1}, {botCount:8}, {timeLimit:59}, {timeLimit:901}, {fragLimit:0}, {fragLimit:901}]) {
    assert.throws(() => validateIdentityZoneConfig(bad), /must be/);
  }
  assert.throws(() => validateIdentityZoneConfig({difficulty:'impossible'}), /Unsupported difficulty/);
  assert.throws(() => validateIdentityZoneConfig({map:MAP}), /Domination config/);
  assert.throws(() => createIdentityZoneMatch({loadouts:{2:{character:'chatgpt'}}}), /seat is out of range/);
  assert.throws(() => createIdentityZoneMatch({loadouts:{0:{character:'nobody'}}}), /Unsupported loadout character/);
  assert.throws(() => createIdentityZoneMatch({loadouts:{0:{weapon:'rail'}}}), /Unsupported loadout field/);
  const normalized = validateIdentityZoneConfig({botCount:0, timeLimit:60, fragLimit:1});
  assert.equal(normalized.botCount, 0);
  assert.equal(normalized.fragLimit, 1);
  assert.equal(normalized.timeLimit, 60);
});

test('identity zone factory builds a real source domination Match from the validated arena', () => {
  const data = readNativeArena(MAP);
  assert.equal(nativeArenaGeometryHash(data.arena), data.geometryHash);
  const match = createIdentityZoneMatch({random:seededRandom(42), config:{botCount:2, timeLimit:300, fragLimit:100}});
  assert.equal(match.arena.id, MAP);
  assert.equal(match.config.mode, 'domination');
  assert.equal(match.snapshot().mapId, MAP);
  assert.equal(match.objectiveState.kind, 'domination');
  assert.equal(match.actors.length, 3);
  assert.equal(match.actors[0].id, 0);
  assert.equal(match.actors[0].team, 0);
  assert.equal(match.actors[0].bot, null);
  assert.ok(match.actors.slice(1).every(actor => actor.bot !== null), 'reserved seats are genuine source bots');
  assert.ok(match.nav.length > 0, 'identity nav graph constructed');
  // Zones are the authored fold points in authored order (or a documented snap
  // onto an existing source nav node), at the authored radius, on real support.
  const authored = data.arena.objectiveZones;
  assert.equal(authored.length, 3);
  assert.deepEqual(authored.map(zone => [zone.x, zone.z, zone.radius]), [[0, -17, 3.5], [0, 0, 3.5], [0, 17, 3.5]]);
  match.objectiveState.zones.forEach((zone, index) => {
    assert.equal(zone.id, IDENTITY_ZONE_IDS[index]);
    const source = authored[index];
    const onAuthored = zone.x === source.x && zone.z === source.z;
    const onNav = match.nav.some(node => node.x === zone.x && node.z === zone.z);
    assert.ok(onAuthored || onNav, `zone ${zone.id} sits on the authored point or a source nav node`);
    assert.equal(zone.radius, source.radius);
    assert.ok(Number.isFinite(zone.y) && zone.y > data.arena.voidY);
    assert.ok(Math.abs(zone.y - floorAt(zone.x, zone.z, data.arena)) < .15);
    assert.equal(zone.owner, null);
    assert.equal(zone.captureTeam, null);
    assert.equal(zone.progress, 0);
    assert.equal(zone.captureSeconds, 5);
  });
  // Both validated team pools survive source normalization exactly, and every
  // published point is real standable ground.
  for (const team of [0, 1]) {
    const pool = identityTeamPool(data.arena, team);
    assert.equal(pool.length, 3);
    assert.deepEqual(match.teamSpawns[team].map(point => [point[0], point[1]]), pool);
    for (const [x, z] of pool) {
      const y = floorAt(x, z, data.arena);
      assert.ok(Number.isFinite(y) && Math.abs(y) < .15);
      assert.equal(obstructed(x, y, z, undefined, data.arena), false);
      assert.ok(match.actors.some(actor => actor.team === team && actor.x === x && actor.z === z) ||
        match.spawns.some(point => point.x === x && point.z === z));
    }
  }
  // The scoped accessor is not a registry write: a second construction on the
  // same envelope still gets the identity arena, and the source registry itself
  // never gained the identity id.
  const again = createIdentityZoneMatch({random:seededRandom(7)});
  assert.equal(again.arena.id, MAP);
  assert.equal(again.objectiveState.zones.length, 3);
  // No global registry write: the source map table never gained the identity id
  // and the source lookup still resolves its own first map for the identity id.
  assert.equal(MAPS.some(entry => entry.id === MAP), false);
  assert.notEqual(getMap(MAP)?.id, MAP);
  assert.throws(() => createIdentityZoneMatch({mapId:'lacuna-court'}), /Unsupported identity zone map/);
  const provenance = match.identityProvenance;
  assert.equal(provenance.mode, 'domination');
  assert.equal(provenance.geometryHash, data.geometryHash);
  assert.deepEqual(provenance.teamSpawns[0], identityTeamPool(data.arena, 0));
  assert.deepEqual(provenance.teamSpawns[1], identityTeamPool(data.arena, 1));
  assert.ok(Object.keys(match).every(key => key !== 'identityProvenance'), 'provenance stays out of source enumerables');
  console.log(JSON.stringify({gate:'identity-zone-factory', mapId:MAP, geometryHash:data.geometryHash,
    zones:match.objectiveState.zones.map(zone => ({id:zone.id, x:zone.x, z:zone.z, radius:zone.radius, y:zone.y})),
    teamSpawns:{0:match.teamSpawns[0], 1:match.teamSpawns[1]}, nav:match.nav.length}));
});

test('identity zone domination rules: capture, contest, lose, recover, both teams score, results, restart', {timeout:120000}, () => {
  const data = readNativeArena(MAP);
  const arena = data.arena;
  const config = {mode:'domination', botCount:0, timeLimit:900, fragLimit:12};
  const match = createIdentityZoneMatch({config, humanCount:2, random:seededRandom(11),
    loadouts:{0:{character:'chatgpt', harness:'openclaw'}, 1:{character:'chatgpt', harness:'openclaw'}}});
  const [west, east] = [match.actors[0], match.actors[1]];
  assert.equal(west.team, 0); assert.equal(east.team, 1);
  assert.equal(match.actors.length, 2);
  const alpha = match.objectiveState.zones[0];
  const bravo = match.objectiveState.zones[1];
  assert.equal(alpha.id, 'alpha'); assert.equal(bravo.id, 'bravo');
  const history = [];
  const record = label => history.push({label, time:match.time, zone:{...alpha},
    scores:{...match.teamScores}, stats:{0:{...west.scoreStats}, 1:{...east.scoreStats}}});
  const distance = (actor, zone) => Math.hypot(actor.x - zone.x, actor.z - zone.z);

  // 1. Team 0 walks from its authored spawn to alpha and captures it.
  const westRoute = routeBetween(arena, [west.x, west.z], [alpha.x, alpha.z]);
  const arrival = followRoute(match, 0, westRoute);
  assert.ok(arrival.arrived, 'team 0 reached alpha');
  assert.ok(distance(west, alpha) <= alpha.radius, 'team 0 inside the ring');
  assert.ok(stepUntil(match, () => alpha.owner === 0, {inputs:() => ({0:{x:0, z:0}})}) >= 0, 'team 0 captured alpha');
  assert.equal(alpha.progress, 100);
  assert.equal(alpha.contested, false);
  record('capture-team-0');
  assert.equal(alpha.owner, 0);
  assert.ok(west.scoreStats.objectiveCaptures >= 1);

  // 2. Held scoring: an uncontested friendly occupant grows the team score.
  const scoreBefore = match.teamScores[0];
  hold(match, 0, {x:0, z:0}, 120);
  assert.ok(match.teamScores[0] > scoreBefore + 1, 'held alpha bleeds team 0 score');
  assert.ok(west.scoreStats.objectiveTime >= 1);
  record('hold-team-0');

  // 3. Team 1 crosses the fold and contests alpha (both teams inside the ring).
  const eastRoute = routeBetween(arena, [east.x, east.z], [alpha.x, alpha.z]);
  followRoute(match, 1, eastRoute);
  assert.ok(distance(east, alpha) <= alpha.radius, 'team 1 inside alpha');
  assert.ok(stepUntil(match, () => alpha.contested === true, {inputs:() => ({0:{x:0, z:0}})}) >= 0, 'both teams contest alpha');
  assert.ok(east.scoreStats.objectiveContests >= 1);
  record('contested');

  // 4. Loss: team 0 leaves the ring and team 1 neutralizes then captures it.
  const westOut = routeBetween(arena, [west.x, west.z], [-16, -24]);
  followRoute(match, 0, westOut);
  assert.ok(distance(west, alpha) > alpha.radius, 'team 0 left alpha');
  assert.ok(stepUntil(match, () => alpha.owner === 1, {maxTicks:3600, inputs:() => ({1:{x:0, z:0}})}) >= 0, 'team 1 captured alpha');
  assert.equal(alpha.progress, 100);
  assert.ok(east.scoreStats.objectiveNeutralizations >= 1 || east.scoreStats.objectiveCaptures >= 1);
  record('capture-team-1'); // alpha lost by team 0

  // 5. Recovery: team 0 returns, contests the enemy owner, then re-captures
  //    the same zone after team 1 leaves for bravo.
  const westBack = routeBetween(arena, [west.x, west.z], [alpha.x, alpha.z]);
  followRoute(match, 0, westBack);
  assert.ok(distance(west, alpha) <= alpha.radius, 'team 0 re-entered alpha');
  assert.ok(stepUntil(match, () => alpha.contested === true, {inputs:() => ({1:{x:0, z:0}})}) >= 0, 'recovery contest');
  const eastBravo = routeBetween(arena, [east.x, east.z], [bravo.x, bravo.z]);
  followRoute(match, 1, eastBravo);
  assert.ok(distance(east, alpha) > alpha.radius, 'team 1 left alpha');
  const capturesBefore = west.scoreStats.objectiveCaptures;
  assert.ok(stepUntil(match, () => alpha.owner === 0, {inputs:() => ({0:{x:0, z:0}})}) >= 0, 'team 0 recovered alpha');
  assert.ok(west.scoreStats.objectiveCaptures > capturesBefore, 'recovery counted a new capture');
  record('recover-team-0');

  // 6. Score from both teams: team 1 holds bravo while team 0 keeps alpha.
  assert.ok(stepUntil(match, () => bravo.owner === 1, {inputs:() => ({1:{x:0, z:0}})}) >= 0, 'team 1 captured bravo');
  const team1Before = match.teamScores[1];
  const team0Before = match.teamScores[0];
  hold(match, 1, {x:0, z:0}, 120);
  assert.ok(match.teamScores[1] > team1Before, 'team 1 held scoring');
  assert.ok(match.teamScores[0] > team0Before, 'team 0 scored during the same window');
  assert.ok(match.teamScores[0] > 0 && match.teamScores[1] > 0, 'both teams scored');
  record('both-teams-score');

  // 7. Reach the score limit: team 1 leaves the objective and team 0 holds
  //    alpha until the source ends the round on the objective limit.
  followRoute(match, 1, [[27, -21]]);
  const approach = () => {
    const d = Math.hypot(east.x - 27, east.z + 21);
    return d > 1.5 ? controlsToward(east, [27, -21]) : {x:0, z:0};
  };
  assert.ok(stepUntil(match, () => match.over, {maxTicks:7200,
    inputs:() => ({0:{x:0, z:0}, 1:approach()})}) >= 0, 'round reached results');
  const final = match.snapshot();
  assert.equal(final.over, true);
  assert.equal(final.overReason, 'objective');
  assert.ok(final.teamScores[0] >= 12, 'results came from the score limit');
  assert.ok(final.teamScores[1] < final.teamScores[0], 'the limit decided one winner');
  assert.equal(final.winner, 0);
  assert.equal(final.objectives.winner, 0);
  record('results');

  // 8. Restart is a genuinely fresh round through the same factory.
  const restarted = createIdentityZoneMatch({config, humanCount:2, random:seededRandom(11),
    loadouts:{0:{character:'chatgpt', harness:'openclaw'}, 1:{character:'chatgpt', harness:'openclaw'}}});
  assert.equal(restarted.time, 0);
  assert.equal(restarted.over, false);
  assert.deepEqual(restarted.teamScores, {0:0, 1:0});
  assert.ok(restarted.actors.every(actor => actor.frags === 0 && actor.deaths === 0 && actor.health > 0));
  // The constructor's initial template may omit `contested`; one ticked step
  // publishes the complete source zone state.
  assert.ok(restarted.objectiveState.zones.every(zone => zone.owner === null && zone.progress === 0 && zone.contested !== true));
  restarted.step(1 / 60, {});
  assert.ok(restarted.objectiveState.zones.every(zone => zone.owner === null && zone.captureTeam === null &&
    zone.progress === 0 && zone.contested === false));
  assert.deepEqual(restarted.identityProvenance.zones, match.identityProvenance.zones);
  assert.deepEqual(restarted.identityProvenance.teamSpawns, match.identityProvenance.teamSpawns);
  console.log(JSON.stringify({gate:'identity-zone-rules', mapId:MAP, mode:'domination',
    events:history.map(item => item.label), sourceTime:final.time, finalScores:final.teamScores,
    winner:final.winner, restartClean:true, deterministicSeats:2, bots:0}));
});

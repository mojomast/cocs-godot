// Owned loopback authority acceptance for Vermilion Fold Domination.
//
// The real socket path is exercised end to end: readiness probe, protocol v3
// `nativeArenaInput` epochs, a domination-only host frame, source snapshots
// carrying the three authored zones, ordinary input driving a capture and held
// score, source results and a clean restart. Rejections pin the static
// allowlist (no client map/path/mode substitution) and the option contract.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readNativeArena} from '../../native-arenas/schema.mjs';
import {createAuthority, createIdentityZoneAuthority} from '../authority.mjs';
import {IDENTITY_ZONE_MAP_ID, identityZoneEntry} from '../catalog.mjs';
import {controlsToward, routeBetween} from '../fixtures.mjs';
import {connect, rejected} from './socket.mjs';

const MAP = IDENTITY_ZONE_MAP_ID;

test('identity zone authority rejects unsupported launch options before binding', async () => {
  assert.throws(() => createAuthority({mapId:'lacuna-court'}), /Unsupported identity zone map/);
  assert.throws(() => createAuthority({mapId:'prism-foundry'}), /Unsupported identity zone map/);
  assert.throws(() => createAuthority({mapId:MAP, mode:'deathmatch'}), /domination only/);
  assert.throws(() => createAuthority({mapId:MAP, nope:1}), /Unsupported identity zone authority option/);
  assert.throws(() => createAuthority({mapId:MAP, botCount:1, bots:2}), /Conflicting bot counts/);
  assert.throws(() => createAuthority({mapId:MAP, timeLimit:60, roundSeconds:90}), /Conflicting time limits/);
  assert.throws(() => createAuthority({mapId:MAP, arenaData:{}}), /Unsupported native arena ID/);
  await assert.rejects(createIdentityZoneAuthority({mapId:'lacuna-court'}), /Unsupported identity zone map/);
  await assert.rejects(createIdentityZoneAuthority({host:'0.0.0.0'}), /must bind loopback/);
});

test('identity zone authority: loopback readiness, allowlist rejection and full live round', {timeout:180000}, async t => {
  const data = readNativeArena(MAP);
  const authority = await createIdentityZoneAuthority({port:0, host:'127.0.0.1', mapId:MAP,
    mode:'domination', bots:2, roundSeconds:60, fragLimit:12, difficulty:'normal'});
  t.after(() => authority.close());
  assert.equal(authority.mode, 'domination');
  const ready = await (await fetch(`http://127.0.0.1:${authority.port}`)).json();
  assert.equal(ready.service, 'cocs-native-identity-zones');
  assert.equal(ready.localOnly, true);
  assert.equal(ready.humanCount, 1);
  assert.equal(ready.mapId, MAP);
  assert.equal(ready.mode, 'domination');
  assert.equal(ready.geometryHash, data.geometryHash);
  assert.equal(identityZoneEntry(MAP).path, `godot/identity_maps/generated/${MAP}.json`);

  // The allowlist refuses a client map/mode substitution and closes.
  await rejected(authority.endpoint, undefined, ws => {
    ws.send(JSON.stringify({type:'create', v:3, delta:0, nativeArenaInput:1}));
    ws.once('message', () => ws.send(JSON.stringify({type:'host', mapId:'lacuna-court',
      config:{mode:'domination', botCount:2, timeLimit:60, fragLimit:12}})));
  });
  await rejected(authority.endpoint, undefined, ws => {
    ws.send(JSON.stringify({type:'create', v:3, delta:0, nativeArenaInput:1}));
    ws.once('message', () => ws.send(JSON.stringify({type:'host', mapId:MAP,
      config:{mode:'deathmatch', botCount:2, timeLimit:60, fragLimit:12}})));
  });

  const client = await connect(authority.endpoint);
  client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
  const welcome = await client.wait(frame => frame.type === 'welcome');
  assert.equal(welcome.v, 3);
  assert.equal(welcome.nativeArenaInput, 1);
  assert.equal(welcome.humanCount, 1);
  assert.equal(welcome.geometryHash, data.geometryHash);
  await client.wait(frame => frame.type === 'lobby');
  client.send({type:'host', mapId:MAP, config:{mode:'domination', botCount:2, timeLimit:60, fragLimit:12}});
  const configured = await client.wait(frame => frame.type === 'lobby' && frame.config);
  assert.equal(configured.config.mode, 'domination');
  assert.equal(configured.config.botCount, 2);
  client.send({type:'start'});
  const started = await client.wait(frame => frame.type === 'start', {timeout:60000});
  assert.equal(started.mapId, MAP);
  assert.equal(started.mode, 'domination');
  assert.ok(Number.isInteger(started.inputEpoch) && started.inputEpoch >= 1);
  assert.equal(started.geometryHash, data.geometryHash);
  const initial = await client.wait(frame => frame.type === 'snapshot', {timeout:60000});
  assert.equal(initial.state.mapId, MAP);
  assert.equal(initial.state.config.mode, 'domination');
  assert.equal(initial.state.actors.length, 3);
  assert.equal(initial.state.actors[0].team, 0);
  assert.ok(initial.state.actors.slice(1).every(actor => actor.bot !== null));
  assert.equal(initial.state.objectives.kind, 'domination');
  assert.equal(initial.state.objectives.zones.length, 3);
  assert.equal(initial.inputEpoch, started.inputEpoch);

  // Ordinary inputs over the wire drive actor 0 to its nearest authored zone.
  let inputSeq = 0, waypoints = null, target = null, replans = 0, lastZone = null;
  const driver = bytes => {
    const frame = JSON.parse(String(bytes));
    if (frame.type !== 'snapshot' || frame.state.over || frame.inputEpoch !== started.inputEpoch) return;
    const actor = frame.state.actors.find(item => item.id === 0);
    if (!actor || actor.health <= 0) return;
    if (waypoints === null || Math.hypot(actor.x - waypoints[0][0], actor.z - waypoints[0][1]) > 6) {
      let best = null, bestDistance = Infinity;
      for (const zone of frame.state.objectives.zones) {
        const distance = Math.hypot(actor.x - zone.x, actor.z - zone.z);
        if (distance < bestDistance) { bestDistance = distance; best = zone; }
      }
      target = best;
      try {
        waypoints = routeBetween(data.arena, [actor.x, actor.z], [best.x, best.z]).map(point => [point[0], point[1]]);
      } catch {
        // A live position can sit inside the planner's clearance envelope (for
        // example at a spawn beside a block); fall back to direct steering.
        waypoints = [[best.x, best.z]];
      }
      replans++;
    }
    while (waypoints.length > 1 && Math.hypot(actor.x - waypoints[0][0], actor.z - waypoints[0][1]) < 1.2) waypoints.shift();
    const inside = Math.hypot(actor.x - target.x, actor.z - target.z) <= target.radius;
    const controls = inside ? {x:0, z:0} : controlsToward(actor, waypoints[0]);
    lastZone = frame.state.objectives.zones.find(zone => zone.id === target.id);
    client.send({type:'input', seq:++inputSeq, inputEpoch:frame.inputEpoch, input:controls});
  };
  client.ws.on('message', driver);
  const result = await client.wait(frame => frame.type === 'results', {timeout:120000});
  client.ws.off('message', driver);
  assert.equal(result.state.over, true);
  assert.equal(result.state.mapId, MAP);
  assert.ok(Number.isInteger(result.inputEpoch) && result.inputEpoch >= started.inputEpoch);
  assert.equal(result.state.objectives.zones.length, 3);

  const snapshots = client.frames.filter(frame => frame.type === 'snapshot');
  const transitions = [];
  let previous = null;
  for (const frame of snapshots) {
    for (const zone of frame.state.objectives.zones) {
      const before = previous?.find(item => item.id === zone.id);
      if (before && before.owner !== zone.owner) transitions.push({seq:frame.seq, id:zone.id, from:before.owner, to:zone.owner});
    }
    previous = frame.state.objectives.zones;
  }
  const actor = result.state.actors.find(item => item.id === 0);
  assert.ok(result.state.actors.length === 3);
  assert.ok(result.state.teamScores[0] > 0 || result.state.teamScores[1] > 0, 'source team score');
  const capturedByZero = transitions.some(item => item.to === 0);
  const contested = snapshots.some(frame => frame.state.objectives.zones.some(zone => zone.contested === true));
  assert.ok(capturedByZero || actor.scoreStats.objectiveCaptures > 0, 'a live capture was observed');
  assert.ok(snapshots.some(frame => frame.state.objectives.zones.some(zone => zone.owner === 0)) ||
    actor.scoreStats.objectiveTime >= 1, 'held objective time observed');
  const boundary = client.frames.length;
  client.send({type:'start'});
  const restarted = await client.wait(frame => frame.type === 'snapshot', {after:boundary, timeout:60000});
  assert.equal(restarted.seq, 1);
  assert.equal(restarted.state.time, 0);
  assert.equal(restarted.state.over, false);
  assert.deepEqual(restarted.state.teamScores, {0:0, 1:0});
  assert.ok(restarted.state.actors.every(item => item.frags === 0 && item.deaths === 0));
  assert.ok(restarted.state.objectives.zones.every(zone => zone.owner === null && zone.progress === 0));
  console.log(JSON.stringify({gate:'identity-zone-authority', mapId:MAP, mode:'domination',
    actors:result.state.actors.length, snapshots:snapshots.length, inputSeq, replans, contested,
    transitions:transitions.slice(0, 12), finalScores:result.state.teamScores, winner:result.state.winner,
    overReason:result.state.overReason, restartSeq:restarted.seq, geometryHash:ready.geometryHash}));
});

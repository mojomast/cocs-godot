// Explicit real generated-data gate for the three identity maps. Run after
// geometry delivery; missing or invalid assets FAIL rather than falling back.
import test from 'node:test';
import assert from 'node:assert/strict';
import {floorAt, obstructed} from '../../../game/core.mjs';
import {IDENTITY_ARENA_IDS, nativeArenaEntry} from '../catalog.mjs';
import {readNativeArena, nativeArenaGeometryHash} from '../schema.mjs';
import {createNativeMatch} from '../match.mjs';
import {createNativeArenaAuthority} from '../authority.mjs';
import {EventCursor} from '../event-cursor.mjs';
import {seededRandom, aimedControls} from './fixtures.mjs';
import {connect} from './socket-helper.mjs';

// The art lane may regenerate geometry hashes mid-flight; this gate recomputes
// the canonical hash from the delivered arena instead of pinning a digest.
for (const mapId of IDENTITY_ARENA_IDS) test(`GENERATED ${mapId}: source Deathmatch AI/combat, results and restart`, () => {
  const data = readNativeArena(mapId);
  assert.equal(data.id, mapId);
  assert.equal(data.arena.id, mapId);
  assert.equal(nativeArenaGeometryHash(data.arena), data.geometryHash);
  assert.equal(nativeArenaEntry(mapId).family, 'identity');
  assert.equal(data.palette.length, 4);
  assert.ok(data.art.length > 0);
  const match = createNativeMatch({mapId, random:seededRandom(42), config:{timeLimit:60, fragLimit:5}});
  assert.equal(match.arena.id, mapId); assert.equal(match.snapshot().mapId, mapId);
  assert.equal(match.actors.length, 4); assert.ok(match.nav.length > 0);
  for (const p of data.arena.spawns) {
    const y = floorAt(p[0], p[1], match.arena);
    assert.ok(Number.isFinite(y));
    assert.ok(match.spawns.some(s => s.x === p[0] && s.z === p[1] && Math.abs(s.y - y) < .15));
    assert.equal(obstructed(p[0], y, p[1], undefined, match.arena), false);
  }
  const cursor = new EventCursor();
  const initialEvents = cursor.take(match), events = [...initialEvents];
  assert.equal(initialEvents.filter(e => e.type === 'spawn').length, 4);
  let botMoved = false, routed = false;
  const origins = match.actors.map(a => ({x:a.x, z:a.z}));
  for (let tick = 0; tick < 61 * 60 && !match.over; tick++) {
    match.step(1 / 60, {inputs:{0:aimedControls(match)}});
    events.push(...cursor.take(match));
    botMoved ||= match.actors.slice(1).some(a => Math.hypot(a.x - origins[a.id].x, a.z - origins[a.id].z) > 3);
    routed ||= match.actors.slice(1).some(a => a.bot.route.length > 0);
  }
  assert.ok(botMoved); assert.ok(routed); assert.ok(match.actors.slice(1).some(a => a.shots > 0));
  assert.ok(events.some(e => e.type === 'damage' && e.source === 0 && e.amount > 0));
  assert.ok(events.some(e => e.type === 'death' && Number.isInteger(e.killer)));
  assert.ok(match.stats.kills > 0); assert.ok(match.actors.some(a => a.frags > 0));
  assert.ok(match.over); assert.ok(match.snapshot().leaders.length > 0);
  const restarted = createNativeMatch({mapId, random:seededRandom(42)});
  assert.equal(restarted.time, 0); assert.ok(restarted.actors.every(a => a.frags === 0 && a.deaths === 0));
  assert.equal(new EventCursor().take(restarted)[0].id, 1);
  console.log(JSON.stringify({gate:'generated-identity-source-deathmatch', mapId, mode:'deathmatch',
    geometryHash:data.geometryHash, nav:match.nav.length, time:match.time, reason:match.overReason,
    stats:match.stats, frags:match.actors.map(a => a.frags), deaths:match.actors.map(a => a.deaths),
    botMoved, routed}));
});

test('identity authority: real loopback Deathmatch, source damage/frags/results and restart', {timeout:150000}, async t => {
  const authority = await createNativeArenaAuthority({port:0, host:'127.0.0.1', mapId:'lacuna-court',
    mode:'deathmatch', bots:2, roundSeconds:60, fragLimit:5});
  t.after(() => authority.close());
  const ready = await (await fetch(`http://127.0.0.1:${authority.port}`)).json();
  assert.equal(ready.localOnly, true); assert.equal(ready.mapId, 'lacuna-court');
  assert.equal(ready.geometryHash, readNativeArena('lacuna-court').geometryHash);
  const client = await connect(authority.endpoint);
  client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
  const welcome = await client.wait(f => f.type === 'welcome');
  assert.equal(welcome.nativeArenaInput, 1);
  await client.wait(f => f.type === 'lobby');
  client.send({type:'host', mapId:'lacuna-court', config:{mode:'deathmatch', botCount:2, difficulty:'easy', timeLimit:60, fragLimit:5}});
  const configured = await client.wait(f => f.type === 'lobby' && f.config);
  assert.equal(configured.config.mode, 'deathmatch');
  client.send({type:'start'});
  const initial = await client.wait(f => f.type === 'snapshot', {timeout:60000});
  assert.equal(initial.state.mapId, 'lacuna-court');
  assert.equal(initial.state.actors.length, 3);
  let inputSeq = 0;
  const driver = bytes => {
    const frame = JSON.parse(String(bytes));
    if (frame.type === 'snapshot' && !frame.state.over) client.send({type:'input', seq:++inputSeq,
      inputEpoch:frame.inputEpoch, input:aimedControls(frame.state)});
  };
  client.ws.on('message', driver);
  const result = await client.wait(f => f.type === 'results', {timeout:90000});
  client.ws.off('message', driver);
  assert.equal(result.state.over, true);
  assert.ok(result.state.stats.shots > 0); assert.ok(result.state.stats.kills > 0);
  assert.ok(result.state.actors.some(a => a.frags > 0), 'source combat scored');
  const events = client.frames.filter(f => f.type === 'events').flatMap(f => f.items);
  assert.ok(events.some(e => e.type === 'damage' && e.amount > 0));
  assert.ok(events.some(e => e.type === 'death' && Number.isInteger(e.killer)));
  const boundary = client.frames.length;
  client.send({type:'start'});
  const restarted = await client.wait(f => f.type === 'snapshot', {after:boundary, timeout:60000});
  assert.equal(restarted.seq, 1); assert.equal(restarted.state.time, 0);
  assert.equal(restarted.state.over, false);
  assert.ok(restarted.state.actors.every(a => a.frags === 0 && a.deaths === 0));
  console.log(JSON.stringify({gate:'identity-authority-deathmatch', mapId:'lacuna-court',
    frags:result.state.actors.map(a => a.frags), shots:result.state.stats.shots, kills:result.state.stats.kills,
    restarted:true, geometryHash:ready.geometryHash}));
});

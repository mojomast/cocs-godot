// Explicit real generated-data gate. Run separately after geometry delivery;
// missing or invalid assets FAIL rather than silently falling back to fixtures.
import test from 'node:test';
import assert from 'node:assert/strict';
import {floorAt, obstructed} from '../../../game/core.mjs';
import {NATIVE_ARENA_IDS} from '../catalog.mjs';
import {readNativeArena} from '../schema.mjs';
import {createNativeMatch} from '../match.mjs';
import {EventCursor} from '../event-cursor.mjs';
import {seededRandom, aimedControls} from './fixtures.mjs';

for (const mapId of NATIVE_ARENA_IDS) test(`GENERATED ${mapId}: source constructor, AI/combat, results and restart`, () => {
  const data = readNativeArena(mapId);
  const match = createNativeMatch({mapId, random:seededRandom(42), config:{timeLimit:60, fragLimit:5}});
  assert.equal(match.arena.id, mapId); assert.equal(match.snapshot().mapId, mapId);
  assert.equal(match.actors.length, 4); assert.ok(match.nav.length > 0);
  for (const p of data.spawnPoints) {
    assert.ok(Math.abs(p.y - floorAt(p.x, p.z, match.arena)) < .15);
    assert.equal(obstructed(p.x, p.y, p.z, undefined, match.arena), false);
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
  assert.ok(events.some(e => e.type === 'damage' && e.amount > 0));
  assert.ok(events.some(e => e.type === 'death' && Number.isInteger(e.killer)));
  assert.ok(match.stats.kills > 0); assert.ok(match.actors.some(a => a.frags > 0));
  assert.ok(match.over); assert.ok(match.snapshot().leaders.length > 0);
  const restarted = createNativeMatch({mapId, random:seededRandom(42)});
  assert.equal(restarted.time, 0); assert.ok(restarted.actors.every(a => a.frags === 0 && a.deaths === 0));
  assert.equal(new EventCursor().take(restarted)[0].id, 1);
  console.log(JSON.stringify({gate:'generated-source-simulation', mapId, geometryHash:data.geometryHash,
    nav:match.nav.length, edges:match.edges.reduce((sum, e) => sum + e.length, 0),
    time:match.time, reason:match.overReason, stats:match.stats,
    frags:match.actors.map(a => a.frags), deaths:match.actors.map(a => a.deaths),
    playerDamageEvents:events.filter(e => e.type === 'damage' && e.source === 0 && e.amount > 0).length}));
});

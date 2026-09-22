// Socket-level verification of the debug channel on the REAL local Horde
// authority (source Match + source single-player waves, reviewed source map).
// The Horde route constructs a fixed reviewed config each round, so it
// advertises exactly zero construction-time debug knobs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createAuthority} from './authority.mjs';
import {WebSocket} from 'ws';

delete process.env.COCS_DEBUG;

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
function connect(endpoint) {
  const ws = new WebSocket(endpoint);
  const frames = [];
  ws.on('message', bytes => frames.push(JSON.parse(String(bytes))));
  ws.on('error', () => {});
  const waiters = new Set();
  ws.on('message', () => { for (const notify of [...waiters]) notify(); });
  return new Promise((resolve, reject) => {
    ws.once('open', () => resolve({
      ws, frames,
      send(frame) { ws.send(JSON.stringify(frame)); },
      wait(predicate, {after = 0, timeout = 15000} = {}) {
        return new Promise((done, fail) => {
          const check = () => { const frame = frames.slice(after).find(predicate); if (frame) finish(null, frame); };
          const closed = () => finish(new Error('Socket closed while waiting for frame'));
          const finish = (error, frame) => { clearTimeout(timer); waiters.delete(check); ws.off('close', closed); error ? fail(error) : done(frame); };
          const timer = setTimeout(() => finish(new Error(`Frame timeout; recent: ${frames.slice(-6).map(f => f.type)}`)), timeout);
          waiters.add(check); ws.once('close', closed); check();
        });
      },
    }));
    ws.once('error', reject);
  });
}
const latest = (client, predicate) => [...client.frames].reverse().find(predicate);
const state = client => latest(client, frame => frame.type === 'snapshot' && frame.state?.actors?.length)?.state;

async function start(client) {
  client.send({type:'create', v:3});
  await client.wait(frame => frame.type === 'welcome');
  const opening = await client.wait(frame => frame.type === 'lobby');
  client.send({type:'host', mapId:'meridian-exchange', config:{mode:'horde', fragLimit:30}});
  const configured = await client.wait(frame => frame.type === 'lobby' && frame.config);
  client.send({type:'start'});
  const initial = await client.wait(frame => frame.type === 'snapshot', {timeout:20000});
  return {opening, configured, initial};
}
async function debug(client, patch) {
  const mark = client.frames.length;
  client.send({type:'debug', v:1, ...patch});
  return client.wait(frame => frame.type === 'debug-state' || frame.type === 'debug-reject', {after:mark});
}
const eventsTo = (frames, id) => frames.filter(frame => frame.type === 'events')
  .flatMap(frame => frame.items).filter(event => event.type === 'damage' && event.actor === id);

test('solo Horde debug is off by default and refuses construction-time knobs when on', async t => {
  for (const debugOption of [false, undefined]) {
    const authority = createAuthority({debug:debugOption});
    t.after(() => authority.close());
    await new Promise(resolve => authority.server.listen(0, '127.0.0.1', resolve));
    const client = await connect(`ws://127.0.0.1:${authority.server.address().port}`);
    const {opening, configured} = await start(client);
    assert.equal(opening.debug, undefined);
    assert.equal(configured.debug, undefined);
    const closed = new Promise(resolve => client.ws.once('close', resolve));
    client.send({type:'debug', v:1, godMode:true});
    const error = await client.wait(frame => frame.type === 'error');
    assert.match(error.message, /Invalid local lifecycle command/);
    await closed;
  }
  const authority = createAuthority({debug:true});
  t.after(() => authority.close());
  await new Promise(resolve => authority.server.listen(0, '127.0.0.1', resolve));
  const client = await connect(`ws://127.0.0.1:${authority.server.address().port}`);
  const {opening} = await start(client);
  assert.equal(opening.debug.enabled, true);
  assert.deepEqual(opening.debug.restart, {}, 'no construction-time knobs on the solo route');
  for (const patch of [{botCount:4}, {startingWeapon:9}]) {
    const reply = await debug(client, patch);
    assert.equal(reply.type, 'debug-reject', JSON.stringify(patch));
    assert.match(reply.reason, /not supported on the solo Horde route/);
  }
  assert.equal((await debug(client, {damage:2})).debug.live.damage, 2);
  for (const patch of [{damage:3}, {difficulty:'impossible'}, {mapId:'prism-foundry'}, {godMode:1}]) {
    const reply = await debug(client, patch);
    assert.equal(reply.type, 'debug-reject', JSON.stringify(patch));
  }
  assert.equal((await debug(client, {})).debug.live.damage, 2, 'refusals changed nothing');
});

test('solo Horde god mode, live damage multiplier, incoming scale and unlock-all', {timeout:90000}, async t => {
  const authority = createAuthority({debug:true});
  t.after(() => authority.close());
  await new Promise(resolve => authority.server.listen(0, '127.0.0.1', resolve));
  const client = await connect(`ws://127.0.0.1:${authority.server.address().port}`);
  const {initial} = await start(client);
  assert.equal(initial.state.actors[0].id, 0);
  await sleep(1800);

  // Live damage multiplier: the self-damage damage event is an exact readout.
  const selfAmount = async (multiplier, scale) => {
    const patch = {godMode:true, damage:multiplier};
    if (scale !== undefined) patch.playerIncomingScale = scale;
    await debug(client, patch);
    const mark = client.frames.length;
    await debug(client, {testDamage:10});
    await sleep(250);
    return eventsTo(client.frames.slice(mark), 0).filter(event => event.source === undefined).map(event => event.amount);
  };
  assert.deepEqual(await selfAmount(1), [10]);
  assert.deepEqual(await selfAmount(2), [20]);
  assert.deepEqual(await selfAmount(1, .5), [5]);
  assert.deepEqual(await selfAmount(1, 2), [20]);
  await debug(client, {damage:1, playerIncomingScale:1, godMode:true});

  // God mode survives lethal damage and clears when switched off.
  const deathsBefore = state(client).actors[0].deaths;
  for (let hit = 0; hit < 2; hit++) { await debug(client, {testDamage:10000}); await sleep(220); }
  const godActor = state(client).actors[0];
  assert.equal(godActor.health, godActor.maxHealth);
  assert.equal(godActor.deaths, deathsBefore);
  await debug(client, {godMode:false});
  await debug(client, {testDamage:10000});
  await sleep(300);
  const deadActor = state(client).actors[0];
  assert.ok(deadActor.deaths > deathsBefore || deadActor.health <= 0, 'without god mode the hit is lethal');

  // Unlock-all grants every slot on the human seat.
  await debug(client, {godMode:true, unlockAllWeapons:true});
  await sleep(220);
  const unlocked = state(client).actors[0];
  assert.deepEqual(unlocked.ammo, Array.from({length:10}, () => '∞'));
  const npc = state(client).actors.find(actor => actor.isNpc === true);
  if (npc) assert.notDeepEqual(npc.ammo, Array.from({length:10}, () => '∞'), 'NPC slots are never granted');
  await debug(client, {unlockAllWeapons:false});
  await sleep(220);
  const revoked = state(client).actors[0];
  assert.equal(revoked.ammo[9], 0, 'the grant is reversible');
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {WebSocket} from 'ws';
import {createNativeArenaAuthority, outboundAllowed, LIMITS} from '../authority.mjs';
import {syntheticArena, seededRandom, aimedControls} from './fixtures.mjs';
import {connect, rejected} from './socket-helper.mjs';

const options = () => ({port:0, host:'127.0.0.1', mapId:'prism-foundry', arenaData:syntheticArena(), random:seededRandom(42)});
async function start(client, config = {}, extension = false) {
  client.send({type:'create', v:3, delta:0, ...(extension ? {nativeArenaInput:1} : {})});
  const welcome = await client.wait(f => f.type === 'welcome');
  assert.equal(welcome.peerId, 0); assert.equal(welcome.v, 3);
  const lobby = await client.wait(f => f.type === 'lobby');
  assert.equal(lobby.players[0].actorId, 0);
  client.send({type:'host', mapId:'prism-foundry', config:{mode:'deathmatch', ...config}});
  const configured = await client.wait(f => f.type === 'lobby' && f.config);
  client.send({type:'start'});
  const initial = await client.wait(f => f.type === 'snapshot');
  assert.equal(initial.state.time, 0); assert.equal(initial.state.mapId, 'prism-foundry');
  assert.equal(initial.state.actors.length, configured.config.botCount + 1);
  return initial;
}

test('SYNTHETIC loopback: ordinary v3 lifecycle, ADS true/false, FIFO ACK and stale cancellation', async t => {
  const observed = [];
  const authority = await createNativeArenaAuthority({...options(), observe:row => observed.push(row)});
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const initial = await start(client, {difficulty:'easy'});
  assert.equal(initial.state.config.timeLimit, 180); assert.equal(initial.state.config.fragLimit, 15);
  client.send({type:'input', seq:1, input:{ads:true}});
  const ads = await client.wait(f => f.type === 'snapshot' && f.acks[0] === 1);
  assert.equal(ads.state.actors[0].ads, true);
  client.send({type:'input', seq:2, input:{ads:false}});
  const released = await client.wait(f => f.type === 'snapshot' && f.acks[0] === 2);
  assert.equal(released.state.actors[0].ads, false);
  client.send({type:'input', seq:3, input:{ads:true}});
  const stale = await client.wait(f => f.type === 'native-arena-input-reset' && f.reason === 'stale-input');
  const cancelled = await client.wait(f => f.type === 'snapshot' && f.inputEpoch === stale.inputEpoch);
  assert.equal(cancelled.state.actors[0].ads, false);
  assert.equal(cancelled.nativeArenaInput.cancelledThrough, 3);
  assert.ok(observed.some(row => row.direction === 'step' && row.inputSeq === 1 && row.controls.ads === true));
  assert.ok(observed.some(row => row.direction === 'step' && row.inputSeq === 2 && row.controls.ads === false));
  // A second local human is explicitly rejected, not silently mapped to actor 0.
  await rejected(authority.endpoint);
  const closed = new Promise(resolve => client.ws.once('close', resolve));
  await authority.close(); await authority.close(); await closed;
  assert.equal(authority.server.listening, false); assert.equal(authority.wss.clients.size, 0);
  assert.notEqual(client.ws.readyState, WebSocket.OPEN);
});

test('SYNTHETIC loopback: epoch-aware cancel rejects old/death/round controls', async t => {
  const authority = await createNativeArenaAuthority(options()); t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const initial = await start(client, {difficulty:'nightmare', fragLimit:50}, true);
  client.send({type:'input', seq:1, inputEpoch:initial.inputEpoch, input:{ads:true}});
  await client.wait(f => f.type === 'snapshot' && f.acks[0] === 1);
  client.send({type:'input', seq:2, inputEpoch:initial.inputEpoch, cancel:true, input:{ads:true, fire:true}});
  const cancelled = await client.wait(f => f.type === 'snapshot' && f.acks[0] === 2);
  assert.equal(cancelled.state.actors[0].ads, false);
  const reset = await client.wait(f => f.type === 'native-arena-input-reset' && f.reason === 'stale-input');
  const oldEpochBoundary = client.frames.length;
  client.send({type:'input', seq:3, inputEpoch:initial.inputEpoch, input:{ads:true}});
  const ignored = await client.wait(f => f.type === 'snapshot' && f.inputEpoch === reset.inputEpoch, {after:oldEpochBoundary});
  assert.equal(ignored.acks[0], 2); assert.equal(ignored.state.actors[0].ads, false);
  const death = await client.wait(f => f.type === 'native-arena-input-reset' && f.reason === 'death', {timeout:30000});
  assert.ok(death.inputEpoch > reset.inputEpoch);
  const deadIndex = client.frames.length;
  client.send({type:'input', seq:4, inputEpoch:reset.inputEpoch, input:{ads:true, fire:true}});
  const respawn = await client.wait(f => f.type === 'snapshot' && f.state.actors[0].health > 0,
    {after:deadIndex, timeout:10000});
  assert.equal(respawn.state.actors[0].ads, false); assert.ok(respawn.state.actors[0].deaths > 0);
});

test('SYNTHETIC real-time loopback: source weapon damage/frags/results and clean restart', {timeout:80000}, async t => {
  const authority = await createNativeArenaAuthority(options()); t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const initial = await start(client, {difficulty:'easy', fragLimit:5, timeLimit:60}, true);
  let inputSeq = 0;
  const driver = bytes => {
    const f = JSON.parse(String(bytes));
    if (f.type === 'snapshot' && !f.state.over) client.send({type:'input', seq:++inputSeq,
      inputEpoch:f.inputEpoch, input:aimedControls(f.state)});
  };
  client.ws.on('message', driver);
  const result = await client.wait(f => f.type === 'results', {timeout:70000});
  client.ws.off('message', driver);
  assert.equal(result.state.over, true); assert.ok(result.state.actors[0].frags > 0);
  assert.ok(result.state.stats.shots > 0); assert.ok(result.state.stats.kills > 0);
  const events = client.frames.filter(f => f.type === 'events').flatMap(f => f.items);
  assert.ok(events.some(e => e.type === 'damage' && e.source === 0 && e.amount > 0));
  assert.ok(events.some(e => e.type === 'death' && e.killer === 0));
  assert.equal(new Set(events.map(e => e.id)).size, events.length);
  assert.ok(events.every(e => Number.isSafeInteger(e.id) && Object.hasOwn(e, 'sourceId')));
  const boundary = client.frames.length;
  client.send({type:'start'});
  const restarted = await client.wait(f => f.type === 'snapshot', {after:boundary});
  assert.equal(restarted.seq, 1); assert.equal(restarted.acks[0], 0);
  assert.equal(restarted.state.time, 0); assert.equal(restarted.state.over, false);
  assert.ok(restarted.state.actors.every(a => a.frags === 0 && a.deaths === 0));
  assert.ok(restarted.inputEpoch > initial.inputEpoch);
  const restartEvents = client.frames.slice(boundary).find(f => f.type === 'events').items;
  assert.equal(restartEvents[0].id, 1); assert.equal(restartEvents.length, 4);
  client.send({type:'input', seq:inputSeq + 1, inputEpoch:initial.inputEpoch, input:{ads:true, fire:true}});
  client.send({type:'input', seq:1, inputEpoch:restarted.inputEpoch, input:{ads:false}});
  const ack = await client.wait(f => f.type === 'snapshot' && f.acks[0] === 1, {after:boundary});
  assert.equal(ack.state.actors[0].ads, false);
});

test('loopback ownership and transport/envelope rejection leave no listeners', async t => {
  await assert.rejects(createNativeArenaAuthority({...options(), host:'0.0.0.0'}), /loopback/);
  const authority = await createNativeArenaAuthority(options()); t.after(() => authority.close());
  await rejected(authority.endpoint, {origin:'https://example.com'});
  await rejected(authority.endpoint + '/unknown');
  for (const frame of [{type:'create', v:2}, {type:'create', v:3, map:syntheticArena()},
    {type:'host', mapId:'prism-foundry', config:{mode:'deathmatch'}}, ['create'], null]) {
    await rejected(authority.endpoint, undefined, ws => ws.send(JSON.stringify(frame)));
  }
  await rejected(authority.endpoint, undefined, ws => ws.send(Buffer.from('binary')));
  await rejected(authority.endpoint, undefined, ws => ws.send('x'.repeat(LIMITS.payload + 1)));
  await rejected(authority.endpoint, undefined, ws => {
    ws.send(JSON.stringify({type:'create', v:3}));
    ws.send(JSON.stringify({type:'host', mapId:'../prism-foundry', config:{mode:'deathmatch'}}));
  });
  await rejected(authority.endpoint, undefined, ws => {
    ws.send(JSON.stringify({type:'create', v:3}));
    for (let i = 0; i < LIMITS.burst + 2; i++) ws.send(JSON.stringify({type:'ping'}));
  });
  assert.equal(outboundAllowed(LIMITS.frame + 1, 0), false);
  assert.equal(outboundAllowed(1, LIMITS.outbound), false);
  // A fresh ordinary client can reconnect after every rejected owned socket.
  const fresh = await connect(authority.endpoint); await start(fresh);
  await authority.close(); assert.equal(authority.wss.clients.size, 0); assert.equal(authority.server.listening, false);
});
test('launcher aliases mode/bots/roundSeconds and HTTP readiness use the delivered interface', async t => {
  const authority = await createNativeArenaAuthority({...options(), mode:'deathmatch', bots:2, roundSeconds:180});
  t.after(() => authority.close());
  const ready = await (await fetch(`http://127.0.0.1:${authority.port}`)).json();
  assert.equal(ready.localOnly, true); assert.equal(ready.port, authority.port);
  const client = await connect(authority.endpoint), initial = await start(client);
  assert.equal(initial.state.config.botCount, 2); assert.equal(initial.state.config.timeLimit, 180);
  await assert.rejects(createNativeArenaAuthority({...options(), mode:'horde'}), /deathmatch/);
  await assert.rejects(createNativeArenaAuthority({...options(), bots:null}), /botCount/);
  await assert.rejects(createNativeArenaAuthority({...options(), roundSeconds:null}), /timeLimit/);
});

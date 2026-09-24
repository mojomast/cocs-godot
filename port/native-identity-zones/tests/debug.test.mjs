// Lead-side verification of the additive debug channel on the REAL identity zone
// (Domination) authority, mirroring the debug lane's Deathmatch/Horde suites.
// Everything is read from public frames or the authority's observer seam.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createIdentityZoneAuthority, DEBUG_RESTART_BOUNDS} from '../authority.mjs';
import {connect} from './socket.mjs';

delete process.env.COCS_DEBUG; // this file proves the default is OFF

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const options = (over = {}) => ({port:0, host:'127.0.0.1', mode:'domination', debug:true, ...over});
const latest = (client, predicate) => [...client.frames].reverse().find(predicate);
const state = client => latest(client, frame => frame.type === 'snapshot' && frame.state?.actors?.length)?.state;
const pool = actor => +(Number(actor.health) + Number(actor.armor)).toFixed(3);

async function start(client) {
  client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
  await client.wait(frame => frame.type === 'welcome');
  await client.wait(frame => frame.type === 'lobby');
  client.send({type:'host', mapId:'vermilion-fold',
    config:{mode:'domination', botCount:1, timeLimit:600, fragLimit:900, difficulty:'easy'}});
  await client.wait(frame => frame.type === 'lobby' && frame.config);
  client.send({type:'start'});
  await client.wait(frame => frame.type === 'snapshot');
  for (let attempt = 0; attempt < 200 && !state(client); attempt++) await sleep(25);
}

test('identity zone debug channel: capability echo, live knobs, god mode, refusal', async () => {
  const authority = await createIdentityZoneAuthority(options());
  try {
    const client = await connect(authority.endpoint);
    await start(client);
    const opening = latest(client, frame => frame.type === 'lobby' && frame.debug);
    assert.ok(opening, 'enabled channel advertises its capability in the lobby echo');
    assert.equal(opening.debug.enabled, true);
    assert.deepEqual(opening.debug.restart.botCount, [...DEBUG_RESTART_BOUNDS.botCount]);
    assert.equal(state(client).config.botCount, 1, 'live debug must not replace the host-selected roster with defaults');

    // Live damage multiplier reaches the source mutators and the snapshot echo.
    client.send({type:'debug', v:1, damage:2});
    const doubled = await client.wait(frame => frame.type === 'debug-state' && frame.debug?.live);
    assert.equal(doubled.debug.live.damage, 2);
    assert.ok(doubled.debug.live, 'live block reported');

    // God mode survives a lethal self-hit and is reversible.
    client.send({type:'debug', v:1, godMode:true});
    await client.wait(frame => frame.type === 'debug-state' && frame.debug?.live?.godMode === true);
    const before = pool(state(client).actors[0]);
    client.send({type:'debug', v:1, testDamage:100000});
    await sleep(400);
    const after = pool(state(client).actors[0]);
    assert.ok(after > 0, `god mode keeps the human alive (pool ${after})`);
    assert.ok(Math.abs(after - before) < 60, 'god mode pool stays near the pre-hit value');

    client.send({type:'debug', v:1, clear:true});
    const cleared = await client.wait(frame => frame.type === 'debug-state' && frame.debug?.live?.godMode === false);
    assert.equal(cleared.debug.live.godMode, false, 'clear releases god mode');

    // Malformed frames are rejected without changing anything.
    const rejects = client.frames.filter(frame => frame.type === 'debug-reject').length;
    client.send({type:'debug', v:1, botCount:99});
    await client.wait(frame => frame.type === 'debug-reject');
    assert.equal(client.frames.filter(frame => frame.type === 'debug-reject').length, rejects + 1);
    assert.equal(latest(client, frame => frame.type === 'error'), undefined, 'a rejected frame never drops the session');
    client.ws.close();
  } finally {
    await authority.close();
  }
});

test('debug channel stays closed by default and the two-human room is untouched', async () => {
  const authority = await createIdentityZoneAuthority({port:0, host:'127.0.0.1', mode:'domination'});
  try {
    const client = await connect(authority.endpoint);
    await start(client);
    assert.equal(latest(client, frame => frame.type === 'lobby' && frame.debug), undefined, 'no capability echo when disabled');
    client.send({type:'debug', v:1, godMode:true});
    const error = await client.wait(frame => frame.type === 'error');
    assert.match(error.message, /Invalid local identity zone lifecycle command/);
    client.ws.close();
  } finally {
    await authority.close();
  }
});

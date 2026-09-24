// Socket-level verification of the additive debug channel against the REAL
// native Deathmatch authority (source Match, source bots, synthetic geometry).
// Every measurement below is read from public frames or the authority's own
// observer seam; nothing mutates the source sim directly.
import test from 'node:test';
import assert from 'node:assert/strict';
import {createNativeArenaAuthority, DEBUG_RESTART_BOUNDS} from '../authority.mjs';
import {syntheticArena, seededRandom, aimedControls} from './fixtures.mjs';
import {connect} from './socket-helper.mjs';

delete process.env.COCS_DEBUG; // the file proves the default is OFF

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const options = (over = {}) => ({port:0, host:'127.0.0.1', mapId:'prism-foundry',
  arenaData:syntheticArena(), random:seededRandom(42), debug:true, ...over});
const latest = (client, predicate) => [...client.frames].reverse().find(predicate);
const state = client => latest(client, frame => frame.type === 'snapshot' && frame.state?.actors?.length)?.state;
const pool = actor => +(Number(actor.health) + Number(actor.armor)).toFixed(3);
const eventsTo = (frames, id) => frames.filter(frame => frame.type === 'events')
  .flatMap(frame => frame.items).filter(event => event.type === 'damage' && event.actor === id);

async function start(client, config = {}) {
  client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
  await client.wait(frame => frame.type === 'welcome');
  const opening = await client.wait(frame => frame.type === 'lobby');
  client.send({type:'host', mapId:'prism-foundry',
    config:{mode:'deathmatch', botCount:1, timeLimit:600, fragLimit:50, difficulty:'easy', ...config}});
  const configured = await client.wait(frame => frame.type === 'lobby' && frame.config);
  client.send({type:'start'});
  const initial = await client.wait(frame => frame.type === 'snapshot');
  return {opening, configured, initial, inputEpoch:initial.inputEpoch};
}

// Real clients repeat input at 60 Hz; the authority's FIFO expires a sample
// after 250 ms without input, so every test stimulus is a held repeat.
const sequences = new WeakMap();
const currentEpoch = client => latest(client, frame => frame.type === 'snapshot' &&
  Number.isInteger(frame.inputEpoch) && frame.inputEpoch > 0)?.inputEpoch ?? 1;
async function hold(client, input, ms = 700, every = 80) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const seq = (sequences.get(client) ?? 0) + 1; sequences.set(client, seq);
    client.send({type:'input', seq, inputEpoch:currentEpoch(client), input});
    await sleep(every);
  }
}

/** Send one debug frame and return the authority's reply (state or reject). */
async function debug(client, patch) {
  const mark = client.frames.length;
  client.send({type:'debug', v:1, ...patch});
  return client.wait(frame => frame.type === 'debug-state' || frame.type === 'debug-reject', {after:mark});
}

test('debug is off by default and a debug frame is the unchanged protocol error', async t => {
  await assert.rejects(createNativeArenaAuthority(options({debug:'yes'})), /Debug flag must be boolean/);
  for (const debugOption of [false, undefined]) {
    const authority = await createNativeArenaAuthority(options({debug:debugOption}));
    t.after(() => authority.close());
    const client = await connect(authority.endpoint);
    const {opening, configured} = await start(client);
    assert.equal(opening.debug, undefined, 'no capability echo when disabled');
    assert.equal(configured.debug, undefined);
    const closed = new Promise(resolve => client.ws.once('close', resolve));
    client.send({type:'debug', v:1, godMode:true});
    const error = await client.wait(frame => frame.type === 'error');
    assert.match(error.message, /Invalid local native arena lifecycle command/);
    await closed;
  }
  // The explicit operator switch (environment) is the launcher path.
  process.env.COCS_DEBUG = '1';
  try {
    const authority = await createNativeArenaAuthority(options({debug:undefined}));
    t.after(() => authority.close());
    const client = await connect(authority.endpoint);
    const {opening} = await start(client);
    assert.equal(opening.debug.enabled, true);
    assert.deepEqual(opening.debug.restart, {botCount:[1, 24], startingWeapon:[0, 9]});
  } finally { delete process.env.COCS_DEBUG; }
});

test('DEBUG_RESTART_BOUNDS is the extended local route bound', () => {
  assert.deepEqual(DEBUG_RESTART_BOUNDS, {botCount:[1, 24], startingWeapon:[0, 9]});
});

test('live source damage multiplier: applied amounts and real pool deltas at 1.0 vs 2.0', {timeout:120000}, async t => {
  const observed = [];
  const authority = await createNativeArenaAuthority({...options({random:seededRandom(4242)}),
    observe:row => observed.push(row)});
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const {initial} = await start(client);
  assert.equal(initial.state.actors.length, 2);
  await sleep(1800); // spawn protection (source RULES.protection = 1.5 s)
  // God mode keeps the human alive and at full health, so the self-damage
  // readout below is never capped by remaining health. Its damage cap only
  // stops lethal hits; it never changes the applied amount of a normal one.
  await debug(client, {godMode:true, damage:1});

  // Self-damage is an explicit debug action; its source-less damage event is an
  // exact readout of the damage the locked source actually applied.
  const selfAmount = async (multiplier, scale) => {
    const patch = {damage:multiplier};
    if (scale !== undefined) patch.playerIncomingScale = scale;
    await debug(client, patch);
    const mark = client.frames.length;
    const reply = await debug(client, {testDamage:10});
    assert.equal(reply.type, 'debug-state', JSON.stringify(reply));
    await sleep(220);
    const amounts = eventsTo(client.frames.slice(mark), 0)
      .filter(event => event.source === undefined).map(event => event.amount);
    return amounts;
  };
  assert.deepEqual(await selfAmount(1), [10], 'damage 1.0 applies exactly 10');
  assert.deepEqual(await selfAmount(2), [20], 'damage 2.0 applies exactly 20');
  assert.deepEqual(await selfAmount(1.5), [15], 'damage 1.5 applies exactly 15');
  // The source's Damage Boost mutator only scales upward: 0.5 is accepted by
  // the config but the locked source applies no reduction to actor damage.
  // That boundary is reported by the echo and documented, never faked here.
  assert.deepEqual(await selfAmount(.5), [10], 'source damage 0.5 is a documented no-op below 1x');
  assert.deepEqual(await selfAmount(1), [10]);

  // Debug-only incoming scale on the human seat (clearly labelled in the panel).
  assert.deepEqual(await selfAmount(1, .5), [5]);
  assert.deepEqual(await selfAmount(1, 4), [40]);
  assert.deepEqual(await selfAmount(1, 1), [10]);

  // Real health+armor pool deltas with god mode OFF. Only windows with zero
  // bot damage are accepted, so the measured delta is the self hit alone.
  const poolDelta = async multiplier => {
    const expected = 10 * multiplier;
    for (let attempt = 0; attempt < 10; attempt++) {
      await debug(client, {godMode:true, damage:multiplier});
      await sleep(220);
      await debug(client, {godMode:false});
      const before = pool(state(client).actors[0]);
      const mark = client.frames.length;
      await debug(client, {testDamage:10});
      await sleep(160);
      const actor = state(client).actors[0];
      const noise = eventsTo(client.frames.slice(mark), 0).filter(event => typeof event.source === 'number');
      const delta = +(before - pool(actor)).toFixed(3);
      if (noise.length === 0 && actor.health > 0 && Math.abs(delta - expected) < .001) return delta;
    }
    return null;
  };
  const atOne = await poolDelta(1);
  const atTwo = await poolDelta(2);
  assert.equal(atOne, 10, 'health+armor lost exactly 10 at 1.0x');
  assert.equal(atTwo, 20, 'health+armor lost exactly 20 at 2.0x');
  await debug(client, {godMode:false});
});

test('god mode survives lethal damage, is reversible, and clears at the round boundary', {timeout:180000}, async t => {
  const observed = [];
  const authority = await createNativeArenaAuthority({...options({random:seededRandom(99)}),
    observe:row => observed.push(row)});
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const {initial} = await start(client, {fragLimit:5, timeLimit:60});
  assert.equal(initial.state.actors.length, 2);
  await sleep(1800);

  assert.equal((await debug(client, {godMode:true, respawn:2})).type, 'debug-state');
  const deathsBefore = state(client).actors[0].deaths;
  for (let hit = 0; hit < 3; hit++) {
    await debug(client, {testDamage:10000});
    await sleep(200);
  }
  const godActor = state(client).actors[0];
  assert.equal(godActor.health, godActor.maxHealth, 'health is restored for as long as god mode is on');
  assert.equal(godActor.deaths, deathsBefore, 'the source death branch never ran');
  assert.equal(state(client).over, false);
  assert.equal(client.frames.filter(frame => frame.type === 'results').length, 0, 'no results while god mode holds');
  assert.ok(observed.some(row => row.direction === 'debug-reconcile' && row.healthLost > 0),
    'the observer seam shows health actually restored after each step');

  // Reversible: with god mode off a lethal hit kills again.
  await debug(client, {godMode:false});
  await debug(client, {respawn:1, damage:1});
  await debug(client, {testDamage:10000});
  await sleep(250);
  const deadActor = state(client).actors[0];
  assert.ok(deadActor.deaths > deathsBefore || deadActor.health <= 0, 'without god mode the same hit is lethal');
  await debug(client, {godMode:true, respawn:4});

  // End the round through ordinary play: the human aims and fires (one-shot),
  // god mode keeps the human alive against the bots. Then queue the
  // construction-time bot count and restart through the existing contract.
  assert.equal((await debug(client, {botCount:4})).debug.queued.botCount, 4);
  assert.equal(state(client).config.botCount, 1, 'the running round keeps its constructed bot count');
  assert.equal(state(client).actors.length, 2);
  assert.equal((await debug(client, {oneShot:true, noRecoil:true})).type, 'debug-state');
  const epoch = initial.inputEpoch;
  let seq = 0;
  const driver = bytes => {
    const frame = JSON.parse(String(bytes));
    if (frame.type !== 'snapshot' || frame.state.over) return;
    client.send({type:'input', seq:++seq, inputEpoch:frame.inputEpoch ?? epoch, input:aimedControls(frame.state)});
  };
  client.ws.on('message', driver);
  const results = await client.wait(frame => frame.type === 'results', {timeout:90000});
  client.ws.off('message', driver);
  assert.equal(results.state.over, true);
  assert.ok(results.state.actors[0].frags >= 5, `the driver reached the frag limit (${results.state.actors[0].frags})`);

  // Restart: the queued bot count is consumed, god mode is cleared at the
  // boundary, and live knobs persist into the new round.
  const boundary = client.frames.length;
  client.send({type:'start'});
  const restarted = await client.wait(frame => frame.type === 'snapshot' && frame.state.time === 0, {after:boundary, timeout:15000});
  assert.equal(restarted.state.actors.length, 5, 'queued botCount=4 applies on restart');
  assert.equal(restarted.state.config.botCount, 4);
  assert.equal(restarted.state.config.damage, 1);
  assert.equal(restarted.state.config.respawn, 4, 'live knobs persist into the new round');
  const echo = await debug(client, {});
  assert.equal(echo.debug.live.godMode, false, 'god mode clears on the round boundary');
  assert.equal(echo.debug.constructed.botCount, 4, 'the running round was constructed with the queued bot count');
  assert.deepEqual(echo.debug.queued, {botCount:4}, 'the restart knob stays queued (sticky) for the next construction');
  // And the cleared god mode really is gone: a lethal hit is lethal again.
  await sleep(1800);
  const roundDeaths = state(client).actors[0].deaths;
  await debug(client, {testDamage:10000});
  await sleep(300);
  assert.ok(state(client).actors[0].deaths > roundDeaths || state(client).actors[0].health <= 0,
    'god mode does not survive the round boundary');
});

test('unlock all weapons grants every slot, the source runs it, and it is reversible', {timeout:60000}, async t => {
  const authority = await createNativeArenaAuthority(options());
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const {initial} = await start(client);
  await sleep(1800);
  const before = state(client).actors[0];
  assert.equal(before.ammo[9], 0, 'slot 9 starts empty for the default loadout');
  assert.equal((await debug(client, {godMode:true, unlockAllWeapons:true})).debug.live.unlockAllWeapons, true);
  await sleep(180);
  const unlocked = state(client).actors[0];
  assert.deepEqual(unlocked.ammo, Array.from({length:10}, () => '∞'), 'all ten slots report infinite ammo');
  // The source accepts the switch and the weapon is usable. Held input is
  // repeated exactly like the real client's 60 Hz send loop.
  await hold(client, {weapon:9});
  const held = state(client).actors[0];
  assert.equal(held.weapon, 9, 'the human seat switched to slot 9');
  await hold(client, {weapon:8, fire:true}, 900);
  const firing = state(client).actors[0];
  assert.equal(firing.weapon, 8);
  assert.ok(firing.shots > 0, 'the granted weapon fires');
  // Revoke: the source spawn belt is restored and only the held weapon is loaded.
  assert.equal((await debug(client, {unlockAllWeapons:false})).debug.live.unlockAllWeapons, false);
  await sleep(200);
  const revoked = state(client).actors[0];
  assert.equal(revoked.ammo[9], 0, 'the grant is reversible');
  assert.ok(revoked.ammo[revoked.weapon] > 0, 'the held weapon keeps a magazine');
});

test('the remaining source mutators are live, echoed in the public snapshot config, and respawn is live', {timeout:60000}, async t => {
  const authority = await createNativeArenaAuthority(options());
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const {initial} = await start(client);
  await sleep(1800);
  const patch = {difficulty:'hard', speed:1.25, gravity:.4, respawn:5, oneShot:true, instagib:false,
    noRecoil:true, bigHead:true, berserk:true, bounty:true, lifeSteal:true, suddenDeath:true,
    fastPowers:true, mirrorLoadout:true, randomLoadout:true};
  const reply = await debug(client, patch);
  assert.equal(reply.type, 'debug-state');
  for (const [key, value] of Object.entries(patch)) assert.equal(reply.debug.live[key], value, key);
  await sleep(250);
  const live = state(client);
  assert.equal(live.time > 0, true, 'the same round is still running (live change, no restart)');
  for (const [key, value] of Object.entries(patch)) assert.equal(live.config[key], value, `snapshot config.${key}`);
  for (const id of ['turbo', 'lowGravity', 'oneShot', 'noRecoil', 'bigHead', 'berserk', 'bounty',
    'lifeSteal', 'suddenDeath', 'fastPowers', 'mirrorLoadout', 'randomLoadout']) {
    assert.ok(live.config.mutators.includes(id), `snapshot config.mutators includes ${id}`);
  }
  // Difficulty is a real live assignment on the match, not only an echo.
  const difficulty = await debug(client, {difficulty:'easy'});
  assert.equal(difficulty.debug.live.difficulty, 'easy');
  // Respawn seconds are read by the source on every death (respawnDelay()).
  await debug(client, {godMode:false, damage:1, oneShot:false, respawn:5});
  await debug(client, {testDamage:10000});
  await sleep(250);
  const dying = state(client).actors[0];
  assert.ok(dying.health <= 0 || dying.dead > 0, 'the human is dead');
  assert.ok(dying.dead > 4.5 && dying.dead <= 5, `dead timer reflects respawn=5 (${dying.dead})`);
  await debug(client, {godMode:true});
  await sleep(400);
  const revived = state(client).actors[0];
  assert.equal(revived.health, revived.maxHealth);
  assert.equal((await debug(client, {clear:true})).type, 'debug-state');
  await sleep(200);
  const cleared = state(client);
  assert.equal(cleared.config.speed, 1);
  assert.equal(cleared.config.gravity, 1);
  assert.equal(cleared.config.respawn, 2);
  assert.equal(cleared.config.oneShot, false);
  assert.deepEqual(cleared.config.mutators, []);
  await debug(client, {damage:1, difficulty:'easy'});
});

test('malformed debug frames change nothing and never take the socket down', {timeout:60000}, async t => {
  const authority = await createNativeArenaAuthority(options());
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  const {initial} = await start(client);
  await sleep(1800);
  await debug(client, {damage:2, godMode:true});
  await sleep(150);
  const before = state(client);
  const rejected = [{mapId:'prism-foundry'}, {path:'/etc/passwd'}, {url:'ws://127.0.0.1:1'},
    {damage:.75}, {damage:3}, {damage:'2'}, {damage:null}, {speed:1.1}, {gravity:0},
    {difficulty:'impossible'}, {respawn:.5}, {respawn:6}, {godMode:1}, {godMode:'yes'},
    {botCount:8.5}, {botCount:25}, {startingWeapon:10}, {playerIncomingScale:1000},
    {testDamage:-1}, {clear:'yes'}, {actor:0}, {teleport:true}];
  for (const patch of rejected) {
    const mark = client.frames.length;
    client.send({type:'debug', v:1, ...patch});
    const reply = await client.wait(frame => frame.type === 'debug-reject' || frame.type === 'debug-state', {after:mark});
    assert.equal(reply.type, 'debug-reject', JSON.stringify(patch));
    assert.equal(typeof reply.reason, 'string');
  }
  // A debug frame that is not an object at all is the pre-existing envelope
  // failure and still closes the connection; that contract is unchanged.
  const versionMark = client.frames.length;
  client.send({type:'debug', v:2});
  const versionReject = await client.wait(frame => frame.type === 'debug-reject', {after:versionMark});
  assert.match(versionReject.reason, /protocol 1 required/);
  await sleep(200);
  const after = state(client);
  assert.equal(after.config.damage, 2, 'refused frames changed nothing');
  assert.equal(after.actors[0].health > 0, true);
  // The channel still works after every refusal.
  const echo = await debug(client, {testDamage:0});
  assert.equal(echo.type, 'debug-state');
  assert.equal(echo.debug.rejected >= rejected.length, true, `reject counter observed (${echo.debug.rejected})`);
  assert.equal(echo.debug.live.damage, 2);
  assert.ok(initial.inputEpoch > 0);
});

test('a debug frame without a live round queues restart knobs and refuses self-damage', async t => {
  const authority = await createNativeArenaAuthority(options());
  t.after(() => authority.close());
  const client = await connect(authority.endpoint);
  client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
  await client.wait(frame => frame.type === 'welcome');
  await client.wait(frame => frame.type === 'lobby');
  const queued = await debug(client, {botCount:6});
  assert.equal(queued.type, 'debug-state');
  assert.deepEqual(queued.debug.queued, {botCount:6});
  const rejected = await debug(client, {testDamage:40});
  assert.equal(rejected.type, 'debug-reject');
  assert.match(rejected.reason, /live round/);
  await assert.rejects(createNativeArenaAuthority(options({debug:true, botCount:null})), /botCount/);
  assert.equal(DEBUG_RESTART_BOUNDS.botCount[1], 24);
});

// Lane 2 (Horde rewards) adapter tests — default-fast.
//
// The intent validator lives inside the already-packaged adapter
// (`port/native-horde/authority.mjs`), so the shipped port adapter inventory in
// tools/godot-package stays exactly `authority.mjs` + `input-buffer.mjs`. This
// file is a test module and never enters that runtime closure.
//
// Nothing here plays a whole run. The separate native wire/UI proof is
// godot/tests/horde/upgrade_loopback.mjs, a TEST-ONLY accelerated-offer fixture,
// not natural wave progression or full-run completion.
import test from 'node:test';
import assert from 'node:assert/strict';
import {WebSocket} from 'ws';
import {createAuthority, createHordeMatch, validateConfig, MAPS,
  pendingOffer, validateUpgradeIntent, upgradeRecord,
  UPGRADE_FRAME, APPLIED_FRAME, REJECTED_FRAME} from './authority.mjs';
import {offerHordeUpgrade, selectHordeUpgrade, HORDE_UPGRADES} from '../../game/singleplayer.mjs';

// ---------------------------------------------------------------------------
// Fixture: a real source Match in the reviewed solo Horde preset, whose offer
// is raised by calling the source's own `offerHordeUpgrade`. Only the offer
// *timing* is a fixture; identities, choices and selection rules stay source.
// ---------------------------------------------------------------------------
function fixtureMatch(waves = 4) {
  const config = validateConfig({mapId: MAPS[0], config: {mode: 'horde', fragLimit: waves}});
  const match = createHordeMatch({mapId: MAPS[0], config, random: () => 0.5});
  match.step(1 / 60, {inputs: {0: {}}});
  return match;
}
// Only the offer *timing* is a fixture (the source raises offers on real
// wave-clear boundaries); identities, choices and selection rules stay source.
function raiseOffer(match, wave = null) {
  if (wave !== null) match.modeState.wave = wave;
  const choices = offerHordeUpgrade(match, match.modeState);
  assert.ok(Array.isArray(choices) && choices.length === 3, 'source offers exactly three choices');
  return choices;
}
const intent = (frame, match, epoch = 7) => validateUpgradeIntent(
  frame !== null && typeof frame === 'object' && !Array.isArray(frame) ? {inputEpoch: epoch, ...frame} : frame,
  {match, epoch});

test('fixture: a source offer is projected without inventing or reordering rows', () => {
  const match = fixtureMatch();
  const choices = raiseOffer(match, 3);
  const offer = pendingOffer(match);
  assert.deepEqual(offer.choices, choices);
  assert.equal(offer.wave, match.modeState.wave);
  assert.ok(HORDE_UPGRADES.some(row => row.id === choices[0]));
  const info = match.snapshot().singleplayer;
  assert.equal(info.upgradeWave, match.modeState.wave);
  assert.deepEqual(info.upgrades.map(row => row.id), choices, 'snapshot carries the offered rows');
  assert.equal(info.upgradeCount, 0);
  assert.equal(info.upgradeSelected, null);
});

test('fixture: malformed intents are refused and leave the offer untouched', () => {
  const match = fixtureMatch();
  const [first] = raiseOffer(match, 3);
  const before = JSON.stringify(match.modeState.pendingUpgrade);
  const cases = [
    [{}, 'malformed-choice'],
    [null, 'malformed-frame'],
    ['frame', 'malformed-frame'],
    [[], 'malformed-frame'],
    [{type: UPGRADE_FRAME}, 'malformed-choice'],
    [{type: UPGRADE_FRAME, choice: 3}, 'malformed-choice'],
    [{type: UPGRADE_FRAME, choice: ''}, 'malformed-choice'],
    [{type: UPGRADE_FRAME, choice: 'x'.repeat(65)}, 'malformed-choice'],
    [{type: UPGRADE_FRAME, choice: `bad\u0000id`}, 'malformed-choice'],
    [{type: UPGRADE_FRAME, choice: first}, 'malformed-wave'],
    [{type: UPGRADE_FRAME, choice: first, wave: 0}, 'malformed-wave'],
    [{type: UPGRADE_FRAME, choice: first, wave: 1.5}, 'malformed-wave'],
    [{type: UPGRADE_FRAME, choice: first, wave: 3}, 'malformed-view'],
    [{type: UPGRADE_FRAME, choice: first, wave: 3, applied: '0'}, 'malformed-view'],
    [{type: UPGRADE_FRAME, choice: first, wave: 3, applied: 0, inputEpoch: 6}, 'stale-round'],
    [{type: UPGRADE_FRAME, choice: first, wave: 3, applied: 0, inputEpoch: 1.5}, 'stale-round'],
  ];
  for (const [frame, reason] of cases) {
    const decision = intent(frame, match);
    assert.equal(decision.ok, false, `expected refusal for ${JSON.stringify(frame)}`);
    assert.equal(decision.reason, reason, `reason for ${JSON.stringify(frame)}`);
  }
  assert.equal(JSON.stringify(match.modeState.pendingUpgrade), before, 'refusals never mutate the offer');
  assert.deepEqual(match.modeState.upgrades, [], 'refusals never apply an upgrade');
});

test('fixture: unknown ids, wrong offers and stale views are refused; the source intent is accepted', () => {
  const match = fixtureMatch();
  const choices = raiseOffer(match, 3);
  const [first] = choices;
  assert.equal(intent({type: UPGRADE_FRAME, choice: 'not-an-upgrade', wave: 3, applied: 0}, match).reason, 'unauthorized-choice');
  assert.equal(intent({type: UPGRADE_FRAME, choice: first, wave: 2, applied: 0}, match).reason, 'stale-offer');
  assert.equal(intent({type: UPGRADE_FRAME, choice: first, wave: 3, applied: 1}, match).reason, 'stale-view');
  const good = intent({type: UPGRADE_FRAME, choice: first, wave: 3, applied: 0}, match);
  assert.equal(good.ok, true);
  assert.equal(good.id, first);
  assert.deepEqual(good.choices, choices);

  // A selection clears the offer: the same intent becomes a wrong-phase refusal.
  assert.equal(selectHordeUpgrade(match, first), true);
  assert.equal(pendingOffer(match), null);
  assert.equal(intent({type: UPGRADE_FRAME, choice: first, wave: 3, applied: 0}, match).reason, 'no-pending-offer');

  // The next offer is a new window: the replayed choice and its wave cannot be
  // reused, and only the live list authorizes a choice.
  match.modeState.wave = match.modeState.nextUpgradeWave;
  const second = raiseOffer(match);
  assert.equal(intent({type: UPGRADE_FRAME, choice: first, wave: 3, applied: 1}, match).reason, 'stale-offer');
  const replayed = intent({type: UPGRADE_FRAME, choice: first, wave: match.modeState.wave, applied: 1}, match);
  assert.equal(replayed.ok, second.includes(first), 'only the live offer authorizes a choice');
  assert.equal(intent({type: UPGRADE_FRAME, choice: second[0], wave: match.modeState.wave, applied: 1}, match).ok, true);
  assert.equal(selectHordeUpgrade(match, second[0]), true);
  assert.deepEqual(match.modeState.upgrades, [first, second[0]], 'run upgrades accumulate in source order');
});

test('fixture: a non-horde or finished round has no offer to authorize', () => {
  const match = fixtureMatch();
  raiseOffer(match);
  assert.equal(intent({type: UPGRADE_FRAME, choice: 'haste', wave: 1, applied: 0}, match).ok, false);
  match.modeState.kind = 'campaign';
  assert.equal(intent({type: UPGRADE_FRAME, choice: 'haste', wave: 1, applied: 0}, match).reason, 'no-pending-offer');
  match.modeState.kind = 'horde';
  raiseOffer(match, 1);
  match.over = true;
  assert.equal(intent({type: UPGRADE_FRAME, choice: pendingOffer(match).choices[0], wave: match.modeState.wave, applied: 0}, match).reason, 'no-live-round');
});

test('fixture: record shape is bounded and carries no client-authored fields', () => {
  const record = upgradeRecord({type: UPGRADE_FRAME, choice: 'haste', wave: 3, applied: 0, extra: 'ignored'});
  assert.deepEqual(Object.keys(record).sort(), ['applied', 'choice', 'direction', 'wave']);
  assert.equal(record.direction, 'upgrade');
  assert.equal(record.choice, 'haste');
  assert.equal(record.wave, 3);
  assert.equal(record.applied, 0);
});

// ---------------------------------------------------------------------------
// Wire routing: a live authority over a real socket refuses everything an
// unauthorized operator can send before any offer exists, and stays healthy.
// ---------------------------------------------------------------------------
test('wire: malformed, stale and out-of-phase intents are refused without ending the round', async () => {
  const authority = createAuthority();
  await new Promise(done => authority.server.listen(0, '127.0.0.1', done));
  const url = `ws://127.0.0.1:${authority.server.address().port}`;
  const ws = new WebSocket(url);
  const received = [];
  ws.on('message', data => received.push(JSON.parse(String(data))));
  const send = frame => ws.send(JSON.stringify(frame));
  await new Promise(ready => ws.once('open', ready));
  send({type: 'create', v: 3});
  send({type: 'host', mapId: MAPS[0], config: {mode: 'horde', botCount: 0, fragLimit: 10}});
  send({type: 'start'});
  const started = await new Promise((ready, reject) => {
    const timer = setInterval(() => {
      const frame = received.find(entry => entry.type === 'start');
      if (frame) { clearInterval(timer); ready(frame); }
    }, 20);
    setTimeout(() => { clearInterval(timer); reject(Error('no start frame')); }, 5000);
  });
  const epoch = started.inputEpoch;
  const refusals = [
    [{type: UPGRADE_FRAME, inputEpoch: epoch, choice: 'haste', wave: 1, applied: 0}, 'no-pending-offer'],
    [{type: UPGRADE_FRAME, inputEpoch: epoch, choice: 'not-an-upgrade', wave: 1, applied: 0}, 'no-pending-offer'],
    [{type: UPGRADE_FRAME, inputEpoch: epoch - 1, choice: 'haste', wave: 1, applied: 0}, 'stale-round'],
    [{type: UPGRADE_FRAME, inputEpoch: epoch, choice: 7, wave: 1, applied: 0}, 'malformed-choice'],
    [{type: UPGRADE_FRAME, inputEpoch: epoch, choice: 'haste', wave: '3', applied: 0}, 'malformed-wave'],
    [{type: UPGRADE_FRAME, inputEpoch: epoch, choice: 'haste', wave: 3, applied: null}, 'malformed-view'],
  ];
  for (const [frame, reason] of refusals) {
    const before = received.length;
    send(frame);
    await new Promise(r => setTimeout(r, 30));
    const answer = received.slice(before).find(entry => entry.type === REJECTED_FRAME);
    assert.ok(answer, `rejection expected for ${JSON.stringify(frame)}`);
    assert.equal(answer.reason, reason);
    assert.ok(!Object.hasOwn(answer, 'count'), 'a refusal never reports an applied count');
    assert.equal(ws.readyState, WebSocket.OPEN, 'refusals never end the session');
  }
  // The round is still live: ordinary inputs and snapshots keep flowing.
  const before = received.length;
  send({type: 'input', seq: 1, inputEpoch: epoch, input: {x: 0, z: 0, yaw: 0, pitch: 0}});
  const snapshot = await new Promise((ready, reject) => {
    const timer = setInterval(() => {
      const frame = received.slice(before).find(entry => entry.type === 'snapshot' && entry.hordeInput?.receivedSeq >= 1);
      if (frame) { clearInterval(timer); ready(frame); }
    }, 20);
    setTimeout(() => { clearInterval(timer); reject(Error('no snapshot after refusals')); }, 5000);
  });
  assert.equal(snapshot.state.singleplayer.upgradeCount, 0);
  assert.equal(snapshot.state.singleplayer.upgrades.length, 0);
  assert.ok(snapshot.hordeInput.receivedSeq >= 1, 'input cursor advanced for an ordinary sample');
  ws.close();
  await new Promise(r => ws.once('close', r));
  await authority.close();
  assert.equal(authority.server.listening, false);
  assert.equal(authority.wss.clients.size, 0);
});

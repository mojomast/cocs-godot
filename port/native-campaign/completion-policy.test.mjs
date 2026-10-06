import test from 'node:test';
import assert from 'node:assert/strict';
import {createCampaignMatch} from './match.mjs';
import {loadCampaignMap} from './maps.mjs';
import {OBJECTIVE_COMPLETION, DEFAULT_OBJECTIVE_COMPLETION, completionPolicyFor, MISSIONS} from './missions.mjs';

// F10 measured experiment: one explicit completion policy for ONE encounter.
//
// Control (`require-all-guards`, the default) is the shipped behaviour and must
// stay reachable unchanged. The experiment (`restore-and-withdraw`) is opted
// into by siltwake-crossing step 1 only. This file pins both paths.
//
// The choice is deliberate: it is a proposal under measurement, not promoted
// behaviour. Nothing here decides whether the experiment should ship.

const MAP = 'siltwake-crossing';
const STEP = 1;                       // "Restart the west pump": restore, 5 s
const CONTROL = OBJECTIVE_COMPLETION.requireAllGuards;
const EXPERIMENT = OBJECTIVE_COMPLETION.restoreAndWithdraw;
const DT = 1 / 60;

const rng = (seed = 8157) => { let n = seed; return () => ((n = Math.imul(n, 1664525) + 1013904223 >>> 0) / 4294967296); };
const anchor = () => loadCampaignMap(MAP).campaign.anchors[`encounter-${STEP + 1}`];
const make = (policy, extra = {}) => createCampaignMatch({mapId: MAP, random: rng(), checkpoint: STEP, objectiveCompletion: policy, ...extra});

// Player placement only. No protection grant: these tests assert objective and
// bookkeeping rules, not damage avoidance.
const put = (match, point) => Object.assign(match.actors[0], {x: point.x, y: point.y, z: point.z, vx: 0, vy: 0, vz: 0, grounded: true, lastValid: {x: point.x, y: point.y, z: point.z}});
const tick = (match, input = {}) => match.step(DT, {inputs: {0: input}});
const idleTick = match => match.step(DT, {inputs: Object.fromEntries(match.actors.map(a => [a.id, {}]))});
const guards = match => match.actors.filter(a => a.isNpc && match.modeState.enemies.includes(a.id) && a.health > 0);
const liveNpcs = match => match.actors.filter(a => a.isNpc && a.health > 0);

function deploy(match) {
  const mark = anchor();
  put(match, {x: mark.x + 34, y: mark.y, z: mark.z}); tick(match);
  if (!match.modeState.deployed) { put(match, mark); tick(match); }
  put(match, mark); tick(match);
  return guards(match).length;
}
// Exercise the real source kill path rather than mutating objective state.
function killAll(match) {
  for (const actor of liveNpcs(match)) {
    actor.protection = 0;
    for (let i = 0; i < 200 && actor.health > 0; i++) match.damage(actor, 1000, match.actors[0], true);
    assert.ok(actor.health <= 0, 'source damage kills the guard');
  }
}
// Run the transfer to a full duration and report whether the objective accepted.
function runTransfer(match, cap = 20 * 60) {
  let n = 0;
  while (n < cap && match.snapshot().campaign.stepIndex === STEP && match.snapshot().campaign.phase === 'playing') {
    tick(match, {interact: n % 2 === 0}); n++;
  }
  return n;
}

test('the control policy is the default and resolves for every encounter', () => {
  assert.equal(DEFAULT_OBJECTIVE_COMPLETION, CONTROL);
  assert.doesNotThrow(() => createCampaignMatch({mapId: MAP, random: rng()}));
  // Every authored encounter resolves to the control rule under the control request.
  for (const mapId of ['rootfall-verge', MAP, 'emberline-ascent', 'crown-array']) {
    for (let step = 0; step < 5; step++) {
      assert.equal(completionPolicyFor(mapId, step, CONTROL), CONTROL, `${mapId} step ${step}`);
    }
  }
});

test('the experiment is opted into exactly one encounter and fails closed otherwise', () => {
  assert.equal(completionPolicyFor(MAP, STEP, EXPERIMENT), EXPERIMENT, 'the one opted-in encounter');
  // A global experiment request must not relax any other map or step.
  const optedIn = [];
  for (const mapId of ['rootfall-verge', MAP, 'emberline-ascent', 'crown-array']) {
    for (let step = 0; step < 5; step++) {
      if (completionPolicyFor(mapId, step, EXPERIMENT) === EXPERIMENT) optedIn.push(`${mapId}:${step}`);
    }
  }
  assert.deepEqual(optedIn, [`${MAP}:${STEP}`], 'exactly one encounter opts in');
  // Unknown policy names fail closed at the constructor, never silently downgraded.
  for (const bad of ['kill-everything', '', null, 42, {}]) {
    assert.throws(() => createCampaignMatch({mapId: MAP, random: rng(), objectiveCompletion: bad}), TypeError, `rejects ${JSON.stringify(bad)}`);
  }
});

test('CONTROL: a finished transfer with every guard still alive never completes the objective', () => {
  const match = make(CONTROL);
  assert.equal(deploy(match), 4, 'the maintenance patrol deploys');
  const run = runTransfer(match);
  assert.ok(run > 300, 'the player actually held the platform for the full 5 s');
  assert.equal(match.snapshot().campaign.holdProgress, 1, 'the transfer reaches 100%');
  assert.equal(match.snapshot().campaign.stepIndex, STEP, 'but the objective still refuses to complete');
  assert.equal(guards(match).length, 4, 'all four guards are still standing');
  assert.equal(match.snapshot().campaign.kills, 0);
  assert.equal(match.events.filter(e => e.type === 'campaign-guard-withdrawal').length, 0, 'control never withdraws');
  // And it completes the instant the guards are gone, which is the whole of F10.
  killAll(match); tick(match, {interact: true});
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1, 'clearing the guards is still what finishes it');
  assert.equal(match.snapshot().campaign.kills, 4);
});

test('EXPERIMENT: the transfer completes with guards alive and they withdraw, bounded', () => {
  const match = make(EXPERIMENT);
  assert.equal(deploy(match), 4);
  const aliveAtCompletion = (() => {
    let previous = guards(match).length, n = 0;
    while (n < 20 * 60 && match.snapshot().campaign.stepIndex === STEP && match.snapshot().campaign.phase === 'playing') {
      tick(match, {interact: n % 2 === 0}); n++;
      if (match.snapshot().campaign.stepIndex !== STEP) return previous;
      previous = guards(match).length;
    }
    return -1;
  })();
  assert.equal(aliveAtCompletion, 4, 'four guards were alive at the completion tick');
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1, 'the objective completed on the transfer alone');
  assert.equal(match.events.filter(e => e.type === 'campaign-guard-withdrawal').length, 1, 'one withdrawal transition');
  assert.equal(match.events.filter(e => e.type === 'campaign-objective-complete').length, 1, 'advanced exactly once');

  const withdrawing = [...match.modeState.withdrawn];
  assert.equal(withdrawing.length, 4, 'every surviving guard is queued to withdraw');
  assert.ok(withdrawing.every(id => match.actors[id].campaignWithdrawn === true));

  // Bounded: the drain is time-driven and unconditional, and completes.
  let ticks = 0;
  while (ticks < 600 && match.modeState.withdrawn.length) { idleTick(match); ticks++; }
  assert.ok(ticks > 0 && ticks <= 90, `withdrawal drains within the grace window (${ticks} ticks)`);
  assert.equal(match.modeState.withdrawn.length, 0);
  for (const id of withdrawing) {
    const actor = match.actors[id];
    assert.ok(actor, 'indexed corpse slot is preserved');
    assert.ok(actor.health <= 0, 'withdrawn guard is despawned');
    assert.equal(actor.campaignWithdrawn, true, 'durable marker bars the respawn hook');
    assert.ok(actor.dead > 1e8, 'pinned so the base respawn branch is unreachable');
    assert.equal(actor.deaths, 0, 'a withdrawal is not a death');
  }
  assert.equal(liveNpcs(match).length, 0, 'no orphan AI left standing');
  assert.equal(match.snapshot().campaign.enemiesRemaining, 0);
});

test('EXPERIMENT: withdrawn guards cannot hurt the player once the objective is banked', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  // Walk far away so only the withdrawal could possibly reach the player.
  put(match, {x: anchor().x + 120, y: anchor().y, z: anchor().z + 120});
  const health = match.actors[0].health, armor = match.actors[0].armor;
  for (let i = 0; i < 240; i++) idleTick(match);
  assert.ok(match.actors[0].health >= health, 'no damage after the objective is earned');
  assert.ok(match.actors[0].armor >= armor);
  assert.equal(liveNpcs(match).length, 0);
});

test('EXPERIMENT: leaving and returning before completion keeps progress and still completes', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  tick(match, {interact: true});
  for (let i = 0; i < 60; i++) idleTick(match);
  const partial = match.snapshot().campaign.holdProgress;
  assert.ok(partial > 0 && partial < 1, `partial transfer (${partial})`);
  put(match, {x: anchor().x + 90, y: anchor().y, z: anchor().z + 90});
  for (let i = 0; i < 60; i++) idleTick(match);
  assert.equal(match.snapshot().campaign.holdProgress, partial, 'leaving pauses the transfer');
  assert.equal(match.snapshot().campaign.stepIndex, STEP, 'still not complete while away');
  put(match, anchor());
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1, 'returning finishes it');
  assert.equal(liveNpcs(match).length, 4, 'the patrol is still standing and withdraws');
  let ticks = 0;
  while (ticks < 600 && match.modeState.withdrawn.length) { idleTick(match); ticks++; }
  assert.equal(liveNpcs(match).length, 0, 'withdrawal drained');
});

test('EXPERIMENT: withdrawal is never a kill and never duplicates rewards on retry', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  // Kill exactly two of the four, then let the transfer finish the objective.
  for (const actor of guards(match).slice(0, 2)) {
    actor.protection = 0;
    for (let i = 0; i < 200 && actor.health > 0; i++) match.damage(actor, 1000, match.actors[0], true);
  }
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  assert.equal(match.snapshot().campaign.kills, 2, 'only the two real kills are banked');
  assert.equal(match.modeState.withdrawn.length, 2, 'the other two withdraw');

  // The checkpoint carries the same total forward; retrying must not add to it.
  const checkpoint = match.campaignCheckpoint();
  assert.equal(checkpoint.kills, 2);
  assert.equal(checkpoint.checkpoint, STEP + 1, 'retry resumes past the completed encounter');
  const retry = createCampaignMatch({mapId: MAP, random: rng(), ...checkpoint, objectiveCompletion: EXPERIMENT});
  assert.equal(retry.snapshot().campaign.kills, 2, 'banked total is carried, not re-earned');
  assert.equal(retry.snapshot().campaign.stepIndex, STEP + 1);
});

test('EXPERIMENT: a withdrawal in flight does not gate the next encounter', () => {
  const data = loadCampaignMap(MAP);
  const match = make(EXPERIMENT);
  deploy(match);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  assert.equal(match.modeState.withdrawn.length, 4, 'the previous patrol is still withdrawing');

  // Run ahead to the next anchor and clear its guards without touching the
  // withdrawing ones.
  const withdrawing = [...match.modeState.withdrawn];
  const next = data.campaign.anchors['encounter-3'];
  put(match, next); tick(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1, 'next encounter deployed');
  for (const actor of liveNpcs(match).filter(a => !withdrawing.includes(a.id))) {
    actor.protection = 0;
    for (let i = 0; i < 200 && actor.health > 0; i++) match.damage(actor, 1000, match.actors[0], true);
  }
  tick(match, {interact: true});
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 2, 'cleared objective completes with no stall');
  let ticks = 0;
  while (ticks < 600 && match.modeState.withdrawn.length) { idleTick(match); ticks++; }
  assert.equal(liveNpcs(match).length, 0, 'both withdrawals eventually drained');
});

test('EXPERIMENT: the map still runs to level-complete, so the objective cannot softlock', () => {
  const data = loadCampaignMap(MAP);
  const match = make(EXPERIMENT, {checkpoint: STEP});
  deploy(match); runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  for (let guard = 0; guard < 4 * 60 && match.snapshot().campaign.phase === 'playing'; guard++) {
    const index = match.snapshot().campaign.stepIndex;
    if (index >= 5) { put(match, data.campaign.anchors.exit); tick(match); continue; }
    const mark = data.campaign.anchors[`encounter-${index + 1}`];
    put(match, {x: mark.x + 34, y: mark.y, z: mark.z}); tick(match);
    if (match.snapshot().campaign.stepIndex === index) { put(match, mark); tick(match); }
    if (match.snapshot().campaign.stepIndex === index) { killAll(match); tick(match, {interact: true}); }
    for (let n = 0; n < 2000 && match.snapshot().campaign.stepIndex === index && match.snapshot().campaign.phase === 'playing'; n++) {
      tick(match, {interact: true});
    }
  }
  assert.equal(match.snapshot().campaign.stepIndex, 5);
  assert.equal(match.snapshot().campaign.phase, 'level-complete');
  assert.equal(match.events.filter(e => e.type === 'campaign-guard-withdrawal').length, 1, 'only the opted-in encounter withdrew');
  assert.equal(liveNpcs(match).length, 0, 'no guard left standing at the end of the level');
});

test('EXPERIMENT does not relax any other restore/hold encounter', () => {
  for (const [mapId, step] of [['rootfall-verge', 2], ['emberline-ascent', 2], ['crown-array', 2], [MAP, 3]]) {
    const encounter = MISSIONS[mapId].encounters[step];
    assert.ok(encounter.seconds > 0, `${mapId} step ${step} is a timed encounter`);
    const seconds = encounter.seconds;
    const data = loadCampaignMap(mapId);
    const mark = data.campaign.anchors[`encounter-${step + 1}`];
    const match = createCampaignMatch({mapId, random: rng(), checkpoint: step, objectiveCompletion: EXPERIMENT});
    // Same fixture the deterministic suite uses for hold/progress proofs: empty
    // externally supplied controls stop enemy AI inputs while role ticks and
    // objective logic continue, and fixture protection stops damage from masking
    // the assertion. This is a policy-scope test, not a difficulty test.
    const place = p => { put(match, p); match.actors[0].protection = 100; };
    const heldTick = () => match.step(DT, {inputs: Object.fromEntries(match.actors.map(a => [a.id, a.id === 0 ? {interact: true} : {}]))});
    place({x: mark.x + 34, y: mark.y, z: mark.z}); tick(match);
    if (!match.modeState.deployed) { place(mark); tick(match); }
    place(mark); tick(match);
    assert.ok(liveNpcs(match).length > 0, `${mapId} step ${step} deployed guards`);
    let n = 0;
    while (n < Math.ceil(seconds * 60) + 120 && match.snapshot().campaign.stepIndex === step && match.snapshot().campaign.phase === 'playing') {
      place(mark); heldTick(); n++;
    }
    assert.equal(match.snapshot().campaign.phase, 'playing', `${mapId} step ${step} survives the fixture`);
    assert.ok(match.snapshot().campaign.holdProgress >= 1, `${mapId} step ${step} transfer reached full duration (${match.snapshot().campaign.holdProgress})`);
    assert.equal(match.snapshot().campaign.stepIndex, step, `${mapId} step ${step} still requires every guard dead`);
    assert.ok(liveNpcs(match).length > 0, `${mapId} step ${step} guards are still standing`);
    assert.equal(match.events.filter(e => e.type === 'campaign-guard-withdrawal').length, 0, `${mapId} step ${step} did not withdraw`);
  }
});

test('EXPERIMENT: the critical path needs no operator ability and no last-guard kill', () => {
  const match = createCampaignMatch({mapId: MAP, random: rng(), checkpoint: STEP, difficulty: 'easy', objectiveCompletion: EXPERIMENT});
  deploy(match);
  // Only walk-to-marker and the stock interact pulse. No power, no altFire, no firing.
  for (let n = 0; n < 20 * 60 && match.snapshot().campaign.stepIndex === STEP; n++) tick(match, {interact: n % 2 === 0});
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1, 'completes without firing a shot or using an ability');
  assert.equal(match.snapshot().campaign.kills, 0, 'and without killing anything');
});
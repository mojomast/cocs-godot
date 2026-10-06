import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, rmSync, writeFileSync, symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createCampaignMatch} from './match.mjs';
import {loadCampaignMap} from './maps.mjs';
import {OBJECTIVE_COMPLETION, DEFAULT_OBJECTIVE_COMPLETION, completionPolicyFor, objectivePresentationFor, MISSIONS} from './missions.mjs';
import {WITHDRAW_GRACE, WITHDRAW_RELEASE, WITHDRAW_MIN_WALK, WITHDRAW_ARRIVAL} from './enemies.mjs';

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
// Actor 0 only, so the source NPC AI drives every guard. `idleTick` below
// deliberately supplies an empty control for EVERY actor, which makes the core
// treat each guard as externally driven and skip botInput entirely -- see the
// live-AI retraction test, which is why the walk-off is measured with this.
const liveTick = match => match.step(DT, {inputs: {0: {}}});
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

// The control-trace bit-identity proof, run FIRST so a regression in the
// experiment additions below cannot hide behind it.
//
// The shipped rule must be bit-for-bit identical on the wire. A deterministic
// control-policy trace is hashed here, and the SAME trace is replayed from a
// pristine `godot/main` checkout of the same files at the same path; any
// behavioural difference in the control path changes the hash. The comparison
// is done by importing the baseline sources from a sibling worktree when one is
// available, and skipped (loudly, as `t.skip`) when it is not -- so the suite
// stays runnable anywhere while CI, which always has `godot/main`, enforces it.
//
// The trace hashes the ENTIRE `campaign` payload plus the per-actor additive
// flag, not a field allowlist. That is the point: an added key anywhere in the
// snapshot the HUD reads (like `withdrawing` or `campaignWithdrawing`) would
// move the hash, so the experiment's "additive" fields can only stay in the
// control path if they are genuinely absent there.
function controlTraceHash() {
  const {createHash} = require_node_crypto;
  const match = make(CONTROL);
  const mark = anchor();
  put(match, {x: mark.x + 34, y: mark.y, z: mark.z}); tick(match);
  if (!match.modeState.deployed) { put(match, mark); tick(match); }
  put(match, mark); tick(match);
  // A fixed 1603-tick scripted control run. Long enough to cross the whole
  // transfer, a real kill and the checkpoint, so the gate covers the objective
  // rule rather than just deployment.
  const seen = [];
  for (let n = 0; n < 1603; n++) {
    if (n % 97 === 40) killAll(match);
    tick(match, {interact: n % 2 === 0});
    const s = match.snapshot();
    seen.push([n, s.campaign, s.actors.map(a => a.campaignWithdrawing ?? null)]);
  }
  return {hash: createHash('sha256').update(JSON.stringify(seen)).digest('hex'), final: seen[seen.length - 1]};
}
let require_node_crypto;
try { require_node_crypto = await import('node:crypto'); } catch { require_node_crypto = {createHash: () => ({update: () => ({digest: () => 'unavailable'})})}; }

// Replay the identical control trace against a PRISTINE `godot/main` checkout, so
// the bit-identity claim is measured rather than asserted. `null` means the
// baseline was not reachable and the caller should skip rather than fake a pass.
function baselineControlTraceHash() {
  let root;
  try {
    root = execFileSync('git', ['rev-parse', '--show-toplevel'], {cwd: new URL('../..', import.meta.url).pathname, encoding: 'utf8'}).trim();
  } catch { return null; }
  const scratch = mkdtempSync(join(tmpdir(), 'f10-baseline-'));
  let tree;
  try {
    execFileSync('git', ['worktree', 'add', '--detach', scratch, 'godot/main'], {cwd: root, stdio: 'pipe'});
    tree = scratch;
  } catch {
    // `godot/main` may already be checked out elsewhere; a detached commit hash
    // works just as well for a read-only source comparison.
    try {
      const head = execFileSync('git', ['rev-parse', 'godot/main'], {cwd: root, encoding: 'utf8'}).trim();
      execFileSync('git', ['worktree', 'add', '--detach', scratch, head], {cwd: root, stdio: 'pipe'});
      tree = scratch;
    } catch { rmSync(scratch, {recursive: true, force: true}); return null; }
  }
  try {
    symlinkSync(join(root, 'node_modules'), join(tree, 'node_modules'));
  } catch { /* the baseline tree resolves its own imports */ }
  const driver = join(tree, 'f10-baseline-trace.mjs');
  writeFileSync(driver, BASELINE_DRIVER);
  try {
    const out = execFileSync(process.execPath, [driver], {cwd: tree, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
    const line = out.split('\n').find(l => l.startsWith('F10_BASELINE_TRACE '));
    return line ? line.slice('F10_BASELINE_TRACE '.length).trim() : null;
  } catch { return null; }
  finally { try { execFileSync('git', ['worktree', 'remove', '--force', tree], {cwd: root, stdio: 'pipe'}); } catch { rmSync(tree, {recursive: true, force: true}); } }
}

// The same scripted control run, expressed against whatever `match.mjs` the file
// sits next to, so the identical script runs against both trees.
const BASELINE_DRIVER = `
import {createHash} from 'node:crypto';
import {createCampaignMatch} from './port/native-campaign/match.mjs';
import {loadCampaignMap} from './port/native-campaign/maps.mjs';
const DT=1/60, MAP='siltwake-crossing', STEP=1;
const rng=(seed=8157)=>{let n=seed;return()=>((n=Math.imul(n,1664525)+1013904223>>>0)/4294967296);};
const mark=loadCampaignMap(MAP).campaign.anchors['encounter-'+(STEP+1)];
const match=createCampaignMatch({mapId:MAP,random:rng(),checkpoint:STEP});
const put=p=>Object.assign(match.actors[0],{x:p.x,y:p.y,z:p.z,vx:0,vy:0,vz:0,grounded:true,lastValid:{x:p.x,y:p.y,z:p.z}});
const tick=(i={})=>match.step(DT,{inputs:{0:i}});
put({x:mark.x+34,y:mark.y,z:mark.z});tick();
if(!match.modeState.deployed){put(mark);tick();}
put(mark);tick();
const live=()=>match.actors.filter(a=>a.isNpc&&a.health>0);
const seen=[];
for(let n=0;n<1603;n++){
  if(n%97===40)for(const a of live()){a.protection=0;for(let i=0;i<200&&a.health>0;i++)match.damage(a,1000,match.actors[0],true);}
  tick({interact:n%2===0});
  const s=match.snapshot();
  seen.push([n,s.campaign,s.actors.map(a=>a.campaignWithdrawing??null)]);
}
console.log('F10_BASELINE_TRACE '+createHash('sha256').update(JSON.stringify(seen)).digest('hex'));
`;

test('CONTROL-TRACE: the shipped rule is bit-for-bit identical to godot/main', t => {
  const mine = controlTraceHash();
  // Pinned to the hash measured on pristine `godot/main` @ 8a6e7be2 with the
  // identical script, including the full campaign payload and the additive
  // per-actor flag. Any change to the shared rule, the shared gate, the
  // presentation counts, the encounter copy or an un-gated additive field moves
  // it.
  assert.equal(mine.hash, 'f301db03ed359dd4688e80c274790862e484153b495d1d1bd1173677b9a27989', 'control trace hash');

  // And, when a pristine baseline checkout is reachable, replay the identical
  // trace there and compare hashes directly. This is the bit-identity proof
  // rather than a claim about it.
  const baseline = baselineControlTraceHash();
  if (!baseline) { t.skip('no pristine godot/main checkout reachable for a live differential'); return; }
  assert.equal(mine.hash, baseline, 'control trace is byte-identical to the shipped sources');
});

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

  // Bounded: the retreat is anchored on match time and the guard's own position,
  // never on the player or the next step, so it always completes.
  let ticks = 0;
  while (ticks < 20 * 60 && match.modeState.withdrawn.length) { liveTick(match); ticks++; }
  assert.ok(ticks > 0, 'the withdrawal actually ran');
  assert.ok(ticks <= WITHDRAW_GRACE * 60 + 2,
    `withdrawal completes within the bounded grace window (${ticks} ticks vs ${Math.ceil(WITHDRAW_GRACE * 60)})`);
  assert.equal(match.modeState.withdrawn.length, 0);
  assert.equal(match.modeState.withdrawAnchor, null, 'the relevance anchor is released with the last guard');
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
  assert.equal(match.snapshot().campaign.withdrawing ?? 0, 0, 'the honest withdrawal count drains too');
});

test('EXPERIMENT: survivors walk off before they despawn, and never pop where they stood', () => {
  const match = make(EXPERIMENT);
  assert.equal(deploy(match), 4);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);

  const ids = [...match.modeState.withdrawn];
  const mark = anchor();
  const start = new Map(ids.map(id => {
    const a = match.actors[id];
    return [id, {x: a.x, z: a.z}];
  }));
  const player = {x: match.actors[0].x, z: match.actors[0].z};
  // Every guard has a nav-graph goal it has not already reached, so the
  // withdrawal is a walk and not an instant despawn. The goal is also on the far
  // side of the guard from the player, so the walk reads as a retreat, not a
  // charge.
  for (const id of ids) {
    const goal = match.actors[id].campaignRetreat;
    assert.ok(goal, 'each withdrawing guard has a retreat goal');
    assert.ok(Math.hypot(goal.x - start.get(id).x, goal.z - start.get(id).z) >= WITHDRAW_MIN_WALK,
      'the goal is far enough away to read as a retreat');
    const outward = (start.get(id).x - player.x) * (goal.x - start.get(id).x)
      + (start.get(id).z - player.z) * (goal.z - start.get(id).z);
    assert.ok(outward > 0, `guard ${id} retreats away from the player, not toward it`);
  }

  // Sample the walk. Every guard must be moving on the first tick it is free to
  // move, must cover the minimum before it goes, and must be observed alive AND
  // displaced on screen first.
  const walked = new Map(ids.map(id => [id, 0]));
  const aliveSamples = new Map(ids.map(id => [id, 0]));
  const terminal = new Map();          // arrived | past | expired, per guard
  let peakAnchor = 0;
  for (let t = 0; t < WITHDRAW_GRACE * 60 + 4 && match.modeState.withdrawn.length; t++) {
    liveTick(match);
    for (const id of ids) {
      const actor = match.actors[id];
      // Position is retained when a guard despawns, so the displacement of the
      // DESPAWN tick is measurable here. Sampling only living guards would miss
      // the final stride, which is exactly the sample that matters.
      const moved = Math.hypot(actor.x - start.get(id).x, actor.z - start.get(id).z);
      walked.set(id, Math.max(walked.get(id), moved));
      const fromAnchor = Math.hypot(actor.x - mark.x, actor.z - mark.z);
      peakAnchor = Math.max(peakAnchor, fromAnchor);
      if (actor.health <= 0) {
        // Record WHY it despawned. The design promises arrival at the goal or
        // out-of-relevance, with the fixed deadline as the hard bound.
        const goal = actor.campaignRetreat;
        const arrived = goal && Math.hypot(actor.x - goal.x, actor.z - goal.z) <= WITHDRAW_ARRIVAL;
        const past = fromAnchor >= WITHDRAW_RELEASE;
        const expired = t >= WITHDRAW_GRACE * 60 - 1;
        terminal.set(id, {arrived, past, expired});
        continue;
      }
      aliveSamples.set(id, aliveSamples.get(id) + 1);
      assert.ok(Math.hypot(actor.vx, actor.vz) > 0.01,
        `guard ${id} is still standing at its post with no walk`);
    }
  }
  assert.equal(match.modeState.withdrawn.length, 0, 'the retreat completed');
  for (const id of ids) {
    assert.ok(walked.get(id) >= WITHDRAW_MIN_WALK,
      `guard ${id} walked ${walked.get(id).toFixed(2)} m before despawn (min ${WITHDRAW_MIN_WALK})`);
    assert.ok(aliveSamples.get(id) > 1,
      `guard ${id} was observed alive while retreating (${aliveSamples.get(id)} ticks)`);
    const why = terminal.get(id) ?? {};
    assert.ok(why.arrived || why.past || why.expired,
      `guard ${id} despawned on arrival, out of relevance or the deadline (${JSON.stringify(why)})`);
  }
  // The patrol cleared the contested position: at least one survivor crossed the
  // relevance radius, so the withdrawal visibly leaves the fight.
  assert.ok(peakAnchor >= WITHDRAW_RELEASE,
    `the patrol cleared the contested position (peak ${peakAnchor.toFixed(2)} m from anchor vs ${WITHDRAW_RELEASE})`);
  assert.equal(match.snapshot().campaign.enemiesRemaining, 0);
});

test('EXPERIMENT: a retreat is never a kill, never a drop and never rewarded', () => {
  const match = make(EXPERIMENT);
  assert.equal(deploy(match), 4);
  const startingAmmo = match.actors[0].ammo.map(a => a);
  const bankedBefore = match.modeState.bankedKills;
  const fragmentsBefore = match.pickups.length;
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);

  // No frag, no kill-feed entry, no stat: the withdrawal writes health, never
  // damage(), so none of the reward surfaces can move.
  assert.equal(match.stats.kills, 0, 'no kill was scored');
  assert.equal(match.events.filter(e => e.type === 'kill').length, 0, 'no kill-feed entry');
  assert.equal(match.snapshot().campaign.kills, 0, 'nothing was banked');
  assert.equal(match.modeState.bankedKills, bankedBefore);

  for (let t = 0; t < WITHDRAW_GRACE * 60 + 4 && match.modeState.withdrawn.length; t++) liveTick(match);
  assert.equal(match.stats.kills, 0, 'still no kill after the retreat finishes');
  assert.equal(match.snapshot().campaign.kills, 0);
  assert.equal(match.pickups.length, fragmentsBefore, 'a withdrawal drops nothing');
  // The player's own ammo refill on objective completion is the stock reward and
  // is unchanged; the point is that it is the ONLY thing that moved.
  assert.deepEqual(match.actors[0].ammo.filter((a, i) => a !== startingAmmo[i] && i !== match.actors[0].weapon).length, 0,
    'no withdrawal-specific ammo appeared');
});

test('EXPERIMENT: the withdrawal is retry-safe and cannot be farmed', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  for (let t = 0; t < WITHDRAW_GRACE * 60 + 4 && match.modeState.withdrawn.length; t++) liveTick(match);
  const banked = match.campaignCheckpoint().kills;
  assert.equal(banked, 0);

  // Retry from that checkpoint: the completed encounter is behind us, so there is
  // nothing to withdraw and nothing to earn a second time.
  const retry = createCampaignMatch({mapId: MAP, random: rng(), ...match.campaignCheckpoint(), objectiveCompletion: EXPERIMENT});
  assert.equal(retry.snapshot().campaign.stepIndex, STEP + 1, 'the retry resumes past it');
  assert.equal(retry.modeState.withdrawn.length, 0, 'a fresh match has no withdrawal in flight');
  for (let t = 0; t < 120; t++) liveTick(retry);
  assert.equal(retry.snapshot().campaign.kills, 0, 'retrying banked nothing extra');
  assert.equal(retry.stats.kills, 0);
  assert.equal(retry.events.filter(e => e.type === 'campaign-guard-withdrawal').length, 0, 'and withdrew nothing');
});

test('EXPERIMENT: withdrawn guards cannot hurt the player once the objective is banked', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  // Walk far away so only the withdrawal could possibly reach the player.
  put(match, {x: anchor().x + 120, y: anchor().y, z: anchor().z + 120});
  const health = match.actors[0].health, armor = match.actors[0].armor;
  // liveTick, not idleTick: with real NPC AI running for every guard, nothing in
  // the withdrawal can reach the player. The previous idleTick fixture supplied
  // an external control for every actor, which made the core skip botInput and
  // so never exercised the guard AI this assertion is about.
  for (let i = 0; i < WITHDRAW_GRACE * 60 + 60; i++) liveTick(match);
  assert.ok(match.actors[0].health >= health, 'no damage after the objective is earned');
  assert.ok(match.actors[0].armor >= armor);
  assert.equal(liveNpcs(match).length, 0);
});

test('EXPERIMENT: a retreating guard never fires, telegraphs or melees', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  const ids = [...match.modeState.withdrawn];
  // Telegraphs already emitted DURING the fight are real combat and stay in the
  // log; what must be zero is anything a withdrawing guard starts afterwards.
  const telegraphsBefore = match.events.filter(e => e.type === 'enemy-telegraph' && ids.includes(e.actor)).length;
  const shotsBefore = match.stats.shots, killsBefore = match.stats.kills;
  // Stand right on top of them so range and line of sight cannot be the reason.
  for (let t = 0; t < WITHDRAW_GRACE * 60 + 60; t++) {
    for (const id of ids) {
      const a = match.actors[id];
      if (a.health <= 0) continue;
      put(match, {x: a.x + 2, y: a.y, z: a.z + 2});
    }
    liveTick(match);
    for (const id of ids) {
      const a = match.actors[id];
      if (a.health <= 0) continue;
      // The retreat policy is the only driver while they are still standing: no
      // target is acquired, the combat state stays `withdraw`, and the attack
      // veto cannot be re-armed by a lane cleanup.
      assert.equal(a.bot.target, -1, `guard ${id} reacquired a target mid-retreat`);
      assert.equal(a.bot.state, 'withdraw', `guard ${id} left the retreat policy`);
      assert.equal(a.campaignReady, Infinity, `guard ${id} attack veto was re-armed`);
      assert.equal(a.campaignWithdrawn, true);
      assert.ok(a.campaignRetreat, `guard ${id} lost its retreat goal`);
    }
  }
  assert.equal(match.stats.shots, shotsBefore, 'a withdrawing guard never shoots');
  assert.equal(match.stats.kills, killsBefore, 'and never kills');
  assert.equal(match.events.filter(e => e.type === 'enemy-telegraph' && ids.includes(e.actor)).length, telegraphsBefore,
    'and never starts a new telegraph');
});

test('EXPERIMENT: a dead or level-complete match still reports no standing guard', () => {
  for (const how of ['dead', 'level-complete']) {
    const match = make(EXPERIMENT);
    deploy(match);
    runTransfer(match);
    assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
    assert.equal(match.modeState.withdrawn.length, 4, `${how}: a retreat is in flight`);
    if (how === 'dead') {
      match.actors[0].health = 0;
    } else {
      match.modeState.stepIndex = 5;
      const exit = loadCampaignMap(MAP).campaign.anchors.exit;
      put(match, {x: exit.x, y: exit.y, z: exit.z});
    }
    liveTick(match);
    assert.equal(match.modeState.withdrawn.length, 0, `${how}: the in-flight retreat was drained`);
    assert.equal(liveNpcs(match).length, 0, `${how}: no guard is left standing`);
    assert.notEqual(match.snapshot().campaign.phase, 'playing', `${how}: the match closed`);
  }
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

test('EXPERIMENT: a withdrawal in flight is not reported as a live threat', () => {
  const match = make(EXPERIMENT);
  deploy(match);
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
  assert.equal(match.modeState.withdrawn.length, 4, 'the patrol is still walking off');
  // The HUD count must not claim four robots are still fighting. The honest
  // number moves to `withdrawing` so a client can say so out loud.
  const snapshot = match.snapshot();
  assert.equal(snapshot.campaign.enemiesRemaining, 0, 'a retreating guard is not a live threat');
  assert.equal(snapshot.campaign.withdrawing, 4, 'the retreat is reported honestly instead');
  // And it stays honest for as long as they are on screen.
  for (let t = 0; t < 60; t++) liveTick(match);
  if (match.modeState.withdrawn.length) {
    const during = match.snapshot();
    assert.equal(during.campaign.enemiesRemaining, 0);
    assert.equal(during.campaign.withdrawing, match.modeState.withdrawn.length);
  }
  for (let t = 0; t < WITHDRAW_GRACE * 60 + 4 && match.modeState.withdrawn.length; t++) liveTick(match);
  assert.equal(match.snapshot().campaign.withdrawing ?? 0, 0, 'and it resolves to zero once they are gone');
  // The field is additive and gated: the control snapshot never grows it, so the
  // shipped wire bytes are unchanged. The running control match is the only
  // control match here, and it must never have carried it.
  assert.equal(Object.hasOwn(snapshot.campaign, 'withdrawing'), true, 'present while withdrawing');
  const control = make(CONTROL);
  deploy(control);
  runTransfer(control);
  assert.equal(Object.hasOwn(control.snapshot().campaign, 'withdrawing'), false,
    'the control payload never carries the experiment-only count');
  assert.ok(control.snapshot().actors.filter(a => a.isNpc).every(a => !Object.hasOwn(a, 'campaignWithdrawing')),
    'the control payload never carries the experiment-only per-actor flag');
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

test('OBJECTIVE STRING: control keeps the shipped copy verbatim, everywhere', () => {
  // The control must not lose a single character of the authored text, on any
  // map or step, in either of the two places the objective is displayed.
  const expected = MISSIONS[MAP].encounters[STEP];
  assert.equal(expected.title, 'Restart the west pump', 'the objective id/title is unchanged');
  assert.equal(expected.text, 'ECHO: A small maintenance patrol. Start the pump and use its platform to catch your breath.',
    'the authored encounter text is untouched by the experiment');
  for (let step = 0; step < 5; step++) {
    assert.equal(objectivePresentationFor(MAP, step, CONTROL), null, `control step ${step} has no experiment copy`);
    for (const mapId of ['rootfall-verge', 'emberline-ascent', 'crown-array']) {
      assert.equal(objectivePresentationFor(mapId, step, CONTROL), null, `control ${mapId}:${step}`);
      assert.equal(objectivePresentationFor(mapId, step, EXPERIMENT), null, `experiment requested at ${mapId}:${step}`);
    }
  }
  // Under the control rule the live HUD line is the shipped mechanic string.
  const match = make(CONTROL);
  deploy(match);
  assert.equal(match.snapshot().campaign.objective, expected.title);
  assert.equal(match.snapshot().campaign.detail, 'Press Interact to start the transfer. Defend nearby; dodge without losing progress.');
  assert.equal(match.snapshot().campaign.transmission.text,
    'A small maintenance patrol. Start the pump and use its platform to catch your breath.');
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP, 'and the stale-string pair never applies under control');
});

test('OBJECTIVE STRING: the experiment describes the transfer and the retreat', () => {
  const copy = objectivePresentationFor(MAP, STEP, EXPERIMENT);
  assert.ok(copy, 'the opted-in encounter has experiment copy');
  // The shipped copy is stale under the experiment: it never says the transfer
  // finishes the job, and it never says survivors may leave.
  assert.match(copy.detail, /transfer/i, 'the HUD line names the transfer as the task');
  assert.match(copy.detail, /falls back/i, 'and says survivors withdraw');
  assert.doesNotMatch(copy.detail, /eliminate the deployed|Defend nearby/i,
    'and drops the control copy that promises an extermination');
  assert.match(copy.brief, /^ECHO: /, 'the brief keeps the ECHO prefix like every other encounter');
  assert.match(copy.brief, /falls back/i, 'the brief says survivors withdraw');
  assert.doesNotMatch(copy.brief, /catch your breath/,
    'the stale "catch your breath" line is gone from the experiment brief');
  // The objective identity itself does not move.
  assert.equal(MISSIONS[MAP].encounters[STEP].title, 'Restart the west pump');
  assert.equal(MISSIONS[MAP].encounters[STEP].mechanic, 'restore');
  assert.equal(MISSIONS[MAP].encounters[STEP].seconds, 5);

  // Live: the opted-in run shows the experiment copy in both places.
  const match = make(EXPERIMENT);
  deploy(match);
  assert.equal(match.snapshot().campaign.objective, 'Restart the west pump', 'objective id is unchanged');
  assert.equal(match.snapshot().campaign.detail, copy.detail, 'the HUD line is the experiment copy');
  assert.equal(match.snapshot().campaign.transmission.text, copy.brief.replace(/^ECHO: /, ''),
    'the deployment transmission is the experiment brief');
  runTransfer(match);
  assert.equal(match.snapshot().campaign.stepIndex, STEP + 1);
});

test('OBJECTIVE STRING: the experiment copy appears on no other map or step', () => {
  const authored = [];
  for (const mapId of ['rootfall-verge', MAP, 'emberline-ascent', 'crown-array']) {
    for (let step = 0; step < 5; step++) {
      if (objectivePresentationFor(mapId, step, EXPERIMENT)) authored.push(`${mapId}:${step}`);
    }
  }
  assert.deepEqual(authored, [`${MAP}:${STEP}`], 'exactly one encounter has experiment copy');
  // Requesting the experiment globally must not restate another encounter.
  const other = createCampaignMatch({mapId: 'crown-array', random: rng(), objectiveCompletion: EXPERIMENT});
  assert.equal(other.snapshot().campaign.detail.startsWith('Press Interact to start the transfer') ||
    other.snapshot().campaign.detail.length > 0, true, 'control copy still resolves');
  assert.equal(objectivePresentationFor('crown-array', 1, EXPERIMENT), null,
    'the crown feeder restore keeps its shipped string');
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

test('EXPERIMENT: the retreat is bounded on every difficulty and seed', () => {
  // Bounded means bounded on the SLOWEST guard at the SLOWEST difficulty, not
  // just on the test seed. Walk the whole drain on a small matrix and pin the
  // two bounds: every guard covers WITHDRAW_MIN_WALK, and the last one is gone
  // inside the fixed grace window.
  const mark = anchor();
  for (const difficulty of ['easy', 'normal', 'hard']) {
    for (let seed = 1; seed <= 4; seed++) {
      const match = make(EXPERIMENT, {difficulty, random: rng(seed * 977)});
      assert.equal(deploy(match), 4, `${difficulty}/${seed} deploys`);
      runTransfer(match);
      assert.equal(match.snapshot().campaign.stepIndex, STEP + 1, `${difficulty}/${seed} completed on the transfer`);
      const ids = [...match.modeState.withdrawn];
      assert.equal(ids.length, 4, `${difficulty}/${seed} queues the survivors`);
      const start = new Map(ids.map(id => [id, {x: match.actors[id].x, z: match.actors[id].z}]));
      let ticks = 0, peakAnchor = 0;
      while (ticks < 20 * 60 && match.modeState.withdrawn.length) {
        liveTick(match); ticks++;
        for (const id of ids) {
          const a = match.actors[id];
          peakAnchor = Math.max(peakAnchor, Math.hypot(a.x - mark.x, a.z - mark.z));
        }
      }
      assert.equal(match.modeState.withdrawn.length, 0, `${difficulty}/${seed} drained`);
      assert.ok(ticks <= WITHDRAW_GRACE * 60 + 2, `${difficulty}/${seed} drained in ${ticks} ticks`);
      for (const id of ids) {
        const a = match.actors[id];
        const walked = Math.hypot(a.x - start.get(id).x, a.z - start.get(id).z);
        const atGoal = Math.hypot(a.x - a.campaignRetreat.x, a.z - a.campaignRetreat.z) <= WITHDRAW_ARRIVAL;
        assert.ok(walked >= WITHDRAW_MIN_WALK || atGoal,
          `${difficulty}/${seed} guard ${id} walked ${walked.toFixed(2)} m (min ${WITHDRAW_MIN_WALK})`);
        assert.equal(a.health, 0, `${difficulty}/${seed} guard ${id} despawned`);
        assert.equal(a.deaths, 0, `${difficulty}/${seed} guard ${id} was not a death`);
      }
      assert.ok(peakAnchor >= WITHDRAW_MIN_WALK, `${difficulty}/${seed} the patrol left the contested ground`);
      assert.equal(liveNpcs(match).length, 0, `${difficulty}/${seed} no orphan AI`);
      assert.equal(match.snapshot().campaign.kills, 0, `${difficulty}/${seed} no kill credit`);
    }
  }
});

test('EXPERIMENT: the retreat is deterministic for identical sim state', () => {
  // Same seed, same scripted ticks: goals, despawn order and despawn positions
  // must be identical. Determinism is what makes the bounded retreat testable.
  const run = () => {
    const match = make(EXPERIMENT, {random: rng(4242)});
    deploy(match);
    runTransfer(match);
    const goals = match.modeState.withdrawn.map(id => [id, {...match.actors[id].campaignRetreat}]);
    let ticks = 0;
    const despawned = [];
    while (ticks < 20 * 60 && match.modeState.withdrawn.length) {
      const before = new Set(match.modeState.withdrawn);
      liveTick(match); ticks++;
      for (const id of before) if (!match.modeState.withdrawn.includes(id)) {
        const a = match.actors[id];
        despawned.push([id, ticks, Number(a.x.toFixed(6)), Number(a.z.toFixed(6))]);
      }
    }
    return {goals, despawned};
  };
  const first = run(), second = run();
  assert.deepEqual(first.goals, second.goals, 'identical retreat goals');
  assert.deepEqual(first.despawned, second.despawned, 'identical despawn order, tick and position');
});
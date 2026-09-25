// REQ field-equipment hydration (lane `port/lattice-hydrate-field-flash`).
//
// Out of `at-mine`, `barrier` and `sentry`, only `sentry` has a shipped,
// deterministic simulation seam in this worktree: the core deployable turret
// (`Match.deploySentry` / `stepDeployables`, `SENTRY` table in `core.mjs`) with
// real health, damage, expiry and enemy counterplay. The REQ row therefore
// reuses that shipped turret and authors only the bounded rent window and the
// one-live-per-operator bound. `at-mine`/`barrier` stay unlaunched: they would
// need new collision/proximity mechanics that this slice does not author.
//
// Truth rule (WP1.3 / COCS-MODE-SPEC §6A.5): a launched row must move
// authoritative world state through the real `Match.step` buy path, debit
// exactly its cost, and never be a paid no-op. Provenance and the pinned-source
// deviation: port/native-lattice/flagship/catalog/FIELD.md.
import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from './core.mjs';
import {RULES} from './data.mjs';
import {applySentry, cocsBuyAction} from './cocs.mjs';
import {coopBuyAction} from './cocs-coop.mjs';
import {
  REQ_MODE_IDS, SENTRY_EFFECT, reqItem, reqItemSupported, reqPurchase,
  reqPurchaseOptions, sentryDeployment,
} from './cocs-economy.mjs';

const DT = RULES.dt;
const mulberry32 = seed => {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};
// Shipped arena construction: OPERATIONS runs on `lattice-slice`.
const pvpMatch = (over = {}) => new Match('chatgpt', 'openclaw', mulberry32(11), 'warfront', {mode: 'cocs', botCount: 2, humanCount: 4, aiSeats: true, timeLimit: 300, ...over});
const coopMatch = (over = {}) => new Match('chatgpt', 'openclaw', mulberry32(7), 'lattice-slice', {mode: 'cocs-coop', botCount: 2, humanCount: 4, aiSeats: true, timeLimit: 900, ...over});
// One fixed step carrying the buy exactly as the wire path does.
const buy = (match, actor, itemId, extra = {}) => {
  const state = match.objectiveState;
  match.step(DT, {cocs: {buys: [{tick: state.tick, peerId: 'p1', cardId: `buy-${itemId}`, actorId: actor.id, itemId, ...extra}]}});
};
// The five floating-point stat fields of one deployable, so a REQ sentry can be
// proven identical to the shipped economy-pickup turret (which is not exported).
const sentryStats = entry => ({health: entry.health, range: entry.range, damage: entry.damage, interval: entry.interval, team: entry.team});
// A reference turret dropped through the shipped economy pickup seam (18 s).
const referenceSentry = match => {
  const actor = match.actors[0];
  assert.equal(match.collect(actor, {kind: 'deployable', x: actor.x, z: actor.z, y: actor.y, wait: 0}), true, 'the economy pickup seam drops a reference turret');
  return match.deployables[match.deployables.length - 1];
};
const offeredIds = (mode, match) => reqPurchaseOptions({team: 0, mode, actor: match.actors[0], state: match.objectiveState})
  .items.filter(entry => entry.modes.includes(mode)).map(entry => entry.id);

test('the source table launches only the supportable sentry fortification, in both modes', () => {
  const sentry = reqItem('sentry');
  assert.equal(sentry.launch, true, 'the sentry row is launched');
  assert.equal(sentry.coopLaunch, undefined, 'launch (not coopLaunch) covers both wire modes');
  assert.equal(sentry.cost, 60, 'the cost is unchanged');
  assert.equal(sentry.category, 'fortification');
  assert.equal(sentry.personalBuff, false, 'a turret is not a personal buff');
  assert.equal(sentry.target, 'ground');
  assert.deepEqual(sentry.effect, SENTRY_EFFECT, 'the row points at the one authored effect descriptor');
  assert.deepEqual([...sentry.modes], ['cocs', 'cocs-coop']);
  assert.equal(typeof sentry.effectCopy, 'string');
  assert.ok(sentry.effectCopy.length > 0, 'the row carries player-facing copy');
  assert.equal(reqItemSupported('sentry', REQ_MODE_IDS.pvp), true);
  assert.equal(reqItemSupported('sentry', REQ_MODE_IDS.coop), true);
  assert.equal(reqPurchase('sentry', {balance: 60}).ok, true);
  assert.equal(reqPurchase('sentry', {balance: 59.999}).reason, 'insufficient-req');

  for (const [mode, make] of [[REQ_MODE_IDS.pvp, pvpMatch], [REQ_MODE_IDS.coop, coopMatch]]) {
    const offered = offeredIds(mode, make());
    assert.ok(offered.includes('sentry'), `${mode}: the picker offers the launched sentry`);
    assert.ok(!offered.includes('at-mine') && !offered.includes('barrier'), `${mode}: the unlaunched fortifications stay unoffered`);
  }

  // The one pure deployment gate is shared: on foot it is legal, mounted it is
  // `no-target`, and owning a live sentry is a refresh rather than a refusal.
  assert.deepEqual({...sentryDeployment({id: 0, health: 100, vehicleId: null}, [])}, {ok: true, reason: null, duration: 30, limit: 1, refresh: false, live: 0});
  assert.equal(sentryDeployment({id: 0, health: 100, vehicleId: 9}, []).reason, 'no-target');
  assert.equal(sentryDeployment({id: 0, health: 0, vehicleId: null}, []).reason, 'no-target');
  assert.equal(sentryDeployment({id: 0, health: 100, vehicleId: null}, [{owner: 0, health: 80, life: 5}]).refresh, true);
  assert.equal(sentryDeployment({id: 0, health: 100, vehicleId: null}, [{owner: 1, health: 80, life: 5}]).refresh, false, 'another operator\'s turret never counts');
  assert.deepEqual({...sentryDeployment({id: 0, health: 100, vehicleId: null}, [{owner: 0, health: 0, life: 5}])}, {ok: true, reason: null, duration: 30, limit: 1, refresh: false, live: 0}, 'a downed turret frees the slot');

  // The pure picker surfaces the same gate as a disabled reason.
  const mounted = reqPurchaseOptions({team: 0, mode: 'cocs', actor: {id: 0, req: 200, reqBuff: null, vehicleId: 3}, state: {command: {seat: [null, null]}, nodes: []}});
  assert.equal(mounted.items.find(item => item.id === 'sentry').disabledReason, 'no-target');
  const onFoot = reqPurchaseOptions({team: 0, mode: 'cocs', actor: {id: 0, req: 200, reqBuff: null, vehicleId: null}, state: {command: {seat: [null, null]}, nodes: []}});
  assert.equal(onFoot.items.find(item => item.id === 'sentry').enabled, true);
});

test('a sentry buy deploys the shipped core turret through the real step in PvPvE and OPERATIONS', () => {
  for (const [mode, make] of [[REQ_MODE_IDS.pvp, pvpMatch], [REQ_MODE_IDS.coop, coopMatch]]) {
    const match = make();
    const state = match.objectiveState;
    const actor = match.actors[0];
    actor.req = 500; actor.reqSpent = 0; actor.reqBuff = undefined;
    actor.vehicleId = null;
    assert.equal(match.deployables.length, 0);
    buy(match, actor, 'sentry');

    assert.equal(match.deployables.length, 1, `${mode}: the buy deploys exactly one turret`);
    const sentry = match.deployables[0];
    assert.equal(sentry.owner, actor.id, `${mode}: the buyer owns the turret`);
    assert.equal(sentry.team, actor.team === 1 ? 1 : 0, `${mode}: the turret carries the buyer's team`);
    assert.equal(sentry.life, SENTRY_EFFECT.duration, `${mode}: the authored ${SENTRY_EFFECT.duration} s window is applied`);
    assert.ok(sentry.health > 0 && sentry.range > 0 && sentry.damage > 0 && sentry.interval > 0, `${mode}: the turret is armed`);

    assert.equal(actor.req, 500 - 60, `${mode}: the exact 60 REQ is debited`);
    assert.equal(actor.reqSpent, 60, `${mode}: the spend is recorded once`);
    assert.equal(actor.reqBuff, undefined, `${mode}: a turret never occupies the personal buff slot`);
    if (state.coop) {
      assert.equal(state.coop.buyLog.filter(entry => entry.itemId === 'sentry').length, 1, 'OPERATIONS logs one authoritative purchase');
    }

    // The wire shape is the untouched shipped sentry shape, so existing
    // render/quantize/counterplay paths keep working without change.
    assert.deepEqual(Object.keys(match.snapshot().deployables[0]).sort(), ['cooldown', 'damage', 'health', 'id', 'interval', 'life', 'owner', 'range', 'team', 'x', 'y', 'z'], `${mode}: the sentry snapshot shape is unchanged`);

    // Provenance: the REQ turret is stat-identical to the shipped economy pickup
    // turret, differing only in the authored REQ window.
    const reference = referenceSentry(make());
    assert.deepEqual(sentryStats(sentry), sentryStats(reference), `${mode}: the REQ sentry is the shipped core turret, not a new entity`);
    assert.notEqual(reference.life, SENTRY_EFFECT.duration, `${mode}: only the rent window is authored by REQ`);
  }
});

test('a re-buy refreshes the live sentry instead of stacking (idempotent and bounded)', () => {
  for (const [mode, make] of [[REQ_MODE_IDS.pvp, pvpMatch], [REQ_MODE_IDS.coop, coopMatch]]) {
    const match = make();
    const state = match.objectiveState;
    const actor = match.actors[0];
    actor.req = 500; actor.reqSpent = 0; actor.reqBuff = undefined; actor.vehicleId = null;
    buy(match, actor, 'sentry');
    const firstId = match.deployables[0].id;

    // Age the turret, then buy again: the same turret comes back to full life.
    match.deployables[0].life = 5;
    buy(match, actor, 'sentry');
    assert.equal(match.deployables.length, 1, `${mode}: no second turret stacks`);
    assert.equal(match.deployables[0].id, firstId, `${mode}: the live turret is the one refreshed`);
    assert.equal(match.deployables[0].life, SENTRY_EFFECT.duration, `${mode}: the window is restored to the authored bound`);
    assert.equal(actor.req, 500 - 120, `${mode}: both buys debit exactly once`);
    assert.equal(actor.reqSpent, 120, `${mode}: both spends are recorded`);

    // Direct applier idempotency: applying again converges, never compounds.
    const applied = applySentry(match, state, actor, SENTRY_EFFECT);
    assert.equal(applied.ok, true);
    assert.equal(applied.refresh, true, `${mode}: the third apply is a refresh`);
    assert.equal(match.deployables.length, 1, `${mode}: apply is idempotent`);

    // A destroyed turret frees the slot for a genuinely new deployment.
    match.damageDeployable(match.deployables[0], 100000, match.actors.find(entry => entry && entry.team !== actor.team));
    assert.equal(match.deployables.length, 0, `${mode}: enemy fire can destroy the turret`);
    buy(match, actor, 'sentry');
    assert.equal(match.deployables.length, 1, `${mode}: a fresh deployment after a kill is allowed`);
  }
});

test('the sentry is a real bounded effect: it fires, expires on its own and is damageable', () => {
  const match = pvpMatch();
  const state = match.objectiveState;
  const actor = match.actors[0];
  actor.req = 500; actor.reqSpent = 0; actor.reqBuff = undefined; actor.vehicleId = null;
  // Isolate one living enemy next to the buyer so only the turret can act.
  const enemy = match.actors.find(entry => entry && entry.team !== actor.team && entry.health > 0);
  const allies = match.actors.filter(entry => entry && entry.id !== actor.id && entry.team === actor.team);
  for (const other of match.actors) if (other && other.id !== actor.id && other.id !== enemy.id) other.health = 0;
  enemy.health = 100; enemy.armor = 0; enemy.protection = 0;
  enemy.x = actor.x + 5; enemy.z = actor.z; enemy.y = actor.y;
  for (const ally of allies) { ally.x = actor.x + 500; ally.z = actor.z + 500; }

  buy(match, actor, 'sentry');
  const sentry = match.deployables[0];
  const healthBefore = enemy.health;
  const eventsBefore = match.events.filter(event => event.type === 'deployable-fire').length;
  for (let i = 0; i < 120; i++) match.step(DT);
  assert.ok(enemy.health < healthBefore, 'the turret damages the visible enemy (a world change beyond the spawn)');
  assert.ok(match.events.filter(event => event.type === 'deployable-fire').length > eventsBefore, 'the turret emits its fire beat');

  // Bounded: when its authored window runs out the turret is removed.
  const live = match.deployables[0];
  assert.ok(live, 'the turret is still alive inside its window');
  live.life = DT;
  match.step(DT);
  assert.equal(match.deployables.some(entry => entry.id === sentry.id), false, 'the turret expires at the end of its window');
});

test('a mounted operator is refused no-target before any REQ moves or any turret spawns', () => {
  for (const [mode, make] of [[REQ_MODE_IDS.pvp, pvpMatch], [REQ_MODE_IDS.coop, coopMatch]]) {
    const match = make();
    const state = match.objectiveState;
    const actor = match.actors[0];
    actor.req = 500; actor.reqSpent = 0; actor.reqBuff = undefined;
    actor.vehicleId = 7; // any live hull id: a turret dropped from a vehicle would ride it
    buy(match, actor, 'sentry');
    assert.equal(actor.req, 500, `${mode}: a mounted buy never debits`);
    assert.equal(actor.reqSpent, 0, `${mode}: a mounted buy records no spend`);
    assert.equal(match.deployables.length, 0, `${mode}: a mounted buy deploys nothing`);
    if (state.coop) assert.equal((state.coop.buyLog ?? []).length, 0, `${mode}: no OPERATIONS buy log entry`);
    const direct = state.coop
      ? coopBuyAction(match, state, {actorId: actor.id, peerId: 'p1', itemId: 'sentry'})
      : cocsBuyAction(match, state, {actorId: actor.id, peerId: 'p1', itemId: 'sentry'});
    assert.equal(direct.ok, false);
    assert.equal(direct.reason, 'no-target');
  }
});

test('a world change between precheck and apply refunds the exact cost and leaves no turret', () => {
  for (const [mode, make, apply] of [[REQ_MODE_IDS.pvp, pvpMatch, cocsBuyAction], [REQ_MODE_IDS.coop, coopMatch, coopBuyAction]]) {
    const match = make();
    const state = match.objectiveState;
    const actor = match.actors[0];
    actor.req = 500; actor.reqSpent = 0; actor.reqBuff = 'overshield'; actor.vehicleId = null;
    // Simulate the deploy seam failing after the debit (e.g. a future core
    // guard). `applySentry` must refund in full and restore the buff slot.
    match.deploySentry = () => false;
    const result = apply(match, state, {actorId: actor.id, peerId: 'p1', itemId: 'sentry'});
    assert.equal(result.ok, false, `${mode}: the failed apply is refused`);
    assert.equal(result.reason, 'no-target');
    assert.equal(actor.req, 500, `${mode}: the exact 60 REQ is refunded`);
    assert.equal(actor.reqSpent, 0, `${mode}: the spend is rolled back`);
    assert.equal(actor.reqBuff, 'overshield', `${mode}: the pre-existing buff slot is restored`);
    assert.equal(match.deployables.length, 0, `${mode}: no turret is left behind`);
    if (state.coop) assert.equal((state.coop.buyLog ?? []).length, 0, `${mode}: no OPERATIONS buy log entry`);
  }
});

test('at-mine and barrier stay unlaunched: no collision, proximity or nav mechanic was authored', () => {
  for (const id of ['at-mine', 'barrier']) {
    const item = reqItem(id);
    assert.equal(item.launch, false, `${id} stays unlaunched`);
    assert.equal(item.coopLaunch, undefined);
    assert.deepEqual([...item.modes], [], `${id} is offered in no mode`);
    assert.equal(reqItemSupported(id, REQ_MODE_IDS.pvp), false);
    assert.equal(reqItemSupported(id, REQ_MODE_IDS.coop), false);
    assert.equal(reqPurchase(id, {balance: 1000}).reason, 'not-launched');
    for (const [mode, make, apply] of [[REQ_MODE_IDS.pvp, pvpMatch, cocsBuyAction], [REQ_MODE_IDS.coop, coopMatch, coopBuyAction]]) {
      const match = make();
      const state = match.objectiveState;
      const actor = match.actors[0];
      actor.req = 500; actor.reqSpent = 0; actor.reqBuff = undefined;
      buy(match, actor, id);
      assert.equal(actor.req, 500, `${mode}: ${id} never debits`);
      assert.equal(match.deployables.length, 0, `${mode}: ${id} spawns nothing`);
      assert.equal((state.coop?.buyLog ?? []).length, 0, `${mode}: ${id} leaves no OPERATIONS buy log`);
      assert.equal(apply(match, state, {actorId: actor.id, peerId: 'p1', itemId: id}).reason, 'not-launched', `${mode}: ${id} is refused before the debit`);
    }
  }
});

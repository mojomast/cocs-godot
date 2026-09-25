// Commander/team REQ slice (WP1.3): the Recon Pulse row, its real commander
// seat gate, its team-private information effect and its negative paths —
// driven through the real `Match.step` buy path and the real `Room.buy` gate in
// both wire modes (`cocs` PvPvE and `cocs-coop` OPERATIONS).
//
// Scope: `game/cocs-economy.mjs`, `game/cocs.mjs`, `game/cocs-coop.mjs`,
// `server/room.mjs`. Design authority: COCS-MODE-SPEC §6A.5 (catalogue),
// §8.1 (SPOT/field recon) and §11.3/§11.4 (per-team visibility).
import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from './core.mjs';
import {RULES} from './data.mjs';
import {cocsBuyAction, cocsSpotDamageScale, cocsTeamVisibility} from './cocs.mjs';
import {coopBuyAction} from './cocs-coop.mjs';
import {filterCocsSnapshot} from './cocs-intel.mjs';
import {
 RECON_PULSE_EFFECT, REQ_MODE_IDS, reconPulseTargets, reqItem, reqItemSupported, reqPurchase, reqPurchaseOptions,
} from './cocs-economy.mjs';
import {Room} from '../server/room.mjs';

const DT = RULES.dt;
const teamOf = actor => (actor.team === 1 ? 1 : 0);
const otherTeam = team => 1 - team;
const find = (msgs, type, to) => msgs.find(m => m.msg.type === type && (to === undefined || m.to === to))?.msg;
const mulberry32 = seed => {
 let a = seed >>> 0;
 return () => {
  a |= 0; a = (a + 0x6D2B79F5) | 0;
  let t = Math.imul(a ^ (a >>> 15), 1 | a);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
 };
};
const seeded = seed => {
 let n = seed;
 return () => ((n = (Math.imul(n, 1664525) + 1013904223) >>> 0) / 4294967296);
};
// Shipped arena construction (mirrors game/cocs-req-effects.test.mjs).
const pvpMatch = (over = {}) => new Match('chatgpt', 'openclaw', mulberry32(11), 'warfront', {mode: 'cocs', botCount: 2, humanCount: 4, aiSeats: true, timeLimit: 300, ...over});
const coopMatch = (over = {}) => new Match('chatgpt', 'openclaw', mulberry32(7), 'lattice-slice', {mode: 'cocs-coop', botCount: 2, humanCount: 4, aiSeats: true, timeLimit: 900, ...over});
// Author the commander seat exactly as the wire does: keyed by `String(actor.id)`
// (the `peerId` mapping), in the PvP `state.command` board or the OPERATIONS
// `state.coop` board.
const seatCommander = (state, actor) => {
 // A real commander seat is a human operator. The local harness spawns every
 // seat as a bot, so mark the buyer human first (the room path does not need
 // this: a joined peer is human by construction).
 actor.bot = null; actor.isNpc = false; actor.spectate = false;
 const team = teamOf(actor);
 if (state.coop) state.coop.commandSeat[team] = String(actor.id);
 else state.command.seat[team] = String(actor.id);
};
const livingEnemies = (match, actor) => match.actors.filter(entry => entry && entry.team === otherTeam(teamOf(actor)) && entry.health > 0);
const buyFrame = (state, actor, cardId) => ({tick: state.tick, peerId: String(actor.id), cardId, actorId: actor.id, itemId: 'recon-pulse'});
// Only the marks this buyer's purchase would own, so unrelated bot recon during
// the same step cannot make a negative-case assertion flaky.
const pulseFootprint = (state, actor) => {
 const team = teamOf(actor);
 const intel = Object.entries(state.fieldSupport?.intel?.[team] ?? {}).filter(([, entry]) => entry?.by === actor.id).map(([id]) => id).sort((a, b) => a - b);
 const spots = Object.entries(state.spots ?? {}).filter(([, entry]) => entry?.by === actor.id).map(([id]) => id).sort((a, b) => a - b);
 return JSON.stringify({intel, spots, req: actor.req, spent: actor.reqSpent});
};

test('Recon Pulse is a launched, commander-only, team-wide row in both wire modes', () => {
 const item = reqItem('recon-pulse');
 assert.equal(item.launch, true, 'the row ships its effect, so it launches');
 assert.equal(item.coopLaunch, undefined, 'no mode-local coop flag');
 assert.equal(item.teamWide, true);
 assert.equal(item.commanderOnly, true);
 assert.equal(item.personalBuff, false, 'a team row never occupies the personal buff slot');
 assert.equal(item.effect, RECON_PULSE_EFFECT);
 assert.equal(item.effect.kind, 'recon-pulse');
 assert.equal(typeof item.effectCopy, 'string');
 assert.ok(item.effectCopy.length > 0, 'the row carries player-facing copy');
 assert.deepEqual([...item.modes], ['cocs', 'cocs-coop']);
 assert.equal(reqItemSupported('recon-pulse', REQ_MODE_IDS.pvp), true);
 assert.equal(reqItemSupported('recon-pulse', REQ_MODE_IDS.coop), true);
 assert.equal(reqPurchase('recon-pulse', {balance: 1000, isCommander: false}).reason, 'commander-only');
 assert.equal(reqPurchase('recon-pulse', {balance: 59, isCommander: true}).reason, 'insufficient-req');
 const ok = reqPurchase('recon-pulse', {balance: 60, isCommander: true});
 assert.equal(ok.ok, true);
 assert.equal(ok.balanceAfter, 0, 'the exact 60 REQ cost is debited');
 assert.ok(!Object.hasOwn(ok, 'flux') && !Object.hasOwn(ok, 'reserve'), 'a team purchase never touches FLUX/RESERVE');

 // The pure selector is id-sorted and skips allies, the dead and the cloaked.
 const actors = [
  {id: 5, team: 1, health: 100, x: 0, z: 0},
  {id: 2, team: 1, health: 100, x: 0, z: 0},
  {id: 1, team: 0, health: 100, x: 0, z: 0},
  {id: 3, team: 1, health: 0, x: 0, z: 0},
  {id: 4, team: 1, health: 100, x: 0, z: 0, powerups: {cloak: 9}},
 ];
 assert.deepEqual([...reconPulseTargets({id: 0, team: 0, health: 100, x: 0, z: 0}, actors)], [2, 5], 'only living, uncloaked enemies are revealable, id-sorted');
 assert.deepEqual([...reconPulseTargets({id: 0, team: 0, health: 0, x: 0, z: 0}, actors)], [], 'a dead buyer reveals nothing');
});

test('a seated commander buys Recon Pulse in both modes and only the buyer team receives the intel', () => {
 for (const [label, make] of [['PvPvE', pvpMatch], ['OPERATIONS', coopMatch]]) {
  const match = make();
  const state = match.objectiveState;
  const actor = match.actors[0];
  const team = teamOf(actor);
  const mode = state.coop ? REQ_MODE_IDS.coop : REQ_MODE_IDS.pvp;
  seatCommander(state, actor);
  actor.req = 500; actor.reqSpent = 0; actor.reqBuff = 'overshield';
  const enemies = livingEnemies(match, actor);
  assert.ok(enemies.length > 0, `${label}: the match has a living enemy to reveal`);
  assert.equal(state.coop ? state.coop.commandSeat[team] : state.command.seat[team], String(actor.id), `${label}: the seat uses the actor id mapping`);

  const option = reqPurchaseOptions({team, mode, actor, state}).items.find(entry => entry.id === 'recon-pulse');
  assert.equal(option.enabled, true, `${label}: the commander menu offers the row`);
  assert.equal(option.disabledReason, null);

  // A deterministic twin without the buy: the only difference is the purchase,
  // so any FLUX/RESERVE/wallet delta on other actors would be the pulse's.
  const control = make();
  seatCommander(control.objectiveState, control.actors[0]);
  control.actors[0].req = 500; control.actors[0].reqSpent = 0; control.actors[0].reqBuff = 'overshield';
  control.step(DT);
  match.step(DT, {cocs: {buys: [buyFrame(state, actor, 'recon-ok')]}});

  assert.equal(actor.req, 440, `${label}: the exact 60 REQ cost is debited`);
  assert.equal(actor.reqSpent, 60, `${label}: the spend is recorded once`);
  assert.equal(actor.reqBuff, 'overshield', `${label}: a team row never evicts a live personal buff`);

  for (const enemy of enemies) {
   const intel = state.fieldSupport?.intel?.[team]?.[enemy.id];
   assert.ok(intel, `${label}: enemy ${enemy.id} is revealed to the buyer team`);
   assert.ok(intel.until > state.tick, `${label}: the reveal outlives the purchase tick`);
   assert.equal(state.fieldSupport.intel[otherTeam(team)]?.[enemy.id], undefined, `${label}: the other team gets no intel`);
   const spot = state.spots?.[enemy.id];
   assert.ok(spot && spot.intelOnly === true, `${label}: the contact is an information-only mark`);
   assert.equal(spot.team, team, `${label}: the mark belongs to the buyer team`);
   assert.equal(cocsSpotDamageScale(match, actor, enemy), 1, `${label}: recon pays no §8.1 damage bonus`);
  }

  // Per-team visibility: the buyer's team sees the reveal, the enemy view does not.
  const ownContacts = cocsTeamVisibility(match, state, team).contacts.filter(entry => enemies.some(enemy => enemy.id === entry.id));
  assert.ok(ownContacts.length > 0 && ownContacts.every(entry => entry.revealed === true), `${label}: the buyer team sees revealed contacts`);
  const enemyContacts = cocsTeamVisibility(match, state, otherTeam(team)).contacts.filter(entry => enemies.some(enemy => enemy.id === entry.id));
  assert.ok(enemyContacts.every(entry => entry.revealed !== true), `${label}: the enemy view has no reveal`);

  // Wire isolation: the other team's filtered snapshot never carries the buyer intel.
  const filtered = filterCocsSnapshot(match.snapshot(), otherTeam(team));
  assert.equal(Object.hasOwn(filtered.cocs.fieldSupport.intel, String(team)), false, `${label}: the other team's wire has no buyer intel map`);
  assert.deepEqual(filtered.cocs.spots.filter(spot => spot.team === team), [], `${label}: the other team's wire has no buyer mark`);

  // The REQ firewall: no FLUX/RESERVE moved and no other wallet changed. The
  // twin match proves the delta is the purchase's, not ordinary step income.
  assert.equal(JSON.stringify(state.flux ?? null), JSON.stringify(control.objectiveState.flux ?? null), `${label}: the pulse moves no team FLUX`);
  assert.equal(JSON.stringify(state.reserve ?? null), JSON.stringify(control.objectiveState.reserve ?? null), `${label}: the pulse moves no RESERVE`);
  for (const entry of match.actors) {
   if (!entry || entry.id === actor.id) continue;
   const twin = control.actors.find(other => other && other.id === entry.id);
   assert.equal(entry.req, twin?.req, `${label}: actor ${entry.id} wallet is untouched by the purchase`);
  }
 }
});

test('an unauthorized, seat-stolen, cloaked or dead Recon Pulse is refused inertly in both modes', () => {
 for (const [label, make] of [['PvPvE', pvpMatch], ['OPERATIONS', coopMatch]]) {
  const match = make();
  const state = match.objectiveState;
  const actor = match.actors[0];
  const team = teamOf(actor);
  const mode = state.coop ? REQ_MODE_IDS.coop : REQ_MODE_IDS.pvp;
  const buyDirect = () => (state.coop
   ? coopBuyAction(match, state, {actorId: actor.id, peerId: String(actor.id), itemId: 'recon-pulse'})
   : cocsBuyAction(match, state, {actorId: actor.id, peerId: String(actor.id), itemId: 'recon-pulse'}));

  // (a) No commander seat: commander-only before any debit.
  actor.req = 500; actor.reqSpent = 0; actor.reqBuff = undefined;
  const beforeA = pulseFootprint(state, actor);
  match.step(DT, {cocs: {buys: [buyFrame(state, actor, 'recon-no-seat')]}});
  assert.equal(actor.req, 500, `${label}: an unauthorized buy never debits`);
  assert.equal(actor.reqSpent, 0, `${label}: an unauthorized buy records no spend`);
  assert.equal(pulseFootprint(state, actor), beforeA, `${label}: an unauthorized buy writes no pulse state`);
  assert.equal(buyDirect().reason, 'commander-only', `${label}: the sim names the seat gate`);
  assert.equal(reqPurchaseOptions({team, mode, actor, state}).items.find(entry => entry.id === 'recon-pulse').disabledReason, 'commander-only', `${label}: the menu is disabled without a seat`);

  // (b) A different actor on the same team holds the seat: still refused.
  const ally = match.actors.find(entry => entry && entry.id !== actor.id && entry.team === actor.team);
  assert.ok(ally, `${label}: the roster has an ally`);
  if (state.coop) state.coop.commandSeat[team] = String(ally.id); else state.command.seat[team] = String(ally.id);
  assert.equal(buyDirect().reason, 'commander-only', `${label}: only the exact seated actor may buy`);

  // (c) Seated, but every enemy is cloaked: `no-target`, inert.
  seatCommander(state, actor);
  for (const enemy of match.actors) {
   if (!enemy || enemy.team !== otherTeam(team)) continue;
   enemy.health = Math.max(1, Number(enemy.health) || 100);
   enemy.powerups = {...(enemy.powerups ?? {}), cloak: 999};
  }
  const beforeC = pulseFootprint(state, actor);
  match.step(DT, {cocs: {buys: [buyFrame(state, actor, 'recon-cloaked')]}});
  assert.equal(actor.req, 500, `${label}: a cloaked-only pulse never debits`);
  assert.equal(actor.reqSpent, 0);
  assert.equal(pulseFootprint(state, actor), beforeC, `${label}: a cloaked-only pulse writes no pulse state`);
  assert.equal(buyDirect().reason, 'no-target', `${label}: the sim names the target gate`);

  // (d) Seated, but every enemy is dead: `no-target`, inert.
  for (const enemy of match.actors) if (enemy && enemy.team === otherTeam(team)) enemy.health = 0;
  assert.equal(buyDirect().reason, 'no-target', `${label}: a dead-only pulse is a no-op`);
  assert.equal(pulseFootprint(state, actor), beforeC, `${label}: a dead-only pulse writes no pulse state`);
  assert.equal(actor.req, 500, `${label}: still no debit`);
 }
});

test('a fully covered same-tick Recon Pulse refuses without a second debit', () => {
 for (const make of [pvpMatch, coopMatch]) {
  const match = make();
  const state = match.objectiveState;
  const actor = match.actors[0];
  actor.req = 500; actor.reqSpent = 0;
  seatCommander(state, actor);
  const purchase = () => state.coop
   ? coopBuyAction(match, state, {actorId: actor.id, peerId: String(actor.id), itemId: 'recon-pulse'})
   : cocsBuyAction(match, state, {actorId: actor.id, peerId: String(actor.id), itemId: 'recon-pulse'});
  assert.equal(purchase().ok, true);
  const balance = actor.req;
  assert.equal(reconPulseTargets(actor, match.actors, RECON_PULSE_EFFECT, state).length, 0);
  assert.equal(purchase().reason, 'no-target');
  assert.equal(actor.req, balance);
  assert.equal(actor.reqSpent, 60);
 }
});

test('Room.buy gates Recon Pulse on the real commander seat and a legal target before queueing', () => {
 const room = new Room('rc', seeded(43), {snapshotHz: 30, keyframeEvery: 5});
 room.join(1, 'Alice', 'chatgpt', 'openclaw');
 room.join(2, 'Bob', 'claude', 'hermes');
 room.host(1, {mode: 'cocs-coop', botCount: 4, timeLimit: 900}, 'warfront');
 room.start(1);
 room.drain();
 const state = room.match.objectiveState;
 const actor = room.match.actors[0];
 const team = teamOf(actor);
 const rev = room.roundRevision;
 actor.req = 200; actor.reqSpent = 0; actor.reqBuff = undefined;

 // Unauthorized: no seat yet, refused commander-only and never queued.
 assert.equal(room.buy(1, {cardId: 'recon-no-seat', itemId: 'recon-pulse', roundRev: rev, actionSeq: 1}, 1000), false);
 assert.equal(find(room.drain(), 'cocs-reject', 1)?.reason, 'commander-only');
 assert.equal(actor.req, 200, 'an unauthorized buy never debits');
 assert.equal(room.pendingCocs.buys.length, 0, 'a refused buy never reaches the queue');

 // Take the seat through the real command handler; the key is the actor id.
 assert.equal(room.command(1, {cardId: 'recon-take', action: 'take', roundRev: rev, actionSeq: 2}, 2000), true);
 for (let i = 0; i < 3; i++) room.tick(DT);
 assert.equal(state.coop.commandSeat[team], String(actor.id), 'the seat uses the in-sim actor id (peerId mapping)');
 room.drain();

 // No legal target: every enemy cloaked. Refused before queueing or debit.
 for (const enemy of room.match.actors) {
  if (!enemy || enemy.team !== otherTeam(team)) continue;
  enemy.health = Math.max(1, Number(enemy.health) || 100);
  enemy.powerups = {...(enemy.powerups ?? {}), cloak: 999};
 }
 assert.equal(room.buy(1, {cardId: 'recon-cloaked', itemId: 'recon-pulse', roundRev: rev, actionSeq: 3}, 3000), false);
 assert.equal(find(room.drain(), 'cocs-reject', 1)?.reason, 'no-target');
 assert.equal(actor.req, 200, 'a target-less pulse never debits');
 assert.equal(room.pendingCocs.buys.length, 0);

 // Legal target: uncloak one enemy, buy accepted, queued once, settled by the sim.
 const enemy = room.match.actors.find(entry => entry && entry.team === otherTeam(team) && entry.health > 0);
 enemy.powerups = {...(enemy.powerups ?? {}), cloak: 0};
 assert.equal(room.buy(1, {cardId: 'recon-ok', itemId: 'recon-pulse', roundRev: rev, actionSeq: 4}, 4000), true);
 assert.equal(room.pendingCocs.buys.length, 1, 'the legal pulse is queued once');
 for (let i = 0; i < 3; i++) room.tick(DT);
 assert.equal(actor.req, 140, 'the exact 60 REQ is debited');
 assert.equal(actor.reqSpent, 60, 'the spend is recorded once');
 assert.ok(state.fieldSupport?.intel?.[team]?.[enemy.id], 'the room buy reveals the enemy to the buyer team');
 assert.equal(state.fieldSupport.intel[otherTeam(team)]?.[enemy.id], undefined, 'the other team gets no intel');
 assert.equal((state.coop.buyLog ?? []).filter(entry => entry.itemId === 'recon-pulse').length, 1, 'one sim purchase applied');
 assert.equal(room.cocsCardList().find(card => card.id === 'recon-ok')?.state, 'done', 'the accepted buy settled from sim state');
});

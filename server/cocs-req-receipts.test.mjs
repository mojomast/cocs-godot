// Personal-REQ buy receipt settlement through the real Room -> Match.step path.
// Guards the two correctness holes the `reqBuff`/`reqSpent` heuristic and the
// actor/item/tick co-op scan left open:
//   * non-buff Spot Drone / Repair Tool preserve the active buff slot, so the
//     old PvP check never settled a successful equipment card;
//   * two same-cost or same-item cards in one tick cross-settled because the
//     evidence was not keyed by the exact action card.
// Every accepted card must settle only from its own receipt; a rechecked/refused
// target debits nothing and writes no success receipt.
import test from 'node:test';
import assert from 'node:assert/strict';
import {Room} from './room.mjs';
import {RULES} from '../game/data.mjs';

function seeded(seed = 11) {
 let n = seed;
 return () => ((n = (Math.imul(n, 1664525) + 1013904223) >>> 0) / 4294967296);
}
const cardOf = (room, id) => room.cocsCardList().find(card => card.id === id);
const receiptsFor = (state, cardId) => (state.buyLog ?? []).filter(entry => entry && String(entry.cardId) === String(cardId));

// An OPERATIONS room with two connected peers and bots filling (the N1 harness).
function coopHarness(seed = 11, botCount = 4) {
 const room = new Room('r', seeded(seed), { snapshotHz: 30, keyframeEvery: 5 });
 room.join(1, 'Alice', 'chatgpt', 'openclaw');
 room.join(2, 'Bob', 'claude', 'hermes');
 room.host(1, { mode: 'cocs-coop', botCount, timeLimit: 900 }, 'warfront');
 room.start(1);
 room.drain();
 return room;
}
// A PvPvE `cocs` practice room with bots filling.
function pvpHarness(seed = 67, botCount = 4) {
 const room = new Room('rp', seeded(seed), { snapshotHz: 30, keyframeEvery: 5 });
 room.join(1, 'Alice', 'chatgpt', 'openclaw');
 room.join(2, 'Bob', 'claude', 'hermes');
 room.host(1, { mode: 'cocs', botCount, timeLimit: 300 }, 'warfront');
 room.start(1);
 room.drain();
 return room;
}
function openCoopWindow(room, {req = 0} = {}) {
 const state = room.match.objectiveState;
 const front = state.nodes.find(node => node.archetype === 'front');
 front.owner = 0;
 state.coop.phase = 'intermission';
 state.coop.intermission = true;
 state.coop.intermissionOpen = true;
 state.coop.intermissionTicks = 99999;
 const actor = room.match.actors[0];
 if (req) actor.req = req;
 return {state, front, actor};
}

test('a PvPvE Spot Drone and Repair Tool settle their cards without occupying the buff slot', () => {
 const room = pvpHarness(101, 4);
 const state = room.match.objectiveState;
 const actor = room.match.actors[0];
 actor.req = 200; actor.reqSpent = 0; actor.reqBuff = undefined;
 state.reqMult = 0;
 const enemy = room.match.actors.find(entry => entry && entry.team !== actor.team && entry.health > 0);
 assert.ok(enemy, 'the practice match has a living enemy');
 enemy.x = actor.x; enemy.z = actor.z;
 room.drain();
 const rev = room.roundRevision;
 assert.equal(room.buy(1, {cardId: 'pvp-drone', itemId: 'spot-drone', roundRev: rev, actionSeq: 1}), true, 'a legal drone buy is accepted');
 for (let i = 0; i < 3; i++) room.tick(RULES.dt);
 assert.equal(actor.reqSpent, 45, 'the drone debited once');
 assert.equal(actor.reqBuff, undefined, 'the equipment never occupied the personal buff slot');
 assert.equal(receiptsFor(state, 'pvp-drone').length, 1, 'the sim wrote the exact card receipt');
 assert.equal(cardOf(room, 'pvp-drone')?.state, 'done', 'the successful PvP equipment card settles from its receipt');
 assert.equal(cardOf(room, 'pvp-drone')?.ok, true);

 const node = state.nodes.find(entry => ['front', 'economy', 'relay'].includes(entry.archetype));
 node.owner = actor.team === 1 ? 1 : 0;
 state.cuts = [node.id];
 actor.x = node.x; actor.z = node.z;
 assert.equal(room.buy(1, {cardId: 'pvp-repair', itemId: 'repair-tool', roundRev: rev, actionSeq: 2}), true, 'a legal repair buy is accepted');
 for (let i = 0; i < 3; i++) room.tick(RULES.dt);
 assert.equal(actor.reqSpent, 75, 'both equipment spends are recorded');
 assert.equal(state.cuts.includes(node.id), false, 'the repair restored the friendly cut link');
 assert.equal(cardOf(room, 'pvp-repair')?.state, 'done', 'the repair tool card settles from its own receipt');
});

test('two same-cost same-tick PvP buff buys settle only the card that applied', () => {
 const room = pvpHarness(103, 4);
 const state = room.match.objectiveState;
 const actor = room.match.actors[0];
 actor.req = 50; actor.reqSpent = 0; actor.reqBuff = undefined; // exactly one 50 REQ overshield
 state.reqMult = 0;
 room.drain();
 const rev = room.roundRevision;
 assert.equal(room.buy(1, {cardId: 'ov-a', itemId: 'overshield', roundRev: rev, actionSeq: 1}), true);
 assert.equal(room.buy(1, {cardId: 'ov-b', itemId: 'overshield', roundRev: rev, actionSeq: 2}), true, 'the room cannot yet see the sibling debit');
 for (let i = 0; i < 3; i++) room.tick(RULES.dt);
 assert.equal(actor.reqSpent, 50, 'exactly one overshield is charged');
 assert.equal((state.buyLog ?? []).filter(entry => entry.itemId === 'overshield').length, 1, 'one authoritative receipt for the applied card');
 const done = ['ov-a', 'ov-b'].map(id => cardOf(room, id)).filter(card => card?.state === 'done');
 assert.equal(done.length, 1, 'exactly one of the coincident same-cost cards settles');
 assert.equal(done[0].id, 'ov-a', 'the deterministic (tick, peer, cardId) winner settles');
 assert.notEqual(cardOf(room, 'ov-b')?.state, 'done', 'the unfunded sibling never cross-settles from the coincident receipt');
});

test('two same-item same-tick OPERATIONS buys never cross-settle from one buyLog entry', () => {
 const room = coopHarness(107, 4);
 const {state, actor} = openCoopWindow(room, {req: 40}); // exactly one 40 REQ field repair
 state.reqMult = 0;
 room.drain();
 const rev = room.roundRevision;
 assert.equal(room.buy(1, {cardId: 'fr-a', itemId: 'field-repair', roundRev: rev, actionSeq: 1}), true);
 assert.equal(room.buy(1, {cardId: 'fr-b', itemId: 'field-repair', roundRev: rev, actionSeq: 2}), true, 'the second frame still clears the pre-apply gate');
 for (let i = 0; i < 3; i++) room.tick(RULES.dt);
 assert.equal(actor.reqSpent, 40, 'exactly one field repair is charged');
 const log = (state.coop.buyLog ?? []).filter(entry => entry.itemId === 'field-repair');
 assert.equal(log.length, 1, 'one authoritative OPERATIONS purchase');
 assert.equal(log[0].cardId, 'fr-a', 'the presentation log is keyed by the applied card');
 const done = ['fr-a', 'fr-b'].map(id => cardOf(room, id)).filter(card => card?.state === 'done');
 assert.equal(done.length, 1, 'exactly one same-item card settles');
 assert.equal(done[0].id, 'fr-a');
 assert.notEqual(cardOf(room, 'fr-b')?.state, 'done', 'the refused sibling cannot reuse the same-item evidence');
});

test('a target that changes before apply is refused with no debit and no receipt', () => {
 const room = pvpHarness(109, 4);
 const state = room.match.objectiveState;
 const actor = room.match.actors[0];
 actor.req = 100; actor.reqSpent = 0; actor.reqBuff = undefined;
 state.reqMult = 0;
 const enemy = room.match.actors.find(entry => entry && entry.team !== actor.team && entry.health > 0);
 enemy.x = actor.x; enemy.z = actor.z;
 room.drain();
 const rev = room.roundRevision;
 assert.equal(room.buy(1, {cardId: 'pvp-recheck', itemId: 'spot-drone', roundRev: rev, actionSeq: 1}), true, 'the room gate sees the target');
 // The world changes between the room gate and the sim apply.
 enemy.x = actor.x + 1000; enemy.z = actor.z + 1000;
 for (let i = 0; i < 3; i++) room.tick(RULES.dt);
 assert.equal(actor.reqSpent ?? 0, 0, 'a recheck-refused buy never debits');
 assert.equal(receiptsFor(state, 'pvp-recheck').length, 0, 'no success receipt is written for the refused card');
 assert.notEqual(cardOf(room, 'pvp-recheck')?.state, 'done', 'the refused card is not presented as a success');
});

test('cocsBuyOutcome resolves only the exact card receipt', () => {
 const room = {match: {actors: {5: {id: 5, team: 0}, 6: {id: 6, team: 1}}}};
 const state = {buyLog: [
  {tick: 9, actor: 5, team: 0, itemId: 'field-repair', cost: 40, cardId: 'card-a'},
 ]};
 const outcome = (record, s = state) => Room.prototype.cocsBuyOutcome.call(room, record, s);
 assert.deepEqual(outcome({cardId: 'card-a', actorId: 5, itemId: 'field-repair'}), {state: 'done', ok: true, reason: null}, 'the owning card settles');
 assert.equal(outcome({cardId: 'card-b', actorId: 5, itemId: 'field-repair', createdTick: 9}), null, 'a coincident same-item sibling card has no receipt of its own');
 assert.equal(outcome({cardId: 'card-a', actorId: 6, itemId: 'field-repair'}), null, 'a different actor cannot claim the receipt');
 assert.equal(outcome({cardId: 'card-a', actorId: 5, itemId: 'haste'}), null, 'a different item cannot claim the receipt');
 assert.equal(outcome({cardId: null, actorId: 5, itemId: 'field-repair'}), null, 'a card without identity can never settle');
 assert.deepEqual(Room.prototype.cocsBuyOutcome.call({match: {actors: {}}}, {cardId: 'card-a', actorId: 5, itemId: 'field-repair'}, state), {state: 'blocked', ok: false, reason: 'missing'}, 'a missing actor blocks');
});

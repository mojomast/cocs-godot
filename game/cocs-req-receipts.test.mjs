// Personal-REQ buy receipts (WP1.3 follow-up): every successful PvPvE /
// OPERATIONS purchase must record an exact, bounded, idempotent receipt keyed by
// the action card id, and a refused/rechecked purchase must record none. The
// room settles its mirrored card from this receipt (`server/cocs-req-receipts`)
// instead of guessing from `reqBuff`/`reqSpent` or an actor/item/tick scan.
import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from './core.mjs';
import {RULES} from './data.mjs';
import {cocsBuyAction, recordCocsBuyReceipt, COCS_BUY_LOG_LIMIT} from './cocs.mjs';
import {coopBuyAction} from './cocs-coop.mjs';

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
const pvpMatch = (over = {}) => new Match('chatgpt', 'openclaw', mulberry32(11), 'warfront', {mode: 'cocs', botCount: 2, humanCount: 4, aiSeats: true, timeLimit: 300, ...over});
const coopMatch = (over = {}) => new Match('chatgpt', 'openclaw', mulberry32(7), 'lattice-slice', {mode: 'cocs-coop', botCount: 2, humanCount: 4, aiSeats: true, timeLimit: 900, ...over});
const receiptsFor = (state, cardId) => (state.buyLog ?? []).filter(entry => entry && String(entry.cardId) === String(cardId));

test('a PvPvE non-buff equipment buy records an exact receipt without touching reqBuff', () => {
 const match = pvpMatch();
 const state = match.objectiveState;
 const actor = match.actors[0];
 actor.req = 200; actor.reqSpent = 0; actor.reqBuff = undefined;
 state.reqMult = 0;

 const enemy = match.actors.find(entry => entry && entry.team !== actor.team && entry.health > 0);
 assert.ok(enemy, 'there is a living enemy to mark');
 enemy.x = actor.x; enemy.z = actor.z;
 const drone = cocsBuyAction(match, state, {tick: state.tick, peerId: 'p1', cardId: 'pvp-drone', actorId: actor.id, itemId: 'spot-drone'});
 assert.equal(drone.ok, true, 'the spot drone applies');
 assert.equal(actor.reqSpent, 45, 'the drone debits exactly its cost');
 assert.equal(actor.reqBuff, undefined, 'the non-buff equipment does not occupy the buff slot');
 const droneReceipt = receiptsFor(state, 'pvp-drone');
 assert.equal(droneReceipt.length, 1, 'exactly one receipt is written for the card');
 assert.deepEqual(
  {actor: droneReceipt[0].actor, itemId: droneReceipt[0].itemId, cost: droneReceipt[0].cost},
  {actor: actor.id, itemId: 'spot-drone', cost: 45},
  'the receipt names the actor, item and cost',
 );

 const node = state.nodes.find(entry => ['front', 'economy', 'relay'].includes(entry.archetype));
 node.owner = actor.team === 1 ? 1 : 0;
 state.cuts = [node.id];
 actor.x = node.x; actor.z = node.z;
 const repair = cocsBuyAction(match, state, {tick: state.tick, peerId: 'p1', cardId: 'pvp-repair', actorId: actor.id, itemId: 'repair-tool'});
 assert.equal(repair.ok, true, 'the repair tool applies');
 assert.equal(actor.reqSpent, 75, 'both equipment spends are recorded');
 assert.equal(receiptsFor(state, 'pvp-repair').length, 1, 'the repair tool gets its own receipt');
});

test('a refused purchase writes neither a receipt nor a spend', () => {
 const match = pvpMatch();
 const state = match.objectiveState;
 const actor = match.actors[0];
 actor.req = 0; actor.reqSpent = 0; actor.reqBuff = undefined;
 const refused = cocsBuyAction(match, state, {tick: state.tick, peerId: 'p1', cardId: 'pvp-broke', actorId: actor.id, itemId: 'field-repair'});
 assert.equal(refused.ok, false, 'an unaffordable buy is refused');
 assert.equal(actor.reqSpent, 0, 'no debit');
 assert.equal(receiptsFor(state, 'pvp-broke').length, 0, 'no success receipt for a refused card');
});

test('receipts are idempotent per card id and bounded', () => {
 const match = pvpMatch();
 const state = match.objectiveState;
 recordCocsBuyReceipt(state, {tick: 1, cardId: 'c1', actorId: 1, itemId: 'haste'}, {actor: 1, team: 0, itemId: 'haste', cost: 35});
 recordCocsBuyReceipt(state, {tick: 1, cardId: 'c1', actorId: 1, itemId: 'haste'}, {actor: 1, team: 0, itemId: 'haste', cost: 35});
 assert.equal(receiptsFor(state, 'c1').length, 1, 'the same card id can never double-log');
 assert.equal(state.buyLog.length, 1);
 recordCocsBuyReceipt(state, {tick: 2, cardId: 'c2', actorId: 1, itemId: 'overshield'}, {actor: 1, team: 0, itemId: 'overshield', cost: 50});
 assert.equal(state.buyLog.length, 2, 'a distinct card id logs separately');
 assert.equal(recordCocsBuyReceipt(state, {tick: 3, cardId: null, actorId: 1, itemId: 'haste'}, {actor: 1, team: 0, itemId: 'haste', cost: 35}), null, 'a card-less record is never receipted');
 assert.equal(state.buyLog.length, 2);
 for (let i = 0; i < COCS_BUY_LOG_LIMIT + 5; i++) {
  recordCocsBuyReceipt(state, {tick: 4 + i, cardId: `fill-${i}`, actorId: 1, itemId: 'haste'}, {actor: 1, team: 0, itemId: 'haste', cost: 35});
 }
 assert.equal(state.buyLog.length, COCS_BUY_LOG_LIMIT, 'the receipt log stays bounded');
 assert.equal(receiptsFor(state, 'c2').length, 0, 'the oldest receipts are trimmed first');
});

test('the OPERATIONS buy logs a card-keyed receipt in both the shared and presentation logs', () => {
 const match = coopMatch();
 const state = match.objectiveState;
 const actor = match.actors[0];
 actor.req = 100; actor.reqSpent = 0; actor.reqBuff = undefined;
 state.reqMult = 0;
 const bought = coopBuyAction(match, state, {tick: state.tick, peerId: 'p1', cardId: 'coop-fr', actorId: actor.id, itemId: 'field-repair'});
 assert.equal(bought.ok, true, 'the field repair applies');
 assert.equal(actor.reqSpent, 40);
 const receipt = receiptsFor(state, 'coop-fr');
 assert.equal(receipt.length, 1, 'the shared receipt log records the card');
 assert.equal(receipt[0].actor, actor.id);
 const presentation = state.coop.buyLog.filter(entry => entry.itemId === 'field-repair');
 assert.equal(presentation.length, 1, 'the OPERATIONS presentation log records the purchase');
 assert.equal(presentation[0].cardId, 'coop-fr', 'the presentation entry is keyed by the same card id');
});

test('two same-item purchases never share one receipt', () => {
 const match = pvpMatch();
 const state = match.objectiveState;
 const actor = match.actors[0];
 actor.req = 500; actor.reqSpent = 0; actor.reqBuff = 'overshield';
 // A re-buy of the active buff is legal: only the fresh card may settle.
 const first = cocsBuyAction(match, state, {tick: 1, peerId: 'p1', cardId: 'ov-1', actorId: actor.id, itemId: 'overshield'});
 const second = cocsBuyAction(match, state, {tick: 1, peerId: 'p1', cardId: 'ov-2', actorId: actor.id, itemId: 'overshield'});
 assert.equal(first.ok, true);
 assert.equal(second.ok, true);
 assert.equal(receiptsFor(state, 'ov-1').length, 1);
 assert.equal(receiptsFor(state, 'ov-2').length, 1);
 assert.notEqual(receiptsFor(state, 'ov-1')[0].cardId, receiptsFor(state, 'ov-2')[0].cardId, 'the two cards keep distinct receipt identities');
});

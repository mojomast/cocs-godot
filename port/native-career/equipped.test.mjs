// Controlled source fixture for the native Career saved-loadout lane.
//
// It uses the real authoritative Room and ProgressionStore (no local balance
// authority, no fabricated identity). Every write is a complete GEAR packet; the
// source normalizes it, replies with a `progression` frame carrying explicit
// gear/attachments maps, and the saved loadout is only applied when the next
// match constructs its actors. The current match actor is never rewritten.
//
// Run (parent serial slot): node --test port/native-career/equipped.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {Room} from '../../server/room.mjs';
import {ProgressionStore} from '../../server/progression.mjs';

function rng() { let n = 23; return () => ((n = (Math.imul(n, 1664525) + 1013904223) >>> 0) / 4294967296); }

const gearReply = room => room.drain().find(item => item.msg.type === 'progression' && item.msg.attachments);

test('the saved loadout is source-normalized and only the next match applies it', () => {
  const store = new ProgressionStore(null);
  const room = new Room('career-equipped', rng(), {progression: store});
  room.join(1, 'Host', 'chatgpt', 'openclaw', '', false, 'player-0001');
  room.host(1, {mode: 'deathmatch', botCount: 0, timeLimit: 60, fragLimit: 5}, 'crosswire');
  room.start(1);
  const actor = room.match.actors[0];
  const initial = structuredClone(actor.attachments);
  assert.equal(initial.items.length, 0, 'the match starts with no attachments');
  // A complete write: the source echoes explicit maps and the live actor holds.
  room.setGear(1, {}, {optic: 'red-dot'}, 1000);
  const reply = gearReply(room);
  assert.ok(reply, 'the source replied to the GEAR write');
  assert.deepEqual(reply.msg.gear, {}, 'the reply carries an explicit gear map');
  assert.equal(reply.msg.attachments.optic, 'red-dot', 'the reply carries the normalized attachment map');
  assert.deepEqual(actor.attachments, initial, 'the current match actor is not rewritten');
  // Unknown slots and IDs never enter the saved loadout as junk. Each write is
  // spaced past the source's 500 ms gear cooldown.
  room.setGear(1, {primary: 'ghost-kit'}, {optic: 'red-dot', alien: 'x'}, 1600);
  const normalized = gearReply(room);
  assert.deepEqual(normalized.msg.gear, {}, 'an unknown gear ID is dropped, never saved');
  assert.deepEqual(normalized.msg.attachments, {optic: 'red-dot'}, 'unknown attachment slots are dropped');
  // Only the next match picks up the saved attachment.
  room.match.spawn(actor);
  assert.deepEqual(actor.attachments, initial, 'respawn does not re-read the saved loadout');
  room.roundOver = true;
  room.start(1);
  assert.equal(room.match.actors[0].attachments.items[0].id, 'red-dot', 'the next match constructs the saved attachment');
});

test('the saved finish is a validated cosmetic with explicit null clearing', () => {
  const store = new ProgressionStore(null);
  const room = new Room('career-finish', rng(), {progression: store});
  room.join(1, 'Host', 'chatgpt', 'openclaw', '', false, 'player-0001');
  // Raise the career to level 4 so the Ion finish is genuinely unlocked.
  for (let i = 0; i < 30 && store.get('player-0001').level < 4; i++) store.award('player-0001', {actor: {frags: 30}, win: true, mode: 'deathmatch'});
  assert.ok(store.get('player-0001').level >= 4, 'the fixture reached the finish level');
  room.host(1, {mode: 'deathmatch', botCount: 0, timeLimit: 60, fragLimit: 5}, 'crosswire');
  room.start(1);
  room.setGear(1, {}, {}, 1000, 'finish-ion');
  assert.equal(gearReply(room).msg.profile.finish, 'finish-ion', 'an unlocked finish is saved');
  room.setGear(1, {}, {}, 1600, null);
  assert.equal(gearReply(room).msg.profile.finish, null, 'explicit null clears the saved finish');
  room.setGear(1, {}, {}, 2200, 'finish-ion');
  assert.equal(gearReply(room).msg.profile.finish, 'finish-ion', 'the finish can be restored');
  room.setGear(1, {}, {}, 2800, 'ghost-finish');
  assert.equal(gearReply(room).msg.profile.finish, null, 'an unknown finish is refused, never saved');
});

test('a low-level career refuses a level-gated finish and keeps explicit null stock', () => {
  const store = new ProgressionStore(null);
  const room = new Room('career-gated', rng(), {progression: store});
  room.join(1, 'Host', 'chatgpt', 'openclaw', '', false, 'player-0002');
  room.host(1, {mode: 'deathmatch', botCount: 0, timeLimit: 60, fragLimit: 5}, 'crosswire');
  room.start(1);
  room.setGear(1, {}, {}, 1000, 'finish-void');
  assert.equal(gearReply(room).msg.profile.finish, null, 'a level-gated finish is refused');
  room.setGear(1, {}, {}, 1600, null);
  assert.equal(gearReply(room).msg.profile.finish, null, 'explicit null stays stock');
});

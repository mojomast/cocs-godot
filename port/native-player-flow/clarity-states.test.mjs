// Source fixture for the native Career player-flow clarity lane.
//
// It pins the exact source behavior behind each reader state the LOADOUT tab
// shows, using the real authoritative Room and ProgressionStore (no local balance
// authority, no fabricated identity):
//   * a GEAR write replies with explicit, complete gear/attachments maps and no
//     award fields -- equipment is never an award;
//   * an unknown gear/attachment ID is normalized away, leaving an explicit empty
//     map -> known stock, so a saved write never produces an "unknown item";
//   * an explicit null finish stays null -> stock, while an unknown or level-gated
//     finish is refused to null, never saved;
//   * only the next match constructs the saved attachment; a respawn does not.
//
// Run (parent serial slot): node --test port/native-player-flow/clarity-states.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {Room} from '../../server/room.mjs';
import {ProgressionStore} from '../../server/progression.mjs';

function rng() { let n = 41; return () => ((n = (Math.imul(n, 1664525) + 1013904223) >>> 0) / 4294967296); }
const gearReply = room => room.drain().find(item => item.msg.type === 'progression' && item.msg.attachments);

test('a GEAR reply is explicit, award-free and normalizes unknown IDs to known stock', () => {
  const store = new ProgressionStore(null);
  const room = new Room('clarity-gear', rng(), {progression: store});
  room.join(1, 'Host', 'chatgpt', 'openclaw', '', false, 'player-0001');
  room.host(1, {mode: 'deathmatch', botCount: 0, timeLimit: 60, fragLimit: 5}, 'crosswire');
  room.start(1);
  const actor = room.match.actors[0];
  const initial = structuredClone(actor.attachments);
  room.setGear(1, {primary: 'ghost-kit'}, {optic: 'red-dot', alien: 'x'}, 1000);
  const reply = gearReply(room);
  assert.ok(reply, 'the source replied to the GEAR write');
  assert.deepEqual(reply.msg.gear, {}, 'an unknown gear ID normalizes to an explicit known-empty (stock) map');
  assert.deepEqual(reply.msg.attachments, {optic: 'red-dot'}, 'an unknown attachment slot is dropped, never saved');
  assert.equal('gained' in reply.msg, false, 'an equipment reply never carries award XP');
  assert.equal('levelUp' in reply.msg, false, 'an equipment reply never carries a level-up');
  assert.equal(reply.msg.profile.finish, null, 'an untouched finish stays explicit null (stock)');
  assert.deepEqual(actor.attachments, initial, 'the current match actor is not rewritten');
  room.match.spawn(actor);
  assert.deepEqual(actor.attachments, initial, 'a respawn does not re-read the saved loadout');
  room.roundOver = true;
  room.start(1);
  assert.equal(room.match.actors[0].attachments.items[0].id, 'red-dot', 'only the next match applies the saved attachment');
});

test('an unknown or level-gated finish is refused to explicit null, never saved', () => {
  const store = new ProgressionStore(null);
  const room = new Room('clarity-finish', rng(), {progression: store});
  room.join(1, 'Host', 'chatgpt', 'openclaw', '', false, 'player-0002');
  room.host(1, {mode: 'deathmatch', botCount: 0, timeLimit: 60, fragLimit: 5}, 'crosswire');
  room.start(1);
  room.setGear(1, {}, {}, 1000, 'ghost-finish');
  assert.equal(gearReply(room).msg.profile.finish, null, 'an unknown finish is refused to stock');
  room.setGear(1, {}, {}, 1600, 'finish-void');
  assert.equal(gearReply(room).msg.profile.finish, null, 'a level-gated finish is refused to stock');
});

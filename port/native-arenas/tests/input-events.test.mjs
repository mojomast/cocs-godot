import test from 'node:test';
import assert from 'node:assert/strict';
import {parseInputEnvelope} from '../../../game/protocol.mjs';
import {InputBuffer, INPUT_LIMIT, INPUT_TTL_MS} from '../input-buffer.mjs';
import {EventCursor} from '../event-cursor.mjs';

test('FIFO keeps press/release order, source normalization and one-step pulses', () => {
  const buffer = new InputBuffer();
  buffer.receive(1, parseInputEnvelope({seq:1, input:{x:99, pitch:9, fire:true, ads:true, reload:true, mobility:true}}), 0);
  buffer.receive(2, parseInputEnvelope({seq:2, input:{ads:false, fire:false}}), 1);
  const first = buffer.take(); assert.equal(first.input.x, 1); assert.equal(first.input.pitch, 1.45);
  assert.equal(first.input.ads, true); assert.equal(first.input.reload, true); buffer.stepped(first.seq);
  const second = buffer.take(); assert.equal(second.input.ads, false); assert.equal(second.input.fire, false);
  buffer.stepped(second.seq); assert.equal(buffer.take().input.ads, false);
  assert.equal(buffer.take().input.reload, undefined); assert.equal(buffer.applied, 2);
  assert.equal(buffer.receive(2, {ads:true}, 2), false);
  assert.equal(buffer.receive(Infinity, {}, 2), false);
});
test('queue age, held TTL, cancel and reset cannot replay ADS/actions', () => {
  const buffer = new InputBuffer();
  buffer.receive(1, {ads:true, power:true}, 0);
  assert.equal(buffer.expired(INPUT_TTL_MS), true);
  buffer.cancel(); assert.deepEqual(buffer.take().input, {}); assert.equal(buffer.applied, 0);
  assert.equal(buffer.cancelledThrough, 1);
  buffer.receive(2, {ads:true}, 300); buffer.take(); assert.equal(buffer.expired(550), true);
  buffer.receive(3, {ads:true, grenade:true}, 560, true);
  assert.deepEqual(buffer.take().input, {}); assert.deepEqual(buffer.take().input, {});
  buffer.reset(); assert.deepEqual(buffer.status(), {receivedSeq:0, appliedSeq:0, cancelledThrough:0, queueDepth:0});
  for (let i = 1; i <= INPUT_LIMIT; i++) buffer.receive(i, {}, 0);
  assert.throws(() => buffer.receive(INPUT_LIMIT + 1, {}, 0), /queue limit/);
});
test('event cursor retains payload IDs, handles serial gaps and repeated events by identity', () => {
  const cursor = new EventCursor(), match = {events:[]};
  const first = {type:'spawn', id:100, actor:0}; match.events.push(first);
  assert.deepEqual(cursor.take(match), [{...first, sourceId:100, id:1}]);
  assert.deepEqual(cursor.take(match), []);
  match.events.push({type:'traversal', id:'pad-a'}, {type:'traversal', id:'pad-a'});
  assert.deepEqual(cursor.take(match).map(e => [e.id, e.sourceId]), [[2, 'pad-a'], [3, 'pad-a']]);
  match.events.shift(); assert.deepEqual(cursor.take(match), []);
  match.events = [{type:'shot', id:500}]; assert.throws(() => cursor.take(match), /cursor lost/);
  assert.equal(new EventCursor().take(match)[0].id, 1);
});

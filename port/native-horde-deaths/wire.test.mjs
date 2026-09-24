import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';

// Committed independent real-run recording, not invented authority output.
const path = 'port/reports/horde-repair-independent/evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60/wire.jsonl.gz';
const packets = gunzipSync(readFileSync(path)).toString().trim().split('\n').map(JSON.parse)
  .filter(row => row.direction === 'out' && row.round === 1).map(row => row.frame);
const states = packets.filter(frame => frame.type === 'snapshot').map(frame => frame.state);
const events = packets.filter(frame => frame.type === 'events').flatMap(frame => frame.items);

test('authoritative Horde damage/deaths have stable IDs, numeric health damage and a finite death location', () => {
  const ids = new Set();
  const hits = events.filter(event => event.type === 'damage');
  const deaths = events.filter(event => event.type === 'death');
  assert.ok(hits.length > 0 && deaths.length >= 3);
  for (const event of [...hits, ...deaths]) {
    assert.ok(Number.isSafeInteger(event.id) && !ids.has(event.id));
    ids.add(event.id);
    assert.ok(Number.isSafeInteger(event.actor));
    assert.ok(Number.isFinite(event.time));
  }
  for (const hit of hits) assert.ok(Number.isFinite(hit.amount) && hit.amount > hit.shield);
  for (const death of deaths) assert.ok(['x', 'y', 'z'].every(key => Number.isFinite(death.pos?.[key])));
});

test('NPC identification comes from public snapshots, not death payload guesses', () => {
  const npcs = new Set(states.flatMap(state => state.actors.filter(actor => actor.isNpc).map(actor => actor.id)));
  const killedNpcs = events.filter(event => event.type === 'death' && npcs.has(event.actor));
  assert.deepEqual([...new Set(killedNpcs.map(event => event.actor))].sort(), [...npcs].sort());
  assert.ok(killedNpcs.every(event => event.actor !== 0 && event.pos));
  assert.ok(events.some(event => event.type === 'death' && event.actor === 0), 'local death must stay separate');
});

test('terminal NPC kill has no future active-frame render tick to rely on', () => {
  const index = packets.findIndex(frame => frame.type === 'results');
  assert.ok(index > 0);
  const lastDeath = packets.slice(0, index).flatMap(frame => frame.type === 'events' ? frame.items : [])
    .filter(event => event.type === 'death').at(-1);
  assert.ok(lastDeath && lastDeath.actor !== 0);
  assert.equal(packets.slice(index + 1).some(frame => frame.type === 'snapshot'), false);
});

// Offline review of retained REAL frames. Does not start a server or create fixtures.
// Gameplay audit restored from 2d4e60a; original execution checks retained.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const dir=resolve(process.argv[2]);
const summary=JSON.parse(readFileSync(resolve(dir,'summary.json')));
const text=name=>gunzipSync(readFileSync(resolve(dir,name))).toString();
const lines=name=>text(name).trim().split('\n').map(JSON.parse);
const wire=lines('wire.jsonl.gz'),obs=lines('observations.jsonl.gz');
for(const r of wire)if(r.frame.type==='welcome') {
  for(const key of ['token','progressToken'])assert.ok(r.frame[key]==null,'Retained welcome credential must be absent/null');
  assert.ok(r.frame.profile?.ownerToken==null,'Retained welcome profile credential must be absent/null');
}
const trace=text('native.stdout.log.gz').split('\n').filter(l=>l.startsWith('PORT_NATIVE_TRACE ')).map(l=>JSON.parse(l.slice(18)));
assert.equal(summary.status,'PASS');assert.equal(summary.completionProven,false);
assert.equal(summary.sourceStatus,'');assert.equal(summary.normalRate,true);
assert.ok(summary.captureWallMs<120000);
assert.equal(summary.cleanup.serverClosed,true);assert.equal(summary.cleanup.socketCount,0);
assert.equal(summary.cleanup.privateTempRemoved,true);
assert.ok(summary.cleanup.children.every(c=>c.reaped));
for(const [name,hash] of Object.entries(summary.hashes)) {
  const bytes=execFileSync('git',['show',`${summary.base}:port/tools/native_pickup_acceptance/${name}`]);
  assert.equal(createHash('sha256').update(bytes).digest('hex'),hash);
}
for(const [path,tree] of Object.entries(summary.runtimeTrees))assert.equal(execFileSync('git',['rev-parse',`${summary.base}:${path}`],{encoding:'utf8'}).trim(),tree);
assert.ok(trace.every((r,i)=>r.sequence===i&&(!i||r.monotonic_usec>=trace[i-1].monotonic_usec)));
assert.ok(!trace.some(r=>r.event==='limit'||r.complete===true));
const input=wire.filter(r=>r.direction==='client'&&r.frame.type==='input').map(r=>r.frame);
const queues=trace.filter(r=>r.event==='input_queue');
assert.equal(input.length,queues.length);
// Pair by observed order and compare controls. Native trace sequence is not protocol input seq.
for(let i=0;i<input.length;i++) {
  assert.equal(input[i].seq,i+1);assert.equal(queues[i].queued,true);
  for(const [k,v] of Object.entries(queues[i].controls)) {
    if(typeof v==='number')assert.ok(Math.abs(v-input[i].input[k])<.00001);
    else assert.equal(v,input[i].input[k]);
  }
}
const native=obs.filter(o=>o.event==='snapshot');
const server=new Map(wire.filter(r=>r.direction==='server'&&r.frame.type==='snapshot').map(r=>[r.frame.seq,r.frame]));
for(const o of native) {
  const f=server.get(o.seq);assert.ok(f);assert.equal(o.time,f.time);
  assert.equal(o.actor_id,summary.actorId);assert.equal(o.actor.id,summary.actorId);
  assert.equal(o.actor.weapon,f.actor.weapon);assert.deepEqual(o.actor.ammo,f.actor.ammo);
  assert.deepEqual(o.pickup,f.pickup);assert.equal(o.marker_visible,o.pickup.wait<=0);
  assert.ok(o.hud.includes(`Weapon ${o.actor.weapon}`));
  const ammo=o.actor.ammo[o.actor.weapon];assert.ok(o.hud.includes(`Ammo ${ammo}`));
  assert.equal(o.ack,f.acks[String(summary.actorId)]??0);
  assert.ok(o.ack<=input.at(-1).seq); // ACK is a high-water mark, not per-input application proof.
}
const i=native.findIndex(o=>o.pickup.wait>0),before=native[i-1],after=native[i];
const j=native.findIndex((o,k)=>k>i&&o.pickup.wait===0),returned=native[j];
assert.ok(before&&after&&returned);
assert.equal(before.pickup.id,0);assert.equal(returned.pickup.id,0);
assert.equal(before.actor.weapon,0);assert.equal(after.actor.weapon,1);
assert.equal(before.actor.ammo[1],0);assert.equal(after.actor.ammo[1],6);
assert.equal(summary.inventoryRule.expectedAmmo,6);assert.equal(summary.inventoryRule.cap,18);
assert.ok(after.pickup.wait>14.8&&after.pickup.wait<=15);
assert.ok(Math.abs(returned.time-after.time-15)<.05);
const span=native.slice(i,j+1);
assert.ok(span.every(o=>o.marker_instance===before.marker_instance));
assert.ok(span.filter(o=>o.stage==='waiting_return').every(o=>o.distance>1.05));
for(let k=1;k<span.length;k++) {
  assert.ok(span[k].pickup.wait<=span[k-1].pickup.wait);
  assert.ok(Math.abs(span[k].pickup.wait-Math.max(0,span[k-1].pickup.wait-(span[k].time-span[k-1].time)))<.003);
}
const events=wire.filter(r=>r.direction==='server'&&r.frame.type==='events').flatMap(r=>r.frame.items);
const picked=events.filter(e=>e.type==='pickup'&&e.kind==='rocket');
assert.equal(picked.length,1);assert.equal(picked[0].actor,summary.actorId);
assert.ok(picked[0].time>before.time&&picked[0].time<=after.time);
assert.ok(obs.some(o=>o.event==='physical_key'&&o.pressed));assert.ok(obs.some(o=>o.event==='mouse_motion'));
const ends=obs.filter(o=>o.event==='harness_end');
assert.equal(ends.length,1);assert.equal(ends[0].stage,'returned');
assert.equal(ends[0].completionProven,false);
// SceneTree.quit is deferred: already-pending snapshots can follow the explicit
// harness boundary. Retain and correlate them, rather than calling this a native
// completion marker or requiring timing-dependent last-line placement.
assert.ok(obs.slice(obs.indexOf(ends[0])+1).every(o=>
  o.event==='snapshot'&&o.stage==='returned'&&o.pickup.wait===0&&o.marker_visible));
console.log(JSON.stringify({status:'PASS',run:dir,executionCommit:summary.base,nativeSnapshots:native.length,
  receivedInputs:input.length,nativeTraceRecords:trace.length,actor:summary.actorId,pickup:0,
  beforeSeq:before.seq,afterSeq:after.seq,returnSeq:returned.seq,pickupEvent:picked[0],
  returnSimulationSeconds:returned.time-after.time,completionProven:false,
  limitation:'Order-paired queue/receive controls and ACK high-water do not prove application of every individual input.'},null,2));

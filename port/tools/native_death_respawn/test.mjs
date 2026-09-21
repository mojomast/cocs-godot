// Evidence-checker regression tests. Mutations below are explicitly synthetic
// corruptions of retained genuine recordings, never additional gameplay runs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {analyze} from './analyze.mjs';
const base=new URL('../../native-death-respawn/evidence/',import.meta.url);
function recording(id){const dir=new URL(`${id}/`,base);return {stdout:gunzipSync(readFileSync(new URL('native.stdout.log.gz',dir))).toString(),wire:JSON.parse(gunzipSync(readFileSync(new URL('wire.json.gz',dir))))};}
const good='f6498d16-7394-4c58-ae8e-f7445d65f61e',bad='4b4af664-c092-4a8a-9336-4665ddeddb38';
test('genuine final recording passes bounded criteria, never native completion',()=>{
 const {stdout,wire}=recording(good),r=analyze(stdout,wire);
 assert.equal(r.status,'PASS');assert.equal(r.completionProven,false);assert.equal(r.counts.deadNeutralInputs,116);assert.equal(r.counts.receivedInputs,495);
});
test('genuine earlier runtime failure stays failed with premature zero-HP alive state',()=>{
 const {stdout,wire}=recording(bad),r=analyze(stdout,wire);
 assert.equal(r.status,'FAIL');assert.equal(r.strictTimerContinuity,false);assert.equal(r.criteria.deadLifecycleGated,false);assert.equal(r.criteria.cameraReseed,false);
 assert.equal(r.ambiguousSnapshots[0].serverSnapshotSeq,157);assert.equal(r.ambiguousSnapshots[0].controlEligible,true);
});
test('synthetic zero-timer boundary retains dead gating and healthy respawn requirement',()=>{
 const {stdout,wire}=recording(good);
 const lastDead=wire.snapshots.filter(s=>s.dead>0).at(-1);lastDead.dead=0;
 const lines=stdout.split('\n');
 for(let i=0;i<lines.length;i++)if(lines[i].startsWith('CORRELATION_OBSERVE ')){
  const o=JSON.parse(lines[i].slice(20));if(o.event!=='snapshot'||o.seq!==lastDead.seq)continue;
  o.dead=0;lines[i]='CORRELATION_OBSERVE '+JSON.stringify(o);
  const native=JSON.parse(lines[i-1].slice(18));native.dead=0;
  assert.equal(native.lifecycle,'dead');assert.equal(native.camera_reseeded,false);
  lines[i-1]='PORT_NATIVE_TRACE '+JSON.stringify(native);
 }
 const r=analyze(lines.join('\n'),wire);
 assert.equal(r.status,'PASS');assert.equal(r.strictTimerContinuity,false);
 assert.equal(r.ambiguousSnapshots.length,1);assert.equal(r.criteria.deadLifecycleGated,true);
 assert.equal(r.criteria.cameraReseed,true);
});
test('missing server receipt cannot pass as successful queue',()=>{
 const {stdout,wire}=recording(good);wire.inputs.pop();assert.throws(()=>analyze(stdout,wire),/unmatched\/inflight/);
});
test('observer association requires immediate synchronous adjacency',()=>{
 const {stdout,wire}=recording(good);assert.throws(()=>analyze(stdout.replace('CORRELATION_OBSERVE ','synthetic intervening line\nCORRELATION_OBSERVE '),wire),/immediately follow/);
});
test('wire camera pose mutation cannot pass native agreement',()=>{
 const {stdout,wire}=recording(good);wire.snapshots[10].pose[0]+=1;assert.throws(()=>analyze(stdout,wire));
});
test('alternate killer cannot pass protocol attacker criterion',()=>{
 const {stdout,wire}=recording(good);wire.events.find(e=>e.type==='death'&&e.actor===wire.actor).killer=999;
 const r=analyze(stdout,wire);assert.equal(r.status,'FAIL');assert.equal(r.criteria.protocolAttackerKill,false);
});
test('trace reordering is rejected',()=>{
 const {stdout,wire}=recording(good);assert.throws(()=>analyze(stdout.replace('"sequence":0','"sequence":100'),wire),/trace order/);
});

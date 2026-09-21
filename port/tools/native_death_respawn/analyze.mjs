// Fresh-round queue ordinal and synchronous signal association patterns adapted
// from native_trace_correlation/validate.mjs at fbc8345 (original author: prior agent).
// Neither native trace sequence nor wall time is treated as a protocol sequence.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
const keys=['x','z','yaw','pitch','fire','jump','reload','sprint','crouch','interact','mobility'];
const actions=keys.slice(4);
const neutral=r=>r.controls.x===0&&r.controls.z===0&&actions.every(k=>r.controls[k]===false);
const near=(a,b)=>Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<1e-5;
export function analyze(stdout,wire) {
 const records=[],observations=[],stimuli=[],samples=[],boundaries=[];
 let lastTime=-1,previous=null;
 for(const [i,line] of stdout.split('\n').entries()) {
  if(line.startsWith('PORT_NATIVE_TRACE ')) {
   const r=JSON.parse(line.slice(18));
   assert.equal(r.schema,1);assert.equal(r.sequence,records.length,'trace order/limit');
   assert.ok(Number.isSafeInteger(r.monotonic_usec)&&r.monotonic_usec>=lastTime);lastTime=r.monotonic_usec;
   assert.ok(['round_start','snapshot','input_queue'].includes(r.event),'error/limit/unknown trace');
   assert.equal(r.round,1);assert.equal(r.actor_id,wire.actor);assert.equal(r.phase,3);
   if(r.event==='input_queue') {
    assert.equal(r.queued,r.queue_result===0);assert.ok(r.queued,'failed queue');
    for(const k of keys)assert.ok(k in r.controls && (keys.indexOf(k)<4?Number.isFinite(r.controls[k]):typeof r.controls[k]==='boolean'));
   }
   previous={...r,line:i+1};records.push(previous);
  } else if(line.startsWith('CORRELATION_OBSERVE ')) {
   const o=JSON.parse(line.slice(20));
   assert.equal(previous?.line,i,'observer must immediately follow runtime trace');
   assert.equal(previous.event,o.event==='start'?'round_start':'snapshot');
   observations.push({...o,nativeSequence:previous.sequence,line:i+1});
  } else if(line.startsWith('HARNESS_STIMULUS '))stimuli.push(JSON.parse(line.slice(17)));
  else if(line.startsWith('HARNESS_SAMPLE '))samples.push(JSON.parse(line.slice(15)));
  else if(line.startsWith('HARNESS_BOUNDARY '))boundaries.push(JSON.parse(line.slice(17)));
 }
 assert.equal(wire.joins,1);assert.equal(wire.connections,2);assert.equal(wire.unexpected.length,0);
 assert.equal(wire.starts.length,1);assert.equal(wire.mappingChanges,0);assert.equal(wire.results,0);
 assert.equal(records[0]?.event,'round_start');assert.equal(records.filter(r=>r.event==='round_start').length,1);
 const start=observations.filter(o=>o.event==='start');assert.equal(start.length,1);
 assert.equal(start[0].actor,wire.actor);assert.equal(start[0].mapId,'meridian-exchange');
 assert.equal(start[0].roundRevision,wire.starts[0].roundRevision);assert.equal(records[0].complete,false);
 const snapshots=records.filter(r=>r.event==='snapshot'),obs=observations.filter(o=>o.event==='snapshot');
 assert.equal(snapshots.length,obs.length);assert.ok(snapshots.length>0);
 const index=new Map(wire.snapshots.map(w=>[w.seq,w]));let seq=-1,time=-1,ack=0;
 const matched=snapshots.map((r,i)=>{
  const o=obs[i],w=index.get(o.seq);assert.ok(w,'server snapshot missing');
  assert.ok(o.seq>seq&&w.time>=time);seq=o.seq;time=w.time;
  assert.equal(o.nativeSequence,r.sequence);assert.equal(o.actor,wire.actor);assert.equal(w.actor,wire.actor);
  assert.equal(w.over,false);assert.equal(o.over,false);assert.equal(o.time,w.time);assert.ok(w.pose);
  for(const k of ['health','dead']){assert.equal(r[k],o[k]);assert.equal(o[k],w[k]);}
  assert.ok(Number.isFinite(r.health)&&Number.isFinite(r.dead)&&r.dead>=0);
  // Keep ambiguous HP=0/dead=0 samples and report a failed continuity criterion.
  ack=Math.max(ack,w.ack);assert.equal(r.ack,ack);assert.equal(o.ack,ack);assert.equal(r.pose_present,true);
  assert.deepEqual(o.pose,w.pose);assert.equal(o.yaw,w.yaw);assert.equal(o.pitch,w.pitch);assert.equal(o.eyeHeight,w.eyeHeight);
  assert.ok(r.camera_position.every((v,j)=>near(v,w.pose[j]+(j===1?w.eyeHeight:0))),'authoritative camera position');
  return {r,o,w};
 });
 const queues=records.filter(r=>r.event==='input_queue');
 assert.equal(queues.length,wire.inputs.length,'unmatched/inflight input tail');
 queues.forEach((r,i)=>{const w=wire.inputs[i];assert.equal(w.seq,i+1);for(const k of keys)assert.equal(r.controls[k],w.input[k],`receipt ${i+1} ${k}`);});
 const deadIndex=matched.findIndex(x=>x.r.dead>0),aliveBefore=matched.slice(0,deadIndex).at(-1);
 const dead=matched[deadIndex],respawn=deadIndex<0?null:matched.slice(deadIndex+1).find(x=>x.r.health>0&&x.r.dead===0);
 assert.ok(aliveBefore&&dead&&respawn,'missing genuine alive/dead/alive witness');
 assert.ok(aliveBefore.w.time<dead.w.time&&dead.w.time<respawn.w.time);
 const deathEvent=wire.events.find(e=>e.type==='death'&&e.actor===wire.actor&&e.time>aliveBefore.w.time&&e.time<=dead.w.time);
 const spawnEvent=wire.events.find(e=>e.type==='spawn'&&e.actor===wire.actor&&e.time>dead.w.time&&e.time<=respawn.w.time);
 const deadQueues=queues.filter(r=>r.sequence>dead.r.sequence&&r.sequence<respawn.r.sequence);
 assert.ok(deadQueues.length>=10);assert.ok(deadQueues.every(neutral),'dead input not neutral');
 const deadSnapshots=matched.filter(x=>x.r.sequence>=dead.r.sequence&&x.r.sequence<respawn.r.sequence);
 const deadLifecycleGated=deadSnapshots.every(x=>x.r.lifecycle==='dead'&&!x.r.pointer_captured&&!x.r.control_eligible);
 assert.equal(respawn.r.lifecycle,'alive');assert.equal(respawn.r.pointer_captured,false);
 const wrapped=Math.atan2(Math.sin(respawn.w.yaw),Math.cos(respawn.w.yaw));
 const anglesMatchAuthority=near(respawn.r.yaw,wrapped)&&near(respawn.r.pitch,Math.max(-1.45,Math.min(1.45,respawn.w.pitch)));
 const held=stimuli.find(s=>s.kind==='held_ctrl_and_mouse_down'),click=stimuli.find(s=>s.kind==='fresh_click_after_respawn');
 assert.ok(held&&click);assert.ok(click.seconds-held.seconds>2);
 // Actual held state is sampled independently; parse_input_event may be buffered.
 const gateQueues=queues.filter(r=>r.sequence>respawn.r.sequence&&r.sequence<click.trace_next);
 assert.ok(gateQueues.length>=20&&gateQueues.every(neutral),'postrespawn gate');
 assert.ok(matched.filter(x=>x.r.sequence>=respawn.r.sequence&&x.r.sequence<click.trace_next).every(x=>!x.r.pointer_captured));
 const heldSamples=samples.filter(s=>s.trace_next>dead.r.sequence&&s.trace_next<click.trace_next);
 assert.ok(heldSamples.length>=3&&heldSamples.every(s=>s.physical_ctrl&&s.mouse_left),'held stimulus across death/respawn');
 const predeathActive=queues.filter(r=>r.sequence>=held.trace_next&&r.sequence<dead.r.sequence&&!neutral(r));
 const postclickActive=queues.filter(r=>r.sequence>=click.trace_next&&!neutral(r));
 const cameraFrame=samples.find(s=>s.trace_next>respawn.r.sequence&&s.trace_next<click.trace_next);
 assert.ok(cameraFrame&&near(cameraFrame.camera_rotation[0],respawn.r.pitch)&&near(cameraFrame.camera_rotation[1],respawn.r.yaw),'camera rotation after process');
 assert.equal(boundaries.length,1);assert.equal(boundaries[0].reason,'post_respawn_window');
 const witness=x=>({nativeTraceSequence:x.r.sequence,serverSnapshotSeq:x.w.seq,time:x.w.time,health:x.r.health,dead:x.r.dead,pose:x.w.pose,camera:x.r.camera_position,authorityYaw:x.w.yaw,authorityPitch:x.w.pitch,nativeYaw:x.r.yaw,nativePitch:x.r.pitch,reseeded:x.r.camera_reseeded});
 const ambiguous=matched.filter(x=>!((x.r.health>0&&x.r.dead===0)||(x.r.health===0&&x.r.dead>0)));
 const criteria={observedSameActorAliveDeadAlive:true,strictLifecycleContinuity:ambiguous.length===0,protocolAttackerKill:!!deathEvent&&Number.isInteger(wire.attackerActor)&&deathEvent.killer===wire.attackerActor,eventCorroborated:!!(deathEvent&&spawnEvent),deadNeutralOutput:true,deadLifecycleGated,cameraPositionAuthority:true,cameraReseed:respawn.r.camera_reseeded&&anglesMatchAuthority,cameraAnglesMatchAuthority:anglesMatchAuthority,cameraRotationAfterProcess:true,pointerReleasedProgramState:true,heldControlsDoNotAutoResume:true,predeathNonneutral:predeathActive.length>0,freshClickResumes:postclickActive.length>0};
 return {status:Object.values(criteria).every(Boolean)?'PASS':'FAIL',actor:wire.actor,roundRevision:wire.starts[0].roundRevision,completionProven:false,
  counts:{records:records.length,snapshots:matched.length,receivedInputs:queues.length,deadNeutralInputs:deadQueues.length,postRespawnNeutralInputs:gateQueues.length,predeathActiveInputs:predeathActive.length,postClickActiveInputs:postclickActive.length},
  criteria,ambiguousSnapshots:ambiguous.map(x=>({...witness(x),lifecycle:x.r.lifecycle,controlEligible:x.r.control_eligible})),
  witness:{alive:witness(aliveBefore),dead:witness(dead),respawn:witness(respawn)},deathEvent:deathEvent??null,spawnEvent:spawnEvent??null,eventCorroborated:!!(deathEvent&&spawnEvent),ackHighWater:ack,receiptNotIndividualApplication:true,harnessBoundary:boundaries[0]};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try {const dir=process.argv[2];const result=analyze(gunzipSync(readFileSync(`${dir}/native.stdout.log.gz`)).toString(),JSON.parse(gunzipSync(readFileSync(`${dir}/wire.json.gz`))));console.log(JSON.stringify(result,null,2));process.exitCode=result.status==='PASS'?0:2;}
 catch(e){console.error(e.stack);process.exitCode=1;}
}

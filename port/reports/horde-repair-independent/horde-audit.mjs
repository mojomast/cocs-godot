// Independent recording audit. No live launches or edits to existing evidence.
import assert from 'node:assert/strict';
import {readFileSync,readdirSync,writeFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {parseInputEnvelope} from '../../../game/protocol.mjs';
import {validateHygiene} from '../../native-horde/validate.mjs';
const root=new URL('./',import.meta.url),reports=[];
const read=(base,name)=>readFileSync(new URL(name,base),'utf8');
const json=(base,name)=>JSON.parse(read(base,name));
const unzip=(base,name)=>gunzipSync(readFileSync(new URL(name+'.gz',base))).toString();
const tagged=(text,prefix)=>text.split('\n').filter(l=>l.startsWith(prefix)).map(l=>JSON.parse(l.slice(prefix.length)));
const actionFields=['x','z','fire','jump','reload','sprint','crouch','interact','mobility','power','melee','grenade','ads','altFire','weapon'];
function sameProjection(actual,expected) {
 // Native JSON emits fewer decimal digits for source floating-point timers.
 if(typeof expected==='number') {assert.equal(typeof actual,'number');assert(Math.abs(actual-expected)<1e-9);return;}
 if(expected&&typeof expected==='object') {
  assert(actual&&typeof actual==='object');assert.equal(Array.isArray(actual),Array.isArray(expected));
  assert.deepEqual(Object.keys(actual).sort(),Object.keys(expected).sort());
  for(const k of Object.keys(expected))sameProjection(actual[k],expected[k]);
 } else assert.equal(actual,expected);
}
for(const id of readdirSync(new URL('evidence/',root)).sort()) {
 const dir=new URL(`evidence/${id}/`,root),summary=json(dir,'summary.json'),launch=json(dir,'launch.json');
 const stdout=unzip(dir,'native.stdout.log'),stderr=unzip(dir,'native.stderr.log');
 const wire=unzip(dir,'wire.jsonl').trim().split('\n').map(JSON.parse);
 const rows=tagged(stdout,'HORDE_NATIVE '),trace=tagged(stdout,'PORT_NATIVE_TRACE ');
 const done=tagged(stdout,'HORDE_DONE '),layout=tagged(stdout,'HORDE_LAYOUT '),products=tagged(stdout,'HORDE_PRODUCT ');
 assert(summary.wallSeconds<180&&summary.attempt<=2);
 validateHygiene(summary,stdout,stderr);
 assert.equal(done.length,1);assert.equal(done[0].ok,true);
 assert.equal(trace.filter(t=>t.event==='recording_end'&&t.complete===true).length,1);
 assert(!trace.some(t=>t.event==='limit'));
 assert.equal(products.length,1);assert.equal(products[0].scene,'res://horde/demo.tscn');
 assert.equal(products[0].script,'res://horde/demo.gd');assert(products[0].scoreboard);
 const receipts=new Map(),steps=new Map(),snapshots=new Map(),results=[],events=[],replays=[],seenEvents=new Map();
 const received=[],stepRows=[];
 let lastObserved=-1;
 for(const r of wire) {
  assert(r.observedMs>=lastObserved,'nonmonotonic observation clock');lastObserved=r.observedMs;
  if(r.direction==='in'&&r.frame.type==='input') {
   const k=`${r.round}:${r.frame.seq}`;assert(!receipts.has(k));receipts.set(k,r);received.push(r);
  } else if(r.direction==='step') {
   if(r.inputSeq!==null) {
    const k=`${r.round}:${r.inputSeq}`,receipt=receipts.get(k);
    assert(receipt&&!steps.has(k),'step lacks unique prior receipt');
    assert.equal(receipt.frame.inputEpoch,r.inputEpoch);
    assert.deepEqual(r.controls,receipt.frame.cancel?{}:JSON.parse(JSON.stringify(parseInputEnvelope(receipt.frame))));
    assert.equal(r.appliedSeq,r.inputSeq);steps.set(k,r);
   }
   stepRows.push(r);
  } else if(r.direction==='out'&&r.frame.type==='snapshot') {
   const f=r.frame;assert.equal(f.acks[0],f.hordeInput.appliedSeq);
   assert(f.hordeInput.receivedSeq>=f.acks[0]);
   if(f.acks[0])assert(steps.has(`${r.round}:${f.acks[0]}`),'ACK without earlier successful source-step record');
   assert(f.hordeInput.queueDepth>=0&&f.hordeInput.queueDepth<=16);
   snapshots.set(`${r.round}:${f.seq}`,r);
  } else if(r.direction==='out'&&r.frame.type==='results')results.push(r);
  else if(r.direction==='out'&&r.frame.type==='events')for(const e of r.frame.items) {
   const original={...e};delete original.id;
   const k=JSON.stringify([r.round,original]);
   if(seenEvents.has(k))replays.push({first:seenEvents.get(k),replayed:e});
   else seenEvents.set(k,e);
   events.push(e);
  }
 }
 const correlated=rows.filter(r=>r.seq>=0);
 assert(correlated.length>10);
 for(const row of correlated) {
  const f=snapshots.get(`${row.round}:${row.seq}`).frame;
  assert.equal(row.ack,f.acks[0]);assert.equal(row.actor_id,0);
  sameProjection(row.model,f.state.singleplayer);
  assert(row.hud.includes(`WAVE ${row.model.wave} / ${row.model.waveTarget}`));
  assert(row.hud.includes(`LIVES ${row.model.lives}`));
  assert.deepEqual(Object.keys(row.rendered).sort(),f.state.actors.map(a=>String(a.id)).sort());
  for(const a of f.state.actors) {
   const actual=row.rendered[a.id];
   [a.x,a.y+.9,a.z].forEach((v,i)=>assert(Math.abs(v-actual.position[i])<.001));
   assert.equal(actual.visible,a.id!==0&&a.health>0&&a.dead<=0);
  }
 }
 const queued=trace.filter(t=>t.event==='input_queue'&&t.queued);
 const queueReceipts=queued.filter(t=>receipts.has(`${t.round}:${t.input_seq}`));
 for(const t of queueReceipts) {
  const f=receipts.get(`${t.round}:${t.input_seq}`).frame;
  assert.equal(t.input_epoch,f.inputEpoch);
  for(const k of actionFields) {
   if(k==='weapon'&&!Object.hasOwn(t.controls,k))continue;
   const a=t.controls[k]??false,b=f.input[k]??false;
   if(typeof a==='number'&&typeof b==='number')assert(Math.abs(a-b)<.00001);
   else assert.equal(a,b,`native queue/receipt mismatch ${k}`);
  }
 }
 for(const size of [[960,640],[1280,800]])assert(layout.some(l=>JSON.stringify(l.viewport)===JSON.stringify(size)));
 for(const l of layout){assert(l.passive&&!l.intersects&&!l.scoreboard_intersects);assert(l.controls_bottom<=l.viewport[1]);if(l.scoreboard_visible)assert(l.scoreboard_bottom<=l.viewport[1]);}
 assert(events.some(e=>e.type==='horde-modifier'&&e.sourceId==='swarm'));
 const states=[...snapshots.values()],effects={};
 if(summary.scenario==='combat') {
  assert.equal(results.length,1);const s=results[0].frame.state,sp=s.singleplayer;
  const enemyVictims=[...new Set(events.filter(e=>e.type==='death'&&e.killer===0&&e.actor!==0&&!e.self).map(e=>e.actor))].sort();
  assert.deepEqual(enemyVictims,[1,2,3]);assert(s.over&&sp.phase==='won'&&sp.winner===0&&sp.waveTarget===1&&sp.enemiesAlive===0);
  const restart=states.find(r=>r.round===2);assert(restart);
  assert(rows.filter(r=>r.round===2).every(r=>!r.captured));
  const fresh=restart.frame.state;assert(fresh.time<=.051&&fresh.singleplayer.kills===0&&fresh.actors[0].shots===0);
  Object.assign(effects,{enemyVictims,netSourceKills:sp.kills,actorFrags:s.actors[0].frags,score:sp.score,lives:sp.lives,winner:sp.winner,
   sourceSelfDeaths:events.filter(e=>e.type==='death'&&e.actor===0&&e.self).length,releasedRestart:true,restartSourceTime:fresh.time});
 } else if(summary.scenario==='death') {
  const dead=states.find(r=>r.frame.state.actors[0].health<=0&&r.frame.state.actors[0].dead>0);
  assert(dead&&dead.frame.state.singleplayer.lives===2);
  const respawn=states.find(r=>r.observedMs>dead.observedMs&&r.frame.state.actors[0].health>0&&r.frame.state.actors[0].dead<=0);
  assert(respawn&&respawn.frame.state.singleplayer.lives===2);
  assert(states.some(r=>r.observedMs<dead.observedMs&&r.frame.state.actors[0].crouching));
  assert(events.some(e=>e.type==='death'&&e.actor===0&&e.killer!==0));
  const firstDead=trace.findIndex(t=>t.event==='snapshot'&&t.dead>0);
  const after=trace.slice(firstDead),recapture=after.findIndex(t=>t.event==='snapshot'&&t.pointer_captured);
  assert(recapture>0);assert(trace.slice(0,firstDead).some(t=>t.event==='input_queue'&&t.controls.interact));
  const neutral=after.slice(0,recapture).filter(t=>t.event==='input_queue');assert(neutral.length>10);
  for(const t of neutral)for(const k of actionFields)assert(!t.controls[k],`held action after death ${k}`);
  assert(done[0].dead_seen&&done[0].respawn_seen&&done[0].blocked_seen);
  Object.assign(effects,{livesBefore:3,livesAfter:2,deadSeq:dead.frame.seq,respawnSeq:respawn.frame.seq,neutralNativeInputs:neutral.length,freshReleasedCapture:true});
 } else {
  assert(states.every(r=>r.frame.state.singleplayer.waveTarget===10));
  assert(states.some(r=>r.frame.state.singleplayer.wave===1&&r.frame.state.singleplayer.enemiesAlive===3));
  assert.equal(results.length,0);Object.assign(effects,{wave:1,target:10,enemies:3,scope:'startup only'});
 }
 const mutations=[['nonzero exit',{...summary,exit:1},stdout,stderr],['open listener',{...summary,serverClosed:false},stdout,stderr],
  ['unreaped child',{...summary,cleanup:summary.cleanup.map(p=>({...p,reaped:false}))},stdout,stderr],
  ['resource leak',summary,stdout,stderr+'\nERROR: resources still in use at exit'],['XDG leak',{...summary,temporaryTreeRemoved:false},stdout,stderr]];
 for(const [,s,o,e] of mutations)assert.throws(()=>validateHygiene(s,o,e));
 const report={id,scenario:summary.scenario,launchCommit:launch.base,wallSeconds:summary.wallSeconds,
  boundedGameplay:'PASS',integrationVerdict:'HOLD: event cursor replay defect',harnessExit:summary.exit,observerComplete:done[0].ok,
  nativeRecordingEnd:true,correlatedSnapshots:correlated.length,queuedNativeSamples:queued.length,queuedWithReceipt:queueReceipts.length,
  receipts:received.length,distinctSteppedSamples:steps.size,sourceSteps:stepRows.length,appliedAckHighWater:Math.max(...correlated.map(r=>r.ack)),
  receivedHighWater:Math.max(...states.map(r=>r.frame.hordeInput.receivedSeq)),effects,
  identicalEventPayloadReplays:replays.length,replayExamples:replays.slice(0,5),hygieneNegativeProbes:mutations.map(m=>m[0])};
 writeFileSync(new URL('independent-audit.json',dir),JSON.stringify(report,null,2)+'\n');reports.push(report);
}
writeFileSync(new URL('live-audits.json',root),JSON.stringify(reports,null,2)+'\n');
console.log(JSON.stringify(reports,null,2));

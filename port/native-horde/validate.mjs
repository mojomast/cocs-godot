import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
import {parseInputEnvelope} from '../../game/protocol.mjs';
export function validateHygiene(summary, stdout, stderr) {
 assert.equal(summary.exit,0,'native harness failed');
 assert.equal(summary.serverClosed,true,'listener leaked');
 assert.equal(summary.sockets,0,'sockets leaked');
 assert.equal(summary.temporaryTreeRemoved,true,'private XDG leaked');
 assert(summary.cleanup?.length===2&&summary.cleanup.every(p=>p.reaped&&p.absent),'owned native/Xvfb cleanup missing');
 assert(!/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use|RIDs? of type.*leaked/.test(stdout+stderr),'native resource/script errors');
}
export function validate(wire,stdout,scenario='startup') {
 const frames=wire.filter(r=>r.direction==='out'),rows=stdout.split('\n').filter(l=>l.startsWith('HORDE_NATIVE ')).map(l=>JSON.parse(l.slice(13)));
 assert(rows.length>0,'no native evidence');
 const snapshots=new Map(frames.filter(r=>r.frame.type==='snapshot').map(r=>[`${r.round}:${r.frame.seq}`,r.frame]));
 let correlated=0;
 for(const row of rows){
  if(row.seq<0)continue;
  const f=snapshots.get(`${row.round}:${row.seq}`);assert(f,'missing recipient snapshot');
  assert.equal(row.actor_id,0,'local actor zero');
  for(const k of ['wave','waveTarget','lives','enemiesAlive','enemiesTotal','phase','score','winner'])assert.equal(row.model[k],f.state.singleplayer[k],`HUD model ${k}`);
  assert(row.hud.includes(`WAVE ${f.state.singleplayer.wave} / ${f.state.singleplayer.waveTarget}`),'wave not visible');
  assert(row.hud.includes(`LIVES ${f.state.singleplayer.lives}`),'lives not visible');
  assert.deepEqual(Object.keys(row.rendered).sort(),f.state.actors.map(a=>String(a.id)).sort(),'rendered identity set');
  for(const a of f.state.actors){const r=row.rendered[a.id];assert(r,'missing rendered actor');for(const [i,v]of [a.x,a.y+0.9,a.z].entries())assert(Math.abs(r.position[i]-v)<0.001,'position mismatch');assert.equal(r.visible,a.id!==0&&a.health>0&&a.dead<=0,'visibility');}
  correlated++;
 }
 assert(correlated>10,'insufficient samples');
 const events=frames.filter(r=>r.frame.type==='events').flatMap(r=>r.frame.items);
 const state=frames.filter(r=>r.frame.type==='snapshot').map(r=>r.frame.state);
 assert(state.some(s=>s.singleplayer.wave>=1&&s.singleplayer.enemiesAlive>0),'no real wave');
 const receipts=wire.filter(r=>r.direction==='in'&&r.frame.type==='input');
 const done=stdout.split('\n').filter(l=>l.startsWith('HORDE_DONE ')).map(l=>JSON.parse(l.slice(11)));
 assert(done.length===1&&done[0].ok,'native completion missing/failed');
 const won=frames.some(r=>r.frame.type==='results'&&r.frame.state.singleplayer.phase==='won');
 const deaths=state.some(s=>s.singleplayer.lives<3);
 if(scenario==='combat'){
  assert(receipts.some(r=>r.frame.input.fire===true),'no fire receipt');
  assert(state.some(s=>s.singleplayer.kills>0),'no real kill');
  assert(won,'no genuine victory');
  assert(rows.some(r=>r.round===2&&!r.captured),'no released restart');
 }
 if(scenario==='death'){
  assert(deaths,'no life loss');
  assert(done[0].dead_seen&&done[0].respawn_seen&&done[0].blocked_seen,'missing respawn input gates');
  const gates=stdout.split('\n').filter(l=>l.startsWith('HORDE_GATE ')).map(l=>JSON.parse(l.slice(11)));
  assert(gates.some(g=>g.stage==='pause')&&gates.some(g=>g.stage==='resumed_holding_interact'),'no explicit pause/resume probe');
  const trace=stdout.split('\n').filter(l=>l.startsWith('PORT_NATIVE_TRACE ')).map(l=>JSON.parse(l.slice(18)));
  const firstDead=trace.findIndex(t=>t.event==='snapshot'&&t.dead>0);
  assert(firstDead>=0,'no native dead state');
  assert(trace.slice(0,firstDead).some(t=>t.event==='input_queue'&&t.controls.interact),'no pre-death held action');
  const after=trace.slice(firstDead);
  const recaptured=after.findIndex(t=>t.event==='snapshot'&&t.pointer_captured);
  const blocked=recaptured<0?after:after.slice(0,recaptured);
  const neutral=blocked.filter(t=>t.event==='input_queue');
  assert(neutral.length>10,'insufficient neutral death/respawn samples');
  for(const t of neutral){for(const key of ['x','z','fire','jump','reload','sprint','crouch','interact','mobility'])assert(!t.controls[key],`held action leaked: ${key}`);}
 }
 return {status:'PASS',scenario,correlated,receipts:receipts.length,ackHighWater:Math.max(...rows.map(r=>r.ack)),won,deaths,eventTypes:[...new Set(events.map(e=>e.type))],nativeTraceCompletionProven:false};
}
export function validateRun({wire,stdout,stderr,summary,launch}) {
 validateHygiene(summary,stdout,stderr);
 const result=validate(wire,stdout,summary.scenario);
 const outputs=wire.filter(r=>r.direction==='out');
 const snapshots=outputs.filter(r=>r.frame.type==='snapshot');
 const receipts=new Map(wire.filter(r=>r.direction==='in'&&r.frame.type==='input').map(r=>[`${r.round}:${r.frame.seq}`,r]));
 const applied=new Map();
 for(const step of wire.filter(r=>r.direction==='step'&&r.inputSeq!==null)) {
  const key=`${step.round}:${step.inputSeq}`,receipt=receipts.get(key);
  assert(receipt,'stepped input has no receipt');
  assert(!applied.has(key),'input sample stepped more than once');
  assert.equal(receipt.frame.inputEpoch,step.inputEpoch,'stale epoch stepped');
  const controls=receipt.frame.cancel?{}:parseInputEnvelope(receipt.frame);
  assert.deepEqual(step.controls,controls,'stepped controls differ from parsed source input');
  assert.equal(step.appliedSeq,step.inputSeq);
  applied.set(key,step);
 }
 assert(applied.size>0,'no actual stepped-input evidence');
 for(const snapshot of snapshots) {
  const f=snapshot.frame,status=f.hordeInput;
  assert(status&&status.appliedSeq===f.acks[0]&&status.receivedSeq>=status.appliedSeq,'receipt/applied metadata invalid');
  if(f.acks[0]>0) {
   const step=applied.get(`${snapshot.round}:${f.acks[0]}`);
   assert(step&&step.observedMs<=snapshot.observedMs,'ACK was not stepped before snapshot');
  }
 }
 const rows=stdout.split('\n').filter(s=>s.startsWith('HORDE_NATIVE ')).map(s=>JSON.parse(s.slice(13)));
 for(const row of rows.filter(r=>r.seq>=0)) {
  const frame=snapshots.find(s=>s.round===row.round&&s.frame.seq===row.seq).frame;
  assert.equal(row.ack,frame.acks[0],'native ACK does not equal stepped high-water');
 }
 const products=stdout.split('\n').filter(s=>s.startsWith('HORDE_PRODUCT ')).map(s=>JSON.parse(s.slice(14)));
 assert(products.length===1&&products[0].scene==='res://horde/demo.tscn'&&products[0].script==='res://horde/demo.gd'&&products[0].scoreboard,'observer did not instantiate actual product scene');
 const layouts=stdout.split('\n').filter(s=>s.startsWith('HORDE_LAYOUT ')).map(s=>JSON.parse(s.slice(13)));
 for(const size of [[960,640],[1280,800]]) assert(layouts.some(l=>JSON.stringify(l.viewport)===JSON.stringify(size)),'both product viewport sizes required');
 for(const layout of layouts) {
  assert(layout.passive&&!layout.intersects&&!layout.scoreboard_intersects,'Horde HUD overlaps shared UI');
  if(layout.scoreboard_visible)assert(layout.scoreboard_bottom<=layout.viewport[1],'scoreboard clipped');
  assert(Number.isFinite(layout.controls_bottom)&&layout.controls_bottom<=layout.viewport[1],'control help clipped/missing');
 }
 const trace=stdout.split('\n').filter(s=>s.startsWith('PORT_NATIVE_TRACE ')).map(s=>JSON.parse(s.slice(18)));
 assert(trace.filter(t=>t.event==='recording_end'&&t.complete===true).length===1,'native recording completion absent/truncated');
 assert(!trace.some(t=>t.event==='limit'),'native trace truncated');
 const events=outputs.filter(r=>r.frame.type==='events').flatMap(r=>r.frame.items);
 assert(events.some(e=>e.type==='horde-modifier'&&e.sourceId==='swarm'&&Number.isSafeInteger(e.id)),'source string-ID event missing');
 if(summary.scenario==='startup')assert(snapshots.every(r=>r.frame.state.singleplayer.waveTarget===10),'default-ten startup required');
 if(summary.scenario==='combat') {
  const state=outputs.find(r=>r.frame.type==='results')?.frame.state;
  assert(state?.over&&state.singleplayer.winner===0&&state.singleplayer.waveTarget===1&&state.singleplayer.enemiesAlive===0,'legal one-wave source outcome required');
  assert.equal(state.singleplayer.kills,3);
  assert.deepEqual([...new Set(events.filter(e=>e.type==='death'&&e.killer===0).map(e=>e.actor))].sort(),[1,2,3]);
  assert(layouts.filter(l=>l.tag.startsWith('results')&&l.scoreboard_visible).length>=2,'results scoreboard not seen at both sizes');
 }
 if(summary.scenario==='death') {
  const dead=snapshots.find(r=>r.frame.state.actors.some(a=>a.id===0&&a.health<=0&&a.dead>0));
  assert(dead&&dead.frame.state.singleplayer.lives===2,'real dead actor/life loss missing');
  assert(snapshots.some(r=>r.observedMs>dead.observedMs&&r.frame.state.singleplayer.lives===2&&r.frame.state.actors.some(a=>a.id===0&&a.health>0&&a.dead<=0)),'living respawn missing');
  assert(wire.some(r=>r.direction==='step'&&r.observedMs<dead.observedMs&&r.controls.crouch),'source-held pre-death action missing');
  assert(events.some(e=>e.type==='death'&&e.actor===0&&e.killer!==0));
  assert(events.some(e=>e.type==='singleplayer-life'&&e.lives===2));
 }
 const first=snapshots[0],last=snapshots.filter(r=>r.round===1).at(-1);
 return {...result,steppedSamples:applied.size,receivedHighWater:Math.max(...snapshots.map(r=>r.frame.hordeInput.receivedSeq)),
  nativeTraceCompletionProven:true,productComposition:true,harnessExit:summary.exit,
  clockDiagnostic:{sourceSeconds:last.frame.state.time-first.frame.state.time,wallSeconds:(last.observedMs-first.observedMs)/1000},
  runtimeCommit:launch.base};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const dir=process.argv[2],read=n=>gunzipSync(readFileSync(`${dir}/${n}.gz`)).toString();
 const result=validateRun({wire:read('wire.jsonl').trim().split('\n').map(JSON.parse),stdout:read('native.stdout.log'),stderr:read('native.stderr.log'),
  summary:JSON.parse(readFileSync(`${dir}/summary.json`)),launch:JSON.parse(readFileSync(`${dir}/launch.json`))});
 writeFileSync(`${dir}/validation.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}

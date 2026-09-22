// Additional independent assertions over immutable recipient/native records.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,readdirSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {validate} from '../../native-horde/validate.mjs';
const root='port/reports/horde-independent/evidence';
const audits=[];
for(const id of readdirSync(root)) {
 const dir=`${root}/${id}`;
 const summary=JSON.parse(readFileSync(`${dir}/summary.json`));
 const wire=gunzipSync(readFileSync(`${dir}/wire.jsonl.gz`)).toString().trim().split('\n').filter(Boolean).map(JSON.parse);
 const text=gunzipSync(readFileSync(`${dir}/native.stdout.log.gz`)).toString();
 const lines=text.split('\n');
 const rows=lines.filter(s=>s.startsWith('HORDE_NATIVE ')).map(s=>JSON.parse(s.slice(13)));
 const snapshots=wire.filter(r=>r.direction==='out'&&r.frame.type==='snapshot');
 const events=wire.filter(r=>r.direction==='out'&&r.frame.type==='events').flatMap(r=>r.frame.items);
 const audit={id,map:summary.map,scenario:summary.scenario,harnessExit:summary.exit,cleanup:summary.cleanup};
 try {
  audit.deliveryValidator=validate(wire,text,summary.scenario);
  assert(summary.serverClosed&&summary.sockets===0&&summary.temporaryTreeRemoved);
  assert(summary.cleanup.every(p=>p.reaped&&p.absent));
  for(const row of rows.filter(r=>r.seq>=0)) {
   const frame=snapshots.find(s=>s.round===row.round&&s.frame.seq===row.seq).frame;
   assert.equal(row.ack,frame.acks[0],'native ACK equals recipient high-water, not input count');
  }
  const first=snapshots.find(r=>r.round===1),last=snapshots.filter(r=>r.round===1).at(-1);
  audit.clock={sourceSeconds:last.frame.state.time-first.frame.state.time,wallSeconds:(last.observedMs-first.observedMs)/1000};
  audit.clock.ratio=audit.clock.sourceSeconds/audit.clock.wallSeconds;
  const states=snapshots.map(r=>r.frame.state);
  audit.maxKills=Math.max(...states.map(s=>s.singleplayer.kills));
  audit.minLives=Math.min(...states.map(s=>s.singleplayer.lives));
  audit.maxActors=Math.max(...states.map(s=>s.actors.length));
  audit.maxSnapshotBytes=Math.max(...snapshots.map(r=>Buffer.byteLength(JSON.stringify(r.frame))));
  audit.localKillEvents=events.filter(e=>e.type==='death'&&e.killer===0&&e.actor!==0);
  if(summary.scenario==='combat') {
   const result=wire.find(r=>r.direction==='out'&&r.frame.type==='results').frame.state;
   assert(result.over&&result.singleplayer.phase==='won'&&result.singleplayer.winner===0);
   assert.equal(result.singleplayer.waveTarget,1);assert.equal(result.singleplayer.wave,1);
   assert.equal(result.singleplayer.kills,3);assert.equal(result.singleplayer.enemiesAlive,0);
   assert.deepEqual([...new Set(audit.localKillEvents.map(e=>e.actor))].sort(),[1,2,3]);
   const restarted=snapshots.find(r=>r.round===2).frame;
   assert.equal(restarted.acks[0],0);assert.equal(restarted.state.singleplayer.kills,0);
   assert.equal(restarted.state.singleplayer.wave,0);assert.equal(restarted.state.singleplayer.lives,3);
   assert.deepEqual(restarted.state.actors.map(a=>a.id),[0]);
   assert(rows.some(r=>r.round===2&&!r.captured));
   audit.result=result.singleplayer;
  }
  if(summary.scenario==='death') {
   const dead=snapshots.find(r=>r.frame.state.actors.some(a=>a.id===0&&a.health<=0&&a.dead>0));
   assert(dead);assert.equal(dead.frame.state.singleplayer.lives,2);
   const respawn=snapshots.find(r=>r.observedMs>dead.observedMs&&r.frame.state.actors.some(a=>a.id===0&&a.health>0&&a.dead<=0));
   assert(respawn);assert.equal(respawn.frame.state.singleplayer.lives,2);
   const held=wire.filter(r=>r.direction==='in'&&r.frame.type==='input'&&r.observedMs<dead.observedMs).at(-1);
   assert(held.frame.input.interact,'last received pre-death control held E');
   const recapture=rows.find(r=>r.seq>=respawn.frame.seq&&r.captured);
   assert(recapture,'living post-respawn snapshot with fresh capture');
   const neutral=wire.filter(r=>r.direction==='in'&&r.frame.type==='input'&&r.observedMs>dead.observedMs+150&&r.observedMs<respawn.observedMs);
   assert(neutral.length>10);
   for(const r of neutral)for(const key of ['x','z','fire','jump','reload','sprint','crouch','interact','mobility'])assert(!r.frame.input[key]);
   assert(events.some(e=>e.type==='death'&&e.actor===0&&e.killer!==0));
   assert(events.some(e=>e.type==='singleplayer-life'&&e.lives===2));
   audit.death={deadSeq:dead.frame.seq,respawnSeq:respawn.frame.seq,recapturedSeq:recapture.seq,preDeathHeldInputSeq:held.frame.seq,neutralWireInputs:neutral.length};
  }
  assert.equal(summary.exit,0,'harness failed even if gameplay validator passed');
  audit.status='PASS';
 } catch(e) {audit.status='FAIL';audit.error=e.stack;process.exitCode=1;}
 writeFileSync(`${dir}/independent-audit.json`,JSON.stringify(audit,null,2));
 audits.push(audit);
}
writeFileSync('port/reports/horde-independent/live-audits.json',JSON.stringify(audits,null,2));
console.log(JSON.stringify(audits.map(({id,status,scenario,maxKills,minLives,clock,error})=>({id,status,scenario,maxKills,minLives,clock,error}))));

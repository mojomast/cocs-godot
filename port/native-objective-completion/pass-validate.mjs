import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {load} from './validate.mjs';
import {inputEvidence} from './inputs.mjs';
export function validatePass(wire,stdout,map,seconds){
 assert.equal(map,'tidal-citadel');assert.equal(seconds,60);
 const parse=prefix=>stdout.split('\n').filter(l=>l.startsWith(prefix)).map(l=>JSON.parse(l.slice(prefix.length)));
 const native=parse('OBJECTIVE_NATIVE '),boundaries=parse('COMPLETION_BOUNDARY '),done=parse('COMPLETION_DONE '),nativeEvents=parse('COMPLETION_PASS_EVENT '),resultRows=parse('COMPLETION_RESULT ');
 const host=wire.filter(f=>f.connection===0),starts=host.filter(f=>f.type==='start'),results=host.filter(f=>f.type==='results');
 assert.equal(starts.length,2);assert.equal(results.length,1);
 const end=results[0].state;assert.equal(end.over,true);assert.equal(end.winner,0);assert.equal(end.teamScores['0'],1);assert.equal(end.teamScores['1'],0);
 assert.ok(end.time>=seconds&&end.time<seconds+1);assert.ok(results[0].wall-starts[0].wall>=seconds*950);
 for(const [key,value]of Object.entries({timeLimit:seconds,botCount:0,speed:1,gravity:1,damage:1,respawn:2}))assert.equal(end.config[key],value,'ordinary config '+key);
 const events=host.filter(f=>f.type==='events'&&f.round===1).flatMap(f=>f.items),passes=events.filter(e=>e.type==='flag-pass');
 assert.equal(passes.length,1);const pass=passes[0];assert.equal(pass.actor,0);assert.equal(pass.to,2);
 assert.equal(nativeEvents.length,1);assert.deepEqual(nativeEvents[0],pass,'native received source pass event');
 assert.equal(events.filter(e=>e.type==='flag-drop').length,0,'pass is not drop/pickup');
 const pickups=events.filter(e=>e.type==='flag-pickup');assert.equal(pickups.length,1);assert.equal(pickups[0].actor,0);assert.ok(pickups[0].time<pass.time);
 const captures=events.filter(e=>e.type==='capture');assert.equal(captures.length,1);assert.equal(captures[0].actor,2);assert.ok(captures[0].time>pass.time);
 const snapshots=new Map(host.filter(f=>f.type==='snapshot').map(f=>[`${f.round}:${f.seq}`,f])),previousSeq=new Map();
 let primary=false,recipient=false,matches=0,captured=false;
 for(const row of native){
  const frame=snapshots.get(`${row.round}:${row.snapshot_seq}`);assert.ok(frame);assert.ok(row.snapshot_seq>(previousSeq.get(row.round)??-1));previousSeq.set(row.round,row.snapshot_seq);
  const a=frame.state.actors.find(a=>a.id===row.actor_id);assert.equal(row.actor_id,0);for(const axis of ['x','y','z'])assert.ok(Math.abs(a[axis]-row.actor[axis])<1e-4);
  for(const flag of frame.state.flags){const marker=row.rendered['flag_'+flag.team];assert.ok(marker);for(const axis of ['x','y','z'])assert.ok(Math.abs(marker[axis]-flag[axis])<1e-4,'exact source flag root');}
  if(row.round===1){
   const flag=frame.state.flags.find(f=>f.team===1);
   if(flag.state==='carried'&&flag.carrier===0){primary=true;assert.equal(a.carryingFlag,true);}
   if(flag.state==='carried'&&flag.carrier===2){assert.ok(primary);recipient=true;assert.equal(a.carryingFlag,false);const ally=frame.state.actors.find(a=>a.id===2);assert.equal(ally.team,a.team);assert.equal(ally.carryingFlag,true);assert.ok(row.hud.includes('carried'));}
   if(frame.state.teamScores['0']===1){assert.ok(recipient);captured=true;}
  }
  matches++;
 }
 assert.ok(primary&&recipient&&captured&&matches>100);
 const before=host.filter(f=>f.type==='snapshot'&&f.round===1&&f.state.time<=pass.time).at(-1).state,from=before.actors.find(a=>a.id===0),to=before.actors.find(a=>a.id===2);
 assert.equal(from.team,to.team);assert.ok(from.health>0&&to.health>0);assert.ok(Math.hypot(from.x-to.x,from.y-to.y,from.z-to.z)<2.6,'ordinary eligible receiver near carrier');
 const interact=host.filter(f=>f.type==='received'&&f.round===1&&f.frame.type==='input'&&f.frame.input.interact===true);assert.ok(interact.length>0,'native E reached source');
 const carryingFrame=host.find(f=>f.type==='snapshot'&&f.round===1&&f.state.flags.some(flag=>flag.team===1&&flag.carrier===2));assert.ok(carryingFrame.acks['0']>=interact[0].frame.seq,'pass follows applied interact high-water');
 assert.equal(resultRows.length,1);const r=resultRows[0];assert.equal(r.released,true);assert.equal(r.captured,false);assert.equal(r.eligible,false);assert.ok(r.model.hint.includes('RED'));
 const restart=boundaries.find(b=>b.event==='start'&&b.round===2);assert.deepEqual(restart.dynamic,[]);assert.equal(restart.captured,false);assert.equal(restart.pose,false);assert.equal(restart.hud,'Objectives unavailable');
 const fresh=host.find(f=>f.type==='snapshot'&&f.round===2).state;assert.equal(fresh.over,false);assert.equal(fresh.teamScores['0'],0);assert.equal(fresh.teamScores['1'],0);assert.ok(fresh.flags.every(f=>f.state==='at-base'&&f.carrier===null));
 assert.equal(done.length,1);assert.equal(done[0].ok,true);assert.equal(done[0].fresh_capture,true);
 return{status:'PASS',matches,pass:{actor:pass.actor,to:pass.to,time:pass.time},capture:{actor:captures[0].actor,time:captures[0].time},inputs:inputEvidence(wire,native),results:1,restarts:1,normalRate:true,nativeCompletionProven:false};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const {wire,stdout,summary}=load(process.argv[2]);console.log(JSON.stringify(validatePass(wire,stdout,summary.map,summary.seconds),null,2));}

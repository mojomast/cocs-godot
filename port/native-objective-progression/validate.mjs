import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
export function validate(wire,stdout,map,seconds){
 const parse=prefix=>stdout.split('\n').filter(l=>l.startsWith(prefix)).map(l=>JSON.parse(l.slice(prefix.length)));
 const native=parse('OBJECTIVE_NATIVE '),boundaries=parse('PROGRESSION_BOUNDARY '),done=parse('PROGRESSION_DONE ');
 const host=wire.filter(f=>f.connection===0),starts=host.filter(f=>f.type==='start'),results=host.filter(f=>f.type==='results');
 assert.equal(starts.length,2);assert.equal(results.length,1);assert.equal(results[0].state.over,true);
 assert.ok(results[0].state.time>=seconds && results[0].state.time<seconds+1,'legal actual time limit');
 assert.ok(results[0].wall-starts[0].wall>=seconds*950,'normal elapsed wall time');
 for(const [key,value]of Object.entries({timeLimit:seconds,botCount:0,speed:1,gravity:1,damage:1,respawn:2}))assert.equal(results[0].state.config[key],value,'ordinary config '+key);
 const snapshots=new Map(host.filter(f=>f.type==='snapshot').map(f=>[`${f.round}:${f.seq}`,f]));
 let matches=0,contestSamples=0,pushAfter=false,idleAfter=false,checkpoint=false,priorDistance=null,contestDistance=null,returned=false,carried=false,dropped=false;
 const previousSeq=new Map();
 const events=host.filter(f=>f.type==='events').flatMap(f=>f.items);
 for(const row of native){
  const f=snapshots.get(`${row.round}:${row.snapshot_seq}`);assert.ok(f,'recipient/round/sequence association');
  assert.ok(row.snapshot_seq>(previousSeq.get(row.round)??-1),'strict native snapshot order within round');previousSeq.set(row.round,row.snapshot_seq);
  const actor=f.state.actors.find(a=>a.id===row.actor_id);assert.ok(actor);
  for(const axis of ['x','y','z'])assert.ok(Math.abs(actor[axis]-row.actor[axis])<1e-4);
  const fields=map==='tidal-citadel'?f.state.flags.map(flag=>['flag_'+flag.team,flag]):[['cart',f.state.objectives.payload.position]];
  for(const [key,pos]of fields){assert.ok(row.rendered[key]);for(const axis of ['x','y','z'])assert.ok(Math.abs(row.rendered[key][axis]-pos[axis])<1e-4);}
  if(row.round===1 && map==='tidal-citadel'){
   const flag=f.state.flags.find(f=>f.team!==actor.team);
   if(flag.state==='carried'&&flag.carrier===actor.id){carried=true;assert.ok(row.hud.includes('carried'));}
   if(carried&&flag.state==='dropped'){dropped=true;assert.ok(row.hud.includes('dropped'));}
   if(dropped&&flag.state==='at-base'){returned=true;assert.ok(row.hud.includes('at-base'));}
  }
  if(row.round===1 && map==='sunscar-convoy'){
   const p=f.state.objectives.payload;
   if(p.contested){contestSamples++;assert.ok(row.hud.includes('CONTESTED'));if(contestDistance!==null)assert.equal(p.distance,contestDistance);contestDistance=p.distance;for(const team of [0,1])assert.ok(f.state.actors.some(a=>a.team===team&&a.health>0&&Math.hypot(a.x-p.position.x,a.z-p.position.z)<=p.radius+.01),'ordinary opposing actor inside cart radius');}
   if(contestSamples>0 && p.pushing===0 && p.distance>contestDistance+1)pushAfter=true;
   if(pushAfter && !p.contested && p.pushing===null && p.distance===priorDistance)idleAfter=true;
   checkpoint ||= p.checkpointsReached>0;priorDistance=p.distance;
  }
  matches++;
 }
 assert.ok(matches>100);
 if(map==='tidal-citadel'){
  for(const type of ['flag-pickup','flag-drop','flag-return'])assert.ok(events.some(e=>e.type===type),type);
  const drop=events.findIndex(e=>e.type==='flag-drop'),ret=events.findIndex(e=>e.type==='flag-return');assert.ok(ret>drop);
  const returnEvent=events[ret];assert.notEqual(returnEvent.actor,native[0].actor_id,'opponent returned own flag');assert.ok(carried&&dropped&&returned,'native correlated carry/drop/return');
 }else assert.ok(contestSamples>=10 && pushAfter && idleAfter,'contest sustained, push resumes, then idle');
 const restart=boundaries.find(b=>b.event==='start'&&b.round===2);assert.ok(restart);assert.deepEqual(restart.dynamic,[]);assert.equal(restart.captured,false);assert.equal(restart.pose,false);assert.equal(restart.hud,'Objectives unavailable');
 const result=boundaries.find(b=>b.event==='results');assert.equal(result.captured,false);assert.equal(result.control_eligible,false);
 const firstRestart=host.find(f=>f.type==='snapshot'&&f.round===2);assert.ok(firstRestart);assert.equal(firstRestart.state.over,false);assert.equal(firstRestart.state.teamScores['0'],0);assert.equal(firstRestart.state.teamScores['1'],0);
 if(map==='tidal-citadel')assert.ok(firstRestart.state.flags.every(f=>f.state==='at-base'&&f.carrier===null));
 else{
  const p=firstRestart.state.objectives.payload;
  // An ordinary random spawn can already be inside escort radius. The first
  // transmitted snapshot may follow a few normal ticks of legitimate pushing.
  // game/quantize.mjs rounds each wire scalar independently to 3 decimals.
  const halfQuantum=.0005;
  assert.ok(p.distance>=0 && p.distance<=(p.speed+halfQuantum)*(firstRestart.state.time+halfQuantum)+halfQuantum+1e-9 && p.distance<1,'fresh cart distance bounded by fresh round time');
  assert.equal(p.checkpointsReached,0);
 }
 assert.equal(done.length,1);assert.equal(done[0].ok,true);assert.equal(done[0].fresh_capture,true);
 const receipts=wire.filter(f=>f.type==='received' && f.frame.type==='input');
 for(const connection of [0,1])assert.ok(receipts.some(f=>f.connection===connection && Math.hypot(f.frame.input.x,f.frame.input.z)>.1),'both ordinary clients moved');
 return{status:'PASS',matches,returned,capture:events.some(e=>e.type==='capture'),contestSamples,pushAfter,idleAfter,checkpoint,results:1,restarts:1,normalRate:true,nativeCompletionProven:false};
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){const dir=process.argv[2],archive=JSON.parse(readFileSync(`${dir}/archive.json`)),read=name=>{const raw=gunzipSync(readFileSync(`${dir}/${name}.gz`));assert.equal(raw.length,archive[name].bytes);assert.equal(createHash('sha256').update(raw).digest('hex'),archive[name].sha256);return raw.toString();};const summary=JSON.parse(readFileSync(`${dir}/summary.json`));console.log(JSON.stringify(validate(read('wire.jsonl').trim().split('\n').map(JSON.parse),read('native.stdout.log'),summary.map,summary.seconds),null,2));}

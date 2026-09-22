import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {inputEvidence} from './inputs.mjs';
export function validate(wire,stdout,map,seconds){
 const parse=prefix=>stdout.split('\n').filter(l=>l.startsWith(prefix)).map(l=>JSON.parse(l.slice(prefix.length)));
 const native=parse('OBJECTIVE_NATIVE '),boundaries=parse('COMPLETION_BOUNDARY '),done=parse('COMPLETION_DONE '),resultRows=parse('COMPLETION_RESULT ');
 const models=new Map(parse('COMPLETION_HUD ').map(r=>[`${r.round}:${r.seq}`,r.model]));
 const host=wire.filter(f=>f.connection===0),starts=host.filter(f=>f.type==='start'),results=host.filter(f=>f.type==='results');
 assert.equal(map,'sunscar-convoy');assert.equal(seconds,180);
 assert.equal(starts.length,2);assert.equal(results.length,1);
 const end=results[0].state,pEnd=end.objectives.payload;
 assert.equal(end.over,true);assert.equal(pEnd.delivered,true);assert.equal(end.objectives.winner,0);assert.equal(end.winner,0);
 assert.equal(pEnd.distance,pEnd.total);assert.equal(pEnd.checkpointsReached,3);assert.ok(end.time<seconds,'delivery ended before time limit');
 assert.ok(end.time>=pEnd.total/pEnd.speed,'unchanged cart pace lower bound');
 assert.ok(results[0].wall-starts[0].wall>=end.time*950,'normal wall elapsed');
 for(const [key,value]of Object.entries({timeLimit:seconds,botCount:0,speed:1,gravity:1,damage:1,respawn:2}))assert.equal(end.config[key],value,'ordinary config '+key);
 const snapshots=new Map(host.filter(f=>f.type==='snapshot').map(f=>[`${f.round}:${f.seq}`,f])),previousSeq=new Map();
 let matches=0,rollbackSamples=0,bankSamples=0,resumed=false,bankStart=null,bankEnd=null,prev=null,previousTime=null;
 const events=host.filter(f=>f.type==='events'&&f.round===1).flatMap(f=>f.items);
 for(const row of native){
  const f=snapshots.get(`${row.round}:${row.snapshot_seq}`);assert.ok(f,'recipient/round/sequence');
  assert.ok(row.snapshot_seq>(previousSeq.get(row.round)??-1));previousSeq.set(row.round,row.snapshot_seq);
  const actor=f.state.actors.find(a=>a.id===row.actor_id);assert.ok(actor);assert.equal(row.actor_id,0,'actor zero valid');
  for(const axis of ['x','y','z'])assert.ok(Math.abs(actor[axis]-row.actor[axis])<1e-4);
  const p=f.state.objectives.payload;
  for(const axis of ['x','y','z'])assert.ok(Math.abs(row.rendered.cart[axis]-p.position[axis])<1e-4,'exact source-root cart '+axis);
  for(const z of f.state.objectives.zones){const marker=row.rendered['cp_'+z.id];assert.ok(marker);for(const axis of ['x','y','z'])assert.ok(Math.abs(marker[axis]-z[axis])<1e-4,'exact checkpoint root');}
  if(row.round===1){
   const bank=f.state.objectives.zones[0].distance;
   if(p.checkpointsReached>=1)assert.ok(p.distance>=bank-.001,'bank never crossed');
   if(prev&&p.pushing===1&&p.distance<prev.distance-.001){
    rollbackSamples++;assert.equal(p.checkpointsReached,1);assert.equal(p.contested,false);assert.ok(models.get(`${row.round}:${row.snapshot_seq}`).title.includes('ROLLING BACK'));
    assert.equal(f.state.objectives.zones[0].owner,0);assert.equal(f.state.objectives.zones[0].progress,100);assert.equal(f.state.teamScores['0'],1);
    if(prev.pushing===1){const expected=Math.max(bank,prev.distance-p.speed*.5*(f.state.time-previousTime));assert.ok(Math.abs(p.distance-expected)<.004,'unchanged half-speed rollback with codec uncertainty');}
    const inside=a=>a.health>0&&Math.hypot(a.x-p.position.x,a.z-p.position.z)<=p.radius+.01&&Math.abs(a.y-p.position.y)<=5;
    assert.ok(f.state.actors.some(a=>a.team===1&&inside(a)));assert.ok(!f.state.actors.some(a=>a.team===0&&inside(a)),'defender alone');
   }
   if(rollbackSamples>0&&p.pushing===1&&Math.abs(p.distance-bank)<.002){bankSamples++;bankStart??=f.state.time;bankEnd=f.state.time;}
   if(bankSamples>10&&p.pushing===0&&p.distance>bank+4){resumed=true;assert.ok(actor.health>0&&Math.hypot(actor.x-p.position.x,actor.z-p.position.z)<=p.radius+.01,'native primary resumed escort');}
   prev=p;previousTime=f.state.time;
  }
  matches++;
 }
 assert.ok(matches>100);assert.ok(rollbackSamples>10,'actual decreasing rollback');assert.ok(bankSamples>20&&bankEnd-bankStart>=1.5,'sustained defender at bank');assert.ok(resumed,'primary resumed beyond earlier rollback point');
 const cps=events.filter(e=>e.type==='payload-checkpoint');assert.deepEqual(cps.map(e=>e.index),[1,2,3]);
 assert.equal(events.filter(e=>e.type==='payload-delivered').length,1,'one source delivered event');assert.equal(events.find(e=>e.type==='payload-delivered').team,0);
 assert.ok(!events.some(e=>e.type==='payload-hold'),'not time-limit hold');
 assert.equal(resultRows.length,1);const r=resultRows[0];assert.equal(r.delivered,true);const settled=parse('COMPLETION_SETTLED ');assert.ok(r.released===true||(settled.length===1&&settled[0].released===true&&settled[0].phase===4&&!settled[0].captured&&!settled[0].eligible),'result physical release');assert.equal(r.captured,false);assert.equal(r.eligible,false);assert.ok(r.hud.includes('DELIVERED'));
 for(const axis of ['x','y','z'])assert.ok(Math.abs(r.rendered.cart[axis]-pEnd.position[axis])<1e-4);
 const restart=boundaries.find(b=>b.event==='start'&&b.round===2);assert.ok(restart);assert.deepEqual(restart.dynamic,[]);assert.equal(restart.captured,false);assert.equal(restart.pose,false);assert.equal(restart.hud,'Objectives unavailable');
 const fresh=host.find(f=>f.type==='snapshot'&&f.round===2).state;assert.equal(fresh.over,false);assert.equal(fresh.teamScores['0'],0);assert.equal(fresh.teamScores['1'],0);
 const p=fresh.objectives.payload,q=.0005;assert.equal(p.delivered,false);assert.equal(p.checkpointsReached,0);assert.ok(p.distance>=0&&p.distance<=(p.speed+q)*(fresh.time+q)+q+1e-9&&p.distance<1);
 assert.equal(done.length,1);assert.equal(done[0].ok,true);assert.equal(done[0].fresh_capture,true);
 const receipts=wire.filter(f=>f.type==='received'&&f.frame.type==='input');
 for(const connection of [0,1])assert.ok(receipts.some(f=>f.connection===connection&&Math.hypot(f.frame.input.x,f.frame.input.z)>.1),'ordinary movement receipt');
 const inputs=inputEvidence(wire,native);
 return{status:'PASS',matches,rollbackSamples,bankSamples,bankStart,bankEnd,resumed,deliveryTime:end.time,checkpoints:cps.map(e=>({index:e.index,time:e.time})),inputs,results:1,restarts:1,normalRate:true,nativeCompletionProven:false};
}
export function load(dir){const archive=JSON.parse(readFileSync(`${dir}/archive.json`)),read=name=>{const raw=gunzipSync(readFileSync(`${dir}/${name}.gz`));assert.equal(raw.length,archive[name].bytes);assert.equal(createHash('sha256').update(raw).digest('hex'),archive[name].sha256);return raw.toString();};return{summary:JSON.parse(readFileSync(`${dir}/summary.json`)),wire:read('wire.jsonl').trim().split('\n').map(JSON.parse),stdout:read('native.stdout.log')};}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const {wire,stdout,summary}=load(process.argv[2]);console.log(JSON.stringify(validate(wire,stdout,summary.map,summary.seconds),null,2));}

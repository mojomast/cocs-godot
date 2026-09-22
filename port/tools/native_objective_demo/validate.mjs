import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
export const readEvidence = path => existsSync(path) ? readFileSync(path,'utf8') : gunzipSync(readFileSync(path+'.gz')).toString('utf8');
import {resolve} from 'node:path';
export function validate(wire,native,map){
 const starts=wire.filter(x=>x.type==='start');
 assert.equal(starts.length,1,'exactly one observed fresh round');
 assert.equal(starts[0].mapId,map,'requested map');
 const snapshots=new Map(wire.filter(x=>x.type==='snapshot').map(x=>[x.seq,x]));
 const receipts=wire.filter(x=>x.type==='input_received');
 let matches=0,carried=false,dropped=false,push=false,idle=false,lastDistance=null,ack=0;
 let priorSeq=-1;
 for(const row of native){
  assert.ok(Number.isInteger(row.snapshot_seq)&&row.snapshot_seq>priorSeq,'strict native sequence ordering');priorSeq=row.snapshot_seq;
  const frame=snapshots.get(row.snapshot_seq);assert.ok(frame,'native snapshot has server sequence');
  const actor=frame.state.actors.find(a=>a.id===row.actor_id);assert.ok(actor,'actor identity');
  for(const key of ['x','y','z'])assert.ok(Math.abs(actor[key]-row.actor[key])<1e-4,'actor position '+key);
  ack=Math.max(ack,row.ack);
  const fields=map==='tidal-citadel'?frame.state.flags.map(f=>['flag_'+f.team,f]):[['cart',frame.state.objectives.payload.position]];
  for(const [key,value] of fields){assert.ok(row.rendered[key],'rendered '+key);for(const axis of ['x','y','z'])assert.ok(Math.abs(row.rendered[key][axis]-value[axis])<1e-4,key+' authoritative '+axis);}
  if(map==='tidal-citadel'){
   const flag=frame.state.flags.find(f=>f.team!==actor.team);
   if(flag.state==='carried' && flag.carrier===actor.id){carried=true;assert.ok(row.hud.includes('carried'));}
   if(carried && flag.state==='dropped'){dropped=true;assert.ok(row.hud.includes('dropped'));}
  }else{
   const p=frame.state.objectives.payload;
   if(lastDistance!==null && p.distance>lastDistance && p.pushing===actor.team){push=true;assert.ok(row.hud.includes('PUSHING'));}
   if(push && p.pushing===null && p.contested===false && p.distance===lastDistance){idle=true;assert.ok(row.hud.includes('IDLE'));}
   lastDistance=p.distance;
  }
  matches++;
 }
 assert.ok(matches>=10,'enough correlated snapshots');
 assert.ok(receipts.some(r=>Math.abs(r.input.x)+Math.abs(r.input.z)>0),'nonneutral movement received');
 if(map==='tidal-citadel'){assert.ok(carried&&dropped,'carry and drop witnessed');assert.ok(receipts.some(r=>r.input.interact===true),'interaction received');assert.ok(wire.some(f=>f.type==='events'&&f.items.some(e=>e.type==='flag-drop')),'source drop event');}
 else assert.ok(push&&idle,'push then idle witnessed');
 return {status:'PASS',matches,carried,dropped,push,idle,ackHighWater:ack,receivedInputs:receipts.length,nativeCompletionProven:false};
}
if(process.argv[1]&&import.meta.url.endsWith('/'+process.argv[1].split('/').at(-1))){
 const directory=resolve(process.argv[2]);
 const summary=JSON.parse(readFileSync(resolve(directory,'summary.json')));
 const wire=readEvidence(resolve(directory,'wire.jsonl')).trim().split('\n').map(JSON.parse);
 const native=readEvidence(resolve(directory,'native.stdout.log')).split('\n').filter(x=>x.startsWith('OBJECTIVE_NATIVE ')).map(x=>JSON.parse(x.slice(17)));
 const result=validate(wire,native,summary.map);writeFileSync(resolve(directory,'validation.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}

// Passive observers produce ordinary input only; never mutate Match/actors.
import assert from 'node:assert/strict';
export const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
export function route(m,a,b){
 const nearest=p=>m.nav.reduce((best,n,i)=>distance(n,p)<distance(m.nav[best],p)?i:best,0);
 const start=nearest(a),end=nearest(b),prev=new Map([[start,-1]]),queue=[start];
 for(let i=0;i<queue.length&&!prev.has(end);i++)for(const n of m.edges[queue[i]])if(!prev.has(n)){prev.set(n,queue[i]);queue.push(n);}
 assert.ok(prev.has(end),'No source route to objective');
 const result=[b];for(let i=end;i!==-1;i=prev.get(i))result.push(m.nav[i]);return result.reverse();
}
export function controller(){
 const paths=new Map();
 return (m,a,target,key)=>{
  if(a.health<=0)return {};
  let path=paths.get(a.id);
  if(!path||path.key!==key||path.deaths!==a.deaths){path={key,deaths:a.deaths,points:route(m,a,target)};paths.set(a.id,path);}
  while(path.points.length>1&&distance(a,path.points[0])<.7)path.points.shift();
  const p=path.points[0],d=distance(a,p);
  return d>.35?{x:(p.x-a.x)/d,z:(p.z-a.z)/d,yaw:Math.atan2(a.x-p.x,a.z-p.z)}:{};
 };
}
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x)),wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
export function drive(m,id){
 const r=m.race.racers.find(r=>r.actorId===id),v=m.vehicles.find(v=>v.id===r.vehicleId)??m.vehicles[id];
 const points=m.arena.race.centerline,n=points.length,a=points[(r.nextGate+n-1)%n],b=points[r.nextGate],c=points[(r.nextGate+1)%n];
 const dx=b.x-a.x,dz=b.z-a.z,len=distance(a,b),along=clamp(((v.position.x-a.x)*dx+(v.position.z-a.z)*dz)/len,0,len);
 const t=clamp((along+8)/len,0,1),p={x:a.x+dx*t,z:a.z+dz*t};
 if(along+8>len){const u=(along+8-len)/distance(b,c);p.x=b.x+(c.x-b.x)*u;p.z=b.z+(c.z-b.z)*u;}
 const err=wrap(Math.atan2(p.x-v.position.x,p.z-v.position.z)-v.heading),turn=Math.abs(wrap(Math.atan2(c.x-b.x,c.z-b.z)-Math.atan2(dx,dz)));
 const desired=len-along<22&&turn>.5?8:14,throttle=v.speed<desired?1:0,steer=clamp(err*1.8,-1,1),yaw=v.heading-Math.PI;
 return {yaw,x:-throttle*Math.sin(yaw)-steer*Math.cos(yaw),z:-throttle*Math.cos(yaw)+steer*Math.sin(yaw),jump:v.speed>desired+2};
}
export function assertOutcome(m,mode,respawn){
 const a=m.actors[0],state=m.snapshot();
 assert.ok(m.over);assert.notEqual(state.overReason,'time');
 if(mode==='puma-race'){
  assert.equal(state.overReason,'race-finish');assert.ok(m.race.racers.some(r=>r.actorId===state.winner&&r.completedLaps>=1));
  assert.ok(respawn.raceReset&&respawn.raceRecovered,'ordinary guest reset/recovery required');
 }else{
  assert.equal(state.overReason,['deathmatch','teamdeathmatch'].includes(mode)?'frag':mode==='ctf'?'capture':'objective');
  assert.ok(respawn.dead&&respawn.alive,'actual death followed by source respawn required');
  if(mode==='deathmatch') {assert.ok(a.frags>=m.config.fragLimit);assert.deepEqual(state.leaders,[a.name]);}
  else assert.equal(state.winner,a.team,'correct team winner');
  if(mode==='teamdeathmatch')assert.ok(a.frags>=m.config.fragLimit);
  else if(mode==='ctf')assert.ok(a.scoreStats.captures>=1);
  else if(mode!=='deathmatch'){
   assert.equal(m.objectiveState.winner,a.team);assert.ok(!m.objectiveState.tiebreak);
   assert.ok(a.scoreStats.objectiveTime>0||a.scoreStats.objectiveCaptures>0);
  }
 }
 return state;
}

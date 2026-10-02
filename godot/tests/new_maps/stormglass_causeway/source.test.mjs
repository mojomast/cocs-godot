import test from 'node:test';
import assert from 'node:assert/strict';
import {Match,floorAt,obstructed,navigation,walkEdge,moveActor} from '../../../../game/core.mjs';
import {PUMA,createVehicle,stepVehicle} from '../../../../game/vehicles.mjs';
import {initializeRace,crossRaceGates,raceStandings} from '../../../../game/race.mjs';
import {validateMapSchema} from '../../../../game/map-schema.mjs';
import {terrainRayHit} from '../../../../game/terrain.mjs';
import {makeStormglass} from '../../../../tools/godot-multiplayer/new-maps/stormglass-causeway/recipe.mjs';
const arena=makeStormglass();
const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
function make(options={}){
  const m=new Match('chatgpt','openclaw',()=>.25,'puma-circuit',{mode:'puma-race',fragLimit:1,timeLimit:240,botCount:0,...options});
  // Controlled initial map injection only; all subsequent motion/scoring belongs to Match.
  m.arena=arena;initializeRace(m);
  m.wallRefusals=0;const collision=m.vehicleCollision.bind(m);
  m.vehicleCollision=(next,vehicle)=>{const result=collision(next,vehicle);if(result===false)m.wallRefusals++;return result;};
  return m;
}
function input(m,id=0){
  const r=m.race.racers[id],v=m.vehicles[id],points=arena.race.centerline,n=points.length;
  const a=points[(r.nextGate+n-1)%n],b=points[r.nextGate],c=points[(r.nextGate+1)%n];
  const dx=b.x-a.x,dz=b.z-a.z,len=Math.hypot(dx,dz),along=clamp(((v.position.x-a.x)*dx+(v.position.z-a.z)*dz)/len,0,len);
  const look=8,t=clamp((along+look)/len,0,1),p={x:a.x+dx*t,z:a.z+dz*t};
  if(along+look>len){const l=Math.hypot(c.x-b.x,c.z-b.z),u=(along+look-len)/l;p.x=b.x+(c.x-b.x)*u;p.z=b.z+(c.z-b.z)*u;}
  const err=wrap(Math.atan2(p.x-v.position.x,p.z-v.position.z)-v.heading),turn=Math.abs(wrap(Math.atan2(c.x-b.x,c.z-b.z)-Math.atan2(dx,dz)));
  const desired=len-along<22&&turn>.5?8:14,throttle=v.speed<desired?1:0,steer=clamp(err*1.8,-1,1),yaw=v.heading-Math.PI;
  return {yaw,x:-throttle*Math.sin(yaw)-steer*Math.cos(yaw),z:-throttle*Math.cos(yaw)+steer*Math.sin(yaw),jump:v.speed>desired+2};
}
test('schema, real road ribbon, triangulated barriers and source gate height constraint',()=>{
  assert.deepEqual(validateMapSchema(arena),[]);
  assert.ok(arena.metrics.length>=900&&arena.metrics.length<=1400,JSON.stringify(arena.metrics));
  assert.ok(arena.terrain.walls.every(w=>w.vertices.length===3));
  for(const p of [...arena.race.centerline,...arena.race.grid]){assert.equal(floorAt(p.x,p.z,arena),0);assert.equal(obstructed(p.x,0,p.z,2.2,arena),false,JSON.stringify(p));}
  assert.equal(floorAt(220,-190,arena),null);
  const m=make(),r=m.race.racers[0],g=m.race.gates[0];
  crossRaceGates(m.race,r,{x:g.x-g.nx,y:10,z:g.z-g.nz},{x:g.x+g.nx,y:10,z:g.z+g.nz},0,1);
  assert.equal(r.passed,0,'absolute-height source rule is preserved');
});
test('ordinary sampled inputs continuously drive a mounted source lap and finish',t=>{
  const m=make();let distance=0,maxStep=0,resets=0,impacts=0;
  for(let frame=0;frame<14400&&!m.over;frame++){
    const p={...m.vehicles[0].position};m.step(1/60,input(m));
    const d=Math.hypot(m.vehicles[0].position.x-p.x,m.vehicles[0].position.z-p.z);distance+=d;maxStep=Math.max(maxStep,d);
    if(m.race.racers[0].resetWait>0)resets++;
    impacts=m.wallRefusals;
  }
  t.diagnostic(JSON.stringify({reason:m.overReason,elapsed:m.race.elapsed,distance,maxStep,resets,impacts,standings:raceStandings(m.race)}));
  assert.equal(m.overReason,'race-finish');assert.equal(resets,0);assert.equal(impacts,0);assert.ok(maxStep<1);assert.equal(m.race.racers[0].completedLaps,1);assert.equal(m.actors[0].vehicleSeat,'driver');
});
test('bounded actual autonomous source pack finishes without checkpoint resets',t=>{
  const m=make({botCount:3});m.actors[0].bot=m.actors[1].bot;let resets=0,maxStep=0;
  for(let frame=0;frame<14400&&!m.over;frame++){
    const before=m.vehicles.map(v=>({...v.position}));m.step(1/60,{inputs:{}});
    m.vehicles.forEach((v,i)=>{maxStep=Math.max(maxStep,Math.hypot(v.position.x-before[i].x,v.position.z-before[i].z));});
    resets+=m.race.racers.filter(r=>r.resetWait>0).length;
  }
  t.diagnostic(JSON.stringify({reason:m.overReason,elapsed:m.race.elapsed,resets,maxStep,standings:raceStandings(m.race)}));
  assert.equal(m.overReason,'race-finish');assert.equal(resets,0);assert.ok(maxStep<1);
});
test('two ordinary input competitors: source countdown, complete race, standings and stopped results',t=>{
  const m=make({humanCount:2});const initial=m.vehicles.map(v=>({...v.position}));
  for(let i=0;i<179;i++)m.step(1/60,{inputs:{0:input(m,0),1:input(m,1)}});
  assert.deepEqual(m.vehicles.map(v=>v.position),initial);assert.equal(m.race.phase,'countdown');
  for(let i=0;i<14000&&!m.over;i++)m.step(1/60,{inputs:{0:input(m,0),1:input(m,1)}});
  assert.equal(m.overReason,'race-finish');const standings=raceStandings(m.race);
  assert.equal(standings.length,2);assert.equal(standings[0].completedLaps,1);
  const elapsed=m.race.elapsed;m.step(1,{x:1});assert.equal(m.race.elapsed,elapsed);
  assert.ok(m.race.racers.every(r=>r.resetWait===0&&r.passed>=21));
  t.diagnostic(JSON.stringify({elapsed,standings}));
});
test('backward, shortcut, repeated, airborne gates and ordinary reset cannot award a lap',()=>{
  const m=make(),r=m.race.racers[0],g=m.race.gates[0];
  const p=(gate,d,y=0)=>({x:gate.x+gate.nx*d,y,z:gate.z+gate.nz*d});
  crossRaceGates(m.race,r,p(g,1),p(g,-1),0,1);assert.equal(r.passed,0);
  const skipped=m.race.gates[7];crossRaceGates(m.race,r,p(skipped,-1),p(skipped,1),0,1);assert.equal(r.passed,0);
  crossRaceGates(m.race,r,p(g,-1),p(g,1),0,1);assert.equal(r.passed,1);
  crossRaceGates(m.race,r,p(g,-1),p(g,1),0,1);assert.equal(r.passed,1);assert.equal(r.completedLaps,0);
  const saved={passed:r.passed,nextGate:r.nextGate,completedLaps:r.completedLaps};
  m.step(3);m.step(1/60,{interact:true});
  for(const key of Object.keys(saved))assert.equal(r[key],saved[key]);assert.ok(r.resetWait>0);
});
test('all 42 road barriers stop sustained infantry bodies and Puma noses, and block shots',t=>{
  const m=make();let count=0;
  for(const edge of Object.values(arena.race.boundary))for(let i=0;i<edge.length;i++){
    const a=edge[i],b=edge[(i+1)%edge.length],c=arena.race.centerline[i],d=arena.race.centerline[(i+1)%edge.length];
    const p={x:(a.x+b.x)/2,z:(a.z+b.z)/2},mid={x:(c.x+d.x)/2,z:(c.z+d.z)/2};
    const len=Math.hypot(b.x-a.x,b.z-a.z),u={x:-(b.z-a.z)/len,z:(b.x-a.x)/len};
    if((p.x-mid.x)*u.x+(p.z-mid.z)*u.z<0){u.x*=-1;u.z*=-1;}
    const actor={...m.actors[0],x:p.x-u.x*5,y:0,z:p.z-u.z*5,vx:0,vy:0,vz:0,grounded:true,vehicleId:null,vehicleSeat:null};
    for(let f=0;f<180;f++)moveActor(actor,{x:u.x,z:u.z},1/60,arena);
    const clearance=(p.x-actor.x)*u.x+(p.z-actor.z)*u.z;
    assert.ok(clearance>=.4&&clearance<1,`${i}: body ${clearance}`);
    const v=createVehicle(PUMA);Object.assign(v.position,{x:p.x-u.x*7,y:0,z:p.z-u.z*7});v.heading=Math.atan2(u.x,u.z);
    for(let f=0;f<180;f++)stepVehicle(v,{throttle:1},1/60,next=>m.vehicleCollision(next,v),()=>0);
    const nose=(p.x-v.position.x)*u.x+(p.z-v.position.z)*u.z;
    assert.ok(nose>=2&&nose<3,`${i}: vehicle ${nose}`);
    assert.ok(terrainRayHit({x:p.x-u.x*5,y:1,z:p.z-u.z*5},{...u,y:0},10,arena.terrain));count++;
  }
  t.diagnostic(`${count} sustained body, vehicle and shot contacts`);
});
test('freight vault and raised gate ceilings block upward shots without stealing road support',()=>{
  for(const i of [1,4,5,6,14,18]){
    const a=arena.race.centerline[i],b=arena.race.centerline[(i+1)%21],p={x:(a.x+b.x)/2,y:1,z:(a.z+b.z)/2};
    assert.equal(floorAt(p.x,p.z,arena),0);
    const hit=terrainRayHit(p,{x:0,y:1,z:0},30,arena.terrain);
    assert.ok(hit&&hit.distance>=6&&hit.distance<=16,`${i}: ${JSON.stringify(hit)}`);
  }
});
test('source navigation is one connected supported circuit',()=>{
  const {nodes,edges}=navigation(arena),seen=new Set([0]),queue=[0];
  for(let i=0;i<queue.length;i++)for(const j of edges[queue[i]])if(!seen.has(j)){seen.add(j);queue.push(j);}
  assert.equal(seen.size,nodes.length);assert.ok(nodes.length>100);
  edges.forEach((list,i)=>list.forEach(j=>assert.ok(walkEdge(nodes[i],nodes[j],arena))));
});
test('measure stock Puma acceleration, braking and steering envelope used by the road',t=>{
  const v=createVehicle(PUMA);let ticks=0;
  while(v.speed<19.5&&ticks++<600)stepVehicle(v,{throttle:1},1/60,p=>p,()=>0);
  assert.ok(v.speed>=19.5);const accelerationSeconds=ticks/60;
  for(let i=0;i<120;i++)stepVehicle(v,{throttle:1},1/60,p=>p,()=>0);
  assert.ok(v.speed>19.9&&v.speed<=20);const maxSpeed=v.speed,from={...v.position};ticks=0;
  while(v.speed>.5&&ticks++<300)stepVehicle(v,{brake:true},1/60,p=>p,()=>0);
  const brakingDistance=Math.hypot(v.position.x-from.x,v.position.z-from.z);
  assert.ok(brakingDistance>4&&brakingDistance<12);
  const turning=createVehicle(PUMA);for(let i=0;i<120;i++)stepVehicle(turning,{throttle:1},1/60,p=>p,()=>0);
  const heading=turning.heading;stepVehicle(turning,{throttle:1,steer:1},1/60,p=>p,()=>0);
  const yawRate=wrap(turning.heading-heading)*60,radius=turning.speed/yawRate;
  assert.ok(radius>2&&radius<10);
  t.diagnostic(JSON.stringify({bodyRadius:Math.hypot(1.05,1.8),raceContactRadius:1.7,accelerationSeconds,maxSpeed,brakingDistance,brakingSeconds:ticks/60,fullSteerRadius:radius,yawRate,roadWidth:28}));
});

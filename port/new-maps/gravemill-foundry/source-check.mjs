import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {canonical} from '../../multiplayer-worlds/catalog.mjs';
import {floorAt,moveActor,navigation,obstructed,walkEdge,rayWorld,visible} from '../../../game/core.mjs';
import {terrainSupportAt} from '../../../game/terrain.mjs';
import {validateMapSchema} from '../../../game/map-schema.mjs';
import {createVehicle,PUMA,stepVehicle,takeVehicleSeat,leaveVehicleSeat} from '../../../game/vehicles.mjs';
import {payloadTemplate,stepPayload} from '../../multiplayer-worlds/derived/payload.mjs';
const {recipe}=await import(process.env.FOUNDRY_CANDIDATE ? '../../../tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/recipe.mjs' : '../../../tools/godot-multiplayer/new-maps/gravemill-foundry/recipe.mjs');
const started=performance.now(),arena=recipe(),results=[];
const ceilingShotLimit=process.env.FOUNDRY_CANDIDATE?20:12;
const record=(name,details)=>{results.push({name,...details});console.log(name,JSON.stringify(details));};
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x)),wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
export function follower(arena,points,onStep=()=>{},actor=null){
 const [x,z]=points[0],a=actor??{x,y:floorAt(x,z,arena),z,vx:0,vy:0,vz:0,yaw:0,pitch:0,grounded:true,health:100,team:0,character:'chatgpt',harness:'openclaw',powerups:{}};
 let steps=0,distance=0,maxFloorError=0;
 for(const [tx,tz] of points.slice(1)){
  let local=0;while(Math.hypot(tx-a.x,tz-a.z)>.3&&local++<5000){const dx=tx-a.x,dz=tz-a.z,old={x:a.x,z:a.z};moveActor(a,{x:dx,z:dz},.025,arena);onStep(a,.025);steps++;distance+=Math.hypot(a.x-old.x,a.z-old.z);maxFloorError=Math.max(maxFloorError,Math.abs(a.y-floorAt(a.x,a.z,arena)));}
  assert.ok(local<5000,`movement stuck ${a.x},${a.z} -> ${tx},${tz}`);
 }
 return {actor:a,steps,distance,maxFloorError};
}
assert.deepEqual(validateMapSchema(arena),[]);
const markers=[...arena.spawns,...arena.pickups.map(p=>p.slice(1)),...arena.objectiveZones,...arena.vehicles];
for(const p of markers){const [x,z]=Array.isArray(p)?p:[p.x,p.z],y=floorAt(x,z,arena);assert.ok(Number.isFinite(y)&&!obstructed(x,y,z,.65,arena),`blocked marker ${x},${z}`);assert.ok(Math.abs(y-terrainSupportAt(x,z,arena.terrain,.8).y)<.03);}
record('schema-and-markers',{markers:markers.length});
for(const r of arena.routes){
 for(let i=1;i<r.points.length;i++){const a=r.points[i-1],b=r.points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1]));let prev=null;for(let j=0;j<=n;j++){const x=a[0]+(b[0]-a[0])*j/n,z=a[1]+(b[1]-a[1])*j/n,p={x,y:floorAt(x,z,arena),z};assert.ok(!obstructed(x,p.y,z,r.width>=18?2.2:.65,arena),`route ${r.id}: ${x},${z}`);if(prev)assert.ok(walkEdge(prev,p,arena),`edge ${r.id}`);prev=p;}}
 const {actor,...forward}=follower(arena,r.points),{actor:reverseActor,...reverse}=follower(arena,r.points.toReversed());
 record(`moveActor-${r.id}`,{forward,reverse});
}
const graph=navigation(arena),closest=p=>{const [x,z]=Array.isArray(p)?p:[p.x,p.z];let best=-1,d=Infinity;graph.nodes.forEach((n,i)=>{const dist=Math.hypot(n.x-x,n.z-z);if(dist<d){d=dist;best=i;}});assert.ok(d<3,`nav target distance ${d} at ${x},${z}`);return best;};
const reached=new Set([closest(arena.spawns[0])]),queue=[...reached];for(const i of queue)for(const j of graph.edges[i])if(!reached.has(j)){reached.add(j);queue.push(j);}
for(const marker of markers)assert.ok(reached.has(closest(marker)),'disconnected marker');
record('source-navigation',{nodes:graph.nodes.length,connected:reached.size,markers:markers.length});
const points=[...arena.routes[0].points,...arena.routes[1].points.slice(1)].map(([x,z])=>({x,z}));
const car=createVehicle(PUMA);car.id='foundry-check-puma';Object.assign(car.position,{...points[0],y:0});car.heading=Math.atan2(points[1].x-points[0].x,points[1].z-points[0].z);
assert.ok(takeVehicleSeat(car,77,'driver'));let sector=0,steps=0,collisions=0,distance=0;
while(sector<points.length-1&&steps++<30000){const a=points[sector],b=points[sector+1],here=car.position,dx=b.x-a.x,dz=b.z-a.z,length=Math.hypot(dx,dz),along=((here.x-a.x)*dx+(here.z-a.z)*dz)/length;if(along>length-2){sector++;continue;}const look=clamp(along+8,3,length+3),target={x:a.x+dx*look/length,z:a.z+dz*look/length},error=wrap(Math.atan2(target.x-here.x,target.z-here.z)-car.heading),old={...here};stepVehicle(car,{throttle:car.speed<8?1:0,steer:clamp(error*1.5,-1,1),brake:car.speed>10},.025,next=>{if(obstructed(next.x,floorAt(next.x,next.z,arena),next.z,2.2,arena)){collisions++;return false;}return next;},(x,z)=>floorAt(x,z,arena));distance+=Math.hypot(car.position.x-old.x,car.position.z-old.z);}
assert.equal(collisions,0);assert.equal(sector,points.length-1);leaveVehicleSeat(car,77);assert.equal(car.driver,null);
record('source-Puma-mounted-service-lap',{sector,steps,distance,collisions,seatReleased:true});
const state=payloadTemplate(arena,{segments:3,navigation:graph,floorAt,walkEdge,obstructed});
assert.ok(state.total>330&&state.total<480);assert.equal(state.checkpoints.length,3);
for(const p of arena.payloadPath)assert.ok(state.path.some(q=>Math.hypot(p.x-q.x,p.z-q.z)<.15));
for(const p of state.path)assert.ok(Math.abs(p.y-floorAt(p.x,p.z,arena))<.15);
record('source-derived-payload-path',{metres:state.total,points:state.path.length,checkpoints:state.checkpoints});
// Continuous escort uses only real moveActor input and source payload update.
const first=state.path[0],escort={x:first.x,y:first.y,z:first.z,vx:0,vy:0,vz:0,grounded:true,health:100,team:0,character:'chatgpt',harness:'openclaw',powerups:{}};
let escortSteps=0;while(!state.delivered&&escortSteps++<20000){const dx=state.position.x-escort.x,dz=state.position.z-escort.z;moveActor(escort,{x:Math.hypot(dx,dz)>.6?dx:0,z:Math.hypot(dx,dz)>.6?dz:0},.025,arena);stepPayload(state,[escort],.025);}
assert.ok(state.delivered);record('source-payload-delivery-movement-fixture',{steps:escortSteps,seconds:escortSteps*.025,checkpointsReached:state.checkpointsReached});
for(const cx of [-66,66]){const z=36+.14*cx;assert.equal(floorAt(cx,z,arena),12);assert.ok(!obstructed(cx,12,z,.65,arena));assert.ok(rayWorld({x:cx,y:13.5,z},{x:0,y:1,z:0},30,arena)<ceilingShotLimit,'roof must stop shot');assert.ok(visible({x:cx-28,y:13.5,z:36+.14*(cx-28)},{x:cx+28,y:13.5,z:36+.14*(cx+28)},arena),'no invisible portal AABB');const x=cx-52/3;assert.ok(visible({x,y:14.5,z:24+.14*x},{x,y:14.5,z:29+.14*x},arena),'window opening must pass shots');assert.ok(!visible({x,y:17.5,z:24+.14*x},{x,y:17.5,z:29+.14*x},arena),'window header must stop shots');}
const corner={x:-81,y:0,z:-62-.14*81,vx:0,vy:0,vz:0,grounded:true,health:100,character:'chatgpt',harness:'openclaw',powerups:{}};
for(let i=0;i<160;i++)moveActor(corner,{x:1,z:0},.025,arena);
assert.ok(corner.x<-78,'continuous input cannot cross the buttress face');assert.ok(!obstructed(corner.x,corner.y,corner.z,.3,arena));
assert.ok(rayWorld({x:-81,y:1.4,z:-62-.14*81},{x:1,y:0,z:0},20,arena)<3.1);
assert.ok(!visible({x:-166,y:1.45,z:-62-.14*166},{x:166,y:1.45,z:-62+.14*166},arena),'cross-map ground shot must have cover');
record('vault-shot-support-and-sightline',{vaults:2,openPortals:4,windowOpenings:2,windowHeaders:2,continuousWallContactSteps:160,spawnSightlineBlocked:true});
const output={status:'source-checks-passed-native-pending',geometryHash:createHash('sha256').update(canonical(arena)).digest('hex'),milliseconds:performance.now()-started,results};
if(process.env.FOUNDRY_EVIDENCE){fs.mkdirSync(process.env.FOUNDRY_EVIDENCE,{recursive:true});fs.writeFileSync(`${process.env.FOUNDRY_EVIDENCE}/source-check.json`,JSON.stringify(output,null,2)+'\n');}
console.log(JSON.stringify(output,null,2));

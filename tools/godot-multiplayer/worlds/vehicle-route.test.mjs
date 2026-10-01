import assert from 'node:assert/strict';
import test from 'node:test';
import {floorAt,obstructed} from '../../../game/core.mjs';
import {createVehicle,PUMA,stepVehicle} from '../../../game/vehicles.mjs';
import {WORLD_RECIPES} from './recipes.mjs';

const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const circuit=WORLD_RECIPES.find(m=>m.id==='sirocco-circuit');
const mapById=id=>WORLD_RECIPES.find(m=>m.id===id);

function drive(map,points,loop=false){
  const v=createVehicle(PUMA);
  Object.assign(v.position,{x:points[0].x,y:0,z:points[0].z});
  v.heading=Math.atan2(points[1].x-points[0].x,points[1].z-points[0].z);
  let sector=0,collisions=0,steps=0,minClearance=Infinity;
  const ground=(x,z)=>floorAt(x,z,map);
  const collide=next=>{
    if(obstructed(next.x,ground(next.x,next.z),next.z,2.2,map)){collisions++;return false;}
    return next;
  };
  const total=loop?points.length:points.length-1;
  while(sector<total&&steps++<25000){
    const here=v.position,a=points[sector%points.length],b=points[(sector+1)%points.length];
    const dx=b.x-a.x,dz=b.z-a.z,length=Math.hypot(dx,dz),along=((here.x-a.x)*dx+(here.z-a.z)*dz)/length;
    if(along>length-3){sector++;continue;}
    const look=clamp(along+10,4,length+6);
    const aim={x:a.x+dx*look/length,z:a.z+dz*look/length};
    const desired=Math.atan2(aim.x-here.x,aim.z-here.z),error=wrap(desired-v.heading);
    const upcoming=points[(sector+2)%points.length];
    const turn=Math.abs(wrap(Math.atan2(upcoming.x-b.x,upcoming.z-b.z)-Math.atan2(dx,dz)));
    const targetSpeed=turn>.55&&along>length-20?8:11;
    const throttle=v.speed<targetSpeed?1:0;
    stepVehicle(v,{throttle,steer:clamp(error*1.5,-1,1),brake:v.speed>targetSpeed+2},.025,collide,ground);
    minClearance=Math.min(minClearance,Math.min(here.x-map.bounds.minX,map.bounds.maxX-here.x,here.z-map.bounds.minZ,map.bounds.maxZ-here.z));
  }
  return {sector,total,collisions,steps,minClearance};
}

test('source Puma physics can negotiate all 14 Sirocco sectors without wall contact',()=>{
  // Deterministic racing-line controller; speed is capped below max on turns.
  // This exercises the actual source wheelbase, grip and steering integration.
  const {collisions,sector,total,minClearance}=drive(circuit,circuit.race.centerline,true);
  assert.equal(collisions,0,`Puma collided ${collisions} times by sector ${sector}`);
  assert.equal(sector,total,'Puma completed one authored checkpoint lap');
  assert.ok(minClearance>3);
});

test('source Puma physics negotiates the dock freight bends and archipelago causeway',()=>{
  const dock=mapById('breakwater-exchange'),isles=mapById('tern-archipelago');
  for(const [m,path] of [[dock,dock.payloadPath],[isles,isles.lanes[0].waypoints.map(([x,z])=>({x,z}))]]){
    const result=drive(m,path);
    assert.equal(result.collisions,0,`${m.id}: ${result.collisions} impacts by sector ${result.sector}`);
    assert.equal(result.sector,result.total,`${m.id}: route was not completed`);
  }
});

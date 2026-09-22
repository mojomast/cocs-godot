import assert from 'node:assert/strict';
import {test} from 'node:test';
import {floorAt, obstructed, walkEdge, moveActor} from '../../game/core.mjs';
import {DESTINATION_COMBAT_MAPS} from '../../game/destination-combat-maps.mjs';
import {groundRouteGeometry,planRoute} from './route.mjs';

const map=DESTINATION_COMBAT_MAPS[0], geometry=groundRouteGeometry(map), goal=[-14,-19];
const failedRoute=[[10,24],[10,14],[8,-6],[6,-14],[0,-18],[-14,-19]];
const distance=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
const at=p=>({x:p[0],y:floorAt(...p,map),z:p[1]});

// Separate synthetic movement fixture: call the unchanged SOURCE collision /
// acceleration routine, not the planner's edge predicate. It receives ordinary
// walking input at 60Hz with 20Hz steering and a two-tick-old observed pose.
// This does not instantiate, relocate, or mutate any live server actor.
function walkRoute(start,route,speed=8.6,maxTicks=2400) {
  const actor={...at(start),vx:0,vy:0,vz:0,moveSpeed:speed,grounded:true,coyote:0,jumpBuffer:0};
  const observations=[start,start,start];
  let waypoint=0,input={},ticks=0;
  for(;ticks<maxTicks;ticks++) {
    if(ticks%3===0) {
      const pos=observations[0];
      if(distance(pos,route[waypoint])<.45 && waypoint<route.length-1)waypoint++;
      const target=route[waypoint],length=distance(pos,target);
      input=length>.35?{x:(target[0]-pos[0])/length,z:(target[1]-pos[1])/length,crouch:length<3}:{};
    }
    moveActor(actor,input,1/60,map);
    observations.push([actor.x,actor.z]);observations.shift();
    assert.ok(Number.isFinite(actor.x)&&Number.isFinite(actor.y)&&Number.isFinite(actor.z));
    if(Math.hypot(actor.x-goal[0],actor.y,actor.z-goal[1])<1.05)return {arrived:true,ticks,actor,waypoint};
  }
  return {arrived:false,ticks,actor,waypoint};
}

test('reported [8,34] route fails at the source causeway side, not box collision',()=>{
  assert.equal(floorAt(8,5.1,map),0);
  assert.equal(floorAt(8,4.9,map),.9);
  assert.equal(obstructed(8,0,4.9,.52,map),false);
  assert.equal(walkEdge(at([8,5.1]),at([8,4.9]),map),false);
  assert.equal(geometry.edge([10,14],[8,-6]),false);
  const result=walkRoute([8,34],failedRoute,8.6,1200);
  assert.equal(result.arrived,false);
  assert.equal(result.waypoint,2);
  assert.ok(Math.abs(result.actor.x-8)<.2 && result.actor.z>=5 && result.actor.z<5.2,JSON.stringify(result));
});

for(const start of map.spawns) test(`ground route from authored Meridian spawn ${start}`,()=>{
  const route=planRoute(map,{x:start[0],z:start[1]},goal,geometry);
  assert.deepEqual(route.at(-1),goal);
  assert.ok(route.length>0&&route.length<=128);
  let total=0;
  // Denser, independently sourced support/collision audit of returned segments.
  for(let index=0,previous=start;index<route.length;previous=route[index++]) {
    const next=route[index],length=distance(previous,next),samples=Math.ceil(length/.1);total+=length;
    let prior=at(previous);
    for(let i=0;i<=samples;i++) {
      const current=at([previous[0]+(next[0]-previous[0])*i/samples,previous[1]+(next[1]-previous[1])*i/samples]);
      assert.ok(current.y!==null&&Math.abs(current.y)<.01);
      assert.equal(obstructed(current.x,current.y,current.z,.72,map),false);
      assert.equal(walkEdge(prior,current,map),true);prior=current;
    }
  }
  assert.ok(total<150,'bounded approach distance');
  for(const speed of [6,8.6,10]) {
    const result=walkRoute(start,route,speed);
    assert.ok(result.arrived,JSON.stringify({start,speed,route,result}));
    assert.ok(result.ticks<2400,'pickup reached with source movement before route deadline');
  }
});

test('bounded planner rejects unsupported starts, holes, malformed coordinates and oversized arenas',()=>{
  assert.throws(()=>planRoute(map,{x:NaN,z:34}),/finite/);
  assert.throws(()=>planRoute(map,{x:8,z:0}),/supported/);
  assert.throws(()=>planRoute(map,{x:1000,z:0}),/supported/);
  assert.throws(()=>groundRouteGeometry({...map,bounds:{minX:-1000,maxX:1000,minZ:-1000,maxZ:1000}}),/budget/);
  const hole={bounds:{minX:-2,maxX:2,minZ:-2,maxZ:2},platforms:[{x:10,z:10,w:1,d:1,y:0}],blocks:[],pickups:[]};
  assert.equal(groundRouteGeometry(hole).clear([0,0]),false);
});

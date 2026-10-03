import test from 'node:test';
import assert from 'node:assert/strict';
import * as source from '../../game/core.mjs';
import * as campaign from './core.generated.mjs';

const arena={blocks:[],bounds:{minX:-10000,maxX:10000,minZ:-10000,maxZ:10000}};
const actor=extra=>({x:0,y:0,z:0,vx:8,vy:0,vz:0,grounded:true,health:100,vehicleId:null,moveSpeed:8,coyote:0,jumpBuffer:0,...extra});
const speed=a=>Math.hypot(a.vx,a.vz);
test('campaign-generated landing tap, incoming impulse and launcher preserve exact source movement',()=>{
 assert.deepEqual(campaign.MOVE,source.MOVE);
 for(const hz of [30,60,120])for(const scenario of ['tap','impulse','launcher']){
  const a=actor(scenario==='tap'?{y:.12,vy:-2,grounded:false}:scenario==='impulse'?{vx:24}:{}),b=structuredClone(a);
  const map=scenario==='launcher'?{...arena,traversal:{boostLaunchers:[{id:'launch',x:0,z:0,dir:[1,0],power:24,vy:12}]}}:arena;
  let slid=false,launched=false;
  for(let tick=0;tick<hz;tick++){
   const input=scenario==='tap'?(tick===0?{crouch:true,sprint:true}:{}):scenario==='impulse'?{jump:true,z:1}:{};
   source.moveActor(a,input,1/hz,map);campaign.moveActor(b,input,1/hz,map);
   assert.deepEqual(b,a,`${scenario} @ ${hz} Hz tick ${tick}`);
   slid ||= b.sliding;launched ||= b.traversalFlight;
   if(scenario==='impulse')assert.ok(speed(b)<=24+1e-9);
  }
  if(scenario==='tap')assert.equal(slid,true);
  if(scenario==='launcher')assert.equal(launched,true);
 }
});

test('generated authoritative Match matches source through 60 seconds of real-ground strafe hops',()=>{
 const rig=Module=>{
  const m=new Module.Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,humanCount:1,skipNav:true});
  m.arena=arena;m.pickups=[];Object.assign(m.actors[0],actor());return m;
 };
 const original=rig(source),generated=rig(campaign);let landings=0;
 for(let tick=0;tick<3600;tick++){
  const a=original.actors[0],s=speed(a),grounded=a.grounded;
  const input={x:-a.vz/s,z:a.vx/s,jump:true};
  original.step(1/60,{inputs:{0:input}});generated.step(1/60,{inputs:{0:input}});
  const b=generated.actors[0];
  const movement=p=>[p.x,p.y,p.z,p.vx,p.vy,p.vz,p.grounded,p.coyote,p.jumpBuffer,p.slideIntent,p.slideTap,p.movement];
  assert.deepEqual(movement(b),movement(a),`fixed-tick parity ${tick}`);
  assert.ok(speed(b)<=8*source.MOVE.terminal+1e-8);
  if(!grounded&&b.grounded)landings++;
 }
 assert.ok(landings>50);
});

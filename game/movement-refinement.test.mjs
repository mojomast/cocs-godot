import test from 'node:test';
import assert from 'node:assert/strict';
import {moveActor,MOVE,Match} from './core.mjs';
import {createOperatorVerbState,EFFORTLESS} from './operator-verbs.mjs';
import {InputBuffer} from '../port/native-arenas/input-buffer.mjs';
import {createVehicle} from './vehicles.mjs';

const arena={blocks:[],bounds:{minX:-10000,maxX:10000,minZ:-10000,maxZ:10000}};
const actor=(extra={})=>({x:0,y:0,z:0,vx:8,vy:0,vz:0,moveSpeed:8,grounded:true,coyote:0,jumpBuffer:0,...extra});
const speed=a=>Math.hypot(a.vx,a.vz);
const orthogonal=a=>({x:-a.vz/speed(a),z:a.vx/speed(a),jump:true});

test('real landing/takeoff strafe hops stay bounded for 60 seconds at supported timesteps',()=>{
 for(const dt of [1/30,1/60,1/120]){
  const a=actor();let landings=0;
  for(let i=0;i<60/dt;i++){
   const grounded=a.grounded;moveActor(a,orthogonal(a),dt,arena);
   if(!grounded&&a.grounded)landings++;
   assert.ok(speed(a)<=8*MOVE.terminal+1e-8,`dt=${dt}, tick=${i}, speed=${speed(a)}`);
  }
  assert.ok(landings>50,`real ground cadence: ${landings}`);
 }
});

test('incoming impulse survives takeoff and cannot gain speed from input',()=>{
 for(const grounded of [true,false]){
  const a=actor({vx:24,grounded,y:grounded?0:10});
  moveActor(a,orthogonal(a),1/60,arena);
  assert.ok(Math.abs(speed(a)-24)<1e-9);
 }
 const a=actor({vx:24});moveActor(a,{},1/60,arena);
 assert.ok(Math.abs(speed(a)-21.6)<1e-9,'ordinary ground friction still dissipates impulse');
});

test('stance, ADS, flag and buff budgets bound input while lower-budget transitions preserve incoming momentum',()=>{
 for(const [extra,input,multiplier] of [[{}, {},1],[{}, {sprint:true},MOVE.sprint],[{}, {crouch:true},MOVE.crouch],[{}, {ads:true},.9],[{carryingFlag:true},{},.9],[{speedMultiplier:1.3,gearSpeed:1.1},{},1.43]]){
  const a=actor({...extra,vx:0.1});
  for(let i=0;i<3600;i++){
   moveActor(a,{...orthogonal(a),...input},1/60,arena);
   assert.ok(speed(a)<=8*multiplier*MOVE.terminal+1e-8,JSON.stringify({extra,input,speed:speed(a)}));
  }
  a.vx=32;a.vz=0;a.grounded=true;a.y=0;
  moveActor(a,{z:1,jump:true,...input},1/60,arena);
  assert.ok(Math.abs(speed(a)-32)<1e-9,'stance change does not delete an impulse above its input budget');
 }
});

test('Effortless keeps its air-control and landing-slide advantages',()=>{
 const verbState=createOperatorVerbState('mistral');
 const a=actor({grounded:false,y:10,verbState}),b=actor({grounded:false,y:10});
 moveActor(a,{z:1},1/60,arena);moveActor(b,{z:1},1/60,arena);
 assert.ok(Math.abs(a.vz/b.vz-EFFORTLESS.airControl(verbState).airAccelMultiplier)<1e-9);
 assert.ok(a.vz>b.vz);
 const boosted=landTap({verbState}).a,normal=landTap().a;
 assert.ok(speed(boosted)>speed(normal));assert.ok(boosted.slideTimer>normal.slideTimer);
});

const landTap=(extra={},dt=1/60)=>{
 const a=actor({grounded:false,y:.12,vy:-2,...extra});
 moveActor(a,{crouch:true,sprint:true},dt,arena);
 let ticks=1;
 while(!a.grounded&&ticks<120){moveActor(a,{},dt,arena);ticks++;}
 moveActor(a,{},dt,arena);return {a,ticks};
};
test('late airborne sprint-crouch tap slides on first post-landing tick, then expires',()=>{
 for(const dt of [1/30,1/60,1/120,1/144]){
  const {a,ticks}=landTap({},dt);
  assert.ok(ticks*dt<.15);assert.equal(a.sliding,true);assert.equal(a.slideTap,true);
  assert.equal(a.crouching,true);assert.equal(a.eyeHeight,MOVE.eyeCrouch);
  assert.ok(speed(a)>8,'slide burst survives crouch budget');
  for(let t=0;t<.6;t+=dt)moveActor(a,{},dt,arena);
  assert.equal(a.sliding,false);assert.equal(a.slideTap,false);assert.equal(a.crouching,false);
 }
});
test('expired, slow, cooldown, traversal and crouch-owned verb landings do not consume a tap',()=>{
 for(const extra of [{y:2},{vx:5},{slideCooldown:1},{traversalFlight:true},{movement:{phase:'active',verb:'air-dash'}},{movement:{phase:'ready',verb:'super-jump'}},{movement:{phase:'ready',verb:'brace-slam'}}]){
  const {a}=landTap(extra);assert.equal(a.sliding,false,JSON.stringify(extra));assert.equal(a.slideIntent,0);
 }
 const a=actor({grounded:false,y:20});
 moveActor(a,{crouch:true,sprint:true},1/60,arena);
 assert.ok(Math.abs(a.slideIntent-.15)<1e-9);
 for(let i=1;i<=3;i++){
  moveActor(a,{crouch:true,sprint:true},1/60,arena);
  assert.equal(a.grounded,false);
  assert.ok(Math.abs(a.slideIntent-(.15-i/60))<1e-9,'held crouch decays without a new press edge');
 }
 for(let i=0;i<30;i++)moveActor(a,{crouch:true,sprint:true},1/60,arena);
 assert.equal(a.slideIntent,0,'holding crouch never refreshes the intent timer');
});
test('buffered slide can hop immediately, and held-crouch slides keep their release semantics',()=>{
 const {a}=landTap();moveActor(a,{jump:true},1/60,arena);
 assert.equal(a.sliding,false);assert.ok(a.vy>0);
 const b=actor();moveActor(b,{crouch:true,sprint:true},1/60,arena);
 assert.equal(b.sliding,true);moveActor(b,{},1/60,arena);assert.equal(b.sliding,false);
});
test('teleport, death, fall, spawn and vehicle transitions clear pending tap intent',()=>{
 const a=actor({vehicleId:null,slideIntent:.1,slideCrouchHeld:true,sliding:true,slideTap:true,slideTimer:.3});
 const control=structuredClone(a);moveActor(control,{},1/60,arena);
 assert.equal(control.sliding,true);assert.equal(control.slideTap,true,'ordinary grounded tick retains committed tap slide');
 moveActor(a,{},1/60,{...arena,traversal:{teleporters:[{x:0,z:0,to:{x:10,y:0,z:0}}]}});
 assert.equal(a.traversalEvent.type,'teleport');assert.equal(a.x,10);
 assert.equal(a.sliding,false);assert.equal(a.slideTap,false,'teleport specifically clears the committed slide');
 assert.equal(a.slideIntent,0);assert.equal(a.slideCrouchHeld,false);
 const match=new Match('chatgpt','openclaw',()=>.5,'exchange',{botCount:0,humanCount:1});
 const p=match.actors[0];
 const prime=()=>Object.assign(p,{slideIntent:.15,slideTap:true,slideCrouchHeld:true});
 const cleared=()=>{assert.equal(p.slideIntent,0);assert.equal(p.slideTap,false);assert.equal(p.slideCrouchHeld,false);};
 prime();match.spawn(p);cleared();
 prime();p.protection=0;match.damage(p,10000,null);cleared();
 match.spawn(p);prime();match.fall(p);cleared();
 match.spawn(p);prime();match.releaseVehicle(p,null);cleared();
 const vehicle=createVehicle();vehicle.id=99;match.vehicles=[vehicle];
 Object.assign(p,vehicle.position);prime();assert.equal(match.enterVehicle(p),true);cleared();
});
test('fixed-tick authoritative replay is deterministic through movement transitions',()=>{
 const replay=()=>{
  let seed=13;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
  const m=new Match('mistral','openclaw',random,'exchange',{botCount:0,humanCount:1});
  m.arena=arena;m.pickups=[];Object.assign(m.actors[0],actor(),{health:100});
  const trace=[];
  for(let tick=0;tick<600;tick++){
   m.step(1/60,{inputs:{0:{x:Math.sin(tick*.03),z:Math.cos(tick*.03),jump:tick%70<3,sprint:tick%100<60,crouch:tick%70===35}}});
   const a=m.actors[0];trace.push([a.x,a.y,a.z,a.vx,a.vy,a.vz,a.sliding,a.slideIntent,a.movement.phase]);
  }return trace;
 };
 assert.deepEqual(replay(),replay());
});

test('native-shaped FIFO samples reach authoritative landing-slide and consume one-shots once',()=>{
 const m=new Match('chatgpt','openclaw',()=>.5,'exchange',{botCount:0,humanCount:1});
 m.arena=arena;m.pickups=[];const a=m.actors[0];
 Object.assign(a,actor({y:.12,vy:-2,vx:8,grounded:false}),{health:100});
 const buffer=new InputBuffer();
 const step=()=>{const sample=buffer.take();m.step(1/60,{inputs:{0:sample.input}});buffer.stepped(sample.seq);};
 buffer.receive(1,{x:0,z:0,yaw:0,pitch:0,crouch:true,sprint:true,jump:false,mobility:false,fire:false,ads:false,reload:true},0);
 step();buffer.receive(2,{x:0,z:0,yaw:0,pitch:0,crouch:false,sprint:false},1000/60);
 for(let i=0;i<3;i++)step();
 assert.equal(a.sliding,true);assert.equal(a.slideTap,true);
 assert.equal(buffer.status().appliedSeq,2);assert.equal(buffer.take().input.reload,undefined);
});

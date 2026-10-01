import test from 'node:test';
import assert from 'node:assert/strict';
import {readBlackwater} from './blackwater-schema.mjs';
import {BlackwaterDirector,BLACKWATER_STATIONS} from './blackwater-director.mjs';
import {validateHordeStagePlan} from '../../game/horde-stages.mjs';
import {Match,floorAt,obstructed,walkEdge,nearest} from '../../game/core.mjs';
import {updateSinglePlayer} from '../../game/singleplayer.mjs';

const realMatch=()=>{
 const a=readBlackwater().arena;
 return new Match('chatgpt','openclaw',()=>.5,a.id,
  {mode:'horde',botCount:0,difficulty:'easy',fragLimit:10,timeLimit:900,humanCount:1,hordeArena:a});
};

test('authored Blackwater extent, stage gates, distinct districts and hash',()=>{
 const d=readBlackwater(),a=d.arena;
 assert.equal(a.bounds.maxX-a.bounds.minX,440);
 assert.equal(a.bounds.maxZ-a.bounds.minZ,380);
 assert.equal(a.hordeStagePlan.transitions.length,2);
 assert.equal(a.terrain.surfaces.filter(s=>s.id.startsWith('gantry-ramp')).length,10);
 assert.equal(new Set(a.blocks.map(b=>b.id)).size,a.blocks.length);
 assert(BLACKWATER_STATIONS.every(s=>s.x>a.bounds.minX&&s.x<a.bounds.maxX&&s.z>a.bounds.minZ&&s.z<a.bounds.maxZ));
 assert.equal(validateHordeStagePlan(a.hordeStagePlan,a).stages.length,3);
 for(const station of BLACKWATER_STATIONS){
  const y=floorAt(station.x,station.z,a);
  assert.notEqual(y,null,station.id+' has a real floor');
  assert.equal(obstructed(station.x,y,station.z,1.2,a),false,station.id+' is reachable space');
 }
});

test('server position and input arm objective; progress and reward survive snapshots',()=>{
 const events=[];
 const player={x:-170,z:78,grounded:true,health:100};
 const match={over:false,actors:[player],modeState:{kind:'horde',wave:1},pickups:[{id:9,x:-169,z:79,wait:150}],emit:(kind,row)=>events.push({kind,...row})};
 const director=new BlackwaterDirector();
 director.step(match,{},1);
 assert.equal(director.progress['north-feeder'],0);
 director.step(match,{interact:true},1);
 for(let i=0;i<4;i++)director.step(match,{},1);
 assert.deepEqual(director.snapshot(match).completed,['north-feeder']);
 assert.equal(match.pickups[0].wait,0);
 assert.equal(events.filter(e=>e.kind==='blackwater-station-restored').length,1);
 for(let i=0;i<10;i++)director.step(match,{interact:true},1);
 assert.equal(events.filter(e=>e.kind==='blackwater-station-restored').length,1);
});

test('distance, death, stage availability and restart do not leak objective progress',()=>{
 const player={x:170,z:-82,grounded:true,health:100};
 const match={over:false,actors:[player],modeState:{kind:'horde',wave:7},pickups:[],emit:()=>{}};
 const director=new BlackwaterDirector();
 director.step(match,{interact:true},20);
 assert.equal(director.progress['relief-valve'],0,'cannot skip feeder/pump dependency');
 player.x=-170;player.z=78;
 director.step(match,{interact:true},1);
 player.health=0;
 director.step(match,{},10);
 assert.equal(director.active,null);
 assert.equal(director.progress['north-feeder'],1);
 assert.deepEqual(new BlackwaterDirector().snapshot(match).completed,[]);
});

test('ordered feeder/repair/valve chain executes actual source resupply only after hold',()=>{
 const events=[];
 const player={x:0,z:0,grounded:true,health:25,maxHealth:100,armor:0,ammo:[12],weapon:0};
 const match={over:false,actors:[player],modeState:{kind:'horde',wave:1,upgrades:[]},pickups:[],
  emit:(kind,row)=>events.push({kind,...row})};
 const director=new BlackwaterDirector();
 for(const station of BLACKWATER_STATIONS){
  match.modeState.wave=station.wave;
  player.x=station.x;player.z=station.z;
  director.step(match,{interact:true},1);
  for(let i=1;i<station.seconds;i++)director.step(match,{},1);
  assert(director.done.includes(station.id),station.id);
 }
 assert.equal(events.filter(e=>e.kind==='horde-resupply').length,2);
 assert.equal(player.health,100);
 assert.equal(player.armor,100);
 assert.equal(events.filter(e=>e.kind==='blackwater-station-restored').length,4);
});

test('real source physics graph links every district, station and stage with each floodgate mask',()=>{
 const m=realMatch();
 for(const mask of [0,1,3]){
  m.applyHordeGateMask(mask);
  assert(m.nav.length>3000,'district graph should not be pruned to a pocket');
  for(const stage of m.arena.hordeStagePlan.stages)assert(m.hordeStageReachable(stage),`stage ${stage.id} reachable under mask ${mask}`);
  for(const station of BLACKWATER_STATIONS){
   const y=floorAt(station.x,station.z,m.arena),p={x:station.x,y,z:station.z};
   const node=m.nav[nearest(p,m.nav)];
   assert(walkEdge(p,node,m.arena),`${station.id} has a source walk edge at mask ${mask}`);
  }
 }
});

test('source wave-clear and timed Blackwater gate opening change actual ray/collision mask',()=>{
 const m=realMatch(),gate=m.arena.hordeStagePlan.gates[0];
 assert(obstructed(gate.x,0,gate.z,.5,m.arena));
 m.modeState.wave=3;m.modeState.phase='wave';m.modeState.enemies=[];
 updateSinglePlayer(m,1/60);
 assert.equal(m.modeState.stage.transit.to,'B');
 for(let n=0;n<180;n++)updateSinglePlayer(m,1/60);
 assert.equal(m.modeState.stage.gateMask&1,1);
 assert(!obstructed(gate.x,0,gate.z,.5,m.arena));
 assert(m.hordeStageReachable(m.arena.hordeStagePlan.stages[1]));
});

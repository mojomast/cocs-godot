import test from 'node:test';
import assert from 'node:assert/strict';
import {readBlackwater} from './blackwater-schema.mjs';
import {BlackwaterDirector,BLACKWATER_STATIONS} from './blackwater-director.mjs';
import {validateHordeStagePlan} from '../../game/horde-stages.mjs';
import {floorAt,obstructed} from '../../game/core.mjs';

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

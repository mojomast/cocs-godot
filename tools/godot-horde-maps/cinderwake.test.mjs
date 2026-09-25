import test from 'node:test';
import assert from 'node:assert/strict';
import {cinderwake,hash} from './cinderwake.mjs';
import {validateCinderwake} from '../../port/native-horde/cinderwake-schema.mjs';
import {floorAt,obstructed,navigation,rayWorld,moveActor,Match} from '../../game/core.mjs';
import {path} from '../../game/bots.mjs';

const data=cinderwake();
const world=mask=>({...data.arena,blocks:[...data.arena.blocks,...data.arena.hordeStagePlan.gates.filter((g,i)=>!(mask&(1<<i)))]});
test('new deterministic union recipe, exact schedule, pickup support and meaningful negative cases',()=>{
 assert.deepEqual(cinderwake(),data);assert.equal(validateCinderwake(data),data);
 assert.equal(data.geometryHash,hash(data.arena));
 assert.deepEqual(data.arena.hordeStagePlan.transitions.map(t=>t.afterWave),[2,5,10,13,15,20,22,24]);
 for(const change of [d=>d.mode='deathmatch',d=>d.arena.blocks[0].w=0,d=>d.arena.terrain.surfaces[0].triangles[0][0]=999,d=>d.arena.blocks[1].id=d.arena.blocks[0].id,d=>d.arena.pickups[0][0]='invented',d=>d.arena.hordeStagePlan.transitions[0].open=['missing'],d=>d.arena.hordeStagePlan.transitions[1].afterWave=2,d=>d.arena.hordeStagePlan.stages[1].arrival.maxZ=-100,d=>d.planHash='0'.repeat(64),d=>d.arena.blocks[0].x+=1,d=>d.arena.navNodes=Array(10001).fill([0,0]),d=>d.arena.hordeStagePlan.transitions[0].teleport=true]){const bad=structuredClone(data);change(bad);assert.throws(()=>validateCinderwake(bad));}
});
test('all four gate masks connect every stage spawn pool and arrival to E',()=>{
 for(let mask=0;mask<4;mask++){
  const arena=world(mask),graph=navigation(arena),seen=new Set([0]),queue=[0];
  for(let i=0;i<queue.length;i++)for(const j of graph.edges[queue[i]])if(!seen.has(j)){seen.add(j);queue.push(j);}
  assert.equal(seen.size,graph.nodes.length,`mask ${mask}: connected graph`);
  const anchors=data.arena.hordeStagePlan.stages.flatMap(s=>[...s.humanSpawns,...s.enemySpawns,[(s.arrival.minX+s.arrival.maxX)/2,(s.arrival.minZ+s.arrival.maxZ)/2]]).concat([[-37,56],[-37,46],[-37,6],[-37,-36]]);
  for(const [x,z] of anchors){assert.equal(floorAt(x,z,arena),0);assert(!obstructed(x,0,z,1.2,arena),`${mask}: anchor ${x},${z}`);assert(graph.nodes.some(n=>Math.hypot(n.x-x,n.z-z)<2.1),`${mask}: nav anchor ${x},${z}`);}
  for(const stage of data.arena.hordeStagePlan.stages)for(const [x,z] of stage.enemySpawns)for(const destination of data.arena.hordeStagePlan.stages){const r=destination.arrival,target={x:(r.minX+r.maxX)/2,y:0,z:(r.minZ+r.maxZ)/2};const route=path({x,y:0,z},target,graph.nodes,graph.edges);assert(route.length,`source A* mask ${mask} ${stage.id} to ${destination.id}`);if(mask===0&&stage.id!==destination.id)assert(route.some(i=>graph.nodes[i].x<=-34),'closed direct gates route through E');}
 }
});
test('source capsule clearance along both directions of each route, supported seams and gate rays',()=>{
 for(const route of data.routes)for(const points of [route.points,[...route.points].reverse()]){
  const arena=world(['B-C','C-D','D-B'].includes(route.id)?3:0);let length=0;
  for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],distance=Math.hypot(b.x-a.x,b.z-a.z);length+=distance;for(let n=0;n<=Math.ceil(distance/.2);n++){const t=n/Math.ceil(distance/.2),x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t;assert.equal(floorAt(x,z,arena),0,`${route.id} floor ${x},${z}`);assert(!obstructed(x,0,z,1.2,arena),`${route.id} capsule ${x},${z}`);}}
  assert(length>0);
 }
 for(let mask=0;mask<4;mask++)for(const [i,g] of data.arena.hordeStagePlan.gates.entries()){
  const arena=world(mask),distance=rayWorld({x:g.x,y:2,z:g.z+3},{x:0,y:0,z:-1},6,arena);
  assert.equal(distance<6,!(mask&(1<<i)),`ray mask ${mask} gate ${g.id}`);
  assert.equal(obstructed(g.x,0,g.z,1.2,arena),!(mask&(1<<i)));
 }
 for(const block of data.arena.blocks.filter(b=>!b.id.includes('hull')&&!b.id.includes('shell'))){const hit=rayWorld({x:block.x,y:Math.min(1,block.h/2),z:block.z+block.d/2+1},{x:0,y:0,z:-1},2,world(3));assert(hit<=1.001,block.id);}
});
test('normal-speed source moveActor physically walks all authored routes in both directions',()=>{
 const baseline=new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'horde',botCount:0,skipNav:true});
 for(const route of data.routes)for(const points of [route.points,[...route.points].reverse()]){
  const arena=world(['B-C','C-D','D-B'].includes(route.id)?3:0),a=structuredClone(baseline.actors[0]);
  Object.assign(a,points[0],{vx:0,vy:0,vz:0,grounded:true});
  for(const target of points.slice(1)){
   let steps=0;
   while(Math.hypot(target.x-a.x,target.z-a.z)>.2&&steps++<1800){moveActor(a,{x:target.x-a.x,z:target.z-a.z,jump:false,sprint:false},1/60,arena,{speed:1,gravity:1});}
   assert(steps<1800,`${route.id}: stalled at ${a.x},${a.z}; target ${target.x},${target.z}`);assert(Math.abs(a.y)<.15);
  }
 }
});

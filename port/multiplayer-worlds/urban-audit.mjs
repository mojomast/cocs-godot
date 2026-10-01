#!/usr/bin/env node
// Static terrain/LOS/travel audit on exactly the arenas the source Match uses.
import assert from 'node:assert/strict';
import {readWorld} from './catalog.mjs';
import {worldMatchClass} from './match.mjs';
import {floorAt,obstructed,rayWorld} from '../../game/core.mjs';
const reach=(m,origin)=>{const seen=new Set([origin]),q=[origin];for(let n=0;n<q.length;n++)for(const j of m.edges[q[n]]??[])if(!seen.has(j)){seen.add(j);q.push(j);}return seen;};
const closest=(nodes,x,z,y)=>nodes.map((p,i)=>[i,Math.hypot(p.x-x,p.z-z,(p.y-y)*2)]).sort((a,b)=>a[1]-b[1])[0];
const records=[];
for(const id of ['switchyard-ward','rainmarket-exchange']){
 const data=readWorld(id),a=data.arena,m=new (worldMatchClass(id,'deathmatch'))('chatgpt','openclaw',()=>.5,id,{mode:'deathmatch',botCount:0,timeLimit:60,fragLimit:5,humanCount:2});
 const origin=closest(m.nav,...a.teamSpawns[0][0],floorAt(...a.teamSpawns[0][0],a))[0],connected=reach(m,origin);
 let unsupported=[],blocked=[],unreachable=[];
 const points=[...a.spawns,...a.pickups.map(p=>p.slice(1)),...a.objectiveZones.map(z=>[z.x,z.z]),...Object.values(a.flagSpawns).map(p=>[p.x,p.z])];
 for(const [x,z] of points){const y=floorAt(x,z,a);if(y===null){unsupported.push([x,z]);continue;}if(obstructed(x,y,z,.65,a))blocked.push([x,z,y]);const [nearest,distance]=closest(m.nav,x,z,y);if(!connected.has(nearest)||distance>5.5)unreachable.push([x,z,y,distance]);}
 // Elevated surface has to be traversable from a genuine source spawn, not
 // merely visually attached to ground. Each roof is a separate audit point.
 const roofs=a.terrain.surfaces.filter(s=>s.walkable!==false&&(s.id.includes('roof')||s.id.includes('overlook')));
 for(const surface of roofs){const vertices=surface.vertices,x=vertices.reduce((n,p)=>n+p[0],0)/vertices.length,z=vertices.reduce((n,p)=>n+p[2],0)/vertices.length,y=floorAt(x,z,a),[nearest,distance]=closest(m.nav,x,z,y);if(!connected.has(nearest)||distance>5)unreachable.push([surface.id,x,z,y,distance]);}
 assert.deepEqual({unsupported,blocked,unreachable},{unsupported:[],blocked:[],unreachable:[]},`${id}: support/nav/clearance`);
 const spawns=a.teamSpawns[0].map(([x,z])=>({x,z,y:floorAt(x,z,a)})),opposites=a.teamSpawns[1].map(([x,z])=>({x,z,y:floorAt(x,z,a)}));
 const minEnemy=Math.min(...spawns.flatMap(p=>opposites.map(q=>Math.hypot(p.x-q.x,p.z-q.z))));
 assert.ok(minEnemy>=15,`${id}: team spawn separation ${minEnemy}`);
 const supportedNodes=m.nav.filter(n=>n.y>1),groundNodes=m.nav.filter(n=>n.y<.5);
 assert.ok(supportedNodes.length>=10&&groundNodes.length>=150,`${id}: insufficient multilevel source navigation`);
 assert.equal(a.overhead?.length,4,`${id}: every enclosed shop needs one physical roof slab`);
 for(const roof of a.overhead){
  const shop=roof.id.replace(/-ceiling$/,''),top=a.terrain.surfaces.find(s=>s.id===`${shop}-roof-top`),under=a.terrain.surfaces.find(s=>s.id===`${shop}-ceiling-underside`);
  const doorway=a.blocks.filter(b=>b.id.startsWith(shop+'-entry-'));
  assert.equal(doorway.length,2,`${roof.id}: shop must retain two doorway jambs`);
  for(const offset of [-1,0,1]){
   const x=doorway[0].id.endsWith('-l')?roof.x:doorway[0].x+offset;
   const z=doorway[0].id.endsWith('-l')?doorway[0].z+offset:roof.z;
   const y=floorAt(x,z,a);
   assert.ok(y!==null&&!obstructed(x,y,z,.4,a),`${roof.id}: standing-height door approach blocked at ${x},${z}`);
  }
  assert.equal(top?.walkable,false,`${roof.id}: inaccessible shop roof accidentally walkable`);
  assert.equal(under?.walkable,false,`${roof.id}: ceiling is not a floor`);
  assert.equal(floorAt(roof.x,roof.z,a),0,`${roof.id}: ground floor superseded by nonwalkable roof`);
  assert.equal(obstructed(roof.x,0,roof.z,.65,a),false,`${roof.id}: interior sealed at actor height`);
  assert.ok(Math.abs(rayWorld({x:roof.x,y:1,z:roof.z},{x:0,y:1,z:0},8,a)-(roof.minY-1))<.02,`${roof.id}: missing underside collision`);
  assert.ok(Math.abs(rayWorld({x:roof.x,y:7,z:roof.z},{x:0,y:-1,z:0},8,a)-(7-roof.maxY))<.02,`${roof.id}: missing topside collision`);
  assert.equal(a.terrain.walls.filter(w=>w.id?.startsWith(shop+'-roof-')).length,4,`${roof.id}: missing slab side`);
  for(const [dx,dz,expected] of [[1,0,roof.w/2],[-1,0,roof.w/2],[0,1,roof.d/2],[0,-1,roof.d/2]])
   assert.ok(Math.abs(rayWorld({x:roof.x,y:(roof.minY+roof.maxY)/2,z:roof.z},{x:dx,y:0,z:dz},20,a)-expected)<.02,`${roof.id}: missing collision along roof side ${dx},${dz}`);
 }
 records.push({id,geometryHash:data.geometryHash,sourceNavNodes:m.nav.length,connected:connected.size,roofNodes:supportedNodes.length,groundNodes:groundNodes.length,minimumOpposingSpawnDistance:minEnemy,roofCount:roofs.length,enclosedShops:a.overhead.length,objectiveCount:a.objectiveZones.length});
}
console.log(JSON.stringify(records,null,2));

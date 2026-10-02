import test from 'node:test';
import assert from 'node:assert/strict';
import {recipe as m,makeRecipe,hash} from './candidate.mjs';
import {floorAt,walkEdge,obstructed,navigation,moveActor,rayWorld} from '../../../../game/core.mjs';
import {terrainSupportAt,terrainTriangles} from '../../../../game/terrain.mjs';
import {validateMapSchema} from '../../../../game/map-schema.mjs';
test('deterministic schema and exact visual/collision correspondence',()=>{
 assert.equal(hash(makeRecipe()),hash(m));assert.deepEqual(validateMapSchema(m),[]);
 assert.equal(terrainTriangles(m.terrain).length,m.terrain.surfaces.reduce((n,s)=>n+s.triangles.length,0),'construction support sampling must not leave an incomplete runtime triangle cache');
 for(const s of m.terrain.surfaces){const visual=m.art.meshes.find(v=>v.id===s.id);assert.deepEqual(s.vertices,visual.vertices);assert.deepEqual(s.triangles,visual.triangles);}
 assert.ok(m.terrain.surfaces.filter(s=>s.walkable).length>600);
 for(const s of m.terrain.surfaces.filter(s=>s.id.includes('vault')||s.id.includes('aqueduct')))assert.equal(s.walkable,false);
});
test('all source route edges and sockets clear; continuous 0/8/16/24m support',()=>{
 for(const r of m.routes)for(let i=1;i<r.points.length;i++){
  const a=r.points[i-1],b=r.points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1]));let prev;
  for(let j=0;j<=n;j++){const x=a[0]+(b[0]-a[0])*j/n,z=a[1]+(b[1]-a[1])*j/n,y=floorAt(x,z,m),p={x,y,z};assert.notEqual(y,null,r.id);assert.ok(!obstructed(x,y,z,.52,m),`${r.id} obstructed ${x},${z}`);if(prev)assert.ok(walkEdge(prev,p,m),`${r.id} edge ${x},${z}`);prev=p;}
 }
 for(const [r,y]of [[12,0],[52,8],[86,16],[116,24]])assert.ok(Math.abs(terrainSupportAt(0,r,m.terrain,.8).y-y)<1e-6);
 for(const p of [...m.spawns,...m.pickups.map(p=>p.slice(1)),...m.objectiveZones.map(p=>[p.x,p.z])])assert.ok(!obstructed(p[0],floorAt(...p,m),p[1],.6,m));
});
test('real source moveActor follows every authored route without teleporting',()=>{
 let ticks=0;
 for(const r of m.routes){const [x,z]=r.points[0],a={x,z,y:floorAt(x,z,m),vx:0,vy:0,vz:0,grounded:true,health:100,moveSpeed:7};
  for(const target of r.points.slice(1)){let n=0;while(Math.hypot(target[0]-a.x,target[1]-a.z)>.35&&n++<600){moveActor(a,{x:target[0]-a.x,z:target[1]-a.z},1/60,m);ticks++;assert.ok(Number.isFinite(a.y));}assert.ok(n<600,`${r.id} stalled ${a.x},${a.z} toward ${target}`);}
 }console.log(`actual movement ticks=${ticks}`);
});
test('source shots pass open archive portal, block side wall, pass glass, and hit ceiling',()=>{
 assert.ok(rayWorld({x:52,y:10,z:-12},{x:0,y:0,z:1},24,m)>=24);
 if(m.art.revision!==2)assert.ok(rayWorld({x:52,y:10,z:0},{x:1,y:0,z:0},10,m)<5);
 if(m.art.revision===2)assert.ok(rayWorld({x:52,y:12,z:0},{x:1,y:0,z:0},10,m)>=10,'glazed lab facade has no invisible shot blocker');
 else assert.ok(rayWorld({x:6,y:3,z:4},{x:0,y:0,z:1},4,m)>=4);
 assert.ok(rayWorld({x:52,y:10,z:0},{x:0,y:1,z:0},15,m)<(m.art.revision===2?12:6));
 assert.equal(floorAt(52,0,m),8);assert.equal(floorAt(0,16,m),0);
});
test('source bot graph connects every spawn, flag, zone and pickup',()=>{
 const graph=navigation(m),nearest=([x,z])=>{let best=-1,d=Infinity;graph.nodes.forEach((p,i)=>{const n=Math.hypot(x-p.x,z-p.z);if(n<d){d=n;best=i;}});assert.ok(d<3);return best;};
 const sockets=[...m.spawns,...Object.values(m.flagSpawns).map(p=>[p.x,p.z]),...m.objectiveZones.map(p=>[p.x,p.z]),...m.pickups.map(p=>p.slice(1))];
 for(const spawn of m.spawns){const start=nearest(spawn),seen=new Set([start]),q=[start];for(const i of q)for(const j of graph.edges[i])if(!seen.has(j)){seen.add(j);q.push(j);}for(const p of sockets)assert.ok(seen.has(nearest(p)),`${spawn} -> ${p}`);}
 console.log(`source graph nodes=${graph.nodes.length} directedEdges=${graph.edges.reduce((n,e)=>n+e.length,0)}`);
});

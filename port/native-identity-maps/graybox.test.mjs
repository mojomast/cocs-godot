import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createIdentityMatch,loadRecipe,CATALOG} from './match.mjs';
import {floorAt,obstructed,navigation,moveActor,visible,nearest,walkEdge} from '../../game/core.mjs';
import {terrainWallSegments,terrainWallTriangles,terrainTriangles} from '../../game/terrain.mjs';
let checks=0;const check=(v,m)=>{checks++;assert.ok(v,m);};
// Cold-construction gate for the collision simplification. Target 1500 ms,
// hard ceiling 3000 ms; the prototype's exact-triangle walls measured
// 6059 / 2950 / 14828 ms on this host (port/native-identity-maps/PERFORMANCE.md),
// so these are the numbers a regression must not walk back to.
const COLD_TARGET_MS=1500,COLD_CEILING_MS=3000,WALL_SEGMENT_BUDGET=2000;
const PROTOTYPE_COLD_MS={'lacuna-court':6059.348,'vermilion-fold':2950.349,'nacre-engine':14827.741};
const result={scope:'Deterministic graybox source-function fixtures, NOT normal-rate live gameplay or GPU performance',maps:[],failures:[]};
function walk(arena,points){
 const a={x:points[0].x,y:floorAt(points[0].x,points[0].z,arena),z:points[0].z,vx:0,vy:0,vz:0,grounded:true,character:'chatgpt',harness:'openclaw',yaw:0};
 let frames=0,minY=a.y,maxY=a.y;
 for(const target of points.slice(1)){
  let reached=false;
  for(let i=0;i<1200;i++){
   const dx=target.x-a.x,dz=target.z-a.z,d=Math.hypot(dx,dz);
   if(d<.32){reached=true;break;}
   moveActor(a,{x:dx/d,z:dz/d},1/60,arena);frames++;
   const f=floorAt(a.x,a.z,arena);check(f!==null,'walk floor');check(Math.abs(a.y-f)<.31,'walk support');
   check(!obstructed(a.x,a.y,a.z,undefined,arena),'walk no penetration');minY=Math.min(minY,a.y);maxY=Math.max(maxY,a.y);
  }
  check(reached,`Route stalled to ${JSON.stringify(target)} from ${JSON.stringify({x:a.x,y:a.y,z:a.z})}`);
 }
 return {seconds:frames/60,minY,maxY};
}
for(const id of Object.keys(CATALOG)){
 try{
 const r=loadRecipe(id),a=r.arena,t=performance.now(),m=createIdentityMatch(id),constructionMs=performance.now()-t;
 check(m.actors.length===(id==='nacre-engine'?1:id==='vermilion-fold'?6:4),'actor counts');
 const segments=terrainWallSegments(a.terrain);
 check(segments.length<=WALL_SEGMENT_BUDGET,`${id} wall segment budget ${segments.length}`);
 check(terrainWallTriangles(a.terrain).length+terrainTriangles(a.terrain).length>0,`${id} collision triangles exist`);
 check(constructionMs<COLD_CEILING_MS,`${id} cold construction ${constructionMs.toFixed(1)} ms exceeds ${COLD_CEILING_MS} ms ceiling`);
 if(constructionMs>=COLD_TARGET_MS)result.failures.push({id,kind:'cold-target',constructionMs,note:`target ${COLD_TARGET_MS} ms (soft)`});
 check(constructionMs*10<PROTOTYPE_COLD_MS[id],`${id} cold construction is not an order of magnitude better than the prototype baseline`);
 for(const [x,z] of [...a.spawns,...a.pickups.map(p=>p.slice(1))]){
  const y=floorAt(x,z,a);check(y!==null,'spawn/pickup floor');check(!obstructed(x,y,z,.65,a),'spawn/pickup clearance');
  if(id==='nacre-engine')check(!obstructed(x,y,z,1.2,a),'conservative visual boss clearance');
 }
 const nav=navigation(a),seen=new Set([0]),q=[0];for(let i=0;i<q.length;i++)for(const v of nav.edges[q[i]])if(!seen.has(v)){seen.add(v);q.push(v);}
 check(seen.size===nav.nodes.length,`Disconnected nav ${seen.size}/${nav.nodes.length}`);
 const routes=r.routes.map(route=>({id:route.id,forward:walk(a,route.points),reverse:walk(a,[...route.points].reverse())}));
 let spawnSightlines=[];
 if(id==='lacuna-court')for(let i=0;i<a.spawns.length;i++)for(let j=i+1;j<a.spawns.length;j++){
  const [x,z]=a.spawns[i],[xx,zz]=a.spawns[j];const sight=visible({x,y:1.6,z},{x:xx,y:1.6,z:zz},a);spawnSightlines.push({i,j,sight});check(!sight,'spawn-to-spawn visibility');
 }
 if(id==='vermilion-fold'){
  check(m.objectiveState.zones.length===3,'three source zones');
  m.objectiveState.zones.forEach((z,i)=>check(Math.hypot(z.x-a.objectiveZones[i].x,z.z-a.objectiveZones[i].z)<.001,'no zone snapping'));
 }
 result.maps.push({id,geometryHash:r.geometryHash,constructionMs,prototypeColdMs:PROTOTYPE_COLD_MS[id],speedup:+(PROTOTYPE_COLD_MS[id]/constructionMs).toFixed(1),wallSegments:segments.length,wallEntries:a.terrain.walls.length,blocks:a.blocks.length,artTriangles:r.art.reduce((s,x)=>s+x.triangles.length,0),navNodes:nav.nodes.length,navEdges:nav.edges.reduce((s,e)=>s+e.length,0),routes,spawnSightlines});
 }catch(e){result.failures.push({id,error:e.stack});}
}
assert.throws(()=>loadRecipe('../x'));checks++;
assert.throws(()=>createIdentityMatch('nacre-engine',{botCount:1}));checks++;
assert.throws(()=>createIdentityMatch('lacuna-court',{mode:'horde'}));checks++;
result.checks=checks;result.passed=result.failures.length===0;
const out=new URL('./evidence/',import.meta.url);mkdirSync(out,{recursive:true});const name=`graybox-${Date.now()}.json`;writeFileSync(new URL(name,out),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));process.exitCode=result.passed?0:1;

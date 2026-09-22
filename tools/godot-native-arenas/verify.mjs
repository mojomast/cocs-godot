import fs from 'node:fs';
import assert from 'node:assert/strict';
import {floorAt,obstructed,rayWorld,walkEdge,navigation} from '../../game/core.mjs';
import {readNativeArena} from '../../port/native-arenas/schema.mjs';

const reports=JSON.parse(fs.readFileSync('/tmp/opencode/native-dm-physics.json','utf8'));
const results=[];
for(const report of reports){
  const data=readNativeArena(report.id),a=data.arena,errors=[];
  const check=(ok,message)=>{if(!ok)errors.push(message);};
  check(data.geometryHash===report.geometryHash,'Physics probe has stale geometry hash');
  for(const [index,p] of data.spawnPoints.entries()){
    check(Math.abs(floorAt(p.x,p.z,a)-p.y)<.002,`spawn ${index} support`);
    check(!obstructed(p.x,p.y,p.z,.65,a),`spawn ${index} clearance`);
  }
  for(const route of data.routes){
    for(const [i,p] of route.points.entries())check(!obstructed(p.x,p.y,p.z,.65,a),`${route.id} clearance ${i}`);
    for(let i=1;i<route.points.length;i++)check(walkEdge(route.points[i-1],route.points[i],a),`${route.id} walk edge ${i}`);
  }
  let floors=0,rays=0;
  const compareRay=(ray,label)=>{
    const [x,y,z]=ray.origin,[dx,dy,dz]=ray.direction;
    const actual=rayWorld({x,y,z},{x:dx,y:dy,z:dz},20,a);
    const native=ray.hit?Math.hypot(...ray.hit.map((v,i)=>v-ray.origin[i])):20;
    check(Math.abs(actual-native)<.035,`${label} source=${actual.toFixed(4)} native=${native.toFixed(4)}`);rays++;
  };
  for(const [i,sample] of report.samples.entries()){
    const [x,y,z]=sample.point,source=floorAt(x,z,a);
    check(source!==null&&sample.floor!==null&&Math.abs(source-sample.floor[1])<.035,`floor ${i} at ${x},${z}: source=${source} native=${sample.floor?.[1]}`);floors++;
    for(const [j,ray] of sample.rays.entries())compareRay(ray,`ray ${i}:${j}`);
    const ceiling=sample.rays.find(ray=>ray.direction[1]===1);
    check(!ceiling.hit||ceiling.hit[1]-y>=1.8-.035,`headroom ${i} below standing actor height`);
  }
  check(report.sealedVolume.hit!==null,'sealed underdeck/buttress/bore is visibly solid in native physics');
  compareRay(report.sealedVolume,'sealed volume');
  const hit=report.sealedVolume.hit,dir=report.sealedVolume.direction;
  if(hit){const x=hit[0]-dir[0]*.2,z=hit[2]-dir[2]*.2,y=report.sealedVolume.origin[1]-.9;check(obstructed(x,y,z,.52,a),'sealed volume source movement wall');}
  const graph=navigation(a),seen=new Set([0]),queue=[0];
  for(let i=0;i<queue.length;i++)for(const next of graph.edges[queue[i]])if(!seen.has(next)){seen.add(next);queue.push(next);}
  check(seen.size===graph.nodes.length,`navigation connected ${seen.size}/${graph.nodes.length}`);
  for(const [x,z] of [...a.navNodes,...a.spawns,...a.pickups.map(p=>p.slice(1))])check(graph.nodes.some(n=>Math.hypot(n.x-x,n.z-z)<.101),`authored nav/spawn/pickup pruned at ${x},${z}`);
  for(const route of data.routes)for(const p of route.points)check(graph.nodes.some(n=>Math.hypot(n.x-p.x,n.z-p.z)<=3.01),`route lacks graph coverage: ${route.id} at ${p.x},${p.z}`);
  for(const [index,neighbors] of graph.edges.entries())for(const next of neighbors)check(Math.hypot(graph.nodes[index].x-graph.nodes[next].x,graph.nodes[index].z-graph.nodes[next].z)<=6.5+1e-8,'edge exceeds source limit');
  const kinds=new Set(a.pickups.map(p=>p[0]));
  for(const kind of ['rocket','rail','scatter','plasma','grenade','shock','flak','marksman','smg','ammo','health','armor'])check(kinds.has(kind),`missing pickup ${kind}`);
  const result={id:report.id,geometryHash:data.geometryHash,spawns:data.spawnPoints.length,routes:data.routes.length,floors,rays,navigationNodes:graph.nodes.length,navigationConnected:seen.size===graph.nodes.length,errors};
  results.push(result);console.log(JSON.stringify(result));
}
fs.writeFileSync('port/native-arena-geometry/verification.json',JSON.stringify({godot:'4.5.2.stable.official.6ce3de25a',results},null,2)+'\n');
assert.equal(results.flatMap(r=>r.errors).length,0,'Native/source geometry parity failed; see verification.json');

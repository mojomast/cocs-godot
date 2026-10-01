import {writeFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';
import {loadCampaignMap,CAMPAIGN_MAP_IDS} from '../native-campaign/maps.mjs';
import {createStructureRay,structurePlacements,facadeTriangles} from './structure-rays.mjs';
const maps=[];
for(const id of CAMPAIGN_MAP_IDS) {
  const data=loadCampaignMap(id),ray=createStructureRay(data),placements=structurePlacements(data),cases=[];
  for(const p of placements) {
    const faces=facadeTriangles(p.key);
    for(let i=0;i<faces.length;i+=Math.max(1,Math.floor(faces.length/12))) {
      const points=faces[i].map(v=>v.map((n,j)=>n*p.scale[['x','y','z'][j]]+p.origin[['x','y','z'][j]]));
      const [a,b,c]=points,u=b.map((v,j)=>v-a[j]),v=c.map((v,j)=>v-a[j]);
      // Structural faces, not subpixel bevels: Godot import quantizes tiny
      // bevel vertices and native triangle queries have a larger area epsilon.
      if(Math.min(...points.map((p,j)=>Math.hypot(...p.map((n,k)=>n-points[(j+1)%3][k]))))<.025)continue;
      const normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]],length=Math.hypot(...normal);
      if(length<1e-8)continue;
      const centre=a.map((v,j)=>(v+b[j]+c[j])/3),n=normal.map(v=>v/length);
      const from={},direction={};
      for(const [j,axis] of ['x','y','z'].entries()){from[axis]=centre[j]+n[j]*.3;direction[axis]=-n[j];}
      cases.push({from,direction,max:.6,distance:ray(from,direction,.6),block:p.block.id});
    }
  }
  const start=performance.now();
  for(let i=0;i<2000;i++){const c=cases[i%cases.length];ray(c.from,c.direction,c.max);}
  const elapsed=performance.now()-start;
  maps.push({id,placements:placements.length,cases,cpuMillisecondsPer2000Queries:elapsed});
  console.log(`${id}: ${placements.length} placements; ${cases.length} actual-art queries; 2000 CPU queries ${elapsed.toFixed(2)}ms`);
}
if(process.env.EDGE_MAP_CASES)writeFileSync(process.env.EDGE_MAP_CASES,JSON.stringify(maps));

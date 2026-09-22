import {loadRecipe,CATALOG} from './match.mjs';
import {rayWorld} from '../../game/core.mjs';
import {writeFileSync} from 'node:fs';
const point=a=>({x:a[0],y:a[1],z:a[2]});const report=[];
for(const id of Object.keys(CATALOG)){
 const r=loadRecipe(id),rays=[];
 function ray(o,d,length,label){rays.push({from:o,to:o.map((v,i)=>v+d[i]*length),distance:rayWorld(point(o),point(d),length,r.arena),label});}
 for(const b of r.arena.blocks){ray([b.x-b.w/2-2,1.5,b.z],[1,0,0],b.w+4,b.id+'-cover');}
 for(const s of r.art){const t=s.triangles[Math.floor(s.triangles.length/2)],v=t.map(i=>s.vertices[i]);const ab=v[1].map((x,i)=>x-v[0][i]),ac=v[2].map((x,i)=>x-v[0][i]);const nn=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]],len=Math.hypot(...nn),n=nn.map(x=>x/len),mid=v[0].map((_,i)=>(v[0][i]+v[1][i]+v[2][i])/3);ray(mid.map((x,i)=>x+n[i]*.2),n.map(x=>-x),.4,s.id+'-surface');}
 for(const s of r.arena.terrain.surfaces.filter(s=>s.id!=='court')){
  const v=s.vertices;const x=v[0][0],z=(v[0][2]+v[1][2])/2,h=(v[0][1]+v[1][1])/2;
  ray([x-2,h*.5,z],[1,0,0],4,s.id+'-infill');
 }
 report.push({id,geometryHash:r.geometryHash,rays});
}
writeFileSync(new URL('../../godot/tests/identity_maps/source-rays.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log('Exported '+report.reduce((n,r)=>n+r.rays.length,0)+' independent source ray distances');

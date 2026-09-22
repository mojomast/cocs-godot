import fs from 'node:fs';
import {floorAt,obstructed} from '../../game/core.mjs';
import {terrainWallSegments} from '../../game/terrain.mjs';
const distance=(x,z,a,b)=>{const dx=b.x-a.x,dz=b.z-a.z,l=dx*dx+dz*dz,t=Math.max(0,Math.min(1,((x-a.x)*dx+(z-a.z)*dz)/l));return Math.hypot(x-a.x-dx*t,z-a.z-dz*t);};
for(const id of process.argv.slice(2)){
  const {arena,routes}=JSON.parse(fs.readFileSync(`godot/native_arenas/generated/${id}.json`));
  for(const route of routes){let problems=[];for(let i=1;i<route.points.length;i++){
    const a=route.points[i-1],b=route.points[i],l=Math.hypot(a.x-b.x,a.z-b.z),n=Math.ceil(l/.2);let prev=a.y;
    for(let j=0;j<=n;j++){const t=j/n,x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t,y=floorAt(x,z,arena);if(y===null||Math.abs(y-prev)>.3||obstructed(x,y,z,.52,arena)){
      const wall=terrainWallSegments(arena.terrain).find(({a,b})=>y<Math.max(a.y,b.y)-1e-6&&y+1.8>Math.min(a.y,b.y)+1e-6&&distance(x,z,a,b)<.52);
      problems.push({segment:i,x,y,z,prev,wall:wall??null});break;
    }prev=y;}
  }console.log(id,route.id,JSON.stringify(problems));}
}

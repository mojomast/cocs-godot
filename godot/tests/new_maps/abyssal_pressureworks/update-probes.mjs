import fs from 'node:fs';
import {build} from '../../../../tools/godot-multiplayer/new-maps/abyssal-pressureworks/build.mjs';
import {floorAt,rayWorld} from '../../../../game/core.mjs';
const d=build(),a=d.arena,out={geometryHash:d.geometryHash,support:[],rays:[],bodies:[]};
const ray=(id,from,dir,length)=>out.rays.push({id,from,dir,length,distance:rayWorld({x:from[0],y:from[1],z:from[2]},{x:dir[0],y:dir[1],z:dir[2]},length,a)});
for(const r of a.routes)for(let i=1;i<r.points.length;i++){const A=r.points[i-1],B=r.points[i],n=Math.ceil(Math.hypot(B[0]-A[0],B[1]-A[1]));for(let j=0;j<=n;j++){const x=A[0]+(B[0]-A[0])*j/n,z=A[1]+(B[1]-A[1])*j/n;out.support.push({x,y:floorAt(x,z,a),z,route:r.id});}}
for(const room of a.structures.filter(s=>s.silhouette)){
 for(const wall of a.terrain.walls.filter(w=>w.id.startsWith(room.id+'-shell-')&&w.id.endsWith('-0'))){const [A,B]=wall.vertices,x=(A[0]+B[0])/2,z=(A[2]+B[2])/2,dx=room.x-x,dz=room.z-z,l=Math.hypot(dx,dz),nx=dx/l,nz=dz/l;ray(wall.id,[x+nx*1.5,room.y+2,z+nz*1.5],[-nx,0,-nz],3);out.bodies.push({id:wall.id,kind:'wall',from:[x+nx*1.5,room.y+.86,z+nz*1.5],dir:[-nx,0,-nz],ticks:180});}
 ray(room.id+'-crown',[room.x,room.y+2,room.z],[0,1,0],45);
 out.bodies.push({id:room.id+'-ceiling',kind:'ceiling',from:[room.x,room.y+room.h-1,room.z],dir:[0,1,0],ticks:180});
 for(const [side,p] of Object.entries(room.ports)){const [nx,nz]=({n:[0,-1],s:[0,1],e:[1,0],w:[-1,0]})[side];ray(room.id+'-'+side,[p.center[0]-nx,room.y+2,p.center[1]-nz],[nx,0,nz],2);}
}
ray('transparent-window',[-94,9,-84],[0,0,-1],15);
out.bodies.push({id:'freight-portal',kind:'portal',from:[-72,10.86,0],dir:[1,0,0],ticks:180});
fs.writeFileSync(new URL('./source-probes.json',import.meta.url),JSON.stringify(out)+'\n');
console.log(JSON.stringify({geometryHash:d.geometryHash,support:out.support.length,rays:out.rays.length,bodies:out.bodies.length}));

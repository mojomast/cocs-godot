import {readFileSync,writeFileSync} from 'node:fs';
import {floorAt,rayWorld} from '../../../../game/core.mjs';
const data=JSON.parse(readFileSync(new URL('../../../multiplayer_worlds/generated/vesper-viaduct.json',import.meta.url)));
const support=[];
for(const route of data.arena.routes)for(let i=1;i<route.points.length;i++){
 const a=route.points[i-1],b=route.points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);
 for(let j=0;j<=n;j++){const x=a[0]+(b[0]-a[0])*j/n,z=a[1]+(b[1]-a[1])*j/n;support.push({route:route.id,x,z,y:floorAt(x,z,data.arena)});}
}
const rays=[['tall wall',[-94,14,-10],[1,0,0],10],['sill',[-66,12.6,-18],[0,0,1],10],['open window',[-63,14,-18],[0,0,1],6],['open doorway',[-94,14,0],[1,0,0],12],['roof underside',[-66,14,0],[0,1,0],30],['canal void',[0,2,-110],[0,-1,0],10],['bridge',[-100,2,-110],[0,-1,0],10]].map(([id,origin,direction,length])=>({id,origin,direction,length,source:rayWorld({x:origin[0],y:origin[1],z:origin[2]},{x:direction[0],y:direction[1],z:direction[2]},length,data.arena)}));
writeFileSync(new URL('./source-probes.json',import.meta.url),JSON.stringify({geometryHash:data.geometryHash,support,rays})+'\n');
console.log(JSON.stringify({support:support.length,rays:rays.length,geometryHash:data.geometryHash}));

import fs from 'node:fs';
import {recipe as m} from './recipe-v2.mjs';
import {floorAt,moveActor} from '../../../../game/core.mjs';
const rows=[];
for(const [prefix,a]of [['archive-inner-retaining',170],['irrigation-filter-wall-north',18],['pavilion-inner-plinth',78]]){
 const parts=m.art.meshes.filter(p=>p.id.startsWith(prefix)&&p.collision==='wall');
 const part=parts.reduce((best,p)=>{const angle=q=>Math.atan2(q.vertices[0][2],q.vertices[0][0]);return Math.abs(angle(p)-a*Math.PI/180)<Math.abs(angle(best)-a*Math.PI/180)?p:best;});
 for(const side of [-1,1]){const A=part.vertices[side<0?0:2],B=part.vertices[side<0?1:3],face=[(A[0]+B[0])/2,0,(A[2]+B[2])/2],l=Math.hypot(face[0],face[2]),n=[face[0]/l,0,face[2]/l],x=face[0]+side*n[0]*2,z=face[2]+side*n[2]*2,y=floorAt(x,z,m),start=[x,y,z],direction=n.map(v=>-side*v),actor={x,y,z,vx:0,vy:0,vz:0,grounded:true,moveSpeed:7,health:100};
 for(let i=0;i<120;i++)moveActor(actor,{x:direction[0],z:direction[2]},1/60,m);
 rows.push({id:part.id,side,start,direction,face,sourceGap:side*((actor.x-face[0])*n[0]+(actor.z-face[2])*n[2])});}
}
fs.writeFileSync(new URL('../../../../godot/tests/new_maps/helix_conservatory/contacts.json',import.meta.url),JSON.stringify(rows,null,2)+'\n');

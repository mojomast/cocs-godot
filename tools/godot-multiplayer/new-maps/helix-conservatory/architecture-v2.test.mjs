import test from 'node:test';
import assert from 'node:assert/strict';
import {recipe as m,polar} from './recipe-v2.mjs';
import {floorAt,moveActor,rayWorld,obstructed} from '../../../../game/core.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
const D=Math.PI/180;
test('district walls stop sustained bodies and rays from both sides',()=>{
 for(const [prefix,r,a] of [['archive-inner-retaining',44.5,170],['irrigation-filter-wall-north',60.5,18],['pavilion-inner-plinth',80,78]]){
  const parts=m.art.meshes.filter(p=>p.id.startsWith(prefix)&&p.collision==='wall');assert.ok(parts.length);
  // Select a real authored segment, test its straight inner/outer radial faces.
  const part=parts.reduce((best,p)=>{const angle=q=>Math.atan2(q.vertices[0][2],q.vertices[0][0]);return Math.abs(angle(p)-a*D)<Math.abs(angle(best)-a*D)?p:best;});
  for(const side of [-1,1]){
   const i=side<0?0:2,j=side<0?1:3,A=part.vertices[i],B=part.vertices[j],face={x:(A[0]+B[0])/2,z:(A[2]+B[2])/2},len=Math.hypot(face.x,face.z),n={x:face.x/len,z:face.z/len},x=face.x+side*n.x*2,z=face.z+side*n.z*2,y=floorAt(x,z,m);
   assert.ok(!obstructed(x,y,z,.42,m),`${prefix} fixture starts clear`);
   const actor={x,y,z,vx:0,vy:0,vz:0,grounded:true,moveSpeed:7,health:100};
   for(let tick=0;tick<720;tick++)moveActor(actor,{x:-side*n.x,z:-side*n.z},1/60,m);
   const gap=side*((actor.x-face.x)*n.x+(actor.z-face.z)*n.z);
   assert.ok(gap>=.419&&gap<.65,`${prefix}/${side} contact gap ${gap}`);
   assert.ok(rayWorld({x,y:y+1,z},{x:-side*n.x,y:0,z:-side*n.z},4,m)<2.1,`${prefix} ray contact`);
  }
 }
});
test('broad inlays follow source planes; glazed lab portal and panes pass shots',()=>{
 const terrain={surfaces:m.terrain.surfaces.filter(p=>p.walkable),walls:[]};let count=0;
 for(const part of m.art.meshes.filter(p=>p.id.startsWith('draped-inlay')))for(const t of part.triangles){
  const c=[0,1,2].map(k=>t.reduce((sum,i)=>sum+part.vertices[i][k]/3,0)),support=terrainSupportAt(c[0],c[2],terrain,.8);
  assert.ok(support);assert.ok(Math.abs(c[1]-support.y-.045)<.0001,`${part.id} drape`);count++;
 }
 assert.ok(count>1000);assert.equal(m.art.meshes.some(p=>p.id.startsWith('masonry-joint')),false);
 assert.ok(rayWorld({x:58,y:9.5,z:0},{x:1,y:0,z:0},5,m)>=5,'maintenance portal');
 const a=18*D,[x,z]=polar(58,a);
 assert.ok(rayWorld({x,y:12,z},{x:Math.cos(a),y:0,z:Math.sin(a)},5,m)>=5,'glazed upper facade');
});
test('source architectural budget and single-valued playable terrain',()=>{
 const total=m.art.meshes.reduce((n,p)=>n+p.triangles.length,0);
 assert.ok(total>=100000&&total<=150000,total);
 assert.ok(new Set(m.art.meshes.map(p=>`${p.material}/${p.collision}/${p.walkable}`)).size+m.art.labels.length<100);
 assert.equal(m.verification.primaryRouteIds.length,15);assert.equal(m.verification.interiorRouteIds.length,5);
 assert.ok(m.terrain.walls.every(w=>w.vertices.length===3));
 assert.ok(m.terrain.surfaces.filter(s=>s.walkable).every(s=>!/(roof|vault|truss|specimen|pipe)/.test(s.id)));
});

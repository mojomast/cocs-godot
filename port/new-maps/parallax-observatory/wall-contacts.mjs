#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match,moveActor,floorAt} from '../../multiplayer-worlds/derived/core.mjs';
import {RULES} from '../../../game/data.mjs';
const data=JSON.parse(readFileSync(new URL('../../../godot/multiplayer_worlds/generated/parallax-observatory.json',import.meta.url))),arena=data.arena;
class M extends Match{get arena(){return arena;}set arena(_){} }
const match=new M('chatgpt','openclaw',()=>.5,arena.id,{mode:'deathmatch',botCount:0,humanCount:2});
const split=wall=>Array.from({length:wall.vertices.length-2},(_,i)=>({...wall,id:`${wall.id}-tri-${i}`,vertices:[wall.vertices[0],wall.vertices[i+1],wall.vertices[i+2]]}));
// Recover pre-fix quads from adjacent source triangle pairs, for a durable
// before/fix reproducer even after the checked production recipe is corrected.
const walls=[];for(let i=0;i<arena.terrain.walls.length;i++){const w=arena.terrain.walls[i];if(w.id.endsWith('-tri-0')){const next=arena.terrain.walls[++i];assert.equal(next.id,w.id.replace(/0$/,'1'));walls.push({...w,id:w.id.replace(/-tri-0$/,''),vertices:[...w.vertices,next.vertices[2]]});}else walls.push(w);}
const parapets=walls.filter(w=>w.id.startsWith('parapet'));
const flatAt=y=>parapets.find(w=>Math.abs(w.vertices[0][1]-y)<1e-7&&Math.abs(w.vertices[1][1]-y)<1e-7&&Math.hypot(w.vertices[1][0]-w.vertices[0][0],w.vertices[1][2]-w.vertices[0][2])>2);
const ramp=parapets.find(w=>Math.abs(w.vertices[0][1]-w.vertices[1][1])>.25);
assert.ok(ramp);
function contact(wall,triangles,side,{top=undefined,block=null}={}){
 const v=wall.vertices.map(p=>p.slice());if(top!==undefined){v[2][1]=v[1][1]+top;v[3][1]=v[0][1]+top;}
 const [a,b]=v,dx=b[0]-a[0],dz=b[2]-a[2],len=Math.hypot(dx,dz),nx=-dz/len,nz=dx/len,x=(a[0]+b[0])/2,z=(a[2]+b[2])/2;
 const yAt=(xx,zz)=>(a[1]+b[1])/2+((xx-x)*dx+(zz-z)*dz)/(len*len)*(b[1]-a[1]);
 // A supported test apron isolates the actual wall from the sea void so both
 // sides can receive three seconds of continuous contact input. This is an
 // explicitly synthetic contact fixture, not an added production floor.
 const terrain={maxSlope:.48,surfaces:[{id:'contact-apron',walkable:true,vertices:[[x-40,yAt(x-40,z-40),z-40],[x-40,yAt(x-40,z+40),z+40],[x+40,yAt(x+40,z+40),z+40],[x+40,yAt(x+40,z-40),z-40]],triangles:[[0,1,2],[0,2,3]]}],walls:triangles?split({...wall,vertices:v}):[{...wall,vertices:v}]};
 if(block)terrain.walls=[];
 const fixture={...arena,blocks:block?[block]:[],terrain},actor=match.actors[0],start={x:x+nx*side*3,z:z+nz*side*3};
 Object.assign(actor,{...start,y:floorAt(start.x,start.z,fixture),vx:0,vy:0,vz:0,grounded:true});
 for(let frame=0;frame<180;frame++)moveActor(actor,{x:-nx*side,z:-nz*side},1/60,fixture,match.config);
 const stopDistance=((actor.x-x)*nx+(actor.z-z)*nz)*side;
 return {side,seconds:3,stopDistance,requiredRadius:RULES.radius,crossed:stopDistance<0};
}
const records=[];
for(const [name,wall,top] of [['ground-parapet',flatAt(0)],['upper-parapet',flatAt(24)],['ramped-parapet',ramp],['ground-tall-wall-regression',flatAt(0),4],['upper-tall-wall-regression',flatAt(24),4]]){
 assert.ok(wall,name);const before=[-1,1].map(side=>contact(wall,false,side,{top})),after=[-1,1].map(side=>contact(wall,true,side,{top}));
 if(top===4)assert.ok(before.every(p=>p.crossed),`${name}: reproduce perimeter-edge bug`);
 for(const p of after)assert.ok(!p.crossed&&p.stopDistance>=RULES.radius-.015&&p.stopDistance<=RULES.radius+.16,`${name}: radius stop ${p.stopDistance}`);
 records.push({name,wall:wall.id,fixture:top===4?'same wall footprint extended to 4m height on supported apron':'exact production wall on supported apron',before,after});
}
// Real production geometry: sustained input through both arch mouths, beneath
// each slab, and into the vault's solid side wall at both floor elevations.
const production=[];
for(const prefix of ['ephemeris-vault','tidal-pump-vault']){
 const block=arena.blocks.find(b=>b.id===prefix+'-wall-1'),{x,z,w,baseY:y,h}=block;
 const wall={id:block.id,vertices:[[x-w/2,y,z],[x+w/2,y,z],[x+w/2,h,z],[x-w/2,h,z]]};
 const contacts=[-1,1].map(side=>contact(wall,false,side,{block}));
 for(const p of contacts){p.faceStopDistance=p.stopDistance-block.d/2;assert.ok(p.faceStopDistance>=RULES.radius-.015&&p.faceStopDistance<=RULES.radius+.16);}
 production.push({name:block.id,kind:'exact-production-solid-block-both-faces-supported-apron',contacts});
}
for(const [name,x,z,y] of [['ephemeris',-36,0,12],['cistern',24,78,0]]){
 for(const side of [-1,1]){
  const actor=match.actors[0];Object.assign(actor,{x:x+side*16,y,z,vx:0,vy:0,vz:0,grounded:true});
  for(let i=0;i<240;i++)moveActor(actor,{x:-side,z:0},1/60,arena,match.config);
  const travel=(actor.x-(x+side*16))*(-side);assert.ok(travel>30,`${name}: arch airwall ${travel}`);production.push({name,kind:'arch-and-vault-through',side,seconds:4,travel});
 }
 for(const side of [-1,1]){const actor=match.actors[0];Object.assign(actor,{x:x+10,y,z:z+side*3,vx:0,vy:0,vz:0,grounded:true});for(let i=0;i<180;i++)moveActor(actor,{x:0,z:side},1/60,arena,match.config);const distance=7.2-(actor.z-z)*side;assert.ok(distance>=RULES.radius-.015&&distance<RULES.radius+.16,`${name}: solid wall stop ${distance}`);production.push({name,kind:'vault-side-wall',side,seconds:3,stopDistance:distance});}
}
{const actor=match.actors[0];Object.assign(actor,{x:20,y:12,z:0,vx:0,vy:0,vz:0,grounded:true});for(let i=0;i<240;i++)moveActor(actor,{x:1,z:0},1/60,arena,match.config);assert.ok(actor.x>50);production.push({name:'meridian-service-gallery',kind:'continuous-walk-under',seconds:4,travel:actor.x-20});}
// Standing contact is clear under the bridge. A deliberately upward-launched
// actor must be stopped by the real underside rather than enter the slab.
for(const roof of arena.overhead){const actor=match.actors[0],floor=floorAt(roof.x,roof.z,arena);Object.assign(actor,{x:roof.x,y:floor,z:roof.z,vx:0,vy:16,vz:0,grounded:false});let maxY=actor.y;for(let i=0;i<120;i++){moveActor(actor,{x:0,z:0},1/60,arena,match.config);maxY=Math.max(maxY,actor.y);}assert.ok(maxY+RULES.height<=roof.minY+.05,`${roof.id}: ceiling penetration`);assert.ok(maxY>floor+1);production.push({name:roof.id,kind:'upward-ceiling-contact',maxFeetY:maxY,headLimit:roof.minY});}
console.log(JSON.stringify({id:arena.id,geometryHash:data.geometryHash,radius:RULES.radius,records,production},null,2));

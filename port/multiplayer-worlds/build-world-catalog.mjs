#!/usr/bin/env node
// Port-owned source-compatible bridge: preserve world-lane recipes byte-for-byte.
// Ground, under-roof, roof-top and roof-side collision are generated from the
// exact minY/maxY AABBs. No GLB mesh is ever used as game authority.
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical} from './catalog.mjs';
import {terrainSupportAt} from '../../game/terrain.mjs';
const ids=['breakwater-exchange','thermal-divide','sirocco-circuit','copper-bowl','tern-archipelago'];
const quad=(id,box,y,walkable=false,flip=false)=>({id,material:'steel',walkable,vertices:[[box.x-box.w/2,y,box.z-box.d/2],[box.x+box.w/2,y,box.z-box.d/2],[box.x+box.w/2,y,box.z+box.d/2],[box.x-box.w/2,y,box.z+box.d/2]],triangles:flip?[[0,1,2],[0,2,3]]:[[2,1,0],[3,2,0]]});
const sides=box=>{
 const x0=box.x-box.w/2,x1=box.x+box.w/2,z0=box.z-box.d/2,z1=box.z+box.d/2,a=box.minY,b=box.maxY;
 return [
  {vertices:[[x0,a,z0],[x1,a,z0],[x1,b,z0],[x0,b,z0]]},
  {vertices:[[x1,a,z1],[x0,a,z1],[x0,b,z1],[x1,b,z1]]},
  {vertices:[[x0,a,z1],[x0,a,z0],[x0,b,z0],[x0,b,z1]]},
  {vertices:[[x1,a,z0],[x1,a,z1],[x1,b,z1],[x1,b,z0]]},
 ];
};
for(const id of ids){
 const recipe=JSON.parse(readFileSync(new URL(`../../port/native-multiplayer-worlds/worlds/${id}.json`,import.meta.url),'utf8'));
 if(recipe.id!==id||!Array.isArray(recipe.blocks)||!Array.isArray(recipe.spawns))throw Error(`Invalid source-compatible world ${id}`);
 const over=recipe.overhead??[],arena={...recipe};
 const flat={maxSlope:.9,base:0,amplitude:0,surfaces:[quad('authored-flat-ground',{x:(arena.bounds.minX+arena.bounds.maxX)/2,z:(arena.bounds.minZ+arena.bounds.maxZ)/2,w:arena.bounds.maxX-arena.bounds.minX,d:arena.bounds.maxZ-arena.bounds.minZ},0,true)],walls:[]};
 arena.terrain=arena.terrain??flat;
 arena.terrain={...arena.terrain,surfaces:[...arena.terrain.surfaces],walls:[...arena.terrain.walls]};
 for(const roof of over){
  if(![roof.x,roof.z,roof.w,roof.d,roof.minY,roof.maxY].every(Number.isFinite)||roof.w<=0||roof.d<=0||roof.maxY<=roof.minY)throw Error(`Invalid overhead ${id}/${roof.id}`);
  arena.terrain.surfaces.push(quad(`${roof.id}-roof-top`,roof,roof.maxY,false));
  arena.terrain.surfaces.push(quad(`${roof.id}-roof-underside`,roof,roof.minY,false,true));
  arena.terrain.walls.push(...sides(roof));
 }
 const spawnPoints=arena.spawns.map(([x,z])=>({x,y:terrainSupportAt(x,z,arena.terrain,arena.terrain.maxSlope)?.y??0,z}));
 // Preserve the original recipe as a checked input; the derived arena is the
 // complete authority geometry and receives its own canonical gameplay hash.
 const recipeHash=createHash('sha256').update(readFileSync(new URL(`../../port/native-multiplayer-worlds/worlds/${id}.json`,import.meta.url))).digest('hex');
 const data={schemaVersion:1,id,name:arena.name,geometryHash:createHash('sha256').update(canonical(arena)).digest('hex'),recipeHash,spawnPoints,arena};
 const path=new URL(`../../godot/multiplayer_worlds/generated/${id}.json`,import.meta.url),bytes=JSON.stringify(data)+'\n';
 if(process.argv.includes('--check')){if(readFileSync(path,'utf8')!==bytes)throw Error(`Stale source world ${id}`);}else writeFileSync(path,bytes);
 console.log(id,data.geometryHash,over.length,'overhead');
}

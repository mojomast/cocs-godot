#!/usr/bin/env node
// Inspect the *shipped GLBs* and collision recipes, not exporter estimates.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {readWorld} from '../../../port/multiplayer-worlds/catalog.mjs';
import {floorAt,obstructed} from '../../../port/multiplayer-worlds/derived/core.mjs';

const result=[];
for(const [id,theme] of [['switchyard-ward','ward'],['rainmarket-exchange','market']]){
 const {arena,geometryHash}=readWorld(id);
 const glb=readFileSync(new URL(`../../../godot/multiplayer_worlds/art/${id}.glb`,import.meta.url));
 assert.equal(glb.toString('ascii',0,4),'glTF');
 assert.equal(glb.readUInt32LE(8),glb.byteLength);
 const json=JSON.parse(glb.subarray(20,20+glb.readUInt32LE(12)).toString());
 const primitives=json.meshes.flatMap(mesh=>mesh.primitives);
 const triangles=primitives.reduce((n,primitive)=>n+json.accessors[primitive.indices].count/3,0);
 assert.ok(triangles>24000&&triangles<38000,`${id}: shipped art triangle budget ${triangles}`);
 assert.ok(primitives.length<=12,`${id}: art draw-call budget`);
 assert.ok(json.materials.some(m=>/windows|glazing/.test(m.name))&&json.materials.some(m=>m.name.includes(theme)),`${id}: distinct facade palette`);
 assert.ok(glb.byteLength<3_000_000,`${id}: GLB byte budget`);
 assert.equal(arena.overhead?.length,4,`${id}: all four shops need a sealed overhead slab`);
 for(const block of arena.blocks.filter(b=>b.id.includes('-counter-')||b.id.includes('-guard-'))){
  assert.ok(block.h>block.baseY&&block.w>0&&block.d>0);
  if(block.id.includes('-guard-')){
   // Guards stand on the real upper support; a rail must stop a waist-high
   // LOS ray and not occupy a 0.65m-radius roof navigation point.
   const y=floorAt(block.x,block.z,arena);
   assert.ok(y>=2.7&&y<=3.2,`${id}/${block.id}: unsupported rail`);
   assert.ok(obstructed(block.x,y,block.z,.1,arena),`${id}/${block.id}: phantom rail`);
  }
 }
 const sidewalks=arena.terrain.surfaces.filter(s=>s.id.includes('sidewalk')||s.id.includes('promenade')||s.id.includes('boardwalk'));
 assert.ok(sidewalks.length>=6,`${id}: street pavement coverage`);
 for(const surface of sidewalks){
  const [a,b,c]=surface.vertices;
  const x=(a[0]+c[0])/2,z=(a[2]+c[2])/2;
  assert.ok(Math.abs(floorAt(x,z,arena)-.12)<.02,`${id}/${surface.id}: sidewalk not on source floor`);
 }
 result.push({id,geometryHash,glbBytes:glb.byteLength,triangles,drawBatches:primitives.length,sidewalks:sidewalks.length,collidableCounters:arena.blocks.filter(b=>b.id.includes('-counter-')).length,roofGuards:arena.blocks.filter(b=>b.id.includes('-guard-')).length,sealedShops:arena.overhead.length});
}
console.log(JSON.stringify(result,null,2));

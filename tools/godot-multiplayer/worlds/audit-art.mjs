#!/usr/bin/env node
// Offline GLB validation while Godot belongs to another lane. Diagnostics do
// not imply a native import/render has been reviewed.
import assert from 'node:assert/strict';
import {readFileSync,statSync} from 'node:fs';
const root=new URL('../../../godot/multiplayer_worlds/art/worlds/',import.meta.url);
const expected={
 'breakwater-exchange':{vertices:13000,height:18.5,materials:['bronze','charcoal','glow-amber','safety-yellow']},
 'thermal-divide':{vertices:8000,height:30,materials:['basalt','bronze','charcoal','ice-blue','sediment']},
 'sirocco-circuit':{vertices:16000,height:30,materials:['sandstone','red-earth','bronze','glow-amber']},
 'copper-bowl':{vertices:3500,height:15,materials:['pitch','copper','charcoal','salt','hazard-white']},
 'tern-archipelago':{vertices:6000,height:12,materials:['deep-water','causeway','limestone','charcoal','cedar']},
};
const result=[];
for(const [id,checks] of Object.entries(expected)){
 const url=new URL(id+'.glb',root),bytes=readFileSync(url);
 assert.equal(bytes.toString('ascii',0,4),'glTF');
 assert.equal(bytes.readUInt32LE(8),bytes.length);
 assert.equal(bytes.toString('ascii',16,20),'JSON');
 const gltf=JSON.parse(bytes.toString('utf8',20,20+bytes.readUInt32LE(12)));
 const names=gltf.materials.map(material=>material.name);
 for(const material of checks.materials)assert.ok(names.includes(material),`${id}: ${material} batch not exported`);
 assert.equal(gltf.meshes.length,gltf.nodes.length,`${id}: one unrotated material batch per mesh`);
 assert.ok(gltf.nodes.every(node=>!node.rotation&&!node.scale&&!node.translation),`${id}: a mesh transforms away from recipe frame`);
 const accessors=gltf.meshes.flatMap(mesh=>mesh.primitives.map(p=>gltf.accessors[p.attributes.POSITION]));
 const vertices=accessors.reduce((total,a)=>total+a.count,0);
 const bounds={min:[Infinity,Infinity,Infinity],max:[-Infinity,-Infinity,-Infinity]};
 for(const accessor of accessors)for(let i=0;i<3;i++){
  bounds.min[i]=Math.min(bounds.min[i],accessor.min[i]);
  bounds.max[i]=Math.max(bounds.max[i],accessor.max[i]);
 }
 assert.ok(vertices>=checks.vertices,`${id}: only ${vertices} vertices, expected >=${checks.vertices}`);
 assert.ok(bounds.max[1]>=checks.height,`${id}: missing dominant architecture height ${bounds.max[1]}`);
 assert.ok(bytes.length<2_000_000,`${id}: oversized art GLB ${bytes.length}`);
 const entry={id,bytes:statSync(url).size,meshBatches:gltf.meshes.length,vertices,bounds,materials:names};
 result.push(entry);
}
console.log(JSON.stringify(result,null,2));

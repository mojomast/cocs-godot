#!/usr/bin/env node
// Run after the granted Blender build; validates actual GLB bytes, not targets.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('../../../',import.meta.url),id='parallax-observatory';
const read=path=>readFileSync(new URL(path,root));
const data=JSON.parse(read(`godot/multiplayer_worlds/generated/${id}.json`));
const dir=`godot/multiplayer_worlds/art/${id}/`,manifest=JSON.parse(read(dir+'asset-manifest.json'));
const bytes=read(dir+id+'.glb');
assert.equal(bytes.readUInt32LE(0),0x46546c67);assert.equal(bytes.readUInt32LE(4),2);assert.equal(bytes.readUInt32LE(8),bytes.length);
const gltf=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
assert.equal(manifest.geometryHash,data.geometryHash);assert.equal(manifest.recipeHash,data.recipeHash);
assert.equal(createHash('sha256').update(bytes).digest('hex'),manifest.glbSha256);
const blend=read(`tools/godot-multiplayer/new-maps/${id}/${id}.blend`);
assert.equal(createHash('sha256').update(blend).digest('hex'),manifest.blendSha256);
let triangles=0;for(const mesh of gltf.meshes)for(const primitive of mesh.primitives){assert.equal(primitive.mode??4,4);triangles+=gltf.accessors[primitive.indices??primitive.attributes.POSITION].count/3;}
assert.ok(triangles<=data.art.budgets.triangles);assert.ok(bytes.length<=data.art.budgets.glbBytes);assert.ok(gltf.materials.length<=data.art.budgets.materialBatches);
for(const node of gltf.nodes.filter(n=>n.mesh!==undefined)){assert.equal(node.extras.geometryHash,data.geometryHash);assert.equal(node.extras.recipeHash,data.recipeHash);}
assert.equal(gltf.nodes.filter(n=>n.mesh!==undefined).length,7);
console.log(JSON.stringify({id,geometryHash:data.geometryHash,triangles,glbBytes:bytes.length,materialBatches:gltf.materials.length,glbSha256:manifest.glbSha256,blendSha256:manifest.blendSha256},null,2));

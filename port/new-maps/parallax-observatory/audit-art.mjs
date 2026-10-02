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
// Direct GLB triangle support independently checks the presentation union.
// This also distinguishes mesh coverage from the native temporary concave
// shape's strict exactly-on-edge ray rejection at six clipping seams.
const binary=bytes.subarray(28+bytes.readUInt32LE(12));
function accessor(i){const a=gltf.accessors[i],v=gltf.bufferViews[a.bufferView],n=a.type==='VEC3'?3:1,size=a.componentType===5123?2:4;return Array.from({length:a.count},(_,j)=>Array.from({length:n},(_,k)=>{const p=(v.byteOffset??0)+(a.byteOffset??0)+j*(v.byteStride??n*size)+k*size;return a.componentType===5126?binary.readFloatLE(p):size===2?binary.readUInt16LE(p):binary.readUInt32LE(p);}));}
const grid=new Map();for(const mesh of gltf.meshes)for(const primitive of mesh.primitives){const v=accessor(primitive.attributes.POSITION),indices=accessor(primitive.indices).flat();for(let i=0;i<indices.length;i+=3){const t=indices.slice(i,i+3).map(j=>v[j]),[a,b,c]=t,den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2]);if(Math.abs(den)<1e-7)continue;for(let x=Math.floor(Math.min(...t.map(p=>p[0]))/8);x<=Math.floor(Math.max(...t.map(p=>p[0]))/8);x++)for(let z=Math.floor(Math.min(...t.map(p=>p[2]))/8);z<=Math.floor(Math.max(...t.map(p=>p[2]))/8);z++){const key=x+','+z;if(!grid.has(key))grid.set(key,[]);grid.get(key).push({a,b,c,den});}}}
let samples=0,maxSupportError=0;for(const route of data.routes)for(let i=1;i<route.points.length;i++){const a=route.points[i-1],b=route.points[i],count=Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/1.5);for(let j=0;j<=count;j++){const t=j/count,x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t,y=z< -60?24:z< -12?12+(-z-12)/4:z<=12?12:z<60?12-(z-12)/4:0;let error=Infinity;for(const {a,b,c,den} of grid.get(Math.floor(x/8)+','+Math.floor(z/8))??[]){const u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den,v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den,w=1-u-v;if(Math.min(u,v,w)>=-1e-6)error=Math.min(error,Math.abs(u*a[1]+v*b[1]+w*c[1]-y));}assert.ok(error<.001,`Missing exact GLB floor ${x},${y},${z}: ${error}`);samples++;maxSupportError=Math.max(maxSupportError,error);}}
console.log(JSON.stringify({id,geometryHash:data.geometryHash,triangles,glbBytes:bytes.length,materialBatches:gltf.materials.length,glbSupportSamples:samples,maxSupportError,glbSha256:manifest.glbSha256,blendSha256:manifest.blendSha256},null,2));

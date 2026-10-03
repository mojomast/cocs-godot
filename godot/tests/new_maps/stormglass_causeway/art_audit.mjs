import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const bytes=readFileSync('godot/multiplayer_worlds/art/worlds/stormglass-causeway.glb');
const jsonLength=bytes.readUInt32LE(12),g=JSON.parse(bytes.toString('utf8',20,20+jsonLength));
const binary=bytes.subarray(28+jsonLength);
function accessor(id){
 const a=g.accessors[id],view=g.bufferViews[a.bufferView],size={SCALAR:1,VEC2:2,VEC3:3,VEC4:4}[a.type],componentBytes={5123:2,5125:4,5126:4}[a.componentType];
 assert.ok(size&&componentBytes);
 const offset=(view.byteOffset??0)+(a.byteOffset??0),stride=view.byteStride??size*componentBytes;
 return Array.from({length:a.count},(_,i)=>Array.from({length:size},(_,j)=>{
  const p=offset+i*stride+j*componentBytes;
  return a.componentType===5126?binary.readFloatLE(p):a.componentType===5125?binary.readUInt32LE(p):binary.readUInt16LE(p);
 }));
}
const point=p=>p.map(v=>Math.round(v*1000)).join(','),key=t=>t.map(point).sort().join('|');
const triangles=new Map(),streams=[],rawTriangles=[];
let total=0;
for(const mesh of g.meshes){
 for(const primitive of mesh.primitives){
  const pos=accessor(primitive.attributes.POSITION),indices=accessor(primitive.indices).flat();total+=indices.length/3;
  const mat=g.materials[primitive.material],preserved=['amber','glass','ocean'].includes(mat.name);
  assert.ok(primitive.attributes.NORMAL!==undefined);
  if(!preserved)assert.ok(primitive.attributes.TEXCOORD_0!==undefined&&mat.pbrMetallicRoughness.baseColorTexture);
  if(['asphalt','concrete','salt','brick','steel'].includes(mat.name))assert.ok(mat.normalTexture);
  if(mat.name==='teal')assert.equal(mat.normalTexture,undefined);
  streams.push({mesh:mesh.name,material:mat.name,vertices:pos.length,triangles:indices.length/3,textured:!preserved,normal:!!mat.normalTexture});
  // Recipe meshes are baked identity batches. Text nodes are separately transformed.
  if(!mesh.name.startsWith('batch-'))continue;
  for(let i=0;i<indices.length;i+=3){const t=indices.slice(i,i+3).map(j=>pos[j]),k=key(t),record={t,used:false};rawTriangles.push(record);if(!triangles.has(k))triangles.set(k,[]);triangles.get(k).push(record);}
 }
}
const arena=JSON.parse(readFileSync('port/native-multiplayer-worlds/worlds/stormglass-causeway.json'));
let matched=0,maxVertexError=0;const missing=[];
const error=(a,b)=>Math.max(...a.map(p=>Math.min(...b.map(q=>Math.hypot(...p.map((x,i)=>x-q[i]))))));
for(const mesh of arena.art.meshes)for(const t of mesh.triangles){
 const source=t.map(i=>mesh.vertices[i]),k=key(source);
 let record=(triangles.get(k)??[]).find(r=>!r.used&&error(source,r.t)<.0001);
 // Float32 conversion can straddle a quantization bin: verify actual distances.
 record??=rawTriangles.find(r=>!r.used&&error(source,r.t)<.0001);
 if(record){matched++;record.used=true;maxVertexError=Math.max(maxVertexError,error(source,record.t));}else missing.push(mesh.id);
}
assert.equal(missing.length,0,JSON.stringify(missing.slice(0,20)));
const sources=Object.fromEntries(['architecture.py','blender_export.py','recipe.mjs'].map(f=>[f,createHash('sha256').update(readFileSync('tools/godot-multiplayer/new-maps/stormglass-causeway/'+f)).digest('hex')]));
const report={accepted:false,glbSha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,triangles:total,matchedSourceTriangles:matched,maxVertexErrorMetres:maxVertexError,comparisonToleranceMetres:.0001,extraTriangles:total-matched,streams,sources};
if(process.argv[2])writeFileSync(process.argv[2],JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({triangles:total,matchedSourceTriangles:matched,extraTriangles:total-matched,streams:streams.length}));

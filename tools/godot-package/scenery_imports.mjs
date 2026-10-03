import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const base='port/expansion-four/scenery/production-f/';
export const SCENERY_MANIFEST=base+'final-assets.json';
export const SCENERY_EVIDENCE=[SCENERY_MANIFEST,base+'generic-receipt.json',base+'HEAVY_GRANT_RELEASE.json',base+'inspection-final/manifest.json',base+'architecture-final/manifest.json',base+'journeys-final/summary.json',
 ...['rootfall-verge-wide','rootfall-verge-compact','siltwake-crossing-wide','emberline-ascent-wide','crown-array-wide'].flatMap(p=>['witness.json','journey.json','manifest.json'].map(f=>base+'journeys-final/'+p+'/'+f))];
const hash=b=>createHash('sha256').update(b).digest('hex');
function manifest(read) {
 const bytes=read(SCENERY_MANIFEST);
 assert.equal(hash(bytes),'f5e7b53a536c7198128f9ff6ce6a9b6fbd41470d57ace08e7ce753398b5daf7f','Immutable received F manifest');
 return JSON.parse(bytes).files.filter(r=>r.path.startsWith('godot/biomes/expansion/art/'));
}
export function sceneryImportPaths(exports,read) {
 const rows=manifest(read);
 assert.deepEqual(rows.filter(r=>r.path.endsWith('.glb')).map(r=>r.path).sort(),[...exports].sort());
 const paths=rows.filter(r=>!r.path.endsWith('.glb')).map(r=>r.path);
 assert.equal(paths.filter(p=>p.endsWith('.png')).length,118);
 assert.equal(paths.filter(p=>p.endsWith('.png.import')).length,118);
 assert.equal(paths.filter(p=>p.endsWith('.glb.import')).length,24);
 assert.equal(new Set(paths).size,260);assert.equal(paths.length,260);
 return paths;
}
export function verifySceneryImports(exports,read) {
 const paths=sceneryImportPaths(exports,read),rows=manifest(read),extracted=[];
 for(const path of [...exports,...paths]) {
  const row=rows.find(r=>r.path===path),bytes=read(path);
  assert.equal(bytes.length,row.bytes,'Scenery received byte size: '+path);
  assert.equal(hash(bytes),row.sha256,'Scenery received hash: '+path);
 }
 for(const path of exports) {
  const bytes=read(path),size=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+size)),bin=bytes.subarray(28+size);
  for(const image of doc.images) {
   assert.match(image.name,/^MothLocal(?:Normal)?_biome4_[a-z]+$/);
   assert.equal(image.mimeType,'image/png');assert.equal(image.uri,undefined);
   const view=doc.bufferViews[image.bufferView];assert.equal(view.buffer,0);
   const png=path.replace(/\.glb$/,'_'+image.name+'.png'),data=read(png);
   assert.deepEqual(data,bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength),'Scenery embedded/extracted image mismatch');
   assert.equal(data.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
   assert.equal(data.toString('ascii',12,16),'IHDR');
   assert.ok(data.readUInt32BE(16)>0&&data.readUInt32BE(20)>0);
   extracted.push(png);
  }
 }
 assert.deepEqual(extracted.sort(),paths.filter(p=>p.endsWith('.png')).sort(),'Exact scenery image shape');
 for(const source of [...exports,...extracted]) {
  const scene=source.endsWith('.glb'),text=read(source+'.import').toString();
  const line=value=>assert.ok(text.split('\n').includes(value),'Scenery import policy: '+source+' '+value);
  line(`source_file="res://${source.slice(6)}"`);line(`importer="${scene?'scene':'texture'}"`);
  for(const value of scene?['meshes/force_disable_compression=true','meshes/ensure_tangents=true','meshes/generate_lods=false','gltf/embedded_image_handling=1']:['compress/mode=0','compress/normal_map=0','process/normal_map_invert_y=false','process/size_limit=0'])line(value);
 }
}

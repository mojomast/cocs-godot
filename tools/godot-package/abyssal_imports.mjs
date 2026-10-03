import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const ABYSSAL_GLB='godot/multiplayer_worlds/art/worlds/abyssal-pressureworks.glb';
export const ABYSSAL_INVENTORY='tools/godot-package/abyssal_i_inventory.json';
const base='port/expansion-three/abyssal/evidence/production-i/';
export const ABYSSAL_EVIDENCE=[ABYSSAL_INVENTORY,...['producer-receipt.json','release-i.json','manifest.json','inspection.json','hosted-summary.json'].map(p=>base+p),
 ...['deathmatch','teamdeathmatch','ctf','koth','domination','holdout'].flatMap(mode=>['outcome.json','teardown.json','private-authority/derivation.json'].map(p=>base+mode+'/'+p))];
export const ABYSSAL_SUPPORTING_RUNTIME={
 'godot/multiplayer_worlds/catalog.gd':{before:'22bcfe114a3c80b0db310ced91f8bf0a9079e0f0f404f4f422a92e5d6a2bb4ca',after:'65a0b3f6fb962eec1cf0b2c0c42a9bfd27713cc850f799e5ab1cc7c72d0cc53a'},
 'godot/multiplayer_worlds/demo.gd':{before:'0284095333fd3e278b1fb9b276cc334436aab9b42bd915ffa988b7381bbe2906',after:'07754d84e61a71756f602d9b9c18e7b717b61fc4e04a21dc8e698d0049cc2748'},
 'godot/multiplayer_worlds/map.gd':{before:'c24d976d372b2ddaf636ae17ac6bc30d8d147a9ab993a3cd9b96cff8ff4a92db',after:'42f7a343947a43f8de328d6b7fedc031824432d73655cc488d42c167cddac543'},
};
const hash=b=>createHash('sha256').update(b).digest('hex');
const names=['MothLocal_copper','MothLocal_coral','MothLocal_ivory','MothLocal_navy','MothLocalNormal_copper'];
export function abyssalImportPaths(){return [ABYSSAL_GLB+'.import',...names.flatMap(name=>{
 const p=ABYSSAL_GLB.replace(/\.glb$/,'_'+name+'.png');return [p,p+'.import'];
})];}
export function verifyAbyssalImports(read){
 const inventory=JSON.parse(read(ABYSSAL_INVENTORY)),paths=[ABYSSAL_GLB,...abyssalImportPaths()];
 assert.deepEqual(inventory.files.map(r=>r.path).sort(),paths.sort(),'Exact I import inventory');
 for(const row of inventory.files){const bytes=read(row.path);assert.equal(bytes.length,row.bytes,'I byte size: '+row.path);assert.equal(hash(bytes),row.sha256,'I content hash: '+row.path);}
 const bytes=read(ABYSSAL_GLB),size=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+size)),bin=bytes.subarray(size+28);
 assert.deepEqual(doc.images.map(i=>i.name).sort(),[...names].sort());
 for(const image of doc.images){
  assert.equal(image.mimeType,'image/png');assert.equal(image.uri,undefined);
  const view=doc.bufferViews[image.bufferView];assert.equal(view.buffer,0);
  const data=read(ABYSSAL_GLB.replace(/\.glb$/,'_'+image.name+'.png'));
  assert.deepEqual(data,bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength),'I embedded/extracted image identity');
  assert.equal(data.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.equal(data.toString('ascii',12,16),'IHDR');assert.ok(data.readUInt32BE(16)>0&&data.readUInt32BE(20)>0);
 }
 for(const source of paths.filter(p=>!p.endsWith('.import'))){
  const text=read(source+'.import').toString(),scene=source===ABYSSAL_GLB;
  const line=s=>assert.ok(text.split('\n').includes(s),'I import policy: '+source+' '+s);
  line(`source_file="res://${source.slice(6)}"`);line(`importer="${scene?'scene':'texture'}"`);
  for(const p of scene?['meshes/ensure_tangents=true','meshes/generate_lods=true','meshes/force_disable_compression=false','gltf/embedded_image_handling=1']:['compress/mode=0','compress/normal_map=0','process/normal_map_invert_y=false','process/size_limit=0'])line(p);
 }
}

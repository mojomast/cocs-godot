import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const VESPER_GLB='godot/multiplayer_worlds/art/worlds/vesper-viaduct.glb';
export const VESPER_INVENTORY='tools/godot-package/vesper_h_inventory.json';
const base='port/expansion-three/vesper/evidence/production-h/';
export const VESPER_EVIDENCE=[VESPER_INVENTORY,...['resource-receipt.json','release-h.json','preservation.json','inspection.json','hosted-summary.json'].map(p=>base+p),
 ...['deathmatch','teamdeathmatch','ctf','domination','koth','uplink'].flatMap(mode=>['outcome.json','teardown.json'].map(p=>base+mode+'/'+p))];
const hash=b=>createHash('sha256').update(b).digest('hex');
export const VESPER_SUPPORTING_RUNTIME={
 'godot/multiplayer_worlds/catalog.gd':{before:'a7d9a5c665ad1b13cfc378d0c37ff37f043f91ade326fae3b3886f0adf6274be',after:'22bcfe114a3c80b0db310ced91f8bf0a9079e0f0f404f4f422a92e5d6a2bb4ca'},
 'godot/multiplayer_worlds/demo.gd':{before:'0acd5e67d1267595d3cc4080e73c12a01b8184ab49277b5357c55c5900f68d2c',after:'0284095333fd3e278b1fb9b276cc334436aab9b42bd915ffa988b7381bbe2906'},
};
const roles=['quay','cobbles','asphalt','sandstone','brick','iron','slate','plaster'];
export function vesperImportPaths(){return [VESPER_GLB+'.import',...roles.flatMap(role=>['MothLocal_','MothLocalNormal_'].flatMap(prefix=>{
 const p=VESPER_GLB.replace(/\.glb$/,'_'+prefix+role+'.png');return [p,p+'.import'];
}))];}
export function verifyVesperImports(read){
 const inventory=JSON.parse(read(VESPER_INVENTORY));
 const paths=[VESPER_GLB,...vesperImportPaths()];
 assert.deepEqual(inventory.files.map(r=>r.path).sort(),paths.sort(),'Exact H import inventory');
 for(const row of inventory.files){const bytes=read(row.path);assert.equal(bytes.length,row.bytes,'H byte size: '+row.path);assert.equal(hash(bytes),row.sha256,'H content hash: '+row.path);}
 const bytes=read(VESPER_GLB),size=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+size)),bin=bytes.subarray(size+28);
 assert.deepEqual(doc.images.map(i=>i.name).sort(),roles.flatMap(r=>['MothLocal_'+r,'MothLocalNormal_'+r]).sort());
 for(const image of doc.images){
  assert.equal(image.mimeType,'image/png');assert.equal(image.uri,undefined);
  const view=doc.bufferViews[image.bufferView];assert.equal(view.buffer,0);
  const png=VESPER_GLB.replace(/\.glb$/,'_'+image.name+'.png'),data=read(png);
  assert.deepEqual(data,bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength),'H embedded/extracted image identity');
  assert.equal(data.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
  assert.equal(data.toString('ascii',12,16),'IHDR');assert.ok(data.readUInt32BE(16)>0&&data.readUInt32BE(20)>0);
 }
 for(const source of paths.filter(p=>!p.endsWith('.import'))){
  const text=read(source+'.import').toString(),scene=source===VESPER_GLB;
  const line=s=>assert.ok(text.split('\n').includes(s),'H import policy: '+source+' '+s);
  line(`source_file="res://${source.slice(6)}"`);line(`importer="${scene?'scene':'texture'}"`);
  // Preserve actual H defaults, unlike scenery's lossless-mesh policy. This
  // source promotion cannot claim a reimport under different engine settings.
  for(const p of scene?['meshes/ensure_tangents=true','meshes/generate_lods=true','meshes/force_disable_compression=false','gltf/embedded_image_handling=1']:['compress/mode=0','compress/normal_map=0','process/normal_map_invert_y=false','process/size_limit=0'])line(p);
 }
}

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {vehicleImportPaths,verifyVehicleImports} from './vehicle_imports.mjs';
import {productionResources,inspectProductionGlb,REQUIREMENTS} from './production_resources.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const read=p=>readFileSync(root+p),has=p=>existsSync(root+p),sha=b=>createHash('sha256').update(b).digest('hex');
const receiptPath='tools/godot-package/production_receipts/vehicles.json';
const receipt=JSON.parse(read(receiptPath)),exports=receipt.exports.map(r=>r.path);
const options={read,has,worldIds:Object.keys(WORLDS),strict:false};

test('nine real vehicle exports bind 69 exact albedo/normal PNGs and 78 import sidecars',()=>{
  verifyVehicleImports(exports,read);
  const paths=vehicleImportPaths(exports),result=productionResources(options);
  assert.equal(paths.filter(p=>p.endsWith('.png')).length,69);
  assert.equal(paths.filter(p=>p.endsWith('.import')).length,78);
  for(const p of paths)assert.equal((p.endsWith('.import')?result.provenance:result.resources)[p],sha(read(p)));
  for(const row of receipt.exports)assert.deepEqual(inspectProductionGlb(read(row.path),receipt.sourceFingerprint),row.textures);
});

test('real missing or tampered vehicle master, GLB, extracted image and sidecar refuse promotion',()=>{
  for(const p of [receipt.masters[0].path,exports[0],...vehicleImportPaths([exports[0]]).slice(0,5)]) {
    const missing={...options,has:path=>path!==p&&has(path)};
    assert.ok(productionResources(missing).pending.includes('vehicles'));
    assert.throws(()=>productionResources({...missing,strict:true}),/remain pending/);
    assert.throws(()=>productionResources({...options,read:path=>path===p?Buffer.from('tampered'):read(path)}),/content hash mismatch/);
  }
});

test('refreshed receipt hashes cannot bless wrong extracted normal/albedo or import policy',()=>{
  const paths=vehicleImportPaths([exports[0]]),sidecar=paths[0],normal=paths[1],albedo=paths[3];
  for(const [p,bytes,pattern]of [
    [normal,Buffer.from('changed normal PNG'),/extracted PNG differs/],
    [albedo,Buffer.from('changed albedo PNG'),/extracted PNG differs/],
    [sidecar,Buffer.from(read(sidecar).toString().replace('gltf/embedded_image_handling=1','gltf/embedded_image_handling=0')),/extracted-image policy/],
    [sidecar,Buffer.from(read(sidecar).toString().replace('meshes/ensure_tangents=true','meshes/ensure_tangents=false')),/tangent policy/],
    [normal+'.import',Buffer.from(read(normal+'.import').toString().replace('source_file="res://','source_file="res://wrong/')),/import source identity/],
    [normal+'.import',Buffer.from(read(normal+'.import').toString().replace('process/normal_map_invert_y=false','process/normal_map_invert_y=true')),/normal orientation/],
  ]) {
    const r=structuredClone(receipt);r.packageInputs[p]=sha(bytes);
    const rb=Buffer.from(JSON.stringify(r)),req=JSON.parse(read(REQUIREMENTS));req.units.vehicles.promotion.sha256=sha(rb);
    assert.throws(()=>productionResources({...options,read:path=>path===p?bytes:path===receiptPath?rb:path===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(path)}),pattern);
  }
});

function rewriteGlb(bytes,mutate) {
  const end=20+bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,end));mutate(doc);
  const json=Buffer.from(JSON.stringify(doc)),padded=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
  const header=Buffer.from(bytes.subarray(0,20));header.writeUInt32LE(20+padded.length+bytes.length-end,8);header.writeUInt32LE(padded.length,12);
  return Buffer.concat([header,padded,bytes.subarray(end)]);
}
test('vehicle local UV/selective-normal policy rejects changed materials without forcing robot colors',()=>{
  const path=exports[0],bytes=read(path);
  assert.throws(()=>inspectProductionGlb(bytes,'0'.repeat(64)),/helper\/recipe fingerprint/);
  for(const [mutate,pattern]of [
    [d=>d.materials.find(m=>m.name==='edge').normalTexture.texCoord=1,/local UV0/],
    [d=>d.materials.find(m=>m.name==='armor').normalTexture={index:1},/selective-normal policy/],
    [d=>d.meshes[0].primitives[0].attributes.COLOR_0=0,/vertex-color multiplication/],
    [d=>d.images[0].name='../unbounded',/image inventory/],
  ]) {
    const changed=rewriteGlb(bytes,mutate);
    assert.throws(()=>verifyVehicleImports([path],p=>p===path?changed:read(p)),pattern);
  }
});

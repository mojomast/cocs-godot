import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {verifyRobotImports,robotImportPaths} from './robot_imports.mjs';
import {productionResources,inspectProductionGlb,REQUIREMENTS} from './production_resources.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const read=p=>readFileSync(root+p),has=p=>existsSync(root+p),sha=b=>createHash('sha256').update(b).digest('hex');
const receiptPath='tools/godot-package/production_receipts/robots.json';
const receipt=JSON.parse(read(receiptPath)),exports=receipt.exports.map(r=>r.path);
const options={read,has,worldIds:Object.keys(WORLDS),strict:false};

test('nine real robot exports bind nine equal extracted PNGs and eighteen import sidecars',()=>{
  verifyRobotImports(exports,read);
  const result=productionResources(options),paths=robotImportPaths(exports);
  assert.equal(paths.length,27);
  for(const p of paths)assert.equal((p.endsWith('.import')?result.provenance:result.resources)[p],sha(read(p)));
  assert.equal(receipt.sourceFingerprint,'3e6deae571e2aa3b7fe22725775b11ea37f04ef5f68acedf45df2fa8cea68190');
  for(const row of receipt.exports)assert.deepEqual(inspectProductionGlb(read(row.path),receipt.sourceFingerprint),row.textures);
});

test('actual missing robots, changed extracted textures and sidecars cannot pass promotion',()=>{
  for(const p of [exports[0],...robotImportPaths([exports[0]])]) {
    const missing={...options,has:path=>path!==p&&has(path)};
    assert.ok(productionResources(missing).pending.includes('robots'));
    assert.throws(()=>productionResources({...missing,strict:true}),/remain pending/);
    assert.throws(()=>productionResources({...options,read:path=>path===p?Buffer.from('tampered'):read(path)}),/content hash mismatch/);
  }
});

test('refreshed outer hashes cannot bless wrong extracted image bytes or import policy',()=>{
  const [sidecar,png]=robotImportPaths([exports[0]]);
  for(const [p,bytes,pattern]of [
    [png,Buffer.from('changed PNG'),/extracted texture differs/],
    [sidecar,Buffer.from(read(sidecar).toString().replace('gltf/embedded_image_handling=1','gltf/embedded_image_handling=0')),/extracted-image policy/],
    [sidecar,Buffer.from(read(sidecar).toString().replace('meshes/ensure_tangents=true','meshes/ensure_tangents=false')),/tangent import policy/],
    [png+'.import',Buffer.from(read(png+'.import').toString().replace('source_file="res://','source_file="res://wrong/')),/import source identity/],
  ]) {
    const r=structuredClone(receipt);r.packageInputs[p]=sha(bytes);
    const rb=Buffer.from(JSON.stringify(r)),req=JSON.parse(read(REQUIREMENTS));req.units.robots.promotion.sha256=sha(rb);
    assert.throws(()=>productionResources({...options,read:path=>path===p?bytes:path===receiptPath?rb:path===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(path)}),pattern);
  }
});

test('actual robot mesh fingerprints and authored vertex colors reject stale/white replacements',()=>{
  const bytes=read(exports[0]);
  assert.throws(()=>inspectProductionGlb(bytes,'0'.repeat(64)),/helper\/recipe fingerprint/);
  const changed=Buffer.from(bytes),length=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+length));
  const a=doc.accessors[doc.meshes[0].primitives[0].attributes.COLOR_0],v=doc.bufferViews[a.bufferView];
  const start=28+length+(v.byteOffset??0)+(a.byteOffset??0);
  for(let i=0;i<a.count;i++)for(let c=0;c<4;c++)changed.writeUInt16LE(65535,start+i*(v.byteStride??8)+c*2);
  assert.throws(()=>verifyRobotImports([exports[0]],p=>p===exports[0]?changed:read(p)),/white placeholder/);
});

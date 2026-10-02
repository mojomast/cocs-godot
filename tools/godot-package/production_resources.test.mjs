import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {productionResources,inspectProductionGlb,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const sha=b=>createHash('sha256').update(b).digest('hex');
const disk=p=>readFileSync(join(root,p)),exists=p=>existsSync(join(root,p));
const worldIds=['helix-conservatory','gravemill-foundry'];

test('real queue remains required and pending; no optional world is silently promoted',()=>{
  const result=productionResources({read:disk,has:exists,worldIds,strict:false});
  assert.deepEqual([...result.pending].sort(),[...REQUIRED_UNITS].sort());
  assert.equal(result.units.robots.expected.exports.length,9);
  assert.equal(result.units.vehicles.expected.masters.length,9);
  assert.equal(result.units.scenery.expected.exports.length,24);
  assert.ok(Object.hasOwn(result.resources,'godot/multiplayer_worlds/dressing/surface.gdshader'));
  assert.ok(!Object.keys(result.resources).some(p=>p.endsWith('.glb')));
  assert.throws(()=>productionResources({read:disk,has:exists,worldIds}),/remain pending/);
  for(const mutate of [r=>delete r.units.robots,r=>r.units.scenery.required=false]) {
    const r=JSON.parse(disk(REQUIREMENTS));mutate(r);
    assert.throws(()=>productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(r)):disk(p),has:exists,strict:false}),/production unit/);
  }
  const plan=JSON.parse(disk('port/finish/ASSET_PRODUCTION.json'));plan.units.find(u=>u.id==='vehicles').recipePaths.pop();
  assert.throws(()=>productionResources({read:p=>p==='port/finish/ASSET_PRODUCTION.json'?Buffer.from(JSON.stringify(plan)):disk(p),has:exists,strict:false}),/builder\/recipe dropped/);
});

// Synthetic binary/metadata fixture uses a real committed PNG. It proves closure
// refusal rules, not a vehicle export, Blender master, or native acceptance.
function fixtureGlb(fingerprint) {
  const image=disk('godot/moth/generated/textures/brushed_metal.png');
  const doc={asset:{version:'2.0'},buffers:[{byteLength:image.length}],bufferViews:[{byteOffset:0,byteLength:image.length}],images:[{name:'fixture',bufferView:0,mimeType:'image/png'}],nodes:[{mesh:0,extras:{asset_source_fingerprint:fingerprint}}],meshes:[{primitives:[]}]};
  const json=Buffer.from(JSON.stringify(doc)),pad=Buffer.alloc((4-json.length%4)%4,32),bin=Buffer.concat([image,Buffer.alloc((4-image.length%4)%4)]);
  const header=Buffer.alloc(20);header.write('glTF');header.writeUInt32LE(2,4);header.writeUInt32LE(28+json.length+pad.length+bin.length,8);header.writeUInt32LE(json.length+pad.length,12);header.writeUInt32LE(0x4e4f534a,16);
  const bh=Buffer.alloc(8);bh.writeUInt32LE(bin.length);bh.writeUInt32LE(0x004e4942,4);
  return Buffer.concat([header,json,pad,bh,bin]);
}
function vehicleFixture() {
  const files=new Map(),read=p=>files.has(p)?files.get(p):disk(p),has=p=>files.has(p)||exists(p);
  const req=JSON.parse(disk(REQUIREMENTS)),plan=JSON.parse(disk(req.plan));
  const unit=plan.units.find(u=>u.id==='vehicles');
  const sourceHashes=Object.fromEntries([...unit.recipePaths,plan.common.finishScript].sort().map(p=>[p,sha(read(p))]));
  const sourceFingerprint=sha(JSON.stringify(sourceHashes));
  const spec=productionResources({read,has,strict:false}).units.vehicles.expected;
  for(const kind of ['puma','titan','scout'])for(let lod=0;lod<3;lod++) {
    const stem=`${kind}-lod${lod}`,recipe=Buffer.from(JSON.stringify({kind,lod,fixture:true}));
    files.set(`tools/godot-vehicle-assets/generated/${stem}.json`,recipe);
    files.set(`tools/godot-vehicle-assets/masters/${stem}-report.json`,Buffer.from(JSON.stringify({kind,lod,recipe_sha256:sha(recipe)})));
  }
  for(const p of spec.masters)files.set(p,Buffer.from('integrity fixture, not an actual master'));
  for(const p of spec.exports)files.set(p,fixtureGlb(sourceFingerprint));
  const receipt={unit:'vehicles',sourceHashes,sourceFingerprint,packageInputs:Object.fromEntries(spec.packageInputs.map(p=>[p,sha(read(p))])),masters:spec.masters.map(path=>({path,sha256:sha(read(path))})),exports:spec.exports.map(path=>({path,sha256:sha(read(path)),textures:inspectProductionGlb(read(path),sourceFingerprint)})),runtimeHooks:{'godot/vehicle_assets/attachment.gd':sha(read('godot/vehicle_assets/attachment.gd'))},rawFiles:[spec.exports[0]]};
  const refresh=()=>{const path='tools/godot-package/production_receipts/vehicles.json',bytes=Buffer.from(JSON.stringify(receipt));files.set(path,bytes);req.units.vehicles.promotion={receipt:path,sha256:sha(bytes)};files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req)));};
  refresh();return {files,read,has,receipt,refresh,spec};
}
test('promoted identity enumerates exact masters/exports and raw bytes; stale helper/recipe/declared hashes fail',()=>{
  const f=vehicleFixture(),check=()=>productionResources({...f,strict:false});
  const result=check();assert.ok(!result.pending.includes('vehicles'));
  assert.equal(result.raw[f.spec.exports[0]],sha(f.read(f.spec.exports[0])));
  for(const helper of ['tools/asset-production/moth_finish.py','tools/godot-vehicle-assets/write-recipes.mjs']) {
    f.files.set(helper,Buffer.from('changed helper'));assert.throws(check,/content hash mismatch/);f.files.delete(helper);
  }
  const recipe='tools/godot-vehicle-assets/generated/puma-lod0.json';const original=f.files.get(recipe);f.files.set(recipe,Buffer.from('{}'));
  assert.throws(check,/content hash mismatch/);f.files.set(recipe,original);
  f.receipt.exports[0].sha256='0'.repeat(64);f.refresh();assert.throws(check,/content hash mismatch/);
});
test('refreshed receipts cannot omit an export, invent texture hashes, or bless stale GLB fingerprints',()=>{
  let f=vehicleFixture();f.receipt.exports.pop();f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/Missing required vehicles exports/);
  f=vehicleFixture();f.receipt.exports[0].textures[0].sha256='0'.repeat(64);f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/embedded texture/);
  f=vehicleFixture();const path=f.spec.exports[0];f.files.set(path,fixtureGlb('0'.repeat(64)));f.receipt.exports[0].sha256=sha(f.read(path));f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/helper\/recipe fingerprint/);
  f=vehicleFixture();f.receipt.rawFiles.push('godot/unreviewed.glb');f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/Undeclared production raw/);
});

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {productionResources,inspectProductionGlb,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const sha=b=>createHash('sha256').update(b).digest('hex');
const disk=p=>readFileSync(join(root,p)),exists=p=>existsSync(join(root,p));
const worldIds=['helix-conservatory','gravemill-foundry'];

test('all seven units remain required; a promotion without registry membership stays pending',()=>{
  const unpromoted=JSON.parse(disk(REQUIREMENTS));unpromoted.units.robots.promotion=null;
  unpromoted.units.vehicles.promotion=null;
  unpromoted.units.scenery.promotion=null;
  unpromoted.units['vesper-viaduct'].promotion=null;
  unpromoted.units['abyssal-pressureworks'].promotion=null;
  const read=p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):disk(p);
  const result=productionResources({read,has:exists,worldIds,strict:false});
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

test('six real promotions bind actual production bytes; one unit remains pending',()=>{
  const options={read:disk,has:exists,worldIds:Object.keys(WORLDS),strict:false};
  const result=productionResources(options);
  assert.equal(Object.keys(WORLDS).length,12);
  assert.deepEqual(result.pending,['stormglass-causeway']);
  const glb='godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb';
  assert.equal(result.raw[glb],'c1dffd357545206d3f70870f850e441c5be148e652830a4a69835185a75610bd');
  assert.ok(!Object.hasOwn(result.resources,glb+'.import'));
  assert.ok(Object.hasOwn(result.provenance,glb+'.import'));
  for(const path of [glb,'godot/multiplayer_worlds/dressing/profiles/parallax-observatory.json'])
    assert.throws(()=>productionResources({...options,read:p=>p===path?Buffer.from('tampered'):disk(p)}),/content hash mismatch/);
  const receiptPath='tools/godot-package/production_receipts/parallax-interiors.json';
  const receipt=JSON.parse(disk(receiptPath));receipt.rawFiles=[];
  const bytes=Buffer.from(JSON.stringify(receipt)),req=JSON.parse(disk(REQUIREMENTS));
  req.units['parallax-interiors'].promotion.sha256=sha(bytes);
  assert.throws(()=>productionResources({...options,read:p=>p===receiptPath?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(req)):disk(p)}),/requires raw GLB/);
  assert.throws(()=>productionResources({...options,strict:true}),/remain pending/);
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
  const req=JSON.parse(disk(REQUIREMENTS));
  const spec=productionResources({read,has,strict:false}).units.vehicles.expected;
  const receipt=JSON.parse(disk('tools/godot-package/production_receipts/vehicles.json'));
  receipt.rawFiles=[spec.exports[0]]; // Synthetic raw-reader scenario on real assets.
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
  const recipe='tools/godot-vehicle-assets/generated/puma-lod0.json';const original=f.read(recipe);f.files.set(recipe,Buffer.from('{}'));
  assert.throws(check,/content hash mismatch/);f.files.set(recipe,original);
  f.receipt.exports[0].sha256='0'.repeat(64);f.refresh();assert.throws(check,/content hash mismatch/);
});
test('refreshed receipts cannot omit an export, invent texture hashes, or bless stale GLB fingerprints',()=>{
  let f=vehicleFixture();f.receipt.exports.pop();f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/Missing required vehicles exports/);
  f=vehicleFixture();f.receipt.exports[0].textures[0].sha256='0'.repeat(64);f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/embedded texture/);
  f=vehicleFixture();const path=f.spec.exports[0];f.files.set(path,fixtureGlb('0'.repeat(64)));f.receipt.exports[0].sha256=sha(f.read(path));f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/helper\/recipe fingerprint/);
  f=vehicleFixture();f.receipt.rawFiles.push('godot/unreviewed.glb');f.refresh();assert.throws(()=>productionResources({...f,strict:false}),/Undeclared production raw/);
});

// Synthetic in-memory receipt/GLB integrity fixtures, never produced art.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {inventory,inputSnapshot,convert,hash} from './package-receipt.mjs';
import {inspectProductionGlb} from '../godot-package/production_resources.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const plan=JSON.parse(readFileSync(resolve(root,'port/finish/ASSET_PRODUCTION.json')));
const audit=inventory(root),unit='vesper-viaduct',expected=audit[unit].expected;
function fixture(){
 const memory=new Map();
 const read=p=>memory.has(p)?memory.get(p):readFileSync(resolve(root,p));
 const entry=plan.units.find(u=>u.id===unit);
 const sourceHashes=Object.fromEntries([...entry.recipePaths,plan.common.finishScript].sort().map(p=>[p,hash(read(p))]));
 const sourceFingerprint=hash(JSON.stringify(sourceHashes));
 const png=read('godot/moth/generated/textures/sand.png');
 const bin=Buffer.concat([png,Buffer.alloc((4-png.length%4)%4)]);
 const doc={asset:{version:'2.0'},buffers:[{byteLength:bin.length}],bufferViews:[{byteOffset:0,byteLength:png.length}],images:[{name:'synthetic-integrity-fixture',bufferView:0}],nodes:[{mesh:0,extras:{asset_source_fingerprint:sourceFingerprint}}]};
 const json=Buffer.from(JSON.stringify(doc));const padded=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);
 const bytes=Buffer.alloc(28+padded.length+bin.length);
 bytes.write('glTF');bytes.writeUInt32LE(2,4);bytes.writeUInt32LE(bytes.length,8);bytes.writeUInt32LE(padded.length,12);bytes.writeUInt32LE(0x4e4f534a,16);padded.copy(bytes,20);
 bytes.writeUInt32LE(bin.length,20+padded.length);bytes.writeUInt32LE(0x004e4942,24+padded.length);bin.copy(bytes,28+padded.length);
 memory.set(expected.masters[0],Buffer.from('SYNTHETIC MASTER — NOT BLENDER'));
 memory.set(expected.exports[0],bytes);
 const receipt={unit,sourceHashes,sourceFingerprint,packageInputHashes:inputSnapshot(expected,read),masters:expected.masters.map(path=>({path,sha256:hash(read(path))})),exports:expected.exports.map(path=>({path,sha256:hash(read(path)),textures:inspectProductionGlb(read(path),sourceFingerprint)}))};
 return {unit,plan,expected,receipt,read,hooks:['godot/multiplayer_worlds/map.gd'],memory};
}
test('conversion uses the package audit exact inventories and preserves embedded image hashes',()=>{
 const f=fixture(),r=convert(f);
 assert.deepEqual(Object.keys(r.packageInputs).sort(),expected.packageInputs);
 assert.deepEqual(r.exports,f.receipt.exports);assert.deepEqual(r.rawFiles,[]);
 assert.deepEqual(r.runtimeHooks,{'godot/multiplayer_worlds/map.gd':hash(f.read('godot/multiplayer_worlds/map.gd'))});
 assert.equal(r.accepted,false);
});
test('missing masters/exports fail independently of current production promotion',()=>{
 for(const path of [...expected.masters,...expected.exports]){
  const f=fixture(),read=f.read;
  f.read=p=>{if(p===path)throw Object.assign(new Error('ENOENT: '+p),{code:'ENOENT'});return read(p);};
  assert.throws(()=>convert(f),/ENOENT/);
 }
});
test('stale builder, auxiliary package inputs, master, GLB and embedded image identities are rejected',()=>{
 for(const mutate of [
  f=>{f.receipt.sourceFingerprint='0'.repeat(64);},
  f=>{delete f.receipt.packageInputHashes[expected.packageInputs[0]];},
  f=>{f.memory.set(expected.packageInputs[0],Buffer.from('changed input'));},
  f=>{f.memory.set(expected.masters[0],Buffer.from('changed master'));},
  f=>{f.receipt.exports[0].sha256='0'.repeat(64);},
  f=>{f.receipt.exports[0].textures[0].sha256='0'.repeat(64);},
  f=>{f.receipt.exports.push(f.receipt.exports[0]);},
 ]){const f=fixture();mutate(f);assert.throws(()=>convert(f));}
 const f=fixture(),bytes=f.memory.get(expected.exports[0]);
 // Even an updated outer GLB hash cannot bless a stale embedded fingerprint.
 const needle=Buffer.from(f.receipt.sourceFingerprint),offset=bytes.indexOf(needle);assert.ok(offset>=0);
 Buffer.from('0'.repeat(64)).copy(bytes,offset);f.receipt.exports[0].sha256=hash(bytes);
 assert.throws(()=>convert(f),/Stale production helper/);
});
test('runtime hooks must be explicit existing production paths; no tests, escapes or duplicates',()=>{
 for(const hooks of [[],['godot/tests/asset_production/hosted.gd'],['godot/../game/core.mjs'],['godot/missing.gd'],['godot/multiplayer_worlds/map.gd','godot/multiplayer_worlds/map.gd']])assert.throws(()=>convert({...fixture(),hooks}));
 const f=fixture();f.receipt.rawFiles=['godot/unreviewed.glb'];assert.throws(()=>convert(f),/no raw/);
});
test('actual CLI refuses a missing robot receipt without changing fixed package receipt',()=>{
 const output=resolve(root,'tools/godot-package/production_receipts/robots.json'),before=existsSync(output)?readFileSync(output):null;
 const result=spawnSync(process.execPath,['tools/asset-production/package-receipt.mjs','robots','/tmp/opencode/nonexistent-asset-receipt.json','--runtime-hook=godot/robot_assets/switchyard/skin_adapter.gd'],{cwd:root,encoding:'utf8',timeout:10000});
  assert.equal(result.status,1);assert.match(result.stderr,/ENOENT.*nonexistent-asset-receipt\.json|Real production inputs\/masters\/exports required/);
 assert.deepEqual(existsSync(output)?readFileSync(output):null,before);
});

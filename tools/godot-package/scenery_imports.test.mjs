import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {sceneryImportPaths,verifySceneryImports} from './scenery_imports.mjs';
import {productionResources} from './production_resources.mjs';
const read=p=>readFileSync(p),receipt=JSON.parse(read('tools/godot-package/production_receipts/scenery.json'));
const exports=receipt.exports.map(r=>r.path),paths=sceneryImportPaths(exports,read);
test('F exact 118 embedded/extracted images and 142 lossless import sidecars',()=>{
 assert.equal(paths.length,260);verifySceneryImports(exports,read);
 const result=productionResources({read,has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false});
 assert.equal(result.units.scenery.expected.packageInputs.length,913);
 assert.deepEqual(result.pending,['stormglass-causeway']);
 for(const p of paths)assert.ok(Object.hasOwn(p.endsWith('.import')?result.provenance:result.resources,p));
 assert.throws(()=>productionResources({read,has:existsSync,worldIds:['parallax-observatory']}),/Required final production units remain pending/);
});
test('missing PNG or either import sidecar refuses scenery admission',()=>{
 for(const path of [paths.find(p=>p.endsWith('.png')),paths.find(p=>p.endsWith('.png.import')),paths.find(p=>p.endsWith('.glb.import'))]) {
  const result=productionResources({read,has:p=>p!==path&&existsSync(p),worldIds:['parallax-observatory'],strict:false});
  assert.ok(result.pending.includes('scenery'));assert.ok(result.units.scenery.missing.includes(path));
 }
});
test('wrong image hashes and changed lossless/normal/source policies fail against immutable F proof',()=>{
 const png=paths.find(p=>p.endsWith('.png'));
 for(const [path,from,to]of [[png,null,null],[exports[0]+'.import','force_disable_compression=true','force_disable_compression=false'],[png+'.import','compress/mode=0','compress/mode=2'],[png+'.import','normal_map_invert_y=false','normal_map_invert_y=true'],[png+'.import','source_file="res://','source_file="res://wrong/']]) {
  const original=read(path),bytes=from?Buffer.from(original.toString().replace(from,to)):Buffer.from(original);
  if(!from)bytes[bytes.length-1]^=1;
  assert.throws(()=>verifySceneryImports(exports,p=>p===path?bytes:read(p)),/Scenery received (hash|byte size)/);
 }
});
test('supporting reconciliation preserves all original production and native fields',()=>{
 for(const id of ['scenery','robots','vehicles','parallax-interiors']) {
  const path=`tools/godot-package/production_receipts/${id}.json`,old=JSON.parse(execFileSync('git',['show',`27f3afc3:${path}`])),now=JSON.parse(read(path));
  for(const [key,value]of Object.entries(old))if(key!=='packageInputs'&&key!=='runtimeHooks')assert.deepEqual(now[key],value,key);
  for(const [p,sha]of Object.entries(old.runtimeHooks))assert.equal(now.dressingAdvance?.runtimeChanged?.[p]?.before??now.vesperPackageVerifierAdvance.runtimeChanged[p]?.before??now.abyssalPackageVerifierAdvance.runtimeChanged[p]?.before??now.featureAdvance.runtimeChanged[p]?.before??now.stormglassPackageVerifierAdvance.runtimeChanged[p]?.before??now.runtimeHooks[p],sha);
  assert.equal(now.sceneryPackageVerifierAdvance.previousReceipt.commit,'27f3afc3');
 }
});

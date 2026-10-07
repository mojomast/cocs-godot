import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {VESPER_GLB,VESPER_INVENTORY,vesperImportPaths,verifyVesperImports} from './vesper_imports.mjs';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const options={read,has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false};
test('H exact 16 PNGs and 17 import sidecars retain promotion; omitted Stormglass registration blocks strict inventory',()=>{
 const paths=vesperImportPaths();assert.equal(paths.length,33);assert.equal(paths.filter(p=>p.endsWith('.png')).length,16);
 verifyVesperImports(read);
 const result=productionResources(options);assert.deepEqual(result.pending,['stormglass-causeway']);
 assert.equal(result.units['vesper-viaduct'].expected.packageInputs.length,680);
 for(const p of paths)assert.ok(Object.hasOwn(p.endsWith('.import')?result.provenance:result.resources,p));
 assert.throws(()=>productionResources({...options,strict:true}),/Required final production units remain pending/);
});
test('H inventory is exactly received committed bytes; no generated replacement evidence',()=>{
 const inventory=JSON.parse(read(VESPER_INVENTORY));
 const apron=JSON.parse(read('tools/godot-package/production_receipts/vesper-viaduct.json')).vesperApronAdvance;
 for(const row of inventory.files){
  // The apron revision re-derives the runtime GLB; its artifact advance owns the
  // before/after, so that one row is exempt from the received-bytes identity.
  if(apron.exportsChanged?.[row.path])continue;
  const bytes=execFileSync('git',['show',`99a4f597:${row.path}`],{maxBuffer:8000000});assert.equal(hash(bytes),row.sha256);assert.equal(bytes.length,row.bytes);
 }
});
test('missing image, scene sidecar, texture sidecar blocks promotion',()=>{
 for(const path of [VESPER_GLB+'.import',...vesperImportPaths().filter(p=>p.includes('MothLocal_iron'))]) {
  const result=productionResources({...options,has:p=>p!==path&&existsSync(p)});
  assert.ok(result.pending.includes('vesper-viaduct'));assert.ok(result.units['vesper-viaduct'].missing.includes(path));
 }
});
test('forged PNG, embedded image and altered import policies are refused',()=>{
 const png=vesperImportPaths().find(p=>p.endsWith('.png'));
 for(const [path,from,to]of [[png,null,null],[VESPER_GLB,null,null],[VESPER_GLB+'.import','force_disable_compression=false','force_disable_compression=true'],[png+'.import','compress/mode=0','compress/mode=2'],[png+'.import','normal_map_invert_y=false','normal_map_invert_y=true']]) {
  const bytes=from?Buffer.from(read(path).toString().replace(from,to)):Buffer.from(read(path));if(!from)bytes[bytes.length-1]^=1;
  assert.throws(()=>verifyVesperImports(p=>p===path?bytes:read(p)),/H (content hash|byte size)/);
 }
});
test('Parallax supporting runtime exception is exact and cannot bless arbitrary hooks',()=>{
 const path='tools/godot-package/production_receipts/parallax-interiors.json',r=JSON.parse(read(path)),req=JSON.parse(read(REQUIREMENTS));
 r.vesperPackageVerifierAdvance.runtimeChanged['godot/multiplayer_worlds/demo.gd'].before='0'.repeat(64);
 const bytes=Buffer.from(JSON.stringify(r));req.units['parallax-interiors'].promotion.sha256=hash(bytes);
 assert.throws(()=>productionResources({...options,read:p=>p===path?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(p)}),/Unreviewed supporting runtime advance/);
});

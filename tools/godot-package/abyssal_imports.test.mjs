import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {ABYSSAL_GLB,ABYSSAL_INVENTORY,abyssalImportPaths,verifyAbyssalImports} from './abyssal_imports.mjs';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const options={read,has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false};
test('I exact five images and six sidecars admit sixth unit; strict final rejects Stormglass',()=>{
 const paths=abyssalImportPaths();assert.equal(paths.length,11);assert.equal(paths.filter(p=>p.endsWith('.png')).length,5);
 verifyAbyssalImports(read);
 const result=productionResources(options);assert.deepEqual(result.pending,['stormglass-causeway']);
 assert.equal(result.units['abyssal-pressureworks'].expected.packageInputs.length,370);
 for(const p of paths)assert.ok(Object.hasOwn(p.endsWith('.import')?result.provenance:result.resources,p));
 assert.throws(()=>productionResources({...options,strict:true}),/Required final production units remain pending/);
});
test('all I inventory bytes are exactly the received foundation, not rebuilt evidence',()=>{
 for(const row of JSON.parse(read(ABYSSAL_INVENTORY)).files){const b=execFileSync('git',['show',`f0e76bf7:${row.path}`],{maxBuffer:8000000});assert.equal(hash(b),row.sha256);assert.equal(b.length,row.bytes);}
});
test('missing PNG and both sidecar types block admission',()=>{
 for(const path of [ABYSSAL_GLB+'.import',...abyssalImportPaths().filter(p=>p.includes('MothLocal_navy'))]){
  const result=productionResources({...options,has:p=>p!==path&&existsSync(p)});
  assert.ok(result.pending.includes('abyssal-pressureworks'));assert.ok(result.units['abyssal-pressureworks'].missing.includes(path));
 }
});
test('wrong image bytes and changed compression/normal/source import policies fail',()=>{
 const png=abyssalImportPaths().find(p=>p.endsWith('.png'));
 for(const [path,from,to]of [[png,null,null],[ABYSSAL_GLB,null,null],[ABYSSAL_GLB+'.import','force_disable_compression=false','force_disable_compression=true'],[png+'.import','compress/mode=0','compress/mode=2'],[png+'.import','normal_map_invert_y=false','normal_map_invert_y=true'],[png+'.import','source_file="res://','source_file="res://wrong/']]){
  const b=from?Buffer.from(read(path).toString().replace(from,to)):Buffer.from(read(path));if(!from)b[b.length-1]^=1;
  assert.throws(()=>verifyAbyssalImports(p=>p===path?b:read(p)),/I (content hash|byte size)/);
 }
});
function forgedReceipt(id,mutate){
 const path=`tools/godot-package/production_receipts/${id}.json`,r=JSON.parse(read(path)),req=JSON.parse(read(REQUIREMENTS));mutate(r);
 const bytes=Buffer.from(JSON.stringify(r));req.units[id].promotion.sha256=hash(bytes);
 return ()=>productionResources({...options,read:p=>p===path?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(p)});
}
test('malformed receipt cannot omit imports, invent embedded identity or remove export',()=>{
 assert.throws(forgedReceipt('abyssal-pressureworks',r=>delete r.packageInputs[ABYSSAL_GLB+'.import']),/Incomplete production packageInputs/);
 assert.throws(forgedReceipt('abyssal-pressureworks',r=>r.exports[0].textures.pop()),/Stale declared embedded texture/);
 assert.throws(forgedReceipt('abyssal-pressureworks',r=>r.exports=[]),/Missing required/);
});
test('Parallax native-to-Vesper-to-Abyssal chain cannot skip or rewrite historical advance',()=>{
 assert.throws(forgedReceipt('parallax-interiors',r=>delete r.vesperPackageVerifierAdvance.runtimeChanged['godot/multiplayer_worlds/demo.gd']),/Broken Parallax native-to-supporting history/);
 assert.throws(forgedReceipt('parallax-interiors',r=>r.abyssalPackageVerifierAdvance.runtimeChanged['godot/multiplayer_worlds/demo.gd'].before='0'.repeat(64)),/Unreviewed supporting runtime advance/);
 assert.throws(forgedReceipt('parallax-interiors',r=>delete r.abyssalPackageVerifierAdvance.runtimeChanged['godot/multiplayer_worlds/map.gd']));
});

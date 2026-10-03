import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {POLISH_INVENTORY,polishInventory,verifyOperatorFinishImports} from './polish_dependencies.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const options={read,has:existsSync,worldIds:Object.keys(WORLDS),strict:true};
const s=polishInventory(read),git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
function forged(id,mutate){
 const path=`tools/godot-package/production_receipts/${id}.json`,r=JSON.parse(read(path)),req=JSON.parse(read(REQUIREMENTS));mutate(r);const bytes=Buffer.from(JSON.stringify(r));req.units[id].promotion.sha256=hash(bytes);
 return ()=>productionResources({...options,read:p=>p===path?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(p)});
}
test('all seven strict closures bind exact 8921 snapshot, opaque shader, identity composition and scene compiler',()=>{
 assert.deepEqual(productionResources(options).pending,[]);
 assert.equal(Object.keys(s.changed).length,22);
 for(const [p,c]of Object.entries(s.changed)){assert.equal(hash(git(s.previous,p)),c.before);assert.equal(hash(git(s.foundation,p)),c.after);assert.equal(hash(read(p)),c.after);}
 for(const [p,sha]of Object.entries(s.added))assert.equal(hash(git(s.foundation,p)),sha);
 for(const id of REQUIRED_UNITS){const r=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));for(const p of ['godot/moth/surface_opaque.gdshader','godot/native_arenas/identity_environment.gd','tools/godot-multiplayer/generate-scenes.mjs'])assert.ok(r.packageInputs[p]);}
});
test('all previous producer/native fields and histories are byte-identical in value; only one declared hook advances',()=>{
 for(const id of REQUIRED_UNITS){
  const path=`tools/godot-package/production_receipts/${id}.json`,oldBytes=git(s.foundation,path),old=JSON.parse(oldBytes),now=JSON.parse(read(path));
  for(const [key,value]of Object.entries(old))if(!['packageInputs','runtimeHooks'].includes(key))assert.deepEqual(now[key],value,id+': '+key);
  assert.equal(now.polishAdvance.previousReceipt.sha256,hash(oldBytes));
  for(const [p,sha]of Object.entries(old.runtimeHooks))assert.equal(now.polishAdvance.runtimeChanged[p]?.before??now.runtimeHooks[p],sha);
  assert.equal(now.polishAdvance.review.combinedNativeChecks,'pending');assert.equal(now.polishAdvance.review.liveKickAcceptance,'not accepted');
 }
 assert.equal(execFileSync('git',['diff','5b5c8791','8921ed41','--','game/','server/','port/multiplayer-worlds/derived/','port/multiplayer-worlds/wall_candidates.mjs','*.glb','*.blend','*.png'],{encoding:'utf8'}),'');
});
test('116 actual K PNG/sidecar pairs retain observed lossless/normal policy and binder evidence without invented imports',()=>{
 verifyOperatorFinishImports(read);
 const entries=Object.entries(s.operatorFinish.imports);assert.equal(entries.length,116);
 const archived=JSON.parse(read('port/finish/polish/package-evidence-k/generated-sidecars-final/manifest.json'));
 const policy=JSON.parse(read('port/finish/polish/package-evidence-k/moth-import-policy.json'));
 assert.deepEqual(policy.map(r=>r.path).sort(),entries.map(([p])=>p).sort());
 for(const [p,r]of entries){assert.equal(hash(git(s.foundation,p)),r.sha256);assert.ok(archived.includes(r.sidecar));}
 for(const [p,sha]of Object.entries(s.evidence))assert.equal(hash(read(p)),sha);
 assert.match(read('port/finish/polish/package-evidence-k/k-finish-binder/operator-finish/native.log').toString(),/OPERATOR_FINISH_LIFECYCLE_OK all nine/);
});
test('missing PNG/sidecar/new shader fails strict closure; changed enum or PNG bytes cannot be blessed',()=>{
 const [png,row]=Object.entries(s.operatorFinish.imports)[0];
 for(const p of [png,row.sidecar,'godot/moth/surface_opaque.gdshader'])assert.throws(()=>productionResources({...options,has:x=>x!==p&&existsSync(x)}),/remain pending/);
 assert.throws(()=>verifyOperatorFinishImports(p=>p===row.sidecar?Buffer.from(read(p).toString().replace('compress/normal_map=0','compress/normal_map=1')):read(p)),/Released K sidecar identity/);
 assert.throws(()=>verifyOperatorFinishImports(p=>p===png?Buffer.from('forged'):read(p)),/Operator finish PNG identity/);
});
test('forged or skipped polish history, stale hooks, later source and invented acceptance fail closed',()=>{
 assert.throws(forged('robots',r=>r.polishAdvance.reviewedSource.changed['godot/source_operators/locomotion.gd'].before='0'.repeat(64)),/Exact reviewed polish source history/);
 assert.throws(forged('stormglass-causeway',r=>delete r.polishAdvance.runtimeChanged['godot/multiplayer_worlds/sports_demo.gd']),/Exact polish activation hook advance/);
 assert.throws(forged('stormglass-causeway',r=>r.runtimeHooks['godot/multiplayer_worlds/sports_demo.gd']=s.changed['godot/multiplayer_worlds/sports_demo.gd'].before),/Polish current runtime identity/);
 assert.throws(forged('scenery',r=>r.polishAdvance.review.combinedNativeChecks='passed'),/Polish review boundary/);
 assert.throws(()=>productionResources({...options,read:p=>p===POLISH_INVENTORY?Buffer.concat([read(p),Buffer.from(' ')]):read(p)}),/Exact 8921ed41 snapshot identity/);
 const p='godot/world/combat_feedback.gd';assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n# L future')]):read(x)}),/content hash mismatch/);
});

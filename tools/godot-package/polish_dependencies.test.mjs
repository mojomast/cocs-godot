import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {POLISH_INVENTORY,polishInventory,verifyOperatorFinishImports,L_SOURCE_CHANGE,L_EVIDENCE,lSupportingHash,O_SOURCE_CHANGE,O_EVIDENCE} from './polish_dependencies.mjs';
import {movementSupportingHash} from './movement_dependencies.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const options={read,has:existsSync,worldIds:Object.keys(WORLDS),strict:true};
const s=polishInventory(read),git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
function forged(id,mutate){
 const path=`tools/godot-package/production_receipts/${id}.json`,r=JSON.parse(read(path)),req=JSON.parse(read(REQUIREMENTS));mutate(r);const bytes=Buffer.from(JSON.stringify(r));req.units[id].promotion.sha256=hash(bytes);
 return ()=>productionResources({...options,read:p=>p===path?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(p)});
}
test('O preserves every prior producer/native/review field and advances only local Settings plus the verifier',()=>{
 for(const id of REQUIRED_UNITS){
  const p=`tools/godot-package/production_receipts/${id}.json`,bytes=git('b17360c9',p),old=JSON.parse(bytes),now=JSON.parse(read(p));
  for(const [k,v]of Object.entries(old))if(k!=='packageInputs')assert.deepEqual(now[k],v,id+': '+k);
  assert.equal(now.oReviewAdvance.previousReceipt.sha256,hash(bytes));
  assert.deepEqual(now.oReviewAdvance.sourceChanged,O_SOURCE_CHANGE);
  assert.deepEqual(Object.keys(now.oReviewAdvance.changed).sort(),['godot/ui/local_settings.gd','tools/godot-package/polish_dependencies.mjs']);
  assert.deepEqual(Object.keys(now.oReviewAdvance.added).sort(),Object.keys(O_EVIDENCE).sort());
  assert.deepEqual(now.oReviewAdvance.runtimeChanged,{});
 }
 for(const [p,c]of Object.entries(O_SOURCE_CHANGE)){assert.equal(hash(git('9cd1ac72',p)),c.before);assert.equal(hash(git('b17360c9',p)),c.after);assert.equal(hash(read(p)),c.after);}
});
test('O retains three passed final receipts and empty release audits without claiming a new native run',()=>{
 for(const [p,sha]of Object.entries(O_EVIDENCE))assert.equal(hash(read(p)),sha);
 const base='port/finish/acceptance/package-evidence-o/',release=JSON.parse(read(base+'HEAVY_GRANT_RELEASE.json'));
 assert.equal(release.released,true);assert.equal(release.audits.length,3);assert.equal(Object.keys(release.job_cleanup).length,18);
 for(const a of release.audits){assert.deepEqual(a.owned_processes,[]);assert.deepEqual(a.live_engines_encoders,[]);}
 for(const job of Object.values(release.job_cleanup))assert.deepEqual(job.remaining,[]);
 for(const run of ['world-final-01','combined-home-regression-01','controls-final-01']){
  const r=JSON.parse(read(base+run+'/receipt.json'));assert.equal(r.status,'passed');assert.equal(r.exit_code,0);assert.equal(r.grant,'GAMEPLAY-REPAIR-20261003-O');assert.deepEqual(r.cleanup.remaining,[]);
  assert.equal(r.input_identity.sha256,'752f896a7768171785bb416b6aaea4660342d6548afa3b9332fbc0235c296747');
 }
});
test('missing/forged O step, stale Settings, later source and altered final receipts reject',()=>{
 assert.throws(forged('robots',r=>delete r.oReviewAdvance),/Explicit O reconciliation required/);
 assert.throws(forged('scenery',r=>r.oReviewAdvance.sourceChanged['godot/ui/local_settings.gd'].before='0'.repeat(64)),/Exact O source history/);
 assert.throws(forged('vehicles',r=>r.packageInputs['godot/ui/local_settings.gd']=O_SOURCE_CHANGE['godot/ui/local_settings.gd'].before),/Current O dependency identity/);
 assert.throws(forged('stormglass-causeway',r=>r.oReviewAdvance.review.liveKickAcceptance='passed'),/O review boundary/);
 const p='godot/ui/local_settings.gd';assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n# future P')]):read(x)}),/content hash mismatch/);
 const evidence=Object.keys(O_EVIDENCE)[1];assert.throws(()=>productionResources({...options,read:x=>x===evidence?Buffer.from('{}'):read(x)}),/Exact retained O evidence/);
});
test('all seven strict closures bind exact 8921 snapshot, opaque shader, identity composition and scene compiler',()=>{
 assert.deepEqual(productionResources(options).pending,[]);
 assert.equal(Object.keys(s.changed).length,22);
 for(const [p,c]of Object.entries(s.changed)){assert.equal(hash(git(s.previous,p)),c.before);assert.equal(hash(git(s.foundation,p)),c.after);assert.equal(hash(read(p)),movementSupportingHash(p,lSupportingHash(p,c.after),read));}
 for(const [p,sha]of Object.entries(s.added))assert.equal(hash(git(s.foundation,p)),sha);
 for(const id of REQUIRED_UNITS){const r=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));for(const p of ['godot/moth/surface_opaque.gdshader','godot/native_arenas/identity_environment.gd','tools/godot-multiplayer/generate-scenes.mjs'])assert.ok(r.packageInputs[p]);}
});
test('L appends one exact lobby correction while preserving the entire original polish review and all producer fields',()=>{
 for(const id of REQUIRED_UNITS){
  const p=`tools/godot-package/production_receipts/${id}.json`,bytes=git('9cd1ac72',p),old=JSON.parse(bytes),now=JSON.parse(read(p));
  for(const [k,v]of Object.entries(old))if(k!=='packageInputs')assert.deepEqual(now[k],v,id+': '+k);
  assert.equal(now.lReviewAdvance.previousReceipt.sha256,hash(bytes));
  assert.deepEqual(now.lReviewAdvance.sourceChanged,L_SOURCE_CHANGE);
  assert.deepEqual(Object.keys(now.lReviewAdvance.changed).sort(),['godot/ui/lobby_choice.gd','tools/godot-package/polish_dependencies.mjs']);
  assert.deepEqual(Object.keys(now.lReviewAdvance.added).sort(),Object.keys(L_EVIDENCE).sort());
  assert.equal(now.polishAdvance.review.combinedNativeChecks,'pending','Historical review must not be rewritten');
 }
 for(const [p,c]of Object.entries(L_SOURCE_CHANGE)){assert.equal(hash(git('8921ed41',p)),c.before);assert.equal(hash(git('9cd1ac72',p)),c.after);}
});
test('retained L release has three empty audits/49 groups, 30 passed gate IDs and all 116 stable sidecars',()=>{
 for(const [p,sha]of Object.entries(L_EVIDENCE))assert.equal(hash(read(p)),sha);
 const base='port/finish/polish/package-evidence-l/';
 const release=JSON.parse(read(base+'release-L.json'));assert.equal(release.released,true);assert.equal(release.owned_groups.length,49);assert.equal(release.audits.length,3);for(const a of release.audits)assert.deepEqual(a.matches,[]);
 const gates=JSON.parse(read(base+'NATIVE_RESULTS_L.json')).latest_after_gates;assert.equal(Object.keys(gates).length,30);for(const r of Object.values(gates))assert.equal(r.status,'passed');
 const rows=JSON.parse(read(base+'sidecars-post-import.json'));assert.equal(rows.length,116);
 assert.deepEqual(rows.map(r=>r.path).sort(),Object.values(s.operatorFinish.imports).map(r=>r.sidecar).sort());
 for(const r of rows){assert.equal(r.equal,true);assert.equal(hash(read(r.path)),r.sha256);assert.equal(hash(git('9cd1ac72',r.path)),r.sha256);}
});
test('missing/forged L step, stale current dependency, future source and rewritten L evidence reject',()=>{
 assert.throws(forged('robots',r=>delete r.lReviewAdvance),/Explicit L reconciliation required/);
 assert.throws(forged('scenery',r=>r.lReviewAdvance.sourceChanged['godot/ui/lobby_choice.gd'].before='0'.repeat(64)),/Exact L source history/);
 assert.throws(forged('vehicles',r=>r.packageInputs['godot/ui/lobby_choice.gd']=L_SOURCE_CHANGE['godot/ui/lobby_choice.gd'].before),/Current L dependency identity/);
 assert.throws(forged('stormglass-causeway',r=>r.lReviewAdvance.review.liveKickAcceptance='passed'),/L review boundary/);
 const p='godot/ui/lobby_choice.gd';assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n# future')]):read(x)}),/content hash mismatch/);
 const evidence=Object.keys(L_EVIDENCE)[0];assert.throws(()=>productionResources({...options,read:x=>x===evidence?Buffer.from('{}'):read(x)}),/Exact retained L evidence/);
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

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {FEATURE_ROOTS,FEATURE_REVIEW_SCOPE,ROBOT_SHARED_RUNTIME_ADVANCES,legacyFunctionHashes,robotSupportingHash} from './feature_dependencies.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const ids=['parallax-interiors','robots','vehicles','scenery','vesper-viaduct','abyssal-pressureworks'];
const options={read,has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false};
const previous=p=>execFileSync('git',['show',`a5c26f25:${p}`],{maxBuffer:128*1024*1024});
function forged(id,mutate){
 const path=`tools/godot-package/production_receipts/${id}.json`,receipt=JSON.parse(read(path)),req=JSON.parse(read(REQUIREMENTS));mutate(receipt);
 const bytes=Buffer.from(JSON.stringify(receipt));req.units[id].promotion.sha256=hash(bytes);
 return ()=>productionResources({...options,read:p=>p===path?bytes:p===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(p)});
}
test('six closures inventory feature roots; omitting Stormglass registration still blocks strict inventory',()=>{
 const result=productionResources(options);assert.deepEqual(result.pending,['stormglass-causeway']);
 for(const id of ids){
  const paths=result.units[id].expected.packageInputs;
  for(const p of [...FEATURE_ROOTS,'godot/campaign/journal.gd','godot/campaign/journal_model.gd','godot/ui/route_search.gd','godot/fighting/presentation/training_feedback.gd','godot/first_person/kick_motion.gd','godot/first_person/kick_rig.gd','godot/first_person/sprint_fov.gd','godot/sports/chase.gd','godot/source_operators/locomotion.gd'])assert.ok(paths.includes(p),id+': '+p);
 }
 assert.throws(()=>productionResources({...options,strict:true}),/Required final production units remain pending/);
});
test('all original producer/assets/native identities and F/H/I histories are preserved',()=>{
 for(const id of ids){
  const path=`tools/godot-package/production_receipts/${id}.json`,old=JSON.parse(previous(path)),now=JSON.parse(read(path));
  for(const [key,value]of Object.entries(old))if(!['packageInputs','runtimeHooks'].includes(key))assert.deepEqual(now[key],value,id+': '+key);
  assert.equal(now.featureAdvance.previousReceipt.sha256,hash(previous(path)));
  assert.equal(now.featureAdvance.review.scope,FEATURE_REVIEW_SCOPE);
  assert.equal(now.featureAdvance.review.nativeFeatureChecks,'pending');
   for(const [p,sha]of Object.entries(old.runtimeHooks))assert.equal(now.featureAdvance.runtimeChanged[p]?.before??now.stormglassPackageVerifierAdvance.runtimeChanged[p]?.before??now.runtimeHooks[p],sha);
  for(const row of [...now.masters,...now.exports])assert.equal(hash(read(row.path)),row.sha256);
 }
});
test('stale campaign hook, forged old/new hook history and invented native acceptance fail',()=>{
 assert.throws(forged('robots',r=>r.runtimeHooks['godot/campaign/demo.gd']=r.featureAdvance.runtimeChanged['godot/campaign/demo.gd'].before),/Feature runtime current identity/);
 assert.throws(forged('robots',r=>r.featureAdvance.runtimeChanged['godot/campaign/demo.gd'].before='0'.repeat(64)),/Unreviewed feature runtime advance/);
 assert.throws(forged('vehicles',r=>r.featureAdvance.runtimeChanged['godot/combined_arms/demo.gd'].after='0'.repeat(64)),/Unreviewed feature runtime advance/);
 assert.throws(forged('scenery',r=>r.featureAdvance.review.nativeFeatureChecks='passed'));
});
test('new preload omission, missing helper and later feature source drift are rejected',()=>{
 const p='godot/first_person/kick_motion.gd';
 assert.throws(forged('robots',r=>delete r.packageInputs[p]),/Incomplete production packageInputs/);
 const missing=productionResources({...options,has:x=>x!==p&&existsSync(x)});for(const id of ids)assert.ok(missing.units[id].missing.includes(p));
 assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n# future drift')]):read(x)}),/Production content hash mismatch/);
});
test('robot contract stays original; every legacy helper function matches executable source and exact allowed API advance',()=>{
 const receipt=JSON.parse(read('tools/godot-package/production_receipts/robots.json'));
 const contractPath='godot/robot_assets/switchyard/contract.json',contract=JSON.parse(read(contractPath));assert.deepEqual(read(contractPath),previous(contractPath));
 for(const [path,change]of Object.entries(ROBOT_SHARED_RUNTIME_ADVANCES)){
  const old=execFileSync('git',['show',`d5a02632:${path}`]);assert.equal(hash(old),change.before);assert.equal(contract.source[path],change.before);
  assert.deepEqual(legacyFunctionHashes(old.toString()),change.legacyFunctions);
  const now=legacyFunctionHashes(read(path).toString());for(const [name,sha]of Object.entries(change.legacyFunctions))assert.equal(now[name],sha);
  assert.equal(robotSupportingHash(path,contract.source[path],receipt,read),change.after);
 }
 assert.throws(forged('robots',r=>r.featureAdvance.sharedRuntimeChanged['godot/source_operators/motion_math.gd'].before='0'.repeat(64)),/Unreviewed shared runtime advance/);
 assert.throws(forged('robots',r=>delete r.featureAdvance.sharedRuntimeChanged['godot/source_operators/ground_contact.gd']),/Unreviewed shared runtime advance/);
});

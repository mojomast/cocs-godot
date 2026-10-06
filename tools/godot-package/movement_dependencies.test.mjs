import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {movementInventory,verifyMovementPredecessor} from './movement_dependencies.mjs';
import {reverseRacing,racingSupportingHash} from './racing_dependencies.mjs';
import {dressingSupportingHash} from './dressing_dependencies.mjs';
import {vesperApronSupportingHash} from './vesper_apron_dependencies.mjs';
import {consolidationSupportingHash} from './consolidation_dependencies.mjs';
import {RACING_CONTRACT,resolveReviewedDerivative} from './racing_derivative.mjs';
import {MOVEMENT_CONTRACT,resolveSourceDerivative} from './source_derivative.mjs';
import {verifySourceState,rederiveClosure} from './manifest_validation.mjs';
import {verifySource} from '../godot-export/semantic.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const git=(...args)=>execFileSync('git',args,{maxBuffer:128*1024*1024});
const gitRead=(rev,p)=>git('show',`${rev}:${p}`),ancestor=(a,b)=>git('merge-base',a,b).toString().trim()===a;
const s=movementInventory(read),options={read,has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true};
function forged(id,mutate){
 const p=`tools/godot-package/production_receipts/${id}.json`,r=JSON.parse(read(p)),req=JSON.parse(read(REQUIREMENTS));mutate(r);
 const bytes=Buffer.from(JSON.stringify(r));req.units[id].promotion.sha256=hash(bytes);
 return ()=>productionResources({...options,read:x=>x===p?bytes:x===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(x)});
}
test('movement inventories exact ancestor bytes and preserves every O producer/history field for all seven units',()=>{
 const newer=JSON.parse(read('tools/godot-package/production_receipts/stormglass-causeway.json'));
 for(const [p,c]of Object.entries(s.changed)){
  assert.equal(hash(gitRead(s.previous,p)),c.before);assert.equal(hash(gitRead(s.foundation,p)),c.after);assert.equal(hash(read(p)),consolidationSupportingHash(p,vesperApronSupportingHash(p,dressingSupportingHash(p,racingSupportingHash(p,c.after,newer),newer),newer),newer));
 }
 for(const id of REQUIRED_UNITS){
  const p=`tools/godot-package/production_receipts/${id}.json`,old=JSON.parse(gitRead(s.foundation,p)),raw=JSON.parse(read(p)),r=reverseRacing(raw,read);
  for(const [k,v]of Object.entries(old))if(k!=='packageInputs')assert.deepEqual(r[k],v,id+': '+k);
  verifyMovementPredecessor(r,read);
  const racingSet=new Set(Object.keys(raw.racingAdvance.changed));
  for(const p of Object.keys(r.movementAdvance.added))if(!p.startsWith('tools/godot-package/')&&!racingSet.has(p))assert.deepEqual(read(p),gitRead(s.foundation,p));
 }
 assert.deepEqual(productionResources(options).pending,[]);
});
test('every unit rejects missing movement step, forged predecessor, unknown producer field and stale/future runtime',()=>{
 for(const id of REQUIRED_UNITS){
  assert.throws(forged(id,r=>delete r.movementAdvance),/Explicit movement/);
  assert.throws(forged(id,r=>r.movementAdvance.previousReceipt.commit=s.previous),/Exact (movement|racing) predecessor/);
  assert.throws(forged(id,r=>r.unreviewedProducerField=true),/Full pre-movement|Exact racing predecessor/);
  assert.throws(forged(id,r=>r.packageInputs['game/core.mjs']=s.changed['game/core.mjs'].before),/Current movement dependency|Racing (previous|delta)/);
  assert.throws(forged(id,r=>r.movementAdvance.review.nativeChecks='passed'),/Movement review boundary|Exact racing predecessor/);
 }
 for(const p of Object.keys(s.changed))assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n# future')]):read(x)}),/Reviewed movement bytes/);
 assert.throws(forged('robots',r=>r.runtimeHooks['godot/horde/demo.gd']=s.changed['godot/horde/demo.gd'].after),/Original native hook identity|Exact racing predecessor/);
 assert.throws(forged('scenery',r=>r.movementAdvance.changed['game/core.mjs'].before='0'.repeat(64)),/Movement previous fingerprint|Exact racing predecessor/);
});
test('racing advance rejects forged, missing and tampered layers',()=>{
 for(const id of REQUIRED_UNITS){
  assert.throws(forged(id,r=>r.racingAdvance.changed['game/race.mjs'].after='0'.repeat(64)),/Racing delta identity/);
  assert.throws(forged(id,r=>r.racingAdvance.changed['godot/sports/chase.gd'].before='0'.repeat(64)),/Broken pre-racing|Racing/);
  assert.throws(forged(id,r=>{delete r.racingAdvance;}),/Movement addition identity|Exact racing|pre-movement|polish dependency identity|Polish current runtime identity|supporting feature identity/);
 }
});
test('package source preflight resolves the exact movement overlay and generator without old-source substitution',()=>{
 const raw=JSON.parse(read(MOVEMENT_CONTRACT)),resolved=resolveSourceDerivative(raw,read,gitRead,ancestor),lock=JSON.parse(read('port/contracts/source-lock.json'));
 assert.equal(Object.keys(resolved.runtime_files).length,13);
 const racing=JSON.parse(read(RACING_CONTRACT));
 assert.deepEqual(verifySource(lock,racing).runtime_files,resolveReviewedDerivative(racing,read,gitRead,ancestor).runtime_files);
 verifySourceState(process.cwd(),lock.source_commit,raw,{portCommit:s.foundation});
 const closure=rederiveClosure(process.cwd(),{port_commit:s.foundation},raw);
 assert.ok(closure.modules['game/core.mjs'].includes('./operator-verbs.mjs'));
 assert.ok(closure.adapterModules['port/native-campaign/core.generated.mjs'].includes('../../game/operator-verbs.mjs'));
 assert.equal(hash(gitRead(resolved.derivative_commit,'game/core.mjs')),s.changed['game/core.mjs'].after);
 assert.equal(hash(gitRead(s.foundation,'port/native-campaign/core.generated.mjs')),s.changed['port/native-campaign/core.generated.mjs'].after);
 assert.equal(closure.worldDataFiles.length,13);
 git('merge-base','--is-ancestor',raw.derivative_commit,s.foundation);
 execFileSync(process.execPath,['port/native-campaign/generate-core.mjs','--check']);
 assert.throws(()=>verifySourceState(process.cwd(),lock.source_commit,JSON.parse(read(raw.parent_contract)),{portCommit:s.foundation}),/inventory|byte mismatch/);
 const forged=structuredClone(raw);forged.runtime_overrides['game/core.mjs'].after='0'.repeat(64);
 assert.throws(()=>resolveSourceDerivative(forged,read,gitRead,ancestor),/overlay differs/);
 assert.throws(()=>resolveSourceDerivative(raw,read,gitRead,()=>false),/ancestry/);
 assert.throws(()=>resolveSourceDerivative(raw,p=>p===raw.parent_contract?Buffer.from('{}'):read(p),gitRead,ancestor),/Historical parent/);
});

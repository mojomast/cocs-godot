// Source-only reconciliation of the exact parent-reviewed a5c26f25 foundation.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {FEATURE_ROOTS,FEATURE_RUNTIME_ADVANCES,FEATURE_REVIEW_SCOPE,ROBOT_SHARED_RUNTIME_ADVANCES,legacyFunctionHashes} from './feature_dependencies.mjs';
const anchor='a5c26f25',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const previous=p=>git(anchor,p);
const req=JSON.parse(previous(REQUIREMENTS)),unpromoted=structuredClone(req);
for(const unit of Object.values(unpromoted.units))unit.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
const own=new Set(['tools/godot-package/production_resources.mjs','tools/godot-package/feature_dependencies.mjs']);
const parentChanges=new Set(execFileSync('git',['diff','--name-only','f0e76bf7',anchor,'--','godot/'],{encoding:'utf8'}).trim().split('\n'));
assert.equal(execFileSync('git',['diff','f0e76bf7',anchor,'--','game/','server/','port/multiplayer-worlds/derived/','port/multiplayer-worlds/wall_candidates.mjs'],{encoding:'utf8'}),'','Authority changed in feature foundation');
assert.equal(execFileSync('git',['diff','--name-only','f0e76bf7',anchor,'--','*.glb','*.blend'],{encoding:'utf8'}),'','Authored binary asset drift');
for(const [path,change]of Object.entries(ROBOT_SHARED_RUNTIME_ADVANCES)){
 const old=git('d5a02632',path),now=read(path);assert.equal(hash(old),change.before);assert.equal(hash(now),change.after);
 const a=legacyFunctionHashes(old.toString()),b=legacyFunctionHashes(now.toString());assert.deepEqual(a,change.legacyFunctions);
 for(const [name,sha]of Object.entries(a))assert.equal(b[name],sha,'Changed legacy robot helper: '+name);
}
const files=new Map(),audit=[];
for(const id of ['parallax-interiors','robots','vehicles','scenery','vesper-viaduct','abyssal-pressureworks']) {
 const path=`tools/godot-package/production_receipts/${id}.json`,original=previous(path),receipt=JSON.parse(original);
 const old=receipt.packageInputs,expected=units[id].expected.packageInputs,changed={},added={},runtimeChanged={};
 for(const p of Object.keys(old))assert.ok(expected.includes(p),'Dropped prior package input: '+p);
 receipt.packageInputs=Object.fromEntries(expected.map(p=>{
  const bytes=read(p),sha=hash(bytes);
  // New features must be exactly the reviewed foundation, not later worktree
  // changes. Only this transaction's two verifier modules are new source.
  if(!own.has(p))assert.deepEqual(bytes,previous(p),'Post-foundation drift: '+p);
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){assert.ok(own.has(p)||parentChanges.has(p),'Unreviewed supporting change: '+p);changed[p]={before:old[p],after:sha};}
  return [p,sha];
 }));
 for(const [p,sha]of Object.entries(receipt.sourceHashes))assert.equal(hash(read(p)),sha,'FAIL producer identity changed: '+p);
 for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256,'FAIL produced asset identity changed: '+row.path);
 for(const [p,sha]of Object.entries(receipt.runtimeHooks)){
  const actual=hash(read(p));if(actual===sha)continue;
  const change={before:sha,after:actual};assert.deepEqual(change,FEATURE_RUNTIME_ADVANCES[id]?.[p],'Unreviewed runtime hook: '+id+'/'+p);
  runtimeChanged[p]=change;receipt.runtimeHooks[p]=actual;
 }
 assert.deepEqual(runtimeChanged,FEATURE_RUNTIME_ADVANCES[id]??{});
 receipt.featureAdvance={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,runtimeChanged,sharedRuntimeChanged:id==='robots'?ROBOT_SHARED_RUNTIME_ADVANCES:{},
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(receipt.packageInputs)),
  dependencyRoots:FEATURE_ROOTS,
  review:{foundation:anchor,scope:FEATURE_REVIEW_SCOPE,nativeFeatureChecks:'pending',document:'port/finish/motion/FEATURE_PACKAGE_RECONCILIATION.md'},
  evidencePolicy:'Original asset production/native evidence and F/H/I reconciliation entries remain immutable. This package-input advance is not new UI, controls, motion, first-person or vehicle native acceptance.'};
 const bytes=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
 assert.ok(read(path).equals(original)||read(path).equals(bytes),'Refusing unrelated receipt replacement');
 files.set(path,bytes);req.units[id].promotion={receipt:path,sha256:hash(bytes)};
 const row={unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,added,changed,runtimeChanged,receiptSHA256:hash(bytes)};
 audit.push(row);console.log(JSON.stringify({...row,added:Object.keys(added).length}));
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
const args={read:p=>files.get(p)??read(p),has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false};
assert.deepEqual(productionResources(args).pending,['stormglass-causeway']);
assert.throws(()=>productionResources({...args,strict:true}),/Required final production units remain pending/);
for(const [p,bytes]of files)writeFileSync(p,bytes);
writeFileSync('port/finish/motion/feature-package-audit.json',JSON.stringify({foundation:anchor,scope:FEATURE_REVIEW_SCOPE,units:audit},null,2)+'\n');

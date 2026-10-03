// Exact source-only J promotion. All receipt candidates validate before writing.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {FEATURE_REVIEW_SCOPE} from './feature_dependencies.mjs';
import {STORMGLASS_GLB,STORMGLASS_INVENTORY,STORMGLASS_EVIDENCE,STORMGLASS_SUPPORTING_RUNTIME,J_RUNTIME_ADVANCES,RACE_RUNTIME_ADVANCES,MELEE_RUNTIME_ADVANCES,MELEE_ADDED,stormglassRuntimePolicy,J_BASE,J_PRODUCER,J_PRODUCER_SHA,stormglassImportPaths} from './stormglass_imports.mjs';
const anchor='38dfb3bd',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const previous=p=>git(anchor,p),files=new Map();
const inventoryPaths=[STORMGLASS_GLB,...stormglassImportPaths(),...STORMGLASS_EVIDENCE.filter(p=>p!==STORMGLASS_INVENTORY),'tools/godot-multiplayer/new-maps/stormglass-causeway/architecture.py'].sort();
files.set(STORMGLASS_INVENTORY,Buffer.from(JSON.stringify({foundation:'9746a9e2',files:inventoryPaths.map(p=>{const bytes=git('9746a9e2',p);assert.deepEqual(read(p),bytes,'Received J bytes changed: '+p);return {path:p,bytes:bytes.length,sha256:hash(bytes)};})},null,2)+'\n'));
const readProposed=p=>files.get(p)??read(p),has=p=>files.has(p)||existsSync(p);
const req=JSON.parse(previous(REQUIREMENTS)),unpromoted=structuredClone(req);for(const u of Object.values(unpromoted.units))u.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):readProposed(p),has,strict:false}).units;
const allowedChanged=new Set(['tools/godot-package/production_resources.mjs','port/multiplayer-worlds/catalog.mjs','godot/multiplayer_worlds/catalog.gd',...Object.keys(RACE_RUNTIME_ADVANCES),...Object.keys(MELEE_RUNTIME_ADVANCES)]);
for(const [p,c]of Object.entries(RACE_RUNTIME_ADVANCES)){
 assert.equal(hash(git('9746a9e2',p)),c.before);assert.equal(hash(previous(p)),c.after);assert.equal(hash(read(p)),c.after,'Later race source drift: '+p);
}
for(const [p,c]of Object.entries(MELEE_RUNTIME_ADVANCES)){
 assert.equal(hash(git('4cc0292d',p)),c.before);assert.equal(hash(previous(p)),c.after);assert.equal(hash(read(p)),c.after,'Later melee source drift: '+p);
}
for(const [p,sha]of Object.entries(MELEE_ADDED))assert.equal(hash(read(p)),sha,'New melee helper drift: '+p);
// Exact reviewed catalogs, not arbitrary registration edits.
assert.equal(hash(read('godot/multiplayer_worlds/catalog.gd')),STORMGLASS_SUPPORTING_RUNTIME['godot/multiplayer_worlds/catalog.gd'].after);
assert.equal(hash(read('port/multiplayer-worlds/catalog.mjs')),'a74314f0b84143ae36a2983f102613ffcced69bfbecc891597797ec268eee3f1');
const audit=[];
for(const id of REQUIRED_UNITS){
 const isJ=id==='stormglass-causeway',path=`tools/godot-package/production_receipts/${id}.json`,oldPath=isJ?J_PRODUCER:path,original=previous(oldPath),receipt=JSON.parse(original);
 if(isJ)assert.equal(hash(original),J_PRODUCER_SHA);
 const old=receipt.packageInputs??receipt.packageInputHashes,expected=units[id].expected.packageInputs,changed={},added={},runtimeChanged={};
 for(const p of Object.keys(old))assert.ok(expected.includes(p),'Dropped previous input: '+p);
 if(!isJ)assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)),['godot/replay/stage.gd',...Object.keys(MELEE_ADDED),'tools/godot-package/stormglass_imports.mjs'].sort(),'Unexpected supporting additions: '+id);
 receipt.packageInputs=Object.fromEntries(expected.map(p=>{
  const bytes=readProposed(p),sha=hash(bytes);
  if(!['tools/godot-package/production_resources.mjs','tools/godot-package/stormglass_imports.mjs',STORMGLASS_INVENTORY,...allowedChanged].includes(p))assert.deepEqual(bytes,previous(p),'Post-foundation drift: '+p);
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){
   // J's old package verifier modules are retained historically; the foundation
   // already contains independently reviewed F/H/I/feature transactions.
   assert.ok(allowedChanged.has(p)||(isJ&&p.startsWith('tools/godot-package/')&&p.endsWith('_imports.mjs')),'Unreviewed supporting drift: '+p);
   changed[p]={before:old[p],after:sha};
  }
  return [p,sha];
 }));
 for(const [p,sha]of Object.entries(receipt.sourceHashes))assert.equal(hash(read(p)),sha,'FAIL producer identity drift: '+p);
 for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256,'FAIL master/export drift: '+row.path);
 if(isJ){
  const summary=JSON.parse(previous(J_BASE+'summary.json'));
  receipt.nativeRuntimeHooks=Object.fromEntries(Object.entries(summary.runtimeAndFixtureHashes).filter(([p])=>p.startsWith('godot/')&&!p.startsWith('godot/tests/')&&p.endsWith('.gd')));
  receipt.runtimeHooks={...receipt.nativeRuntimeHooks};receipt.rawFiles=[];
 }
 for(const [p,before]of Object.entries(receipt.runtimeHooks)){
  const after=hash(read(p));if(after===before)continue;
  const change={before,after};assert.deepEqual(change,stormglassRuntimePolicy(id)[p],'Unreviewed runtime advance: '+id+'/'+p);
  runtimeChanged[p]=change;receipt.runtimeHooks[p]=after;
 }
 receipt.stormglassPackageVerifierAdvance={previousReceipt:{commit:anchor,path:oldPath,sha256:hash(original)},changed,added,runtimeChanged,
  nativeToFeatureAdvance:isJ?{to:'a5c26f25',changed:J_RUNTIME_ADVANCES}:null,
  raceSourceAdvance:{from:'9746a9e2',to:'4cc0292d',changed:RACE_RUNTIME_ADVANCES},
  meleeSourceAdvance:{from:'4cc0292d',to:anchor,changed:MELEE_RUNTIME_ADVANCES,added:MELEE_ADDED},
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(receipt.packageInputs)),
  review:{foundation:anchor,scope:FEATURE_REVIEW_SCOPE,nativeFeatureChecks:'pending',document:'port/finish/STORMGLASS_PACKAGE_PROMOTION.md'},
  reason:isJ?'Original J producer and private native snapshots preserved. Runtime chain: J to a5c26f25 features to 4cc0292d shared race fixes and 38dfb3bd melee presentation; native pending. One public Puma race pair; flat-road concession.':'One Stormglass public Puma race registration after featureAdvance; exact catalog/verifier, 4cc0292d race HUD/audio/attachment and 38dfb3bd melee presentation reconciliation. Original E/F/H/I/native evidence and all previous advances retained; new native checks pending.'};
 if(isJ)receipt.integrationReview={acceptedBy:'parent actual overview/terminal/freight bore/surgeworks/wide gameplay/compact results review',foundation:anchor,publicModes:['puma-race'],drivableReliefMetres:0,sharedProductionFeatureAcceptance:false,
  limitations:['explicit flat-road concession; zero drivable relief; no jumps or elevated road claims','hard water boundary','dark walls and scenic repetition','private fixture patched HUD name, compact results and audio cleanup; shared fixes integrated at 4cc0292d but native checks pending','J used historical camera; new feature acceptance pending; no hardware performance or human-feel claim'],
  assetReady:true,nativeEvidence:J_BASE+'summary.json'};
 const bytes=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
 if(existsSync(path))assert.ok(read(path).equals(original)||read(path).equals(bytes),'Refusing unrelated receipt replacement: '+path);
 files.set(path,bytes);req.units[id].promotion={receipt:path,sha256:hash(bytes)};
 audit.push({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,added:Object.keys(added).length,changed,runtimeChanged,sha256:hash(bytes)});
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
const options={read:readProposed,has,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true};
assert.deepEqual(productionResources(options).pending,[]);
for(const [p,bytes]of files)writeFileSync(p,bytes);
writeFileSync('port/finish/stormglass-package-audit.json',JSON.stringify({foundation:anchor,units:audit},null,2)+'\n');
console.log(JSON.stringify(audit,null,2));

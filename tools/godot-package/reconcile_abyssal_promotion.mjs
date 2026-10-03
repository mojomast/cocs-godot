// Source-only I integration; original production/native evidence is immutable.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {abyssalImportPaths,ABYSSAL_EVIDENCE,ABYSSAL_SUPPORTING_RUNTIME} from './abyssal_imports.mjs';
const anchor='f0e76bf7',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const previous=p=>execFileSync('git',['show',`${anchor}:${p}`],{maxBuffer:128*1024*1024});
const req=JSON.parse(previous(REQUIREMENTS)),unpromoted=structuredClone(req);
for(const unit of Object.values(unpromoted.units))unit.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
const files=new Map();
for(const id of ['parallax-interiors','robots','vehicles','scenery','vesper-viaduct','abyssal-pressureworks']) {
 const path=`tools/godot-package/production_receipts/${id}.json`,original=previous(path),receipt=JSON.parse(original);
 const old=receipt.packageInputs,expected=units[id].expected.packageInputs,changed={},added={},runtimeChanged={};
 const allowedAdded=['tools/godot-package/abyssal_imports.mjs',...(id==='parallax-interiors'?['godot/multiplayer_worlds/abyssal_presentation.gd']:[]),...(id==='abyssal-pressureworks'?['tools/godot-package/vesper_imports.mjs',...abyssalImportPaths(),...ABYSSAL_EVIDENCE,'godot/multiplayer_worlds/catalog.gd','godot/multiplayer_worlds/abyssal_presentation.gd']:[])];
 assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)).sort(),allowedAdded.sort(),'Unexpected additions: '+id);
 const allowedChanged=['tools/godot-package/production_resources.mjs',...(['parallax-interiors','vesper-viaduct','abyssal-pressureworks'].includes(id)?['port/multiplayer-worlds/catalog.mjs','godot/multiplayer_worlds/catalog.gd']:[]),...(id==='parallax-interiors'?['godot/multiplayer_worlds/map.gd','godot/multiplayer_worlds/demo.gd']:[])];
 for(const p of Object.keys(old))assert.ok(expected.includes(p),'Dropped input: '+p);
 receipt.packageInputs=Object.fromEntries(expected.map(p=>{
  const sha=hash(read(p));
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){assert.ok(allowedChanged.includes(p),'Unexpected supporting drift: '+id+'/'+p);changed[p]={before:old[p],after:sha};}
  return [p,sha];
 }));
 for(const [p,sha]of Object.entries(receipt.sourceHashes))assert.equal(hash(read(p)),sha,'Production source drift: '+p);
 for(const [p,sha]of Object.entries(receipt.runtimeHooks)) {
  const actual=hash(read(p));if(actual===sha)continue;
  assert.ok(['parallax-interiors','vesper-viaduct'].includes(id));assert.deepEqual({before:sha,after:actual},ABYSSAL_SUPPORTING_RUNTIME[p]);
  runtimeChanged[p]={before:sha,after:actual};receipt.runtimeHooks[p]=actual;
 }
 for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256);
 receipt.abyssalPackageVerifierAdvance={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,runtimeChanged,
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(receipt.packageInputs)),
  reason:'Parent accepted Abyssal I integration and six public modes. Source-only supporting hook/catalog/verifier reconciliation; original I/H/F native evidence and prior advances remain immutable.',
  review:'port/finish/ABYSSAL_PACKAGE_PROMOTION.md'};
 if(id==='abyssal-pressureworks')receipt.integrationReview={acceptedBy:'parent overview, reef window, vessel-1-2 interior and compact CTF results review',foundation:anchor,nativeEvidence:'port/expansion-three/abyssal/evidence/production-i/hosted-summary.json',limitations:['room-shell repetition','software performance limits; no hardware performance claim'],publicModes:['deathmatch','teamdeathmatch','ctf','koth','domination','holdout']};
 const bytes=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
 assert.ok(read(path).equals(original)||read(path).equals(bytes),'Refusing unrelated receipt replacement');
 files.set(path,bytes);req.units[id].promotion={receipt:path,sha256:hash(bytes)};
 console.log(JSON.stringify({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,added:Object.keys(added).length,changed,runtimeChanged,sha256:hash(bytes)}));
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
const args={read:p=>files.get(p)??read(p),has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false};
assert.deepEqual(productionResources(args).pending,['stormglass-causeway']);
assert.throws(()=>productionResources({...args,strict:true}),/Required final production units remain pending/);
for(const [p,bytes]of files)writeFileSync(p,bytes);

// Source-only parent-authorized H integration. Native evidence remains frozen.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {vesperImportPaths,VESPER_EVIDENCE,VESPER_SUPPORTING_RUNTIME} from './vesper_imports.mjs';
const anchor='99a4f597',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const previous=p=>execFileSync('git',['show',`${anchor}:${p}`],{maxBuffer:128*1024*1024});
const req=JSON.parse(previous(REQUIREMENTS)),unpromoted=structuredClone(req);
for(const unit of Object.values(unpromoted.units))unit.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
const files=new Map();
for(const id of ['parallax-interiors','robots','vehicles','scenery','vesper-viaduct']) {
 const path=`tools/godot-package/production_receipts/${id}.json`,original=previous(path),receipt=JSON.parse(original);
 const old=receipt.packageInputs,expected=units[id].expected.packageInputs,changed={},added={},runtimeChanged={};
 const allowedAdded=['tools/godot-package/vesper_imports.mjs',...(id==='vesper-viaduct'?['tools/godot-package/scenery_imports.mjs',...vesperImportPaths(),...VESPER_EVIDENCE,'godot/multiplayer_worlds/catalog.gd']:[])];
 assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)).sort(),allowedAdded.sort(),'Unexpected additions: '+id);
 const allowedChanged=['tools/godot-package/production_resources.mjs',...(['parallax-interiors','vesper-viaduct'].includes(id)?['port/multiplayer-worlds/catalog.mjs']:[]),...(id==='parallax-interiors'?Object.keys(VESPER_SUPPORTING_RUNTIME):[])];
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
  assert.equal(id,'parallax-interiors');assert.deepEqual({before:sha,after:actual},VESPER_SUPPORTING_RUNTIME[p]);
  runtimeChanged[p]={before:sha,after:actual};receipt.runtimeHooks[p]=actual;
 }
 for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256);
 receipt.vesperPackageVerifierAdvance={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,runtimeChanged,
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(receipt.packageInputs)),
  reason:'Parent accepted Vesper H integration/public six-mode registration; supporting verifier/catalog/demo reconciliation only. H native evidence used the original frozen authority, not the later Helix navigation optimization.',
  review:'port/finish/VESPER_PACKAGE_PROMOTION.md'};
 if(id==='vesper-viaduct')receipt.integrationReview={acceptedBy:'parent explicit overview, ticket concourse, compact CTF results, civic front stair, street arcade, canal bridge and actual DM frame review',productionAssetCommit:'8adb9f05',nativeEvidence:'port/expansion-three/vesper/evidence/production-h/hosted-summary.json',limitations:['dark interior final review pending','software rendering performance final review pending','H is not proof of the later Helix-optimized authority'],publicModes:['deathmatch','teamdeathmatch','ctf','domination','koth','uplink']};
 const bytes=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
 assert.ok(read(path).equals(original)||read(path).equals(bytes),'Refusing unrelated receipt replacement');
 files.set(path,bytes);req.units[id].promotion={receipt:path,sha256:hash(bytes)};
 console.log(JSON.stringify({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,added:Object.keys(added).length,changed,runtimeChanged,sha256:hash(bytes)}));
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
const args={read:p=>files.get(p)??read(p),has:existsSync,worldIds:['parallax-observatory','vesper-viaduct'],strict:false};
assert.deepEqual(productionResources(args).pending,['abyssal-pressureworks','stormglass-causeway']);
assert.throws(()=>productionResources({...args,strict:true}),/Required final production units remain pending/);
for(const [p,bytes]of files)writeFileSync(p,bytes);

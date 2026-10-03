// Parent-authorized source-only F promotion; immutable production/native records.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {sceneryImportPaths,SCENERY_EVIDENCE} from './scenery_imports.mjs';
const anchor='27f3afc3',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const previous=p=>execFileSync('git',['show',`${anchor}:${p}`],{maxBuffer:128*1024*1024});
const req=JSON.parse(previous(REQUIREMENTS)),unpromoted=structuredClone(req);
for(const unit of Object.values(unpromoted.units))unit.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
const files=new Map();
for(const id of ['parallax-interiors','robots','vehicles','scenery']) {
 const path=`tools/godot-package/production_receipts/${id}.json`,original=previous(path),receipt=JSON.parse(original);
 const old=receipt.packageInputs,expected=units[id].expected.packageInputs,changed={},added={};
 const allowedAdded=['tools/godot-package/scenery_imports.mjs',...(id==='scenery'?['tools/godot-package/vehicle_imports.mjs',...sceneryImportPaths(receipt.exports.map(r=>r.path),read),...SCENERY_EVIDENCE]:[])];
 assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)).sort(),allowedAdded.sort(),'Unexpected additions: '+id);
 for(const p of Object.keys(old))assert.ok(expected.includes(p),'Dropped input: '+p);
 receipt.packageInputs=Object.fromEntries(expected.map(p=>{
  const sha=hash(read(p));
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){assert.equal(p,'tools/godot-package/production_resources.mjs','Unexpected supporting drift: '+id);changed[p]={before:old[p],after:sha};}
  return [p,sha];
 }));
 for(const [p,sha]of Object.entries({...receipt.sourceHashes,...receipt.runtimeHooks}))assert.equal(hash(read(p)),sha,'Production identity drift: '+p);
 for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256);
 receipt.sceneryPackageVerifierAdvance={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(receipt.packageInputs)),
  productionSourceCheckpoint:id==='scenery'?'b320c270':null,
  reason:'Parent accepted F visual review; source-only texture/import closure and supporting-input reconciliation. No new native attestation or build.',
  review:'port/finish/SCENERY_PACKAGE_PROMOTION.md'};
 if(id==='scenery')receipt.integrationReview={acceptedBy:'parent explicit four-chapter and architecture image review',nativeRendering:'capture-paced llvmpipe; continuous rendered playability and human feel unproven',nativeEvidence:'port/expansion-four/scenery/production-f/journeys-final/summary.json'};
 const bytes=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
 assert.ok(read(path).equals(original)||read(path).equals(bytes),'Refusing unrelated receipt replacement');
 files.set(path,bytes);req.units[id].promotion={receipt:path,sha256:hash(bytes)};
 console.log(JSON.stringify({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,added:Object.keys(added).length,changed,sha256:hash(bytes)}));
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
const args={read:p=>files.get(p)??read(p),has:existsSync,worldIds:['parallax-observatory'],strict:false};
assert.deepEqual(productionResources(args).pending,['vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
assert.throws(()=>productionResources({...args,strict:true}),/Required final production units remain pending/);
for(const [p,bytes]of files)writeFileSync(p,bytes);

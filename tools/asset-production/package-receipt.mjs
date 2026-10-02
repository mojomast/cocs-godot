// Producer conversion only. Never edits requirements, registration or promotion.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {productionResources,inspectProductionGlb} from '../godot-package/production_resources.mjs';
export const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const sorted=paths=>[...paths].sort();
const safe=p=>assert.ok(typeof p==='string'&&/^(godot|tools|port|game)\/[a-zA-Z0-9_./-]+$/.test(p)&&!p.split('/').some(s=>['','.','..'].includes(s)),'Invalid receipt path '+p);
export function inventory(root){
 return productionResources({read:p=>readFileSync(resolve(root,p)),has:p=>existsSync(resolve(root,p)),strict:false}).units;
}
export function inputSnapshot(expected,read){
 return Object.fromEntries(expected.packageInputs.map(p=>{safe(p);return [p,hash(read(p))];}));
}
export function convert({unit,plan,expected,receipt,read,hooks}){
 assert.ok(unit!=='parallax-interiors','External Parallax has a separate producer');
 assert.equal(receipt.unit,unit);
 const entry=plan.units.find(u=>u.id===unit);assert.ok(entry&&!entry.external);
 const sourceHashes=Object.fromEntries(sorted([...entry.recipePaths,plan.common.finishScript]).map(p=>[p,hash(read(p))]));
 assert.deepEqual(receipt.sourceHashes,sourceHashes,'Stale generic source hashes');
 const fingerprint=hash(JSON.stringify(sourceHashes));
 assert.equal(receipt.sourceFingerprint,fingerprint,'Stale generic fingerprint');
 const packageInputs=inputSnapshot(expected,read);
 // This snapshot is recorded by the generic receipt when actual assets pass.
 // Re-running the converter cannot silently bless changed supporting inputs.
 assert.deepEqual(receipt.packageInputHashes,packageInputs,'Stale/missing generic package-input snapshot; regenerate the generic receipt');
 for(const field of ['masters','exports']){
  assert.ok(Array.isArray(receipt[field]));
  assert.deepEqual(sorted(receipt[field].map(row=>row.path)),sorted(expected[field]),'Exact package '+field+' inventory mismatch');
  for(const row of receipt[field]){
   safe(row.path);const bytes=read(row.path);
   assert.equal(hash(bytes),row.sha256,'Stale output '+row.path);
   if(field==='exports')assert.deepEqual(row.textures,inspectProductionGlb(bytes,fingerprint),'Embedded image/fingerprint mismatch '+row.path);
  }
 }
 assert.ok(Array.isArray(hooks)&&hooks.length,'Explicit actual runtime hooks required');
 assert.equal(new Set(hooks).size,hooks.length,'Duplicate runtime hook');
 const runtimeHooks=Object.fromEntries(sorted(hooks).map(p=>{
  safe(p);assert.match(p,/^godot\/(?!tests\/).+\.(gd|gdshader|json)$/,'Production runtime hook required');
  return [p,hash(read(p))];
 }));
 assert.deepEqual(receipt.rawFiles??[],[],'Current producers have no raw runtime file reads');
 // All current producers use imported resources; raw GLB copies are not needed.
 return {...receipt,packageInputs,runtimeHooks,rawFiles:[],accepted:false};
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const [unit,receiptPath,...args]=process.argv.slice(2);
 const root=fileURLToPath(new URL('../../',import.meta.url));
 const plan=JSON.parse(readFileSync(resolve(root,'port/finish/ASSET_PRODUCTION.json')));
 const status=inventory(root)[unit];assert.ok(status,'Unknown production unit');
 assert.deepEqual(status.missing,[],'Real production inputs/masters/exports required');
 const read=p=>readFileSync(resolve(root,p));
 const receipt=JSON.parse(readFileSync(receiptPath));
 const hooks=args.filter(a=>a.startsWith('--runtime-hook=')).map(a=>a.slice('--runtime-hook='.length));
 assert.equal(hooks.length,args.length,'Unexpected package receipt argument');
 const result=convert({unit,plan,expected:status.expected,receipt,read,hooks});
 const output=resolve(root,`tools/godot-package/production_receipts/${unit}.json`);
 const bytes=JSON.stringify(result,null,2)+'\n';
 // Parent may already have promoted this fixed receipt. Never overwrite it.
 if(existsSync(output))assert.equal(readFileSync(output,'utf8'),bytes,'Fixed receipt differs; retain and explicitly reconcile with parent');
 else{mkdirSync(dirname(output),{recursive:true});writeFileSync(output,bytes,{flag:'wx'});}
 console.log(JSON.stringify({unit,receipt:output,sha256:hash(bytes),accepted:false,promotionChanged:false}));
}

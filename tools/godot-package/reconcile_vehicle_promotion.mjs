// Source-only parent-authorized E promotion. No production or native rerun.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {vehicleImportPaths,VEHICLE_EVIDENCE} from './vehicle_imports.mjs';
process.chdir(fileURLToPath(new URL('../../',import.meta.url)));
const anchor='6e6395a2c4d4e204b7d017cfd59c5d8748daea16';
const previousHashes={vehicles:'6981afdfd64b22455abe3c36a706667ab94ed842b2509bccf94fb9cc390b1668',robots:'e0667a6bc7295f30f337f571301f3e7747b84c265835e96c2a310b5ba5e00d85','parallax-interiors':'3c7d26b851d031ff1509aa50e7aa81dc26df5f8836b5668e00ad7af2fef39ab5'};
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const gitRead=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const req=JSON.parse(read(REQUIREMENTS)),unpromoted=structuredClone(req);
for(const r of Object.values(unpromoted.units))r.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
const results=[];
for(const id of ['vehicles','robots','parallax-interiors']) {
  const path=`tools/godot-package/production_receipts/${id}.json`,original=gitRead(anchor,path),receipt=JSON.parse(original);
  assert.equal(hash(original),previousHashes[id]);
  const expected=units[id].expected.packageInputs,old=receipt.packageInputs,changed={},added={};
  const allowedAdded=['tools/godot-package/vehicle_imports.mjs',...(id==='vehicles'?[...vehicleImportPaths(receipt.exports.map(r=>r.path)),...VEHICLE_EVIDENCE]:[])];
  assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)).sort(),allowedAdded.sort(),'Unexpected new input');
  for(const p of Object.keys(old))assert.ok(expected.includes(p),`Dropped input: ${p}`);
  receipt.packageInputs=Object.fromEntries(expected.map(p=>{
    const bytes=read(p);assert.deepEqual(bytes,gitRead('HEAD',p),`Uncommitted input: ${p}`);
    const sha=hash(bytes);
    if(!Object.hasOwn(old,p))added[p]=sha;
    else if(old[p]!==sha){assert.equal(p,'tools/godot-package/production_resources.mjs','Unexpected supporting drift');changed[p]={before:old[p],after:sha};}
    return [p,sha];
  }));
  for(const [p,sha]of Object.entries({...receipt.sourceHashes,...receipt.runtimeHooks}))assert.equal(hash(read(p)),sha,`Production identity drift: ${p}`);
  for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256);
  receipt.packageVerifierAdvance={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,
    reason:'Parent 1f129ab2 authorized bounded vehicle asset promotion and import closure; supporting verifier advance only for retained robot/Parallax promotions; no rebuilt assets or new native attestation',
    review:'port/finish/VEHICLE_PACKAGE_PROMOTION.md'};
  const bytes=JSON.stringify(receipt,null,2)+'\n';
  assert.ok(read(path).equals(original)||read(path).toString()===bytes,'Refusing unrelated receipt replacement');
  results.push({path,bytes});req.units[id].promotion={receipt:path,sha256:hash(bytes)};
  console.log(JSON.stringify({unit:id,sha256:hash(bytes),inputs:expected.length,changed:Object.keys(changed),added:Object.keys(added).length}));
}
// Validate the entire proposed promotion transaction before writing any file.
const files=new Map(results.map(r=>[r.path,Buffer.from(r.bytes)]));files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
const audit=productionResources({read:p=>files.get(p)??read(p),has:existsSync,worldIds:['parallax-observatory'],strict:false});
assert.deepEqual(audit.pending,['scenery','vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
for(const [p,bytes]of files)writeFileSync(p,bytes);

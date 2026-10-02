// Explicit one-time, source-only reconciliation authorized by parent 2c39d1ad.
// Original producer snapshots and receipts remain available at the anchor below.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';
import {robotImportPaths} from './robot_imports.mjs';
process.chdir(fileURLToPath(new URL('../../',import.meta.url)));
const anchor='e59a762529bb4d76a92c363ab58fa4ca6bdfae55';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const gitRead=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const req=JSON.parse(read(REQUIREMENTS));
const unpromoted=structuredClone(req);for(const r of Object.values(unpromoted.units))r.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
for(const id of ['robots','parallax-interiors']) {
  const path=`tools/godot-package/production_receipts/${id}.json`,original=gitRead(anchor,path),receipt=JSON.parse(original);
  assert.equal(hash(original),id==='robots'?'e0e5bf6defc6bc8dacb0093070089aea1953554f1a72af26ba2d333c7d4a3f94':'f0d2b15ddb6c1d1609a2be5f1bc37cbf486b4b7034bf7fa6973577af9e79e6d0');
  const old=receipt.packageInputs,changed={},added={};
  const expected=units[id].expected.packageInputs;
  const allowedAdded=id==='robots'?[...robotImportPaths(receipt.exports.map(r=>r.path)),'tools/godot-robots/production-d.json','tools/godot-package/robot_imports.mjs','godot/biomes/expansion/scenery_pack.gd']:['tools/godot-package/robot_imports.mjs'];
  assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)).sort(),allowedAdded.sort());
  for(const p of Object.keys(old))assert.ok(expected.includes(p),`Dropped input: ${p}`);
  receipt.packageInputs=Object.fromEntries(expected.map(p=>{
    const bytes=read(p);assert.deepEqual(bytes,gitRead('HEAD',p),`Uncommitted input: ${p}`);
    const sha=hash(bytes);
    if(!Object.hasOwn(old,p))added[p]=sha;
    else if(old[p]!==sha){assert.ok(p==='tools/godot-package/production_resources.mjs'||(id==='robots'&&p==='godot/biomes/expansion/scenery_pack.gd'),'Unexpected supporting input drift');changed[p]={before:old[p],after:sha};}
    return [p,sha];
  }));
  for(const [p,sha]of Object.entries({...receipt.sourceHashes,...receipt.runtimeHooks}))assert.equal(hash(read(p)),sha,`Production identity drift: ${p}`);
  for(const row of [...receipt.masters,...receipt.exports])assert.equal(hash(read(row.path)),row.sha256);
  receipt.packageReconciliation={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,
    reason:'Parent-authorized verifier input advance and bounded robot import/extracted-image closure; no asset rebuild or new native attestation'+(id==='robots'?'; includes scenery adapter cf0e8def/fa2e5fd8, not covered by D native results':''),
    review:'port/finish/ROBOT_PACKAGE_PROMOTION.md'};
  if(id==='robots') {
    const p='godot/biomes/expansion/scenery_pack.gd';
    receipt.packageReconciliation.supportingRuntimeRevision={commit:'cf0e8def',path:p,before:hash(gitRead(anchor,p)),after:hash(read(p)),nativeValidation:'Pending; D native evidence predates this scenery adapter'};
  }
  const bytes=JSON.stringify(receipt,null,2)+'\n';
  const existing=read(path),draft=id==='robots'?'0548eda811ffae6a7b8c5a8fd99e66d8011ab5681bec1a545a0e6a21576836ab':'7855b25ba360d0cd0787e3801fd72820605b8f154301840a7c616661ab2fd411';
  assert.ok(existing.equals(original)||existing.toString()===bytes||hash(existing)===draft||(id==='robots'&&hash(existing)==='6ed1bf51818feae5e40e33b65814ea64c72b5f859d8b5eb0118d2680da177e80'),'Refusing unrelated receipt replacement');
  writeFileSync(path,bytes);
  req.units[id].promotion={receipt:path,sha256:hash(bytes)};
  console.log(JSON.stringify({unit:id,sha256:hash(bytes),inputs:expected.length,changed:Object.keys(changed),added:Object.keys(added).length}));
}
writeFileSync(REQUIREMENTS,JSON.stringify(req,null,2)+'\n');

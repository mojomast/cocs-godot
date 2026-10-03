// Source-only transaction pinned to the reviewed movement merge, never floating HEAD.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {movementInventory,MOVEMENT_INVENTORY} from './movement_dependencies.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const s=movementInventory(read),anchor=s.foundation,previous=p=>git(anchor,p),files=new Map();
const local=new Set([MOVEMENT_INVENTORY,'tools/godot-package/movement_dependencies.mjs','tools/godot-package/source_derivative.mjs','tools/godot-package/polish_dependencies.mjs','tools/godot-package/production_resources.mjs']);
const proposed=p=>files.get(p)??read(p),has=p=>files.has(p)||existsSync(p);
const req=JSON.parse(previous(REQUIREMENTS)),empty=structuredClone(req);for(const u of Object.values(empty.units))u.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(empty)):proposed(p),has,strict:false}).units,audit=[];
for(const [p,c]of Object.entries(s.changed)){assert.equal(hash(git(s.previous,p)),c.before);assert.equal(hash(previous(p)),c.after);}
for(const id of REQUIRED_UNITS){
 const p=`tools/godot-package/production_receipts/${id}.json`,original=previous(p),r=JSON.parse(original),old=r.packageInputs,expected=units[id].expected.packageInputs,changed={},added={};
 for(const p of Object.keys(old))assert.ok(expected.includes(p),'Removed dependency: '+p);
 r.packageInputs=Object.fromEntries(expected.map(p=>{
  const bytes=proposed(p),sha=hash(bytes);
  if(!local.has(p))assert.deepEqual(bytes,previous(p),'Post-foundation drift: '+p);
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){
   assert.ok(local.has(p)||Object.hasOwn(s.changed,p),'Unreviewed supporting change: '+p);
   if(s.changed[p])assert.deepEqual({before:old[p],after:sha},s.changed[p]);
   changed[p]={before:old[p],after:sha};
  }
  return [p,sha];
 }));
 const hook='godot/horde/demo.gd',runtimeChanged=id==='robots'?{[hook]:s.changed[hook]}:{};
 for(const [p,sha]of Object.entries({...r.sourceHashes,...r.runtimeHooks})){
  if(runtimeChanged[p])assert.equal(sha,runtimeChanged[p].before,'Native hook predecessor');
  assert.equal(hash(read(p)),runtimeChanged[p]?.after??sha,'Producer or native hook drift: '+p);
 }
 for(const row of [...r.masters,...r.exports])assert.equal(hash(read(row.path)),row.sha256);
 r.movementAdvance={previousReceipt:{commit:anchor,path:p,sha256:hash(original)},changed,added,runtimeChanged,reviewedSource:s,
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(r.packageInputs)),
  review:{foundation:anchor,status:s.status,nativeChecks:'pending',assetProduction:'reuse unchanged original production bytes',document:'port/finish/movement-research/PACKAGE_RECONCILIATION.md'}};
 const bytes=Buffer.from(JSON.stringify(r,null,2)+'\n');
 if(!read(p).equals(original)&&!read(p).equals(bytes)){
  // Iterating verifier source is allowed only over a fully preserved previous
  // transaction. Never overwrite unrelated producer/history changes.
  const current=JSON.parse(read(p));delete current.movementAdvance;current.packageInputs=old;
  assert.deepEqual(current,JSON.parse(original),'Unrelated receipt replacement');
 }
 files.set(p,bytes);req.units[id].promotion={receipt:p,sha256:hash(bytes)};
 audit.push({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,changed,added,sha256:hash(bytes)});
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
assert.deepEqual(productionResources({read:proposed,has,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true}).pending,[]);
for(const [p,b]of files)writeFileSync(p,b);
writeFileSync('port/finish/movement-research/package-audit.json',JSON.stringify({foundation:anchor,units:audit},null,2)+'\n');
console.log(JSON.stringify(audit.map(({changed,added,...r})=>({...r,changed:Object.keys(changed).length,added:Object.keys(added).length})),null,2));

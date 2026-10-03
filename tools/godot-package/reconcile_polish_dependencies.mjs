// Fixed 8921ed41 only: validate the complete seven-receipt proposal before writes.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {polishInventory,POLISH_INVENTORY} from './polish_dependencies.mjs';
const anchor='8921ed41',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const previous=p=>execFileSync('git',['show',`${anchor}:${p}`],{maxBuffer:128*1024*1024});
const s=polishInventory(read),req=JSON.parse(previous(REQUIREMENTS)),unpromoted=structuredClone(req);
for(const u of Object.values(unpromoted.units))u.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(unpromoted)):read(p),has:existsSync,strict:false}).units;
const own=['tools/godot-package/production_resources.mjs','tools/godot-package/stormglass_imports.mjs','tools/godot-package/polish_dependencies.mjs',POLISH_INVENTORY];
const received=new Set([...Object.keys(s.evidence),...Object.values(s.operatorFinish.imports).map(r=>r.sidecar)]);
const files=new Map(),audit=[];
for(const id of REQUIRED_UNITS){
 const path=`tools/godot-package/production_receipts/${id}.json`,original=previous(path),r=JSON.parse(original),old=r.packageInputs,expected=units[id].expected.packageInputs,changed={},added={},runtimeChanged={};
 for(const p of Object.keys(old))assert.ok(expected.includes(p),'Dropped input: '+p);
 r.packageInputs=Object.fromEntries(expected.map(p=>{
  const bytes=read(p),sha=hash(bytes);
  if(!own.includes(p)&&!received.has(p))assert.deepEqual(bytes,previous(p),'Post-foundation drift: '+p);
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){
   if(!own.includes(p)){assert.equal(old[p],s.changed[p]?.before,'Unreviewed predecessor: '+p);assert.equal(sha,s.changed[p].after,'Unreviewed current source: '+p);}
   changed[p]={before:old[p],after:sha};
  }
  return [p,sha];
 }));
 for(const [p,sha]of Object.entries(r.sourceHashes))assert.equal(hash(read(p)),sha,'FAIL producer changed: '+p);
 for(const row of [...r.masters,...r.exports])assert.equal(hash(read(row.path)),row.sha256,'FAIL master/export changed: '+row.path);
 for(const [p,before]of Object.entries(r.runtimeHooks)){
  const after=hash(read(p));if(before===after)continue;
  assert.equal(id,'stormglass-causeway');assert.equal(p,'godot/multiplayer_worlds/sports_demo.gd');assert.equal(before,s.changed[p].before);assert.equal(after,s.changed[p].after);
  runtimeChanged[p]={before,after};r.runtimeHooks[p]=after;
 }
 r.polishAdvance={previousReceipt:{commit:anchor,path,sha256:hash(original)},changed,added,runtimeChanged,
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(r.packageInputs)),
  reviewedSource:{previous:s.previous,foundation:s.foundation,changed:s.changed,added:s.added},
  review:{foundation:anchor,scope:s.scope,combinedNativeChecks:'pending',liveKickAcceptance:'not accepted',document:'port/finish/polish/PACKAGE_RECONCILIATION.md'},
  evidencePolicy:'Original asset acceptance, producer fingerprints, pending lists and all preceding histories remain immutable. K supplemental native records retain their historical anchors; staged gait/melee/FPS galleries differ from the actual public Stormglass journey. Combined polish native acceptance pending; live kick not accepted.'};
 const bytes=Buffer.from(JSON.stringify(r,null,2)+'\n');assert.ok(read(path).equals(original)||read(path).equals(bytes),'Unrelated receipt change: '+path);
 files.set(path,bytes);req.units[id].promotion={receipt:path,sha256:hash(bytes)};
 audit.push({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,added:Object.keys(added).length,changed:Object.keys(changed).length,runtimeChanged,sha256:hash(bytes)});
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
assert.deepEqual(productionResources({read:p=>files.get(p)??read(p),has:existsSync,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true}).pending,[]);
for(const [p,b]of files)writeFileSync(p,b);
writeFileSync('port/finish/polish/package-reconciliation-audit.json',JSON.stringify({foundation:anchor,units:audit},null,2)+'\n');
console.log(JSON.stringify(audit,null,2));

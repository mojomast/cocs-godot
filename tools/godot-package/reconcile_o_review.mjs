// Fixed b17360c9 source/evidence advance. No native execution or asset mutation.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {O_SOURCE_CHANGE,O_EVIDENCE} from './polish_dependencies.mjs';
const anchor='b17360c9',read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const git=(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{maxBuffer:128*1024*1024});
const previous=p=>git(anchor,p),files=new Map();
for(const [p,sha]of Object.entries(O_EVIDENCE)){
 const suffix=p.slice('port/finish/acceptance/package-evidence-o/'.length);
 const bytes=read('/home/mojo/.tmp-on-disk/cocs-gameplay-repair-O-20261003/'+suffix);assert.equal(hash(bytes),sha);
 if(existsSync(p))assert.deepEqual(read(p),bytes);files.set(p,bytes);
}
const proposed=p=>files.get(p)??read(p),has=p=>files.has(p)||existsSync(p);
const req=JSON.parse(previous(REQUIREMENTS)),empty=structuredClone(req);for(const u of Object.values(empty.units))u.promotion=null;
const units=productionResources({read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(empty)):proposed(p),has,strict:false}).units,audit=[];
for(const [p,c]of Object.entries(O_SOURCE_CHANGE)){assert.equal(hash(git('9cd1ac72',p)),c.before);assert.equal(hash(previous(p)),c.after);}
for(const id of REQUIRED_UNITS){
 const p=`tools/godot-package/production_receipts/${id}.json`,original=previous(p),r=JSON.parse(original),old=r.packageInputs,expected=units[id].expected.packageInputs,changed={},added={};
 assert.deepEqual(expected.filter(p=>!Object.hasOwn(old,p)).sort(),Object.keys(O_EVIDENCE).sort());
 for(const p of Object.keys(old))assert.ok(expected.includes(p));
 r.packageInputs=Object.fromEntries(expected.map(p=>{
  const bytes=proposed(p),sha=hash(bytes);
  if(p!=='tools/godot-package/polish_dependencies.mjs'&&!Object.hasOwn(O_EVIDENCE,p))assert.deepEqual(bytes,previous(p),'Post-foundation drift: '+p);
  if(!Object.hasOwn(old,p))added[p]=sha;
  else if(old[p]!==sha){
   assert.ok(p==='tools/godot-package/polish_dependencies.mjs'||Object.hasOwn(O_SOURCE_CHANGE,p),'Unreviewed supporting change: '+p);
   if(O_SOURCE_CHANGE[p])assert.deepEqual({before:old[p],after:sha},O_SOURCE_CHANGE[p]);
   changed[p]={before:old[p],after:sha};
  }
  return [p,sha];
 }));
 for(const [p,sha]of Object.entries({...r.sourceHashes,...r.runtimeHooks}))assert.equal(hash(read(p)),sha,'Producer or native hook drift: '+p);
 for(const row of [...r.masters,...r.exports])assert.equal(hash(read(row.path)),row.sha256);
 r.oReviewAdvance={previousReceipt:{commit:anchor,path:p,sha256:hash(original)},changed,added,runtimeChanged:{},sourceChanged:O_SOURCE_CHANGE,
  previousPackageFingerprint:hash(JSON.stringify(old)),packageFingerprint:hash(JSON.stringify(r.packageInputs)),
  review:{foundation:anchor,scope:'one reviewed Settings Return Home correction and retained O final receipts',nativeCoverage:'ordinary world and combined-arms journeys plus 90-assertion controls fixture; not final 142 acceptance',liveKickAcceptance:'not accepted',document:'port/finish/acceptance/O_PACKAGE_RECONCILIATION.md'}};
 const bytes=Buffer.from(JSON.stringify(r,null,2)+'\n');assert.ok(read(p).equals(original)||read(p).equals(bytes),'Unrelated receipt replacement');
 files.set(p,bytes);req.units[id].promotion={receipt:p,sha256:hash(bytes)};
 audit.push({unit:id,previousInputs:Object.keys(old).length,inputs:expected.length,changed:Object.keys(changed).length,added:Object.keys(added).length,sha256:hash(bytes)});
}
files.set(REQUIREMENTS,Buffer.from(JSON.stringify(req,null,2)+'\n'));
assert.deepEqual(productionResources({read:proposed,has,worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true}).pending,[]);
for(const [p,b]of files){mkdirSync(dirname(p),{recursive:true});writeFileSync(p,b);}
writeFileSync('port/finish/acceptance/o-package-audit.json',JSON.stringify({foundation:anchor,units:audit},null,2)+'\n');
console.log(JSON.stringify(audit,null,2));

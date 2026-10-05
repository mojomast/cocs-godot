import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {stagedResources,gitStagedResources,rejectStagedInputs,rejectStagedReferences,STAGED_MANIFEST,STAGED_MANIFEST_SHA,STAGED_CANDIDATE} from './staged_resources.mjs';
import {STAGED_ENTRIES} from './staged_resources.mjs';
const read=p=>readFileSync(p),git=(...a)=>execFileSync('git',a,{maxBuffer:128*1024*1024});
// Keep the original R5 fixture independent of later candidate inventories.
const paths=git('ls-tree','-r','--name-only','-z','7ae3f2f5','--','godot').toString().split('\0').filter(Boolean),options={paths,read,required:true};
test('exact R5 manifest and all 63 staged files match original artifact; accepted runtime remains selected',()=>{
 const manifest=git('show',`${STAGED_CANDIDATE}:${STAGED_MANIFEST}`);
 assert.equal(createHash('sha256').update(manifest).digest('hex'),STAGED_MANIFEST_SHA);
 const p=stagedResources(options);assert.equal(p.status,'staged-not-runtime-promoted');assert.equal(Object.keys(p.files).length,63);
 assert.equal(Object.values(p.files).reduce((n,r)=>n+r.bytes,0),16911756);
 assert.equal(p.nativeFiles.length,2494);
 for(const file of Object.keys(p.files)){assert.deepEqual(read(file),git('show',`${STAGED_CANDIDATE}:${file}`));assert.ok(!p.nativeFiles.includes(file));assert.ok(p.excludePaths.includes(file.slice(6)));}
 for(const file of ['art/worlds/gravemill-foundry.glb','generated/gravemill-foundry.json','dressing/profiles/gravemill-foundry.json'])assert.ok(p.nativeFiles.includes('godot/multiplayer_worlds/'+file));
});
test('unknown revision artifacts, tampered staged bytes, missing manifest and missing declared files fail closed',()=>{
 const p=stagedResources(options),first=Object.keys(p.files)[0];
 assert.throws(()=>stagedResources({...options,paths:[...paths,'godot/multiplayer_worlds/art/revisions/unreviewed.glb']}),/Unreviewed staged revision/);
 assert.throws(()=>stagedResources({...options,read:x=>x===first?Buffer.alloc(p.files[first].bytes):read(x)}),/Staged hash/);
 assert.throws(()=>stagedResources({...options,read:x=>x===STAGED_MANIFEST?Buffer.from('{}'):read(x)}),/Exact R5 staged manifest/);
 assert.throws(()=>stagedResources({...options,read:x=>{if(x===STAGED_MANIFEST)throw Error('Missing staged manifest');return read(x);}}),/Missing staged manifest/);
 assert.throws(()=>stagedResources({...options,paths:paths.filter(x=>x!==first)}),/Missing staged resource/);
});
test('production path, basename and UID references reject; raw/import/data shipping cannot bypass staging',()=>{
 const p=stagedResources(options),first=Object.keys(p.files)[0],consumer='godot/ui/main_menu.gd';
 for(const ref of ['res://'+first.slice(6),first.split('/').at(-1),read(first+'.import').toString().match(/uid="([^"]+)"/)[1]]){
  assert.throws(()=>stagedResources({...options,read:x=>x===consumer?Buffer.from('var forbidden = "'+ref+'"'):read(x)}),/Production reference/);
 }
 for(const file of Object.keys(p.files))assert.throws(()=>rejectStagedInputs([file],p),/Staged resource in runtime/);
 assert.throws(()=>rejectStagedReferences(['port/runtime-consumer.mjs'],x=>x.endsWith('.mjs')?Buffer.from('read("'+first+'")'):read(x),p.files),/Production reference/);
});
test('recorded pre-R5 source ignores ambient candidate files and requires no new manifest',()=>{
 const p=gitStagedResources(process.cwd(),'4cd806fa');assert.deepEqual(p.files,{});assert.deepEqual(p.excludePaths,[]);
 assert.ok(p.nativeFiles.includes('godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb'));
});
const r6=STAGED_ENTRIES.find(e=>e.id==='foundry-r6');
// Fixed pre-Y source keeps the R6 cases meaningful after later additions.
const currentPaths=git('ls-tree','-r','--name-only','-z','167ac4bc','--','godot').toString().split('\0').filter(Boolean);
const both={paths:currentPaths,read,required:['foundry-r5','foundry-r6']};
test('R6 manifest exactly covers artifact Git diff; both candidates excluded and accepted native count unchanged',()=>{
 const p=stagedResources(both),entry=p.entries.find(e=>e.id===r6.id);
 const added=git('diff','--name-only',r6.candidate+'^',r6.candidate,'--','godot').toString().trim().split('\n').filter(p=>!p.startsWith('godot/tests/'));
 assert.deepEqual([...entry.paths].sort(),added.sort());assert.equal(entry.paths.length,74);
 assert.equal(entry.paths.filter(p=>p.endsWith('.png')).length,36);
 assert.equal(entry.paths.filter(p=>p.endsWith('.import')).length,37);
 assert.equal(entry.paths.reduce((n,f)=>n+p.files[f].bytes,0),19007243);
 assert.equal(Object.keys(p.files).length,137);assert.equal(p.nativeFiles.length,2494);
 assert.equal(entry.status,'unpromoted-artifact-review-pending');
 for(const f of entry.paths){assert.deepEqual(read(f),git('show',`${r6.candidate}:${f}`));assert.ok(!p.nativeFiles.includes(f));assert.ok(p.excludePaths.includes(f.slice(6)));}
 assert.deepEqual(read(r6.manifest),git('show',`${r6.candidate}:${r6.manifest}`));
 git('merge-base','--is-ancestor',r6.source,r6.candidate);
 const glb=entry.paths.find(p=>p.endsWith('.glb')),b=read(glb),doc=JSON.parse(b.subarray(20,20+b.readUInt32LE(12)));
 assert.equal(doc.images.length,36);assert.equal(b.length,15012396);
 assert.equal(p.files[glb].sha256,'945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c');
});
test('R6 missing/changed manifest, artifact and unknown revision reject without granting an exemption',()=>{
 const p=stagedResources(both),first=p.entries.find(e=>e.id===r6.id).paths[0];
 assert.throws(()=>stagedResources({...both,read:x=>x===r6.manifest?Buffer.from('{}'):read(x)}),/Exact R6 staged manifest/);
 assert.throws(()=>stagedResources({...both,read:x=>{if(x===r6.manifest)throw Error('Missing R6 manifest');return read(x);}}),/Missing R6 manifest/);
 assert.throws(()=>stagedResources({...both,read:x=>x===first?Buffer.alloc(p.files[first].bytes):read(x)}),/Staged hash/);
 assert.throws(()=>stagedResources({...both,paths:currentPaths.filter(x=>x!==first)}),/Missing staged resource/);
 assert.throws(()=>stagedResources({...both,paths:[...currentPaths,'godot/multiplayer_worlds/art/revisions/unreviewed-r7.glb']}),/Unreviewed staged revision/);
 assert.throws(()=>stagedResources({...both,required:['foundry-r5']}),/Unreviewed staged revision/);
});
test('R6 production path/UID consumers and all raw/import/copy inputs reject',()=>{
 const p=stagedResources(both),entry=p.entries.find(e=>e.id===r6.id),glb=entry.paths.find(p=>p.endsWith('.glb'));
 for(const ref of ['res://'+glb.slice(6),read(glb+'.import').toString().match(/uid="([^"]+)"/)[1]])assert.throws(()=>stagedResources({...both,read:x=>x==='godot/ui/main_menu.gd'?Buffer.from('load("'+ref+'")'):read(x)}),/Production reference/);
 for(const f of entry.paths)assert.throws(()=>rejectStagedInputs([f],p),/Staged resource in runtime/);
});
test('recorded pre-W base retains only R5; original W ancestry activates R6 independently of ambient HEAD',()=>{
 const before=gitStagedResources(process.cwd(),'5f5a58c7');assert.equal(Object.keys(before.files).length,63);assert.equal(before.entries.length,1);
 const after=gitStagedResources(process.cwd(),'167ac4bc');assert.equal(Object.keys(after.files).length,137);assert.equal(after.entries.length,2);
});
const yPaths=git('ls-tree','-r','--name-only','-z','HEAD','--','godot').toString().split('\0').filter(Boolean);
const all={paths:yPaths,read,required:['foundry-r5','foundry-r6']};
const R7_MANIFEST='tools/godot-multiplayer/new-maps/gravemill-foundry/revision7/evidence/Y/final-manifest.json';
const R7_GLB='6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f';
const hash=b=>createHash('sha256').update(b).digest('hex');
test('R7 is promoted: runtime Foundry bytes match Y, revision namespace removed, R5/R6 remain staged',()=>{
 const manifest=JSON.parse(read(R7_MANIFEST));
 const native=Object.entries(manifest.files).filter(([p])=>p.startsWith('godot/')&&!p.startsWith('godot/tests/'));
 assert.equal(native.length,74);
 assert.equal(STAGED_ENTRIES.length,2);
 assert.equal(hash(read('godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb')),R7_GLB);
 for(const [p,r] of native){
  if(p.endsWith('.glb')||p.endsWith('.glb.import'))continue;
  const target=p.replace('art/revisions/gravemill-foundry-r7_','art/worlds/gravemill-foundry_');
  const bytes=read(target);
  if(p.endsWith('.import')){
   const text=bytes.toString();
   assert.ok(text.includes('source_file="res://multiplayer_worlds/art/worlds/gravemill-foundry_'),'Promoted sidecar path: '+target);
   assert.ok(!text.includes('art/revisions/'),'Promoted sidecar has no revision path: '+target);
   assert.ok(text.includes('path="res://.godot/imported/gravemill-foundry_'),'Promoted sidecar import cache: '+target);
   assert.ok(text.includes('dest_files=["res://.godot/imported/gravemill-foundry_'),'Promoted sidecar dest cache: '+target);
   assert.ok(!text.includes('gravemill-foundry-r7_'),'Promoted sidecar has no revision basename: '+target);
  } else {
   assert.equal(bytes.length,r.bytes,'Promoted R7 byte length: '+target);
   assert.equal(hash(bytes),r.sha256,'Promoted R7 asset: '+target);
  }
 }
 assert.equal(git('ls-files','godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7*').toString().trim(),'');
 assert.deepEqual(git('diff','--name-only','25c189bd','HEAD','--','godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7*').toString().trim().split('\n').filter(Boolean).length,74);
 const p=stagedResources(all);
 assert.equal(Object.keys(p.files).length,137);
 assert.ok(!Object.keys(p.files).some(f=>f.includes('gravemill-foundry-r7')));
 for(const f of ['godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb','godot/multiplayer_worlds/art/worlds/gravemill-foundry_aggregate-normal.png'])assert.ok(p.nativeFiles.includes(f),'Promoted runtime is native: '+f);
 const glb=read('godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb');
 assert.equal(glb.length,15012592);
 assert.equal(JSON.parse(glb.subarray(20,20+glb.readUInt32LE(12))).images.length,36);
});
test('R7 promotion does not weaken the remaining R5/R6 staged exclusions',()=>{
 const p=stagedResources(all),first=p.entries.find(e=>e.id==='foundry-r6').paths[0];
 assert.throws(()=>stagedResources({...all,paths:yPaths.filter(x=>x!==first)}),/Missing staged resource/);
 assert.throws(()=>stagedResources({...all,paths:[...yPaths,'godot/multiplayer_worlds/art/revisions/unreviewed-r8.glb']}),/Unreviewed staged revision/);
 const glb=p.entries.find(e=>e.id==='foundry-r6').paths.find(p=>p.endsWith('.glb'));
 assert.throws(()=>rejectStagedInputs([glb],p),/Staged resource in runtime/);
});
test('pre-Y recorded source requires only R5/R6; missing R6 ancestry still rejects R6 revisions',()=>{
 const before=gitStagedResources(process.cwd(),'167ac4bc');assert.equal(Object.keys(before.files).length,137);assert.deepEqual(before.provenance,STAGED_ENTRIES.map(e=>e.manifest));
 const after=gitStagedResources(process.cwd(),'HEAD');assert.equal(Object.keys(after.files).length,137);assert.equal(after.entries.length,2);
 // Same integrated artifact tree with a pre-R6 parent simulates copying or
 // cherry-picking R6 without preserving its activation ancestry. Git metadata
 // only: no asset checkout, copied binaries or source repository ref changes.
 const dir=mkdtempSync('/tmp/opencode/r6-no-ancestry-');
 const g=(args,input)=>execFileSync('git',args,{cwd:dir,input,env:{...process.env,GIT_AUTHOR_NAME:'Fixture',GIT_AUTHOR_EMAIL:'fixture@invalid',GIT_COMMITTER_NAME:'Fixture',GIT_COMMITTER_EMAIL:'fixture@invalid'},stdio:['pipe','pipe','pipe']});
 try{
  g(['init','-q']);writeFileSync(dir+'/.git/objects/info/alternates',git('rev-parse','--path-format=absolute','--git-path','objects').toString().trim()+'\n');
  const synthetic=g(['commit-tree',git('rev-parse','HEAD^{tree}').toString().trim(),'-p',git('rev-parse','5f5a58c7').toString().trim()],'no R6 ancestry fixture\n').toString().trim();
  assert.throws(()=>gitStagedResources(dir,synthetic),/Unreviewed staged revision/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});

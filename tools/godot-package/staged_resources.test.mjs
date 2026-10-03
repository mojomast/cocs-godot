import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {stagedResources,gitStagedResources,rejectStagedInputs,rejectStagedReferences,STAGED_MANIFEST,STAGED_MANIFEST_SHA,STAGED_CANDIDATE} from './staged_resources.mjs';
const read=p=>readFileSync(p),git=(...a)=>execFileSync('git',a,{maxBuffer:128*1024*1024});
const paths=git('ls-files','-z','--','godot').toString().split('\0').filter(Boolean),options={paths,read,required:true};
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

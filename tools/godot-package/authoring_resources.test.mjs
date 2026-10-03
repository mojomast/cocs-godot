import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {AUTHORING_CONTRACT,AUTHORING_COMMIT,authoringInventory,verifyAuthoringResources,rejectAuthoringRuntime} from './authoring_resources.mjs';
import {verifySourceState,rederiveClosure} from './manifest_validation.mjs';
import {verifySource} from '../godot-export/semantic.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const git=(...args)=>execFileSync('git',args,{maxBuffer:128*1024*1024,stdio:['pipe','pipe','pipe']});
const base='4cd806fa0783b1731505f8003e840bdc2f7d4786';
const lock=JSON.parse(read('port/contracts/source-lock.json')),movement=JSON.parse(read('port/contracts/movement-candidate-derivative.json'));
test('886 authoring files exactly enumerate immutable 9dc08e53, including failed archives and hidden metadata',()=>{
 const files=authoringInventory(read),paths=git('ls-tree','-r','--name-only','-z',AUTHORING_COMMIT,'--','assets/moth/map-variety-20261003').toString().split('\0').filter(Boolean).sort();
 assert.deepEqual(Object.keys(files),paths);assert.equal(paths.length,886);
 assert.equal(Object.values(files).reduce((n,r)=>n+r.bytes,0),133726498);
 for(const p of paths){const b=git('show',`${AUTHORING_COMMIT}:${p}`);assert.equal(hash(b),files[p].sha256);assert.equal(b.length,files[p].bytes);}
 const resolved=verifySource(lock,movement);assert.equal(Object.keys(resolved.runtime_files).length,13);
 for(const p of paths)assert.ok(!Object.hasOwn(resolved.runtime_files,p));
});
test('approved hash drift, missing inventory/entry and runtime shipping reject; old commit reads no ambient approval',()=>{
 const files=authoringInventory(read),first=Object.keys(files)[0],options={read,isAncestor:()=>true,sourceCommit:lock.source_commit,portCommit:base,added:Object.keys(files)};
 assert.throws(()=>verifyAuthoringResources({...options,read:p=>p===first?Buffer.alloc(files[first].bytes):read(p)}),/Authoring resource hash/);
 assert.throws(()=>verifyAuthoringResources({...options,read:p=>p===AUTHORING_CONTRACT?Buffer.from('{}'):read(p)}),/Exact authoring resource inventory/);
 assert.throws(()=>verifyAuthoringResources({...options,added:options.added.slice(1)}),/missing from source additions/);
 assert.throws(()=>rejectAuthoringRuntime([first],files),/cannot ship as runtime/);
 assert.throws(()=>rejectAuthoringRuntime(['runtime/'+first],files),/cannot ship as runtime/);
 assert.deepEqual(verifyAuthoringResources({...options,isAncestor:()=>false,read:()=>{throw Error('ambient read');}}),{});
});
test('actual integrated base plus exact contract passes recorded verification; extra assets and missing contract reject',()=>{
 // Git-object-only synthetic descendants of the actual integrated base. No
 // asset checkout/copy, engine, server or mutation of the shared repository.
 const dir=mkdtempSync('/tmp/opencode/authoring-source-'),env={...process.env,GIT_AUTHOR_NAME:'Source fixture',GIT_AUTHOR_EMAIL:'fixture@invalid',GIT_COMMITTER_NAME:'Source fixture',GIT_COMMITTER_EMAIL:'fixture@invalid'};
 const g=(args,input)=>execFileSync('git',args,{cwd:dir,env,input,maxBuffer:128*1024*1024,stdio:['pipe','pipe','pipe']});
 try{
  g(['init','-q']);mkdirSync(join(dir,'.git/objects/info'),{recursive:true});
  const objects=git('rev-parse','--path-format=absolute','--git-path','objects').toString().trim();
  writeFileSync(join(dir,'.git/objects/info/alternates'),objects+'\n');
  const commit=(path,bytes)=>{
   g(['read-tree',base]);const blob=g(['hash-object','-w','--stdin'],read(AUTHORING_CONTRACT)).toString().trim();
   g(['update-index','--add','--cacheinfo',`100644,${blob},${AUTHORING_CONTRACT}`]);
   if(path){const b=g(['hash-object','-w','--stdin'],bytes).toString().trim();g(['update-index','--add','--cacheinfo',`100644,${b},${path}`]);}
   return g(['commit-tree',g(['write-tree']).toString().trim(),'-p',base], 'source-only fixture\n').toString().trim();
  };
  const good=commit();
  const approved=verifySourceState(dir,lock.source_commit,movement,{portCommit:good});assert.equal(Object.keys(approved).length,886);
  const closure=rederiveClosure(dir,{port_commit:good},movement);
  rejectAuthoringRuntime([...Object.keys(closure.modules),...Object.keys(closure.adapterModules)],approved);
  for(const p of ['assets/unreviewed-resource.txt','assets/moth/map-variety-20261003/unreviewed.test.mjs']){
   const bad=commit(p,Buffer.from('unreviewed'));
   assert.throws(()=>verifySourceState(dir,lock.source_commit,movement,{portCommit:bad}),/Derivative source inventory/);
  }
  assert.throws(()=>verifySourceState(dir,lock.source_commit,movement,{portCommit:base}),/moth-authoring-resources|Committed object/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});

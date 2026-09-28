import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync,mkdirSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname,join} from 'node:path';
import {verifySource} from './semantic.mjs';

const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const names=['attachments','cocs-coop','cocs-economy','cocs','progression','core','singleplayer']
  .map(name=>`game/${name}.mjs`).concat('server/progression.mjs','server/room.mjs');

test('temporary Git checkout inventories the original lock and exactly ten combined runtime files',()=>{
 const root=mkdtempSync(join(tmpdir(),'cocs-source-inventory-'));
 const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
 const put=(path,contents)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),contents);};
 try{
  git('init','-q');git('config','user.email','fixture@example.invalid');git('config','user.name','Source fixture');
  for(const path of names)put(path,`export const original = ${JSON.stringify(path)};\n`);
  git('add','.');git('commit','-qm','locked source');
  const source_commit=git('rev-parse','HEAD'),lock={source_commit};
  verifySource(lock,null,root);
  put('game/stray.mjs','export const stray = true;\n');
  assert.throws(()=>verifySource(lock,null,root),/Locked source differs/, 'strict mode refuses an untracked new module');
  git('add','game/stray.mjs');
  assert.throws(()=>verifySource(lock,null,root),/Locked source differs/, 'strict mode refuses a staged new module');
  git('rm','-fq','game/stray.mjs');
  for(const path of names)put(path,`export const combined = ${JSON.stringify(path)};\n`);
  put('game/horde-stages.mjs','export const sourceStage = true;\n');
  git('add','.');git('commit','-qm','reviewed combined derivative');
  const derivative_commit=git('rev-parse','HEAD');
  const runtime_files=Object.fromEntries([...names,'game/horde-stages.mjs'].map(path=>[path,sha(readFileSync(join(root,path)))]));
  const derivative={schema_version:1,source_commit,derivative_commit,runtime_files};
  assert.equal(Object.keys(runtime_files).length,10);
  verifySource(lock,derivative,root);
  assert.throws(()=>verifySource(lock,{...derivative,runtime_files:{...runtime_files,'game/extra.mjs':sha('other')}},root),/inventory differs/,
    'invented inventory entry cannot authorize absent source');
  const {['game/horde-stages.mjs']:missing,...nine}=runtime_files;
  assert(missing);
  assert.throws(()=>verifySource(lock,{...derivative,runtime_files:nine},root),/inventory differs/,
    'new source module must be inventoried');
  assert.throws(()=>verifySource(lock,{...derivative,runtime_files:{...runtime_files,'game/core.mjs':'0'.repeat(64)}},root),/byte mismatch/);
  assert.throws(()=>verifySource(lock,{...derivative,runtime_files:{...runtime_files,'game/../server/evil.mjs':sha('other')}},root),/Invalid derivative source entry/,
    'untrusted manifest path is rejected before git show or filesystem reads');
  put('game/stray.mjs','export const stray = true;\n');
  assert.throws(()=>verifySource(lock,derivative,root),/inventory differs/, 'untracked extra cannot evade the derivative census');
  git('add','game/stray.mjs');
  assert.throws(()=>verifySource(lock,derivative,root),/inventory differs/, 'staged extra cannot evade the derivative census');
  git('rm','-fq','game/stray.mjs');
  verifySource(lock,derivative,root);
  put('game/late.mjs','export const late = true;\n');
  git('add','game/late.mjs');git('commit','-qm','late module outside reviewed derivative');
  const late={...derivative,runtime_files:{...runtime_files,'game/late.mjs':sha(readFileSync(join(root,'game/late.mjs')))}};
  assert.throws(()=>verifySource(lock,late,root),/game\/late\.mjs/,
    'a new module committed after the derivative is not present at the reviewed commit');
 }finally{rmSync(root,{recursive:true,force:true});}
});

test('selected combined derivative retains the seven LATTICE runtime hashes and adds only three Horde files',()=>{
 const derivative=JSON.parse(readFileSync(new URL('../../port/contracts/lattice-catalog-derivative.json',import.meta.url)));
 const lock=JSON.parse(readFileSync(new URL('../../port/contracts/source-lock.json',import.meta.url)));
 const original=JSON.parse(execFileSync('git',['show','89dd5745:port/contracts/lattice-catalog-derivative.json'],{encoding:'utf8'}));
 assert.equal(derivative.source_commit,lock.source_commit);
 assert.deepEqual(Object.keys(derivative.runtime_files).sort(),
  [...Object.keys(original.runtime_files),'game/core.mjs','game/horde-stages.mjs','game/singleplayer.mjs'].sort());
 for(const [path,hash] of Object.entries(original.runtime_files))assert.equal(derivative.runtime_files[path],hash,path);
 verifySource(lock,derivative);
});

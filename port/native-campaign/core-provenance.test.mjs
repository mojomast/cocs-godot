// Text-only checks: no engine import or simulation slot required.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {generateCampaignCore,SOURCE_SHA256} from './generate-core.mjs';
const source=readFileSync(new URL('../../game/core.mjs',import.meta.url),'utf8');
const generated=readFileSync(new URL('./core.generated.mjs',import.meta.url),'utf8');
test('explicit melee derivative preserves original identity and inventories every runtime change',()=>{
  const root=new URL('../../',import.meta.url);
  const git=(...args)=>execFileSync('git',args,{cwd:root});
  const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
  const lock=JSON.parse(readFileSync(new URL('port/contracts/source-lock.json',root)));
  const derivative=JSON.parse(readFileSync(new URL('port/contracts/lattice-catalog-derivative.json',root)));
  assert.equal(lock.source_commit,'515daf07589150dd3241f4ae1425cc1b093912f5');
  assert.equal(derivative.source_commit,lock.source_commit);
  assert.equal(git('merge-base',derivative.derivative_commit,'HEAD').toString().trim(),derivative.derivative_commit);
  const changed=git('diff','--name-only',lock.source_commit,'--','game','server').toString().trim().split('\n').filter(p=>p&&!p.endsWith('.test.mjs')).sort();
  assert.deepEqual(changed,Object.keys(derivative.runtime_files).sort());
  for(const [path,hash] of Object.entries(derivative.runtime_files)){
    assert.equal(sha(git('show',`${derivative.derivative_commit}:${path}`)),hash,path);
    assert.equal(sha(readFileSync(new URL(path,root))),hash,path);
    if(path!=='game/core.mjs')assert.equal(sha(git('show',`61fca35c65488502b794900cde0a5247bfb123bf:${path}`)),hash,path);
  }
  assert.equal(derivative.runtime_files['game/core.mjs'],SOURCE_SHA256);
});
test('committed static adapter is exactly reproducible from the pinned source',()=>{
  assert.equal(createHash('sha256').update(source).digest('hex'),SOURCE_SHA256);
  assert.equal(generated,generateCampaignCore(source));
  assert.throws(()=>generateCampaignCore(source+'\n'),/Locked core drift/);
});
test('independent inverse comparison preserves every source byte outside imports and actorHit',()=>{
  const sourceStart=source.indexOf('function actorHit('),sourceEnd=source.indexOf('function hitActor(',sourceStart);
  assert.ok(sourceStart>0&&sourceEnd>sourceStart);
  const body=generated.split('\n').slice(2).join('\n').replace(/from '\.\.\/\.\.\/game\//g,"from './");
  const start=body.indexOf('function actorHit('),end=body.indexOf('function hitActor(',start);
  assert.ok(start>0&&end>start);
  const restored=body.slice(0,start)+source.slice(sourceStart,sourceEnd)+body.slice(end);
  assert.equal(restored,source);
  assert.equal((generated.match(/from '\.\.\/\.\.\/game\//g)||[]).length,34);
  assert.ok(!/\b(?:eval|Function)\s*\(|\bimport\s*\(/.test(generated));
});

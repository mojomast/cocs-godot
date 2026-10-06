// Text-only checks: no engine import or simulation slot required.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {generateCampaignCore,SOURCE_SHA256,MOVEMENT_DEPENDENCY_SHA256,verifyCampaignMovementDependency} from './generate-core.mjs';
const source=readFileSync(new URL('../../game/core.mjs',import.meta.url),'utf8');
const generated=readFileSync(new URL('./core.generated.mjs',import.meta.url),'utf8');
test('movement candidate preserves historical derivative identity and inventories every runtime change',()=>{
  const root=new URL('../../',import.meta.url);
  const git=(...args)=>execFileSync('git',args,{cwd:root});
  const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
  const lock=JSON.parse(readFileSync(new URL('port/contracts/source-lock.json',root)));
  const derivative=JSON.parse(readFileSync(new URL('port/contracts/lattice-catalog-derivative.json',root)));
  const candidate=JSON.parse(readFileSync(new URL('port/contracts/movement-candidate-derivative.json',root)));
  assert.equal(lock.source_commit,'515daf07589150dd3241f4ae1425cc1b093912f5');
  assert.equal(derivative.source_commit,lock.source_commit);
  assert.equal(git('merge-base',derivative.derivative_commit,'HEAD').toString().trim(),derivative.derivative_commit);
  assert.equal(candidate.source_commit,lock.source_commit);
  assert.equal(candidate.parent_contract,'port/contracts/lattice-catalog-derivative.json');
  assert.equal(candidate.parent_derivative_commit,derivative.derivative_commit);
  assert.equal(candidate.derivative_commit,'91f58a1c5dcd85544574ba9cd11fcecd0d50d522');
  assert.equal(git('merge-base',candidate.derivative_commit,'HEAD').toString().trim(),candidate.derivative_commit);
  const expected={...derivative.runtime_files};
  const movementChanged=git('diff','--name-only',candidate.baseline_commit,candidate.derivative_commit,'--','game','server').toString().trim().split('\n').filter(p=>p&&!p.endsWith('.test.mjs')).sort();
  assert.deepEqual(movementChanged,Object.keys(candidate.runtime_overrides).sort());
  for(const [path,{before,after}] of Object.entries(candidate.runtime_overrides)){
    assert.equal(sha(git('show',`${candidate.baseline_commit}:${path}`)),before,path+' before');
    assert.equal(sha(git('show',`${candidate.derivative_commit}:${path}`)),after,path+' candidate');
    expected[path]=after;
  }
  const changed=git('diff','--name-only',lock.source_commit,candidate.derivative_commit,'--','game','server').toString().trim().split('\n').filter(p=>p&&!p.endsWith('.test.mjs')).sort();
  assert.deepEqual(changed,Object.keys(expected).sort());
  for(const [path,hash] of Object.entries(derivative.runtime_files)){
    assert.equal(sha(git('show',`${derivative.derivative_commit}:${path}`)),hash,path);
    if(path!=='game/core.mjs')assert.equal(sha(git('show',`61fca35c65488502b794900cde0a5247bfb123bf:${path}`)),hash,path);
  }
  const contact=JSON.parse(readFileSync(new URL('port/contracts/contact-candidate-derivative.json',root)));
  assert.equal(contact.runtime_overrides['game/core.mjs'].after,SOURCE_SHA256);
  assert.equal(expected['game/operator-verbs.mjs'],MOVEMENT_DEPENDENCY_SHA256);
});

test('active source descriptor resolves the reviewed overlay to current runtime bytes',async()=>{
  const root=new URL('../../',import.meta.url);
  const path=fileURLToPath(root);
  const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
  const {verifySource}=await import('../../tools/godot-export/semantic.mjs');
  const {activeSource}=await import('../../tools/godot-dev/active_source.mjs');
  const lock=JSON.parse(readFileSync(new URL('port/contracts/source-lock.json',root)));
  const selection=activeSource(path);
  assert.equal(selection.contract.derivative_commit,'8a6e7be2b9999338e556a9714a31861d097ef553');
  assert.equal(selection.contract.parent_contract,'port/contracts/racing-candidate-derivative.json');
  const resolved=verifySource(lock,selection.contract,path);
  assert.equal(resolved.derivative_commit,selection.contract.derivative_commit);
  // Every current tracked change is covered by the reviewed active source and
  // every reviewed active byte matches the working tree.
  const changed=execFileSync('git',['diff','--name-only',lock.source_commit,'--','game','server'],{cwd:path}).toString().trim().split('\n').filter(p=>p&&!p.endsWith('.test.mjs')).sort();
  assert.ok(changed.length>0);
  for(const p of changed)assert.ok(Object.hasOwn(resolved.runtime_files,p),p+' is not in the reviewed active source');
  for(const [p,hash] of Object.entries(resolved.runtime_files))assert.equal(sha(readFileSync(new URL(p,root))),hash,p+' current bytes');
});
test('committed static adapter is exactly reproducible from the pinned source',()=>{
  verifyCampaignMovementDependency();
  assert.throws(()=>verifyCampaignMovementDependency('changed'),/Locked operator dependency drift/);
  assert.equal(createHash('sha256').update(source).digest('hex'),SOURCE_SHA256);
  assert.equal(generated,generateCampaignCore(source));
  assert.throws(()=>generateCampaignCore(source+'\n'),/Locked core drift/);
});
test('independent inverse comparison preserves every source byte outside four reviewed adapters',()=>{
  const sourceStart=source.indexOf('function actorHit('),sourceEnd=source.indexOf('function hitActor(',sourceStart);
  assert.ok(sourceStart>0&&sourceEnd>sourceStart);
  const body=generated.split('\n').slice(2).join('\n').replace(/from '\.\.\/\.\.\/game\//g,"from './");
  const start=body.indexOf('function actorHit('),end=body.indexOf('function hitActor(',start);
  assert.ok(start>0&&end>start);
  const restored=(body.slice(0,start)+source.slice(sourceStart,sourceEnd)+body.slice(end)).replace('baseWeapon=this.projectileWeapon?.(r)??WEAPONS[r.weapon??1],w=altSpec?', 'baseWeapon=WEAPONS[r.weapon??1],w=altSpec?')
    .replaceAll('hit:clear?(target?.id??vehicleTarget?.id??sentryTarget?.id??false):false,falloff','hit:target?.id??vehicleTarget?.id??sentryTarget?.id??false,falloff');
  assert.equal(generated.split('hit:clear?').length-1,2);
  assert.equal(restored,source);
  assert.equal((generated.match(/from '\.\.\/\.\.\/game\//g)||[]).length,34);
  assert.ok(!/\b(?:eval|Function)\s*\(|\bimport\s*\(/.test(generated));
});

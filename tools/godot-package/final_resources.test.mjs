import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {finalResources,OPERATORS} from './final_resources.mjs';
import {verifyFinalProvenance} from './manifest_validation.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const read=path=>readFileSync(join(root,path));
const has=path=>existsSync(join(root,path));
test('actual final source content: all finish profiles/116 PNGs, 54 sounds, original Moth bytes; missing fighter assets block release',()=>{
  const audit=finalResources({read,has,requireFighters:false});
  assert.equal(Object.keys(audit.resources).filter(p=>p.startsWith('godot/source_operators/moth_finish/assets/')&&p.endsWith('.png')).length,116);
  assert.equal(Object.keys(audit.raw).filter(p=>p.endsWith('.wav')).length,54);
  assert.equal(Object.keys(audit.resources).filter(p=>p.startsWith('godot/source_operators/moth_finish/profiles/')).length,9);
  assert.ok(Object.hasOwn(audit.provenance,'game/moth-baked.mjs'));
  // Deliberately remove the real manifest/GLB family from the reader; never create
  // fake accepted rig content to make an unavailable art lane appear complete.
  assert.throws(()=>finalResources({read,has:p=>!p.startsWith('godot/fighting/assets/operators/')&&has(p)}),/requires all nine/);
  assert.deepEqual(finalResources({read,has:p=>!p.startsWith('godot/fighting/assets/operators/')&&has(p),requireFighters:false}).pending,OPERATORS);
});
test('missing/corrupt actual content fails for JSON, PCM, finish PNG, profile and baked provenance',()=>{
  for(const target of ['godot/fighting/assets/effects/audio/meta_attack.wav','godot/source_operators/moth_finish/assets/meta-shell-albedo.png','game/moth-baked.mjs']) {
    assert.throws(()=>finalResources({has,read:p=>p===target?Buffer.from('corrupt'):read(p),requireFighters:false}),/Content hash mismatch/);
    assert.throws(()=>finalResources({has,read:p=>{if(p===target)throw Error('fixture missing '+p);return read(p);},requireFighters:false}),/fixture missing/);
  }
  for(const target of ['godot/fighting/data/schema.json','godot/source_operators/moth_finish/profiles/meta.json'])
    assert.throws(()=>finalResources({has,read:p=>p===target?Buffer.from('{'):read(p),requireFighters:false}),SyntaxError);
});
test('FX inventory cannot omit a sound, repeat one, redirect paths or detach from roster',()=>{
  for(const mutate of [m=>m.files.pop(),m=>m.files[0]=m.files[1],m=>m.files[0].file='../escape.wav']) {
    const manifest=JSON.parse(read('godot/fighting/assets/effects/manifest.json'));mutate(manifest);
    assert.throws(()=>finalResources({has,read:p=>p==='godot/fighting/assets/effects/manifest.json'?Buffer.from(JSON.stringify(manifest)):read(p),requireFighters:false}),/54 fighting sounds/);
  }
  const catalog=JSON.parse(read('godot/fighting/assets/effects/catalog.json'));catalog.content_roster_sha256='0'.repeat(64);
  assert.throws(()=>finalResources({has,read:p=>p==='godot/fighting/assets/effects/catalog.json'?Buffer.from(JSON.stringify(catalog)):read(p),requireFighters:false}),/roster drift/);
});
test('actual finish bytes remain bound to the recorded commit despite dirty worktree and refreshed metadata',()=>{
  const fixture=mkdtempSync(join(tmpdir(),'final committed content '));
  const put=(p,b)=>{mkdirSync(dirname(join(fixture,p)),{recursive:true});writeFileSync(join(fixture,p),b);};
  const git=(...args)=>execFileSync('git',args,{cwd:fixture,encoding:'utf8',maxBuffer:16*1024*1024}).trim();
  try {
    const finish=finalResources({read,has:p=>p!=='godot/fighting/main.gd'&&has(p)});
    for(const p of [...Object.keys(finish.resources),...Object.keys(finish.provenance),'godot/source_operators/moth_finish/binder.gd'])put(p,read(p));
    put('tools/godot-package/build.py','# Recorded integrity fixture "final_resource_sha256"\n');
    git('init','-q');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','real finish bytes');
    const manifest={final_resource_sha256:finish.resources,final_provenance_sha256:finish.provenance,raw_resource_sha256:{},raw_export_plugin_sha256:null};
    const identity={port_commit:git('rev-parse','HEAD'),manifest};
    verifyFinalProvenance(fixture,identity);
    const path='godot/source_operators/moth_finish/assets/meta-shell-albedo.png';put(path,Buffer.from('dirty checkout'));
    verifyFinalProvenance(fixture,identity);
    manifest.final_resource_sha256[path]='0'.repeat(64);
    assert.throws(()=>verifyFinalProvenance(fixture,identity),/differs from recorded content closure/);
    delete manifest.final_resource_sha256;
    assert.throws(()=>verifyFinalProvenance(fixture,identity),/missing/);
  } finally {rmSync(fixture,{recursive:true,force:true});}
});

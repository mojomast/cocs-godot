import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync,existsSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {BASE_WORLDS,worldClosure,worldArt} from './world_closure.mjs';
import {coverage} from './verify_expansion.mjs';
import {copyReplayRuntime,REPLAY_FILES} from './replay_runtime.mjs';
import {verifyReplayRuntime,verifyFeatureProvenance} from './manifest_validation.mjs';
import {featureResources} from './feature_resources.mjs';
const hash=b=>createHash('sha256').update(b).digest('hex');
const base=()=>Object.fromEntries(Object.entries(BASE_WORLDS).map(([id,modes])=>[id,{modes:[...modes]}]));
test('catalog grants only registered reviewed pairs, preserves all original pairs and named asset paths',()=>{
  const worlds=base();assert.equal(worldClosure(worlds).length,7);
  worlds['vesper-viaduct']={modes:['deathmatch','ctf']};
  const manifest={server_closure:{worldDataFiles:worldClosure(worlds),hordeDataFiles:['godot/horde_maps/generated/blackwater-reclamation.json']}};
  assert.equal(coverage(manifest,worlds).length,45);
  assert.equal(worldArt('vesper-viaduct'),'res://multiplayer_worlds/art/vesper-viaduct/vesper-viaduct.glb');
  assert.equal(worldArt('sirocco-circuit'),'res://multiplayer_worlds/art/worlds/sirocco-circuit.glb');
  worlds['vesper-viaduct'].modes=[];assert.throws(()=>worldClosure(worlds),/Invalid accepted modes/);
  delete worlds['vesper-viaduct'];worlds['random-map']={modes:['deathmatch']};assert.throws(()=>worldClosure(worlds),/Unreviewed world/);
  delete worlds['random-map'];worlds['switchyard-ward'].modes.pop();assert.throws(()=>worldClosure(worlds),/Original accepted/);
});
test('committed replay bytes copied exactly; forged refreshed inventories, absent helpers and dirty inputs fail',()=>{
  const root=mkdtempSync(join(tmpdir(),'replay committed fixture '));
  const put=(path,bytes)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),bytes);};
  const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
  try {
    put('game/demo.mjs','export const fixture = true;\n');
    put('godot/replay/admission.json',JSON.stringify({demoSha256:hash(readFileSync(join(root,'game/demo.mjs')))}));
    put('tools/port/replay/adapter.mjs','// integrity fixture; not runtime acceptance\n');
    put('tools/port/replay/service.mjs','// integrity fixture; not runtime acceptance\n');
    put('godot/replay/bridge.gd','extends Node\n');
    git('init','-q');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','recorded');
    const commit=git('rev-parse','HEAD'), output=join(root,'package/replay-runtime');
    const hashes=copyReplayRuntime(root,output,commit);
    const identity={port_commit:commit,files:Object.fromEntries([...REPLAY_FILES,'manifest.json'].map(path=>['replay-runtime/'+path,hash(readFileSync(join(output,path)))])),manifest:{replay_runtime_sha256:hashes}};
    verifyReplayRuntime(root,identity,join(root,'package'));
    assert.throws(()=>copyReplayRuntime(root,output,commit),/fresh/);
    put('tools/port/replay/service.mjs','dirty checkout');
    verifyReplayRuntime(root,identity,join(root,'package')); // Recorded bytes, not HEAD/worktree.
    assert.throws(()=>copyReplayRuntime(root,join(root,'refused'),commit),/differs from recorded/);
    assert.equal(existsSync(join(root,'refused')),false);
    writeFileSync(join(output,'tools/port/replay/service.mjs'),'tamper');
    hashes['tools/port/replay/service.mjs']=hash('tamper');
    const own=JSON.parse(readFileSync(join(output,'manifest.json')));own.files=hashes;
    writeFileSync(join(output,'manifest.json'),JSON.stringify(own));
    assert.throws(()=>verifyReplayRuntime(root,identity,join(root,'package')),/differs from recorded/);
    rmSync(join(output,'tools/port/replay/service.mjs'));
    assert.throws(()=>verifyReplayRuntime(root,identity,join(root,'package')));
  } finally {rmSync(root,{recursive:true,force:true});}
});
test('feature catalogs require their actual inputs and InputBindings autoload; unrelated JSON is ignored',()=>{
  const root=mkdtempSync(join(tmpdir(),'feature resources '));
  const put=(path,bytes)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),bytes);};
  try {
    put('godot/unrelated.json','{}');assert.deepEqual(featureResources(root),[]);
    put('godot/input_bindings/service.gd','extends Node');
    assert.throws(()=>featureResources(root),/ENOENT/);
    put('godot/input_bindings/contexts.json','{}');put('godot/project.godot','[autoload]\n');
    assert.throws(()=>featureResources(root),/autoload missing/);
    put('godot/project.godot','[autoload]\nInputBindings="*res://input_bindings/service.gd"\n');
    assert.deepEqual(featureResources(root),['godot/input_bindings/contexts.json']);
    put('godot/experience/kill_feed.gd','extends Node');put('godot/experience/public_event_types.json','malformed');
    assert.throws(()=>featureResources(root),SyntaxError);
  } finally {rmSync(root,{recursive:true,force:true});}
});
test('feature provenance cannot omit committed JSON or substitute a refreshed hash',()=>{
  const root=mkdtempSync(join(tmpdir(),'feature provenance '));
  const put=(path,bytes)=>{mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),bytes);};
  const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
  try {
    put('tools/godot-package/build.py','# fixture declares "feature_resource_sha256"\n');
    put('godot/input_bindings/service.gd','extends Node\n');
    const path='godot/input_bindings/contexts.json';put(path,'{"schema":1}\n');
    git('init','-q');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','recorded');
    const identity={port_commit:git('rev-parse','HEAD'),manifest:{feature_resource_sha256:{[path]:hash(readFileSync(join(root,path)))}}};
    verifyFeatureProvenance(root,identity);
    put(path,'dirty checkout');verifyFeatureProvenance(root,identity);
    identity.manifest.feature_resource_sha256[path]=hash('dirty checkout');
    assert.throws(()=>verifyFeatureProvenance(root,identity),/differs from recorded/);
    identity.manifest.feature_resource_sha256={};
    assert.throws(()=>verifyFeatureProvenance(root,identity),/Committed feature resource closure/);
    delete identity.manifest.feature_resource_sha256;
    assert.throws(()=>verifyFeatureProvenance(root,identity),/provenance missing/);
  } finally {rmSync(root,{recursive:true,force:true});}
});

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync,readFileSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {dressingResources} from './dressing_resources.mjs';
import {verifyDressingProvenance} from './manifest_validation.mjs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {worldArt} from './world_closure.mjs';
test('optional profiles are explicit hashed/exportable inputs only for registered maps',()=>{
  assert.equal(worldArt('gravemill-foundry'),'res://multiplayer_worlds/art/worlds/gravemill-foundry.glb');
  const root=mkdtempSync('/tmp/opencode/dressing-closure-');
  const put=(p,v)=>{mkdirSync(dirname(join(root,p)),{recursive:true});writeFileSync(join(root,p),JSON.stringify(v));};
  try {
    const worlds={'helix-conservatory':{},'gravemill-foundry':{}};
    assert.deepEqual(dressingResources(root,worlds),[]);
    for(const id of ['helix-conservatory','gravemill-foundry','parallax-observatory']) {
      put(`godot/multiplayer_worlds/generated/${id}.json`,{geometryHash:'a'.repeat(64)});
      put(`godot/multiplayer_worlds/dressing/profiles/${id}.json`,{version:1,map_id:id,geometry_hash:'a'.repeat(64)});
    }
    const result=dressingResources(root,worlds);
    assert.equal(result.length,2);assert.ok(!result.some(p=>p.includes('parallax')));
    worlds['parallax-observatory']={};assert.equal(dressingResources(root,worlds).length,3);
    put('godot/multiplayer_worlds/dressing/profiles/helix-conservatory.json',{version:1,map_id:'helix-conservatory',geometry_hash:'bad'});
    assert.throws(()=>dressingResources(root,worlds),/identity mismatch/);
    put('godot/multiplayer_worlds/dressing/profiles/helix-conservatory.json',{version:2});
    assert.throws(()=>dressingResources(root,worlds),/identity mismatch/);
    const build=readFileSync(new URL('./build.py',import.meta.url),'utf8');
    assert.match(build,/dressing_files/);assert.match(build, /join\(dressing_files\)/);
    assert.ok(!build.includes('dressing/profiles/*.json'));
  } finally {rmSync(root,{recursive:true,force:true});}
});
test('committed profile provenance rejects omitted profiles and refreshed dirty hashes',()=>{
  const root=mkdtempSync('/tmp/opencode/dressing-provenance-');
  const put=(p,v)=>{mkdirSync(dirname(join(root,p)),{recursive:true});writeFileSync(join(root,p),v);};
  const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
  const hash=b=>createHash('sha256').update(b).digest('hex');
  const path='godot/multiplayer_worlds/dressing/profiles/helix-conservatory.json';
  try {
    put('tools/godot-package/build.py','# fixture "dressing_resource_sha256"\n');put(path,'{"version":1}\n');
    git('init','-q');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','recorded');
    const identity={port_commit:git('rev-parse','HEAD'),worldDataFiles:['godot/multiplayer_worlds/generated/helix-conservatory.json'],manifest:{dressing_resource_sha256:{[path]:hash(readFileSync(join(root,path)))}}};
    verifyDressingProvenance(root,identity);
    put(path,'dirty');verifyDressingProvenance(root,identity);
    identity.manifest.dressing_resource_sha256[path]=hash('dirty');assert.throws(()=>verifyDressingProvenance(root,identity),/differs from recorded/);
    identity.manifest.dressing_resource_sha256={};assert.throws(()=>verifyDressingProvenance(root,identity),/Committed dressing resource closure/);
    delete identity.manifest.dressing_resource_sha256;assert.throws(()=>verifyDressingProvenance(root,identity),/provenance missing/);
  } finally {rmSync(root,{recursive:true,force:true});}
});

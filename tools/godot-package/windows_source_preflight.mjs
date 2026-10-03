// No engine, export or archive. Exercise actual recorded-object verification
// on a real Windows host before spending time on another package build.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {rederiveClosure,verifySourceState,verifyFinalProvenance,verifyProductionProvenance} from './manifest_validation.mjs';
import {finalResources} from './final_resources.mjs';
import {fighterImports} from './fighter_imports.mjs';
import {channelProduction,buildIntent} from './build_channel.mjs';
assert.equal(process.platform,'win32','Real Windows source preflight required');
const root=fileURLToPath(new URL('../../',import.meta.url));
const git=args=>execFileSync('git',args,{cwd:root,maxBuffer:256*1024*1024});
const commit=git(['rev-parse','HEAD']).toString().trim();assert.equal(commit,process.env.GITHUB_SHA);
const paths=new Set(git(['ls-tree','-r','--name-only','-z',commit]).toString().split('\0')),cache=new Map();
const read=p=>{
  if(!cache.has(p)) {
    const bytes=git(['show',`${commit}:${p}`]);
    assert.deepEqual(readFileSync(join(root,p)),bytes,`Checkout differs from Git bytes: ${p}`);
    cache.set(p,bytes);
  }
  return cache.get(p);
};
const has=p=>paths.has(p),hash=b=>createHash('sha256').update(b).digest('hex');
const lock=JSON.parse(read('port/contracts/source-lock.json')),derivative=JSON.parse(read('port/contracts/lattice-catalog-derivative.json'));
verifySourceState(root,lock.source_commit,derivative,{portCommit:commit});
const closure=rederiveClosure(root,{port_commit:commit},derivative);
assert.equal(closure.worldDataFiles.length,10);
for(const p of [...Object.keys(closure.modules),...Object.keys(closure.adapterModules)])assert.ok(!p.includes('\\'));
const final=finalResources({read,has}),imports=fighterImports({read,has});
const options={read,has,worldIds:closure.worldDataFiles.map(p=>p.split('/').at(-1).slice(0,-5))};
const production=channelProduction(options,'preview'),intent=buildIntent(commit,'preview',production);
assert.deepEqual(production.pending,['scenery','vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
assert.throws(()=>channelProduction(options,'final'),/remain pending/);
const manifest={...intent,build_intent:intent,final_resource_sha256:final.resources,final_provenance_sha256:final.provenance,raw_resource_sha256:final.raw,
 raw_export_plugin_sha256:hash(read('tools/godot-package/raw_export_plugin.gd')),fighter_import_sha256:imports,
 fighter_import_generator_sha256:hash(read('tools/fighting/animation/prepare_native.py')),
 production_resource_sha256:production.resources,production_provenance_sha256:production.provenance,production_raw_resource_sha256:production.raw};
const identity={port_commit:commit,worldDataFiles:closure.worldDataFiles,manifest};
verifyFinalProvenance(root,identity);verifyProductionProvenance(root,identity);
console.log(JSON.stringify({status:'passed',platform:process.platform,commit,sourceModules:Object.keys(closure.modules).length,adapters:Object.keys(closure.adapterModules).length,worlds:closure.worldDataFiles.length,fighterImports:Object.keys(imports).length,gitBytesChecked:cache.size,pending:production.pending},null,2));

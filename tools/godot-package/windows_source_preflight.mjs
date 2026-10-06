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
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
import {MOVEMENT_CONTRACT} from './source_derivative.mjs';
import {RACING_CONTRACT} from './racing_derivative.mjs';
import {resolveReviewedDerivative} from './contact_derivative.mjs';
import {rejectAuthoringRuntime} from './authoring_resources.mjs';
import {gitStagedResources,rejectStagedInputs} from './staged_resources.mjs';
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
const lock=JSON.parse(read('port/contracts/source-lock.json')),contractPath=has(RACING_CONTRACT)?RACING_CONTRACT:MOVEMENT_CONTRACT,derivative=resolveReviewedDerivative(JSON.parse(read(contractPath)),read,(rev,p)=>git(['show',`${rev}:${p}`]),(a,b)=>git(['merge-base',a,b]).toString().trim()===a);
// Source-only generator check, with exact committed generator/output/operator bytes.
for(const p of ['port/native-campaign/generate-core.mjs','port/native-campaign/core.generated.mjs','game/core.mjs','game/operator-verbs.mjs'])read(p);
execFileSync(process.execPath,['port/native-campaign/generate-core.mjs','--check'],{cwd:root});
const authoring=verifySourceState(root,lock.source_commit,derivative,{portCommit:commit});
const closure=rederiveClosure(root,{port_commit:commit},derivative);
rejectAuthoringRuntime([...Object.keys(closure.modules),...Object.keys(closure.adapterModules)],authoring);
read('port/multiplayer-worlds/catalog.mjs'); // bind imported registry to exact Git bytes
assert.deepEqual([...closure.worldDataFiles].sort(),Object.keys(WORLDS).map(id=>`godot/multiplayer_worlds/generated/${id}.json`).sort());
assert.equal(closure.worldDataFiles.length,13);
const pairs=Object.entries(WORLDS).flatMap(([id,world])=>world.modes.map(mode=>`${id}/${mode}`));
assert.equal(pairs.length,73);assert.equal(new Set(pairs).size,73);
for(const p of [...Object.keys(closure.modules),...Object.keys(closure.adapterModules)])assert.ok(!p.includes('\\'));
const final=finalResources({read,has}),imports=fighterImports({read,has});
const options={read,has,worldIds:closure.worldDataFiles.map(p=>p.split('/').at(-1).slice(0,-5))};
const production=channelProduction(options,'final'),intent=buildIntent(commit,'final',production);
const staged=gitStagedResources(root,commit,{consumers:[...Object.keys(closure.modules),...Object.keys(closure.adapterModules),...closure.worldDataFiles,...closure.campaignDataFiles,...closure.hordeDataFiles]});
rejectStagedInputs([...Object.keys(final.resources),...Object.keys(final.raw),...Object.keys(imports),...Object.keys(production.resources),...Object.keys(production.raw)],staged);
assert.deepEqual(production.pending,[]);
const manifest={...intent,build_intent:intent,final_resource_sha256:final.resources,final_provenance_sha256:final.provenance,raw_resource_sha256:final.raw,
 raw_export_plugin_sha256:hash(read('tools/godot-package/raw_export_plugin.gd')),fighter_import_sha256:imports,
 fighter_import_generator_sha256:hash(read('tools/fighting/animation/prepare_native.py')),
 production_resource_sha256:production.resources,production_provenance_sha256:production.provenance,production_raw_resource_sha256:production.raw};
const identity={port_commit:commit,worldDataFiles:closure.worldDataFiles,manifest};
verifyFinalProvenance(root,identity);verifyProductionProvenance(root,identity);
console.log(JSON.stringify({status:'passed',scope:'source-only; not frozen package or native acceptance',platform:process.platform,node:process.version,commit,sourceModules:Object.keys(closure.modules).length,adapters:Object.keys(closure.adapterModules).length,worlds:closure.worldDataFiles.length,pairs:pairs.length,buildChannel:'final',fighterImports:Object.keys(imports).length,gitBytesChecked:cache.size,pending:production.pending},null,2));

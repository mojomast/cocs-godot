import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {productionResources} from './production_resources.mjs';
import {verifySourceState} from './manifest_validation.mjs';
const cwd=fileURLToPath(new URL('../../',import.meta.url));
const git=args=>execFileSync('git',args,{cwd,maxBuffer:128*1024*1024});

test('committed seven-unit promotion and import bytes validate independently of worktree reads',()=>{
  const commit=git(['rev-parse','HEAD']).toString().trim();
  const paths=new Set(git(['ls-tree','-r','--name-only',commit]).toString().trim().split('\n')),cache=new Map();
  const read=p=>{if(!cache.has(p))cache.set(p,git(['show',`${commit}:${p}`]));return cache.get(p);};
  // Recorded native registry, independently of the current JS catalog module.
  const registry=read('godot/multiplayer_worlds/catalog.gd').toString();
  assert.match(registry,/"parallax-observatory"/);
  const options={read,has:p=>paths.has(p),worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway'],strict:true};
  const result=productionResources(options);
  verifySourceState(cwd,JSON.parse(read('port/contracts/source-lock.json')).source_commit,
    JSON.parse(read('port/contracts/movement-candidate-derivative.json')),{portCommit:commit});
  assert.deepEqual(result.pending,[]);
  assert.throws(()=>productionResources({...options,worldIds:options.worldIds.slice(0,-1)}),/remain pending/);
  for(const id of ['abyssal-pressureworks','vesper-viaduct','scenery','robots','vehicles','parallax-interiors','stormglass-causeway']) {
    const receipt=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));
    const advance=receipt.movementAdvance,previous=advance.previousReceipt;
    const bytes=git(['show',`${previous.commit}:${previous.path}`]);
    assert.equal(createHash('sha256').update(bytes).digest('hex'),previous.sha256);
    const old=JSON.parse(bytes);
    assert.equal(previous.commit,'f61f6156d9575d8dcf44ca4daf7a09bef727b034');
    const oldInputs=old.packageInputs??old.packageInputHashes;
    const changed={},added={};
    for(const [p,sha]of Object.entries(oldInputs)) {
      assert.ok(Object.hasOwn(receipt.packageInputs,p),'Previous input dropped: '+p);
      if(receipt.packageInputs[p]!==sha)changed[p]={before:sha,after:receipt.packageInputs[p]};
    }
    for(const [p,sha]of Object.entries(receipt.packageInputs))if(!Object.hasOwn(oldInputs,p))added[p]=sha;
    assert.deepEqual(advance.changed,changed);
    assert.deepEqual(advance.added,added);
    for(const [key,value]of Object.entries(old))if(key!=='packageInputs'&&key!=='runtimeHooks')assert.deepEqual(receipt[key],value);
    for(const [p,sha]of Object.entries(old.runtimeHooks??receipt.nativeRuntimeHooks)) {
      const change=advance.runtimeChanged[p];
      if(change){assert.equal(id,'robots');assert.equal(change.before,sha);assert.equal(sha,receipt.runtimeHooks[p]);assert.equal(change.after,receipt.packageInputs[p]);}
      else assert.equal(receipt.runtimeHooks[p],sha);
    }
    assert.equal(createHash('sha256').update(JSON.stringify(oldInputs)).digest('hex'),advance.previousPackageFingerprint);
    assert.equal(createHash('sha256').update(JSON.stringify(receipt.packageInputs)).digest('hex'),advance.packageFingerprint);
  }
  const image='godot/robot_assets/switchyard/generated/needle_surveyor_MothLocal_Switchyard_vertex_enamel.png';
  assert.throws(()=>productionResources({...options,read:p=>p===image?Buffer.from('forged'):read(p)}),/content hash mismatch/);
  const vehicleSidecar='godot/vehicle_assets/generated/puma-lod0.glb.import';
  assert.throws(()=>productionResources({...options,read:p=>p===vehicleSidecar?Buffer.from('forged'):read(p)}),/content hash mismatch/);
  const master='tools/godot-vehicle-assets/masters/puma-lod0.blend';
  assert.ok(productionResources({...options,strict:false,has:p=>p!==master&&paths.has(p)}).pending.includes('vehicles'));
  for(const id of ['robots','parallax-interiors','vehicles']) {
    const receipt=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));
    const previous=receipt.packageVerifierAdvance.previousReceipt;
    const oldBytes=git(['show',`${previous.commit}:${previous.path}`]);
    assert.equal(createHash('sha256').update(oldBytes).digest('hex'),previous.sha256);
    const old=JSON.parse(oldBytes);
    for(const key of ['sourceHashes','sourceFingerprint','masters','exports','rawFiles'])assert.deepEqual(receipt[key],old[key],`${id}: production identity preserved: ${key}`);
    for(const [p,sha]of Object.entries(old.runtimeHooks))assert.equal(receipt.vesperPackageVerifierAdvance.runtimeChanged[p]?.before??receipt.abyssalPackageVerifierAdvance.runtimeChanged[p]?.before??receipt.featureAdvance.runtimeChanged[p]?.before??receipt.stormglassPackageVerifierAdvance.runtimeChanged[p]?.before??receipt.runtimeHooks[p],sha);
    assert.deepEqual(Object.keys(receipt.packageVerifierAdvance.changed),['tools/godot-package/production_resources.mjs']);
    if(id==='robots') {
      const revision=receipt.packageReconciliation.supportingRuntimeRevision;
      assert.equal(revision.path,'godot/biomes/expansion/scenery_pack.gd');
      assert.equal(revision.after,createHash('sha256').update(read(revision.path)).digest('hex'));
      assert.notEqual(revision.before,revision.after);
      assert.equal(receipt.packageReconciliation.added[revision.path],revision.after);
    }
  }
});

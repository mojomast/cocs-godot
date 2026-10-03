import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {productionResources} from './production_resources.mjs';
const cwd=fileURLToPath(new URL('../../',import.meta.url));
const git=args=>execFileSync('git',args,{cwd,maxBuffer:128*1024*1024});

test('committed six-unit promotion and import bytes validate independently of worktree reads',()=>{
  const commit=git(['rev-parse','HEAD']).toString().trim();
  const paths=new Set(git(['ls-tree','-r','--name-only',commit]).toString().trim().split('\n')),cache=new Map();
  const read=p=>{if(!cache.has(p))cache.set(p,git(['show',`${commit}:${p}`]));return cache.get(p);};
  // Recorded native registry, independently of the current JS catalog module.
  const registry=read('godot/multiplayer_worlds/catalog.gd').toString();
  assert.match(registry,/"parallax-observatory"/);
  const options={read,has:p=>paths.has(p),worldIds:['parallax-observatory','vesper-viaduct','abyssal-pressureworks'],strict:false};
  const result=productionResources(options);
  assert.deepEqual(result.pending,['stormglass-causeway']);
  assert.throws(()=>productionResources({...options,strict:true}),/remain pending/);
  for(const id of ['abyssal-pressureworks','vesper-viaduct','scenery','robots','vehicles','parallax-interiors']) {
    const receipt=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));
    const advance=receipt.featureAdvance,previous=advance.previousReceipt;
    const bytes=git(['show',`${previous.commit}:${previous.path}`]);
    assert.equal(createHash('sha256').update(bytes).digest('hex'),previous.sha256);
    const old=JSON.parse(bytes);
    assert.equal(previous.commit,'a5c26f25');
    const changed={},added={};
    for(const [p,sha]of Object.entries(old.packageInputs)) {
      assert.ok(Object.hasOwn(receipt.packageInputs,p),'Previous input dropped: '+p);
      if(receipt.packageInputs[p]!==sha)changed[p]={before:sha,after:receipt.packageInputs[p]};
    }
    for(const [p,sha]of Object.entries(receipt.packageInputs))if(!Object.hasOwn(old.packageInputs,p))added[p]=sha;
    assert.deepEqual(advance.changed,changed);
    assert.deepEqual(advance.added,added);
    for(const [key,value]of Object.entries(old))if(key!=='packageInputs'&&key!=='runtimeHooks')assert.deepEqual(receipt[key],value);
    for(const [p,sha]of Object.entries(old.runtimeHooks)) {
      const change=advance.runtimeChanged[p];
      if(change){assert.ok(['robots','vehicles'].includes(id));assert.equal(change.before,sha);assert.equal(change.after,receipt.runtimeHooks[p]);}
      else assert.equal(receipt.runtimeHooks[p],sha);
    }
    assert.equal(createHash('sha256').update(JSON.stringify(old.packageInputs)).digest('hex'),advance.previousPackageFingerprint);
    assert.equal(createHash('sha256').update(JSON.stringify(receipt.packageInputs)).digest('hex'),advance.packageFingerprint);
  }
  const image='godot/robot_assets/switchyard/generated/needle_surveyor_MothLocal_Switchyard_vertex_enamel.png';
  assert.throws(()=>productionResources({...options,read:p=>p===image?Buffer.from('forged'):read(p)}),/content hash mismatch/);
  const vehicleSidecar='godot/vehicle_assets/generated/puma-lod0.glb.import';
  assert.throws(()=>productionResources({...options,read:p=>p===vehicleSidecar?Buffer.from('forged'):read(p)}),/content hash mismatch/);
  const master='tools/godot-vehicle-assets/masters/puma-lod0.blend';
  assert.ok(productionResources({...options,has:p=>p!==master&&paths.has(p)}).pending.includes('vehicles'));
  for(const id of ['robots','parallax-interiors','vehicles']) {
    const receipt=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));
    const previous=receipt.packageVerifierAdvance.previousReceipt;
    const oldBytes=git(['show',`${previous.commit}:${previous.path}`]);
    assert.equal(createHash('sha256').update(oldBytes).digest('hex'),previous.sha256);
    const old=JSON.parse(oldBytes);
    for(const key of ['sourceHashes','sourceFingerprint','masters','exports','rawFiles'])assert.deepEqual(receipt[key],old[key],`${id}: production identity preserved: ${key}`);
    for(const [p,sha]of Object.entries(old.runtimeHooks))assert.equal(receipt.vesperPackageVerifierAdvance.runtimeChanged[p]?.before??receipt.abyssalPackageVerifierAdvance.runtimeChanged[p]?.before??receipt.featureAdvance.runtimeChanged[p]?.before??receipt.runtimeHooks[p],sha);
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

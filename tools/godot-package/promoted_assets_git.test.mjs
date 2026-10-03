import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {productionResources} from './production_resources.mjs';
const cwd=fileURLToPath(new URL('../../',import.meta.url));
const git=args=>execFileSync('git',args,{cwd,maxBuffer:128*1024*1024});

test('committed two-unit promotion and import bytes validate independently of worktree reads',()=>{
  const commit=git(['rev-parse','HEAD']).toString().trim();
  const paths=new Set(git(['ls-tree','-r','--name-only',commit]).toString().trim().split('\n')),cache=new Map();
  const read=p=>{if(!cache.has(p))cache.set(p,git(['show',`${commit}:${p}`]));return cache.get(p);};
  // Recorded native registry, independently of the current JS catalog module.
  const registry=read('godot/multiplayer_worlds/catalog.gd').toString();
  assert.match(registry,/"parallax-observatory"/);
  const options={read,has:p=>paths.has(p),worldIds:['parallax-observatory'],strict:false};
  const result=productionResources(options);
  assert.deepEqual(result.pending,['vehicles','scenery','vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
  assert.throws(()=>productionResources({...options,strict:true}),/remain pending/);
  const image='godot/robot_assets/switchyard/generated/needle_surveyor_MothLocal_Switchyard_vertex_enamel.png';
  assert.throws(()=>productionResources({...options,read:p=>p===image?Buffer.from('forged'):read(p)}),/content hash mismatch/);
  for(const id of ['robots','parallax-interiors']) {
    const receipt=JSON.parse(read(`tools/godot-package/production_receipts/${id}.json`));
    const previous=receipt.packageReconciliation.previousReceipt;
    const oldBytes=git(['show',`${previous.commit}:${previous.path}`]);
    assert.equal(createHash('sha256').update(oldBytes).digest('hex'),previous.sha256);
    const old=JSON.parse(oldBytes);
    for(const key of ['sourceHashes','sourceFingerprint','masters','exports','runtimeHooks','rawFiles'])assert.deepEqual(receipt[key],old[key],`${id}: production identity preserved: ${key}`);
    assert.deepEqual(Object.keys(receipt.packageReconciliation.changed),['tools/godot-package/production_resources.mjs']);
    if(id==='robots') {
      const revision=receipt.packageReconciliation.supportingRuntimeRevision;
      assert.equal(revision.path,'godot/biomes/expansion/scenery_pack.gd');
      assert.equal(revision.after,createHash('sha256').update(read(revision.path)).digest('hex'));
      assert.notEqual(revision.before,revision.after);
      assert.equal(receipt.packageReconciliation.added[revision.path],revision.after);
    }
  }
});

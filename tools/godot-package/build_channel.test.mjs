import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {channelProduction,buildIntent,verifyChannelManifest,previewReadme} from './build_channel.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const read=p=>readFileSync(root+p),has=p=>existsSync(root+p);
const options={read,has,worldIds:Object.keys(WORLDS)},commit='a'.repeat(40);
test('preview permits exactly unpromoted pending production; final remains strict',()=>{
  const result=channelProduction(options,'preview');
  assert.deepEqual(result.pending,['vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
  assert.throws(()=>channelProduction(options),/remain pending/);
  assert.throws(()=>channelProduction(options,'unknown'),/Unknown build channel/);
  const path='godot/vehicle_assets/generated/puma-lod0.glb';
  assert.throws(()=>channelProduction({...options,has:p=>p!==path&&has(p)},'preview'),/Promoted production unit unavailable/);
  assert.throws(()=>channelProduction({...options,read:p=>p===path?Buffer.from('tamper'):read(p)},'preview'),/content hash mismatch/);
});
test('channel, flag, pending names and recorded intent must agree; historical final cannot downgrade',()=>{
  const result=channelProduction(options,'preview'),intent=buildIntent(commit,'preview',result);
  const manifest={...intent,build_intent:intent},builder='"build_channel"';
  assert.deepEqual(verifyChannelManifest(manifest,builder,result),intent);
  for(const change of [{build_channel:'final'},{build_flags:[]},{pending_production:[]},{pending_production:['unknown']},{verification_limits:[]},{build_intent:{...intent,build_channel:'final'}}])
    assert.throws(()=>verifyChannelManifest({...manifest,...change},builder,result));
  assert.throws(()=>verifyChannelManifest(manifest,'historical strict builder',result),/Historical/);
  assert.match(previewReadme(intent,'Original instructions'),/^# PREVIEW/);
  assert.match(previewReadme(intent,'Original instructions'),/vesper-viaduct, abyssal-pressureworks/);
  assert.equal(previewReadme(buildIntent(commit,'final',{pending:[]}),'Original instructions'),'Original instructions');
});

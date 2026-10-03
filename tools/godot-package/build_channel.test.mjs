import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {channelProduction,buildIntent,verifyChannelManifest,previewReadme} from './build_channel.mjs';
import {REQUIREMENTS} from './production_resources.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const read=p=>readFileSync(root+p),has=p=>existsSync(root+p);
const options={read,has,worldIds:Object.keys(WORLDS)},commit='a'.repeat(40);
test('seven promoted units satisfy inventory in either channel; a deliberately unpromoted fixture still blocks final',()=>{
  const result=channelProduction(options,'preview');
  assert.deepEqual(result.pending,[]);
  assert.deepEqual(channelProduction(options).pending,[]);
  const requirements=JSON.parse(read(REQUIREMENTS));requirements.units['stormglass-causeway'].promotion=null;
  const fixture={...options,read:p=>p===REQUIREMENTS?Buffer.from(JSON.stringify(requirements)):read(p)};
  assert.deepEqual(channelProduction(fixture,'preview').pending,['stormglass-causeway']);
  assert.throws(()=>channelProduction(fixture),/remain pending/);
  assert.throws(()=>channelProduction(options,'unknown'),/Unknown build channel/);
  const path='godot/vehicle_assets/generated/puma-lod0.glb';
  assert.throws(()=>channelProduction({...options,has:p=>p!==path&&has(p)},'preview'),/Promoted production unit unavailable/);
  assert.throws(()=>channelProduction({...options,read:p=>p===path?Buffer.from('tamper'):read(p)},'preview'),/content hash mismatch/);
});
test('channel, flag, pending names and recorded intent must agree; historical final cannot downgrade',()=>{
  const result=channelProduction(options,'preview'),intent=buildIntent(commit,'preview',result);
  const manifest={...intent,build_intent:intent},builder='"build_channel"';
  assert.deepEqual(verifyChannelManifest(manifest,builder,result),intent);
  for(const change of [{build_channel:'final'},{build_flags:[]},{pending_production:['stormglass-causeway']},{pending_production:['unknown']},{verification_limits:[]},{build_intent:{...intent,build_channel:'final'}}])
    assert.throws(()=>verifyChannelManifest({...manifest,...change},builder,result));
  assert.throws(()=>verifyChannelManifest(manifest,'historical strict builder',result),/Historical/);
  assert.match(previewReadme(intent,'Original instructions'),/^# PREVIEW/);
  assert.match(previewReadme(intent,'Original instructions'),/Pending production: none/);
  assert.equal(previewReadme(buildIntent(commit,'final',{pending:[]}),'Original instructions'),'Original instructions');
});

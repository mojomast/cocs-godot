import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {productionResources,REQUIREMENTS} from './production_resources.mjs';

export const PREVIEW_LIMITS=['Not a final production release.','Pending production units use existing stock/fallback content; unregistered maps remain unavailable.','Final native/manual/audio, HUD accessibility/performance and Windows acceptance are not implied by this preview.'];
export function channelProduction(options,channel='final') {
  assert.ok(['final','preview'].includes(channel),'Unknown build channel');
  const result=productionResources({...options,strict:channel==='final'});
  const requirements=JSON.parse(options.read(REQUIREMENTS));
  // Audit mode alone can report a missing promoted unit as pending. A preview
  // must refuse that loss, not silently replace accepted assets with fallbacks.
  for(const [id,unit]of Object.entries(requirements.units))if(unit.promotion)
    assert.ok(!result.pending.includes(id),`Promoted production unit unavailable: ${id}`);
  return result;
}
export function buildIntent(commit,channel,production) {
  assert.match(commit,/^[a-f0-9]{40}$/);assert.ok(['final','preview'].includes(channel));
  return {version:1,port_commit:commit,build_channel:channel,build_flags:channel==='preview'?['--preview']:[],
    pending_production:production.pending,verification_limits:channel==='preview'?PREVIEW_LIMITS:[]};
}
export function previewReadme(intent,original) {
  return intent.build_channel==='preview'?`# PREVIEW — non-final test build\n\nCandidate: ${intent.port_commit}\n\nPending production: ${intent.pending_production.join(', ')||'none'}.\n\n${intent.verification_limits.map(s=>'- '+s).join('\n')}\n\n---\n\n${original}`:original;
}
export function verifyChannelManifest(manifest,builder,production) {
  const supported=builder.includes('"build_channel"');
  if(!supported) {
    assert.equal(manifest.build_channel,undefined,'Historical build cannot be relabeled preview');
    assert.equal(manifest.build_flags,undefined,'Historical build cannot gain preview flags');
    return null;
  }
  const intent=buildIntent(manifest.port_commit,manifest.build_channel,production);
  for(const key of ['build_channel','build_flags','pending_production','verification_limits'])
    assert.deepEqual(manifest[key],intent[key],`Build channel ${key} mismatch`);
  assert.deepEqual(manifest.build_intent,intent,'Recorded build intent mismatch');
  if(intent.build_channel==='final')assert.deepEqual(intent.pending_production,[],'Final build has pending production');
  return intent;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const [rootArg,commit,...flags]=process.argv.slice(2);assert.ok(flags.length===0||(flags.length===1&&flags[0]==='--preview'),'Unknown build flag');
  const root=resolve(rootArg),{WORLDS}=await import(pathToFileURL(join(root,'port/multiplayer-worlds/catalog.mjs')));
  const channel=flags.length?'preview':'final';
  const result=channelProduction({read:p=>readFileSync(join(root,p)),has:p=>existsSync(join(root,p)),worldIds:Object.keys(WORLDS)},channel);
  console.log(JSON.stringify({...result,build_intent:buildIntent(commit,channel,result)},null,2));
}

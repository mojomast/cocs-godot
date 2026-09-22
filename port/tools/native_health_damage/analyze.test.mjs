// Genuine old/new recordings. Mutations are synthetic evidence corruptions,
// never additional gameplay or injected actor state.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {analyze} from './analyze.mjs';
import * as projection from './project.mjs';
const historical=new URL('../../native-health-damage/evidence/d06d6f7a-cacd-43a4-8910-97007273dc21/',import.meta.url);
const evidence=new URL('../../native-hud-acceptance/evidence/',import.meta.url);
const current=new URL('3f0691a0-fe42-4254-a6da-1aa6d07cfcd7/',evidence);
const inconclusive=new URL('2df9b589-642a-4a47-8898-1fa7a4cc6a65/',evidence);
const read=(dir,name)=>readFileSync(new URL(name,dir));
const hash=b=>createHash('sha256').update(b).digest('hex');
function recording(dir=current){return {stdout:gunzipSync(read(dir,'native.stdout.log.gz')).toString(),wire:JSON.parse(gunzipSync(read(dir,'wire.json.gz')))};}
function rewrite(stdout,prefix,edit){return stdout.split('\n').flatMap(line=>{if(!line.startsWith(prefix))return [line];const o=JSON.parse(line.slice(prefix.length));return edit(o)===false?[]:[prefix+JSON.stringify(o)];}).join('\n');}
function corruptHUD(edit){const {stdout,wire}=recording();return ()=>analyze(rewrite(stdout,'HEALTH_OBSERVE ',o=>{if(o.event==='hud_render')return edit(o);}),wire);}
test('current real default HUD, nonlethal damage, +35 health and 12s return',()=>{
 const {stdout,wire}=recording(),r=analyze(stdout,wire);
 assert.equal(r.status,'PASS');assert.equal(r.hudAcceptance.mode,'compact-default-rendered');assert.equal(r.hudAcceptance.currentHUDProven,true);
 assert.equal(r.completionProven,false);assert.equal(r.healthPickup.observedGain,35);
 assert.ok(Math.abs(r.damage.eventAmountTotal-r.damage.healthLoss-r.damage.armorLoss)<.002);
 assert.equal(r.damage.hurtUI.image,'hurt.png');assert.ok(r.damage.hurtUI.hurt_strength>0);
});
test('genuine historical recording stays legacy text-only and cannot establish current HUD',()=>{
 const {stdout,wire}=recording(historical),r=analyze(stdout,wire,{hudMode:'legacy'});
 assert.equal(r.status,'PASS');assert.equal(r.hudAcceptance.mode,'historical-legacy-text-only');
 assert.equal(r.hudAcceptance.currentHUDProven,false);assert.equal(r.hudAcceptance.legacyVisibilityProven,false);
 assert.equal(r.counts.receivedInputs,1334);assert.equal(r.healthPickup.observedGain,35);
 assert.throws(()=>analyze(stdout,wire),/missing current rendered HUD/);
 const live=recording();assert.throws(()=>analyze(live.stdout,live.wire,{hudMode:'legacy'}),/cannot be downgraded/);
});
test('old/new artifact hashes; executed historical sources checked at immutable pre-update commit',()=>{
 for(const dir of [historical,current]){
  const summary=JSON.parse(read(dir,'summary.json'));
  for(const [name,entry] of Object.entries(summary.artifacts)){const b=read(dir,name);assert.equal(b.length,entry.bytes);assert.equal(hash(b),entry.sha256,name);}
  for(const [name,expected] of Object.entries(summary.sourceHashes)){
   const bytes=dir===historical?execFileSync('git',['show',`fe29ac3:port/tools/native_health_damage/${name}`]):readFileSync(new URL(name,import.meta.url));
   assert.equal(hash(bytes),expected,name);
  }
 }
 const summary=JSON.parse(read(current,'summary.json'));
 for(const name of ['baseline.png','hurt.png','collected.png']){
  assert.ok(summary.artifacts[name]);assert.equal(read(current,name).subarray(1,4).toString(),'PNG');
 }
 for(const [name,expected] of Object.entries(summary.runtimeHashes))assert.equal(hash(execFileSync('git',['show',`fe29ac3:${name}`])),expected,name);
 assert.equal(summary.normalRate,true);assert.equal(summary.cleanup.serverClosed,true);assert.equal(summary.cleanup.socketCount,0);assert.equal(summary.cleanup.privateTempRemoved,true);
});
test('inconclusive route/output-cap run remains intact and cannot pass acceptance',()=>{
 const summary=JSON.parse(read(inconclusive,'summary.json'));assert.equal(summary.status,'INCONCLUSIVE');assert.match(summary.error,/output cap/);
 for(const [name,entry] of Object.entries(summary.artifacts)){const b=read(inconclusive,name);assert.equal(b.length,entry.bytes);assert.equal(hash(b),entry.sha256,name);}
 const {stdout,wire}=recording(inconclusive);assert.throws(()=>analyze(stdout,wire));
});
for(const key of ['layer_visible','root_visible','vitals_visible'])test(`reject hidden HUD ${key}`,()=>assert.throws(corruptHUD(h=>{h[key]=false;}),/HUD/));
for(const key of ['health_label','armor_label','health_bar','armor_bar'])test(`reject hidden HUD ${key}`,()=>assert.throws(corruptHUD(h=>{h[key].visible=false;}),/HUD/));
test('reject offscreen and empty label geometry',()=>{
 assert.throws(corruptHUD(h=>{h.health_label.in_viewport=false;}),/viewport/);
 assert.throws(corruptHUD(h=>{h.armor_label.rect[2]=0;}),/geometry/);
});
test('reject wrong integer labels, gauges and maxima',()=>{
 assert.throws(corruptHUD(h=>{h.health_label.text='HEALTH  999';}),/health integer/);
 assert.throws(corruptHUD(h=>{h.armor_label.text='ARMOR  999';}),/armor integer/);
 assert.throws(corruptHUD(h=>{h.health_bar.value=-1;}),/health bar/);
 assert.throws(corruptHUD(h=>{h.armor_bar.value=999;}),/armor bar/);
 assert.throws(corruptHUD(h=>{h.health_bar.max=999;}),/health maximum/);
 assert.throws(corruptHUD(h=>{h.armor_bar.max=999;}),/armor reference/);
 assert.throws(corruptHUD(h=>{h.health_bar.step=1;}),/supported precision/);
});
test('reject missing, stale, wrong-authority and wrong-trace rendered observations',()=>{
 assert.throws(corruptHUD(()=>false),/missing current rendered HUD/);
 assert.throws(corruptHUD(h=>{h.seq--;}),/latest snapshot/);
 assert.throws(corruptHUD(h=>{h.native_sequence++;}),/trace association/);
 assert.throws(corruptHUD(h=>{h.actor.health++;}),/actor authority/);
 assert.throws(corruptHUD(h=>{h.post_draw=false;}),/after render/);
 assert.throws(corruptHUD(h=>{h.render_frame=1;}),/frame order/);
});
test('reject missing collected and return HUD observations',()=>{
 const {stdout,wire}=recording(),r=analyze(stdout,wire),start=r.healthPickup.collected.snapshotSeq,end=r.healthPickup.returned.snapshotSeq;
 assert.throws(corruptHUD(h=>h.seq>=start&&h.seq<end?false:undefined),/missing collected/);
 assert.throws(corruptHUD(h=>h.seq>=end?false:undefined),/missing returned/);
});
test('hidden text or positive feedback alone cannot replace visible rendered hurt',()=>{
 for(const edit of [h=>{h.overlay.visible=false;},h=>{h.hurt_strength=0;},h=>{h.overlay_draw_hurt=0;},h=>{h.overlay_draw_frame--;},h=>{h.damage_event_id=-999;},h=>{delete h.image;}])assert.throws(corruptHUD(edit),/overlay hurt|damage event association/);
 assert.throws(corruptHUD(h=>{if(h.image)h.image_result=1;}),/image save/);
});
test('synchronous authority adjacency remains mandatory',()=>{
 const {stdout,wire}=recording();assert.throws(()=>analyze(stdout.replace('HEALTH_CORRELATE ','synthetic interruption\nHEALTH_CORRELATE '),wire),/immediately follow/);
});
test('strict receipt, marker lifecycle and stopped incoming fire checks remain',()=>{
 {const {stdout,wire}=recording();wire.inputs.pop();assert.throws(()=>analyze(stdout,wire),/unmatched\/inflight/);}
 {const {stdout,wire}=recording();wire.attackerInputs.find(i=>i.seq===wire.attackStop.nextInputSeq).input.fire=true;assert.throws(()=>analyze(stdout,wire),/incoming fire stopped/);}
 {const {stdout,wire}=recording();let changed=false;assert.throws(()=>analyze(rewrite(stdout,'HEALTH_CORRELATE ',o=>{if(o.event==='snapshot'&&o.pickup.wait>0&&!changed){o.marker_instance++;changed=true;}}),wire),/same native marker/);}
});
test('HP-only accounting is rejected even when event observations agree',()=>{
 let {stdout,wire}=recording();const e=wire.events.find(e=>e.type==='damage'&&e.actor===wire.actor);e.amount-=5;
 stdout=rewrite(stdout,'HEALTH_OBSERVE ',o=>{if(o.event==='events')for(const n of o.items)if(n.id===e.id)n.amount=e.amount;});
 assert.throws(()=>analyze(stdout,wire),/HP plus armor loss/);
});
test('retained evidence excludes credentials and welcome packets',()=>{
 const forbidden=new Set(['token','progressToken','resumeToken','reconnectToken']);
 function scan(v){if(!v||typeof v!=='object')return;for(const [k,x] of Object.entries(v)){assert.ok(!forbidden.has(k),`credential ${k}`);assert.ok(!(k==='type'&&x==='welcome'));scan(x);}}
 for(const dir of [historical,current,inconclusive]){
  const {stdout,wire}=recording(dir);scan(wire);scan(JSON.parse(read(dir,'summary.json')));
  for(const line of stdout.split('\n'))for(const prefix of ['PORT_NATIVE_TRACE ','HEALTH_CORRELATE ','HEALTH_OBSERVE '])if(line.startsWith(prefix))scan(JSON.parse(line.slice(prefix.length)));
 }
 const fake={token:'SYNTHETIC_SECRET',progressToken:'SYNTHETIC_SECRET',id:1};
 for(const fn of [projection.actor,projection.pickup,projection.event])assert.ok(!JSON.stringify(fn(fake)).includes('SYNTHETIC_SECRET'));
});

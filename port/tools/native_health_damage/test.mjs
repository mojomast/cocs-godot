// One genuine live recording; all negative mutations below are explicitly
// synthetic evidence corruptions, not additional gameplay executions.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {analyze} from './analyze.mjs';
import * as projection from './project.mjs';
const directory=new URL('../../native-health-damage/evidence/d06d6f7a-cacd-43a4-8910-97007273dc21/',import.meta.url);
const read=name=>readFileSync(new URL(name,directory));
function recording(){return {stdout:gunzipSync(read('native.stdout.log.gz')).toString(),wire:JSON.parse(gunzipSync(read('wire.json.gz')))};}
function rewriteRecords(stdout,prefix,edit){return stdout.split('\n').map(line=>{if(!line.startsWith(prefix))return line;const r=JSON.parse(line.slice(prefix.length));edit(r);return prefix+JSON.stringify(r);}).join('\n');}
test('genuine live damage, +35 health, same marker and 12-second return pass without native completion',()=>{
 const {stdout,wire}=recording(),r=analyze(stdout,wire);assert.equal(r.status,'PASS');assert.equal(r.completionProven,false);
 assert.ok(Math.abs(r.damage.eventAmountTotal-r.damage.healthLoss-r.damage.armorLoss)<.001);
 assert.equal(r.healthPickup.observedGain,35);assert.equal(r.healthPickup.id,6);assert.equal(r.counts.receivedInputs,1334);
});
test('artifact lengths/hashes and executed source hashes match provenance',()=>{
 const summary=JSON.parse(read('summary.json'));
 for(const [name,entry] of Object.entries(summary.artifacts)){const b=read(name);assert.equal(b.length,entry.bytes);assert.equal(createHash('sha256').update(b).digest('hex'),entry.sha256,name);}
 for(const [name,hash] of Object.entries(summary.sourceHashes))assert.equal(createHash('sha256').update(readFileSync(new URL(name,import.meta.url))).digest('hex'),hash,name);
});
test('credential field names and welcome packets are absent from retained evidence; projections exclude them',()=>{
 const forbidden=new Set(['token','progressToken','resumeToken','reconnectToken']);
 function scan(value){if(!value||typeof value!=='object')return;for(const [k,v] of Object.entries(value)){assert.ok(!forbidden.has(k),`retained credential key ${k}`);assert.ok(!(k==='type'&&v==='welcome'),'retained welcome body');scan(v);}}
 const {stdout,wire}=recording();scan(wire);scan(JSON.parse(read('summary.json')));
 for(const line of stdout.split('\n'))for(const prefix of ['PORT_NATIVE_TRACE ','HEALTH_CORRELATE ','HEALTH_OBSERVE '])if(line.startsWith(prefix))scan(JSON.parse(line.slice(prefix.length)));
 const fake={token:'SYNTHETIC_SECRET',progressToken:'SYNTHETIC_SECRET',id:1};
 for(const fn of [projection.actor,projection.pickup,projection.event])assert.ok(!JSON.stringify(fn(fake)).includes('SYNTHETIC_SECRET'));
});
test('native combat text alone cannot substitute for actual UI Label text',()=>{
 const {stdout,wire}=recording();const mutated=rewriteRecords(stdout,'HEALTH_OBSERVE ',o=>{if(o.event==='frame')o.ui_text='';});
 assert.throws(()=>analyze(mutated,wire),/actual combat Label/);
});
test('HP-only damage accounting is rejected even if both event observations agree',()=>{
 let {stdout,wire}=recording();const first=wire.events.find(e=>e.type==='damage'&&e.actor===wire.actor);first.amount-=5;
 stdout=rewriteRecords(stdout,'HEALTH_OBSERVE ',o=>{if(o.event==='events')for(const e of o.items)if(e.id===first.id)e.amount=first.amount;});
 assert.throws(()=>analyze(stdout,wire),/HP plus armor loss/);
});
test('missing server input receipt does not become successful queue evidence',()=>{
 const {stdout,wire}=recording();wire.inputs.pop();assert.throws(()=>analyze(stdout,wire),/unmatched\/inflight/);
});
test('observer snapshot association rejects an intervening line',()=>{
 const {stdout,wire}=recording();assert.throws(()=>analyze(stdout.replace('HEALTH_CORRELATE ','synthetic line\nHEALTH_CORRELATE '),wire),/immediately follow/);
});
test('replacement pickup marker cannot be claimed as the same marker lifecycle',()=>{
 const {stdout,wire}=recording();let changed=false;const mutated=rewriteRecords(stdout,'HEALTH_CORRELATE ',o=>{if(o.event==='snapshot'&&o.pickup.wait>0&&!changed){o.marker_instance++;changed=true;}});
 assert.throws(()=>analyze(mutated,wire),/same native marker/);
});
test('continued attacker fire after stop cannot pass nonlethal stop criterion',()=>{
 const {stdout,wire}=recording();wire.attackerInputs.find(i=>i.seq===wire.attackStop.nextInputSeq).input.fire=true;
 assert.throws(()=>analyze(stdout,wire),/incoming fire stopped/);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {validateNpcKills,validateRun} from './validate.mjs';
const path='port/reports/horde-repair-independent/evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60';
const read=name=>gunzipSync(readFileSync(`${path}/${name}.gz`)).toString();
const wire=read('wire.jsonl').split('\n').map(JSON.parse);
const outputs=wire.filter(r=>r.direction==='out'&&r.round===1);
const states=outputs.filter(r=>r.frame.type==='snapshot').map(r=>r.frame.state);
const events=outputs.filter(r=>r.frame.type==='events').flatMap(r=>r.frame.items);
const result=outputs.find(r=>r.frame.type==='results').frame.state;
const input={wire,stdout:read('native.stdout.log'),stderr:read('native.stderr.log'),
 summary:JSON.parse(readFileSync(`${path}/summary.json`)),launch:JSON.parse(readFileSync(`${path}/launch.json`))};
const npcDeath=e=>e.type==='death'&&e.actor===1;
const replaceVictim=patch=>events.map(e=>npcDeath(e)?{...e,...patch}:e);

test('preserved real Meridian three-NPC victory accepts net frags 2 and one legitimate self-kill',()=>{
 const valid=validateRun(input);
 assert.deepEqual(valid.combatKills,{npcKills:3,npcVictims:[1,2,3],netFrags:2,lives:2,selfDeaths:1});
 assert.equal(valid.harnessExit,0);assert.equal(valid.correlated,564);
});
test('missing NPC death cannot be supplied by the legitimate local self-kill',()=>{
 assert.throws(()=>validateNpcKills(states,events.filter(e=>!npcDeath(e)),result),/three local NPC/);
});
test('duplicating another NPC death does not replace a missing target',()=>{
 const other=events.find(e=>e.type==='death'&&e.actor===2);
 assert.throws(()=>validateNpcKills(states,events.map(e=>npcDeath(e)?{...other}:e),result),/duplicate NPC/);
});
test('extra repeated NPC death is not silently payload-deduplicated',()=>{
 assert.throws(()=>validateNpcKills(states,[...events,{...events.find(npcDeath)}],result),/three local NPC/);
});
test('nonlocal credited death cannot stand in for a local NPC kill',()=>{
 assert.throws(()=>validateNpcKills(states,replaceVictim({killer:2}),result),/three local NPC/);
});
test('NPC self-death cannot stand in for a local NPC kill even with killer 0',()=>{
 assert.throws(()=>validateNpcKills(states,replaceVictim({self:true}),result),/three local NPC/);
});
test('local actor death cannot stand in for a missing NPC victim',()=>{
 assert.throws(()=>validateNpcKills(states,replaceVictim({actor:0}),result),/three local NPC/);
});
test('unknown victim is rejected instead of trusting hard-coded actor IDs',()=>{
 assert.throws(()=>validateNpcKills(states,replaceVictim({actor:999}),result),/not a snapshot NPC/);
});
test('NPC identities must be established by received snapshots, not death payload claims',()=>{
 const missing=states.map(s=>({...s,actors:s.actors.map(a=>a.id===1?{...a,isNpc:false}:a)}));
 assert.throws(()=>validateNpcKills(missing,events,result),/snapshot-identified NPC/);
});
test('snapshot NPC identities are not hard-coded to 1,2,3',()=>{
 const id=x=>x===0?0:x+20;
 const renamed=states.map(s=>({...s,actors:s.actors.map(a=>({...a,id:id(a.id)}))}));
 const deaths=events.map(e=>e.type==='death'?{...e,actor:id(e.actor),killer:id(e.killer)}:e);
 assert.deepEqual(validateNpcKills(renamed,deaths,result).npcVictims,[21,22,23]);
});
test('source net-frag projection remains independently checked',()=>{
 assert.throws(()=>validateNpcKills(states,events,{...result,singleplayer:{...result.singleplayer,kills:3}}),/net-frag projection/);
});
test('full validator still rejects dirty exit and absent NPC evidence after predicate correction',()=>{
 assert.throws(()=>validateRun({...input,summary:{...input.summary,exit:1}}),/harness failed/);
 const altered=wire.map(r=>r.direction==='out'&&r.frame.type==='events'?{...r,frame:{...r.frame,items:r.frame.items.filter(e=>!npcDeath(e))}}:r);
 assert.throws(()=>validateRun({...input,wire:altered}),/three local NPC/);
});

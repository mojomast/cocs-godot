import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {parseSample,assertRole,assertPositive,until,stopChild} from './lib.mjs';
const sample={seconds:1,phase:11,phase_seconds:1,snapshots:0,ack:0,actor:1,starts:0,pose:false,error:''};
test('synthetic: bounded native sample parsing',()=>{
 assert.equal(parseSample('Godot Engine'),null);
 assert.deepEqual(parseSample('GUEST_SAMPLE '+JSON.stringify(sample)),sample);
 assert.throws(()=>parseSample('GUEST_SAMPLE {'));
 assert.throws(()=>parseSample('GUEST_SAMPLE '+JSON.stringify({...sample,ack:'2'})));
});
test('synthetic: role assertion rejects host/start/restart and unknown commands',()=>{
 assertRole({join:1,input:10});
 for(const type of ['host','start','restart','create','rematch','unknown']) assert.throws(()=>assertRole({join:1,[type]:1}));
 assert.throws(()=>assertRole({input:1}));
});
test('synthetic: waiting alone or wire snapshots alone cannot prove positive',()=>{
 const samples=[sample,{...sample,seconds:1.5},{...sample,seconds:2},{...sample,seconds:3,phase:3,pose:true,starts:1,snapshots:8,ack:8}];
 const wire={guest:{join:1,input:9},snapshots:10,starts:1,positiveAcks:3};
 assertPositive(samples,wire,2.1);
 assert.throws(()=>assertPositive(samples.slice(0,3),wire,2.1));
 assert.throws(()=>assertPositive(samples,{...wire,snapshots:0},2.1));
 assert.throws(()=>assertPositive(samples.map(s=>({...s,starts:1})),wire,2.1));
});
test('synthetic: real wall-clock deadline and predicate errors',async()=>{
 await until(()=>true,100,'ready');
 await assert.rejects(until(()=>false,30,'expected'),/Deadline: expected/);
 await assert.rejects(until(()=>{throw Error('predicate failure');},30,'error'),/predicate failure/);
});
test('offline: owned child cleanup after successful readiness and failed deadline',async()=>{
 for(const fail of [false,true]) {
  const child=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});
  try {if(fail)await assert.rejects(until(()=>false,30,'failure'),/Deadline/);else await until(()=>!!child.pid,100,'spawn');}
  finally {assert.equal((await stopChild(child)).reaped,true);}
  assert.equal((await stopChild(child)).reaped,true);
 }
});
test('offline: escalation reaps only an owned SIGTERM-resistant child',async()=>{
 const child=spawn(process.execPath,['-e',"process.on('SIGTERM',()=>{});console.log('ready');setInterval(()=>{},1000)"],{stdio:['ignore','pipe','ignore']});
 let ready=false;child.stdout.on('data',()=>ready=true);
 try {await until(()=>ready,2000,'resistant child ready');}
 finally {const result=await stopChild(child);assert.equal(result.reaped,true);assert.equal(result.signal,'SIGKILL');}
});
test('offline: cleanup tolerates missing executable',async()=>{
 const child=spawn('/nonexistent/guest-harness-binary',[],{stdio:'ignore'});
 await new Promise(r=>child.once('error',r));
 assert.equal((await stopChild(child)).reaped,true);
});

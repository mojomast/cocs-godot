import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync} from 'node:fs';
import {join} from 'node:path';
import {ownProcess,stopOwned,until,liveGroup} from './connected-process.mjs';
mkdirSync('/tmp/opencode',{recursive:true});
const output=mkdtempSync('/tmp/opencode/spectator-process-check-');

test('escalation drains a TERM-resistant parent and grandchild, retaining logs',async()=>{
  const code=`const {spawn}=require('node:child_process');process.on('SIGTERM',()=>{});const c=spawn(process.execPath,['-e',"process.on('SIGTERM',()=>{});console.log('GRANDCHILD_READY');setInterval(()=>{},1000)"],{stdio:'inherit'});console.log('PARENT_READY',c.pid);setInterval(()=>{},1000);`;
  const owned=ownProcess(process.execPath,['-e',code],{log:join(output,'resistant.log')});
  try {
    await until(()=>owned.text.includes('GRANDCHILD_READY'),'synthetic descendant ready');
    assert.ok(liveGroup(owned.child.pid).length>=2);
    const result=await stopOwned(owned,{termMs:100,killMs:3000});
    assert.equal(result.escalated,true);assert.deepEqual(result.live,[]);
    assert.match(readFileSync(owned.log,'utf8'),/GRANDCHILD_READY/);
  } finally {await stopOwned(owned,{termMs:100});}
});

test('spawn failure and ordinary exit both close their logs and settle',async()=>{
  const missing=ownProcess('/does-not-exist-experience',[],{log:join(output,'spawn-failure.log')});
  await stopOwned(missing,{termMs:500});assert.equal(missing.error.code,'ENOENT');
  const normal=ownProcess(process.execPath,['-e',"console.log('NORMAL_EXIT')"],{log:join(output,'normal.log')});
  await until(()=>normal.closed,'ordinary child exit');
  const result=await stopOwned(normal);assert.equal(result.code,0);assert.equal(result.escalated,false);
  assert.match(readFileSync(normal.log,'utf8'),/NORMAL_EXIT/);
});

test('an already exited leader cannot hide a live TERM-resistant descendant',async()=>{
  const code=`const {spawn}=require('node:child_process');spawn(process.execPath,['-e',"process.on('SIGTERM',()=>{});setInterval(()=>{},1000)"],{stdio:'ignore'});setTimeout(()=>process.exit(0),250);`;
  const owned=ownProcess(process.execPath,['-e',code],{log:join(output,'exited-leader.log')});
  try {
    await until(()=>owned.closed,'synthetic leader exited');
    assert.equal(owned.child.exitCode,0);assert.ok(liveGroup(owned.child.pid).length>0);
    const result=await stopOwned(owned,{termMs:100,killMs:3000});
    assert.equal(result.escalated,true);assert.deepEqual(result.live,[]);
  } finally {await stopOwned(owned,{termMs:100});}
});

test('deadline and cancellation reject without leaving a process',async()=>{
  await assert.rejects(until(()=>false,'synthetic timeout',{ms:25}),/Deadline/);
  await assert.rejects(until(()=>false,'synthetic interrupt',{abort:()=>{throw Error('SIGTERM fixture');}}),/SIGTERM fixture/);
});
console.log('SYNTHETIC_PROCESS_EVIDENCE '+output);

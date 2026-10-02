import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {observeChild,shutdownPeers} from './process-evidence.mjs';

function fixture(){
 const child=new EventEmitter();child.stdout=new EventEmitter();child.stderr=new EventEmitter();child.pid=123;
 child.kill=signal=>{queueMicrotask(()=>child.emit('close',null,signal));return true;};
 return {child,peer:observeChild(child,'host')};
}
const budget={graceMs:30,termMs:30,killMs:30};
function finish(child,{code=0,late='',notify=true}={}){
 if(notify)child.stdout.emit('data','CANDIDATE_TEARDOWN_READY {"role":"host"}\n');
 child.emit('exit',code,null);
 // Stdio may produce errors AFTER exit but BEFORE close.
 setTimeout(()=>{child.stderr.emit('data',late);child.emit('close',code,null);},5);
}
test('graceful notification and zero close pass only after final stdio drains',async()=>{
 const {child,peer}=fixture();
 const pending=shutdownPeers([peer],()=>finish(child),budget);
 assert.equal(peer.closed,false);
 const [result]=await pending;
 assert.equal(result.clean,true);assert.equal(result.requested,true);assert.equal(result.forced,false);
});
test('late teardown errors and leaks fail even after a zero exit event',async()=>{
 for(const late of ['ERROR: shutdown resource failure\n','SCRIPT ERROR: cleanup\n','Parse Error: teardown\n','WARNING: ObjectDB instances leaked at exit\n','WARNING: 2 RIDs of type Mesh were leaked\n','ERROR: Resources still in use at exit\n']){
  const {child,peer}=fixture();
  const [result]=await shutdownPeers([peer],()=>finish(child,{late}),budget);
  assert.equal(result.clean,false,late);assert.ok(result.failures.includes('native-log-error-or-leak'));
  assert.equal(peer.stderr,late);assert.ok(peer.log.endsWith(late));assert.equal(peer.code,0);
 }
});
test('nonzero, unrequested early exit and missing fixture notification fail',async()=>{
 const bad=fixture();
 assert.equal((await shutdownPeers([bad.peer],()=>finish(bad.child,{code:7}),budget))[0].clean,false);
 const early=fixture();early.child.emit('close',0,null);
 const [result]=await shutdownPeers([early.peer],()=>assert.fail('must not request an already exited child'),budget);
 assert.ok(result.failures.includes('unexpected-exit'));
 const silent=fixture();
 assert.ok((await shutdownPeers([silent.peer],()=>finish(silent.child,{notify:false}),budget))[0].failures.includes('missing-graceful-notification'));
});
test('timeout escalation remains failure even if forced child exits zero; second peer still drains',async()=>{
 const stuck=fixture(),good=fixture();good.peer.role='guest';
 stuck.child.kill=()=>{queueMicrotask(()=>{stuck.child.stdout.emit('data','CANDIDATE_TEARDOWN_READY {}\n');stuck.child.emit('close',0,null);});};
 const results=await shutdownPeers([stuck.peer,good.peer],p=>{if(p===good.peer)finish(good.child);},budget);
 assert.equal(results[0].forced,true);assert.equal(results[0].clean,false);assert.equal(results[1].clean,true);
});
test('spawn error and failed quit command preserve failure evidence and clean other owned peers',async()=>{
 const failed=fixture(),good=fixture();
 failed.child.emit('error',Error('ENOENT'));
 queueMicrotask(()=>failed.child.emit('close',-2,null));
 const results=await shutdownPeers([failed.peer,good.peer],p=>{if(p===good.peer)finish(good.child);},budget);
 assert.match(results[0].spawnError,/ENOENT/);assert.equal(results[0].clean,false);assert.equal(results[1].clean,true);
 const requestFailed=fixture();
 const [report]=await shutdownPeers([requestFailed.peer],()=>{throw Error('write failed');},budget);
 assert.equal(report.clean,false);assert.ok(report.failures.some(s=>s.includes('write failed')));
});

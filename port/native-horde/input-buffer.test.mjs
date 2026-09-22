import test from 'node:test';
import assert from 'node:assert/strict';
import {InputBuffer,INPUT_LIMIT,INPUT_TTL_MS} from './input-buffer.mjs';
import {controlsFromState} from '../../game/input.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {eventBatch,outboundAllowed} from './authority.mjs';
test('source one-shot fields are consumed once while source held fields persist',()=>{
 const b=new InputBuffer();
 const source=controlsFromState({keys:new Set(['Space','KeyX','KeyZ','ShiftLeft','ControlLeft']),fire:true,reload:true,power:true,interact:true,melee:true,grenade:true,ads:true,weapon:1});
 b.receive(1,parseInputEnvelope({seq:1,input:source}),0);
 assert.deepEqual(b.take().input,parseInputEnvelope({seq:1,input:source}));b.stepped(1);
 const next=b.take().input;
 for(const field of ['reload','power','interact','melee','grenade','weapon'])assert(!Object.hasOwn(next,field));
 for(const field of ['fire','jump','mobility','altFire','sprint','crouch','ads'])assert.equal(next[field],true);
 assert.equal(b.applied,1);
});
test('FIFO preserves two distinct press/release pairs, bounds work instead of dropping commands',()=>{
 const b=new InputBuffer();
 for(let seq=1;seq<=INPUT_LIMIT;seq++)b.receive(seq,{fire:seq%2===1},0);
 assert.throws(()=>b.receive(INPUT_LIMIT+1,{},0),/queue limit/);
 assert.equal(b.received,INPUT_LIMIT);
 for(let seq=1;seq<=INPUT_LIMIT;seq++){const sample=b.take();assert.equal(sample.seq,seq);assert.equal(sample.input.fire,seq%2===1);b.stepped(seq);}
 assert.equal(b.status().queueDepth,0);
});
test('cancel and round reset clear queue/holds without falsely claiming old samples were stepped',()=>{
 const b=new InputBuffer();b.receive(1,{fire:true},0);b.receive(2,{fire:true},1,true);
 assert.equal(b.applied,0);assert.equal(b.cancelledThrough,1);assert.deepEqual(b.take().input,{});b.stepped(2);
 b.reset();assert.deepEqual(b.status(),{receivedSeq:0,appliedSeq:0,cancelledThrough:0,queueDepth:0});assert.deepEqual(b.take().input,{});
});
test('duplicate/unsafe seq does not renew expiry; stale samples are never implicitly applied',()=>{
 const b=new InputBuffer();b.receive(2,{fire:true},0);
 for(const seq of [0,1,2,NaN,1.5,Number.MAX_SAFE_INTEGER+1])assert.equal(b.receive(seq,{},200),false);
 assert(b.expired(INPUT_TTL_MS));assert.equal(b.applied,0);b.cancel();assert.deepEqual(b.take().input,{});
});
test('serial cursor preserves repeated opaque source IDs and detects a lost source ring',()=>{
 const match={serial:3,events:[{id:'swarm',type:'horde-modifier'},{id:'pad-1',type:'traversal'},{id:'swarm',type:'horde-modifier'}]};
 assert.deepEqual(eventBatch(match,0).map(e=>[e.id,e.sourceId]),[[1,'swarm'],[2,'pad-1'],[3,'swarm']]);
 assert.deepEqual(eventBatch(match,2).map(e=>e.id),[3]);assert.deepEqual(eventBatch(match,3),[]);
 assert.throws(()=>eventBatch({serial:5,events:match.events},0),/overflow/);
});
test('outbound message and total queued-byte boundaries are inclusive and bounded',()=>{
 assert(outboundAllowed(1048576,1048576));assert(!outboundAllowed(1048577,0));assert(!outboundAllowed(1,2097152));
});

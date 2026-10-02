import {test} from 'node:test';
import assert from 'node:assert/strict';
import {campaignInputDiagnostic} from './campaign-input-diagnostic.mjs';

test('wire received, FIFO applied, snapshot pose join without retaining identity or mutable references',()=>{
  const probe=campaignInputDiagnostic();
  const received={round:1,observedMs:1,direction:'in',frame:{type:'input',seq:8,inputEpoch:2,cancel:false,input:{x:1,z:0,token:'secret'}}};
  probe.observe(received);
  received.frame.input.x=0;
  probe.observe({direction:'step',round:1,observedMs:2,inputEpoch:2,inputSeq:8,appliedSeq:8,sourceTime:3,controls:{x:1,z:0}});
  const frame={type:'snapshot',seq:20,ack:8,inputEpoch:2,nativeArenaInput:{appliedSeq:8,queueDepth:0},state:{time:3.1,actors:[{id:0,x:2,y:18,z:4,progressToken:'secret'},{id:1,isNpc:true,x:99}]}};
  probe.observe({direction:'out',round:1,observedMs:3,frame});
  frame.state.actors[0].x=9;
  const data=probe.result();
  assert.equal(data.rows[0].controls.x,1);
  assert.equal(data.rows[1].inputSeq,data.rows[0].seq);
  assert.equal(data.rows[2].ack,8);
  assert.deepEqual(data.rows[2].actors,[{id:0,x:2,y:18,z:4}]);
  assert.doesNotMatch(JSON.stringify(data),/secret|token/i);
});

test('cancellation and zero/default application are distinguishable; exhaustion is explicit',()=>{
  const probe=campaignInputDiagnostic(2);
  probe.observe({direction:'in',frame:{type:'input',seq:9,inputEpoch:2,cancel:true,input:{}}});
  probe.observe({direction:'step',inputEpoch:2,inputSeq:0,controls:{x:0,z:0},cancelledThrough:9});
  probe.observe({direction:'step',inputSeq:10,controls:{x:1}});
  assert.equal(probe.result().rows[0].cancel,true);
  assert.equal(probe.result().rows[1].inputSeq,0);
  assert.equal(probe.result().rows[1].cancelledThrough,9);
  assert.equal(probe.result().rows.length,2);
  assert.equal(probe.result().dropped,1);
  assert.equal(probe.result().complete,false);
});

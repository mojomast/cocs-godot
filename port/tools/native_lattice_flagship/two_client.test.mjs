import {test} from 'node:test';
import assert from 'node:assert/strict';
import {evaluatePair} from './two_client.mjs';

const rec=(direction,type,frame={})=>({direction,frame:{type,...frame}});
test('pre-start gate uses two ordinary peers; post-start requires distinct actor assignments and both starts',()=>{
  const players=[{peerId:1,actorId:null,connected:true,spectate:false},{peerId:2,actorId:null,connected:true,spectate:false}];
  const s={host:[rec('recipient','welcome',{roomId:'ABCD',peerId:1}),rec('recipient','lobby',{roomId:'ABCD',config:{mode:'cocs'},players})],guest:[rec('recipient','welcome',{roomId:'ABCD',peerId:2}),rec('recipient','lobby',{roomId:'ABCD',players})]};
  const before=evaluatePair(s);assert.equal(before.two_distinct_peers,true);assert.equal(before.host_config_echoed,true);assert.equal(before.two_distinct_actors,false);
  const assigned=players.map((p,i)=>({...p,actorId:10+i}));
  for(const who of ['host','guest'])s[who].push(rec('recipient','lobby',{roomId:'ABCD',players:assigned}),rec('recipient','start'));
  assert.deepEqual(evaluatePair(s),{room_match:true,host_config_echoed:true,guest_published_presence:true,two_distinct_peers:true,two_distinct_actors:true,host_start_observed:true,guest_start_observed:true,guest_start_messages:0});
});
test('no actors or mismatched room never opens host start gate; outgoing guest start is explicitly counted',()=>{
 const s={host:[rec('recipient','welcome',{roomId:'ABCD',peerId:1})],guest:[rec('recipient','lobby',{roomId:'OTHER',players:[{peerId:2,actorId:20}]}),rec('client','start')]};
  const gate=evaluatePair(s);assert.equal(gate.room_match,false);assert.equal(gate.guest_published_presence,false);assert.equal(gate.two_distinct_peers,false);assert.equal(gate.two_distinct_actors,false);assert.equal(gate.guest_start_messages,1);
});

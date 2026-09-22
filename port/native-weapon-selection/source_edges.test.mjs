import test from 'node:test';
import assert from 'node:assert/strict';
import {Room} from '../../server/room.mjs';

test('real Room replaces weapon with latest packet, with ACK only after simulation',()=>{
  const room=new Room('weapon-edge-proof',()=>0.5);
  room.join(1,'Native source contract');
  room.host(1,{botCount:0,timeLimit:30},'crosswire');
  room.start(1);
  const peer=room.peers.get(1);
  room.input(1,{seq:1,input:{weapon:1}});
  assert.equal(peer.latest.weapon,1);
  assert.equal(peer.appliedSeq,0,'receipt is not applied ACK');
  room.input(1,{seq:2,input:{}});
  assert.equal(peer.latest.weapon,undefined,'neutral packet overwrites unconsumed switch');
  room.tick(1/60);
  assert.equal(peer.appliedSeq,2);
  assert.equal(room.match.actors[0].weapon,0);
  room.input(1,{seq:3,input:{weapon:1}});
  room.input(1,{seq:4,input:{weapon:1}});
  assert.equal(peer.latest.weapon,1,'bounded repeat survives packet coalescing');
  room.tick(1/60);
  assert.equal(peer.appliedSeq,4);
  assert.equal(room.match.actors[0].weapon,0,'authority rejects unavailable rocket despite applied ACK');
  room.input(1,{seq:5,input:{}});
  assert.equal(peer.latest.weapon,undefined);
});

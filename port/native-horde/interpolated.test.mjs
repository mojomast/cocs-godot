import test from 'node:test';
import assert from 'node:assert/strict';
import {validate,onSourceSegment} from './validate.mjs';

test('remote Horde render is source-segment interpolation, never unconstrained prediction',()=>{
 const sp={wave:1,waveTarget:10,lives:3,enemiesAlive:1,enemiesTotal:1,phase:'wave',score:0,winner:null};
 const wire=[],rows=[];
 for(let seq=1;seq<=11;seq++){
  const npc={id:1,x:seq-1,y:0,z:2,health:100,dead:0};
  wire.push({direction:'out',round:1,frame:{type:'snapshot',seq,state:{singleplayer:sp,actors:[{id:0,x:0,y:0,z:0,health:100,dead:0},npc]}}});
  rows.push({round:1,seq,actor_id:0,ack:seq,model:sp,hud:'WAVE 1 / 10 LIVES 3',rendered:{
   0:{position:[0,.9,0],visible:false},1:{position:[Math.max(0,seq-1.5),.9,2],visible:true}}});
 }
 const stdout=()=>rows.map(row=>'HORDE_NATIVE '+JSON.stringify(row)).join('\n')+'\nHORDE_DONE {"ok":true}';
 assert.equal(validate(wire,stdout(),'startup',true).correlated,11);
 assert.throws(()=>validate(wire,stdout(),'startup',false),/position mismatch/,
  'the exact-pose policy cannot accidentally validate interpolated NPCs');
 rows[9].rendered[1].position=[50,.9,2];
 assert.throws(()=>validate(wire,stdout(),'startup',true),/lacks a source segment/,
  'an off-path render cannot pass merely because interpolation was enabled');
 assert(onSourceSegment([.5,.9,2],[0,.9,2],[1,.9,2]));
 assert(!onSourceSegment([.5,.9,4],[0,.9,2],[1,.9,2]));
});

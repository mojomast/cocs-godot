import test from 'node:test';
import assert from 'node:assert/strict';
import {Match,MELEE} from '../../game/core.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';

test('held Horde melee attempts once and needs a fresh press after cooldown',()=>{
 const match=new Match('chatgpt','openclaw',()=>.5,'meridian-exchange',
  {mode:'horde',difficulty:'easy',botCount:0,fragLimit:10,timeLimit:1800});
 const held=parseInputEnvelope({input:{melee:true}});
 const neutral=parseInputEnvelope({input:{melee:false}});
 assert.equal(held.melee,true);
 assert.equal(neutral.melee,false);
 const accepted=()=>match.events.filter(event=>event.type==='melee'&&event.actor===0);
 for(let i=0;i<12;i++)match.step(1/60,{inputs:{0:held}});
 assert.equal(accepted().length,1,'repeated held requests cannot bypass source cooldown');
 for(let i=0;i<Math.ceil(MELEE.cooldown*60)+2;i++)match.step(1/60,{inputs:{0:held}});
 assert.equal(accepted().length,1,'holding through cooldown cannot repeat');
 for(let i=0;i<Math.ceil(MELEE.cooldown*60)+2;i++)match.step(1/60,{inputs:{0:neutral}});
 assert.equal(accepted().length,1,'release/modal-neutral frames do not produce a kick');
 match.step(1/60,{inputs:{0:held}});
 assert.equal(accepted().length,2,'fresh request is eligible after cooldown');
});

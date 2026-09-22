// Source-derived desktop vectors for the native input test, not a second game.
import {controlsFromState,cycleWeapon} from '../../game/input.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {writeFileSync} from 'node:fs';
const state={keys:new Set(),look:{yaw:.7,pitch:.2},weapon:-1};
const ammo=['∞',4,0,8,0,0,0,0,0,3];
const cases=[];
const key=(code,pressed=true,echo=false)=>({kind:'key',code,pressed,echo});
const mouse=(button,pressed=true)=>({kind:'mouse',button,pressed});
const actions={Space:'jump',KeyR:'reload',KeyE:'interact',KeyQ:'power',KeyF:'melee',KeyG:'grenade'};
function sample(name,events=[],cancel=false) {
 if(cancel){state.keys.clear();for(const k of ['fire','fireTap','jump','reload','interact','power','melee','grenade','ads','altFire'])state[k]=false;state.weapon=-1;}
 for(const e of events) {
  if(e.kind==='key') {
   if(!e.pressed)state.keys.delete(e.code);
   else {state.keys.add(e.code);if(!e.echo&&actions[e.code])state[actions[e.code]]=true;
    if(!e.echo&&/^Digit[0-9]$/.test(e.code)){const n=e.code==='Digit0'?9:Number(e.code.slice(-1))-1;if(ammo[n])state.weapon=n;}}
  } else if(e.button===1){state.fire=e.pressed;if(e.pressed)state.fireTap=true;}
  else if(e.button===2)state.ads=e.pressed;
  else if(e.button===3)state.altFire=e.pressed;
  else if(e.pressed)state.weapon=cycleWeapon(ammo,0,state.weapon,e.button===5?1:-1);
 }
 const raw=controlsFromState(state),length=Math.hypot(raw.x,raw.z);
 if(length>1){raw.x/=length;raw.z/=length;} // equivalent to source Match movement normalization
 const expected=parseInputEnvelope({input:raw});delete expected.seq;
 cases.push({name,events,cancel,expected});
 for(const k of ['fireTap','jump','reload','interact','power','melee','grenade'])state[k]=false;
 state.weapon=-1;
}
sample('idle');
sample('fire tap between sends',[mouse(1),mouse(1,false)]);sample('tap consumed');
sample('held fire',[mouse(1)]);sample('held fire persists');sample('fire release',[mouse(1,false)]);
sample('all source one-shot presses',['KeyR','KeyE','KeyQ','KeyF','KeyG'].map(c=>key(c)));
sample('holding edge keys does not repeat');sample('OS key-repeat does not repeat',['KeyR','KeyE'].map(c=>key(c,true,true)));
sample('new reload press',[key('KeyR',false),key('KeyR')]);
sample('jump tap',[key('Space'),key('Space',false)]);sample('jump tap consumed');
sample('jump held',[key('Space')]);sample('autohop hold');sample('jump released',[key('Space',false)]);
sample('mobility held',[key('KeyX')]);sample('mobility hold');sample('mobility released',[key('KeyX',false)]);
sample('source mobility down/up between steps is released',[key('KeyX'),key('KeyX',false)]);
sample('ADS and alt held',[mouse(2),key('KeyZ')]);sample('held ADS alt');
sample('MMB alternate path',[key('KeyZ',false),mouse(3)]);sample('ADS alt released',[mouse(2,false),mouse(3,false)]);
sample('diagonal world-axis direction',[key('KeyW'),key('KeyD')]);
sample('posture alias',[key('KeyC'),key('ShiftLeft')]);
sample('weapon selection',[key('Digit2')]);sample('weapon consumed');
sample('wheel skips empty weapons',[mouse(5)]);sample('reverse wheel',[mouse(4)]);
sample('boundary clears holds and pulses',[],true);sample('after boundary remains neutral');
writeFileSync(process.argv[2],JSON.stringify({source:'game/input.mjs; app/page.tsx desktop press/reset rules',ammo,cases},null,2));
console.log(`SOURCE_INPUT_VECTORS ${cases.length}`);

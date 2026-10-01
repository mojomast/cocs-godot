import {floorAt,obstructed,visible} from './core.generated.mjs';
import {interludeDefinitions} from './interlude-definitions.mjs';

const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
export function createCampaignInterludes(data,carry={}) {
  const definitions=interludeDefinitions(data),saved=structuredClone(carry),states={};
  for(const def of definitions)states[def.id]={stage:0,choice:null,completed:false,...saved[def.id]};
  // A new transport/retry must see a released button before accepting E.
  let held=true,feedback=null,feedbackUntil=0,prompt=null;
  function eligible(player,p,arena) {
    return player.health>0&&distance(player,p)<=2.8&&Math.abs(player.y-p.y)<1.4&&
      Math.abs(player.y-floorAt(player.x,player.z,arena))<.35&&
      !obstructed(player.x,player.y,player.z,.45,arena)&&
      visible({...player,y:player.y+1.2},{...p,y:p.y+1.2},arena);
  }
  function aligned(player,target,arena) {
    const dx=target.x-player.x,dz=target.z-player.z,angle=Math.atan2(-dx,-dz);
    return Math.cos((player.yaw??0)-angle)>.965&&
      visible({...player,y:player.y+1.4},{...target,y:target.y+2.5},arena);
  }
  function reward(match,kind) {
    const player=match.actors[0];
    if(kind==='armor')player.armor=Math.min(100,player.armor+35);
    else player.ammo.forEach((amount,i)=>{const cap=match.weaponForIndex(player,i)?.cap;
      // The source starter rifle has infinite ammunition. Always include the
      // scattergun cache so an early detour has a real, immediately usable gift.
      if((amount>0||i===player.weapon||i===3)&&Number.isFinite(cap))player.ammo[i]=cap;});
  }
  function update(match,state,input,priority=false) {
    const player=match.actors[0],now=state.totalElapsed,fresh=input.interact===true&&!held;
    held=input.interact===true;prompt=null;
    if(feedback&&now>=feedbackUntil)feedback=null;
    // Main mission and Patch own E first. Combat never asks for optional work.
    if(priority||state.phase!=='playing'||state.deployed||player.health<=0)return;
    for(const def of definitions) {
      const s=states[def.id];if(s.completed||state.stepIndex<def.step)continue;
      const candidates=def.family==='choice'?['a','b']:[def.family==='link'&&s.stage===1?'b':'a'];
      const terminal=candidates.find(key=>eligible(player,def[key],match.arena));if(!terminal)continue;
      const ready=def.family!=='align'||aligned(player,def.b,match.arena);
      prompt={id:def.id,terminal,ready,text:ready?`[E] ${def.actions[terminal==='a'?0:1]}`:'Face the gold receiver, then press E'};
      if(fresh&&ready) {
        if(def.family==='link'&&s.stage===0) {
          s.stage=1;feedback={speaker:def.title,text:'Power connected. Follow the lit cable to the far control.'};
        } else {
          s.completed=true;s.stage=2;s.choice=def.family==='choice'?terminal:null;
          const kind=def.reward==='choice'?(terminal==='a'?'armor':'ammo'):def.reward;
          reward(match,kind);feedback={speaker:def.title,text:def.result+(def.family==='choice'?(kind==='armor'?' +35 armor.':' Carried ammunition refilled.'):'')};
        }
        feedbackUntil=now+5;
        match.emit('campaign-interlude',{id:def.id,stage:s.stage,completed:s.completed,choice:s.choice});
        prompt=null;
      }
      break;
    }
  }
  function snapshot(playing=true) {
    return {version:1,beats:definitions.map(def=>({...def,...states[def.id]})),
      prompt:playing?prompt:null,feedback:playing?feedback:null};
  }
  return {update,snapshot,continuity:()=>structuredClone(states)};
}

// Bounded SOURCE INPUT probe, accelerated simulation time, not native proof.
// No state mutation: a source human follows the source VIP using ordinary input.
// Records a reproducible route stall instead of claiming successful extraction.
import {Match} from '../../../game/core.mjs';
const match=new Match('chatgpt','openclaw',()=>.5,'sunscar-convoy',{mode:'vip-escort',botCount:0,humanCount:2,timeLimit:180});
const samples=[];
for(let tick=0;tick<10801&&!match.over;tick++){
 const actor=match.actors[0],vip=match.actors.find(a=>a.isVip),dx=vip?vip.x-actor.x:0,dz=vip?vip.z-actor.z:0,d=Math.hypot(dx,dz);
 match.step(1/60,{inputs:{0:{x:d>2?dx/d:0,z:d>2?dz/d:0}}});
 if(tick%1800===0)samples.push({time:match.time,actor:[actor.x,actor.z],vip:vip?[vip.x,vip.z]:null});
}
console.log(JSON.stringify({kind:'source-input-accelerated-probe',map:'sunscar-convoy',mode:'vip-escort',samples,time:match.time,progress:match.objectiveState.progress,winner:match.objectiveState.winner,escortTeam:match.objectiveState.escortTeam,extract:match.objectiveState.extract,extracted:match.events.some(e=>e.type==='vip-extracted')},null,2));

import {writeFileSync} from 'node:fs';
import {worldMatchClass} from '../../multiplayer-worlds/match.mjs';
import {readWorld} from '../../multiplayer-worlds/catalog.mjs';
const rows=[];
for(const mode of ['ctf','koth']){
 let seed=20261002;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 const Match=worldMatchClass('parallax-observatory',mode),m=new Match('chatgpt','openclaw',random,'parallax-observatory',{mode,botCount:3,humanCount:1,aiSeats:true,timeLimit:90,fragLimit:3});
 const track=m.actors.map(a=>({id:a.id,distance:0,minY:a.y,maxY:a.y,last:{x:a.x,z:a.z},stalledSeconds:0,maxStalledSeconds:0}));
 for(let i=0;i<5400&&!m.over;i++){
  m.step(1/60,{});
  if(i%60===0)for(const t of track){const a=m.actors[t.id],distance=Math.hypot(a.x-t.last.x,a.z-t.last.z);t.distance+=distance;t.minY=Math.min(t.minY,a.y);t.maxY=Math.max(t.maxY,a.y);t.stalledSeconds=distance<.25&&a.health>0?t.stalledSeconds+1:0;t.maxStalledSeconds=Math.max(t.maxStalledSeconds,t.stalledSeconds);t.last={x:a.x,z:a.z};}
 }
 rows.push({mode,seconds:m.time,reason:m.overReason,scores:m.teamScores,actors:m.actors.map(a=>({...track[a.id],health:a.health,frags:a.frags,stats:a.scoreStats})),classification:'Unscripted built-in source bot AI; seeded 90-second bounded observation, no route/actor/objective writes'});
}
const result={geometryHash:readWorld('parallax-observatory').geometryHash,rows};
writeFileSync('/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/bots.json',JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));

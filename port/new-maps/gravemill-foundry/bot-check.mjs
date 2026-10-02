import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {worldMatchClass} from '../../multiplayer-worlds/match.mjs';
import {readWorld} from '../../multiplayer-worlds/catalog.mjs';
const start=performance.now(),results=[];
for(const mode of ['domination','payload']){
 let seed=781;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 const Match=worldMatchClass('gravemill-foundry',mode),match=new Match('chatgpt','openclaw',random,'gravemill-foundry',{mode,botCount:6,humanCount:1,fragLimit:mode==='payload'?3:50,timeLimit:300});
 const bots=match.actors.filter(a=>a.bot),travel=new Map(bots.map(a=>[a.id,{distance:0,last:{x:a.x,z:a.z},maxStep:0}]));let maxPayload=0,owned=0;
 for(let i=0;i<2400&&!match.over;i++){
  match.step(.05,{inputs:{0:{}}});
  for(const a of bots){const t=travel.get(a.id),d=Math.hypot(a.x-t.last.x,a.z-t.last.z);if(d<3)t.distance+=d;t.maxStep=Math.max(t.maxStep,d);t.last={x:a.x,z:a.z};}
  maxPayload=Math.max(maxPayload,match.objectiveState?.distance??0);owned=Math.max(owned,(match.objectiveState?.zones??[]).filter(z=>z.owner!==null).length);
 }
 results.push({mode,label:'autonomous source bots; no bot input override; stationary human seat; bounded 120 simulated seconds',seconds:match.time,over:match.over,kills:match.stats.kills,maxPayloadMetres:maxPayload,maxOwnedZones:owned,teamScores:match.teamScores,bots:bots.map(a=>({id:a.id,team:a.team,distanceExcludingRespawnJumps:travel.get(a.id).distance,largestStep:travel.get(a.id).maxStep,x:a.x,y:a.y,z:a.z})),objectiveObserved:mode==='payload'?maxPayload>1:owned>0});
 console.log(JSON.stringify(results.at(-1)));
}
const report={geometryHash:readWorld('gravemill-foundry').geometryHash,milliseconds:performance.now()-start,results};
const dir=process.env.FOUNDRY_EVIDENCE??'/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002';fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(`${dir}/bot-check.json`,JSON.stringify(report,null,2)+'\n');

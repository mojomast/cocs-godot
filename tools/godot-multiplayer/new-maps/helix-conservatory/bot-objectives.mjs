import assert from 'node:assert/strict';
import fs from 'node:fs';
import {worldMatchClass} from '../../../../port/multiplayer-worlds/match.mjs';
import {readWorld} from '../../../../port/multiplayer-worlds/catalog.mjs';
const results=[];
for(const mode of ['ctf','domination']){
 let seed=61002;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 const Class=worldMatchClass('helix-conservatory',mode),m=new Class('chatgpt','openclaw',random,'helix-conservatory',{mode,humanCount:1,botCount:3,aiSeats:true,difficulty:'hard',fragLimit:mode==='ctf'?1:10,timeLimit:180});
 const initial=m.actors.map(a=>({id:a.id,x:a.x,z:a.z})),events={},walked={};const emit=m.emit.bind(m);
 m.emit=(type,data)=>{events[type]=(events[type]??0)+1;return emit(type,data);};
 let frames=0;
 while(!m.over&&frames<10801){const before=m.actors.map(a=>({x:a.x,z:a.z,health:a.health}));m.step(1/60,{inputs:{}});frames++;
  for(const a of m.actors){const b=before[a.id];if(b.health>0&&a.health>0)walked[a.id]=(walked[a.id]??0)+Math.hypot(a.x-b.x,a.z-b.z);}
 }
 console.log(JSON.stringify({mode,frames,walked,events,positions:m.actors.map(a=>({id:a.id,x:a.x,z:a.z,state:a.bot?.state,health:a.health})),over:m.over,scores:m.teamScores}));
 assert.ok(m.actors.every(a=>a.bot),'all four seats autonomous');assert.ok(Object.values(walked).some(n=>n>30),'autonomous bot traverses macro-route');assert.equal(m.stats.falls,0);
 if(mode==='ctf')assert.ok(events['flag-pickup']>0,'autonomous source bot physically picked up flag');
 else assert.ok(events['zone-capture']>0,'autonomous source bot captured zone');
 results.push({mode,classification:'autonomous source bots; no supplied inputs or post-construction state writes',frames,time:m.time,over:m.over,endReason:m.overReason,events,initial,walked,teamScores:m.teamScores,actors:m.actors.map(a=>({id:a.id,frags:a.frags,scoreStats:a.scoreStats,botState:a.bot.state}))});
}
const report={geometryHash:readWorld('helix-conservatory').geometryHash,results};
fs.writeFileSync(new URL('../../../../port/new-maps/helix-conservatory/bot-validation.json',import.meta.url),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));

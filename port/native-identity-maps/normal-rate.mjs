import {createIdentityMatch,loadRecipe} from './match.mjs';
import {EventCursor} from '../native-arenas/event-cursor.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import {gzipSync} from 'node:zlib';
import {setTimeout as delay} from 'node:timers/promises';
const dir=new URL(`./evidence/normal-rate-${Date.now()}/`,import.meta.url);mkdirSync(dir,{recursive:true});
async function run(id,limit){
 const recipe=loadRecipe(id);writeFileSync(new URL(id+'-recipe.json.gz',dir),gzipSync(JSON.stringify(recipe)));
 let m=createIdentityMatch(id,{timeLimit:60,difficulty:'easy',fragLimit:id==='nacre-engine'?3:15});
 const records=[],events=[],rounds=[];let cursor=new EventCursor(),ticks=0,round=1,restarts=0,maxWave=0,last=performance.now(),acc=0;const begin=last;
 while(performance.now()-begin<limit*1000){
  const now=performance.now();acc=Math.min(acc+(now-last)/1000,5/60);last=now;
  while(acc>=1/60){
   acc-=1/60;
   const me=m.actors[0],enemies=m.actors.filter(a=>a.id!==0&&a.health>0&&(id==='lacuna-court'||a.team!==me.team));
   enemies.sort((a,b)=>Math.hypot(a.x-me.x,a.z-me.z)-Math.hypot(b.x-me.x,b.z-me.z));
   const enemy=enemies[0];let input={};
   if(enemy){const dx=enemy.x-me.x,dz=enemy.z-me.z,d=Math.hypot(dx,dz);input={yaw:Math.atan2(-dx,-dz),pitch:Math.atan2((enemy.y+1.1)-(me.y+1.6),d),fire:true,reload:me.ammo===0};}
   // Plain controls only; no actor pose/health/score/time injection.
   if(id==='vermilion-fold'){const goal=m.objectiveState.zones.find(z=>z.owner!==me.team)??m.objectiveState.zones[1],dx=goal.x-me.x,dz=goal.z-me.z,d=Math.hypot(dx,dz);if(d>2)Object.assign(input,{x:dx/d,z:dz/d});}
   m.step(1/60,{inputs:{0:input}});ticks++;
   const batch=cursor.take(m);events.push(...batch.map(e=>({round,...e})));
   if(ticks%3===0)records.push({round,wallMs:now-begin,sourceTime:m.time,state:m.snapshot()});
   maxWave=Math.max(maxWave,m.modeState?.wave??0);
   if(m.over){rounds.push({round,state:m.snapshot(),sourceTime:m.time});if(restarts===0){m=createIdentityMatch(id,{timeLimit:60,difficulty:'easy',fragLimit:id==='nacre-engine'?3:15});cursor=new EventCursor();restarts++;round++;acc=0;}else break;}
  }
  if(rounds.length>=2)break;
  await delay(4);
 }
 const types={};for(const e of events)types[e.type]=(types[e.type]??0)+1;
 const result={id,scope:'Normal wall-rate in-process source Match with ordinary controls. No WebSocket/Godot client integration, no pose/health/score injection.',elapsedMs:performance.now()-begin,ticks,snapshots:records.length,eventTypes:types,roundResults:rounds.map(r=>({round:r.round,time:r.sourceTime,over:r.state.over})),restarts,maxWave,final:m.snapshot()};
 writeFileSync(new URL(id+'.json',dir),JSON.stringify(result,null,2));writeFileSync(new URL(id+'-snapshots.jsonl.gz',dir),gzipSync(records.map(r=>JSON.stringify(r)).join('\n')));writeFileSync(new URL(id+'-events.jsonl.gz',dir),gzipSync(events.map(r=>JSON.stringify(r)).join('\n')));console.log(JSON.stringify({id,ticks,snapshots:records.length,eventTypes:types,restarts,maxWave,results:rounds.length}));return result;
}
console.log('Evidence '+dir.pathname);await Promise.all([run('lacuna-court',130),run('vermilion-fold',130),run('nacre-engine',180)]);

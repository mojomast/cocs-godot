import assert from 'node:assert/strict';
import {arena,walk,matchFor} from './source-check.mjs';
import {aimedControls} from '../../../../port/native-arenas/tests/fixtures.mjs';
const results=[];
for(const mode of ['deathmatch','teamdeathmatch']){
 const m=matchFor(mode,{humanCount:2,timeLimit:60,fragLimit:5});
 const a=m.actors[0],b=m.actors[1];
 // Setup only. After this point all movement, damage, score and respawns are source.
 Object.assign(a,{x:-120,y:12,z:0,vx:0,vy:0,vz:0,protection:0});
 Object.assign(b,{x:-92,y:12,z:0,vx:0,vy:0,vz:0,protection:0});
 walk(a,[[-102,0]],input=>m.step(1/60,{inputs:{0:input,1:{}}}));
 while(!m.over&&m.time<61)m.step(1/60,{inputs:{0:aimedControls(m),1:{}}});
 assert.ok(m.over);assert.ok(a.frags>0,'ordinary fire produced scored frag');assert.ok(a.frags>b.frags);assert.ok(m.snapshot().leaders.length);
 results.push({mode,frags:a.frags,winner:m.snapshot().winner,reason:m.snapshot().overReason,time:m.time});
}
{
 const m=matchFor('ctf'),a=m.actors[0];
 // Source team spawn is the start; there are no placement writes in this round.
 const step=input=>{m.step(1/60,{inputs:{0:input}});return m.over;};
 walk(a,[[-120,a.z],[-120,0]],step);
 for(let capture=0;capture<m.config.fragLimit;capture++){
  const outward=capture%2===0?[[ -120,-85],[120,-85],[120,0]]:[[-120,85],[120,85],[120,0]];
  walk(a,outward,step);assert.equal(a.carryingFlag,true);
  walk(a,[[-120,0]],step);
  if(!m.over)for(let t=0;t<60;t++)step({});
 }
 assert.ok(m.over);assert.equal(m.snapshot().winner,0);assert.equal(a.scoreStats.captures,m.config.fragLimit);
 results.push({mode:'ctf',captures:a.scoreStats.captures,winner:m.snapshot().winner,reason:m.snapshot().overReason,time:m.time});
}
for(const mode of ['domination','koth','uplink']){
 const m=matchFor(mode,{fragLimit:12}),a=m.actors[0],step=input=>{m.step(1/60,{inputs:{0:input}});return m.over;};
 walk(a,[[-120,a.z],[-120,0]],step);
 let ticks=0;
 while(!m.over&&ticks++<24000){const zones=m.objectiveState.zones,target=mode==='domination'?zones[0]:zones[0];
  if(Math.hypot(a.x-target.x,a.z-target.z)>.4)walk(a,[[target.x,target.z]],step);else step({});
 }
 assert.ok(m.over,mode+' completed');assert.equal(m.snapshot().winner,0);assert.ok(a.scoreStats.objectiveTime>0||a.scoreStats.objectiveCaptures>0,JSON.stringify({mode,stats:a.scoreStats}));
 results.push({mode,objectiveTime:a.scoreStats.objectiveTime,captures:a.scoreStats.objectiveCaptures,winner:m.snapshot().winner,reason:m.snapshot().overReason,time:m.time});
}
console.log(JSON.stringify({gate:'controlled source full scored rounds; ordinary inputs; no position writes after setup',map:arena.id,results}));

// Process-scoped map injection: frozen game files and published registries stay intact.
// Only getMap's template lookup is extended; Match/movement/combat/objectives run unchanged.
import {registerHooks} from 'node:module';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import {recipe,hash} from './recipe.mjs';
const mapsURL=new URL('../../../../game/maps.mjs',import.meta.url).href;
const recipeURL=new URL('./recipe.mjs',import.meta.url).href;
const hook=registerHooks({load(url,context,next){const loaded=next(url,context);if(url!==mapsURL)return loaded;
 const old="export const getMap=id=>MAPS.find(m=>m.id===id)||MAPS[0];";
 const text=String(loaded.source);assert.ok(text.includes(old),'scoped map injection anchor changed');
 return {...loaded,source:`import {recipe as helixFixtureArena} from '${recipeURL}';\n`+text.replace(old,"export const getMap=id=>id==='helix-conservatory'?helixFixtureArena:MAPS.find(m=>m.id===id)||MAPS[0];")};}});
const {Match,floorAt,walkEdge,visible}=await import('../../../../game/core.mjs');
hook.deregister();
const DT=1/60,results=[];
function fixture(mode,options={}){
 let seed=61002;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 const match=new Match('chatgpt','openclaw',random,recipe.id,{mode,botCount:0,humanCount:2,fragLimit:5,timeLimit:900,respawn:1,...options});
 assert.equal(match.arena,recipe);assert.equal(match.config.mode,mode);
 const trace=createHash('sha256');
 const log={mode,kind:'controlled-input-full-round',config:{...match.config},frames:0,walkedMetres:0,maxLiveStep:0,minY:Infinity,maxY:-Infinity,events:{},milestones:[],setup:[],endReason:null};
 const emit=match.emit.bind(match);match.emit=(type,data)=>{log.events[type]=(log.events[type]??0)+1;if(['flag-pickup','flag-drop','flag-return','capture','zone-capture','juggernaut-transfer','objective-win'].includes(type))log.milestones.push({type,frame:log.frames,time:match.time,data,positions:match.actors.map(a=>({id:a.id,x:a.x,y:a.y,z:a.z}))});return emit(type,data);};
 function setup(id,x,z){assert.equal(log.frames,0,'position setup is forbidden after stepping');const a=match.actors[id],y=floorAt(x,z,recipe);Object.assign(a,{x,y,z,lastValid:{x,y,z},vx:0,vy:0,vz:0});log.setup.push({id,x,y,z});}
 function step(inputs={}){
  assert.ok(!match.over,'fixture attempted inputs after round end');
  const before=match.actors.map(a=>({x:a.x,z:a.z,alive:a.health>0}));
  match.step(DT,{inputs});log.frames++;
  trace.update(JSON.stringify({inputs,positions:match.actors.map(a=>[a.id,a.x,a.y,a.z,a.health])})+'\n');
  for(const a of match.actors){assert.ok([a.x,a.y,a.z].every(Number.isFinite));log.minY=Math.min(log.minY,a.y);log.maxY=Math.max(log.maxY,a.y);const b=before[a.id],d=Math.hypot(a.x-b.x,a.z-b.z);if(b.alive&&a.health>0){assert.ok(d<.8,`nonphysical displacement ${d}`);log.walkedMetres+=d;log.maxLiveStep=Math.max(log.maxLiveStep,d);}}
  assert.equal(match.stats.falls,0,'unexpected map fall');assert.ok(log.frames<54000,'900s fixture budget exceeded');
 }
 const nearest=p=>{let best=-1,d=Infinity;match.nav.forEach((n,i)=>{const q=Math.hypot(n.x-p.x,n.z-p.z);if(q<d&&walkEdge({...p,y:floorAt(p.x,p.z,recipe)},n,recipe)){d=q;best=i;}});assert.ok(best>=0,`no graph attachment ${JSON.stringify(p)}`);return best;};
 function path(id,target){const start=nearest(match.actors[id]),end=nearest(target),prev=new Map([[start,null]]),queue=[start];
  for(let k=0;k<queue.length&&!prev.has(end);k++)for(const j of match.edges[queue[k]])if(!prev.has(j)){prev.set(j,queue[k]);queue.push(j);}
  assert.ok(prev.has(end),'disconnected source navigation');const route=[];for(let n=end;n!==null;n=prev.get(n))route.push(match.nav[n]);return [...route.reverse(),target];
 }
 function walk(id,target){for(const p of path(id,target)){let count=0;const a=match.actors[id];while(Math.hypot(p.x-a.x,p.z-a.z)>.12&&!match.over){assert.ok(a.health>0,'walker died');assert.ok(count++<900,`${mode} actor ${id} stalled ${a.x},${a.z} -> ${p.x},${p.z}`);step({[id]:{x:p.x-a.x,z:p.z-a.z}});}}}
 function wait(seconds){for(let i=0;i<Math.ceil(seconds/DT)&&!match.over;i++)step();}
 function finish(){assert.equal(match.over,true,'round did not finish');assert.ok(['capture','frag','objective'].includes(match.overReason),'round must finish by scoring, not timeout');log.endReason=match.overReason;log.seconds=match.time;log.walkedMetres=Number(log.walkedMetres.toFixed(3));log.trajectoryHash=trace.digest('hex');log.falls=match.stats.falls;log.teamScores={...match.teamScores};log.actors=match.actors.map(a=>({id:a.id,frags:a.frags,deaths:a.deaths,scoreStats:{...a.scoreStats}}));results.push(log);console.log(JSON.stringify(log));}
 return {match,log,setup,step,walk,wait,finish};
}

test('controlled CTF: physically steal/drop/return, then walk three captures to round end',()=>{
 const f=fixture('ctf',{fragLimit:3}),m=f.match;
 f.setup(0,-86,-5);f.setup(1,86,5);
 // Enemy physically steals the home flag, carries it out, and presses interact to drop.
 f.walk(1,{x:-86,z:0});assert.equal(m.flags[0].carrier,1);
 f.walk(1,{x:-86,z:12});f.step({1:{interact:true}});assert.equal(m.flags[0].state,'dropped');
 const drop={x:m.flags[0].x,z:m.flags[0].z};
 // Move away immediately, within the real one-second pickup lock.
 for(let i=0;i<45;i++)f.step({1:{z:1}});
 assert.equal(m.flags[0].state,'dropped');
 f.walk(0,drop);assert.equal(m.flags[0].state,'at-base');assert.equal(m.actors[0].scoreStats.flagReturns,1);
 f.walk(1,{x:0,z:-86});
 for(let capture=1;capture<=3;capture++){
  f.walk(0,{x:86,z:0});assert.equal(m.flags[1].carrier,0,'physical flag pickup');
  f.walk(0,{x:-86,z:0});assert.equal(m.teamScores[0],capture,'physical home capture');
 }
 assert.equal(m.actors[0].scoreStats.flagPickups,3);assert.equal(m.actors[0].scoreStats.captures,3);
 assert.equal(f.log.events['flag-drop'],1);assert.equal(f.log.events['flag-return'],1);assert.equal(f.log.events.capture,3);f.finish();
});

for(const mode of ['deathmatch','teamdeathmatch','arsenal'])test(`controlled ${mode}: input-fired kills, natural respawns, physically rejoined duel, full round`,()=>{
 const f=fixture(mode,{startingWeapon:2,unlimitedAmmo:true}),m=f.match;
 // Allowed source configuration: rail starting weapon + unlimited ammo, not damage injection.
 f.log.loadout='source config startingWeapon=2, unlimitedAmmo=true; Full Arsenal keeps its native all-weapons loadout';
 f.setup(0,-3,0);f.setup(1,3,0);
 if(mode==='arsenal')assert.ok(m.actors[0].ammo.every(n=>n===Infinity));
 for(let kill=1;kill<=m.config.fragLimit;kill++){
  if(kill>1){while(m.actors[1].health<=0)f.step();f.walk(1,{x:3,z:0});}
  let frames=0;
  while(m.actors[1].health>0&&!m.over){assert.ok(frames++<900,'controlled duel exceeded 15 seconds');const a=m.actors[0],b=m.actors[1],dx=b.x-a.x,dz=b.z-a.z,dy=b.y+1-a.y-a.eyeHeight;
   assert.ok(visible({x:a.x,y:a.y+1.45,z:a.z},{x:b.x,y:b.y+1,z:b.z},recipe));
   f.step({0:{weapon:2,yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(dy,Math.hypot(dx,dz)),fire:true}});
  }
  assert.equal(m.actors[0].frags,kill);
 }
 assert.equal(m.actors[1].deaths,5);assert.ok(m.stats.shots>=5);assert.ok(m.stats.respawns>=4);f.finish();
});

test('controlled Juggernaut: input-fired role transfer then physical role-hold to objective win',()=>{
 const f=fixture('juggernaut',{fragLimit:15,startingWeapon:2,unlimitedAmmo:true}),m=f.match;
 f.setup(0,-3,0);f.setup(1,3,0);
 const original=m.objectiveState.juggernautId,killer=1-original;
 let frames=0;
 while(m.objectiveState.juggernautId===original){assert.ok(frames++<900);const a=m.actors[killer],b=m.actors[original];
  f.step({[killer]:{fire:true,yaw:Math.atan2(a.x-b.x,a.z-b.z),pitch:Math.atan2(b.y+1-a.y-a.eyeHeight,Math.hypot(a.x-b.x,a.z-b.z))}});
 }
 assert.equal(m.objectiveState.juggernautId,killer);assert.equal(m.actors[killer].frags,1);
 f.walk(killer,{x:0,z:12});f.wait(30);assert.equal(m.objectiveState.winner,killer);assert.ok(f.log.events['juggernaut-transfer']>=1);f.finish();
});

for(const mode of ['domination','koth'])test(`controlled ${mode}: walk from canopy spawn into actual zone and occupy through full round`,()=>{
 const f=fixture(mode,{fragLimit:5}),m=f.match;
 f.setup(0,-86,0);f.setup(1,86,5);
 const zone=m.objectiveState.zones[0];f.log.zone={x:zone.x,y:zone.y,z:zone.z,radius:zone.radius};
 f.walk(0,zone);f.wait(25);
 assert.equal(m.over,true);assert.ok(m.teamScores[0]>=5);assert.ok(m.actors[0].scoreStats.objectiveTime>=5);assert.ok(m.actors[0].scoreStats.objectiveCaptures>=1);f.finish();
});

after(()=>{
 if(results.length!==7)return;
 const report={schemaVersion:1,id:recipe.id,recipeContentHash:hash(recipe),classification:'scripted controlled source inputs; no native or human claim',validatedSourceModes:results.map(r=>r.mode),modeBindingsRemainPending:true,results};
 const dest=new URL('../../../../port/new-maps/helix-conservatory/source-validation.json',import.meta.url);
 const bytes=JSON.stringify(report,null,2)+'\n';
 if(process.env.HELIX_WRITE_SOURCE_REPORT==='1')fs.writeFileSync(dest,bytes);
});

// Explicit upstream-worktree harness while intake is pending. Never imported
// by the product authority and never used to bypass the semantic source lock.
import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
import {cinderwake} from './cinderwake.mjs';
const root=resolve(process.env.CINDERWAKE_SOURCE_ROOT||'.');
const {Match,floorAt,obstructed}=await import(pathToFileURL(resolve(root,'game/core.mjs')));
const {updateSinglePlayer,spawnGroup,hordeWavePlan}=await import(pathToFileURL(resolve(root,'game/singleplayer.mjs')));
const {ENEMY_TYPES}=await import(pathToFileURL(resolve(root,'game/enemy-types.mjs')));
console.log('Controlled upstream fixtures; source revision',execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim());
const recipe=cinderwake();
const make=target=>new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'horde',difficulty:'normal',botCount:0,fragLimit:target,timeLimit:1800,hordeArena:recipe.arena});
const tick=(m,n)=>{for(let i=0;i<n;i++)updateSinglePlayer(m,1/60);};

test('real upstream controller consumes new recipe; each target 1..30 terminates before further transit',()=>{
 assert.equal(typeof Match.prototype.applyHordeGateMask,'function','approved upstream stage module required');
 for(let target=1;target<=30;target++){
  const m=make(target);assert.equal(m.modeState.lives,3);
  for(let wave=1;wave<=target;wave++){
   // Controlled wave-clear setup. Composition itself is source hordeWavePlan.
   m.modeState.wave=wave;m.modeState.phase='wave';m.modeState.enemies=[];m.actors=m.actors.filter(a=>a.id===0);
   tick(m,1);
   if(wave===target){assert(m.over);assert.equal(m.modeState.phase,'won');assert.equal(m.modeState.stage.transit,null);break;}
   const schedule=recipe.arena.hordeStagePlan.transitions.find(t=>t.afterWave===wave);
   if(!schedule)continue;
   assert(m.modeState.stage.transit);
   tick(m,180);assert.equal(m.modeState.wave,wave);
   const stage=recipe.arena.hordeStagePlan.stages.find(s=>s.id===schedule.to),r=stage.arrival;
   Object.assign(m.actors[0],{x:(r.minX+r.maxX)/2,z:(r.minZ+r.maxZ)/2,y:0,grounded:true});
   tick(m,122);assert.equal(m.modeState.stage.stageId,stage.id);assert.equal(m.modeState.stage.transit,null);
   assert.deepEqual(m.teamSpawns[1],stage.enemySpawns);
  }
 }
 for(const wave of [9,18,27])assert(hordeWavePlan(wave,'normal').counts.boss);
});
test('source NPC archetypes, including champions and summons, spawn supported in every gate mask',()=>{
 const m=make(30);
 for(let mask=0;mask<4;mask++){
  m.applyHordeGateMask(mask);
  for(const stage of recipe.arena.hordeStagePlan.stages){
   assert(m.hordeStageReachable(stage),`mask ${mask}, ${stage.id}`);
   m.teamSpawns={0:stage.humanSpawns,1:stage.enemySpawns};
   for(const type of Object.keys(ENEMY_TYPES)){
    m.actors=m.actors.filter(a=>a.id===0);m.modeState.enemies=[];
    const ids=spawnGroup(m,m.modeState,{type,count:1},{team:1}),npc=m.actors.find(a=>a.id===ids[0]);
    assert(npc?.isNpc,type);assert.notEqual(floorAt(npc.x,npc.z,m.arena),null);assert(!obstructed(npc.x,npc.y,npc.z,undefined,m.arena),`${type} mask ${mask}`);
   }
  }
 }
 const fresh=make(30);assert.equal(fresh.modeState.stage.gateMask,0);assert.equal(recipe.arena.blocks.some(b=>b.id==='G_BC'),false);
 const npc=m.actors.find(a=>a.isNpc);assert(npc?.bot);npc.bot.route=[0,1];npc.bot.think=10;
 const previousArena=m.arena;m.applyHordeGateMask(0);assert.notEqual(m.arena,previousArena);assert.deepEqual(npc.bot.route,[]);assert.equal(npc.bot.think,0);
});
test('ordinary Match.step starts the natural first wave with unchanged pacing; death/restart uses source rules',()=>{
 const m=make(10);for(let i=0;i<299;i++)m.step(1/60,{});assert.equal(m.modeState.wave,0);
 for(let i=0;i<3;i++)m.step(1/60,{});assert.equal(m.modeState.wave,1);assert(m.modeState.enemies.length>0);
 for(let life=2;life>=0;life--){m.actors[0].health=0;m.actors[0].deaths++;tick(m,1);assert.equal(m.modeState.lives,life);}
 assert(m.over);assert.equal(m.modeState.phase,'lost');const fresh=make(10);assert.equal(fresh.modeState.wave,0);assert.equal(fresh.modeState.lives,3);
});

test('controlled clear followed by actual input-driven travel causes arrival then later wave start',()=>{
 const m=make(10);m.modeState.phase='wave';m.modeState.wave=2;m.step(1/60,{});
 const begin=m.events.find(e=>e.type==='horde-transit-begin');assert(begin);
 // Waiting at the actual source spawn cannot advance the next wave.
 for(let i=0;i<600;i++)m.step(1/60,{});assert.equal(m.modeState.wave,2);
 const targets=[{x:0,z:58},...recipe.routes.find(r=>r.id==='A-B').points.slice(1),...recipe.routes.find(r=>r.id==='B-C').points.slice(1)];
 for(const p of targets){let steps=0;while(Math.hypot(m.actors[0].x-p.x,m.actors[0].z-p.z)>.2&&steps++<1800){const human=m.actors[0];m.step(1/60,{x:p.x-human.x,z:p.z-human.z});}assert(steps<1800,'input traversal must not stall');}
 for(let i=0;i<35;i++)m.step(1/60,{});
 const entered=m.events.find(e=>e.type==='horde-stage-entered'),wave=m.events.find(e=>e.type==='horde-wave'&&e.wave===3);
 assert(entered&&wave);assert.equal(entered.causeEventId,begin.causeEventId);assert(entered.arrivalTicks>=30);assert(entered.time<wave.time);assert.equal(m.modeState.stage.stageId,'C');
});

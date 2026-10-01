import test from 'node:test';
import assert from 'node:assert/strict';
import {createHordeMatch,HORDE_MAPS} from './authority.mjs';
import {ROBOT_FOR_ROLE,ROBOT_SILHOUETTE,hordeRobotState} from './robot-roles.mjs';
import {BLACKWATER_STATIONS} from './blackwater-director.mjs';
import {floorAt} from '../../game/core.mjs';

const config={mode:'horde',botCount:0,difficulty:'easy',fragLimit:10,timeLimit:900};
test('all six local Horde arenas field source Warden once on final wave with a real hit volume',()=>{
 for(const mapId of HORDE_MAPS){
  const match=createHordeMatch({mapId,config,random:()=>.5});
  match.modeState.wave=9;match.modeState.phase='intermission';match.modeState.timer=0;
  match.step(1/60,{inputs:{0:{}}});
  const boss=match.actors.filter(a=>a.isNpc&&a.npcType==='warden');
  assert.equal(boss.length,1,mapId);
  assert.equal(boss[0].hitScale,2,mapId);
  assert.equal(boss[0].maxHealth,450,mapId);
  assert.equal(match.modeState.boss,boss[0].id,mapId);
  assert(match.modeState.enemies.includes(boss[0].id),mapId);
  const actual=match.snapshot().actors.find(a=>a.id===boss[0].id);
  assert.equal(hordeRobotState({actors:[actual]}).actors[0].npcModel,'warden',mapId);
  assert.equal(match.actors[0].hitScale,1,mapId);
  assert(match.actors.filter(a=>a.isNpc).length<=13,mapId+' exceeds easy live cap + boss allowance');
 }
});

test('source role brain and health are preserved while derived hit volumes track new robot silhouettes',()=>{
 const match=createHordeMatch({mapId:'blackwater-reclamation',config,random:()=>.5});
 match.modeState.timer=0;
 match.step(1/60,{inputs:{0:{}}});
 assert.equal(match.modeState.wave,1);
 for(const a of match.actors.filter(a=>a.isNpc)){
  assert.equal(a.hitScale,ROBOT_SILHOUETTE[a.npcType].hitScale);
  assert.equal(a.maxHealth,a.npcProfile.health);
  const shown=hordeRobotState({actors:[a]}).actors[0];
  assert.equal(shown.npcModel,ROBOT_FOR_ROLE[a.npcType]);
  assert.equal(shown.npcProfile.scale,ROBOT_SILHOUETTE[a.npcType].scale);
  assert.equal(a.npcProfile.scale!==undefined,true,'source profile unchanged');
 }
});

test('full Blackwater objective chain advances through real authority steps and resets independently',()=>{
 const match=createHordeMatch({mapId:'blackwater-reclamation',config,random:()=>.5});
 const player=match.actors[0];
 // Controlled intermission fixture isolates interaction/physics from combat;
 // it is not a natural-wave completion or gameplay capture.
 match.modeState.phase='intermission';match.modeState.timer=1e6;
 for(const station of BLACKWATER_STATIONS){
  match.modeState.wave=station.wave;
  Object.assign(player,{x:station.x,y:floorAt(station.x,station.z,match.arena),z:station.z,
   vx:0,vy:0,vz:0,grounded:true,health:Math.max(player.health,20)});
  match.step(1/60,{inputs:{0:{interact:true}}});
  for(let i=0;i<=station.seconds*60;i++)match.step(1/60,{inputs:{0:{}}});
  assert(match.snapshot().blackwater.completed.includes(station.id),station.id);
 }
 const final=match.snapshot();
 assert.equal(final.blackwater.serial,4);
 assert.equal(final.blackwater.completed.length,4);
 assert.equal(final.actors[0].health,final.actors[0].maxHealth);
 assert(match.events.some(e=>e.type==='horde-resupply'));
 const later=match.snapshot();
 assert.deepEqual(later.blackwater.completed,final.blackwater.completed,'late snapshot carries full state');
 const retry=createHordeMatch({mapId:'blackwater-reclamation',config,random:()=>.5});
 assert.deepEqual(retry.snapshot().blackwater.completed,[]);
 assert.equal(retry.snapshot().blackwater.serial,0);
});

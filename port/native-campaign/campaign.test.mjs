import test from 'node:test';
import assert from 'node:assert/strict';
import {createCampaignMatch} from './match.mjs';
import {loadCampaignMap} from './maps.mjs';
import {MISSION_IDS, MISSIONS} from './missions.mjs';
import {ROBOTS, MAX_ACTIVE_ENEMIES, deployEncounter} from './enemies.mjs';
import {validateCampaignInput} from './authority.mjs';
import {updateEnemyRoles} from '../../game/singleplayer.mjs';

const rng=()=>{let n=8157;return()=>((n=Math.imul(n,1664525)+1013904223>>>0)/4294967296);};
function make(id=MISSION_IDS[0], extra={}) {return createCampaignMatch({mapId:id,random:rng(),...extra});}
function at(match, point) {Object.assign(match.actors[0],{x:point.x,y:point.y,z:point.z,vx:0,vy:0,vz:0,lastValid:{x:point.x,y:point.y,z:point.z},protection:100});}
function tick(match, input={}) {match.step(1/60,{inputs:{0:input}});}
function clear(match) {
  for(const actor of match.actors.filter(a=>a.isNpc&&a.health>0)) {
    actor.protection=0;
    // Exercise the actual source kill path, not objective-state mutation.
    for(let i=0;i<100&&actor.health>0;i++) match.damage(actor,1000,match.actors[0],true);
    assert.ok(actor.health<=0,`source damage kills ${actor.npcType}`);
  }
}
function finishLevel(match,data) {
  for(let i=0;i<5;i++) {
    at(match,data.campaign.anchors[`encounter-${i+1}`]);tick(match);
    assert.equal(match.snapshot().campaign.stepIndex,i);
    assert.ok(match.actors.filter(a=>a.isNpc&&a.health>0).length<=MAX_ACTIVE_ENEMIES);
    assert.ok(match.actors.every((actor,index)=>actor.id===index));
    clear(match);tick(match,{interact:true});
    for(let n=0;n<1000&&match.snapshot().campaign.stepIndex===i;n++)tick(match,{interact:true});
    assert.equal(match.snapshot().campaign.stepIndex,i+1);
  }
  at(match,data.campaign.anchors.exit);tick(match);
  assert.equal(match.snapshot().campaign.phase,'level-complete');
}

test('authored palettes teach six actual source brains within a finite budget',()=>{
  const seen=new Set();
  for(const mission of Object.values(MISSIONS)) {
    assert.equal(mission.encounters.length,5);
    for(const encounter of mission.encounters) {
      assert.ok(Object.keys(encounter.roster).length<=3);
      assert.ok(Object.values(encounter.roster).reduce((a,b)=>a+b,0)<=MAX_ACTIVE_ENEMIES);
      for(const model of Object.keys(encounter.roster)){assert.ok(ROBOTS[model]);seen.add(model);}
    }
  }
  assert.equal(seen.size,6);
});
test('ordinary ticks gate future anchors, require combat, and advance exactly once',()=>{
  const match=make(),data=loadCampaignMap(MISSION_IDS[0]);
  at(match,data.campaign.anchors.exit);tick(match);
  assert.equal(match.snapshot().campaign.stepIndex,0);
  at(match,data.campaign.anchors['encounter-1']);tick(match);
  assert.equal(match.snapshot().campaign.stepIndex,0);
  const ids=match.actors.filter(a=>a.isNpc).map(a=>a.id);tick(match);
  assert.deepEqual(match.actors.filter(a=>a.isNpc).map(a=>a.id),ids);
  clear(match);tick(match);assert.equal(match.snapshot().campaign.stepIndex,1);
  for(let i=0;i<60;i++)tick(match);
  assert.equal(match.snapshot().campaign.stepIndex,1);
  assert.equal(match.events.filter(e=>e.type==='campaign-objective-complete').length,1);
});
test('death freezes controls and retry reconstructs an unsolved checkpoint without stale actors/projectiles',()=>{
  const match=make('crown-array'),data=loadCampaignMap('crown-array');
  at(match,data.campaign.anchors['encounter-1']);tick(match);
  const expected=match.actors.filter(a=>a.isNpc).length;
  match.actors[0].protection=0;match.damage(match.actors[0],100000,undefined,true);tick(match);
  assert.equal(match.snapshot().campaign.phase,'dead');
  const position={x:match.actors[0].x,z:match.actors[0].z};tick(match,{x:1,fire:true});
  for(let i=0;i<1200;i++)tick(match,{fire:true});
  assert.equal(match.snapshot().campaign.phase,'dead');
  assert.equal(match.snapshot().campaign.marker,null);
  assert.equal(match.actors[0].x,position.x);
  const retry=make('crown-array',match.campaignCheckpoint());tick(retry);
  assert.equal(retry.snapshot().campaign.phase,'playing');assert.ok(retry.actors[0].health>0);
  assert.equal(retry.actors.filter(a=>a.isNpc).length,expected);assert.equal(retry.rockets.length,0);
  assert.equal(retry.snapshot().campaign.stepIndex,0);
});
test('dead NPC indexed slots stay dead beyond respawn delay and the base clock cannot end play',()=>{
  const match=make(),data=loadCampaignMap(MISSION_IDS[0]);
  at(match,data.campaign.anchors['encounter-1']);tick(match);
  const enemy=match.actors[1];enemy.protection=0;
  for(let i=0;i<100&&enemy.health>0;i++)match.damage(enemy,1000,match.actors[0],true);
  for(let i=0;i<900;i++)tick(match);
  assert.ok(enemy.health<=0);assert.equal(match.actors[enemy.id],enemy);
  match.config.timeLimit=1;tick(match);
  assert.equal(match.over,false);
  assert.equal(match.actors[0].team,0);
  assert.ok(match.actors.filter(a=>a.isNpc).every(a=>a.team===1));
});
test('all four chapters complete through ticks, interaction gates, and a non-looping ending',()=>{
  let elapsed=0,kills=0;
  for(const [index,id] of MISSION_IDS.entries()) {
    const data=loadCampaignMap(id),match=make(id,{totalElapsed:elapsed,kills});
    finishLevel(match,data);
    const status=match.snapshot().campaign;
    assert.equal(status.nextMapId,MISSION_IDS[index+1]??null);
    assert.ok(status.totalElapsed>elapsed);elapsed=status.totalElapsed;kills=status.kills;
    match.completeCampaign();
    assert.equal(match.snapshot().campaign.phase,index===3?'campaign-complete':'level-complete');
  }
});
test('source artillery telegraphs a fixed point and resolves real damage',()=>{
  const match=make('siltwake-crossing',{checkpoint:2}),data=loadCampaignMap('siltwake-crossing');
  at(match,data.campaign.anchors['encounter-3']);tick(match);
  const mortar=match.actors.find(a=>a.npcModel==='mortar'),player=match.actors[0];
  player.x=mortar.x+15;player.z=mortar.z;player.protection=0;player.armor=0;
  mortar.artilleryCooldown=0;
  updateEnemyRoles(match,match.modeState,1/60);
  assert.ok(mortar.artilleryMark);assert.ok(match.events.some(e=>e.type==='enemy-telegraph'&&e.kind==='artillery'));
  const health=player.health;
  updateEnemyRoles(match,match.modeState,1.3);
  assert.ok(player.health<health);assert.ok(match.events.some(e=>e.type==='enemy-artillery'&&e.hit));
});
test('restoration requires an interaction pulse, pauses outside, then finishes on natural ticks',()=>{
  const match=make('rootfall-verge',{checkpoint:2}),data=loadCampaignMap('rootfall-verge');
  const anchor=data.campaign.anchors['encounter-3'];
  at(match,anchor);tick(match);clear(match);
  for(let i=0;i<60;i++)tick(match);
  assert.equal(match.snapshot().campaign.holdProgress,0);
  assert.equal(match.snapshot().campaign.stepIndex,2);
  tick(match,{interact:true});
  const progress=match.snapshot().campaign.holdProgress;
  at(match,data.campaign.anchors.start);for(let i=0;i<60;i++)tick(match);
  assert.equal(match.snapshot().campaign.holdProgress,progress);
  at(match,anchor);for(let i=0;i<370;i++)tick(match);
  assert.equal(match.snapshot().campaign.stepIndex,3);
});
test('source hitscan collision accepts shots through every visible chassis after spawn',()=>{
  for(const [model,robot] of Object.entries(ROBOTS)) {
    const match=make(),anchor=loadCampaignMap(MISSION_IDS[0]).campaign.anchors['encounter-1'];
    deployEncounter(match,match.modeState,{roster:{[model]:1}},anchor);
    const enemy=match.actors[1];enemy.protection=0;
    assert.equal(enemy.hitScale,robot.hitScale);
    const before=enemy.health+enemy.armor;
    // pierceAlong uses the same private hitActor/actorHit slabs as source fire.
    const from={x:enemy.x+robot.chassis[0]*.4,y:enemy.y+robot.chassisY,z:enemy.z-10};
    match.pierceAlong(from,{x:0,y:0,z:1},20,{id:-1},{pierce:1,damage:20},1,match.actors[0]);
    assert.ok(enemy.health+enemy.armor<before,`${model} visible chassis point takes source damage`);
  }
});
test('finite typed inputs and cancellation validate at the wire boundary',()=>{
  const base={type:'input',seq:1,inputEpoch:1,input:{x:1,z:0,fire:true}};
  assert.equal(validateCampaignInput(base).fire,true);
  for(const value of [Infinity,NaN,'1',null])assert.throws(()=>validateCampaignInput({...base,input:{x:value}}));
  assert.throws(()=>validateCampaignInput({...base,input:{fire:1}}));
  assert.throws(()=>validateCampaignInput({...base,seq:0}));
  assert.throws(()=>validateCampaignInput({...base,inputEpoch:NaN}));
  assert.throws(()=>validateCampaignInput({...base,path:'/tmp/geometry'}));
  assert.doesNotThrow(()=>validateCampaignInput({...base,cancel:true,input:{}}));
});

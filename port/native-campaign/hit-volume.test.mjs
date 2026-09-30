import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from './core.generated.mjs';
import {applyEnemyFields} from '../../game/enemy-types.mjs';
import {ROBOTS,robotHitVolume} from './enemies.mjs';

function fixture(model) {
  // Exercise real source rays/projectile stepping away from world surfaces.
  // This is a collision-unit fixture, not a campaign-navigation test.
  const match=new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,skipNav:true});
  const enemy=match.actor(1,'chatgpt','openclaw');
  enemy.isNpc=true;applyEnemyFields(enemy,ROBOTS[model].npcType);
  match.actors.push(enemy);match.spawn(enemy);enemy.bot=null;
  Object.assign(enemy,{x:0,y:20,z:0,vx:0,vy:0,vz:0,protection:0,hitScale:ROBOTS[model].hitScale,npcHitVolume:robotHitVolume(model)});
  Object.assign(match.actors[0],{x:8,y:20,z:8,vx:0,vy:0,vz:0,protection:100});
  return {match,enemy};
}
function ray(match,enemy,y) {
  const before=enemy.health+enemy.armor;
  match.pierceAlong({x:enemy.x,y:enemy.y+y,z:enemy.z-2},{x:0,y:0,z:1},4,{id:-1},
    {pierce:1,damage:20},1,match.actors[0]);
  return before-(enemy.health+enemy.armor);
}
test('every robot central visible body hits, above-body empty space misses',()=>{
  for(const [model,robot] of Object.entries(ROBOTS)) {
    const {match,enemy}=fixture(model),volume=enemy.npcHitVolume;
    assert.ok(ray(match,enemy,robot.chassisY)>0,`${model}: chassis hit`);
    assert.equal(ray(match,enemy,volume.top+.15),0,`${model}: above-body miss`);
    assert.equal(ray(match,enemy,volume.bottom-.05),0,`${model}: below-chassis miss`);
  }
});
test('source projectile sweep hits chassis and passes through overhead empty space',()=>{
  for(const [model,robot] of Object.entries(ROBOTS))for(const above of [false,true]) {
    const {match,enemy}=fixture(model),volume=enemy.npcHitVolume,before=enemy.health+enemy.armor;
    const projectile={id:1,owner:0,weapon:1,pos:{x:enemy.x,
      y:enemy.y+(above?volume.top+.15:robot.chassisY),z:enemy.z-volume.depth/2-.05},
      dir:{x:0,y:0,z:1},life:2,damageMultiplier:1,bounces:0};
    match.rockets.push(projectile);
    match.step(1/60,{inputs:{0:{},1:{}}});
    if(above){assert.equal(match.rockets.length,1,`${model}: overhead projectile survives`);assert.equal(enemy.health+enemy.armor,before);}
    else {assert.equal(match.rockets.length,0,`${model}: body projectile impacts`);assert.ok(enemy.health+enemy.armor<before);}
  }
});
test('humans and actors without valid explicit volumes retain exact scalar fallback',()=>{
  const {match,enemy}=fixture('scrapper');
  enemy.isNpc=false;
  assert.ok(ray(match,enemy,.9)>0,'a human ignores the NPC volume');
  enemy.isNpc=true;enemy.npcHitVolume={width:Infinity,depth:1,bottom:0,top:1};
  assert.ok(ray(match,enemy,.9)>0,'invalid volume cannot create an unbounded hitbox');
});

test('campaign kicks contact every robot body and shove through the shared authority',()=>{
  for(const model of Object.keys(ROBOTS)){
    const {match,enemy}=fixture(model),volume=enemy.npcHitVolume,actor=match.actors[0];
    match.arena={blocks:[],bounds:{minX:-20,maxX:20,minZ:-20,maxZ:20}};
    Object.assign(actor,{x:0,y:0,z:2,yaw:0,pitch:0,melee:0});
    Object.assign(enemy,{x:0,y:0,z:0,health:1000,armor:0,grounded:true});
    assert.equal(match.melee(actor),true,model);
    const event=match.events.filter(e=>e.type==='melee').at(-1);
    assert.equal(event.hit,enemy.id,model);assert.equal(event.outcome,'hit',model);
    assert.ok(event.impact.y>=volume.bottom&&event.impact.y<=volume.top,`${model}: body contact`);
    assert.ok(Math.abs(event.impact.z)<=volume.depth/2+1e-6,`${model}: contact before shove`);
    assert.ok(enemy.z<0,`${model}: authoritative shove`);
  }
});

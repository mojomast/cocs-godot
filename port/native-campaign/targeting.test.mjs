import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match} from './core.generated.mjs';
import {Match as SourceMatch} from '../../game/core.mjs';
import {WEAPONS} from '../../game/data.mjs';
import {robotHitVolume} from './enemies.mjs';
import {createCampaignMatch} from './match.mjs';
import {playerWeapon,projectileWeapon,trackingInput} from './targeting.mjs';
import {ROBOT_SILHOUETTE,applyRobotHitVolume} from '../native-horde/robot-roles.mjs';

function fixture() {
  const m=new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,skipNav:true,noRecoil:true});
  m.arena={blocks:[],bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100}};
  const e=m.actor(1,'chatgpt','openclaw');m.actors.push(e);m.spawn(e);e.bot=null;
  m.projectileWeapon=r=>projectileWeapon(m,r);
  m.weaponForIndex=(a,i)=>playerWeapon(a,Match.prototype.weaponForIndex.call(m,a,i),i);
  return {m,e,p:m.actors[0]};
}
function setup(m,e,p,row,side,weapon=0) {
  const [x,y,z]=row.point;
  Object.assign(e,{x:0,y:row.feet,z:0,bodyYaw:row.yaw,health:1000,maxHealth:1000,armor:0,protection:0,isNpc:true,npcHitVolume:robotHitVolume(row.model),vx:0,vy:0,vz:0});
  const dx=Math.sin(side)*15,dz=Math.cos(side)*15;
  Object.assign(p,{x:x+dx,y:y-1.45,z:z+dz,eyeHeight:1.45,health:1000,protection:0,weapon,shotWait:0,weaponSwitch:0,punchYaw:0,punchPitch:0,punchVelYaw:0,punchVelPitch:0,spread:0,vx:0,vy:0,vz:0,reloading:false,yaw:Math.atan2(dx,dz),pitch:0});
  p.ammo[weapon]=100;m.over=false;m.rockets=[];
}
test('native Blender solid body samples register actual primary fire from four sides at terrain height',()=>{
  const rows=JSON.parse(readFileSync(new URL('../../godot/tests/campaign/targeting-points.json',import.meta.url)));
  const {m,e,p}=fixture();let fired=0;
  for(const row of rows)for(const side of [0,Math.PI/2,Math.PI,Math.PI*1.5]) {
    setup(m,e,p,row,side);
    assert.equal(m.fire(p),true);
    assert.ok(e.health<1000,JSON.stringify({row,side}));fired++;
  }
  console.log(`native triangle-centre fire→damage checks: ${fired}`);
});
test('player speed hook changes actual swept travel, keeps NPC/source identity and no tunnelling',()=>{
  const m=createCampaignMatch({random:()=>.5}),p=m.actors[0];
  for(const i of [1,4,5])assert.ok(m.weaponForIndex(p,i).speed>WEAPONS[i].speed);
  const before=JSON.stringify(WEAPONS),{m:match,e,p:player}=fixture();
  for(const weapon of [1,4,5]) {
    const row={model:'sentinel',feet:20,yaw:0,point:[0,20.8,0]};
    setup(match,e,player,row,0,weapon);e.x=70;
    assert.equal(match.fire(player),true);
    const start={...match.rockets[0].pos};
    match.step(1/60,{inputs:{0:{},1:{}}});
    const r=match.rockets[0],travel=Math.hypot(r.pos.x-start.x,r.pos.y-start.y,r.pos.z-start.z);
    assert.ok(Math.abs(travel-match.weaponForIndex(player,weapon).speed/60)<.002);
    console.log(`weapon ${weapon}: actual one-tick travel ${travel.toFixed(4)}m`);
    assert.equal(projectileWeapon(match,{owner:1,weapon}).speed,WEAPONS[weapon].speed);
  }
  setup(match,e,player,{model:'skirmisher',feet:20,yaw:Math.PI/2,point:[0,21,0]},0,4);
  assert.equal(match.fire(player),true);
  for(let i=0;i<9&&match.rockets.length;i++)match.step(1/60,{inputs:{0:{},1:{}}});
  assert.ok(e.health<1000,'138m/s plasma sweeps through a narrow target');
  assert.equal(JSON.stringify(WEAPONS),before);
  const source=new SourceMatch('chatgpt','openclaw',()=>.5,'exchange',{botCount:0,skipNav:true});
  assert.equal(source.weaponForIndex(source.actors[0],4).speed,46);
});
test('cover blocks source fire and fast projectiles before body collision',()=>{
  for(const weapon of [0,4]) {
    const {m,e,p}=fixture();setup(m,e,p,{model:'sentinel',feet:0,yaw:0,point:[0,.8,0]},0,weapon);
    m.arena={blocks:[{x:0,z:5,w:8,d:1,h:8}],bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100}};
    assert.equal(m.fire(p),true);
    for(let i=0;i<15;i++)m.step(1/60,{inputs:{0:{},1:{}}});
    assert.equal(e.health,1000);
  }
});
test('committed movement suppresses rapid reversals and provides planted windows',()=>{
  const actor={isNpc:true,npcModel:'skirmisher',gearSpeed:1,speedMultiplier:1,bot:{state:'engage'}};
  let previous=0,reversals=0,planted=0;
  for(let i=0;i<600;i++) {
    const input=trackingInput({time:i/60},actor,{x:i%2?1:-1,z:0,sprint:true},'normal');
    if(input.x&&previous&&input.x!==previous)reversals++;
    if(input.x)previous=input.x;else planted++;
    assert.equal(input.sprint,false);
  }
  assert.ok(reversals<=6);assert.ok(planted>=150);
  console.log({committedReversalsPer10s:reversals,plantedSeconds:planted/60});
});
test('Horde canonical scalar volumes already contain the six imported body silhouettes',()=>{
  const rows=JSON.parse(readFileSync(new URL('../../godot/tests/campaign/targeting-points.json',import.meta.url)));
  const roles={scrapper:['husk',.72],skirmisher:['lancer',.86],sentinel:['sentinel',1.28],mortar:['mortar',1.15],bulwark:['bulwark',1.5],warden:['warden',1.6]};
  const m=new SourceMatch('chatgpt','openclaw',()=>.5,'exchange',{botCount:0,skipNav:true,noRecoil:true});
  m.arena={blocks:[],bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100}};
  const e=m.actor(1,'chatgpt','openclaw');m.actors.push(e);m.spawn(e);e.bot=null;
  for(const row of rows.filter((_,i)=>i%7===0))for(const side of [0,Math.PI/2,Math.PI,Math.PI*1.5]) {
    const [role,scale]=roles[row.model],ratio=ROBOT_SILHOUETTE[role].scale/scale;
    setup(m,e,m.actors[0],{...row,point:[row.point[0]*ratio,row.feet+(row.point[1]-row.feet)*ratio,row.point[2]*ratio]},side);
    e.npcType=role;applyRobotHitVolume(e);m.fire(m.actors[0]);assert.ok(e.health<1000,`${row.model} Horde body`);
  }
});
test('campaign ally filter uses team identity for primary hitscan and swept projectiles',()=>{
  for(const weapon of [0,4])for(const npc of [true,false]) {
    const {m,e,p}=fixture();setup(m,e,p,{model:'sentinel',feet:20,yaw:0,point:[0,20.8,0]},0,weapon);
    m.config.mode='campaign';m.updateSinglePlayer=()=>{};p.team=0;e.team=0;e.isNpc=npc;
    m.fire(p);for(let i=0;i<12;i++)m.step(1/60,{inputs:{0:{},1:{}}});
    assert.equal(e.health,1000,`ally npc=${npc} weapon=${weapon}`);
  }
});
test('raised shield surface catches shots outside the torso; lowered guard no longer blocks empty space',()=>{
  const {m,e,p}=fixture(),row={model:'bulwark',feet:20,yaw:0,point:[-1,21.5,-.7]};
  for(const raised of [true,false]) {
    setup(m,e,p,row,Math.PI);e.npcShield=raised?{arc:.6,reduction:.45}:null;e.yaw=0;
    m.fire(p);assert.equal(e.health<1000,raised);
  }
});
test('campaign guard reduction publishes a distinct confirmed shield contact',()=>{
  const m=createCampaignMatch({random:()=>.5}),p=m.actors[0],e=m.actor(1,'chatgpt','openclaw');
  m.actors.push(e);Object.assign(e,{isNpc:true,npcModel:'bulwark',health:100,maxHealth:100,armor:0,protection:0,x:0,y:0,z:0,yaw:0,npcShield:{arc:.6,reduction:.45},campaignGuard:0,campaignStagger:0});
  Object.assign(p,{x:0,z:-10});m.damage(e,20,p);
  const event=m.events.filter(e=>e.type==='damage').at(-1);
  assert.equal(event.shieldBlocked,true);assert.ok(event.amount<20);
  assert.ok(m.snapshot().actors.find(a=>a.id===1).campaignShieldHit>0);
});

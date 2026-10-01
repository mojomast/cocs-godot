// Deterministic authority benchmark: real source bot input and movement on a
// flat firing range. Outputs measurements, not a claim about human enjoyment.
import {Match} from './core.generated.mjs';
import {applyEnemyFields,enemyById} from '../../game/enemy-types.mjs';
import {ROBOTS,robotHitVolume} from './enemies.mjs';
import {tuneRobot} from './feel.mjs';
import {trackingInput,playerWeapon,projectileWeapon} from './targeting.mjs';
import {WEAPONS} from '../../game/data.mjs';

function range(model) {
  let seed=134;const random=()=>((seed=(1664525*seed+1013904223)>>>0)/2**32);
  const m=new Match('chatgpt','openclaw',random,'exchange',{mode:'deathmatch',botCount:0,skipNav:true,noRecoil:true});
  m.arena={blocks:[],bounds:{minX:-150,maxX:150,minZ:-150,maxZ:150}};
  const type=enemyById(ROBOTS[model].npcType);
  const e=m.actor(1,type.character??'chatgpt',type.harness??'openclaw');e.isNpc=true;m.actors.push(e);applyEnemyFields(e,type);m.spawn(e);
  e.isNpc=true;e.npcModel=model;e.npcHitVolume=robotHitVolume(model);tuneRobot(e,0);
  const p=m.actors[0];Object.assign(p,{x:0,y:0,z:0,protection:999,health:10000});
  Object.assign(e,{x:0,y:0,z:-15,yaw:Math.PI,bodyYaw:Math.PI,protection:0});
  m.damage=()=>0;m.updateSinglePlayer=()=>{};
  // Match the campaign's existing NPC power/alt/grenade restrictions.
  m.power=()=>false;m.altFire=()=>false;m.throwGrenade=()=>false;
  return {m,e,p};
}
const movement=[];
for(const model of Object.keys(ROBOTS))for(const tuned of [false,true])for(const distance of [15,30,50]) {
  const {m,e}=range(model);e.z=-distance;
  if(tuned)m.botInput=(a,dt)=>trackingInput(m,a,Match.prototype.botInput.call(m,a,dt),'normal');
  let path=0,peak=0,turns=0,last=null,planted=0;
  for(let i=0;i<600;i++) {
    const x=e.x,z=e.z;m.step(1/60,{inputs:{0:{}}});
    const dx=e.x-x,dz=e.z-z,speed=Math.hypot(dx,dz)*60;
    path+=Math.hypot(dx,dz);peak=Math.max(peak,speed);if(speed<.2)planted++;
    if(speed>1){const direction={x:dx*60/speed,z:dz*60/speed};if(last&&last.x*direction.x+last.z*direction.z<0)turns++;last=direction;}
  }
  movement.push({model,tuned,distance,path:+path.toFixed(2),peak:+peak.toFixed(2),turns,plantedSeconds:planted/60});
}
const travel=WEAPONS.map((w,index)=>({index,name:w.name,before:w.speed??'hitscan',after:playerWeapon({id:0},w,index).speed??'hitscan',secondsBefore:w.speed?[15,30,50].map(d=>+(d/w.speed).toFixed(3)):[],secondsAfter:w.speed?[15,30,50].map(d=>+(d/playerWeapon({id:0},w,index).speed).toFixed(3)):[]}));

// A reproducible tracking task: aim at the rendered torso every 0.4 sec,
// constant lateral target speed, no prediction or spread, real swept impact.
const tracking=[];
for(const tuned of [false,true])for(const weapon of [0,4])for(const distance of [15,30,50]) {
  let hits=0;
  for(let shot=0;shot<20;shot++) {
    const {m,e,p}=range('skirmisher');m.random=()=>.5;m.damage=Match.prototype.damage;
    e.bot=null;e.health=e.maxHealth=1000;e.armor=0;e.protection=0;e.bodyYaw=0;
    const speed=tuned?3.5:e.moveSpeed*e.gearSpeed,delay=tuned?0:.1;
    const x=(shot%5-2)*.1;
    Object.assign(e,{x,y:20,z:-distance,vx:0,vy:0,vz:0});
    if(!tuned)e.npcHitVolume={width:.3268,depth:.4472,bottom:.7267,top:1.372};
    const aimX=x-speed*delay;
    Object.assign(p,{x:0,y:19.55,z:0,weapon,shotWait:0,weaponSwitch:0,punchYaw:0,punchPitch:0,punchVelYaw:0,punchVelPitch:0,spread:0,yaw:Math.atan2(-aimX,distance),pitch:0});p.ammo[weapon]=100;
    if(tuned){m.projectileWeapon=r=>projectileWeapon(m,r);m.weaponForIndex=(a,i)=>playerWeapon(a,Match.prototype.weaponForIndex.call(m,a,i),i);}
    m.fire(p);
    for(let tick=0;tick<120&&m.rockets.length;tick++) {
      e.x+=speed/60;e.y=20;e.vy=0;p.y=19.55;p.vy=0;
      m.step(1/60,{inputs:{0:{},1:{}}});
    }
    if(e.health<1000)hits++;
  }
  tracking.push({tuned,weapon,distance,hits,shots:20});
}
console.log(JSON.stringify({movement,travel,tracking},null,2));

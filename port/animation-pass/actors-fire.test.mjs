import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match} from '../native-campaign/core.generated.mjs';
import {robotHitVolume} from '../native-campaign/enemies.mjs';

test('animated imported damage surfaces register actual source fire from four sides',()=>{
  const path=process.env.ACTOR_ANIMATION_POINTS;
  assert.ok(path,'Set ACTOR_ANIMATION_POINTS to geometry.gd output (no generated fixture writes by default)');
  const rows=JSON.parse(readFileSync(path));
  assert.ok(rows.length>10000,'Broad six-role pose sampling required');
  const m=new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,skipNav:true,noRecoil:true});
  m.arena={blocks:[],bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100}};
  const e=m.actor(1,'chatgpt','openclaw');m.actors.push(e);m.spawn(e);e.bot=null;
  const p=m.actors[0];let fired=0;
  for(const row of rows)for(const side of [0,Math.PI/2,Math.PI,Math.PI*1.5]){
    const [x,y,z]=row.point,dx=Math.sin(side)*15,dz=Math.cos(side)*15;
    Object.assign(e,{x:0,y:row.feet,z:0,bodyYaw:row.yaw,health:1000,maxHealth:1000,armor:0,protection:0,isNpc:true,npcHitVolume:robotHitVolume(row.model),vx:0,vy:0,vz:0});
    Object.assign(p,{x:x+dx,y:y-1.45,z:z+dz,eyeHeight:1.45,health:1000,protection:0,weapon:0,shotWait:0,weaponSwitch:0,punchYaw:0,punchPitch:0,punchVelYaw:0,punchVelPitch:0,spread:0,vx:0,vy:0,vz:0,reloading:false,yaw:Math.atan2(dx,dz),pitch:0});
    p.ammo[0]=100;m.over=false;m.rockets=[];
    assert.equal(m.fire(p),true);assert.ok(e.health<1000,JSON.stringify({row,side}));fired++;
  }
  console.log(`animated native triangle-centre fire→damage checks: ${fired}`);
});

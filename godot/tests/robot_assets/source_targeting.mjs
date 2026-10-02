// Read actual native triangle samples; exercise source authority without edits.
import {readFileSync,writeFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import {Match} from '../../../game/core.mjs';
import {ROBOT_SILHOUETTE,applyRobotHitVolume} from '../../../port/native-horde/robot-roles.mjs';
const path=join(process.env.ROBOT_CONTACTS,'targeting-points.json');
const out=process.env.ASSET_STAGE_EVIDENCE;
const rows=JSON.parse(readFileSync(path));
const control=spawnSync('node',['--test','port/native-campaign/targeting.test.mjs'],{encoding:'utf8',timeout:60000,env:{...process.env,CAMPAIGN_TARGETING_POINTS:path}});
writeFileSync(join(out,'campaign-targeting.log'),control.stdout+control.stderr);
assert.equal(control.status,0,control.stdout+control.stderr);
const m=new Match('chatgpt','openclaw',()=>.5,'exchange',{botCount:0,skipNav:true,noRecoil:true});
m.arena={blocks:[],bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100}};
const enemy=m.actor(1,'chatgpt','openclaw');m.actors.push(enemy);m.spawn(enemy);enemy.bot=null;
const player=m.actors[0], counts={};
const roles={skirmisher:['lancer','spitter'],bulwark:['brute','bulwark'],mortar:['mortar']};
const scales={skirmisher:.86,bulwark:1.5,mortar:1.15};
for(const row of rows)for(const role of roles[row.model])for(const side of [0,Math.PI/2,Math.PI,3*Math.PI/2]){
  const ratio=ROBOT_SILHOUETTE[role].scale/scales[row.model];
  const [x,y,z]=[row.point[0]*ratio,row.feet+(row.point[1]-row.feet)*ratio,row.point[2]*ratio];
  Object.assign(enemy,{x:0,y:row.feet,z:0,bodyYaw:row.yaw,health:1000,maxHealth:1000,armor:0,protection:0,isNpc:true,npcType:role,vx:0,vy:0,vz:0});
  applyRobotHitVolume(enemy);
  const dx=Math.sin(side)*15,dz=Math.cos(side)*15;
  Object.assign(player,{x:x+dx,y:y-1.45,z:z+dz,eyeHeight:1.45,health:1000,protection:0,weapon:0,shotWait:0,weaponSwitch:0,punchYaw:0,punchPitch:0,punchVelYaw:0,punchVelPitch:0,spread:0,vx:0,vy:0,vz:0,reloading:false,yaw:Math.atan2(dx,dz),pitch:0});
  player.ammo[0]=100;m.over=false;m.rockets=[];
  assert.equal(m.fire(player),true);assert.ok(enemy.health<1000,JSON.stringify({role,row,side}));
  const key=row.skin+'/'+role;counts[key]=(counts[key]??0)+1;
}
const report={sourcePoints:path,campaignFourSideChecks:rows.length*4,hordeFourSideChecks:Object.values(counts).reduce((a,b)=>a+b,0),counts,failures:[]};
writeFileSync(join(out,'targeting.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report));

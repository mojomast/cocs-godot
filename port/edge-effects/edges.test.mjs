import test from 'node:test';
import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';
import {Match,rayWorld} from '../../game/core.mjs';
import {Match as CampaignCore} from '../native-campaign/core.generated.mjs';
import {playerWeapon,projectileWeapon} from '../native-campaign/targeting.mjs';
import {createStructureRay,facadeTriangles,readImportedTriangles,structurePlacements} from './structure-rays.mjs';
import {loadCampaignMap,CAMPAIGN_MAP_IDS} from '../native-campaign/maps.mjs';

export const data={campaign:{index:0},arena:{blocks:[{id:'service cabin',material:'stone',x:0,z:0,w:4,d:4,h:4,baseY:0}],
  bounds:{minX:-20,maxX:20,minZ:-20,maxZ:20},terrain:{maxSlope:1.5,surfaces:[{id:'floor',material:'ground',walkable:true,
    vertices:[[-20,0,-20],[-20,0,20],[20,0,20],[20,0,-20]],triangles:[[0,1,2],[0,2,3]]}],walls:[]}}};
const ray=createStructureRay(data),records=[];
test('committed glTF bytes are the actual campaign cover prototypes',()=>{
  const keys=new Set();
  for(const id of CAMPAIGN_MAP_IDS)for(const p of structurePlacements(loadCampaignMap(id)))keys.add(p.key);
  for(const key of keys)assert.deepEqual(facadeTriangles(key),readImportedTriangles(key),key);
  console.log(`facade provenance: ${keys.size} used prototypes`);
});
test('confirmed empty-AABB side and pitched-roof false blocks are removed; solid walls stay solid',()=>{
  for(const sign of [-1,1])for(const [x,y,clear] of [[1.96,2,true],[1.6,3.85,true],[0,2,false],[1.639,2,false],[1.641,2,true],[0,4.001,true]]) {
    const o={x:x*sign,y,z:8},d={x:0,y:0,z:-1};
    const before=rayWorld(o,d,16,data.arena),after=ray(o,d,16);
    assert.equal(after===16,clear,JSON.stringify({o,before,after}));
    if(clear&&y<4)assert.equal(before,6,'baseline stops in empty containing box');
    records.push({kind:'ray',o,d,max:16,before,after});
  }
  for(const dx of [-1e-9,0,1e-9])assert.ok(ray({x:0,y:2,z:8},{x:dx,y:0,z:-1},16)<8);
  for(const sign of [-1,1]) {
    const o={x:8*sign,y:2,z:0},d={x:-sign,y:0,z:0};
    assert.ok(Math.abs(ray(o,d,16)-6.36)<.001,'other wall face');
  }
  assert.ok(ray({x:0,y:6,z:0},{x:0,y:-1,z:0},8)<2.2,'roof from above');
  assert.ok(ray({x:0,y:3.5,z:0},{x:0,y:1,z:0},2)<.5,'roof from below');
});
function fire(x,y,weapon,repaired,Type=CampaignCore,z=8) {
  const m=new Type('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,skipNav:true,noRecoil:true});
  m.projectileWeapon=r=>projectileWeapon(m,r);
  m.weaponForIndex=(a,i)=>playerWeapon(a,Type.prototype.weaponForIndex.call(m,a,i),i);
  // Real source support keeps the standard-size target stationary while the
  // projectile travels; the drill must not enlarge actor hit regions to pass.
  m.arena={...data.arena,blocks:[...data.arena.blocks,...[-8,z].map((at,i)=>({id:`stand-${i}`,x,z:at,w:2,d:2,h:y-1.45,baseY:0,material:'rock'}))]};
  if(repaired)m.rayWorld=createStructureRay({...data,arena:m.arena});
  const p=m.actors[0],e=m.actor(1,'chatgpt','openclaw');m.actors.push(e);m.spawn(e);e.bot=null;
  Object.assign(e,{x,y:y-1.45,z:-8,health:1000,maxHealth:1000,armor:0,protection:0,grounded:true});
  Object.assign(p,{x,y:y-1.45,z,eyeHeight:1.45,weapon,shotWait:0,weaponSwitch:0,punchYaw:0,punchPitch:0,spread:0,vx:0,vy:0,vz:0,reloading:false,yaw:0,pitch:0});
  p.ammo[weapon]=100;m.events=[];
  assert.equal(m.fire(p),true);
  if(weapon===4)for(let i=0;i<30&&m.rockets.length;i++)m.step(1/60,{inputs:{0:{},1:{}}});
  return {damage:1000-e.health,events:m.events};
}
test('actual source fire/damage crosses visible edge air, never a solid wall; swept plasma keeps first cover',()=>{
  for(const weapon of [0,4])for(const [x,y,clear] of [[1.96,2,true],[0,2,false],[1.6,3.85,true],[0,3,false]]) {
    const before=fire(x,y,weapon,false),after=fire(x,y,weapon,true);
    assert.equal(before.damage,0,'baseline false block or real cover');
    assert.equal(after.damage>0,clear,JSON.stringify({weapon,x,y,after}));
    records.push({kind:'fire',weapon,x,y,before,after});
  }
  if(process.env.EDGE_SOURCE_EVENTS)writeFileSync(process.env.EDGE_SOURCE_EVENTS,JSON.stringify({data,records},null,2));
});
test('camera target behind muzzle cover is correctly published as surface contact, not actor damage',()=>{
  const before=fire(-1.7,2,0,true,Match,2.3),after=fire(-1.7,2,0,true,CampaignCore,2.3);
  assert.equal(before.damage,0);assert.equal(after.damage,0);
  assert.equal(before.events.find(e=>e.type==='shot').hit,1,'source candidate is not actual damage');
  assert.equal(after.events.find(e=>e.type==='shot').hit,false,'campaign event no longer suppresses wall impact');
  records.push({kind:'muzzle-cover',before,after});
  if(process.env.EDGE_SOURCE_EVENTS)writeFileSync(process.env.EDGE_SOURCE_EVENTS,JSON.stringify({data,records},null,2));
});

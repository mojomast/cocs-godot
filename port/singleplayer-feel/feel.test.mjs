import test from 'node:test';
import assert from 'node:assert/strict';
import {createCampaignMatch} from '../native-campaign/match.mjs';
import {loadCampaignMap} from '../native-campaign/maps.mjs';
import {deployEncounter} from '../native-campaign/enemies.mjs';
import {createFeel} from '../native-campaign/feel.mjs';
import {measureBalance} from './measure.mjs';
const data=loadCampaignMap('rootfall-verge');
function setup(roster={bulwark:1},difficulty='normal') {
  const m=createCampaignMatch({mapData:data,difficulty,random:()=>.5});
  deployEncounter(m,m.modeState,{roster},data.campaign.anchors['encounter-1']);
  for(const a of m.actors)a.protection=0;
  return m;
}
test('ideal connected-hit matrix reduces grinding while preserving precision and automatic roles',()=>{
  const {rows}=measureBalance();
  const row=(variant,model,weapon,facing='front')=>rows.find(r=>r.variant===variant&&r.model===model&&r.weapon===weapon&&r.facing===facing);
  assert.equal(row('after','scrapper',2).shots,1,'precision finally one-shots light chassis');
  assert.equal(row('after','scrapper',0).shots,3,'rifle retains a short burst');
  for(const model of ['sentinel','bulwark','mortar'])assert.ok(row('after',model,0).shots<row('before',model,0).shots*.7,model);
  assert.ok(row('after','bulwark',0,'rear').shots<row('after','bulwark',0).shots,'flank still rewards aim/position');
  assert.ok(row('after','warden',0).shots>row('after','bulwark',0).shots,'boss distinct');
});
test('normal absorbs simultaneous crossfire but sustained fire still kills; tiers order survival',()=>{
  const results=[];
  for(const difficulty of ['easy','normal','hard']) {
    const m=setup({sentinel:3},difficulty),p=m.actors[0];
    for(const a of m.actors.slice(1))a.damageMultiplier=1;
    const before=p.health+p.armor;
    for(let n=0;n<15;n++)m.damage(p,20,m.actors[1+n%3]);
    assert.ok(before-p.health-p.armor<=({easy:26,normal:34,hard:46})[difficulty]+1e-6);
    let elapsed=0;
    while(p.health>0&&elapsed<20){m.time+=.31;elapsed+=.31;for(const a of m.actors.slice(1))m.damage(p,20,a);}
    assert.ok(p.health<=0,'no permanent immunity');results.push(elapsed);
  }
  assert.ok(results[0]>results[1]&&results[1]>results[2],JSON.stringify(results));
});
test('guard break uses source damage, exposes briefly, and restores; stagger cannot stunlock',()=>{
  const m=setup(),p=m.actors[0],a=m.actors[1];
  Object.assign(a,{x:0,z:0,yaw:0});Object.assign(p,{x:0,z:-10});
  for(let i=0;i<6;i++)m.damage(a,11,p);
  assert.equal(a.npcShield,null);assert.ok(a.health>0);
  assert.ok(m.events.some(e=>e.type==='campaign-guard-break'));
  assert.ok(m.events.filter(e=>e.type==='campaign-stagger').length<=1);
  const shield=a.campaignSavedShield;m.time=3;
  const feel=createFeel('normal');feel.update(m,.016);
  assert.deepEqual(a.npcShield,shield);
});
test('attack lane budget, acquisition warning, distance limit and rest are enforced',()=>{
  const m=setup({sentinel:4}),f=createFeel('normal'),p=m.actors[0];m.time=2;
  for(const a of m.actors.slice(1)){a.x=p.x+10;a.z=p.z;assert.equal(f.attack(m,a),false);}
  assert.equal(m.events.filter(e=>e.type==='enemy-telegraph'&&e.kind==='attack').length,3);
  m.time=2.6;assert.equal(f.attack(m,m.actors[1]),true);assert.equal(f.attack(m,m.actors[4]),false);
  m.time=3.3;assert.equal(f.attack(m,m.actors[1]),false,'expired shooter rests');
  m.actors[4].x=p.x+100;assert.equal(f.attack(m,m.actors[4]),false,'no long-range surprise');
});
test('recovery permits return fire and near kills grant bounded salvage once',()=>{
  const m=setup({scrapper:1}),p=m.actors[0],a=m.actors[1],f=createFeel('normal');
  p.health=60;p.armor=0;p.shotWait=1;f.damaged(m,p,a,10,10);m.time=2;f.update(m,1);assert.equal(p.health,60);
  m.time=4;f.update(m,1);assert.equal(p.health,76);
  a.x=p.x+3;a.z=p.z;m.damage(a,100,p);assert.equal(p.health,84);assert.equal(p.armor,6);
  m.damage(a,100,p);assert.equal(p.health,84,'dead target cannot farm recovery');
});
test('console rush disables guard network but cannot bypass living enemies',()=>{
  const m=createCampaignMatch({mapData:data,checkpoint:4,random:()=>.5}),p=m.actors[0],anchor=data.campaign.anchors['encounter-5'];
  Object.assign(p,{...anchor,protection:100,lastValid:{...anchor}});
  m.step(1/60,{inputs:{0:{}}});
  m.step(1/60,{inputs:{0:{interact:true}}});
  assert.equal(m.modeState.bypassed,true);assert.equal(m.modeState.stepIndex,4);
  assert.ok(m.actors.slice(1).every(a=>a.npcPhalanx===null&&a.npcShield===null));
});
test('restoration overlaps combat and Warden slam has a readable punish window',()=>{
  const m=createCampaignMatch({mapData:data,checkpoint:2,random:()=>.5}),p=m.actors[0],anchor=data.campaign.anchors['encounter-3'];
  Object.assign(p,{...anchor,protection:100,lastValid:{...anchor}});m.step(1/60,{inputs:{0:{interact:true}}});
  assert.ok(m.modeState.holdProgress>0);assert.ok(m.actors.some(a=>a.isNpc&&a.health>0));
  const boss=setup({warden:1}),a=boss.actors[1];boss.emit('enemy-telegraph',{kind:'boss',actor:a.id,duration:.8});
  assert.equal(a.bossStompWindup,1.15);boss.emit('boss-slam',{actor:a.id});
  assert.equal(a.campaignExposedUntil,1.6);a.armor=0;
  const health=a.health;boss.damage(a,20,boss.actors[0]);assert.equal(health-a.health,27);
});

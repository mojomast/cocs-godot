import test from 'node:test';
import assert from 'node:assert/strict';
import {CAMPAIGN_MAP_IDS,loadCampaignMap} from './maps.mjs';
import {createCampaignMatch} from './match.mjs';
import {createCampaignInterludes} from './interludes.mjs';
import {interludeDefinitions} from './interlude-definitions.mjs';
import {floorAt,obstructed} from './core.generated.mjs';

const tick=(match,input={})=>match.step(1/60,{inputs:{0:input}});
const dist=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const nearest=(path,p)=>path.reduce((best,q,i)=>dist(q,p)<dist(path[best],p)?i:best,0);
function walk(match,points){
  let ticks=0;
  for(const p of points){
    let count=0;
    while(dist(match.actors[0],p)>.35&&count++<200){
      const a=match.actors[0],d=dist(a,p);
      tick(match,{x:(p.x-a.x)/d,z:(p.z-a.z)/d});ticks++;
      assert.equal(match.over,false,'ordinary source movement stays alive');
    }
    assert.ok(count<200,`blocked at ${JSON.stringify(p)} from ${JSON.stringify({x:match.actors[0].x,y:match.actors[0].y,z:match.actors[0].z})}`);
    assert.ok(Math.abs(match.actors[0].y-floorAt(match.actors[0].x,match.actors[0].z,match.arena))<.35);
  }
  return ticks/60;
}
const beatState=(match,id)=>match.snapshot().campaign.interludes.beats.find(b=>b.id===id);

for(const mapId of CAMPAIGN_MAP_IDS)test(`${mapId}: walk from checkpoint, play both authored workshops, rejoin next fight`,()=>{
  const data=loadCampaignMap(mapId),path=data.campaign.criticalPath;
  for(const def of interludeDefinitions(data)){
    const previous=data.campaign.anchors[`encounter-${def.step}`];
    const match=createCampaignMatch({mapId,mapData:data,checkpoint:def.step,checkpointPoint:previous,random:()=>.5});
    const route=s=>data.routes.find(r=>r.id===`interlude-${def.id}-${s}`).points;
    const seconds=walk(match,path.slice(nearest(path,previous)+1,nearest(path,def.entry)+1));
    const sideSeconds=walk(match,route('a'));
    assert.equal(match.modeState.deployed,false,'optional activity is outside the next encounter trigger');
    tick(match);const p=match.actors[0];p.armor=60;p.ammo[3]=1;
    if(def.family==='align'){
      tick(match,{yaw:Math.atan2(-(def.b.x-p.x),-(def.b.z-p.z))+Math.PI,interact:true});
      assert.equal(beatState(match,def.id).completed,false,'looking away does not lock the receiver');
      tick(match);tick(match,{yaw:Math.atan2(-(def.b.x-p.x),-(def.b.z-p.z)),interact:true});
    }else tick(match,{interact:true});
    if(def.family==='link'){
      assert.equal(beatState(match,def.id).stage,1);
      // A continuously held key cannot connect the far terminal.
      const controller=createCampaignInterludes(data,match.campaignCheckpoint().interludeCarry);
      const before=controller.continuity();
      controller.update({...match,actors:[{...p,...def.b}],arena:match.arena,emit:()=>{}},match.modeState,{interact:true});
      assert.deepEqual(controller.continuity(),before);
      walk(match,route('link'));
      tick(match);tick(match,{interact:true});
    }
    assert.equal(beatState(match,def.id).completed,true,def.id);
    assert.equal(match.modeState.stepIndex,def.step,'optional completion never advances a mission');
    assert.ok(match.events.some(e=>e.type==='campaign-interlude'&&e.id===def.id&&e.completed));
    if(def.reward==='armor'||def.family==='choice')assert.equal(p.armor,95);
    else assert.equal(p.ammo[3],match.weaponForIndex(p,3).cap);
    const armor=p.armor,ammo=[...p.ammo];
    for(let i=0;i<8;i++){tick(match);tick(match,{interact:true});}
    assert.equal(p.armor,armor);assert.deepEqual(p.ammo,ammo,'no repeat farming');
    const checkpoint=match.campaignCheckpoint(),retry=createCampaignMatch({...checkpoint,mapData:data,random:()=>.5});
    assert.equal(beatState(retry,def.id).completed,true,'death retry retains the claim');
    assert.equal(beatState(retry,def.id).choice,def.family==='choice'?'a':null);
    // Return via the actual short spur, without a teleport or invisible gate.
    if(def.family==='link')walk(match,[...route('b')].reverse());
    else walk(match,[...route('a')].reverse());
    const start=nearest(path,match.actors[0]),next=data.campaign.anchors[`encounter-${def.step+1}`];
    walk(match,path.slice(start+1,nearest(path,next)-12));
    assert.equal(match.modeState.stepIndex,def.step);
    console.log(JSON.stringify({mapId,beat:def.id,approachWalkingSeconds:seconds,entrySpurSeconds:sideSeconds,completed:true,checkpointClaim:true}));
  }
});

test('source eligibility rejects remote, vertical, inside-solid, priority, held and dead interactions',()=>{
  const data=loadCampaignMap('rootfall-verge'),def=interludeDefinitions(data)[0];
  const match=createCampaignMatch({mapData:data,checkpoint:1,checkpointPoint:def.a,random:()=>.5});
  const state={phase:'playing',stepIndex:1,totalElapsed:1,deployed:false};
  for(const [name,position,priority]of [
    ['remote',{...def.a,x:def.a.x+10},false],['vertical',{...def.a,y:def.a.y+2},false],
    ['main mission / Patch',def.a,true],['dead',{...def.a,health:0},false]]){
    const controller=createCampaignInterludes(data),player={...match.actors[0],...position};
    const fake={arena:match.arena,actors:[player],emit:()=>assert.fail('rejected interaction emitted')};
    controller.update(fake,state,{},priority);controller.update(fake,state,{interact:true},priority);
    assert.equal(controller.continuity()[def.id].stage,0,name);
  }
  const solid={...data.arena,blocks:[...data.arena.blocks,{x:def.a.x,z:def.a.z,w:2,d:2,h:def.a.y+3,baseY:0}]};
  assert.equal(obstructed(def.a.x,def.a.y,def.a.z,.45,solid),true);
  const blocked=createCampaignInterludes(data),fake={arena:solid,actors:[{...match.actors[0],...def.a}],emit:()=>assert.fail('solid interaction')};
  blocked.update(fake,state,{});blocked.update(fake,state,{interact:true});assert.equal(blocked.continuity()[def.id].stage,0);
  const held=createCampaignInterludes(data);held.update(match,state,{interact:true});assert.equal(held.continuity()[def.id].stage,0);
});

test('allocation is mutually exclusive, including retries, and B gives ammunition instead of armor',()=>{
  const data=loadCampaignMap('siltwake-crossing'),def=interludeDefinitions(data)[1];
  const match=createCampaignMatch({mapId:data.id,mapData:data,checkpoint:3,checkpointPoint:def.b,random:()=>.5});
  const p=match.actors[0];p.armor=60;p.ammo[3]=0;
  tick(match);tick(match,{interact:true});assert.equal(beatState(match,def.id).choice,'b');assert.equal(p.armor,60);
  assert.equal(p.ammo[3],match.weaponForIndex(p,3).cap);
  walk(match,[...data.routes.find(r=>r.id===`interlude-${def.id}-link`).points].reverse());
  tick(match);tick(match,{interact:true});assert.equal(beatState(match,def.id).choice,'b');assert.equal(p.armor,60);
  assert.equal(match.events.filter(e=>e.type==='campaign-interlude'&&e.completed).length,1);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {CAMPAIGN_MAP_IDS,loadCampaignMap,campaignSupportAt} from './maps.mjs';
import {createCampaignMatch} from './match.mjs';
import {createCampaignStory,storyPlacement} from './story.mjs';
import {floorAt,obstructed} from './core.generated.mjs';

const tick=(match,input={})=>match.step(1/60,{inputs:{0:input}});
const at=(match,p)=>Object.assign(match.actors[0],{x:p.x,y:p.y,z:p.z,vx:0,vy:0,vz:0,
  protection:100,lastValid:{x:p.x,y:p.y,z:p.z}});

test('all four authored chapters stage operators and Patch on source-supported reachable route points',()=>{
  for(const id of CAMPAIGN_MAP_IDS){
    const data=loadCampaignMap(id),placement=storyPlacement(data),story=createCampaignStory(data);
    for(const p of Object.values(placement)){
      assert.ok(Math.abs(campaignSupportAt(data.arena,p.x,p.z).y-p.y)<.001,id);
      assert.ok(Math.abs(floorAt(p.x,p.z,data.arena)-p.y)<.08,id);
      assert.equal(obstructed(p.x,p.y,p.z,.65,data.arena),false,id);
      assert.ok(data.campaign.criticalPath.some(q=>Math.hypot(q.x-p.x,q.z-p.z)<.01),id);
    }
    const match=createCampaignMatch({mapId:id,random:()=>.5}),initial=match.snapshot().campaign.story;
    assert.equal(initial.version,1);assert.equal(initial.entities.filter(e=>e.kind==='puppy').length,1,id);
    assert.ok(initial.entities.some(e=>e.id==='mara'||e.id==='ivo'),id);
    const pup=initial.entities.find(e=>e.kind==='puppy');
    assert.equal(pup.id,'patch');assert.equal(pup.name,'Patch');
    assert.ok(Math.abs(floorAt(pup.x,pup.z,data.arena)-pup.y)<.08);
    assert.equal(obstructed(pup.x,pup.y,pup.z,.65,data.arena),false);
    assert.ok(data.campaign.criticalPath.some(q=>Math.hypot(q.x-pup.x,q.z-pup.z)<.01));
    at(match,pup);tick(match);assert.equal(match.snapshot().campaign.story.prompt?.action,'pet',id);
    tick(match,{interact:true});const pet=match.snapshot().campaign.story;
    assert.equal(pet.pets,1,id);assert.equal(pet.entities.find(e=>e.id==='patch').reactionSerial,1,id);
    for(let i=0;i<5;i++)tick(match,{interact:true});
    assert.equal(match.snapshot().campaign.story.pets,1,'held E must not repeat');
    tick(match);tick(match,{interact:true});assert.equal(match.snapshot().campaign.story.pets,2,'fresh E pets again');
    assert.equal(match.actors.filter(a=>a.isNpc).length,0,'friendlies never become hostile actors');
    assert.equal(match.snapshot().campaign.kills,0);
  }
});

test('four distinct proximity beats per chapter, stable IDs and no per-frame caption replay',()=>{
  for(const id of CAMPAIGN_MAP_IDS){
    const data=loadCampaignMap(id),story=createCampaignStory(data),points=storyPlacement(data),
      keys=id==='rootfall-verge'?['arrival','archive','repeater','departure']:
        id==='siltwake-crossing'?['arrival','pump','bridge','departure']:
        id==='emberline-ascent'?['arrival','bus','uplink','departure']:['arrival','feeder','cradle','reunion'],
      steps=id==='rootfall-verge'?[0,1,3,5]:id==='siltwake-crossing'?[0,2,4,5]:
        id==='emberline-ascent'?[0,2,4,5]:[0,2,3,5];
    keys.forEach((key,i)=>{
      const state={stepIndex:steps[i],totalElapsed:i*20,encounter:null,deployed:false,marker:points[key]},
        player=points[key],first=story.update(state,player,false,data.arena);
      assert.equal(first.caption?.id,`${id}-${key}`,`${id} ${key}`);
      assert.ok(first.entities.some(e=>e.pose!== 'idle'));
      const repeat=story.update({...state,totalElapsed:state.totalElapsed+6},player,false,data.arena);
      assert.equal(repeat.caption,null,'caption expires and does not replay');
      assert.ok(repeat.completed.includes(`${id}-${key}`));
    });
    if(id==='crown-array'){
      const finale=story.update({stepIndex:5,totalElapsed:100,marker:points.reunion},points.reunion,false,data.arena);
      const pup=finale.entities.find(e=>e.kind==='puppy');
      assert.equal(pup?.id,'patch');
      assert.equal(obstructed(pup.x,pup.y,pup.z,.65,data.arena),false);
      assert.ok(Math.abs(floorAt(pup.x,pup.z,data.arena)-pup.y)<.08);
    }
  }
});

test('mandatory E wins, and remote/vertical/occluded pets are rejected',()=>{
  const data=loadCampaignMap('rootfall-verge'),story=createCampaignStory(data),
    base={stepIndex:0,totalElapsed:1,encounter:null,deployed:false,marker:data.campaign.anchors.start};
  const pup=story.update(base,data.campaign.anchors.start,false,data.arena).entities.find(e=>e.id==='patch');
  assert.equal(story.update(base,{...pup,x:pup.x+20},true,data.arena).pets,0);
  story.update(base,pup,false,data.arena);
  assert.equal(story.update(base,{...pup,y:pup.y+2},true,data.arena).pets,0);
  story.update(base,pup,false,data.arena);
  const mandatory={...base,encounter:{mechanic:'interact'},deployed:true,enemiesRemaining:0,
    marker:{...pup,radius:3}};
  const protectedPet=story.update(mandatory,pup,true,data.arena);
  assert.equal(protectedPet.prompt,null);assert.equal(protectedPet.pets,0);
  story.update(base,pup,false,data.arena);
  // A test-only opaque wall across the sight ray leaves the route and entity unchanged.
  const blocked={...data.arena,blocks:[...data.arena.blocks,{x:pup.x+.8,z:pup.z,w:.6,d:3,baseY:0,h:100}]};
  const position={...pup,x:pup.x+1.6};
  assert.equal(story.update(base,position,true,blocked).pets,0);
});

test('retry preserves chapter completion and pet serial; restart drops only current chapter',()=>{
  const first=createCampaignMatch({random:()=>.5}),puppy=first.snapshot().campaign.story.entities.find(e=>e.kind==='puppy');
  at(first,puppy);tick(first);tick(first,{interact:true});
  const checkpoint=first.campaignCheckpoint();
  assert.equal(checkpoint.storyCarry.chapters['rootfall-verge'].petCount,1);
  const retry=createCampaignMatch({...checkpoint,random:()=>.5}),replay=retry.snapshot().campaign.story;
  assert.equal(replay.pets,1);assert.equal(replay.entities.find(e=>e.id==='patch').reactionSerial,1);
  assert.ok(replay.completed.includes('rootfall-verge-arrival'));
  const next=createCampaignMatch({mapId:'siltwake-crossing',storyCarry:retry.campaignStoryContinuity(),random:()=>.5});
  assert.equal(next.snapshot().campaign.story.pets,1);
  const reset={chapters:{...next.campaignStoryContinuity().chapters}};
  delete reset.chapters['siltwake-crossing'];
  assert.equal(createCampaignMatch({mapId:'siltwake-crossing',storyCarry:reset,random:()=>.5}).snapshot().campaign.story.pets,1);
});

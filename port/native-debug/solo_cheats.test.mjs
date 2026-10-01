import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createCampaignMatch} from '../native-campaign/match.mjs';
import {createAuthority} from '../native-campaign/authority.mjs';
import {spawnGroup} from '../../game/singleplayer.mjs';
import {attachSoloCheats, parseSoloCheat, soloCheatPreferences} from './solo_cheats.mjs';

const make = () => createCampaignMatch({random:()=>.5});
test('disabled solo cheats leave the source campaign simulation unchanged', () => {
  const baseline=make(), wrapped=make();
  attachSoloCheats(wrapped);
  for(let i=0;i<40;i++) {
    const input={inputs:{0:{x:.5,z:.25,yaw:.2,fire:i%12===0}}};
    baseline.step(1/60,input);wrapped.step(1/60,input);
    const {soloCheats,...actual}=wrapped.snapshot();
    assert.equal(soloCheats.invulnerable,false);
    assert.deepEqual(actual,baseline.snapshot());
  }
});
test('solo cheats validate explicit booleans, actions and input epochs', () => {
  const valid = {type:'solo-cheat',v:1,action:'flight',enabled:true,inputEpoch:1};
  assert.equal(parseSoloCheat(valid).enabled,true);
  for (const frame of [{...valid,inputEpoch:0},{...valid,enabled:1},{...valid,action:'teleport'},
    {...valid,x:100},{...valid,v:2},{...valid,action:'weapons'}]) assert.throws(()=>parseSoloCheat(frame));
});

test('human-only invulnerability is reversible; ammo and grants do not change source config', () => {
  const match=make(), preferences=soloCheatPreferences(), cheats=attachSoloCheats(match,preferences), player=match.actors[0];
  player.protection=0;player.armor=0;
  match.damage(player,10,null);assert.ok(player.health<player.maxHealth);
  cheats.apply({action:'invulnerable',enabled:true});
  const health=player.health, armor=player.armor;
  match.damage(player,10000,null);
  assert.equal(player.health,health);assert.equal(player.armor,armor);assert.equal(match.over,false);
  const [npcId]=spawnGroup(match,match.modeState,{type:'husk',count:1,group:'cheat-isolation'},{team:1});
  const npc=match.actors.find(actor=>actor.id===npcId);
  npc.protection=0;npc.armor=0;
  const npcHealth=npc.health;
  match.damage(npc,10,player);
  assert.ok(npc.health<npcHealth,'Invulnerability does not protect enemies');
  cheats.apply({action:'invulnerable',enabled:false});
  match.damage(player,10,null);assert.ok(player.health<health || player.armor<armor);
  const config=JSON.stringify(match.config);
  cheats.apply({action:'weapons'});
  assert.equal(player.ammo.length,10);
  player.ammo.forEach((value,index)=>assert.equal(value,match.weaponForIndex(player,index).cap));
  player.weapon=1;
  cheats.apply({action:'unlimitedAmmo',enabled:true});
  player.ammo[player.weapon]=1;
  match.step(1/60,{inputs:{0:{}}});
  assert.equal(player.ammo[player.weapon],match.weaponForIndex(player,player.weapon).cap);
  assert.equal(JSON.stringify(match.config),config);
  cheats.apply({action:'clear'});
  assert.deepEqual(preferences,soloCheatPreferences());
  player.ammo[player.weapon]=1;
  match.step(1/60,{inputs:{0:{}}});
  assert.equal(player.ammo[player.weapon],1);
});

test('flight rises and descends from real controls, remains bounded, and lands outside solids', () => {
  const match=make(), cheats=attachSoloCheats(match), player=match.actors[0];
  const initial={x:player.x,y:player.y,z:player.z};
  cheats.apply({action:'invulnerable',enabled:true});
  cheats.apply({action:'flight',enabled:true});
  for(let i=0;i<60;i++)match.step(1/60,{inputs:{0:{jump:true}}});
  assert.ok(player.y>initial.y+11 && player.y<initial.y+13);
  const high=player.y;
  for(let i=0;i<30;i++)match.step(1/60,{inputs:{0:{crouch:true}}});
  assert.ok(player.y<high-5);
  assert.equal(player.grounded,false);
  cheats.apply({action:'flight',enabled:false});
  assert.equal(player.grounded,true);
  assert.ok(Math.abs(player.y-initial.y)<.01);
  assert.ok(player.health>0);
  const paused=match.snapshot().campaign.totalElapsed;
  cheats.apply({action:'pause',enabled:true});
  for(let i=0;i<60;i++)match.step(1/60,{inputs:{0:{x:1,fire:true}}});
  assert.equal(match.snapshot().campaign.totalElapsed,paused);
  cheats.apply({action:'pause',enabled:false});
  match.step(1/60,{inputs:{0:{}}});
  assert.ok(match.snapshot().campaign.totalElapsed>paused);
});

test('campaign wire confirms cheats, pauses authority time, rejects stale commands and clears on new connection', {timeout:12000}, async () => {
  const authority=createAuthority({random:()=>.5});
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  let socket;
  const connect=async()=>{
    socket=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}/native-campaign`);
    const frames=[];socket.on('message',bytes=>frames.push(JSON.parse(String(bytes))));
    await once(socket,'open');
    const wait=async predicate=>{for(let i=0;i<250;i++){const item=frames.findLast(predicate);if(item)return item;await new Promise(resolve=>setTimeout(resolve,10));}throw Error('Campaign wire deadline');};
    socket.send(JSON.stringify({type:'create',v:3,nativeArenaInput:1}));await wait(f=>f.type==='welcome');
    socket.send(JSON.stringify({type:'start'}));await wait(f=>f.type==='snapshot');
    return {frames,wait};
  };
  try {
    let {frames,wait}=await connect();
    let latest=frames.findLast(f=>f.type==='snapshot');
    const epoch=latest.inputEpoch;
    socket.send(JSON.stringify({type:'solo-cheat',v:1,action:'pause',enabled:true,inputEpoch:epoch}));
    latest=await wait(f=>f.state?.soloCheats?.paused===true);
    assert.ok(latest.inputEpoch>epoch);
    const time=latest.state.campaign.totalElapsed, seq=latest.seq;
    const next=await wait(f=>f.type==='snapshot'&&f.seq>seq+4);
    assert.equal(next.state.campaign.totalElapsed,time);
    socket.send(JSON.stringify({type:'solo-cheat',v:1,action:'flight',enabled:true,inputEpoch:epoch}));
    const later=await wait(f=>f.type==='snapshot'&&f.seq>next.seq+2);
    assert.equal(later.state.soloCheats.flight,false);
    socket.send(JSON.stringify({type:'solo-cheat',v:1,action:'invulnerable',enabled:true,inputEpoch:latest.inputEpoch}));
    await wait(f=>f.state?.soloCheats?.invulnerable===true);
    socket.send(JSON.stringify({type:'solo-cheat',v:1,action:'pause',enabled:false,inputEpoch:latest.inputEpoch}));
    const resumed=await wait(f=>f.type==='snapshot'&&f.state.soloCheats.paused===false&&f.state.soloCheats.invulnerable===true);
    assert.ok(resumed.inputEpoch>latest.inputEpoch);
    await wait(f=>f.state?.campaign?.totalElapsed>time);
    socket.close();await once(socket,'close');
    ({frames,wait}=await connect());
    latest=await wait(f=>f.type==='snapshot');
    assert.equal(latest.state.soloCheats.invulnerable,false);
    assert.equal(latest.state.soloCheats.paused,false);
  } finally {
    if(socket?.readyState===WebSocket.OPEN){socket.close();await once(socket,'close');}
    await authority.close();
  }
});

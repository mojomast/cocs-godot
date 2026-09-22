// PRIVATE source oracle: setup mutations are explicit and never enter a server.
// Actual Match.applyPowerup / damage / collect / spawn generate all combat data.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdirSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {Match} from '../../game/core.mjs';
import {applyEnemyFields} from '../../game/enemy-types.mjs';
import {EventCursor} from '../native-horde/authority.mjs';

const json = x => JSON.parse(JSON.stringify(x));
export function sourceScenario() {
  const match = new Match('chatgpt','openclaw',()=>.37,'meridian-exchange',{mode:'deathmatch',botCount:1});
  const [source,target] = match.actors;
  // Deliberate private test rig, sufficient HP to survive real shield depletion.
  Object.assign(source,{x:2,y:0,z:5,protection:0,bot:null});
  Object.assign(target,{x:0,y:0,z:0,yaw:0,health:300,maxHealth:300,armor:24,protection:0,temporaryShield:0,juggernautShield:0,bot:null});
  const cursor = new EventCursor(); cursor.take(match);
  const frames=[];
  let seq=0;
  const take = label => {
    const items=cursor.take(match);
    frames.push({label,events:{type:'events',items:json(items)},snapshot:{type:'snapshot',seq:++seq,acks:{0:0},state:json(match.snapshot())}});
  };
  take('armor');
  assert(match.applyPowerup(target,'overshield')); take('shield');
  const before=json(target);
  match.damage(target,35,source); take('shield-damage');
  assert.equal(before.temporaryShield-target.temporaryShield,35);
  assert.equal(target.armor,24);
  const remaining=target.temporaryShield;
  match.damage(target,remaining+80,source); take('armor-depleted');
  const broken=frames.at(-1).events.items.find(e=>e.type==='damage');
  assert.equal(target.temporaryShield,0); assert.equal(target.armor,0); assert(target.health>0);
  assert.equal(broken.shieldBreak,true);
  assert.equal(broken.shield,remaining);
  assert.equal(broken.amount,remaining+80);
  assert(target.powerups.overshield>0,'timer intentionally remains after pool breaks');
  match.collect(target,{kind:'health',wait:0}); take('recovery');
  match.spawn(target); take('respawn');
  return {match,source,target,frames,cursor,take};
}

export function fixtures() {
  const {frames}=sourceScenario();
  const dashMatch=new Match('chatgpt','cline',()=>.37,'meridian-exchange',{mode:'deathmatch',botCount:0});
  const runner=dashMatch.actors[0];
  const dashCursor=new EventCursor(); dashCursor.take(dashMatch);
  assert(dashMatch.power(runner));
  const dash={events:{type:'events',items:dashCursor.take(dashMatch)},snapshot:{type:'snapshot',seq:1,acks:{0:0},state:json(dashMatch.snapshot())}};
  const moved=dash.events.items.find(e=>e.type==='dash');
  assert(moved && Math.hypot(moved.to.x-moved.from.x,moved.to.z-moved.from.z)>1,'source dash actually moved');
  const horde=new Match('chatgpt','openclaw',()=>.37,'meridian-exchange',{mode:'horde',botCount:0});
  // Same public NPC setup used by source singleplayer spawning, in a private rig.
  const npc=horde.actor(21,'grok','openclaw'); npc.isNpc=true;
  applyEnemyFields(npc,'bulwark'); horde.actors.push(npc); horde.spawn(npc);
  npc.protection=0;
  assert(npc.npcShield?.reduction>0);
  const cursor=new EventCursor();
  const hordeFrame={events:{type:'events',items:cursor.take(horde)},snapshot:{type:'snapshot',seq:1,acks:{0:0},inputEpoch:1,state:json(horde.snapshot())}};
  const manifest=JSON.parse(readFileSync(new URL('../../godot/content/generated/manifest.json',import.meta.url)));
  const maps=manifest.maps.map(map=>{
    const mode=map.modes.includes('deathmatch')?'deathmatch':map.modes[0];
    const m=new Match('chatgpt','openclaw',()=>.37,map.id,{mode,botCount:0});
    assert.equal(m.arena.id,map.id);
    return {mapId:map.id,mode,actor:json(m.snapshot().actors[0])};
  });
  return {provenance:'Private setup + executed, unmodified source Match methods and actual Match.snapshot; numeric Horde EventCursor IDs. Not natural multiplayer play.',frames,dash,horde:hordeFrame,maps};
}

if (process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  const data=fixtures();
  mkdirSync(new URL('../../godot/tests/combat_shields/',import.meta.url),{recursive:true});
  writeFileSync(new URL('../../godot/tests/combat_shields/source.json',import.meta.url),JSON.stringify(data,null,2)+'\n');
  console.log(`COMBAT_SHIELDS_SOURCE_OK frames=${data.frames.length} maps=${data.maps.length} shield_damage=35 armor_depletion=24 horde_directional=${data.horde.snapshot.state.actors[1].npcShield.reduction}`);
}

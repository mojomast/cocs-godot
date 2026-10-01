#!/usr/bin/env node
// Execute each advertised pair through the real two-human room constructor.
import assert from 'node:assert/strict';
import {Room} from './derived/room.mjs';
import {WORLDS,readWorld} from './catalog.mjs';

const rows=[];
for(const [map,entry] of Object.entries(WORLDS)){
 const hash=readWorld(map).geometryHash;
 for(const mode of entry.modes){
  const room=new Room();
  room.join(1,'Host');room.join(2,'Guest');
  room.host(1,{mode,botCount:2,timeLimit:120,fragLimit:3},map);
  assert.equal(room.config?.mode,mode,`${map}/${mode} configuration`);
  assert.equal(room.start(1),true,`${map}/${mode} starts`);
  assert.equal(room.mapId,map);
  assert.equal(room.match.snapshot().mapId,map);
  assert.equal(room.match.actors.filter(actor=>!actor.bot).length,2,`${map}/${mode} humans`);
  if(mode.startsWith('puma-'))assert.ok(room.match.vehicles?.length>=2,`${map}/${mode} vehicle seats`);
  else assert.ok(room.match.nav.length>=400,`${map}/${mode} bot navigation`);
  const start=room.drain().findLast(item=>item.msg.type==='start')?.msg;
  assert.equal(start?.geometryHash,hash,`${map}/${mode} geometry identity`);
  for(let i=0;i<30;i++)room.tick(1/60);
  assert.equal(room.match.config.mode,mode);
  const state=room.match.snapshot();
  if(mode==='ctf')assert.equal(state.objectives.flags.length,2);
  if(mode==='payload')assert.ok(state.objectives.payload.total>60);
  if(['koth','domination','uplink','holdout','assault'].includes(mode))assert.ok(state.objectives.zones.length>=1);
  rows.push({map,mode,hash,humans:2,bots:2,nav:room.match.nav.length,objective:state.objectives?.kind??state.race?.kind??(mode==='ctf'?'flags':'combat')});
 }
}
console.log(JSON.stringify({pairs:rows.length,rows},null,2));

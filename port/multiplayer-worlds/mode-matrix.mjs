#!/usr/bin/env node
// Execute each advertised pair through the real two-human room constructor.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Room} from './derived/room.mjs';
import {WORLDS,readWorld} from './catalog.mjs';
import {floorAt,obstructed,rayWorld} from './derived/core.mjs';

// A race circuit's checkpoint count is authored data, never a constant here.
// The hand-written recipe carries race.gates verbatim into the generated Godot
// arena, and game/race.mjs initializeRace copies them into the live room, so
// the room must reproduce the authored gate sequence exactly. Sources of truth:
//   port/native-multiplayer-worlds/worlds/sirocco-circuit.json      14 gates
//   port/native-multiplayer-worlds/worlds/stormglass-causeway.json  21 gates
// Each circuit derives one gate per authored centerline corner (see
// tools/godot-multiplayer/new-maps/stormglass-causeway/recipe.mjs), and a
// circuit is only valid when the gate sequence matches the driving loop.
const authoredRace=map=>{
 const recipe=JSON.parse(readFileSync(new URL(`../native-multiplayer-worlds/worlds/${map}.json`,import.meta.url),'utf8'));
 if(recipe.id!==map||!Array.isArray(recipe.race?.gates)||!recipe.race.gates.length||!Array.isArray(recipe.race?.centerline))throw Error(`No authored race circuit for ${map}`);
 return recipe.race;
};

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
  if(mode==='payload' && room.match.arena.payloadPath){
   const path=room.match.objectiveState.path;
   for(const point of room.match.arena.payloadPath)assert.ok(path.some(p=>Math.hypot(p.x-point.x,p.z-point.z)<.15),`${map}: freight cart missed ${JSON.stringify(point)}`);
  }
  for(const box of room.match.arena.overhead??[]){
   // Ground access remains open beneath the roof, while an authority ray
   // upward is stopped by precisely the authored underside height.
   assert.equal(obstructed(box.x,0,box.z,.65,room.match.arena),false,`${map}/${box.id}: walk-under sealed`);
   assert.ok(floorAt(box.x,box.z,room.match.arena)!==null,`${map}/${box.id}: missing ground`);
   const hit=rayWorld({x:box.x,y:1,z:box.z},{x:0,y:1,z:0},box.maxY+1,room.match.arena);
   assert.ok(Math.abs(hit-(box.minY-1))<.02,`${map}/${box.id}: roof underside authority mismatch ${hit}`);
  }
  if(mode==='puma-race'){
   const circuit=authoredRace(map);
   assert.equal(circuit.gates.length,circuit.centerline.length,`${map}: authored gates match the driving loop`);
   assert.deepEqual(room.match.race.gates,circuit.gates,`${map}: race room carries the authored gate sequence`);
  }
  if(mode==='cocs'||mode==='cocs-coop')assert.equal(room.match.arena.nodes.length,7);
  if(['koth','domination','uplink','holdout','assault'].includes(mode))assert.ok(state.objectives.zones.length>=1);
  rows.push({map,mode,hash,humans:2,bots:2,nav:room.match.nav.length,objective:state.objectives?.kind??state.race?.kind??(mode==='ctf'?'flags':'combat')});
 }
}
console.log(JSON.stringify({pairs:rows.length,rows},null,2));

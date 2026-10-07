#!/usr/bin/env node
// Execute each advertised pair through the real two-human room constructor.
import assert from 'node:assert/strict';
import {Room} from './derived/room.mjs';
import {WORLDS,readWorld} from './catalog.mjs';
import {assertAuthoredCircuit} from './race-circuits.mjs';
import {floorAt,obstructed,rayWorld} from './derived/core.mjs';

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
   //
   // The ray is released just *below* the authored underside rather than from
   // the floor. Probing from y=1 only worked for roofs low above ground: tall
   // interiors legitimately floor over (parallax-observatory decks a walkable
   // storey at y=12 beneath the ephemeris vault ceiling at y=16.8), so a ray
   // from the floor is intercepted by that interior deck and reports the deck
   // rather than the roof, which is a false failure. Releasing at
   // minY-CLEARANCE puts the origin in the empty gap directly under the roof
   // for every authored map (audited: all 23 overhead boxes across the six
   // ceiling maps have an empty window there), so the ray can only be stopped
   // by the underside it is meant to measure.
   //
   // This is still not self-fulfilling: the expectation comes from the
   // authored overhead declaration, while the ray is answered by the
   // collision geometry the world builder derives from it. A ceiling whose
   // underside is authored at one height but built at another still fails,
   // as does a missing underside (the ray runs to maxY+1).
   const CLEARANCE=.5;
   const start=box.minY-CLEARANCE;
   assert.equal(obstructed(box.x,0,box.z,.65,room.match.arena),false,`${map}/${box.id}: walk-under sealed`);
   assert.ok(floorAt(box.x,box.z,room.match.arena)!==null,`${map}/${box.id}: missing ground`);
   assert.ok(start>0,`${map}/${box.id}: overhead clearance below the floor ${start}`);
   const hit=rayWorld({x:box.x,y:start,z:box.z},{x:0,y:1,z:0},box.maxY+1,room.match.arena);
   assert.ok(Math.abs(hit-CLEARANCE)<.02,`${map}/${box.id}: roof underside authority mismatch ${start+hit} vs authored ${box.minY}`);
  }
  if(mode==='puma-race')assertAuthoredCircuit(room.match.race,map,`${map}/${mode}`);
  if(mode==='cocs'||mode==='cocs-coop')assert.equal(room.match.arena.nodes.length,7);
  if(['koth','domination','uplink','holdout','assault'].includes(mode))assert.ok(state.objectives.zones.length>=1);
  rows.push({map,mode,hash,humans:2,bots:2,nav:room.match.nav.length,objective:state.objectives?.kind??state.race?.kind??(mode==='ctf'?'flags':'combat')});
 }
}
console.log(JSON.stringify({pairs:rows.length,rows},null,2));

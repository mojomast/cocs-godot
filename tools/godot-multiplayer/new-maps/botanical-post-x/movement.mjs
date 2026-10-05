// Execute the production authoritative mover itself, not a guessed stair solver.
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {moveActor,floorAt,obstructed,MOVE} from '../../../../game/core.mjs';
import {RULES} from '../../../../game/data.mjs';
import {ensureTerrainBvh,terrainRayHitFast} from '../../../../game/terrain-bvh.mjs';
const root=new URL('../../../../',import.meta.url);
export const PINS={
 // 'godot/multiplayer_worlds/generated/vesper-viaduct.json' re-pinned
 // 2026-10-05 by the support-visible stair edge rebuild
 // (VESPER_BEVEL_SUPPORT_VISIBLE_20261005.md): the 80 civic tread tops are
 // byte-identical to the authored world and 80 walkable -apron surfaces carry
 // the ascent face at 40.03 deg, inside terrain.maxSlope (40.107 deg).
 'godot/multiplayer_worlds/generated/vesper-viaduct.json':'0f7f8a0aa5bd8ff1bd8b5098fa0c9e3a63fa770cc748407ae2a0db29ca484a0c',
 'port/new-maps/vesper-viaduct/variety/urban-v3/authority.json':'d4a61518a58dfd9c906d6d5641e2b9f58ea2fa005d202da95c5528c0fa26e70f',
 'game/core.mjs':'655f112934b7b4a4f1d9f043a8c545511e7284f557e4c9586dfd72d3e5a8e7a3',
 'game/data.mjs':'2c96517b6a04e0c35f82cd03ab3bb5ff17202181fe8870f6ff605fb88af45e44',
};
export function bytes(path){const b=readFileSync(new URL(path,root));assert.equal(createHash('sha256').update(b).digest('hex'),PINS[path],`Pinned source drift: ${path}`);return b;}
export function inputs(){for(const p of Object.keys(PINS))bytes(p);return {
 accepted:JSON.parse(bytes('godot/multiplayer_worlds/generated/vesper-viaduct.json')),
 candidate:JSON.parse(bytes('port/new-maps/vesper-viaduct/variety/urban-v3/authority.json'))};}
export const RUNS={civic:{lanes:[30.5,31.25,32,32.75,33.5],ends:[24,66]},roof:{lanes:[16.5,17.25,18,18.75,19.5],ends:[51,70]}};
export function trial(arena,run,x,direction,sprint=false){
 const [z0,z1]=direction===1?run.ends:[...run.ends].reverse();
 const a={x,y:floorAt(x,z0,arena),z:z0,vx:0,vy:0,vz:0,moveSpeed:8,grounded:true,coyote:0,jumpBuffer:0};
 assert.ok(Number.isFinite(a.y));
 const trace=[];const bvh=ensureTerrainBvh(arena.terrain);let maxDeltaY=0,blockedFrames=0,headroomFailures=0;
 for(let frame=0;frame<720&&direction*(z1-a.z)>.08;frame++){
  const before={x:a.x,y:a.y,z:a.z};moveActor(a,{z:direction,sprint},RULES.dt,arena);
  assert.ok([a.x,a.y,a.z,a.vx,a.vy,a.vz].every(Number.isFinite));
  const deltaY=a.y-before.y;maxDeltaY=Math.max(maxDeltaY,Math.abs(deltaY));
  if(Math.abs(a.z-before.z)<1e-9)blockedFrames++;
  // Independent upper-body headroom probe: start above the documented <.25m
  // terrain step band. This does not claim a finite lower capsule is clear.
  const headHits=[];
  for(const [dx,dz] of [[0,0],[-RULES.radius,-RULES.radius],[-RULES.radius,RULES.radius],[RULES.radius,-RULES.radius],[RULES.radius,RULES.radius]]){
   const hit=terrainRayHitFast(bvh,{x:a.x+dx,y:a.y+.25,z:a.z+dz},{x:0,y:1,z:0},RULES.height-.25);
   if(hit)headHits.push({dx,dz,distance:hit.distance});
  }
  const obstructedNow=obstructed(a.x,a.y,a.z,RULES.radius,arena);
  headroomFailures+=headHits.length;
  trace.push({frame,x:a.x,y:a.y,z:a.z,vx:a.vx,vy:a.vy,vz:a.vz,grounded:a.grounded,
   support:floorAt(a.x,a.z,arena),deltaY,obstructed:obstructedNow,headHits});
 }
 return {x,direction,sprint,start:[x,floorAt(x,z0,arena),z0],goal:[x,floorAt(x,z1,arena),z1],
  reached:direction*(z1-a.z)<=.08,frames:trace.length,maxDeltaY,blockedFrames,headroomFailures,trace};
}
export function campaign(){
 const maps=inputs(),trials=[];
 for(const [variant,data] of Object.entries(maps))for(const [name,run] of Object.entries(RUNS))for(const x of run.lanes)for(const direction of [-1,1])for(const sprint of [false,true]){
  const r=trial(data.arena,run,x,direction,sprint);const required=variant==='candidate'||name==='civic';
  if(required){assert.ok(r.reached,`${variant}/${name}/${x}/${direction} stalled`);assert.equal(r.blockedFrames,0);assert.equal(r.headroomFailures,0);
   assert.ok(r.maxDeltaY<.25);assert.ok(r.trace.every(t=>t.grounded&&Math.abs(t.y-t.support)<1e-7&&!t.obstructed));}
  trials.push({variant,run:name,required,...r});
 }
 return {scope:'actual production JS moveActor at 60Hz; no Godot engine or CharacterBody equivalence claimed',pins:PINS,
  rules:{dt:RULES.dt,radius:RULES.radius,height:RULES.height,eye:MOVE.eyeStanding,terminal:MOVE.terminal,
   terrainSnapStrictlyLessThan:.25,horizontalFloorRiseStrictlyLessThan:.3,axisSubstepMaximum:.18},
  nativeStatus:'pending explicit future grant',trials};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const result=campaign();
 if(process.argv[2])writeFileSync(process.argv[2],JSON.stringify(result)+'\n',{flag:'wx'});
 console.log(JSON.stringify({trials:result.trials.length,requiredPassed:result.trials.filter(t=>t.required&&t.reached).length,
  frames:result.trials.reduce((s,t)=>s+t.frames,0),acceptedRoofReached:result.trials.filter(t=>t.variant==='accepted'&&t.run==='roof'&&t.reached).length,
  nativeStatus:result.nativeStatus}));
}

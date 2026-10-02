#!/usr/bin/env node
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical} from '../../multiplayer-worlds/catalog.mjs';
import {Match,floorAt,obstructed,rayWorld,moveActor,walkEdge} from '../../multiplayer-worlds/derived/core.mjs';
import {terrainSupportAt,terrainTriangles} from '../../../game/terrain.mjs';
const data=JSON.parse(readFileSync(new URL('../../../godot/multiplayer_worlds/generated/parallax-observatory.json',import.meta.url))),a=data.arena;
assert.equal(createHash('sha256').update(canonical(a)).digest('hex'),data.geometryHash);
assert.ok(a.terrain.walls.every(w=>w.vertices.length===3),'source walls must retain movement-blocking diagonals');
// The exact derivative constructor used by the production world factory, with
// only its arena assignment intercepted. Shared registries belong to parent.
class ObservatoryMatch extends Match {get arena(){return a;}set arena(_fallback){} }
const make=mode=>new ObservatoryMatch('chatgpt','openclaw',()=>.5,a.id,{mode,botCount:0,humanCount:2,timeLimit:600,fragLimit:3});
const m=make('ctf');
const nearest=p=>m.nav.map((q,i)=>[i,Math.hypot(p.x-q.x,p.y-q.y,p.z-q.z)]).sort((a,b)=>a[1]-b[1])[0];
const point=([x,z])=>({x,y:floorAt(x,z,a),z});
const targets=[...a.spawns,...a.pickups.map(p=>p.slice(1)),...a.objectiveZones.map(p=>[p.x,p.z]),...Object.values(a.flagSpawns).map(p=>[p.x,p.z])].map(point);
const seen=new Set([0]),q=[0];for(let i=0;i<q.length;i++)for(const j of m.edges[q[i]])if(!seen.has(j)){seen.add(j);q.push(j);}
for(const p of targets){assert.notEqual(p.y,null);assert.equal(obstructed(p.x,p.y,p.z,.65,a),false,`blocked ${JSON.stringify(p)}`);const [n,d]=nearest(p);assert.ok(d<5&&seen.has(n)&&walkEdge(p,m.nav[n],a),`unreachable target ${JSON.stringify(p)} ${d}`);}
assert.equal(seen.size,m.nav.length);
const distance=(from,to)=>{const start=nearest(from)[0],end=nearest(to)[0],d=m.nav.map(()=>Infinity),done=new Set();d[start]=0;while(done.size<d.length){let i=-1;for(let j=0;j<d.length;j++)if(!done.has(j)&&(i<0||d[j]<d[i]))i=j;if(i===end)return d[i];if(!Number.isFinite(d[i]))return null;done.add(i);for(const j of m.edges[i])d[j]=Math.min(d[j],d[i]+Math.hypot(m.nav[j].x-m.nav[i].x,m.nav[j].y-m.nav[i].y,m.nav[j].z-m.nav[i].z));}};
const travel=a.objectiveZones.map(zone=>({zone:zone.id,teams:[0,1].map(team=>a.teamSpawns[team].map(p=>distance(point(p),zone)))}));
const actor=m.actors[0];
function place(actor,p){Object.assign(actor,{x:p.x,y:p.y,z:p.z,vx:0,vy:0,vz:0,grounded:true,lastValid:{x:p.x,y:p.y,z:p.z}});}
function walk(points,onStep=()=>{}){
 let frames=0,maxFloorError=0;
 for(const p of points){let n=0;while(Math.hypot(p.x-actor.x,p.z-actor.z)>.18){
  const dx=p.x-actor.x,dz=p.z-actor.z;moveActor(actor,{x:dx,z:dz},1/60,a,m.config);onStep();frames++;n++;
  const y=floorAt(actor.x,actor.z,a);assert.notEqual(y,null,`fell ${JSON.stringify(actor.lastValid)}`);maxFloorError=Math.max(maxFloorError,Math.abs(actor.y-y));
  assert.ok(actor.y>=y-.15&&Math.abs(actor.y-y)<.6,`support discontinuity ${actor.x},${actor.z}: ${actor.y}/${y}`);
  assert.ok(n<5000,`stuck moving to ${JSON.stringify(p)} at ${actor.x},${actor.y},${actor.z}`);
 }
 }
 return {frames,seconds:frames/60,maxFloorError};
}
const journeys=[];
for(const route of data.routes){
 for(const reverse of [false,true]){
  const points=reverse?[...route.points].reverse():route.points;place(actor,points[0]);
  for(let i=1;i<points.length;i++){const p=points[i-1],r=points[i],n=Math.ceil(Math.hypot(r.x-p.x,r.z-p.z)/.2);for(let j=0;j<=n;j++){const t=j/n,x=p.x+(r.x-p.x)*t,z=p.z+(r.z-p.z)*t;const y=terrainSupportAt(x,z,a.terrain)?.y;assert.ok(Number.isFinite(y));assert.equal(obstructed(x,y,z,.65,a),false,`${route.id}: blocked centerline ${x},${y},${z}`);}}
  journeys.push({route:route.id,reverse,...walk(points.slice(1))});
 }
}
// Accurate source ceiling/top/side rays and open entrance rays for all slabs.
for(const roof of a.overhead){const y=floorAt(roof.x,roof.z,a);assert.ok(roof.minY-y>=4.8-1e-8);assert.equal(obstructed(roof.x,y,roof.z,.65,a),false);assert.ok(Math.abs(rayWorld({x:roof.x,y:y+1,z:roof.z},{x:0,y:1,z:0},20,a)-(roof.minY-y-1))<.01);assert.ok(Math.abs(rayWorld({x:roof.x,y:roof.maxY+2,z:roof.z},{x:0,y:-1,z:0},20,a)-2)<.01);assert.equal(terrainSupportAt(roof.x,roof.z,a.terrain).y,y);}
for(const [x,z,y] of [[-36,0,12],[24,78,0]]){assert.ok(rayWorld({x:x-16,y:y+1.5,z},{x:1,y:0,z:0},32,a)>31.9,'open arch airwall');assert.ok(rayWorld({x,y:y+1.5,z},{x:0,y:0,z:1},12,a)<8,'vault wall must occlude');}
assert.equal(terrainSupportAt(145,100,a.terrain),null,'sea must be a real void');
assert.ok(terrainTriangles(a.terrain).filter(t=>t.walkable).every(t=>t.normal[1]>=Math.cos(.48)));
// Actual movement carries the enemy flag home by the upper route; the lower
// route is traversed in the opposite direction for the next capture.
actor.team=0;const other=m.actors[1];other.team=1;place(other,point([118,5]));
const captures=[];
for(const name of ['armillary-arc','tidal-cistern']){
 const route=data.routes.find(r=>r.id===name);place(actor,route.points[0]);walk(route.points.slice(1),()=>m.objective(actor));assert.equal(m.flags[1].carrier,actor.id);
 captures.push({route:name,...walk([...route.points].reverse().slice(1),()=>m.objective(actor))});assert.equal(m.flags[1].state,'at-base');
}
assert.equal(m.teamScores[0],2);
place(actor,point([108,0]));m.objective(actor);assert.equal(m.flags[1].carrier,actor.id);m.dropFlag(actor);place(actor,point([0,0]));place(other,point([108,0]));m.objective(other);assert.equal(m.flags[1].state,'at-base');assert.equal(other.scoreStats.flagReturns,1);
place(other,point([118,5]));place(actor,point([108,0]));m.objective(actor);
walk([...data.routes[0].points].reverse().slice(1),()=>m.objective(actor));
assert.equal(m.teamScores[0],3);assert.equal(m.over,true);assert.equal(m.overReason,'capture');
const modes=[];
for(const mode of ['deathmatch','teamdeathmatch','koth','uplink','holdout']){const match=make(mode);assert.equal(match.snapshot().mapId,a.id);assert.equal(match.config.mode,mode);for(const actor of match.actors)assert.equal(obstructed(actor.x,actor.y,actor.z,.65,a),false);if(['koth','uplink','holdout'].includes(mode)){const z=match.objectiveState.zones[0];place(match.actors[0],z);place(match.actors[1],point([118,5]));for(let i=0;i<600;i++)match.updateObjectives(1/60);assert.ok(match.actors[0].scoreStats.objectiveTime>0||match.actors[0].scoreStats.objectiveCaptures>0,`${mode} objective interaction`);}modes.push({mode,nav:match.nav.length,objective:match.objectiveState?.kind??'combat'});}
const rounds=[{mode:'ctf',winner:0,score:m.teamScores[0],reason:m.overReason}];
for(const mode of ['deathmatch','teamdeathmatch']){const match=make(mode),[killer,victim]=match.actors;for(let i=0;i<match.config.fragLimit;i++){match.spawn(victim);victim.protection=0;match.damage(victim,10000,killer);}assert.equal(match.over,true);assert.equal(match.overReason,'frag');rounds.push({mode,kills:match.stats.kills,reason:match.overReason});}
for(const mode of ['koth','uplink','holdout']){
 const match=make(mode);place(match.actors[1],point([118,5]));
 if(mode==='holdout'){match.actors[1].team=0;place(match.actors[1],match.objectiveState.zones[1]);}
 let ticks=0;while(!match.over&&ticks++<12000){place(match.actors[0],match.objectiveState.zones[0]);match.updateObjectives(1/60);}
 assert.equal(match.over,true,`${mode}: full source round`);rounds.push({mode,seconds:ticks/60,reason:match.overReason,score:match.teamScores[0]});
}
const pickupMatch=make('deathmatch'),collector=pickupMatch.actors[0];place(collector,point([-36,0]));collector.health=20;pickupMatch.step(1/60,{});assert.ok(collector.health>20);assert.ok(pickupMatch.stats.pickups>0);
console.log(JSON.stringify({id:a.id,geometryHash:data.geometryHash,source:'port/multiplayer-worlds/derived/core.mjs',navNodes:m.nav.length,connected:seen.size,targets:targets.length,travel,journeys,captures,flagReturns:other.scoreStats.flagReturns,healthPickup:pickupMatch.stats.pickups,modes,rounds,nativeStatus:'This report is source-only; see native-validation.json and VISUAL.md for separately executed native evidence.'},null,2));

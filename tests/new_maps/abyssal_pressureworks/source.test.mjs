import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from '../../../tools/godot-multiplayer/new-maps/abyssal-pressureworks/build.mjs';
import {Match,moveActor,floorAt,obstructed,navigation,rayWorld} from '../../../game/core.mjs';
import {validateMapSchema} from '../../../game/map-schema.mjs';
import {path} from '../../../game/bots.mjs';
const data=build(),arena=data.arena;
// Same arena-assignment seam as port/multiplayer-worlds/match.mjs, without registration.
class Fixture extends Match{get arena(){return arena;}set arena(_){}constructor(mode='ctf',options={}){super('chatgpt','openclaw',()=>.5,arena.id,{mode,botCount:0,fragLimit:1,timeLimit:30,...options});}}
const actor=()=>structuredClone(new Fixture('deathmatch',{skipNav:true}).actors[0]);
function place(a,[x,z]){Object.assign(a,{x,y:floorAt(x,z,arena),z,vx:0,vy:0,vz:0,grounded:true});}
function walk(a,points,tick){let total=0;for(const [x,z] of points){let n=0;while(Math.hypot(a.x-x,a.z-z)>.18&&n++<2400){const dx=x-a.x,dz=z-a.z,d=Math.hypot(dx,dz),input={x:dx/d,z:dz/d};if(tick){if(tick(input)===false)return total;}else moveActor(a,input,1/60,arena);total++;}assert(n<2400,`stalled ${a.x},${a.y},${a.z} -> ${x},${z}`);assert(Math.abs(a.y-floorAt(a.x,a.z,arena))<.15);}return total;}
test('deterministic schema, dry 20m terraces, 12 chambers / 17 galleries',()=>{
 assert.deepEqual(build(),data);assert.deepEqual(validateMapSchema(arena),[]);
 assert.equal(arena.structures.filter(s=>s.silhouette).length,12);assert.equal(arena.routes.length,17);
 assert.equal(arena.routes.filter(r=>r.id.startsWith('crosslink')).length,8);
 assert(arena.terrain.walls.every(w=>w.vertices.length===3));
 assert.equal(Math.max(...data.spawnPoints.map(p=>p.y))-Math.min(...data.spawnPoints.map(p=>p.y)),20);
 for(const s of arena.terrain.surfaces.filter(s=>!s.id.endsWith('-deck')&&!s.id.endsWith('-ramp')))assert.equal(s.walkable,false);
});
test('ordinary source moveActor walks every route in both directions and never leaves dry support',()=>{
 for(const route of arena.routes)for(const points of [route.points,[...route.points].reverse()]){const a=actor();place(a,points[0]);walk(a,points.slice(1));}
});
test('source bot graph connects all spawns, flags and objectives',()=>{
 const g=navigation(arena),seen=new Set([0]),q=[0];for(let i=0;i<q.length;i++)for(const n of g.edges[q[i]])if(!seen.has(n)){seen.add(n);q.push(n);}assert.equal(seen.size,g.nodes.length);
 const anchors=[...data.spawnPoints,...arena.objectiveZones,...Object.values(arena.flagSpawns).map(p=>({...p,y:floorAt(p.x,p.z,arena)}))];
 for(const a of anchors){assert(!obstructed(a.x,a.y,a.z,.65,arena));assert(g.nodes.some(n=>Math.hypot(n.x-a.x,n.z-a.z)<1));for(const b of anchors)assert(path(a,b,g.nodes,g.edges).length);}
});
test('actual standing body contact, portal rays, exact ceiling and transparent glazing',()=>{
 const a=actor();place(a,[-111,-68]);for(let i=0;i<360;i++)moveActor(a,{x:-1},1/60,arena);assert(a.x>-114.1,'west shell stopped sustained input');
 assert(rayWorld({x:-110,y:8,z:-68},{x:-1,y:0,z:0},10,arena)<5);
 assert.equal(rayWorld({x:-85,y:8,z:-68},{x:1,y:0,z:0},14,arena),14,'open E/W portal');
 const roof=rayWorld({x:-94,y:8,z:-68},{x:0,y:1,z:0},30,arena);assert(Math.abs(roof-11)<.01);
 assert.equal(rayWorld({x:-94,y:9,z:-84},{x:0,y:0,z:-1},15,arena),15,'transparent glazing does not stop shots');
 assert.equal(floorAt(-94,-92,arena),null,'ocean has no support');
});
test('every full shell segment sustains standing contact; all chamber ceilings and portals ray-test',()=>{
 let contacts=0,portals=0;
 for(const room of arena.structures.filter(s=>s.silhouette)){
  for(const wall of arena.terrain.walls.filter(w=>w.id.startsWith(`${room.id}-shell-`)&&w.id.endsWith('-0'))){
   const [a,b]=wall.vertices,x=(a[0]+b[0])/2,z=(a[2]+b[2])/2,dx=room.x-x,dz=room.z-z,l=Math.hypot(dx,dz),nx=dx/l,nz=dz/l;
   const hit=rayWorld({x:x+nx*1.5,y:room.y+2,z:z+nz*1.5},{x:-nx,y:0,z:-nz},3,arena);
   assert(hit<1.51,`${wall.id} ray`);
   const body=actor();place(body,[x+nx*1.5,z+nz*1.5]);
   for(let frame=0;frame<180;frame++)moveActor(body,{x:-nx,z:-nz},1/60,arena);
   assert((body.x-x)*nx+(body.z-z)*nz>.2,`${wall.id} standing contact`);contacts++;
  }
  const expected=room.h+({'terraced-laboratories':3,'pump-energy':5,'residential-operations':1.5}[room.district])-2;
  assert(Math.abs(rayWorld({x:room.x,y:room.y+2,z:room.z},{x:0,y:1,z:0},60,arena)-expected)<.01,room.id+' crown');
  for(const [side,p] of Object.entries(room.ports)){
   const [nx,nz]=({n:[0,-1],s:[0,1],e:[1,0],w:[-1,0]})[side];
   assert.equal(rayWorld({x:p.center[0]-nx,y:room.y+2,z:p.center[1]-nz},{x:nx,y:0,z:nz},2,arena),2,`${room.id}/${side} aperture`);portals++;
  }
 }
 assert(contacts>=30);assert.equal(portals,34);
});
test('walkable support polygons have no overlapping interiors',()=>{
 const floors=arena.terrain.surfaces.filter(s=>s.walkable);
 const inside=(x,z,s)=>{
  let sign=0;
  for(let i=0;i<s.vertices.length;i++){const a=s.vertices[i],b=s.vertices[(i+1)%s.vertices.length],c=(b[0]-a[0])*(z-a[2])-(b[2]-a[2])*(x-a[0]);if(Math.abs(c)<1e-5)return false;const next=Math.sign(c);if(sign&&next!==sign)return false;sign=next;}
  return true;
 };
 for(let x=-119.63;x<120;x+=1.1)for(let z=-109.71;z<110;z+=1.1){const count=floors.filter(s=>inside(x,z,s)).length;assert(count<=1,`stacked support at ${x},${z}`);}
});
test('elevated control approach and reactor floor have reciprocal counterfire sightlines',()=>{
 const route=arena.routes.find(r=>r.id==='crosslink-1-2'),a=route.points[1],b=route.points[2];
 const x=a[0]+(b[0]-a[0])*.55,z=a[1]+(b[1]-a[1])*.55;
 const high={x,y:floorAt(x,z,arena)+1.6,z},low={x:34,y:11.6,z:8};
 assert(high.y-low.y>5);
 for(const [from,to] of [[high,low],[low,high]]){const dx=to.x-from.x,dy=to.y-from.y,dz=to.z-from.z,d=Math.hypot(dx,dy,dz);assert(rayWorld(from,{x:dx/d,y:dy/d,z:dz/d},d,arena)>=d-.01);}
});
test('physical CTF carry round through ordinary Match.step input',()=>{
 const m=new Fixture(),a=m.actors[0];place(a,[-91,0]);a.team=0;
 const route=arena.routes.filter(r=>r.id.startsWith('broad-pump')).flatMap(r=>r.points);
 walk(a,route,input=>m.step(1/60,input));assert.equal(m.flags[1].carrier,a.id);
 walk(a,[...route].reverse(),input=>{m.step(1/60,input);return !m.over;});assert(m.over);assert.equal(m.teamScores[0],1);assert.equal(a.scoreStats.captures,1);
});
for(const mode of ['koth','domination','holdout'])test(`${mode}: source-input approach, capture and objective round win`,()=>{
 const m=new Fixture(mode,{timeLimit:600}),a=m.actors[0];a.team=0;place(a,[-91,0]);
 const approach=zone=>{
  const indices=path(a,zone,m.nav,m.edges);assert(indices.length);
  walk(a,indices.map(i=>[m.nav[i].x,m.nav[i].z]).concat([[zone.x,zone.z]]),input=>{m.step(1/60,input);return !m.over;});
 };
 const zone=m.objectiveState.zones[0];approach(zone);
 for(let i=0;i<1800&&!m.over&&zone.owner!==0;i++)m.step(1/60,{});
 assert.equal(zone.owner,0,'captured by physical presence');
 if(mode==='holdout'){
  const second=m.objectiveState.zones[1];approach(second);
  for(let i=0;i<1800&&!m.over&&second.owner!==0;i++)m.step(1/60,{});
  assert.equal(second.owner,0);
 }
 for(let i=0;i<6000&&!m.over;i++)m.step(1/60,{});
 assert(m.over,`${mode} round finished`);assert.equal(m.objectiveState.winner,0);
 assert(!m.objectiveState.tiebreak,'objective completion rather than time expiry');
 assert(a.scoreStats.objectiveTime>0);
});
test('all candidate modes construct on authored support; autonomous source bots leave spawn rooms',()=>{
 for(const mode of ['deathmatch','teamdeathmatch','ctf','koth','domination','holdout']){
  const m=new Fixture(mode,{botCount:3,timeLimit:600,fragLimit:20}),start=m.actors.map(a=>({x:a.x,z:a.z}));
  for(const a of m.actors)assert(!obstructed(a.x,a.y,a.z,.65,arena));
  for(let n=0;n<900;n++)m.step(1/60,{});
  const moved=m.actors.filter((a,i)=>a.bot&&Math.hypot(a.x-start[i].x,a.z-start[i].z)>8);
  assert(moved.length>0,`${mode} source bots moved >8m`);
  for(const a of m.actors)assert(Number.isFinite(a.y)&&a.y>arena.voidY);
 }
});

// Controlled source input evidence; not a native or human-play acceptance claim.
import assert from 'node:assert/strict';
import {Match,moveActor,floorAt,obstructed,rayWorld} from '../../../../game/core.mjs';
import {validateMapSchema} from '../../../../game/map-schema.mjs';
import {recipe} from '../../../../tools/godot-multiplayer/new-maps/vesper-viaduct/recipe.mjs';
export const arena=recipe();
export function actorAt([x,z]){return {x,z,y:floorAt(x,z,arena),vx:0,vy:0,vz:0,grounded:true,character:'chatgpt',harness:'openclaw',health:100,powerups:{},coyote:0,jumpBuffer:0};}
export function walk(actor,points,step=(input)=>moveActor(actor,input,1/60,arena)){
 let ticks=0;
 for(const [x,z] of points){let t=0;while(Math.hypot(actor.x-x,actor.z-z)>.35&&t++<2400){const dx=x-actor.x,dz=z-actor.z,length=Math.hypot(dx,dz);const done=step({x:dx/length*Math.min(1,length),z:dz/length*Math.min(1,length)});ticks++;if(done===true)return ticks;assert.ok(Number.isFinite(actor.y)&&actor.y>-3,'fell out of city');}assert.ok(t<2400,`stuck toward ${x},${z} at ${actor.x},${actor.y},${actor.z}`);}
 return ticks;
}
export function matchFor(mode,extra={}){
 class CityMatch extends Match{get arena(){return arena;}set arena(_value){}}
 return new CityMatch('chatgpt','openclaw',()=>.5,arena.id,{mode,botCount:0,humanCount:1,timeLimit:900,fragLimit:3,...extra});
}
assert.deepEqual(validateMapSchema(arena),[]);
const footprints=arena.terrain.surfaces.filter(s=>s.walkable).map(s=>({id:s.id,x0:Math.min(...s.vertices.map(p=>p[0])),x1:Math.max(...s.vertices.map(p=>p[0])),z0:Math.min(...s.vertices.map(p=>p[2])),z1:Math.max(...s.vertices.map(p=>p[2]))}));
for(let i=0;i<footprints.length;i++)for(let j=i+1;j<footprints.length;j++){const a=footprints[i],b=footprints[j];assert.ok(Math.min(a.x1,b.x1)-Math.max(a.x0,b.x0)<1e-6||Math.min(a.z1,b.z1)-Math.max(a.z0,b.z0)<1e-6,`overlapping playable decks ${a.id}/${b.id}`);}
let ticks=0;
for(const route of arena.routes)for(const reverse of [false,true]){const points=reverse?[...route.points].reverse():route.points;const a=actorAt(points[0]);ticks+=walk(a,points.slice(1));}
for(const p of [...arena.spawns,...arena.pickups.map(p=>p.slice(1)),...arena.objectiveZones.map(p=>[p.x,p.z]),...arena.navNodes.map(p=>[p.x,p.z])]){const y=floorAt(...p,arena);assert.notEqual(y,null);assert.equal(obstructed(p[0],y,p[1],.45,arena),false,`blocked nav/target ${p}`);}
assert.equal(floorAt(0,-110,arena),null,'water is a source void');
assert.equal(floorAt(0,85,arena),24,'station roof never becomes a floor');
assert.equal(floorAt(-66,0,arena),12,'courtyard roof never becomes a floor');
assert.ok(arena.terrain.walls.every(w=>w.vertices.length===3));
const tall=actorAt([-94,-10]);for(let i=0;i<360;i++)moveActor(tall,{x:1},1/60,arena);
assert.ok(tall.x<-90,'sustained contact crossed a 9 m triangular wall');
assert.ok(rayWorld({x:-94,y:14,z:-10},{x:1,y:0,z:0},10,arena)<4.1,'same tall wall stops eye ray');
for(const p of arena.spawns){const a=actorAt(p);walk(a,[[Math.sign(p[0])*120,p[1]],[Math.sign(p[0])*120,0],[0,0]]);}
for(const p of arena.pickups){const a=actorAt([0,0]);walk(a,[[0,p[2]],[p[1],p[2]]]);}
// Sustained body pressure and ray through the same wall, actual empty window,
// open doorway, roof underside. Checks avoid relying on metadata alone.
const a=actorAt([-66,-18]);for(let i=0;i<240;i++)moveActor(a,{z:1},1/60,arena);
assert.ok(a.z<-15,'body crossed sill');
assert.ok(rayWorld({x:-66,y:12.6,z:-18},{x:0,y:0,z:1},10,arena)<4);
assert.equal(rayWorld({x:-63,y:14,z:-18},{x:0,y:0,z:1},6,arena),6,'window is open');
assert.equal(rayWorld({x:-94,y:14,z:0},{x:1,y:0,z:0},12,arena),12,'doorway open');
assert.ok(rayWorld({x:-66,y:14,z:0},{x:0,y:1,z:0},30,arena)<12,'ceiling stops ray');
const jumper=actorAt([-66,0]);jumper.vy=35;jumper.grounded=false;let max=0;for(let i=0;i<100;i++){moveActor(jumper,{},1/60,arena);max=Math.max(max,jumper.y);}assert.ok(max<25,'ceiling stops body');
const navigation=matchFor('deathmatch'),visited=new Set([0]),queue=[0];
for(let i=0;i<queue.length;i++)for(const next of navigation.edges[queue[i]])if(!visited.has(next)){visited.add(next);queue.push(next);}
for(const [x,z] of [...arena.spawns,...arena.pickups.map(p=>p.slice(1)),...arena.objectiveZones.map(p=>[p.x,p.z])])assert.ok(navigation.nav.some((p,i)=>visited.has(i)&&Math.hypot(p.x-x,p.z-z)<2),`target missing from connected source nav ${x},${z}`);
console.log(JSON.stringify({gate:'source connected navigation',nodes:navigation.nav.length,reachable:visited.size,targets:15}));
console.log(JSON.stringify({gate:'source geometry and continuous movement',routes:arena.routes.length,directions:2,ticks,spawns:arena.spawns.length,pickups:arena.pickups.length,nav:arena.navNodes.length,wallTriangles:arena.terrain.walls.length,maxJumpY:max}));

#!/usr/bin/env node
// Static terrain/LOS/travel audit on exactly the arenas the source Match uses.
import assert from 'node:assert/strict';
import {readWorld} from './catalog.mjs';
import {worldMatchClass} from './match.mjs';
import {floorAt,obstructed,walkEdge} from '../../game/core.mjs';
const reach=(m,origin)=>{const seen=new Set([origin]),q=[origin];for(let n=0;n<q.length;n++)for(const j of m.edges[q[n]]??[])if(!seen.has(j)){seen.add(j);q.push(j);}return seen;};
const closest=(nodes,x,z,y)=>nodes.map((p,i)=>[i,Math.hypot(p.x-x,p.z-z,(p.y-y)*2)]).sort((a,b)=>a[1]-b[1])[0];
const records=[];
for(const id of ['switchyard-ward','rainmarket-exchange']){
 const data=readWorld(id),a=data.arena,m=new (worldMatchClass(id,'deathmatch'))('chatgpt','openclaw',()=>.5,id,{mode:'deathmatch',botCount:0,timeLimit:60,fragLimit:5,humanCount:2});
 const origin=closest(m.nav,...a.teamSpawns[0][0],floorAt(...a.teamSpawns[0][0],a))[0],connected=reach(m,origin);
 let unsupported=[],blocked=[],unreachable=[];
 const points=[...a.spawns,...a.pickups.map(p=>p.slice(1)),...a.objectiveZones.map(z=>[z.x,z.z]),...Object.values(a.flagSpawns).map(p=>[p.x,p.z])];
 for(const [x,z] of points){const y=floorAt(x,z,a);if(y===null){unsupported.push([x,z]);continue;}if(obstructed(x,y,z,.65,a))blocked.push([x,z,y]);const [nearest,distance]=closest(m.nav,x,z,y);if(!connected.has(nearest)||distance>5.5)unreachable.push([x,z,y,distance]);}
 // Elevated surface has to be traversable from a genuine source spawn, not
 // merely visually attached to ground. Each roof is a separate audit point.
 const roofs=a.terrain.surfaces.filter(s=>s.id.includes('roof')||s.id.includes('overlook'));
 for(const surface of roofs){const vertices=surface.vertices,x=vertices.reduce((n,p)=>n+p[0],0)/vertices.length,z=vertices.reduce((n,p)=>n+p[2],0)/vertices.length,y=floorAt(x,z,a),[nearest,distance]=closest(m.nav,x,z,y);if(!connected.has(nearest)||distance>5)unreachable.push([surface.id,x,z,y,distance]);}
 assert.deepEqual({unsupported,blocked,unreachable},{unsupported:[],blocked:[],unreachable:[]},`${id}: support/nav/clearance`);
 const spawns=a.teamSpawns[0].map(([x,z])=>({x,z,y:floorAt(x,z,a)})),opposites=a.teamSpawns[1].map(([x,z])=>({x,z,y:floorAt(x,z,a)}));
 const minEnemy=Math.min(...spawns.flatMap(p=>opposites.map(q=>Math.hypot(p.x-q.x,p.z-q.z))));
 assert.ok(minEnemy>=15,`${id}: team spawn separation ${minEnemy}`);
 const supportedNodes=m.nav.filter(n=>n.y>1),groundNodes=m.nav.filter(n=>n.y<.5);
 assert.ok(supportedNodes.length>=10&&groundNodes.length>=150,`${id}: insufficient multilevel source navigation`);
 records.push({id,geometryHash:data.geometryHash,sourceNavNodes:m.nav.length,connected:connected.size,roofNodes:supportedNodes.length,groundNodes:groundNodes.length,minimumOpposingSpawnDistance:minEnemy,roofCount:roofs.length,objectiveCount:a.objectiveZones.length});
}
console.log(JSON.stringify(records,null,2));

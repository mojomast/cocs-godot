// Diagnostic only: the public schema currently rejects nextGen:true. This
// measures the unchanged source navigation function without publishing an
// invalid asset or claiming a passing native constructor/handshake.
import fs from 'node:fs';
import {navigation} from '../../game/core.mjs';
import {readNativeArena, nativeArenaGeometryHash, parseNativeArena} from '../../port/native-arenas/schema.mjs';

const data=readNativeArena('aurora-basin');
const previousHash=data.geometryHash;
data.arena.nextGen=true;
data.geometryHash=nativeArenaGeometryHash(data.arena);
let schemaError=null;
try { parseNativeArena(data,data.id); } catch(error) { schemaError=error.message; }
const started=performance.now(),graph=navigation(data.arena);
const navigationMs=performance.now()-started;
const seen=new Set([0]),queue=[0];
for(let i=0;i<queue.length;i++)for(const k of graph.edges[queue[i]])if(!seen.has(k)){seen.add(k);queue.push(k);}
const omittedAuthored=[...data.arena.navNodes,...data.arena.spawns,...data.arena.pickups.map(p=>p.slice(1))].filter(([x,z])=>!graph.nodes.some(n=>Math.hypot(n.x-x,n.z-z)<.101));
let worstRouteDistance=0,maxEdge=0;
for(const route of data.routes)for(const p of route.points)worstRouteDistance=Math.max(worstRouteDistance,Math.min(...graph.nodes.map(n=>Math.hypot(n.x-p.x,n.z-p.z))));
for(const [i,edges] of graph.edges.entries())for(const j of edges)maxEdge=Math.max(maxEdge,Math.hypot(graph.nodes[i].x-graph.nodes[j].x,graph.nodes[i].z-graph.nodes[j].z));
const result={previousHash,candidateHash:data.geometryHash,schemaError,navigationMs,nodes:graph.nodes.length,edges:graph.edges.reduce((s,e)=>s+e.length,0),connected:seen.size===graph.nodes.length,omittedAuthored,worstRouteDistance,maxEdge,scope:'Cold source navigation only; no schema bypass or native-constructor pass claimed'};
console.log(JSON.stringify(result,null,2));
if(!result.connected||omittedAuthored.length||worstRouteDistance>3.01||maxEdge>6.50001)process.exitCode=1;

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {wallCandidates} from './wall_candidates.mjs';
import * as original from '../../game/core.mjs';
import * as optimized from './derived/core.mjs';
import {terrainWallSegments,stampTerrainFloor} from '../../game/terrain.mjs';

// Execute the unchanged source distance expression as the independent oracle.
const source=readFileSync(new URL('../../game/core.mjs',import.meta.url),'utf8');
const distance=Function('clamp',`return ${source.match(/const segmentDistance=(.*);/)[1]}`)((n,a,b)=>Math.max(a,Math.min(b,n)));
const segment=(x,z,bx,bz,y=0,by=3)=>({a:{x,y,z},b:{x:bx,y:by,z:bz}});
test('candidate superset retains EVERY blocker in original order across grid and distance boundaries',()=>{
  const segments=[segment(-16,8,16,8),segment(8,-16,8,16),segment(-16,-16,16,16),
    segment(0,0,0,0),segment(0,0,1e-6,1e-6),segment(-1e7,0,1e7,0)];
  let seed=731;const random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/2**32);
  for(let i=0;i<80;i++)segments.push(segment(random()*80-40,random()*80-40,random()*80-40,random()*80-40));
  const queries=[];
  for(const x of [-16,-8,0,8,16])for(const z of [-8,0,8])for(const r of [0,.52,.65,8])
    for(const epsilon of [-1e-10,0,1e-10])queries.push([x+r+epsilon,z,r]);
  for(let i=0;i<200;i++)queries.push([random()*100-50,random()*100-50,random()*4]);
  for(const [x,z,r] of queries){
    const candidates=wallCandidates(segments,x,z,r);
    const blocking=segments.filter(({a,b})=>distance(x,z,a,b)<r);
    assert.deepEqual(candidates.filter(({a,b})=>distance(x,z,a,b)<r),blocking);
    assert.deepEqual(candidates.map(s=>segments.indexOf(s)),[...new Set(candidates.map(s=>segments.indexOf(s)))].sort((a,b)=>a-b));
  }
  for(const q of [[NaN,0,1],[0,Infinity,1],[0,0,-1],[0,0,Infinity],[1e8,0,1],[0,0,1e5]])
    assert.equal(wallCandidates(segments,...q),segments);
});
function arena(){return {id:'tiny-wall-equivalence',bounds:{minX:-9,maxX:9,minZ:-9,maxZ:9},blocks:[],pickups:[],spawns:[[-6,-6],[6,6]],navNodes:[[0,-6],[0,6]],
  terrain:{surfaces:[{vertices:[[-10,0,-10],[-10,0,10],[10,0,10],[10,0,-10]]}],
    walls:[{a:[0,0,-4],b:[0,3,4]},{vertices:[[-8,0,-8],[-8,3,-4],[-4,3,-4]]}]}};}
test('actual original vs generated collision/height and walkEdge predicates match',()=>{
  const a=arena();
  for(const x of [-8,-.650000001,-.65,-.649999999,0,.519999999,.52,.520000001,8])
    for(const z of [-8,-4,0,4,8])for(const y of [-2,-1.8,-.000001,0,2.999999,3])
      for(const r of [.52,.65])assert.equal(optimized.obstructed(x,y,z,r,a),original.obstructed(x,y,z,r,a));
  const nodes=[];for(const x of [-6,-3,0,3,6])for(const z of [-6,0,6])nodes.push({x,y:0,z});
  for(const from of nodes)for(const to of nodes)assert.equal(optimized.walkEdge(from,to,a),original.walkEdge(from,to,a));
});
test('actual navigation nodes, ordered adjacency and nearest-node tie breaking remain exact',()=>{
  for(const nextGen of [false,true]){
    const a=arena();a.nextGen=nextGen;
    a.jumpLinks=[{source:{x:-6,y:0,z:-6},target:{x:6,y:0,z:6}}];
    const expected=original.navigation(a),actual=optimized.navigation(a);
    assert.ok(expected.nodes.length>3);assert.deepEqual(actual,expected);
    for(const p of [{x:0,y:0,z:0},{x:-3,y:0,z:3}])assert.equal(optimized.nearest(p,actual.nodes),original.nearest(p,expected.nodes));
    assert.deepEqual(optimized.navigation(a),expected,'warm index must preserve insertion order');
  }
});
test('terrain stamping replaces segment identity; cached broadphase follows invalidation',()=>{
  const a=arena(),before=terrainWallSegments(a.terrain);
  wallCandidates(before,0,0,.65);
  stampTerrainFloor(a.terrain,[[-2,-2],[2,-2],[2,2],[-2,2]],()=>0);
  const after=terrainWallSegments(a.terrain);assert.notEqual(after,before);
  for(const x of [-8,0,8])assert.equal(optimized.obstructed(x,0,0,.65,a),original.obstructed(x,0,0,.65,a));
});
test('spatial filter removes distant work, retaining long-segment fallback',()=>{
  const segments=Array.from({length:100},(_,i)=>segment(i*16,0,i*16+2,2));
  segments.push(segment(-1e7,0,1e7,0));
  assert.deepEqual(wallCandidates(segments,1,1,.65),[segments[0],segments[100]]);
});

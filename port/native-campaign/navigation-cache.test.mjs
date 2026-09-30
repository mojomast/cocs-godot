import test from 'node:test';
import assert from 'node:assert/strict';
import {createCampaignMatch,primeCampaignSourceNavigation} from './match.mjs';
import {floorAt as sourceFloorAt,walkEdge as sourceWalkEdge,navigation as sourceNavigation} from '../../game/core.mjs';
import {floorAt as generatedFloorAt,walkEdge as generatedWalkEdge} from './core.generated.mjs';
import {terrainTriangles} from '../../game/terrain.mjs';

function terrain(y=2) {return {surfaces:[{id:'floor',walkable:true,
  vertices:[[-12,y,-12],[-12,y,12],[12,y,12],[12,y,-12]],triangles:[[0,1,2],[0,2,3]]}],walls:[]};}
function envelope() {
  const point={x:-6,y:2,z:0,radius:3};
  return {id:'rootfall-verge',name:'Cache bridge fixture',geometryHash:'cache-fixture',
    arena:{id:'rootfall-verge',name:'Cache bridge fixture',nextGen:true,raised:false,
      bounds:{minX:-12,maxX:12,minZ:-12,maxZ:12},blocks:[],pickups:[],spawns:[[-6,0],[6,0]],
      navNodes:[],terrain:terrain()},
    campaign:{index:0,nextMapId:'siltwake-crossing',anchors:{start:{...point},exit:{...point},
      ...Object.fromEntries(Array.from({length:5},(_,i)=>[`encounter-${i+1}`,{...point,x:6}]))}}};
}
function trackTriangleReads(terrain) {
  let reads=0;
  for(const triangle of terrainTriangles(terrain)) {
    const vertices=triangle.vertices;
    Object.defineProperty(triangle,'vertices',{configurable:true,get(){reads++;return vertices;}});
  }
  return {get reads(){return reads;},reset(){reads=0;}};
}
function assertCachedAgreement(arena,height,tracker) {
  tracker.reset();
  for(const [x,z] of [[0,0],[-3,1],[4,-2]]) {
    assert.ok(Math.abs(sourceFloorAt(x,z,arena)-height)<1e-9);
    assert.ok(Math.abs(generatedFloorAt(x,z,arena)-height)<1e-9);
  }
  const a={x:-2,y:height,z:0},b={x:2,y:height,z:0};
  assert.equal(sourceWalkEdge(a,b,arena),true);
  assert.equal(generatedWalkEdge(a,b,arena),true);
  assert.equal(tracker.reads,0,'original and generated floor/walkEdge queries must use baked arrays, not terrain triangles');
}
test('generated campaign construction primes original bot floor queries and retries reuse the bridge',()=>{
  const data=envelope(),tracker=trackTriangleReads(data.arena.terrain);
  // Positive control proves this instrumentation sees the uncached source path.
  assert.equal(sourceFloorAt(0,0,data.arena),2);
  assert.ok(tracker.reads>0,'cold source query scans triangle vertices');
  const first=createCampaignMatch({mapData:data,random:()=>.5});
  assertCachedAgreement(data.arena,2,tracker);
  let graphBuildIterations=0;
  const authoredNodes=data.arena.navNodes;
  // objectiveTemplate also iterates this metadata on every construction. Count
  // only iterations originating in the pinned source navigation() implementation.
  Object.defineProperty(authoredNodes,Symbol.iterator,{configurable:true,value:function*(){
    if(/\bat navigation\b/.test(new Error().stack))graphBuildIterations++;
    yield* Array.prototype.values.call(this);
  }});
  assert.equal(primeCampaignSourceNavigation(data.arena),false,'same arena/surfaces is already primed');
  assert.equal(tracker.reads,0);
  const retry=createCampaignMatch({...first.campaignCheckpoint(),mapData:data,random:()=>.5});
  assert.equal(retry.arena,data.arena);
  assert.equal(graphBuildIterations,0,'retry must not rebuild either navigation graph');
  assert.equal(retry.nav,first.nav,'generated navigation graph identity is reused');
  assert.equal(retry.edges,first.edges,'generated graph edges are reused');
  assert.equal(tracker.reads,0,'retry construction must not rebuild a floor lattice');
  assertCachedAgreement(data.arena,2,tracker);
  sourceNavigation(data.arena);
  assert.equal(graphBuildIterations,1,'positive control detects an actual original-core graph rebuild');
});
test('new surfaces invalidate the bridge and a second arena with shared surfaces is independently primed',()=>{
  const data=envelope();createCampaignMatch({mapData:data,random:()=>.5});
  // Replacing the terrain gives its triangle cache a new identity as well as
  // changing surfaces. This is the supported immutable geometry-edit path.
  data.arena.terrain=terrain(3);
  const tracker=trackTriangleReads(data.arena.terrain);
  assert.equal(sourceFloorAt(0,0,data.arena),3);assert.ok(tracker.reads>0);
  assert.equal(primeCampaignSourceNavigation(data.arena),true);
  createCampaignMatch({mapData:data,random:()=>.5});
  assertCachedAgreement(data.arena,3,tracker);
  // Same terrain object/surfaces, different arena: core caches are arena-keyed.
  const other={...data,arena:{...data.arena,id:'cache-other-arena'}};
  tracker.reset();assert.equal(sourceFloorAt(0,0,other.arena),3);assert.ok(tracker.reads>0);
  assert.equal(primeCampaignSourceNavigation(other.arena),true);
  createCampaignMatch({mapData:other,random:()=>.5});
  assertCachedAgreement(other.arena,3,tracker);
  // A surfaces-only identity replacement also invalidates the memoized bridge.
  data.arena.terrain.surfaces=[...data.arena.terrain.surfaces];
  assert.equal(primeCampaignSourceNavigation(data.arena),true);
  assert.equal(primeCampaignSourceNavigation(data.arena),false);
});

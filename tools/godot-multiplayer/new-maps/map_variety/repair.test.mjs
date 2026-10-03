import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {portalFailures, stackedPlayableFailures, navConnectivity, canonicalGeometryHash} from './variety_lib.mjs';
import {traceRoute, auditPhysicalRoutes, physicalIndex, standingFailure} from './navigation_audit.mjs';
import {makeRecipe as helixBase} from '../helix-conservatory/recipe-v2.mjs';
import {recipe as vesperBase} from '../vesper-viaduct/recipe.mjs';

const root=new URL('../../../../',import.meta.url);
const read=path=>JSON.parse(readFileSync(new URL(path,root)));
const authority=(id,revision)=>read(`port/new-maps/${id}/variety/${revision}/authority.json`);
const helix=authority('helix-conservatory','revision-3'),parallax=authority('parallax-observatory','districts-v3'),vesper=authority('vesper-viaduct','urban-v2');
const flat=(id,y,x0=-10,x1=10,z0=-10,z1=10)=>({id,material:'m',walkable:true,vertices:[[x0,y,z0],[x0,y,z1],[x1,y,z1],[x1,y,z0]],triangles:[[0,1,2],[0,2,3]]});
const wall={id:'blocked',material:'m',vertices:[[0,0,-5],[0,4,-5],[0,4,5]]};
const wall2={...wall,vertices:[[0,0,-5],[0,4,5],[0,0,5]]};

test('two-component portal directions detect a real obstruction; malformed rays fail closed',()=>{
  const arena={terrain:{walls:[wall,wall2]}};
  for(const dir of [[1,0],[1,0,0],[NaN,0],[0,0],[1,0,undefined]]){
    const failures=[];portalFailures(arena,[{id:'fixture',at:[-1,0,0],dir,width:2,depth:3}],failures);
    assert.ok(failures.length,JSON.stringify(dir));
  }
  const clear=[];portalFailures({terrain:{walls:[]}},[{id:'open',at:[-1,0,0],dir:[1,0],width:2,depth:3}],clear);assert.deepEqual(clear,[]);
});

test('continuous route and graph reject an intervening wall despite clear endpoints',()=>{
  const arena={terrain:{maxSlope:.7,surfaces:[flat('floor',0)],walls:[wall,wall2]},navNodes:[{x:-2,z:0},{x:2,z:0}]};
  assert.ok(traceRoute(arena,[[-2,0],[2,0]]).some(f=>f.reason.startsWith('wall:')));
  assert.equal(navConnectivity(arena).connected,1);
});

test('route evidence rejects discontinuous support, low headroom and wrong intended height',()=>{
  const arena={terrain:{maxSlope:.7,surfaces:[flat('floor',0),flat('raised',2,0,10)],walls:[]}};
  assert.ok(traceRoute(arena,[[-2,0],[2,0]]).some(f=>f.reason==='height-discontinuity'));
  const low={terrain:{maxSlope:.7,surfaces:[flat('floor',0)],walls:[]},overhead:[{id:'roof',x:0,z:0,w:5,d:5,minY:1.5,maxY:2}]};
  assert.ok(traceRoute(low,[[-2,0],[2,0]]).some(f=>f.reason==='box:roof'));
  const wrong={terrain:{maxSlope:.7,surfaces:[flat('floor',12)],walls:[]}};
  assert.ok(traceRoute(wrong,[{x:-2,z:0,y:8},{x:2,z:0,y:8}]).some(f=>f.reason==='intended-height'));
});

test('stacked authored node heights are retained rather than overwritten by highest support',()=>{
  const failures=[];stackedPlayableFailures({terrain:{surfaces:[flat('high',12)],walls:[]},navNodes:[{x:0,z:0,y:8},{x:0,z:0,y:12}]},failures);
  assert.equal(failures.length,1);
});

test('Parallax well genuinely descends 12 to 8; restoring the old covering floor fails',()=>{
  const a=parallax.arena,index=physicalIndex(a);
  for(const [x,y] of [[44,12],[40,10],[36,8],[34,8],[32,8]])assert.ok(Math.abs(index.support(x,-34).y-y)<1e-7);
  const route=a.routes.find(r=>r.id==='lightwell-stair');assert.deepEqual(traceRoute(a,route.points),[]);
  const old=structuredClone(a);old.terrain.surfaces.push(flat('old-cover',12,22,46,-46,-1));
  assert.ok(traceRoute(old,route.points).some(f=>f.reason==='intended-height'));
});

test('Vesper roof connects to upper district; accepted civic stair heights remain exact',()=>{
  const a=vesper.arena,index=physicalIndex(a),base=physicalIndex(vesperBase());
  for(const id of ['roof-access-ramp','roof-terrace-loop'])assert.deepEqual(traceRoute(a,a.routes.find(r=>r.id===id).points),[]);
  assert.ok(Math.abs(index.support(18,53.1).y-(22+1/7))<1e-6);
  for(let z=25.25;z<65;z+=.5)assert.equal(index.support(32,z).y,base.support(32,z).y);
  assert.equal(index.support(18,45).y,22);
});

test('all old and new route corridors, spawn/objective heights and candidate hashes are preserved/validated',()=>{
  const p=read('godot/multiplayer_worlds/generated/parallax-observatory.json');
  for(const [data,base] of [[helix,helixBase()],[parallax,{...p.arena,routes:p.routes}],[vesper,vesperBase()]]) {
    const a=data.arena,result=auditPhysicalRoutes(a,base);
    assert.deepEqual(result.failures,[]);assert.deepEqual(result.baselineDefects,[]);
    assert.equal(canonicalGeometryHash(a),data.geometryHash);
    const after=physicalIndex(a),before=physicalIndex(base);
    const points=[...a.spawns,...a.objectiveZones,...Object.values(a.teamSpawns??{}).flat(),...Object.values(a.flagSpawns??{})];
    for(const point of points){const [x,z]=Array.isArray(point)?point:[point.x,point.z];const y=after.support(x,z).y;assert.ok(Math.abs(y-before.support(x,z).y)<1e-6);assert.equal(standingFailure(a,x,z,y),null);}
    const graph=navConnectivity(a);assert.equal(graph.connected,graph.nodes);
    assert.ok(a.terrain.walls.some(w=>w.renderSource==='kit'));
  }
});

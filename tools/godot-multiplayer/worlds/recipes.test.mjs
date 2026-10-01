import assert from 'node:assert/strict';
import test from 'node:test';
import {floorAt,navigation,obstructed,walkEdge} from '../../../game/core.mjs';
import {validateMapSchema,validateLattice} from '../../../game/map-schema.mjs';
import {WORLD_RECIPES} from './recipes.mjs';

const find=id=>WORLD_RECIPES.find(m=>m.id===id);
const clear=(m,x,z,r=.6)=>{
  const y=floorAt(x,z,m);
  return y!==null&&!obstructed(x,y,z,r,m);
};
test('all authored marker families have source-compatible geometry and clear ground',()=>{
  for(const m of WORLD_RECIPES){
    assert.deepEqual(validateMapSchema(m),[],m.id);
    const markers=[...m.spawns,...(m.vehicles??[]),...m.objectiveZones,...(m.flagSpawns?Object.values(m.flagSpawns):[]),
      ...(m.nodes??[]),...(m.depots??[]),...(m.terminals??[])];
    for(const p of markers){const x=Array.isArray(p)?p[0]:p.x,z=Array.isArray(p)?p[1]:p.z;
      assert.ok(clear(m,x,z),`${m.id}: marker (${x}, ${z}) must have unobstructed floor`);
    }
  }
});

test('each infantry route is continuously walkable under the source movement rules',()=>{
  for(const m of WORLD_RECIPES.filter(m=>m.id!=='sirocco-circuit'))for(const route of m.routes){
    let previous=null;
    for(let i=1;i<route.points.length;i++){
      const [ax,az]=route.points[i-1],[bx,bz]=route.points[i],count=Math.ceil(Math.hypot(bx-ax,bz-az)/1.5);
      for(let k=0;k<=count;k++){
        const x=ax+(bx-ax)*k/count,z=az+(bz-az)*k/count,p={x,y:floorAt(x,z,m),z};
        assert.ok(clear(m,x,z),`${m.id}/${route.id}: obstruction at ${x},${z}`);
        if(previous)assert.ok(walkEdge(previous,p,m),`${m.id}/${route.id}: impassable ${previous.x},${previous.z} -> ${x},${z}`);
        previous=p;
      }
    }
  }
});

test('race checkpoints form a valid loop and grid/boxes stay on the driving ribbon',()=>{
  const m=find('sirocco-circuit'),r=m.race;
  assert.equal(r.gates.length,r.centerline.length);
  for(const g of [...r.gates,...r.grid,...r.itemBoxes,...r.boostPads,...r.coins]){
    assert.ok(clear(m,g.x,g.z,1),`race marker (${g.x},${g.z}) collides`);
  }
  for(let i=0;i<r.centerline.length;i++){
    const a=r.centerline[i],b=r.centerline[(i+1)%r.centerline.length];
    assert.ok(Math.hypot(a.x-b.x,a.z-b.z)>12,'nondegenerate checkpoint segment');
    const count=Math.ceil(Math.hypot(a.x-b.x,a.z-b.z));
    for(let j=0;j<=count;j++){
      const x=a.x+(b.x-a.x)*j/count,z=a.z+(b.z-a.z)*j/count;
      assert.ok(clear(m,x,z,2.2),`Puma footprint blocked at gate segment ${i}, ${j}`);
    }
  }
});

test('freight and archipelago vehicle corridors have a continuous Puma footprint',()=>{
  for(const m of [find('breakwater-exchange'),find('tern-archipelago')]){
    const paths=m.id==='breakwater-exchange'?[m.payloadPath.map(p=>[p.x,p.z])]:[m.lanes[0].waypoints];
    for(const path of paths)for(let i=1;i<path.length;i++){
      const a=path[i-1],b=path[i],count=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1]));
      for(let j=0;j<=count;j++){
        const x=a[0]+(b[0]-a[0])*j/count,z=a[1]+(b[1]-a[1])*j/count;
        assert.ok(clear(m,x,z,2.2),`${m.id}: Puma footprint blocked at ${x},${z}`);
      }
    }
  }
});

test('soccer is symmetric, with clear net pockets, ball and kickoff positions',()=>{
  const m=find('copper-bowl'),r=m.race;
  assert.equal(r.kind,'soccer');
  assert.deepEqual(r.pitch,{minX:-47,maxX:47,minZ:-27,maxZ:27});
  for(const s of [-1,1])for(const z of [-4,0,4])assert.ok(clear(m,s*49,z,1.1),`goal pocket ${s},${z}`);
  assert.ok(clear(m,0,0,1.1));
  for(const v of m.vehicles)assert.ok(clear(m,v.x,v.z,2));
});

test('archipelago preserves source Lattice topology and reachable mandatory sockets',()=>{
  const m=find('tern-archipelago');
  assert.deepEqual(validateLattice(m),[]);
  assert.equal(m.nodes.length,7);assert.equal(m.nodes.filter(n=>n.archetype!=='hq').length,5);
  for(const [a,b] of m.lattice)assert.ok(m.nodes.some(n=>n.id===a)&&m.nodes.some(n=>n.id===b));
  const edges=new Map(m.nodes.map(n=>[n.id,[]]));
  for(const [a,b] of m.lattice){edges.get(a).push(b);edges.get(b).push(a);}
  const seen=new Set(['hq-0']),todo=['hq-0'];
  for(const id of todo)for(const next of edges.get(id))if(!seen.has(next)){seen.add(next);todo.push(next);}
  assert.equal(seen.size,7);
  for(const d of m.depots)assert.ok(m.routes.some(r=>r.points.some(([x,z])=>Math.hypot(x-d.x,z-d.z)<10)));
});

test('source bot navigation connects both teams to every mandatory capture and flag socket',()=>{
  for(const m of WORLD_RECIPES.filter(m=>m.teamSpawns&&m.id!=='copper-bowl')){
    const graph=navigation(m);
    const closest=p=>{
      const x=Array.isArray(p)?p[0]:p.x,z=Array.isArray(p)?p[1]:p.z;
      let best=-1,distance=Infinity;
      graph.nodes.forEach((n,i)=>{const d=Math.hypot(n.x-x,n.z-z);if(d<distance){best=i;distance=d;}});
      assert.ok(distance<3,`${m.id}: marker ${x},${z} is >3m from bot graph`);
      return best;
    };
    const targets=[...m.objectiveZones,...(m.nodes??[]),...Object.values(m.flagSpawns??{}),...(m.terminals??[])];
    for(const team of [0,1]){
      const start=closest(m.teamSpawns[team][0]),seen=new Set([start]),queue=[start];
      for(const i of queue)for(const j of graph.edges[i])if(!seen.has(j)){seen.add(j);queue.push(j);}
      for(const p of targets)assert.ok(seen.has(closest(p)),`${m.id}: team ${team} cannot path to ${p.id??p.label??JSON.stringify(p)}`);
    }
  }
});

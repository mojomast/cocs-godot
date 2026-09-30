import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {CAMPAIGN_MAP_IDS,loadCampaignMap,parseCampaignMap,campaignSupportAt} from '../../port/native-campaign/maps.mjs';
import {compileCampaign,routeLength} from './compile.mjs';
import {terrainSupportAt} from '../../game/terrain.mjs';
import {moveActor,floorAt} from '../../game/core.mjs';
import {RULES} from '../../game/data.mjs';
import {nativeArenaGeometryHash} from '../../port/native-arenas/schema.mjs';

// A coarse walking-only shortest path estimate through mandatory anchor disks.
// Edges sample the complete swept segment, including cover and cliff slopes.
// This is intentionally labelled a grid estimate, not a speedrun lower bound.
export function gateRouteMetrics(data,step=4) {
  const a=data.arena,b=a.bounds,cols=(b.maxX-b.minX)/step,rows=(b.maxZ-b.minZ)/step,nodes=[];
  const walk=(x,z)=>{const s=campaignSupportAt(a,x,z);return s&&!a.blocks.some(v=>Math.abs(x-v.x)<v.w/2+.65&&Math.abs(z-v.z)<v.d/2+.65&&v.h>s.y+.15&&v.baseY<s.y+1.8)?s.y:null;};
  for(let iz=0;iz<rows;iz++)for(let ix=0;ix<cols;ix++){const x=b.minX+(ix+.5)*step,z=b.minZ+(iz+.5)*step,y=walk(x,z);nodes.push(y===null?null:{x,y,z});}
  const adjacency=new Map();
  const edges=i=>{
    if(adjacency.has(i))return adjacency.get(i);
    const out=[],p=nodes[i];
    for(const [dx,dz]of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]) {
      const xx=i%cols+dx,zz=Math.floor(i/cols)+dz,j=zz*cols+xx,q=nodes[j];
      if(xx<0||xx>=cols||zz<0||zz>=rows||!q)continue;
      const distance=Math.hypot(q.x-p.x,q.z-p.z),count=Math.ceil(distance/.4);let previous=p.y,good=true;
      for(let k=1;k<=count;k++){const t=k/count,y=walk(p.x+(q.x-p.x)*t,p.z+(q.z-p.z)*t);if(y===null||Math.abs(y-previous)>Math.tan(a.terrain.maxSlope)*distance/count+.002){good=false;break;}previous=y;}
      if(good)out.push([j,Math.hypot(distance,q.y-p.y)]);
    }
    adjacency.set(i,out);return out;
  };
  const ordered=['start',...Array.from({length:5},(_,i)=>`encounter-${i+1}`),'exit'].map(k=>data.campaign.anchors[k]);
  const pools=ordered.map(p=>nodes.flatMap((v,i)=>v&&Math.hypot(v.x-p.x,v.z-p.z)<=p.radius?[i]:[]));
  assert.ok(pools.every(p=>p.length),'each gate has walkable grid samples');
  // Multi-source distance propagation carries the same arrival state across
  // gates (summing independent min pairs would underestimate the total route).
  let frontier=pools[0].map(i=>[i,0]);const cumulative=[];
  for(let leg=1;leg<pools.length;leg++) {
    const distances=new Float64Array(nodes.length).fill(Infinity),heap=[];
    const push=(entry)=>{heap.push(entry);let i=heap.length-1;while(i>0){const p=(i-1)>>1;if(heap[p][1]<=entry[1])break;heap[i]=heap[p];i=p;}heap[i]=entry;};
    const pop=()=>{const root=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let child=i*2+1;if(child+1<heap.length&&heap[child+1][1]<heap[child][1])child++;if(heap[child][1]>=last[1])break;heap[i]=heap[child];i=child;}heap[i]=last;}return root;};
    for(const [i,d]of frontier){distances[i]=d;push([i,d]);}
    while(heap.length){const [i,d]=pop();if(d>distances[i])continue;for(const [j,cost]of edges(i))if(d+cost<distances[j]){distances[j]=d+cost;push([j,d+cost]);}}
    frontier=pools[leg].filter(i=>Number.isFinite(distances[i])).map(i=>[i,distances[i]]);
    assert.ok(frontier.length,`${data.id}: gate ${leg} unreachable on ${step}m grid`);
    cumulative.push(Math.min(...frontier.map(p=>p[1])));
  }
  return {gridStep:step,orderedMeters:routeLength(data.campaign.criticalPath),gateWalkingMeters:cumulative.at(-1),gateCumulativeMeters:cumulative};
}

for(const [index,id] of CAMPAIGN_MAP_IDS.entries()) {
  test(`${id}: generated geometry, supported routes and chapter identity`,()=>{
    const data=loadCampaignMap(id),a=data.arena;
    assert.deepEqual(data,compileCampaign(id),'regenerate committed content');
    assert.equal(data.campaign.index,index);assert.equal(data.campaign.nextMapId,CAMPAIGN_MAP_IDS[index+1]??null);
    assert.equal(a.bounds.maxX-a.bounds.minX,320+index*32);
    assert.ok(routeLength(data.campaign.criticalPath)>=900&&routeLength(data.campaign.criticalPath)<=1500);
    assert.ok(a.terrain.surfaces.length<320);assert.ok(data.art.length<=1600);
    const ys=data.campaign.criticalPath.map(p=>p.y);assert.ok(Math.max(...ys)-Math.min(...ys)>8,'walkable elevation, not flat arena');
    // Independent source triangle reader cross-checks both diagonal halves,
    // off-grid points, bounds and every explicit deployment/anchor position.
    const samples=[...Object.values(data.campaign.anchors),...data.spawnPoints,...data.routes.flatMap(r=>r.points.filter((_,i)=>i%13===0))];
    for(const p of samples){const source=terrainSupportAt(p.x,p.z,a.terrain,a.terrain.maxSlope);assert.ok(source,`unsupported ${JSON.stringify(p)}`);assert.ok(Math.abs(source.y-p.y)<.0001);assert.ok(Math.abs(source.y-campaignSupportAt(a,p.x,p.z).y)<1e-7);}
    for(let i=1;i<=5;i++){const p=data.campaign.anchors[`encounter-${i}`],loop=data.routes.find(r=>r.id===`encounter-${i}-supply-loop`);assert.ok(loop);assert.ok(routeLength(loop.points)>100);assert.ok(a.pickups.filter(q=>Math.hypot(q[1]-p.x,q[2]-p.z)<30).length>=3);assert.ok(a.blocks.filter(q=>q.id.startsWith(`fight-${i}-`)).length>=4);}
  });
  test(`${id}: actual source movement traverses every critical and flank segment`,()=>{
    const data=loadCampaignMap(id),arena=data.arena;
    for(const route of data.routes) {
      const start=route.points[0],actor={...start,vx:0,vy:0,vz:0,moveSpeed:8,grounded:true,coyote:0,jumpBuffer:0};
      for(let i=1;i<route.points.length;i++) {
        const target=route.points[i];let steps=0;
        while(Math.hypot(actor.x-target.x,actor.z-target.z)>.20&&steps++<180){const dx=target.x-actor.x,dz=target.z-actor.z,d=Math.hypot(dx,dz);moveActor(actor,{x:dx/d,z:dz/d},RULES.dt,arena);assert.ok(Number.isFinite(actor.y)&&actor.y>arena.voidY);}
        assert.ok(steps<180,`${id} ${route.id} blocked at waypoint ${i}: ${JSON.stringify(actor)} -> ${JSON.stringify(target)}`);
        const floor=floorAt(actor.x,actor.z,arena);assert.ok(floor!==null&&Math.abs(actor.y-floor)<.3,'source feet remain supported');
      }
    }
  });
  test(`${id}: mandatory gates cannot collapse into an open-ground diagonal`,()=>{
    const data=loadCampaignMap(id),metrics=gateRouteMetrics(data);
    console.log(`${id} gate route metrics ${JSON.stringify(metrics)}`);
    assert.ok(metrics.gateWalkingMeters>metrics.orderedMeters*.78,'ridge geography preserves route budget');
    assert.ok(metrics.gateWalkingMeters>900,'minimum mandatory walking distance');
  });
}

test('strict campaign parser rejects unsafe identity, geometry and unsupported content',()=>{
  const original=JSON.parse(readFileSync(new URL('../../godot/campaign/generated/rootfall-verge.json',import.meta.url)));
  const bad=mutate=>{const d=structuredClone(original);mutate(d);d.geometryHash=nativeArenaGeometryHash(d.arena);assert.throws(()=>parseCampaignMap(d));};
  assert.throws(()=>loadCampaignMap('../rootfall-verge'));
  bad(d=>d.arena.bounds.maxX=300);bad(d=>d.arena.gravity=0);bad(d=>d.campaign.nextMapId=d.id);
  bad(d=>d.arena.terrain.surfaces[0].triangles[0].reverse());
  bad(d=>d.arena.terrain.surfaces[0].vertices[0][1]=Infinity);
  bad(d=>d.spawnPoints[0].y+=1);bad(d=>d.campaign.anchors['encounter-3'].x=255);
  bad(d=>d.routes[0].points[20].y+=.4);bad(d=>d.art[0].scale=[1000,1,1]);
  bad(d=>d.arena.terrain.surfaces.pop());
  const first=loadCampaignMap(CAMPAIGN_MAP_IDS[0]);first.arena.spawns[0][0]=999;
  assert.notEqual(loadCampaignMap(CAMPAIGN_MAP_IDS[0]).arena.spawns[0][0],999,'loads are independent');
});

test('chapters retain genuinely different normalized route footprints and exact handoffs',()=>{
  const data=CAMPAIGN_MAP_IDS.map(loadCampaignMap);
  const footprints=data.map(d=>{const b=d.arena.bounds;return new Set(d.campaign.criticalPath.map(p=>`${Math.floor((p.x-b.minX)/(b.maxX-b.minX)*20)},${Math.floor((p.z-b.minZ)/(b.maxZ-b.minZ)*20)}`));});
  for(let i=0;i<data.length;i++){
    if(i<3)assert.equal(data[i].campaign.anchors.exit.y,data[i+1].campaign.anchors.start.y,'exact chapter seam elevation');
    for(let j=i+1;j<data.length;j++){
      const common=[...footprints[i]].filter(k=>footprints[j].has(k)).length,union=new Set([...footprints[i],...footprints[j]]).size;
      assert.ok(common/union<.55,`${data[i].id}/${data[j].id} rescaled footprints too similar: ${common/union}`);
    }
  }
});

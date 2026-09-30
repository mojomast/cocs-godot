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

// Signal metrics operate on sampled geometry, not generator parameters. A
// repeated sawtooth has high discrete curvature and frequent prominent slope
// reversals; a broad bench or isolated cliff break does not. Test the detector
// on synthetic counterexamples as well as the generated route-side profiles.
export function profileMetrics(values) {
  let slopeEnergy=0,curvatureEnergy=0,teeth=0;
  for(let i=1;i<values.length;i++)slopeEnergy+=(values[i]-values[i-1])**2;
  for(let i=1;i<values.length-1;i++){
    const left=values[i]-values[i-1],right=values[i+1]-values[i];
    curvatureEnergy+=(right-left)**2;
    if(left*right<0&&Math.min(Math.abs(left),Math.abs(right))>.55)teeth++;
  }
  return {roughness:slopeEnergy>1e-6?curvatureEnergy/slopeEnergy:0,toothRate:teeth/Math.max(1,values.length-2)};
}

export function terrainVarietyMetrics(data) {
  const a=data.arena,unrestricted={...a,terrain:{...a.terrain,maxSlope:Math.PI/2}},path=data.campaign.criticalPath;
  const profiles=[],clearances=[];
  for(const offset of [-32,-24,24,32]) {
    let values=[],previousDirection=null;
    const flush=()=>{if(values.length>=10)profiles.push(profileMetrics(values));values=[];};
    for(let i=1;i<path.length-1;i++) {
      const p=path[i],q=path[i+1],dx=q.x-p.x,dz=q.z-p.z,d=Math.hypot(dx,dz),direction=[dx/d,dz/d];
      const nearFight=Object.values(data.campaign.anchors).some(v=>Math.hypot(v.x-p.x,v.z-p.z)<32);
      if(nearFight||previousDirection&&direction[0]*previousDirection[0]+direction[1]*previousDirection[1]<.995)flush();
      previousDirection=direction;
      if(nearFight)continue;
      const side=campaignSupportAt(unrestricted,p.x-direction[1]*offset,p.z+direction[0]*offset);
      if(!side){flush();continue;}
      const clearance=side.y-p.y;values.push(clearance);
      if(Math.abs(offset)===32)clearances.push(clearance);
    }
    flush();
  }
  const percentile=(v,t)=>v.slice().sort((a,b)=>a-b)[Math.floor((v.length-1)*t)];
  return {profiles:profiles.length,roughness90:percentile(profiles.map(p=>p.roughness),.90),toothRate90:percentile(profiles.map(p=>p.toothRate),.90),ridgeRelief80:percentile(clearances,.90)-percentile(clearances,.10)};
}

test('terrain profile detector rejects repeated teeth but permits broad irregular relief',()=>{
  const teeth=Array.from({length:80},(_,i)=>i%2?14:18);
  const varied=Array.from({length:80},(_,i)=>8+13*Math.exp(-(((i-21)/17)**2))+6*Math.exp(-(((i-63)/9)**2)));
  assert.ok(profileMetrics(teeth).roughness>3&&profileMetrics(teeth).toothRate>.9);
  assert.ok(profileMetrics(varied).roughness<.1&&profileMetrics(varied).toothRate===0);
  const bench=profileMetrics(Array.from({length:80},(_,i)=>i<40?5:17));
  assert.ok(bench.roughness>1&&bench.toothRate===0,'an isolated geological step is not repeated teeth');
});

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
  test(`${id}: route-side ridge geometry avoids repeated teeth and has broad relief variety`,()=>{
    const metrics=terrainVarietyMetrics(loadCampaignMap(id));
    console.log(`${id} terrain variety ${JSON.stringify(metrics)}`);
    if(process.env.CAMPAIGN_TERRAIN_BASELINE){const before=JSON.parse(readFileSync(`${process.env.CAMPAIGN_TERRAIN_BASELINE}/${id}.json`));console.log(`${id} before terrain variety ${JSON.stringify(terrainVarietyMetrics(before))}`);}
    assert.ok(metrics.profiles>=8,'sample enough actual non-combat ridge profiles');
    assert.ok(metrics.roughness90<.9||metrics.toothRate90<.12,'short-period alternating wall geometry (isolated bench breaks are allowed)');
    assert.ok(metrics.toothRate90<.18,'repeated prominent teeth along player-height ridge views');
    assert.ok(metrics.ridgeRelief80>12,'varied ridge setbacks/heights, not a constant-height trench or featureless mound');
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

test('Crown guardian authored deployment pool retains several clear 1.65m-radius feet positions',()=>{
  const data=loadCampaignMap('crown-array'),a=data.arena,pool=data.spawnPoints.slice(17,21),radius=1.65;
  const clear=p=>{
    if(a.blocks.some(b=>Math.abs(p.x-b.x)<b.w/2+radius&&Math.abs(p.z-b.z)<b.d/2+radius&&p.y<b.h))return false;
    for(let i=0;i<16;i++){const angle=i*Math.PI/8,s=campaignSupportAt(a,p.x+Math.cos(angle)*radius,p.z+Math.sin(angle)*radius);if(!s||Math.abs(s.y-p.y)>.3)return false;}
    return true;
  };
  assert.ok(pool.filter(clear).length>=3,`only ${pool.filter(clear).length}/4 authored guardian positions have large-body clearance`);
});

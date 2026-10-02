// Pure route construction and source clearance, never an authority simulation.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {interludeDefinitions} from '../../../port/native-campaign/interlude-definitions.mjs';
import {floorAt,obstructed} from '../../../port/native-campaign/core.generated.mjs';
import {ROBOTS,robotHitVolume} from '../../../port/native-campaign/enemies.mjs';
export const sha=b=>createHash('sha256').update(b).digest('hex');
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
export function planJourney(data,catalog,sourceBytes){
 const chapter=catalog.chapters[data.id];assert.ok(chapter);
 assert.equal(chapter.recipeSha256,sha(sourceBytes));assert.equal(chapter.geometryHash,data.geometryHash);
 assert.equal(chapter.placements.length,3);assert.equal(new Set(chapter.placements.map(p=>p.asset)).size,3);
 const path=data.campaign.criticalPath,stages=[],visited=[path[0]];
 const nearest=p=>path.reduce((best,q,i)=>distance(q,p)<distance(path[best],p)?i:best,0);
 let cursor=0,step=0;
 function travel(points,label){for(const p of points){stages.push({kind:'walk',point:p,label});visited.push(p);}}
 function mainTo(point,label){const end=nearest(point);assert.ok(end>=cursor,'Route order');travel(path.slice(cursor+1,end+1),label);cursor=end;}
 for(const def of interludeDefinitions(data)){
  while(step<def.step){const anchor=data.campaign.anchors[`encounter-${step+1}`];mainTo(anchor,'mission-approach');travel([anchor],'mission-anchor');stages.push({kind:'encounter',step:++step,point:anchor});}
  mainTo(def.entry,'workshop-approach');
  const route=s=>data.routes.find(r=>r.id===`interlude-${def.id}-${s}`).points;
  travel(route('a'),'workshop-'+def.id);
  stages.push({kind:'interact',id:def.id,stage:def.family==='link'?1:2,look:def.family==='align'?def.b:null});
  if(def.family==='link'){travel(route('link'),'workshop-link');stages.push({kind:'interact',id:def.id,stage:2,look:null});}
  travel([...route(def.family==='link'?'b':'a')].reverse(),'workshop-return');
 }
 // Walk the same connected path back, with no pose write or checkpoint restart.
 travel([...visited].reverse(),'spawn-return');
 let samples=0,previous=path[0];
 for(const stage of stages)if(stage.kind==='walk'){
  const p=stage.point,n=Math.max(1,Math.ceil(distance(previous,p)/.5));
  for(let i=1;i<=n;i++){const t=i/n,x=previous.x+(p.x-previous.x)*t,z=previous.z+(p.z-previous.z)*t,y=floorAt(x,z,data.arena);
   assert.ok(Number.isFinite(y)&&!obstructed(x,y,z,.45,data.arena),`Source route blocked ${data.id}/${stage.label}/${x},${z}`);samples++;}
  previous=p;
 }
 return {id:data.id,geometryHash:data.geometryHash,sourceSha:sha(sourceBytes),recipeHash:catalog.recipeSha256,assets:chapter.placements.map(p=>p.asset),workshops:interludeDefinitions(data).map(d=>d.id),hitVolumes:Object.fromEntries(Object.keys(ROBOTS).map(id=>[id,robotHitVolume(id)])),start:path[0],stages,clearanceSamples:samples};
}

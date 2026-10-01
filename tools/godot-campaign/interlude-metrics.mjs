import {execFileSync} from 'node:child_process';
import {CAMPAIGN_MAP_IDS,loadCampaignMap} from '../../port/native-campaign/maps.mjs';
import {interludeDefinitions} from '../../port/native-campaign/interlude-definitions.mjs';

const length=points=>points.slice(1).reduce((n,p,i)=>n+Math.hypot(p.x-points[i].x,p.y-points[i].y,p.z-points[i].z),0);
const round=n=>+n.toFixed(2);
export function pacingMetrics(data,withInterludes=true){
  const path=data.campaign.criticalPath,cumulative=[0];
  for(let i=1;i<path.length;i++)cumulative.push(cumulative.at(-1)+length([path[i-1],path[i]]));
  const at=p=>{let best=0;path.forEach((q,i)=>{if(Math.hypot(q.x-p.x,q.z-p.z)<Math.hypot(path[best].x-p.x,path[best].z-p.z))best=i;});return cumulative[best];};
  const anchors=Array.from({length:5},(_,i)=>at(data.campaign.anchors[`encounter-${i+1}`]));
  const beats=withInterludes?interludeDefinitions(data).map(b=>{
    const route=s=>data.routes.find(r=>r.id===`interlude-${b.id}-${s}`).points;
    const optionalMeters=length(route('a'))+length(route('link'))+length(route('b'));
    const bypassMeters=Math.abs(at(route('b')[0])-at(route('a')[0]));
    return {id:b.id,family:b.family,afterEncounter:b.step,entryArc:round(at(b.entry)),
      optionalLoopMeters:round(optionalMeters),bypassMeters:round(bypassMeters),addedLoopMeters:round(optionalMeters-bypassMeters),
      walkingOnlySecondsAt8mps:round(optionalMeters/8),forcedWaitSeconds:0};
  }):[];
  const legs=anchors.slice(1).map((end,i)=>{
    const start=anchors[i],activity=beats.find(b=>b.afterEncounter===i+1);
    // Route-arc estimate, not a speedrun or human duration claim: combat is
    // considered over at the old center, deployment starts ~36m before next.
    const transit=Math.max(0,end-start-36);
    return {fromEncounter:i+1,toEncounter:i+2,anchorArcMeters:round(end-start),
      transitToDeploymentMeters:round(transit),activity:activity?.id??null,
      largestUninterruptedTransitMeters:round(activity?Math.max(activity.entryArc-start,end-36-activity.entryArc):transit)};
  });
  return {orderedMeters:round(cumulative.at(-1)),beats,legs,
    totalTransitToDeploymentMeters:round(legs.reduce((n,l)=>n+l.transitToDeploymentMeters,0)),
    largestUninterruptedTransitMeters:Math.max(...legs.map(l=>l.largestUninterruptedTransitMeters))};
}

const beforeRef=process.argv[2]??'f426e755';
const report=CAMPAIGN_MAP_IDS.map(id=>{
  const before=JSON.parse(execFileSync('git',['show',`${beforeRef}:godot/campaign/generated/${id}.json`],{maxBuffer:16*1024*1024}));
  return {id,before:pacingMetrics(before,false),after:pacingMetrics(loadCampaignMap(id))};
});
console.log(JSON.stringify({method:'Reviewed critical-path arclength; next fight deploy radius 36m. Optional loops walk-only at assumed 8m/s; exclude decision/looking time. Largest gap includes untreated legs. Not measured human pacing.',report},null,2));

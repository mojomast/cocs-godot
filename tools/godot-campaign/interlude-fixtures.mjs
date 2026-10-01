// Produce wire snapshots by applying real source controls, for native replay.
import {writeFileSync} from 'node:fs';
import {CAMPAIGN_MAP_IDS,loadCampaignMap} from '../../port/native-campaign/maps.mjs';
import {interludeDefinitions} from '../../port/native-campaign/interlude-definitions.mjs';
import {createCampaignMatch} from '../../port/native-campaign/match.mjs';
const frames=[];
for(const mapId of CAMPAIGN_MAP_IDS){
  const data=loadCampaignMap(mapId);
  for(const def of interludeDefinitions(data)){
    const match=createCampaignMatch({mapId,mapData:data,checkpoint:def.step,checkpointPoint:def.entry,random:()=>.5});
    const tick=(input={})=>match.step(1/60,{inputs:{0:input}});
    const walk=points=>{for(const p of points){let n=0;
      while(Math.hypot(p.x-match.actors[0].x,p.z-match.actors[0].z)>.35&&n++<240){
        const a=match.actors[0],d=Math.hypot(p.x-a.x,p.z-a.z);tick({x:(p.x-a.x)/d,z:(p.z-a.z)/d});
      }if(n>=240)throw Error(`Native fixture walk blocked: ${def.id}`);
    }};
    walk(data.routes.find(r=>r.id===`interlude-${def.id}-a`).points);tick();
    const before=match.snapshot().campaign;
    const a=match.actors[0];tick({interact:true,yaw:Math.atan2(-(def.b.x-a.x),-(def.b.z-a.z))});
    const linked=match.snapshot().campaign;
    if(def.family==='link'){walk(def.cable);tick();tick({interact:true});}
    const after=match.snapshot().campaign;
    if(!after.interludes.beats.find(b=>b.id===def.id).completed)throw Error(`Incomplete fixture: ${def.id}`);
    frames.push({mapId,geometryHash:data.geometryHash,id:def.id,before,linked,after});
  }
}
writeFileSync(process.argv[2],JSON.stringify(frames,null,2)+'\n');
console.log(`Wrote ${frames.length} source-controlled workshop fixtures`);

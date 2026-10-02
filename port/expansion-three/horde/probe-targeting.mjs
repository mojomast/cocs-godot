#!/usr/bin/env node
// Focused deterministic replay to one retained wave-nine decision, NOT a new
// completion attempt. Replays ordinary input/upgrade actions only, then stops.
import {readFileSync,mkdtempSync,writeFileSync} from 'node:fs';
import {createHordeMatch} from '../../native-horde/authority.mjs';
import {selectHordeUpgrade} from '../../../game/singleplayer.mjs';
import {parseInputEnvelope} from '../../../game/protocol.mjs';
import {readBlackwater} from '../../native-horde/blackwater-schema.mjs';
import {visible} from '../../../game/core.mjs';
const root='/home/mojo/.tmp-on-disk/cocs-expansion-three-horde-evidence-20261002';
const prior=`${root}/source-boss-UXBKiC`;
const result=JSON.parse(readFileSync(`${prior}/result.json`));
const rows=readFileSync(`${prior}/inputs-events.jsonl`,'utf8').trim().split('\n').map(JSON.parse);
let seed=0x20261002;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const match=createHordeMatch({mapId:'blackwater-reclamation',config:result.config,random});
let maxPositionError=0;
for(const row of rows){
 const state=match.snapshot(),player=state.actors.find(a=>a.id===0);
 if(row.position)maxPositionError=Math.max(maxPositionError,Math.hypot(player.x-row.position[0],player.y-row.position[1],player.z-row.position[2]));
 if(row.sourceTime>=552.11){
  const base=readBlackwater().arena,mask=state.singleplayer.stage.gateMask;
  const arena={...base,blocks:[...base.blocks,...base.hordeStagePlan.gates.filter((_,i)=>!(mask&(1<<i)))]};
  const enemies=state.actors.filter(a=>a.isNpc&&a.health>0).map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,health:a.health,npcType:a.npcType,
   distance:Math.hypot(a.x-player.x,a.z-player.z),visible:visible({x:player.x,y:player.y+1.45,z:player.z},{x:a.x,y:a.y+1.2,z:a.z},arena)})).sort((a,b)=>a.distance-b.distance);
  const report={level:'focused baseline input replay, not completion',sourceTime:state.time,tick:row.tick,maxPositionError,player:{x:player.x,y:player.y,z:player.z},mask,
   recordedInput:row.input,recordedRoute:row.route,enemies,oldTarget:enemies.find(e=>e.visible)?.id??enemies[0]?.id,
   rangeAwareTarget:enemies.find(e=>e.visible&&e.distance<65)?.id??enemies[0]?.id};
  const out=mkdtempSync(`${root}/target-probe-`);writeFileSync(`${out}/probe.json`,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({out,...report},null,2));break;
 }
 if(row.intent)selectHordeUpgrade(match,row.intent.choice);
 match.step(1/60,{inputs:{0:parseInputEnvelope({input:row.input})}});
}

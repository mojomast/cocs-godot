#!/usr/bin/env node
// Accelerated wall time, normal 1/60 source dt; no actor/director writes.
import {mkdirSync,mkdtempSync,createWriteStream,writeFileSync} from 'node:fs';
import {once} from 'node:events';
import {createHordeMatch,validateConfig,EventCursor} from '../../native-horde/authority.mjs';
import {selectHordeUpgrade} from '../../../game/singleplayer.mjs';
import {parseInputEnvelope} from '../../../game/protocol.mjs';
import {JourneyController} from './controller.mjs';
const goal=process.argv[2]??'chain';if(!['chain','boss'].includes(goal))throw Error('chain or boss required');
const root='/home/mojo/.tmp-on-disk/cocs-expansion-three-horde-evidence-20261002';mkdirSync(root,{recursive:true});
const out=mkdtempSync(`${root}/source-${goal}-`),log=createWriteStream(`${out}/inputs-events.jsonl`);
const config=validateConfig({mapId:'blackwater-reclamation',config:{mode:'horde',difficulty:'easy',fragLimit:10,timeLimit:900}});
// Reproducible RNG at construction only. No mutation after Match setup.
let seed=0x20261002;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
const match=createHordeMatch({mapId:'blackwater-reclamation',config,random});
const controller=new JourneyController(),cursor=new EventCursor(),events=[];
const evidence={goal,level:'automated source keyboard-state input; not native or human',normalDelta:1/60,acceleratedWallTime:true,wire:false,seed:'0x20261002',config,out,steps:0,passed:false};
const start=performance.now();let snapshot=match.snapshot();
try{
 for(let tick=0;tick<60*900;tick++){
  if(performance.now()-start>180000){evidence.reason='180s wall budget';break;}
  const command=controller.sample(snapshot);
  if(command.intent){const accepted=selectHordeUpgrade(match,command.intent.choice);events.push({type:'controller-upgrade',...command.intent,accepted});}
  const input=parseInputEnvelope({input:command.input});
  match.step(1/60,{inputs:{0:input}});evidence.steps++;
  snapshot=match.snapshot();const batch=cursor.take(match);events.push(...batch);
  if(!log.write(JSON.stringify({tick,sourceTime:snapshot.time,...command,events:batch})+'\n'))await once(log,'drain');
  const stations=snapshot.blackwater.completed.length===4;
  const gates=['B','C'].every(stage=>events.some(e=>e.type==='horde-stage-entered'&&e.stageId===stage));
  const warden=events.find(e=>e.type==='horde-warden-arrived');
  const defeated=warden&&snapshot.actors.some(a=>a.id===warden.actor&&a.health<=0);
  if(stations&&gates&&(goal==='chain'||defeated&&snapshot.singleplayer.phase==='won')){evidence.passed=true;evidence.reason='source-earned receipts';break;}
  if(snapshot.over){evidence.reason=snapshot.singleplayer.phase;break;}
 }
 evidence.reason??='900s source budget';
}catch(error){evidence.reason=String(error);evidence.stack=error.stack;}
finally{
 evidence.wallSeconds=(performance.now()-start)/1000;evidence.sourceSeconds=snapshot.time;
 evidence.final={player:snapshot.actors.find(a=>a.id===0),horde:snapshot.singleplayer,mission:snapshot.blackwater};
 evidence.events=events;writeFileSync(`${out}/result.json`,JSON.stringify(evidence,null,2)+'\n');
 await new Promise(resolve=>log.end(resolve));console.log(JSON.stringify({out,passed:evidence.passed,reason:evidence.reason,steps:evidence.steps,sourceSeconds:evidence.sourceSeconds,wallSeconds:evidence.wallSeconds,completed:snapshot.blackwater.completed,wave:snapshot.singleplayer.wave}));
 if(!evidence.passed)process.exitCode=1;
}

#!/usr/bin/env node
// EXCLUSIVE GODOT SLOT ONLY. Bounded ordinary native InputEvent fixture; do
// not invoke while another lane owns Godot. No debug channel, Match access,
// clock acceleration, fabricated snapshots, injected health or fake outcomes.
import {spawn} from 'node:child_process';
import {createWriteStream,mkdirSync,writeFileSync} from 'node:fs';
import {createAuthority} from './authority.mjs';

const goal=process.argv[2]??'chain';
if(!['chain','boss'].includes(goal))throw Error('Expected chain or boss');
const out='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/horde';
mkdirSync(out,{recursive:true});
const log=createWriteStream(`${out}/headless-${goal}.log`);
const binary=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const evidence={goal,normalClock:true,fixtureControls:'native InputEvent -> HordeControls.sample -> HordeClient.send_controls',
 debug:false,events:[],resetReasons:[],steps:0,appliedSamples:0,cancelledInputFrames:0,maxInputGapMs:0,
 lastInputAt:null,firstSourceTime:null,lastSourceTime:null};
const authority=createAuthority({debug:false,observe:record=>{
 if(record.direction==='in'&&record.frame?.type==='input'){
  if(record.frame.cancel===true)evidence.cancelledInputFrames++;
  if(evidence.lastInputAt!==null)evidence.maxInputGapMs=Math.max(evidence.maxInputGapMs,record.observedMs-evidence.lastInputAt);
  evidence.lastInputAt=record.observedMs;
 }
 if(record.direction==='control-reset')evidence.resetReasons.push({reason:record.reason,epoch:record.inputEpoch,at:record.observedMs});
 if(record.direction==='step'){
  evidence.steps++;
  if(record.inputSeq!==null)evidence.appliedSamples++;
  evidence.firstSourceTime??=record.sourceTime;
  evidence.lastSourceTime=record.sourceTime;
 }
 if(record.direction==='out'&&record.frame?.type==='events'){
  for(const item of record.frame.items??[]){
   if(['blackwater-station-armed','blackwater-station-restored','horde-resupply',
    'horde-gate-open','horde-gate-closed','horde-transit-begin','horde-stage-entered',
    'horde-transit-fallback','horde-warden-arrived','boss-phase','enemy-telegraph','boss-slam'].includes(item.type)){
    evidence.events.push({type:item.type,id:item.id,sourceTime:item.time,station:item.station,
     phase:item.phase,kind:item.kind,stageId:item.stageId,geometryRevision:item.geometryRevision});
   }
  }
 }
 if(record.direction==='transport-error')evidence.events.push({type:'transport-error',reason:record.reason});
}});
await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
let child,output='',code=null,timedOut=false;
const deadline=goal==='chain'?660000:800000;
try{
 const endpoint=`ws://127.0.0.1:${authority.server.address().port}`;
 const started=Date.now();
 child=spawn(binary,['--headless','--audio-driver','Dummy','--path','godot',
  'res://tests/horde/blackwater_headless.tscn','--',`--endpoint=${endpoint}`,
  '--map=blackwater-reclamation','--waves=10',`--goal=${goal}`],
 {env:{...process.env,BLACKWATER_HEADLESS_FIXTURE:'1',LP_NUM_THREADS:'1'}});
 child.stdout.on('data',part=>{output+=String(part);log.write(part)});
 child.stderr.on('data',part=>{output+=String(part);log.write(part)});
 const exit=new Promise(resolve=>child.once('exit',resolve));
 const timeout=new Promise(resolve=>setTimeout(()=>{timedOut=true;child.kill('SIGTERM');resolve(null)},deadline));
 code=await Promise.race([exit,timeout]);
 evidence.wallSeconds=(Date.now()-started)/1000;
 const line=output.split('\n').findLast(row=>row.startsWith('BLACKWATER_HEADLESS_DONE '));
 evidence.nativeDone=line?JSON.parse(line.slice('BLACKWATER_HEADLESS_DONE '.length)):null;
 evidence.engineErrors=output.split('\n').filter(row=>/SCRIPT ERROR|Parse Error|ERROR:/.test(row)).slice(0,30);
 evidence.code=code;evidence.timedOut=timedOut;
 evidence.passed=code===0&&!timedOut&&evidence.nativeDone?.ok===true&&!evidence.engineErrors.length&&
  evidence.steps>300&&evidence.appliedSamples>100&&evidence.resetReasons.every(row=>row.reason!=='stale-input')&&
  evidence.events.some(row=>row.type==='horde-stage-entered'&&row.stageId==='B')&&
  evidence.events.some(row=>row.type==='horde-stage-entered'&&row.stageId==='C')&&
  (!('boss'===goal)||evidence.events.some(row=>row.type==='boss-phase'&&row.phase===3));
 writeFileSync(`${out}/headless-${goal}.json`,JSON.stringify(evidence,null,2)+'\n');
 console.log('BLACKWATER_HEADLESS_RESULT '+JSON.stringify({goal,passed:evidence.passed,code,timedOut,
  wallSeconds:evidence.wallSeconds,sourceSeconds:(evidence.lastSourceTime??0)-(evidence.firstSourceTime??0),
  steps:evidence.steps,appliedSamples:evidence.appliedSamples,maxInputGapMs:evidence.maxInputGapMs,
  resets:evidence.resetReasons,nativeDone:evidence.nativeDone,errors:evidence.engineErrors}));
 if(!evidence.passed)process.exitCode=1;
}finally{
 if(child&&child.exitCode===null)child.kill('SIGTERM');
 await authority.close();
 await new Promise(resolve=>log.end(resolve));
}

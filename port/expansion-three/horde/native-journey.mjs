#!/usr/bin/env node
// EXPLICIT ENGINE GRANT REQUIRED. Normal wall clock, shipping source authority.
import {spawn} from 'node:child_process';
import {mkdirSync,mkdtempSync,createWriteStream,writeFileSync} from 'node:fs';
import {createAuthority} from '../../native-horde/authority.mjs';
const goal=process.argv[2]??'chain';if(!['chain','boss'].includes(goal))throw Error('chain or boss required');
const rendered=process.argv.includes('--rendered'),compact=process.argv.includes('--compact');
if(compact&&!rendered)throw Error('--compact requires --rendered');
const root='/home/mojo/.tmp-on-disk/cocs-expansion-three-horde-evidence-20261002';mkdirSync(root,{recursive:true});
const out=mkdtempSync(`${root}/native-${goal}-`),log=createWriteStream(`${out}/native.log`),wire=createWriteStream(`${out}/wire.jsonl`);
const result={out,goal,rendered,compact,normalClock:true,debug:false,events:[],resets:[],upgrades:[],steps:0,applied:0,maxInputGapMs:0,maxAck:0,errors:[],passed:false};
let lastInput=null,doneAt=null,epoch=null,child,timer,killTimer,output='';
const authority=createAuthority({debug:false,observe:r=>{
 if(r.direction==='in'&&r.frame?.type==='input'){
  if(epoch===r.frame.inputEpoch&&lastInput!==null)result.maxInputGapMs=Math.max(result.maxInputGapMs,r.observedMs-lastInput);
  epoch=r.frame.inputEpoch;lastInput=r.observedMs;
 }
 if(r.direction==='step'){result.steps++;if(r.inputSeq!==null)result.applied++;}
 if(r.direction==='control-reset')result.resets.push(r);
 if(r.direction==='upgrade-applied'||r.direction==='upgrade-reject')result.upgrades.push(r);
 if(r.direction==='out'&&r.frame?.type==='snapshot'){
  result.maxAck=Math.max(result.maxAck,r.frame.acks?.[0]??0);result.final=r.frame.state;
 }else wire.write(JSON.stringify(r)+'\n');
 if(r.direction==='out'&&r.frame?.type==='events')result.events.push(...r.frame.items);
}});
try{
 await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
 const env={...process.env,LP_NUM_THREADS:'1'};
 if(rendered)delete env.BLACKWATER_HEADLESS_FIXTURE;else env.BLACKWATER_HEADLESS_FIXTURE='1';
 child=spawn(process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64',
 [...(rendered?['--rendering-method','gl_compatibility','--windowed','--resolution',compact?'760x520':'1280x800']:['--headless']),
 '--audio-driver','Dummy','--path','godot','res://tests/horde_expansion/journey.tscn','--',`--endpoint=ws://127.0.0.1:${authority.server.address().port}`,'--map=blackwater-reclamation','--waves=10',`--goal=${goal}`,
 ...(rendered?[`--capture-directory=${out}/captures`]:[]),...(compact?['--compact']:[])],{env});
 const record=chunk=>{output+=String(chunk);log.write(chunk);if(doneAt===null&&output.includes('BLACKWATER_HEADLESS_DONE '))doneAt=performance.now();};
 child.stdout.on('data',record);child.stderr.on('data',record);
 timer=setTimeout(()=>{result.timedOut=true;child.kill('SIGTERM');killTimer=setTimeout(()=>child.kill('SIGKILL'),3000);},goal==='chain'?660000:950000);
 result.code=await new Promise((resolve,reject)=>{child.once('exit',resolve);child.once('error',reject);});
 const line=output.split('\n').findLast(s=>s.startsWith('BLACKWATER_HEADLESS_DONE '));
 result.native=line?JSON.parse(line.slice('BLACKWATER_HEADLESS_DONE '.length)):null;
 result.captures=output.split('\n').filter(s=>s.startsWith('BLACKWATER_CAPTURE ')).map(s=>JSON.parse(s.slice('BLACKWATER_CAPTURE '.length)));
 const video=result.captures.filter(c=>c.video&&c.error===0);
 if(video.length>1){
  const rows=['ffconcat version 1.0'];
  for(let i=0;i<video.length;i++){
   rows.push(`file 'captures/${video[i].file}'`);
   if(i+1<video.length)rows.push(`duration ${(video[i+1].wall_seconds-video[i].wall_seconds).toFixed(6)}`);
  }
  writeFileSync(`${out}/walkthrough.ffconcat`,rows.join('\n')+'\n');
  result.videoCadence={frames:video.length,wallSpan:video.at(-1).wall_seconds-video[0].wall_seconds,sourceSpan:video.at(-1).source_time-video[0].source_time,
   label:'first 60 wall seconds of automated input; variable measured capture cadence, not full mission footage'};
 }
 result.errors=output.split('\n').filter(s=>/SCRIPT ERROR|Parse Error|ERROR:/.test(s)&&!/RID allocations|resources still in use/.test(s));
 result.passed=result.code===0&&!result.timedOut&&result.native?.ok===true&&!result.errors.length&&
  result.maxInputGapMs<=250&&result.maxAck>100&&result.upgrades.some(r=>r.direction==='upgrade-applied')&&
  result.resets.every(r=>r.reason!=='stale-input'||doneAt!==null&&r.observedMs>=doneAt)&&
  ['north-feeder','south-feeder','switch-pump','relief-valve'].every(station=>result.events.some(e=>e.type==='blackwater-station-restored'&&e.station===station))&&
  ['B','C'].every(stage=>result.events.some(e=>e.type==='horde-stage-entered'&&e.stageId===stage))&&
  (goal!=='boss'||result.final?.singleplayer?.phase==='won')&&
  (!rendered||result.captures.length>0&&result.captures.every(c=>c.error===0));
}catch(error){result.errors.push(String(error));}
finally{
 clearTimeout(timer);clearTimeout(killTimer);if(child&&child.exitCode===null)child.kill('SIGKILL');
 await authority.close();await Promise.all([new Promise(r=>log.end(r)),new Promise(r=>wire.end(r))]);
 writeFileSync(`${out}/result.json`,JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({out,goal,passed:result.passed,maxInputGapMs:result.maxInputGapMs,maxAck:result.maxAck,upgrades:result.upgrades,native:result.native,errors:result.errors}));
 if(!result.passed)process.exitCode=1;
}

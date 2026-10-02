#!/usr/bin/env node
// Bounded actual transport contract probe. Replays at most ten seconds from
// an existing source-input trace. This is NOT mission completion or native input.
import {readFileSync,mkdirSync,mkdtempSync,writeFileSync} from 'node:fs';
import {WebSocket} from 'ws';
import {createAuthority} from '../../native-horde/authority.mjs';
const path=process.argv[2];if(!path)throw Error('source inputs-events.jsonl required');
const inputs=readFileSync(path,'utf8').trim().split('\n').slice(0,600).map(s=>JSON.parse(s).input);
const root='/home/mojo/.tmp-on-disk/cocs-expansion-three-horde-evidence-20261002';mkdirSync(root,{recursive:true});
const out=mkdtempSync(`${root}/wire-replay-`);
const report={out,trace:path,level:'bounded Node wire replay, not native or completion',flow:'at most two unacknowledged samples; no catch-up burst',maxGapMs:0,maxAck:0,resets:[],errors:[],steps:0,applied:0,sent:0};
let last=null,epoch=null,ws,timer,index=0,finish;
const done=new Promise(resolve=>finish=resolve);
const authority=createAuthority({debug:false,observe:r=>{
 if(r.direction==='in'&&r.frame?.type==='input'&&!r.frame.cancel){if(last!==null)report.maxGapMs=Math.max(report.maxGapMs,r.observedMs-last);last=r.observedMs;}
 if(r.direction==='control-reset')report.resets.push(r);
 if(r.direction==='transport-error'){report.errors.push(r.reason);finish();}
 if(r.direction==='step'){report.steps++;if(r.inputSeq!==null)report.applied++;}
}});
let deadline;
try{
 await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
 ws=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}`);
 const send=frame=>ws.send(JSON.stringify(frame));
 ws.on('error',error=>{report.errors.push(String(error));finish();});
 ws.on('open',()=>send({type:'create',v:3}));
 ws.on('message',raw=>{
  const f=JSON.parse(String(raw));
  if(f.type==='welcome')send({type:'host',mapId:'blackwater-reclamation',config:{mode:'horde',difficulty:'easy',fragLimit:10,timeLimit:900}});
  if(f.type==='lobby'&&f.config&&epoch===null){epoch=0;send({type:'start'});}
  if(f.type==='start'){
   epoch=f.inputEpoch;
   timer=setInterval(()=>{
    // Node truncates 1000/60 timers to 16ms. Bound outstanding work by actual
    // applied ACK, rather than building a 62.5Hz queue against a 60Hz source.
    if(report.sent-report.maxAck>=2)return;
    if(index<inputs.length){send({type:'input',inputEpoch:epoch,seq:++report.sent,input:inputs[index++]});}
    else {clearInterval(timer);send({type:'input',inputEpoch:epoch,seq:++report.sent,input:{},cancel:true});}
   },1000/60);
  }
  if(f.type==='horde-input-reset')epoch=f.inputEpoch;
  if(f.type==='snapshot'){
   report.maxAck=Math.max(report.maxAck,f.acks?.[0]??0);
   if(index===inputs.length&&report.maxAck>=inputs.length)finish();
  }
  if(f.type==='error'){report.errors.push(f.message);finish();}
 });
 deadline=setTimeout(()=>{report.errors.push('20s wall deadline');finish();},20000);
 await done;
}finally{
 clearInterval(timer);clearTimeout(deadline);ws?.terminate();await authority.close();
 report.passed=inputs.length>=100&&report.maxAck>=inputs.length&&report.applied>=100&&report.maxGapMs<=250&&!report.errors.length&&!report.resets.some(r=>r.reason==='stale-input');
 writeFileSync(`${out}/result.json`,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(!report.passed)process.exitCode=1;
}

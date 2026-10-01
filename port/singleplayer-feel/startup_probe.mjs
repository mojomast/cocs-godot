// External diagnostic only. Import the exact extracted package authority.
// --model-stall is Node-only. --run-native requires the owner's engine grant.
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {EventEmitter} from 'node:events';
import {spawn} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
const args=process.argv.slice(2),arg=(key,fallback)=>args.find(x=>x.startsWith(`--${key}=`))?.split('=').slice(1).join('=')??fallback;
const pkg=arg('package'), mode=args.includes('--model-stall')?'model':args.includes('--run-native')?'native':null;
if(!mode)throw Error('Choose --model-stall (no engine) or --run-native (requires permission)');
if(mode==='native'&&!pkg)throw Error('--package=<extracted unchanged package> required');
const base=pkg?resolve(pkg):resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const modulePath=join(base,pkg?'runtime/port/native-campaign/authority.mjs':'port/native-campaign/authority.mjs');
const {createAuthority,LIMITS}=await import(pathToFileURL(modulePath));
const output=resolve(arg('output','/tmp/opencode/campaign-startup-probe'));
await mkdir(output,{recursive:true});
const mapId=arg('map','crown-array'), began=performance.now();
const summary={mode,mapId,modulePath,limits:LIMITS,outFrames:0,outBytes:0,maxFrame:0,types:{},transportErrors:[],firstInputMs:null};
const timeline=[];let child,timer,fake,firstStart=null,lastSample=0;
const mark=(kind,details={})=>{if(timeline.length<1500)timeline.push({ms:performance.now()-began,kind,...details});};
const authority=createAuthority({mapId,observe(record){
 const f=record.frame;
 if(record.direction==='transport-error'){summary.transportErrors.push(record.reason);mark('authority-terminate',{reason:record.reason,bufferedAmount:([...authority.wss.clients][0]??fake)?.bufferedAmount});}
 if(record.direction==='in'&&f?.type==='input'&&summary.firstInputMs===null){summary.firstInputMs=performance.now()-began;mark('first-input');}
 if(record.direction!=='out'||!f)return;
 const bytes=Buffer.byteLength(JSON.stringify(f));summary.outFrames++;summary.outBytes+=bytes;summary.maxFrame=Math.max(summary.maxFrame,bytes);summary.types[f.type]=(summary.types[f.type]??0)+1;
 if(f.type==='start'){firstStart=performance.now();mark('authority-start');}
 if(summary.outFrames<=8||f.type==='native-arena-input-reset')mark('wire',{type:f.type,bytes,seq:f.seq,reason:f.reason,actors:f.state?.actors?.map(a=>({id:a.id,npcModel:a.npcModel}))});
 if(performance.now()-lastSample>=250){lastSample=performance.now();const ws=[...authority.wss.clients][0]??fake;mark('wire-totals',{frames:summary.outFrames,bytes:summary.outBytes,bufferedAmount:ws?.bufferedAmount,sourceTime:f.state?.time});}
}});
authority.wss.on('connection',ws=>{
 mark('ws-connection');
 ws.on('error',e=>mark('ws-error',{message:e.message,code:e.code}));
 ws.on('close',(code,reason)=>mark('ws-close',{code,reason:reason?.toString(),bufferedAmount:ws.bufferedAmount}));
 ws._socket?.on('error',e=>mark('tcp-error',{message:e.message,code:e.code}));
 ws._socket?.on('end',()=>mark('tcp-end'));
});
try{
 if(mode==='model'){
  // Model only the authority's *reported unsent bytes*. Real TCP kernel buffers
  // delay this growth; this cannot prove a native receive-queue disconnection.
  fake=new EventEmitter();fake.readyState=1;fake.bufferedAmount=0;
  fake.send=(text,callback)=>{fake.bufferedAmount+=Buffer.byteLength(text);callback?.();};
  let end;const stopped=new Promise(r=>end=r);
  fake.terminate=()=>{fake.readyState=3;fake.emit('close',1006,Buffer.alloc(0));end();};
  authority.wss.emit('connection',fake);
  const send=f=>fake.emit('message',Buffer.from(JSON.stringify(f)),false);
  send({type:'create',v:3,nativeArenaInput:1});send({type:'start'});
  timer=setTimeout(end,8000);await stopped;
  summary.secondsFromStart=(performance.now()-firstStart)/1000;
  summary.modeCaveat='Synthetic fully blocked sender, no TCP/Godot; queue count alone is not modeled as failure';
 }else{
  await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
  const engine=join(base,process.platform==='win32'?'cocs.exe':'cocs.x86_64');
  const script=fileURLToPath(new URL('./startup_probe.gd',import.meta.url));
  const command=['--headless','--verbose','--audio-driver','Dummy','--main-pack',join(base,'cocs.pck'),'--script',script,'--',`--map=${mapId}`,'--mode=campaign','--smoke',`--endpoint=ws://127.0.0.1:${authority.server.address().port}/native-campaign`];
  await writeFile(join(output,'invocation.json'),JSON.stringify({engine,command},null,2));
  let log='';child=spawn(engine,command,{cwd:base,env:{...process.env,LP_NUM_THREADS:'1'},stdio:['ignore','pipe','pipe']});
  for(const stream of [child.stdout,child.stderr])stream.on('data',b=>{if(log.length<8*1024*1024)log+=b;});
  timer=setTimeout(()=>{mark('diagnostic-watchdog');child.kill();},120000);
  summary.exit=await new Promise((r,j)=>{child.once('error',j);child.once('exit',(code,signal)=>r({code,signal}));});
  await writeFile(join(output,'native.log'),log);
  summary.smokePassed=summary.exit.code===0&&log.includes('CAMPAIGN_SMOKE_OK');
  if(!summary.smokePassed)process.exitCode=1;
 }
}finally{
 clearTimeout(timer);await authority.close();
 await writeFile(join(output,'transport.json'),JSON.stringify({summary,timeline},null,2));
 console.log('STARTUP_DIAGNOSTIC',JSON.stringify(summary));
}

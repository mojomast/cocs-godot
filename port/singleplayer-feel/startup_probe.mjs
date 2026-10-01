// External diagnostic only. Import the exact extracted package authority.
// --model-stall is Node-only. --run-native requires the owner's engine grant.
import {resolve,join,dirname} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {EventEmitter} from 'node:events';
import {spawn} from 'node:child_process';
import {mkdir,writeFile,mkdtemp,rm,readdir,readFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
const args=process.argv.slice(2),arg=(key,fallback)=>args.find(x=>x.startsWith(`--${key}=`))?.split('=').slice(1).join('=')??fallback;
const pkg=arg('package'), mode=args.includes('--run-launcher')?'launcher':args.includes('--model-stall')?'model':args.includes('--run-native')?'native':null;
if(!mode)throw Error('Choose --model-stall, --run-native (external SceneTree), or --run-launcher (original entrypoint)');
if(mode!=='model'&&!pkg)throw Error('--package=<extracted unchanged package> required');
const base=pkg?resolve(pkg):resolve(dirname(fileURLToPath(import.meta.url)),'../..');
if(mode==='launcher'){
 const output=resolve(arg('output',join(tmpdir(),'campaign-launcher-probe')));await mkdir(output,{recursive:true});
 const sandbox=await mkdtemp(join(tmpdir(),'cocs windows smoke '));
 const preload=new URL('./startup_preload.mjs',import.meta.url).href;
 const env={...process.env,TEMP:sandbox,TMP:sandbox,APPDATA:join(sandbox,'roaming'),LOCALAPPDATA:join(sandbox,'local'),
  COCS_STARTUP_PACKAGE:base,COCS_STARTUP_OUTPUT:output,NODE_OPTIONS:`${process.env.NODE_OPTIONS??''} --import=${preload}`.trim()};
 await mkdir(env.APPDATA);await mkdir(env.LOCALAPPDATA);
 const map=arg('map','crown-array');if(!/^[a-z0-9-]+$/.test(map))throw Error('Invalid map');
 const windows=process.platform==='win32';
 if(!windows){for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=join(sandbox,key);await mkdir(env[key]);}env.LP_NUM_THREADS='1';}
 const executable=windows?(process.env.ComSpec||'cmd.exe'):process.execPath;
 const command=windows?['/d','/s','/c',`""${join(base,'Campaign.cmd')}" --map=${map} --smoke"`]:[join(base,'run.mjs'),'--experience=campaign',`--map=${map}`,'--smoke'];
 const began=process.hrtime.bigint(),beganWall=Date.now(),chunks=[];let bytes=0,child,timer,killTimer,timedOut=false,result;
 const record=(kind,extra={})=>chunks.push({kind,wall:Date.now(),monoNs:String(process.hrtime.bigint()),ms:Number(process.hrtime.bigint()-began)/1e6,pid:child?.pid,...extra});
 await writeFile(join(output,'launcher-invocation.json'),JSON.stringify({executable,command,cwd:sandbox,preload,package:base,sandbox,platform:process.platform},null,2));
 try{
  child=spawn(executable,command,{cwd:sandbox,env,windowsVerbatimArguments:windows,detached:!windows,stdio:['ignore','pipe','pipe']});
  record('spawn');
  for(const name of ['stdout','stderr'])child[name].on('data',b=>{if(bytes<8*1024*1024){bytes+=b.length;record(name,{text:b.toString()});}});
  const killTree=force=>{
   record('owned-tree-stop',{force});
   if(windows){const killer=spawn('taskkill',['/PID',String(child.pid),'/T',...(force?['/F']:[])],{stdio:'ignore',env:{...process.env,NODE_OPTIONS:''}});killer.on('error',e=>record('taskkill-error',{message:e.message}));}
   else try{process.kill(-child.pid,force?'SIGKILL':'SIGTERM');}catch{}
  };
  // Same 120-second campaign bound as verify_windows. Windows uses owned-tree
  // termination directly so cmd.exe cannot exit first and orphan its manager.
  timer=setTimeout(()=>{timedOut=true;killTree(windows);if(!windows)killTimer=setTimeout(()=>killTree(true),2000);},120000);
  result=await new Promise((r,j)=>{child.once('error',j);child.once('close',(code,signal)=>r({code,signal}));});
  record('child-exit',result);
 }finally{
  clearTimeout(timer);clearTimeout(killTimer);
  const text=chunks.filter(x=>x.text).map(x=>x.text).join('');
  const observerRows=[];
  for(const name of await readdir(output))if(/^startup-ws-\d+\.jsonl$/.test(name)){
   for(const line of (await readFile(join(output,name),'utf8')).split('\n'))try{const row=JSON.parse(line);if(row.wall>=beganWall)observerRows.push(row);}catch{}
  }
  const instrumented=observerRows.some(x=>x.kind==='socket-observed')&&!observerRows.some(x=>x.kind==='preload-setup-failed');
  const passed=instrumented&&result?.code===0&&!timedOut&&text.includes('CAMPAIGN_SMOKE_OK')&&!/SCRIPT ERROR|ERROR:|Assertion failed/.test(text);
  await writeFile(join(output,'launcher-stream.jsonl'),chunks.map(x=>JSON.stringify(x)).join('\n')+'\n');
  await writeFile(join(output,'launcher.log'),text);
  await writeFile(join(output,'launcher-result.json'),JSON.stringify({passed,instrumented,result,timedOut,platform:process.platform,map},null,2));
  await rm(sandbox,{recursive:true,force:true});
  console.log('STARTUP_LAUNCHER',JSON.stringify({passed,result,timedOut,output}));if(!passed)process.exitCode=1;
 }
}else{
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
}

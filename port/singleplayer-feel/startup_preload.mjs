// Observation-only NODE_OPTIONS preload. Never import a source-tree ws fallback.
import {createWriteStream,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
const pkg=process.env.COCS_STARTUP_PACKAGE,output=process.env.COCS_STARTUP_OUTPUT;
if(pkg&&output){
 mkdirSync(output,{recursive:true});
 const file=join(resolve(output),`startup-ws-${process.pid}.jsonl`);
 const stream=createWriteStream(file,{flags:'a'});stream.on('error',()=>{});
 let lines=0,serial=0;const began=process.hrtime.bigint(),live=new Set(),states=new WeakMap();
 const log=(kind,extra={})=>{
  try{if(lines++<16000)stream.write(JSON.stringify({kind,pid:process.pid,ppid:process.ppid,wall:Date.now(),monoNs:String(process.hrtime.bigint()),ms:Number(process.hrtime.bigint()-began)/1e6,...extra})+'\n');}catch{}
 };
 const view=ws=>({socket:states.get(ws)?.id,route:states.get(ws)?.route,readyState:ws.readyState,bufferedAmount:ws.bufferedAmount,tcpWritableLength:ws._socket?.writableLength,senderBufferedBytes:ws._sender?._bufferedBytes,bytesWritten:ws._socket?.bytesWritten,bytesRead:ws._socket?.bytesRead,localPort:ws._socket?.localPort,remotePort:ws._socket?.remotePort});
 log('preload',{argv:process.argv,cwd:process.cwd(),package:resolve(pkg),temp:process.env.TEMP,appdata:process.env.APPDATA});
 try{
  const moduleURL=pathToFileURL(join(resolve(pkg),'runtime/node_modules/ws/index.js')).href;
  const {default:WebSocket}=await import(moduleURL);
  const WebSocketServer=WebSocket.WebSocketServer??WebSocket.Server;
  log('ws-module',{moduleURL});
  const attach=(ws,req)=>{
   if(states.has(ws))return states.get(ws);
   const state={id:++serial,route:req?.url??ws.url,outFrames:0,outBytes:0,inFrames:0,inBytes:0,outTypes:{},inTypes:{},map:null};
   states.set(ws,state);live.add(ws);log('socket-observed',view(ws));
   ws.on('message',(data,binary)=>{try{
    state.inFrames++;state.inBytes+=data.byteLength??Buffer.byteLength(String(data));
    if(binary)return;
    const f=JSON.parse(String(data));state.inTypes[f.type]=(state.inTypes[f.type]??0)+1;
    if(state.inTypes[f.type]===1||['host','start','campaign-action'].includes(f.type))log('incoming-command',{...view(ws),type:f.type,frame:f});
   }catch{}});
   ws.on('error',e=>log('ws-error',{...view(ws),message:e.message,code:e.code,stack:e.stack}));
   ws.on('close',(code,reason)=>{log('ws-closed',{...view(ws),code,reason:reason.toString(),counts:state});live.delete(ws);});
   ws._socket?.on('error',e=>log('tcp-error',{...view(ws),message:e.message,code:e.code}));
   ws._socket?.on('end',()=>log('tcp-end',view(ws)));
   return state;
  };
  const emit=WebSocketServer.prototype.emit;
  WebSocketServer.prototype.emit=function(event,...args){
   if(event==='connection'){try{attach(args[0],args[1]);}catch{}}
   return Reflect.apply(emit,this,[event,...args]);
  };
  for(const method of ['send','terminate','close']){
   const original=WebSocket.prototype[method];
   WebSocket.prototype[method]=function(...args){
    try{
     const state=attach(this);
     if(method==='send'){
      const text=typeof args[0]==='string'?args[0]:Buffer.isBuffer(args[0])?args[0].toString():'';
      const bytes=Buffer.byteLength(text),type=/"type"\s*:\s*"([^"\\]+)"/.exec(text)?.[1]??'unknown';
      state.outFrames++;state.outBytes+=bytes;state.outTypes[type]=(state.outTypes[type]??0)+1;
      if(state.outTypes[type]===1||['start','error','native-arena-input-reset'].includes(type)){
       const f=JSON.parse(text);state.map=f.mapId??f.state?.mapId??state.map;
       log('outgoing-frame',{...view(this),type,bytes,map:state.map,seq:f.seq,reason:f.reason,message:f.message,inputEpoch:f.inputEpoch,actors:f.state?.actors?.length});
      }
     }else log(`ws-${method}-call`,{...view(this),counts:state,args:method==='close'?args.slice(0,2).map(String):[],stack:new Error('observation callsite').stack});
    }catch{}
    // Preserve original args/callback/return/throw behavior exactly.
    return Reflect.apply(original,this,args);
   };
  }
  setInterval(()=>{for(const ws of live)log('outstanding',{...view(ws),counts:states.get(ws)});},250).unref();
  process.once('beforeExit',code=>{log('process-before-exit',{code,liveSockets:live.size});stream.end();});
 }catch(e){log('preload-setup-failed',{message:e.message,stack:e.stack});stream.end();}
}

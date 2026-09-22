// Local-only, single-user transport around unchanged source Match.
// Deliberately not Room: the public room service forbids single-player modes.
import http from 'node:http';
import {WebSocketServer, WebSocket} from 'ws';
import {Match} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';
export const MAPS = ['meridian-exchange','verdant-reliquary','ember-crucible'];
export function validateConfig(frame) {
 if(!MAPS.includes(frame.mapId)||frame.config?.mode!=='horde')throw Error('Unsupported local Horde map/mode');
 const waves=frame.config.fragLimit===undefined?10:frame.config.fragLimit;
 if(!Number.isInteger(waves)||waves<1||waves>30)throw Error('Wave target must be 1..30');
 return normalizeConfig({mode:'horde',botCount:0,humanCount:1,difficulty:'easy',fragLimit:waves,timeLimit:1800});
}
export function createAuthority({observe=()=>{}}={}) {
 const server=http.createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/plain'});res.end('Local Horde authority\n');});
 const wss=new WebSocketServer({server,maxPayload:16384});
 let socket=null,config=null,mapId=null,match=null,round=0,seq=0,received=0,ack=0,input={},lastInput=0,eventId=0,finished=false,created=false;
 const send=frame=>{if(socket?.readyState===WebSocket.OPEN){observe({direction:'out',round,frame});socket.send(JSON.stringify(frame));}};
 const lobby=()=>send({type:'lobby',mapId,config,players:[{peerId:0,actorId:0,name:'Local player'}]});
 wss.on('connection',(ws,req)=>{
  if(socket||!['127.0.0.1','::ffff:127.0.0.1','::1'].includes(req.socket.remoteAddress)||req.headers.origin){ws.close(1008,'Local native connection only');return;}
  socket=ws;
  ws.on('message',data=>{
   try {
    const f=JSON.parse(String(data));observe({direction:'in',round,frame:f});
    if(f.type==='create'&&!created){if(f.v!==3)throw Error('Protocol 3 required');created=true;send({type:'welcome',v:3,roomId:'local-horde',peerId:0});lobby();}
    else if(f.type==='host'&&created&&!match){config=validateConfig(f);mapId=f.mapId;lobby();}
    else if(f.type==='start'&&config&&(!match||match.over)){
     match=new Match('chatgpt','openclaw',Math.random,mapId,config);
     if(match.arena.id!==mapId||match.config.mode!=='horde')throw Error('Source substituted map/mode');
     round++;seq=0;received=0;ack=0;input={};eventId=0;finished=false;
     send({type:'start',mapId});
    } else if(f.type==='input'&&match){
     // Inputs already in flight at results are benign; never reopen simulation.
     if(match.over)return;
     const parsed=parseInputEnvelope(f);
     if(Number.isSafeInteger(f.seq)&&f.seq>received){received=f.seq;input=parsed;lastInput=performance.now();}
    } else throw Error('Invalid local lifecycle command');
   }catch(e){send({type:'error',message:e.message});}
  });
  ws.on('close',()=>{socket=null;match=null;created=false;config=null;input={};});
 });
 let ticks=0;
 const timer=setInterval(()=>{
  if(!match||finished)return;
  const controls=performance.now()-lastInput<250?input:{};
  // One normal-rate simulation step. No source state edits or artificial kills.
  match.step(1/60,{inputs:{0:controls}});ack=received;
  const events=match.events.filter(e=>e.id>eventId);
  if(events.length){eventId=events.at(-1).id;send({type:'events',items:events});}
  if(++ticks%3===0||match.over)send({type:'snapshot',seq:++seq,acks:{0:ack},state:match.snapshot()});
  if(match.over){send({type:'results',state:match.snapshot()});finished=true;}
 },1000/60);
 return {server,wss,async close(){clearInterval(timer);for(const s of wss.clients)s.terminate();await new Promise(r=>wss.close(r));await new Promise(r=>server.close(r));}};
}

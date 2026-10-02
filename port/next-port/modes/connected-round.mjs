#!/usr/bin/env node
// Normal-rate SOURCE WIRE acceptance, not native acceptance. No state mutation,
// accelerated tick, score injection or direct Room/Match access. Default crown
// target 30 completes by source survival credit with scripted ordinary inputs.
import assert from 'node:assert/strict';
import {WebSocket} from 'ws';
import {createGameServer} from '../../../server/game-server.mjs';
const game=createGameServer({historyPath:null,progressionPath:null,graceMs:15000});
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
const endpoint=`ws://127.0.0.1:${game.server.address().port}`,peers=[];
async function connect(){
 const ws=new WebSocket(endpoint),messages=[];
 ws.on('message',bytes=>messages.push(JSON.parse(String(bytes))));
 await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject);});
 const peer={ws,messages,seq:0,send:frame=>ws.send(JSON.stringify(frame)),async next(type,after=0,timeout=15000){
  const end=Date.now()+timeout;
  while(Date.now()<end){const found=messages.slice(after).find(m=>m.type===type);if(found)return found;
   const error=messages.slice(after).find(m=>m.type==='error');if(error)throw Error(JSON.stringify(error));
   await new Promise(resolve=>setTimeout(resolve,25));
  }
  throw Error(`Timeout ${type}: ${JSON.stringify(messages.slice(-1))}`);
 }};
 peers.push(peer);return peer;
}
let controls;
try{
 const host=await connect(),guest=await connect();
 host.send({type:'create',v:3,delta:0,name:'Competitive modes proof',playerName:'Crown host',character:'chatgpt',harness:'openclaw'});
 const welcome=await host.next('welcome');
 guest.send({type:'join',v:3,delta:0,roomId:welcome.roomId,name:'Crown guest',character:'gemini',harness:'openclaw'});
 const seat=await guest.next('welcome');assert.notEqual(welcome.peerId,seat.peerId);
 let mark=host.messages.length;
 host.send({type:'host',mapId:'meridian-exchange',config:{mode:'juggernaut',botCount:0,timeLimit:120}});
 await host.next('lobby',mark);host.send({type:'start'});
 const start=await host.next('start');await guest.next('start');
 const first=await host.next('snapshot');assert.equal(first.state.config.fragLimit,30);
 const guestActor=[...guest.messages].reverse().find(f=>f.type==='lobby'&&f.players.some(p=>p.peerId===seat.peerId&&Number.isInteger(p.actorId)))?.players.find(p=>p.peerId===seat.peerId).actorId;
 assert.ok(Number.isInteger(guestActor),'source lobby assigned guest actor');
 const wallStart=Date.now();
 // Rotate and fire upwards: valid ordinary input, cannot manufacture objectives.
 // Crown survival is itself a legitimate scoring action in the original mode.
 let activeGuest=guest;
 controls=setInterval(()=>{
  for(const p of [host,activeGuest])if(p.ws.readyState===WebSocket.OPEN)p.send({type:'input',seq:++p.seq,input:{x:0,z:0,yaw:(p.seq%100)*.02,pitch:1.2,fire:true}});
 },50);
 const viewer=await connect();viewer.send({type:'join',v:3,delta:0,roomId:welcome.roomId,name:'Late viewer'});
 const spectator=await viewer.next('welcome');assert.equal(spectator.spectate,true);await viewer.next('snapshot');
 guest.ws.terminate();await new Promise(resolve=>setTimeout(resolve,200));
 const resumed=await connect();resumed.seq=guest.seq;
 resumed.send({type:'join',v:3,delta:0,roomId:welcome.roomId,name:'Crown guest',token:seat.token,character:'gemini',harness:'openclaw'});
 const resume=await resumed.next('welcome');
 assert.equal(resume.spectate,false);assert.equal(resume.reconnected,true);
 const resumeLobby=await resumed.next('lobby');
 const resumedActor=resumeLobby.players.find(p=>p.peerId===resume.peerId)?.actorId;
 assert.equal(resumedActor,guestActor);activeGuest=resumed;
 const result=await host.next('results',0,60000);await resumed.next('results',0,5000);await viewer.next('results',0,5000);
 clearInterval(controls);
 const wallMs=Date.now()-wallStart;
 assert.ok(wallMs>30000,'normal-rate default-target round, not accelerated');
 assert.equal(result.state.over,true);assert.equal(result.state.winner,first.state.objectives.juggernautId);
 assert.ok(result.state.objectives.points[result.state.winner]>=30);
 assert.ok(result.state.actors.some(a=>a.shots>0),'scripted fire reached source');
 mark=host.messages.length;const viewMark=viewer.messages.length;
 host.send({type:'start'});const restart=await host.next('start',mark);
 assert.ok(restart.roundRevision>start.roundRevision);
 const fresh=await host.next('snapshot',mark);assert.ok(fresh.state.objectives.points[fresh.state.objectives.juggernautId]<1);
 await viewer.next('start',viewMark);assert.equal(spectator.spectate,true);
 for(const p of [host,resumed,viewer])p.send({type:'leave'});
 console.log('MODE_CONNECTED_ROUND_OK '+JSON.stringify({kind:'source-wire-normal-rate',map:'meridian-exchange',mode:'juggernaut',wallMs,sourceSeconds:result.state.time,points:result.state.objectives.points,winner:result.state.winner,host:welcome.peerId,guest:seat.peerId,resumedActor,spectator:spectator.spectate,restartRevision:restart.roundRevision,inputFrames:host.seq+resumed.seq}));
}finally{
 clearInterval(controls);for(const p of peers)p.ws.terminate();await game.close();
}

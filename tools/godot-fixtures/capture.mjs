import {createGameServer} from '../../server/game-server.mjs';
import {WebSocket} from 'ws';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
import {verifySource} from '../godot-export/semantic.mjs';
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const mapId='meridian-exchange';assert.ok(lock.map_ids.includes(mapId));
const game=createGameServer({tickMs:1,tickDt:1/60,historyPath:null,progressionPath:null});
const frames=[];const sockets=[];let largest=0,total=0,snapshots=0;
async function connect(){
 const ws=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);sockets.push(ws);
 const items=[];const waiters=[];const client=sockets.length;
 ws.on('message',data=>{const msg=JSON.parse(data);total+=data.length;largest=Math.max(largest,data.length);if(msg.type==='snapshot')snapshots++;
  if(msg.type!=='snapshot'||snapshots<8)frames.push({direction:'server',client,frame:msg});
  const index=waiters.findIndex(w=>w.predicate(msg));if(index>=0){const w=waiters.splice(index,1)[0];clearTimeout(w.timer);w.resolve(msg);}else {items.push(msg);if(items.length>1000)items.shift();}
 });
 await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject);});
 return {send(frame){frames.push({direction:'client',client,frame});ws.send(JSON.stringify(frame));},until(predicate){const index=items.findIndex(predicate);if(index>=0)return Promise.resolve(items.splice(index,1)[0]);return new Promise((resolve,reject)=>{const w={predicate,resolve,timer:setTimeout(()=>{waiters.splice(waiters.indexOf(w),1);reject(Error('Frame wait timeout'));},20000)};waiters.push(w);});}};
}
try{
 await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
 const a=await connect();a.send({type:'create',name:'Port fixture',playerName:'Port A',v:3,delta:0});
 const welcome=await a.until(m=>m.type==='welcome');const b=await connect();
 b.send({type:'join',roomId:welcome.roomId,name:'Port B',v:3,delta:0});await b.until(m=>m.type==='welcome');
 a.send({type:'host',mapId,config:{mode:'deathmatch',botCount:2,timeLimit:30,fragLimit:100}});
 await a.until(m=>m.type==='lobby'&&m.config&&m.mapId===mapId);
 a.send({type:'start'});const start=await a.until(m=>m.type==='start');assert.equal(start.mapId,mapId);
 const lobby=await a.until(m=>m.type==='lobby'&&m.started);const actorId=lobby.players.find(p=>p.peerId===welcome.peerId).actorId;
 assert.notEqual(actorId,welcome.peerId);
 a.send({type:'input',seq:1,input:{forward:1,yaw:0,pitch:0,fire:true}});
 const ack=await a.until(m=>m.type==='snapshot'&&m.acks?.[String(actorId)]>=1);assert.equal(ack.state.mapId,mapId);
 frames.push({direction:'server',client:1,frame:ack});
 const result=await a.until(m=>m.type==='results');assert.ok(result.state.over);assert.equal(result.state.mapId,mapId);
 a.send({type:'start'});const restart=await a.until(m=>m.type==='start');assert.equal(restart.mapId,mapId);
 const report={source_commit:lock.source_commit,protocol:3,delta:0,map_id:mapId,clients:2,bots:2,actor_id:actorId,peer_id:welcome.peerId,largest_frame_bytes:largest,total_received_bytes:total,snapshot_count:snapshots,results:true,restart:true,clock:'accelerated wall-clock: tickMs=1, unchanged dt=1/60; not latency/performance evidence'};
 // Omit only ephemeral reconnect/progress credentials; mark sanitization explicitly.
 for(const item of frames)for(const key of ['token','progressToken'])if(key in item.frame)item.frame[key]=null;
 mkdirSync('godot/tests/protocol',{recursive:true});writeFileSync('godot/tests/protocol/captured.json',JSON.stringify({report,redacted_fields:['welcome.token','welcome.progressToken'],frames},null,2)+'\n');
 writeFileSync('port/reports/protocol-capture.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{for(const ws of sockets)ws.terminate();await game.close();}

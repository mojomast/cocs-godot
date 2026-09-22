// Owned loopback, OS-assigned port, unmodified createGameServer clock/physics.
// Passive sanitized receipts distinguish input arrival/ACK from application.
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {writeFileSync} from 'node:fs';
const [root, output] = process.argv.slice(2);
const {createGameServer}=await import(pathToFileURL(resolve(root,'server/game-server.mjs')));
const game=createGameServer({historyPath:null,progressionPath:null});
const evidence={clock:'default normal-rate server; no tick/state writes',inputs:[],samples:[],events:[],results:[],configs:[],starts:0};
const since=Date.now();
let lastSample=0, actor=null;
const sample=f=>({round:evidence.starts,wallMs:Date.now()-since,seq:f.seq,ack:f.acks?.[actor],time:f.state.time,actor,over:f.state.over,overReason:f.state.overReason,vehicle:f.state.vehicles?.find(v=>v.driver===actor),race:f.state.race});
game.wss.on('connection',socket=>{
 socket.on('message',raw=>{const f=JSON.parse(raw.toString());if(f.type==='input'&&evidence.inputs.length<18000)evidence.inputs.push({round:evidence.starts,wallMs:Date.now()-since,seq:f.seq,input:f.input});});
 const original=socket.send;
 socket.send=function(raw,...args){
  const f=JSON.parse(raw.toString());
  if(f.type==='start'){evidence.starts++; evidence.configs.push({mapId:f.mapId,config:f.config});}
  if(f.type==='lobby'){actor=f.players?.find(p=>p.actorId!=null)?.actorId??actor;if(f.config)evidence.configs.push({mapId:f.mapId,config:f.config});}
  if(f.type==='events') evidence.events.push(...f.items.map(item=>({round:evidence.starts,wallMs:Date.now()-since,...item})));
  if(f.type==='results') evidence.results.push(sample(f));
  if(f.type==='snapshot'&&Date.now()-lastSample>=150){lastSample=Date.now(); evidence.samples.push(sample(f));}
  return original.call(this,raw,...args);
 };
});
await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
console.log(`ENDPOINT ws://127.0.0.1:${game.server.address().port}`);
let closing=false;
async function close(){if(closing)return;closing=true;clearTimeout(deadline);for(const s of game.wss.clients)s.terminate();await game.close();evidence.cleanup={serverClosed:!game.server.listening,sockets:game.wss.clients.size};writeFileSync(output,JSON.stringify(evidence));}
process.on('SIGTERM',close);process.on('SIGINT',close);
const deadline=setTimeout(close,240000);

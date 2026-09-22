// Owned normal-rate server. Observe sanitized fields only; never retain welcome.
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {writeFileSync} from 'node:fs';
const [root, output] = process.argv.slice(2);
const {createGameServer}=await import(pathToFileURL(resolve(root,'server/game-server.mjs')));
const game=createGameServer({historyPath:null,progressionPath:null});
const evidence={clock:'unmodified default normal-rate server',inputs:[],samples:[],starts:0};
let lastSample=0, actor=null;
game.wss.on('connection',socket=>{
 socket.on('message',raw=>{const f=JSON.parse(raw.toString());if(f.type==='input'&&evidence.inputs.length<3000)evidence.inputs.push({seq:f.seq,input:f.input});});
 const original=socket.send;
 socket.send=function(raw,...args){
  const f=JSON.parse(raw.toString());
  if(f.type==='start')evidence.starts++;
  if(f.type==='lobby')actor=f.players?.find(p=>p.actorId!=null)?.actorId??actor;
  if(f.type==='snapshot'&&Date.now()-lastSample>=150){
   lastSample=Date.now();
   const vehicle=f.state?.vehicles?.find(v=>v.driver===actor);
   if(vehicle)evidence.samples.push({seq:f.seq,ack:f.acks?.[actor],time:f.state.time,actor,vehicle,phase:f.state.race?.phase,ball:f.state.race?.ball});
  }
  return original.call(this,raw,...args);
 };
});
await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
console.log(`ENDPOINT ws://127.0.0.1:${game.server.address().port}`);
let closing=false;
async function close(){if(closing)return;closing=true;clearTimeout(deadline);for(const s of game.wss.clients)s.terminate();await game.close();evidence.cleanup={serverClosed:!game.server.listening,sockets:game.wss.clients.size};writeFileSync(output,JSON.stringify(evidence));}
process.on('SIGTERM',close);process.on('SIGINT',close);
const deadline=setTimeout(close,85000);

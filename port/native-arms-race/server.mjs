// Passive wire receipts only. Unchanged ordinary source scheduler, no Match writes.
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {writeFileSync} from 'node:fs';
const [root, output] = process.argv.slice(2);
const {createGameServer} = await import(pathToFileURL(resolve(root,'server/game-server.mjs')));
const game = createGameServer({port:0,historyPath:null,progressionPath:null});
const evidence = {inputs:[],samples:[],events:[],results:[],configs:[],hostRequests:[],starts:0,clock:'default source scheduler; no state/time writes'};
const since = Date.now();
let actor = null;
const sample = f => ({wallMs:Date.now()-since,round:evidence.starts,seq:f.seq,ack:f.acks?.[actor],actor,state:f.state});
game.wss.on('connection',socket=>{
 socket.on('message',raw=>{const f=JSON.parse(raw.toString());if(f.type==='input') evidence.inputs.push({wallMs:Date.now()-since,round:evidence.starts,seq:f.seq,input:f.input});if(f.type==='host')evidence.hostRequests.push(f);});
 const send=socket.send;
 socket.send=function(raw,...args){
  const f=JSON.parse(raw.toString());
  if(f.type==='lobby')actor=f.players?.find(p=>p.actorId!=null)?.actorId??actor;
  if(f.type==='start'){evidence.starts++;evidence.configs.push(f);}
  if(f.type==='events')evidence.events.push(...f.items.map(e=>({round:evidence.starts,...e})));
  if(f.type==='results')evidence.results.push(sample(f));
  if(f.type==='snapshot'){
   // Retain every scalar actor/effect snapshot, omit bulky static-independent trees.
   const s=f.state;
   evidence.samples.push(sample({...f,state:{mapId:s.mapId,time:s.time,config:s.config,over:s.over,overReason:s.overReason,winner:s.winner,actors:s.actors.map(a=>({id:a.id,bot:!!a.bot,name:a.name,x:a.x,y:a.y,z:a.z,health:a.health,dead:a.dead,ladder:a.ladder,weapon:a.weapon,frags:a.frags,deaths:a.deaths,shots:a.shots}))}}));
  }
  return send.call(this,raw,...args);
 };
});
await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
console.log(`ENDPOINT ws://127.0.0.1:${game.server.address().port}`);
let closing=false;
async function close(){if(closing)return;closing=true;clearTimeout(deadline);for(const s of game.wss.clients)s.terminate();await game.close();evidence.cleanup={serverClosed:!game.server.listening,sockets:game.wss.clients.size};writeFileSync(output,JSON.stringify(evidence));}
process.on('SIGTERM',close);process.on('SIGINT',close);
const deadline=setTimeout(close,195000);

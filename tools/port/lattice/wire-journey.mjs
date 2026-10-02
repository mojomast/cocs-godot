// Real WebSocket -> ordinary Room command -> Match.step -> recipient frames.
// Controlled wallet/phase setup is recorded explicitly; no fabricated snapshots.
import assert from 'node:assert/strict';
import {mkdirSync, mkdtempSync, writeFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {once} from 'node:events';
import {setTimeout as sleep} from 'node:timers/promises';
import {WebSocket} from 'ws';
import {createGameServer} from '../../../port/multiplayer-worlds/derived/game-server.mjs';

const root = process.env.LATTICE_EVIDENCE ?? '/home/mojo/.tmp-on-disk/cocs-expansion-three-lattice-evidence-20261002';
mkdirSync(root, {recursive:true});
const output = mkdtempSync(join(resolve(root), 'wire-'));
const evidence = {scope:'two protocol players + spectator; controlled source wallet/phase; not native or human acceptance', checks:[], setup:[], passed:false};
const game = createGameServer({historyPath:null, progressionPath:null});
const clients = [];
let bytes = 0;
let fatal = null;
const journal = [];
const interrupt=()=>{fatal=Error('Interrupted');};
process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
function record(value) {
 const text = JSON.stringify(value);
 bytes += Buffer.byteLength(text);
 assert.ok(bytes < 16_000_000, 'bounded evidence');
 journal.push(text);
}
async function until(fn, label, ms=6000) {
 const end=Date.now()+ms;
 while(Date.now()<end) { if(fatal)throw fatal; const value=fn(); if(value)return value; await sleep(20); }
 throw Error(`Deadline: ${label}`);
}
function check(value, label) {assert.ok(value,label); evidence.checks.push(label);}
async function connect(endpoint, name) {
 const ws=new WebSocket(endpoint), client={ws,name,frames:[],seq:0};
 clients.push(client);
 ws.on('message', raw=>{
  try {
  const frame=JSON.parse(raw.toString());
  record({recipient:name,frame});
  client.frames.push(frame);
  if(client.frames.length>300)client.frames.shift();
  } catch(error) {fatal=error;}
 });
 ws.on('error', error=>{evidence.socketError=error.message;});
 let openTimer;
 try {await Promise.race([once(ws,'open'),new Promise((_,bad)=>{openTimer=setTimeout(()=>bad(Error('Open deadline')),5000);})]);}
 finally {clearTimeout(openTimer);}
 client.send=frame=>{record({sender:name,frame});ws.send(JSON.stringify(frame));};
 return client;
}
async function request(client, round, payload, reason=null) {
 const cardId=`fixture-${client.name}-${++client.seq}`;
 client.send({...payload,cardId,roundRev:round,actionSeq:client.seq});
 const result=await until(()=>client.frames.find(f=>f.type==='cocs-reject'&&f.cardId===cardId) ?? client.frames.flatMap(f=>f.state?.cocs?.cards??[]).find(c=>c.id===cardId),cardId);
 if(reason)check(result.reason===reason,`${cardId}: source refusal ${reason} (actual ${result.reason})`);
 else check(result.accepted===true&&result.ok===true,`${cardId}: source accepted exact card`);
 return {cardId,result};
}
try {
 game.server.listen(0,'127.0.0.1'); await once(game.server,'listening');
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 const host=await connect(endpoint,'host');
 host.send({type:'create',v:3,delta:0,name:'Lattice feedback fixture',playerName:'Host',character:'chatgpt',harness:'openclaw'});
 const welcome=await until(()=>host.frames.find(f=>f.type==='welcome'),'host welcome');
 const guest=await connect(endpoint,'guest'), spectator=await connect(endpoint,'spectator');
 for(const c of [guest,spectator])c.send({type:'join',v:3,delta:0,roomId:welcome.roomId,name:c.name,character:'claude',harness:'hermes',spectate:c===spectator});
 for(const c of [guest,spectator])c.welcome=await until(()=>c.frames.find(f=>f.type==='welcome'),`${c.name} welcome`);
 host.send({type:'host',mapId:'tern-archipelago',config:{mode:'cocs',botCount:0,timeLimit:900}});
 await until(()=>host.frames.find(f=>f.type==='lobby'&&f.config?.mode==='cocs'&&f.mapId==='tern-archipelago'),'configuration');
 host.send({type:'start'});
 const start=await until(()=>host.frames.find(f=>f.type==='start'),'start');
 const room=game.registry.get(welcome.roomId), round=start.roundRevision;
 const actor=room.match.actors[room.peers.get(welcome.peerId).actorId];
 check(room.match.actors.length===2,'two real player actors, no bots');
 const ownNode=room.match.objectiveState.nodes.find(n=>n.owner===actor.team);
 await request(host,round,{type:'order',verb:'HOLD',target:ownNode.id});
 await request(host,round,{type:'order',verb:'HOLD',target:'not-a-source-node'},'target');
 await request(spectator,round,{type:'order',verb:'HOLD',target:ownNode.id},'spectator');
 // Explicit controlled setup: enable a funded purchase and isolate empty repair.
 actor.req=200; actor.reqSpent=0; room.match.objectiveState.reqMult=0;
 room.match.objectiveState.cuts=[];
 evidence.setup.push('PvP actor REQ=200, reqSpent=0, reqMult=0, cuts=[]');
 await request(host,round,{type:'buy',itemId:'repair-tool'},'no-target');
 check(actor.reqSpent===0,'no-target refusal debits nothing');
 await request(host,round,{type:'buy',itemId:'recon-pulse'},'commander-only');
 check(actor.reqSpent===0,'seat refusal debits nothing');
 const bought=await request(host,round,{type:'buy',itemId:'overshield'});
 await until(()=>host.frames.some(f=>f.state?.cocs?.cards?.some(c=>c.id===bought.cardId&&c.state==='done'&&c.ok===true)),'exact settled BUY');
 check(actor.reqSpent===50,'settled source BUY debits exactly 50 REQ');
 await request(host,round,{type:'buy',itemId:'haste'},'one-active-buff');
 check(actor.reqSpent===50,'buff refusal does not debit again');
 const enemyNode=room.match.objectiveState.nodes.find(n=>n.owner!==null&&n.owner!==actor.team&&n.archetype==='hq');
 await request(guest,round,{type:'order',verb:'HOLD',target:enemyNode.id});
 await until(()=>spectator.frames.some(f=>f.type==='snapshot'),'spectator snapshot');
 for(const c of clients) {
  const f=c.frames.filter(f=>f.type==='snapshot').at(-1), board=f.state.cocs;
  check(!!board,`${c.name}: actual recipient objective snapshot`);
  if(c===spectator) {
   check(!board.cards?.length, 'spectator has no private cards');
   check(!board.contacts||Object.keys(board.contacts).length===0,'spectator has no contact bucket');
  } else {
   const peerId=c===host?welcome.peerId:c.welcome.peerId;
   const team=room.match.actors[room.peers.get(peerId).actorId].team;
   check(Object.keys(board.contacts??{}).every(k=>k===String(team)),`${c.name}: only own contact bucket`);
  }
 }
 // Reconfigure through ordinary host/start; old card identities must refuse.
 host.send({type:'host',mapId:'tern-archipelago',config:{mode:'cocs-coop',botCount:0,timeLimit:900}});
 await until(()=>host.frames.some(f=>f.type==='lobby'&&f.config?.mode==='cocs-coop'),'Operations configuration');
 host.send({type:'start'});
 const coop=await until(()=>host.frames.find(f=>f.type==='start'&&f.config?.mode==='cocs-coop'),'Operations start');
 room.match.objectiveState.coop.phase='wave';
 room.match.objectiveState.coop.intermission=false;
 room.match.objectiveState.coop.intermissionOpen=false;
 evidence.setup.push('Operations phase=wave, intermission=false, intermissionOpen=false');
 await request(host,coop.roundRevision,{type:'economy',action:'reinforce',role:'fighter'},'window-closed');
 await request(host,round,{type:'order',verb:'HOLD',target:ownNode.id},'stale-round');
 evidence.passed=true;
} catch(error) {
 evidence.error=error.stack; process.exitCode=1;
} finally {
 // Await socket close and both listening resources; preserve every failed run.
 await Promise.all(clients.map(async({ws})=>{
  if(ws.readyState===WebSocket.CLOSED)return;
  const closed=once(ws,'close'); ws.close();
  const timeout=setTimeout(()=>ws.terminate(),1500);
  try {await closed;} finally {clearTimeout(timeout);}
 }));
 const serverClosed=game.server.listening?once(game.server,'close'):Promise.resolve();
 const websocketClosed=once(game.wss,'close');
 await game.close(); await Promise.all([serverClosed,websocketClosed]);
 writeFileSync(join(output,'wire.jsonl'),journal.join('\n')+'\n');
 writeFileSync(join(output,'result.json'),JSON.stringify(evidence,null,2)+'\n');
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
 console.log(JSON.stringify({output,...evidence},null,2));
}

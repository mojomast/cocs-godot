/** Ordinary socket-seat floor test; automated seats are NEVER human playtesters. */
import {existsSync,readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {PROTOCOL_VERSION} from '../../../game/protocol.mjs';
const root=resolve(fileURLToPath(new URL('../../../',import.meta.url)));
const marker='/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted';
if(!existsSync(marker))throw Error(`Refusing server work without ${marker}`);
const [{createGameServer},{WebSocket}]=await Promise.all([import('../../../server/game-server.mjs'),import('ws')]);
const lock=JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
const out=join(root,'port/native-lattice/evidence/flagship',`ordinary-floor-${Date.now()}`);mkdirSync(out,{recursive:true});
const cases=[];
const game=createGameServer({historyPath:null,progressionPath:null});
let closed=false;
const wait=(predicate,limit=6000)=>new Promise((ok,no)=>{const start=Date.now();const id=setInterval(()=>{
 if(predicate()) {clearInterval(id);ok()} else if(Date.now()-start>limit){clearInterval(id);no(Error('ordinary wire deadline'))}
},20)});
async function seat(url,name,room) {
 const ws=new WebSocket(url),frames=[];
 ws.on('message',data=>{try{const f=JSON.parse(data.toString());if(frames.length<200)frames.push(f)}catch{}});
 ws.on('error',()=>{});
 await wait(()=>ws.readyState===WebSocket.OPEN);
 ws.send(JSON.stringify(room?{type:'join',roomId:room,name,character:'chatgpt',harness:'openclaw',v:PROTOCOL_VERSION,delta:0}:{type:'create',name,playerName:name,character:'chatgpt',harness:'openclaw',v:PROTOCOL_VERSION,delta:0}));
 await wait(()=>frames.some(f=>f.type==='welcome'));
 return {ws,frames,room:frames.find(f=>f.type==='welcome').roomId};
}
try {
 await new Promise((ok,no)=>{game.server.once('error',no);game.server.listen(0,'127.0.0.1',ok)});
 const url=`ws://127.0.0.1:${game.server.address().port}`;
 for(const map of ['asterion-relay','monsoon-foundry'])for(const rung of ['4v4','8v8'])for(const count of [1,2,7,8,9]){
  const disconnectedBeforeStart=count===9, seats=disconnectedBeforeStart?8:count;
  const peers=[];const result={map,rung,automated_seats:seats,disconnected_before_start:disconnectedBeforeStart,evidence_class:'ordinary-wire',status:'FAIL'};cases.push(result);
  try{
   const host=await seat(url,`floor-host-${map}-${rung}-${count}`);peers.push(host);
   host.ws.send(JSON.stringify({type:'host',mapId:map,config:{mode:'cocs',rung,timeLimit:900,botCount:0}}));
   await wait(()=>host.frames.some(f=>f.type==='lobby' && f.config?.rung===rung));
   for(let i=1;i<seats;i++)peers.push(await seat(url,`seat-${i}`,host.room));
   await wait(()=>host.frames.some(f=>f.type==='lobby' && f.players?.filter(p=>p.connected && !p.spectate).length===seats));
   if(disconnectedBeforeStart){
    peers.at(-1).ws.terminate();
    await wait(()=>host.frames.some(f=>f.type==='lobby' && f.players?.filter(p=>p.connected && !p.spectate).length===7));
   }
   result.echo=host.frames.filter(f=>f.type==='lobby').at(-1)?.cocs;
   host.ws.send(JSON.stringify({type:'start'}));
   await wait(()=>host.frames.some(f=>f.type==='start' || f.type==='error' && f.message?.startsWith('below-minimum:')));
   const observed=host.frames.filter(f=>f.type==='start' || f.type==='error' && f.message?.startsWith('below-minimum:')).at(-1);
   result.response=observed.type==='start'?{type:'start',mapId:observed.mapId,config:observed.config,roundRevision:observed.roundRevision}:{type:'error',message:observed.message};
   // A start frame echoes the room config; the source may only publish actual
   // human/bot population in later recipient snapshots. Do not invent it here.
   result.status=(count===8?observed.type==='start' && observed.config?.rung===rung && observed.mapId===map:observed.type==='error' && observed.message.includes(`have ${disconnectedBeforeStart?7:count}`))?'PASS':'FAIL';
  }catch(e){result.error=String(e)}finally{for(const peer of peers)peer.ws.terminate()}
 }
}finally{
 for(const ws of game.wss.clients)ws.terminate();await game.close();closed=!game.server.listening;
 writeFileSync(join(out,'results.json'),JSON.stringify({schema_version:1,source_commit:lock.source_commit,evidence_class:'ordinary-wire',note:'Automated ordinary seats, not human participants; no native clients or full rounds',cases,cleanup:{server_closed:closed,children_waited:true}},null,2));
 console.log(`${out}: ${cases.filter(c=>c.status==='PASS').length}/${cases.length} floor cases; server closed=${closed}`);
 if(!closed || cases.some(c=>c.status!=='PASS'))process.exitCode=1;
}

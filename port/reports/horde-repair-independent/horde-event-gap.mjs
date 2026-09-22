// Independent normal-rate source action probe. No source instance access,
// injected clock, RNG selection, or source state writes.
import {createAuthority} from '../../native-horde/authority.mjs';
import {WebSocket} from 'ws';
import {writeFileSync} from 'node:fs';
import {gzipSync} from 'node:zlib';
import assert from 'node:assert/strict';
const records=[],authority=createAuthority({observe:r=>records.push(r)});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let socket,endpoint;
try {
 await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
 endpoint=`ws://127.0.0.1:${authority.server.address().port}`;
 socket=new WebSocket(endpoint);socket.on('error',()=>{});
 await new Promise((r,j)=>{socket.once('open',r);socket.once('error',j);});
 const send=f=>socket.send(JSON.stringify(f));
 send({type:'create',v:3});
 send({type:'host',mapId:'meridian-exchange',config:{mode:'horde'}});
 send({type:'start'});
 const deadline=performance.now()+3000;
 while(!records.some(r=>r.frame?.type==='snapshot')&&performance.now()<deadline)await delay(10);
 assert(records.some(r=>r.frame?.type==='snapshot'),'startup failed');
 const epoch=records.find(r=>r.direction==='out'&&r.frame?.type==='start').frame.inputEpoch;
 await delay(400);
 send({type:'input',inputEpoch:epoch,seq:1,input:{grenade:true}});
 send({type:'input',inputEpoch:epoch,seq:2,input:{grenade:false}});
 await delay(300);
} finally {
 socket?.terminate();await authority.close();
 writeFileSync(new URL('event-gap-wire.jsonl.gz',import.meta.url),gzipSync(records.map(r=>JSON.stringify(r)).join('\n')));
}
const batches=records.filter(r=>r.direction==='out'&&r.frame?.type==='events');
const events=batches.flatMap(r=>r.frame.items);
const seen=new Map(),duplicates=[];
for(const event of events){
 const key=JSON.stringify([event.type,event.sourceId,event.time]);
 if(seen.has(key))duplicates.push({first:seen.get(key),replayed:event});
 else seen.set(key,event);
}
const result={endpoint,serverClosed:!authority.server.listening,sockets:authority.wss.clients.size,
 ordinaryGrenadeStepped:records.some(r=>r.direction==='step'&&r.inputSeq===1&&r.controls.grenade),
 grenadeEvents:events.filter(e=>e.type==='grenade'),duplicates,
 errors:records.filter(r=>r.direction==='transport-error'),batches};
writeFileSync(new URL('event-gap.json',import.meta.url),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result,null,2));
assert(result.ordinaryGrenadeStepped,'ordinary grenade was not stepped');
assert.equal(result.errors.length,0,'event cursor disconnected valid action');
assert.equal(duplicates.length,0,'source event replayed under a new wire ID');

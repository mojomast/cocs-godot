import {WebSocket} from 'ws';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {randomUUID,createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {createObjectOracle,installCursorOracle} from './horde-object-oracle.mjs';
import {revision} from './horde-revision.mjs';
const baseline=process.argv.find(s=>s.startsWith('--baseline='))?.slice(11);
const out=new URL(`diagnostics/${randomUUID()}/`,import.meta.url);mkdirSync(out,{recursive:true});
let adapter,oracle,restore=()=>{},source;
if(baseline) {
 oracle=createObjectOracle();globalThis.__hordeObjectOracle=(match,batch)=>oracle.check(match,batch);
 const old=await revision(baseline,'port/native-horde/authority.mjs',code=>{
  const before='eventBatch(active,eventCursor)';
  if(code.split(before).length!==2)throw Error('Old cursor anchor changed');
  return code.replace(before,'globalThis.__hordeObjectOracle(active,eventBatch(active,eventCursor))');
 });adapter=old.module;source=old.bytes;
} else {
 adapter=await import('../../native-horde/authority.mjs');
 ({oracle,restore}=installCursorOracle(adapter.EventCursor));source=readFileSync('port/native-horde/authority.mjs');
}
const records=[],authority=adapter.createAuthority({observe:r=>records.push(r)}),delay=ms=>new Promise(r=>setTimeout(r,ms));
let socket,endpoint,error=null;
try {
 await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
 endpoint=`ws://127.0.0.1:${authority.server.address().port}`;
 socket=new WebSocket(endpoint);socket.on('error',()=>{});
 await new Promise((r,j)=>{socket.once('open',r);socket.once('error',j);});
 const send=f=>socket.send(JSON.stringify(f));
 send({type:'create',v:3});send({type:'host',mapId:'meridian-exchange',config:{mode:'horde'}});send({type:'start'});
 const end=performance.now()+3000;
 while(!records.some(r=>r.frame?.type==='snapshot')){if(performance.now()>end)throw Error('startup timeout');await delay(10);}
 const epoch=records.find(r=>r.direction==='out'&&r.frame.type==='start').frame.inputEpoch;
 await delay(400);
 send({type:'input',inputEpoch:epoch,seq:1,input:{grenade:true}});
 send({type:'input',inputEpoch:epoch,seq:2,input:{grenade:false}});
 await delay(300);
} catch(e) {error=e.stack;}
finally {socket?.terminate();await authority.close();restore();delete globalThis.__hordeObjectOracle;}
const ordinaryGrenadeStepped=records.some(r=>r.direction==='step'&&r.inputSeq===1&&r.controls.grenade);
const summary={baseline:baseline??'working final repair',endpoint,error,ordinaryGrenadeStepped,
 sourceObjectOracle:oracle.summary(),serverClosed:!authority.server.listening,sockets:authority.wss.clients.size,
 authoritySHA256:createHash('sha256').update(source).digest('hex')};
for(const [name,data]of [['wire',records],['source-object-oracle',oracle.records]])
 writeFileSync(new URL(name+'.jsonl.gz',out),gzipSync(data.map(r=>JSON.stringify(r)).join('\n')));
writeFileSync(new URL('summary.json',out),JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify({directory:out.pathname,...summary},null,2));
if(error||!ordinaryGrenadeStepped||!summary.sourceObjectOracle.passed||!summary.serverClosed||summary.sockets)process.exitCode=1;

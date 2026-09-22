// Same expectations against old committed adapter (HORDE_BASELINE=59c2b33)
// and repaired adapter. Loopback/source Match only; never replace/mutate Match.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync,spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {createRequire} from 'node:module';
import {WebSocket} from 'ws';
const require=createRequire(import.meta.url);
async function revision(file) {
 if(!process.env.HORDE_BASELINE)return import(pathToFileURL(resolve(file)).href);
 let code=execFileSync('git',['show',`${process.env.HORDE_BASELINE}:${file}`],{encoding:'utf8'});
 code=code.replace(/from '([^']+)'/g,(all,ref)=>{
  if(ref==='ws')return `from '${new URL('wrapper.mjs',pathToFileURL(require.resolve('ws'))).href}'`;
  return ref.startsWith('.')?`from '${new URL(ref,pathToFileURL(resolve(file))).href}'`:all;
 });
 return import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
}
const adapter=await revision('port/native-horde/authority.mjs');
const validation=await revision('port/native-horde/validate.mjs');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function wait(predicate,ms=2000) {
 const end=performance.now()+ms;
 while(performance.now()<end){const found=predicate();if(found)return found;await delay(5);}
 throw Error('Bounded diagnostic timeout');
}
async function connect(url) {
 const ws=new WebSocket(url);ws.on('error',()=>{});
 await new Promise((r,j)=>{ws.once('open',r);ws.once('error',j);});return ws;
}
async function rig(start=true) {
 const records=[];
 const authority=adapter.createAuthority({observe:r=>records.push({...r,observedMs:performance.now()})});
 await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
 const url=`ws://127.0.0.1:${authority.server.address().port}`,ws=await connect(url);
 const send=f=>ws.send(JSON.stringify(f));
 send({type:'create',v:3});send({type:'host',mapId:'meridian-exchange',config:{mode:'horde'}});
 const result={authority,records,ws,url,send,epoch:1,
  snapshots:()=>records.filter(r=>r.direction==='out'&&r.frame.type==='snapshot'),
  async close(){ws.terminate();await authority.close();}};
 if(start){send({type:'start'});await wait(()=>result.snapshots()[0]);result.epoch=records.find(r=>r.frame?.type==='start'&&r.direction==='out').frame.inputEpoch??1;}
 result.input=(seq,input={},cancel=false)=>send({type:'input',seq,input,cancel,inputEpoch:result.epoch});
 return result;
}
if(process.argv.includes('--oversize-child')) {
 const r=await rig(false);
 try {
  const closed=new Promise(resolve=>r.ws.once('close',resolve));r.ws.send('x'.repeat(16385));await closed;
  const next=await connect(r.url);next.terminate();
 } finally {await r.close();}
} else {
 test('received fire tap is stepped before release, not merely ACKed',async()=>{
  const r=await rig();try {
   await delay(400);r.input(1,{fire:true,yaw:.1});r.input(2,{fire:false,yaw:.2});
   const sample=await wait(()=>r.snapshots().find(s=>s.frame.acks[0]===2));
   console.log('TAP_DIAGNOSTIC',JSON.stringify({shots:sample.frame.state.actors[0].shots,ack:sample.frame.acks[0],input:sample.frame.hordeInput}));
   assert(sample.frame.state.actors[0].shots>0,'received fire tap was lost');
   const steps=r.records.filter(s=>s.direction==='step'&&s.inputSeq!==null);
   assert.deepEqual(steps.slice(0,2).map(s=>s.inputSeq),[1,2]);
   assert.deepEqual(steps.slice(0,2).map(s=>s.controls.fire),[true,false]);
   assert.equal(sample.frame.hordeInput.appliedSeq,2);
  }finally{await r.close();}
 });
 test('explicit cancellation discards pending fire, ACK names only stepped neutral sample',async()=>{
  const r=await rig();try {
   await delay(400);r.input(1,{fire:true});r.input(2,{fire:true},true);
   const sample=await wait(()=>r.snapshots().find(s=>s.frame.acks[0]===2));
   assert.equal(sample.frame.state.actors[0].shots,0,'cancelled fire executed');
   assert(!r.records.some(s=>s.direction==='step'&&s.inputSeq===1));
   assert.equal(sample.frame.hordeInput.cancelledThrough,1);
  }finally{await r.close();}
 });
 test('input expiry invalidates epoch and never ACKs a late stale-epoch command',async()=>{
  const r=await rig();try {
   await delay(400);r.input(1,{fire:true});
   await wait(()=>r.snapshots().some(s=>s.frame.acks[0]===1));await delay(400);
   const before=r.snapshots().at(-1).frame.state.actors[0].shots;
   r.input(2,{fire:true});await delay(150);
   assert.equal(r.snapshots().at(-1).frame.state.actors[0].shots,before,'stale epoch rearmed firing');
   assert.equal(r.snapshots().at(-1).frame.acks[0],1);
   assert(r.records.some(s=>s.frame?.type==='horde-input-reset'&&s.frame.reason==='stale-input'));
  }finally{await r.close();}
 });
 test('source string-ID wave event gets unique serial wire identity',async()=>{
  const r=await rig();try {
   await wait(()=>r.snapshots().find(s=>s.frame.state.singleplayer.wave===1),10000);
   const events=r.records.filter(s=>s.frame?.type==='events').flatMap(s=>s.frame.items);
   assert(events.some(e=>e.type==='horde-modifier'&&e.sourceId==='swarm'&&Number.isSafeInteger(e.id)),'genuine source modifier event lost');
   assert.equal(new Set(events.map(e=>e.id)).size,events.length);
  }finally{await r.close();}
 });
 test('oversized frame closes peer gracefully and listener survives',()=>{
  const child=spawnSync(process.execPath,[process.argv[1],'--oversize-child'],{encoding:'utf8',timeout:10000,env:process.env});
  assert.equal(child.status,0,child.stderr);
 });
 test('valid lifecycle-message flood is rate bounded',async()=>{
  const r=await rig(false);try {
   for(let i=0;i<200;i++)r.send({type:'host',mapId:'meridian-exchange',config:{mode:'horde'}});
   await wait(()=>r.ws.readyState===WebSocket.CLOSED,1200);
   assert(r.records.some(s=>s.reason==='Message rate limit'));
  }finally{await r.close();}
 });
 test('outbound backlog limit closes peer (synthetic WebSocket backpressure, not source state)',async()=>{
  const r=await rig(false);try {
   const peer=[...r.authority.wss.clients][0];
   Object.defineProperty(peer,'bufferedAmount',{get:()=>2097152});
   r.send({type:'host',mapId:'meridian-exchange',config:{mode:'horde'}});
   await wait(()=>r.ws.readyState===WebSocket.CLOSED,1200);
   assert(r.records.some(s=>s.reason==='Outbound limit'));
  }finally{await r.close();}
 });
 test('normal-rate clock diagnostic uses measured wall time, not injected time',async()=>{
  const r=await rig();try {
   const first=r.snapshots()[0];await delay(4500);const last=r.snapshots().at(-1);
   const source=last.frame.state.time-first.frame.state.time,wall=(last.observedMs-first.observedMs)/1000;
   console.log('CLOCK_DIAGNOSTIC',JSON.stringify({sourceSeconds:source,wallSeconds:wall,ratio:source/wall}));
   assert(source<=wall+1/30,'source clock is running ahead of wall time');
   assert(source>=wall-.2,'diagnostic environment too slow for a useful clock measurement');
  }finally{await r.close();}
 });
 test('retained failed product run cannot pass acceptance hygiene',()=>{
  const dir='port/reports/horde-independent/evidence/5f80cc71-f9f8-4315-a26c-223395de1d9c';
  const read=name=>gunzipSync(readFileSync(`${dir}/${name}.gz`)).toString();
  const stdout=read('native.stdout.log'),stderr=read('native.stderr.log'),summary=JSON.parse(readFileSync(`${dir}/summary.json`));
  assert.throws(()=>{
   if(validation.validateHygiene)validation.validateHygiene(summary,stdout,stderr);
   else validation.validate(read('wire.jsonl').trim().split('\n').map(JSON.parse),stdout,'combat');
  },'failed harness/resource log accepted');
  assert.throws(()=>{
   if(validation.validateHygiene)validation.validateHygiene({...summary,exit:0},stdout,stderr);
   else validation.validate(read('wire.jsonl').trim().split('\n').map(JSON.parse),stdout,'combat');
  },'resource errors accepted even with nominal exit zero');
 });
}

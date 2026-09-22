import test from 'node:test';
import assert from 'node:assert/strict';
import {WebSocket} from 'ws';
import {Match} from '../../game/core.mjs';
import {EventCursor,createAuthority,MAPS,validateConfig} from './authority.mjs';

const source=(map=MAPS[0],extra={})=>new Match('chatgpt','openclaw',Math.random,map,
 {...validateConfig({mapId:map,config:{mode:'horde'}}),...extra});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function wait(predicate) {
 const end=performance.now()+3000;
 while(performance.now()<end){const result=predicate();if(result)return result;await delay(5);}
 throw Error('Bounded adapter diagnostic timeout');
}
async function rig() {
 const records=[],authority=createAuthority({observe:r=>records.push(r)});
 await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
 const url=`ws://127.0.0.1:${authority.server.address().port}`;
 const sockets=[];
 const connect=async()=>{
  const ws=new WebSocket(url);sockets.push(ws);ws.on('error',()=>{});
  await new Promise((r,j)=>{ws.once('open',r);ws.once('error',j);});
  return ws;
 };
 const send=(ws,frame)=>ws.send(JSON.stringify(frame));
 const start=ws=>{send(ws,{type:'create',v:3});send(ws,{type:'host',mapId:MAPS[0],config:{mode:'horde'}});send(ws,{type:'start'});};
 return {authority,records,connect,send,start,async close(){for(const ws of sockets)ws.terminate();await authority.close();}};
}
const eventFrames=records=>records.filter(r=>r.direction==='out'&&r.frame.type==='events');

test('all supported source constructors expose their initial spawn before stepping',()=>{
 for(const map of MAPS) {
  const match=source(map),cursor=new EventCursor();
  assert.equal(match.time,0);assert.equal(match.events.length,1);
  assert.equal(match.events[0].type,'spawn');
  const initial=JSON.stringify(match.events);
  assert.deepEqual(cursor.take(match),[{...match.events[0],sourceId:match.events[0].id,id:1}]);
  assert.equal(JSON.stringify(match.events),initial);
  assert.deepEqual(cursor.take(match),[]);
 }
});

test('empty cursor reads are inert, and same ring can be read without replay',()=>{
 const cursor=new EventCursor();
 assert.deepEqual(cursor.take({events:[]}),[]);assert.deepEqual(cursor.take({events:[]}),[]);
 const match=source();assert.equal(cursor.take(match)[0].id,1);
 assert.deepEqual(cursor.take(match),[]);
});

test('real source projectile, grenade and sentry serial allocations never replay retained events',()=>{
 const match=source(MAPS[0],{startingWeapon:1}),cursor=new EventCursor();
 cursor.take(match);
 const previous=match.events.at(-1),serial=match.serial;
 // Offline source API fixture: ordinary fixed steps, legal source starting
 // weapon, then source's own sentry method. No direct source state assignments.
 for(let i=0;i<45;i++)match.step(1/60,{inputs:{0:{fire:true,grenade:i===0}}});
 match.deploySentry(match.actors[0],10);
 const fresh=match.events.slice(match.events.indexOf(previous)+1);
 assert(fresh.some(e=>e.type==='launch'),'source projectile allocation not exercised');
 assert(fresh.some(e=>e.type==='grenade'),'source grenade allocation not exercised');
 assert(fresh.some(e=>e.type==='deployable'),'source sentry allocation not exercised');
 assert(match.serial-serial>fresh.length,'source did not allocate non-event serials');
 const originals=JSON.stringify(match.events);
 const actual=cursor.take(match);
 assert.deepEqual(actual,fresh.map((event,i)=>({...event,sourceId:event.id,id:i+2})));
 assert.equal(JSON.stringify(match.events),originals);assert.deepEqual(cursor.take(match),[]);
});

test('source emit may repeat identical string IDs/payloads and overwrite type: both objects must be delivered',()=>{
 const match=source(),cursor=new EventCursor();cursor.take(match);
 match.emit('horde-modifier',{id:'swarm'});match.emit('horde-modifier',{id:'swarm'});
 match.emit('nominal-type',{id:'pad-1',type:'payload-type'});
 const fresh=match.events.slice(-3),originals=JSON.stringify(fresh);
 assert.deepEqual(fresh[0],fresh[1]);assert.notStrictEqual(fresh[0],fresh[1]);
 const actual=cursor.take(match);
 assert.deepEqual(actual.map(e=>[e.id,e.sourceId,e.type]),[[2,'swarm','horde-modifier'],[3,'swarm','horde-modifier'],[4,'pad-1','payload-type']]);
 assert.equal(JSON.stringify(fresh),originals);
});

test('source ring growth and shift retain the last object even at the oldest retained slot',()=>{
 const match=source(),cursor=new EventCursor();cursor.take(match);
 for(let i=0;i<299;i++)match.emit('fixture',{id:'repeat'});
 assert.equal(match.events.length,300);
 assert.equal(cursor.take(match).length,299);
 const previous=match.events.at(-1);
 for(let i=0;i<299;i++)match.emit('fixture',{id:'repeat'});
 assert.strictEqual(match.events[0],previous);
 const next=cursor.take(match);
 assert.equal(next.length,299);assert.equal(next[0].id,301);assert.equal(next.at(-1).id,599);
 assert.deepEqual(cursor.take(match),[]);
});

test('source ring eviction fails closed without advancing cursor or ordinal',()=>{
 const match=source(),cursor=new EventCursor();cursor.take(match);
 for(let i=0;i<300;i++)match.emit('fixture',{id:'repeat'});
 assert.throws(()=>cursor.take(match),/cursor lost/);
 assert.throws(()=>cursor.take(match),/cursor lost/);
 assert.equal(cursor.ordinal,1);
 assert.throws(()=>cursor.take({events:[]}),/cursor lost/);
});

test('lost source ring cursor terminates authority peer and listener accepts a fresh client',async t=>{
 const original=EventCursor.prototype.take;let calls=0;
 t.mock.method(EventCursor.prototype,'take',function(match) {
  // Explicit fault fixture through the unchanged source emit/ring API, after
  // the real construction cursor was consumed. Not a live gameplay attempt.
  if(++calls===2)for(let i=0;i<300;i++)match.emit('overflow-fixture',{id:'repeat'});
  return original.call(this,match);
 });
 const r=await rig();try {
  const ws=await r.connect();r.start(ws);
  await wait(()=>ws.readyState===WebSocket.CLOSED);
  assert(r.records.some(x=>x.direction==='transport-error'&&x.reason==='Authority step failed: Source event ring cursor lost'));
  assert.equal(eventFrames(r.records).length,1,'overflow batch escaped on wire');
  assert(!r.records.some(x=>x.direction==='out'&&x.frame.type==='snapshot'));
  const next=await r.connect();r.start(next);
  await wait(()=>r.records.some(x=>x.round===2&&x.frame?.type==='snapshot'));
  const first=eventFrames(r.records).find(x=>x.round===2);
  assert.deepEqual(first.frame.items.map(e=>[e.id,e.type]),[[1,'spawn']]);
 } finally {await r.close();}
});

test('actual source endMatch lifecycle fixture resets cursor at restart before the first step',async t=>{
 const original=EventCursor.prototype.take,cursors=new Set();let calls=0;
 t.mock.method(EventCursor.prototype,'take',function(match) {
  cursors.add(this);
  // End via source API solely to bound this adapter lifecycle test. Real
  // one-wave victory/restart is separately exercised by the product observer.
  if(++calls===2)match.endMatch('time');
  return original.call(this,match);
 });
 const r=await rig();try {
  const ws=await r.connect();r.start(ws);
  await wait(()=>r.records.some(x=>x.frame?.type==='results'));
  r.send(ws,{type:'start'});
  await wait(()=>r.records.some(x=>x.round===2&&x.frame?.type==='snapshot'));
  assert.equal(cursors.size,2);
  for(const round of [1,2])assert.deepEqual(eventFrames(r.records).find(x=>x.round===round).frame.items.map(e=>[e.id,e.type]),[[1,'spawn']]);
  const initialIndex=r.records.findIndex(x=>x.round===2&&x.frame?.type==='events');
  const stepIndex=r.records.findIndex(x=>x.round===2&&x.direction==='step');
  assert(initialIndex<stepIndex,'construction events not consumed before stepping');
 } finally {await r.close();}
});

test('new client has fresh ordinal and cannot replay prior client grenade events',async()=>{
 const r=await rig();try {
  const ws=await r.connect();r.start(ws);
  const snapshot=await wait(()=>r.records.find(x=>x.direction==='out'&&x.frame.type==='snapshot'));
  r.send(ws,{type:'input',seq:1,inputEpoch:snapshot.frame.inputEpoch,input:{grenade:true}});
  await wait(()=>eventFrames(r.records).some(x=>x.frame.items.some(e=>e.type==='grenade')));
  ws.terminate();await wait(()=>r.authority.wss.clients.size===0);
  const next=await r.connect();r.start(next);
  await wait(()=>r.records.some(x=>x.round===2&&x.frame?.type==='snapshot'));
  const fresh=eventFrames(r.records).filter(x=>x.round===2).flatMap(x=>x.frame.items);
  assert.deepEqual(fresh.map(e=>[e.id,e.type]),[[1,'spawn']]);
 } finally {await r.close();}
});

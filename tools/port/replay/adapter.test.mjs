import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync,writeFileSync,symlinkSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {randomBytes,createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {Match} from '../../../game/core.mjs';
import {Room} from '../../../server/room.mjs';
import {applySnapshotDelta} from '../../../game/protocol.mjs';
import {DemoRecorder,DemoPlayer,serializeDemo,trimDemo} from '../../../game/demo.mjs';
import {normalizeMap} from '../../godot-export/semantic.mjs';
import {MAPS} from '../../../game/maps.mjs';
import {Capture,Playback,Library,LocalReplay,ADMISSION,LIMIT,decode,validateDemo,visualState,verifySourceModule} from './adapter.mjs';

const options={mapId:'meridian-exchange',mode:'deathmatch',role:'seated'};
function fixture() {
  const match=new Match('chatgpt','openclaw',()=>.4,options.mapId,{mode:options.mode,botCount:0});
  const recorder=new DemoRecorder({recordHz:18});
  for(let i=0;i<13;i++) {match.step(1/60,{inputs:{0:{forward:1,yaw:3.12,fire:true}}});recorder.frame(match.snapshot(),match.events);}
  // Network/native/file boundary is JSON: source snapshots have optional undefined keys.
  return JSON.parse(serializeDemo(recorder.finish({createdAt:'2026-10-02T00:00:00.000Z'})));
}
const temporary=()=>mkdtempSync(join(process.env.TMPDIR??tmpdir(),'replay-test-'));

test('original source demo module/core and exact semantic catalog hashes remain pinned',()=>{
  verifySourceModule();
  const hash=x=>createHash('sha256').update(x).digest('hex');
  assert.equal(hash(readFileSync(new URL('../../../game/core.mjs',import.meta.url))),ADMISSION.coreSha256);
  assert.equal(hash(readFileSync(new URL('../../../port/contracts/source-lock.json',import.meta.url))),ADMISSION.sourceContractSha256);
  assert.equal(hash(readFileSync(new URL('../../../port/contracts/lattice-catalog-derivative.json',import.meta.url))),ADMISSION.derivativeContractSha256);
  assert.equal(hash(JSON.stringify(normalizeMap(MAPS.find(m=>m.id===options.mapId)))+'\n'),ADMISSION.maps[options.mapId].semanticSha256);
});
test('actual source DemoRecorder JSON and gzip import round-trip byte semantics',()=>{
  const demo=fixture();
  assert.deepEqual(decode(serializeDemo(demo)),demo);
  assert.deepEqual(decode(gzipSync(serializeDemo(demo))),demo);
});
test('capture uses source rounding, dedupe and trim without a second simulation',()=>{
  const d=fixture(),capture=new Capture(options),oracle=new DemoRecorder({recordHz:18,maxSeconds:600});
  for(const {state} of d.keyframes) {capture.frame({state,events:d.events,role:'seated'});oracle.frame(state,d.events);}
  const result=capture.finish(.1),expected=trimDemo(oracle.finish(),.1);
  assert.deepEqual(result.keyframes,expected.keyframes);assert.deepEqual(result.events,expected.events);
  assert.equal(result.meta.nativeReplay.stream,'delivered-client-snapshots');
});
test('exact seeks, actor membership and yaw wrap are source DemoPlayer results',()=>{
  const d=fixture();d.keyframes=d.keyframes.slice(0,2);d.keyframes[0].time=d.keyframes[0].state.time=40;d.keyframes[1].time=d.keyframes[1].state.time=42;
  Object.assign(d.keyframes[0].state.actors[0],{x:2,yaw:3.12});Object.assign(d.keyframes[1].state.actors[0],{x:10,yaw:-3.12});
  const p=new Playback(d),source=new DemoPlayer(d);
  for(const time of [-1,0,.25,1,1.99,2,99]) assert.deepEqual(p.command({op:'seek',time}).state,visualState(source.sample(time)));
  const middle=p.command({op:'seek',time:1}).state.actors[0];assert.equal(middle.x,6);assert.ok(Math.abs(middle.yaw-Math.PI)<.0001);
});
test('absolute event clock, no duplicate ticks, seek clears and speed suppresses cue bursts',()=>{
  const d=fixture();for(let i=0;i<d.keyframes.length;i++){d.keyframes[i].time=d.keyframes[i].state.time=20+i;}
  d.events=[{id:1,type:'shot',actor:0,weapon:0,time:20.05},{id:2,type:'death',actor:0,time:20.1}];
  const p=new Playback(d);p.command({op:'play'});
  assert.equal(p.command({op:'tick',dt:.1}).events.length,2);
  assert.equal(p.command({op:'tick',dt:0}).events.length,0);
  const seek=p.command({op:'seek',time:0});assert.equal(seek.clear,true);assert.deepEqual(seek.events,[]);
  p.command({op:'speed',speed:4});assert.deepEqual(p.command({op:'tick',dt:.1}).events,[]);
  p.command({op:'pause'});const t=p.clock.time;p.command({op:'tick',dt:.2});assert.equal(p.clock.time,t);
  p.command({op:'seek',time:999});assert.equal(p.command({op:'sample'}).phase,'ended');
});
test('source birth/despawn, discrete bodyYaw and single-frame semantics retained',()=>{
  const d=fixture();d.keyframes=d.keyframes.slice(0,2);
  const first=d.keyframes[0].state.actors[0],next=d.keyframes[1].state.actors[0];
  first.bodyYaw=1;next.bodyYaw=2;
  d.keyframes[0].state.actors.push({...first,id:8});
  d.keyframes[1].state.actors.push({...next,id:9});
  const p=new Playback(d),source=new DemoPlayer(d),time=p.clock.duration/2;
  const sampled=p.command({op:'seek',time}).state;
  assert.deepEqual(sampled,visualState(source.sample(time)));
  assert.deepEqual(sampled.actors.map(a=>a.id),[0,9]);assert.equal(sampled.actors[0].bodyYaw,1);
  d.keyframes=d.keyframes.slice(0,1);
  const only=new Playback(d);assert.equal(only.clock.duration,0);assert.deepEqual(only.command({op:'sample'}).state,visualState(new DemoPlayer(d).sample(0)));
});
test('unknown map/mode, mismatch and forged provenance refuse rather than fallback',()=>{
  for(const mutate of [d=>d.header.mapId='../meridian-exchange',d=>d.header.config.mode='campaign',d=>d.keyframes[0].state.mapId='exchange',d=>d.meta.nativeReplay={version:1,semanticSha256:'0'.repeat(64)}]) {
    const d=fixture();mutate(d);assert.throws(()=>validateDemo(d));
  }
});
test('malformed finite numbers/counts/identity and credential or prototype payloads rejected',()=>{
  for(const mutate of [d=>d.version=2,d=>d.keyframes=[],d=>d.keyframes[0].state.actors[0].x=Infinity,d=>d.keyframes[0].state.actors[0].health={},d=>d.keyframes[0].state.actors.push(d.keyframes[0].state.actors[0]),d=>d.events=[{id:1,time:1,type:'shot'},{id:1,time:2,type:'shot'}],d=>d.keyframes[1].time=d.keyframes[0].time,d=>d.meta.token='credential',d=>d.keyframes[0].state.actors=Array(65).fill(d.keyframes[0].state.actors[0]),d=>d.events=Array(LIMIT.events+1).fill({time:1,type:'shot'})]) {
    const d=fixture();mutate(d);assert.throws(()=>validateDemo(d));
  }
  assert.throws(()=>decode('{"version":1,"__proto__":{"polluted":true}}'));
  assert.throws(()=>decode('not JSON'));assert.equal({}.polluted,undefined);
});
test('zip bomb and oversized input bounded before source parsing',()=>{
  assert.throws(()=>decode(Buffer.alloc(LIMIT.bytes+1)));
  assert.throws(()=>decode(gzipSync(Buffer.alloc(LIMIT.bytes+1,32))));
});
test('role and round reset stop capture; no private fields projected into replay HUD',()=>{
  const state=fixture().keyframes[0].state,c=new Capture(options);
  c.frame({state,role:'seated'});
  assert.throws(()=>c.frame({state,role:'spectator'}),/role changed/);
  assert.throws(()=>c.frame({state:{...state,time:0},role:'seated'}),/Round changed/);
  const projected=visualState(state);assert.equal(projected.actors[0].ammo,undefined);assert.equal(projected.actors[0].movement,undefined);
});
test('library saves unique clips, preserves originals, reports corrupt files and rejects paths/symlinks',()=>{
  const root=temporary();try {
    const lib=new Library(root),d=fixture(),a=lib.save(d),b=lib.save(d);assert.notEqual(a.id,b.id);assert.equal(lib.list().length,2);
    assert.throws(()=>lib.read('../demo.json'));
    writeFileSync(join(root,a.id),'broken');assert.match(lib.list().find(r=>r.id===a.id).error,/JSON/);assert.deepEqual(lib.read(b.id),d);
    const link='clip-00000000-0000-0000-0000-000000000000.json';symlinkSync(join(root,b.id),join(root,link));assert.throws(()=>lib.read(link),/regular/);
  } finally {rmSync(root,{recursive:true,force:true});}
});
test('actual recipient Room protocol snapshots capture exactly, excluding welcome tickets and authority-only sentinels',()=>{
  const room=new Room('replay-recipient',()=>.4,{snapshotHz:18});room.join(1,'Seat');room.join(2,'Public','chatgpt','openclaw','',true);
  room.host(1,{mode:'deathmatch',botCount:0,timeLimit:30},options.mapId);room.start(1);
  room.match.authorityOnlySentinel='NOT_DELIVERED';
  const captures=[new Capture(options),new Capture({...options,role:'spectator'})],oracles=[new DemoRecorder({recordHz:18}),new DemoRecorder({recordHz:18})];
  const latest=[null,null],pending=[[],[]];let delivered=0;
  function drain() {
    for(const envelope of room.drain()) for(let i=0;i<2;i++) {
      if(envelope.to!==null&&envelope.to!==i+1)continue;
      const msg=JSON.parse(JSON.stringify(envelope.msg));
      if(msg.type==='events')pending[i].push(...msg.items);
      if(msg.type==='snapshot'&&msg.state)latest[i]=msg.state;
      else if(msg.type==='snapshot'&&msg.delta)latest[i]=applySnapshotDelta(latest[i],msg.delta);
      else if(msg.type==='start'&&msg.state)latest[i]=msg.state;
      else continue;
      if(!latest[i])continue;
      captures[i].frame({state:latest[i],events:pending[i],role:i?'spectator':'seated'});oracles[i].frame(latest[i],pending[i]);pending[i]=[];delivered++;
    }
  }
  drain();for(let i=0;i<60;i++){room.input(1,{seq:i+1,forward:1,yaw:.3,fire:i%9===0});room.tick(1/60);drain();}
  assert.ok(delivered>=20);
  for(let i=0;i<2;i++) {
    const d=captures[i].finish();assert.deepEqual(d.keyframes,oracles[i].keyframes);assert.deepEqual(d.events,oracles[i].events);
    const text=serializeDemo(d);assert.ok(!text.includes('NOT_DELIVERED'));assert.ok(!text.includes('resumeToken'));assert.equal(d.meta.nativeReplay.role,i?'spectator':'seated');
  }
  // Meridian has no team-private intel projection. Unsupported COCS is rejected,
  // rather than pretending this combat admission proves LATTICE private replay.
  assert.throws(()=>new Capture({...options,mode:'cocs'}),/Unsupported/);
});
test('read-only API rejects all authority/input/progression verbs',()=>{
  const root=temporary();try {
    const local=new LocalReplay(root);const clip=local.dispatch({op:'import',text:serializeDemo(fixture())}).clip;
    local.dispatch({op:'open',id:clip.id});
    for(const op of ['input','host','join','start','awardMatch','command','buy','loadScript']) assert.throws(()=>local.dispatch({op}));
    assert.deepEqual(local.library.ids(),[clip.id]);
    for(const op of ['play','pause','sample'])assert.ok(local.dispatch({op}).state);
  }finally{rmSync(root,{recursive:true,force:true});}
});
test('bounded native packet batching retains source capture order/due decisions',()=>{
  const root=temporary();try {
    const local=new LocalReplay(root),oracle=new Capture(options),frames=fixture().keyframes.map(({state})=>({state,events:[],role:'seated'}));
    local.dispatch({op:'record',...options});
    local.dispatch({op:'frames',frames});for(const frame of frames)oracle.frame(frame);
    assert.deepEqual(local.capture.finish().keyframes,oracle.finish().keyframes);
    assert.throws(()=>local.dispatch({op:'frames',frames:Array(33).fill(frames[0])}),/capture batch/);
  }finally{rmSync(root,{recursive:true,force:true});}
});
test('actual bounded loopback service authentication, record/save/open/seek/discard lifecycle',async()=>{
  const root=temporary(),ready=join(root,'ready.json'),token=randomBytes(32).toString('hex');
  const child=spawn(process.execPath,[new URL('./service.mjs',import.meta.url).pathname,root,ready,token],{stdio:'pipe'});
  try {
    for(let i=0;i<100&&!existsSync(ready);i++)await new Promise(r=>setTimeout(r,20));
    assert.ok(existsSync(ready));const {port}=JSON.parse(readFileSync(ready));const url=`http://127.0.0.1:${port}/replay`;
    const request=async(body,auth=token)=>(await fetch(url,{method:'POST',headers:{authorization:`Bearer ${auth}`},body:JSON.stringify(body)}));
    assert.equal((await request({op:'list'},'bad')).status,403);
    assert.equal((await (await request({op:'record',...options})).json()).ok,true);
    for(const {state} of fixture().keyframes)assert.equal((await (await request({op:'frame',state,events:[],role:'seated'})).json()).ok,true);
    const save=await(await request({op:'save'})).json();assert.equal(save.ok,true);
    assert.equal((await(await request({op:'open',id:save.clip.id})).json()).phase,'paused');
    assert.equal((await(await request({op:'seek',time:.05})).json()).time,.05);
    assert.equal((await(await request({op:'close'})).json()).closed,true);
    await request({op:'record',...options});assert.equal((await(await request({op:'discard'})).json()).recording,false);
    assert.equal((await(await request({op:'list'})).json()).clips.length,1);
  } finally {child.kill();await new Promise(r=>child.once('exit',r));rmSync(root,{recursive:true,force:true});}
});

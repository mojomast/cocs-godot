import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createAuthority} from './authority.mjs';

async function connect(t, options={}) {
  const mapId=options.mapId??'rootfall-verge';
  const observed=[],authority=createAuthority({...options,observe:event=>observed.push(event),random:()=>.5});
  t.after(()=>authority.close());
  authority.server.listen(0,'127.0.0.1');await once(authority.server,'listening');
  const port=authority.server.address().port;
  const ws=new WebSocket(`ws://127.0.0.1:${port}/native-campaign`),frames=[];
  ws.on('message',bytes=>frames.push(JSON.parse(String(bytes))));
  await once(ws,'open');
  const send=frame=>ws.send(JSON.stringify(frame));
  async function wait(predicate) {
    const existing=frames.find(predicate);if(existing)return existing;
    return new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>{ws.off('message',message);reject(new Error('Campaign frame timeout'));},10000);
      function message(bytes){const frame=JSON.parse(String(bytes));if(predicate(frame)){clearTimeout(timeout);ws.off('message',message);resolve(frame);}}
      ws.on('message',message);
    });
  }
  send({type:'create',v:3,delta:0,nativeArenaInput:1,playerName:'Campaign test'});await wait(f=>f.type==='welcome');
  send({type:'host',mapId,config:{mode:'campaign',difficulty:'normal',botCount:0,timeLimit:900,fragLimit:5}});
  await wait(f=>f.type==='lobby'&&f.mapId===mapId);
  send({type:'start'});const start=await wait(f=>f.type==='start');
  return {authority,ws,frames,send,wait,start,observed,port};
}
test('NativeClient v3 handshake, cancellation, restart epoch, stale packet rejection',async t=>{
  const c=await connect(t),epoch=c.start.inputEpoch;
  const health=await fetch(`http://127.0.0.1:${c.port}/`).then(r=>r.json());
  assert.equal(health.service,'cocs-native-campaign');
  c.send({type:'input',seq:1,inputEpoch:epoch,input:{x:1,fire:true}});
  await c.wait(f=>f.type==='snapshot'&&f.acks?.[0]===1);
  c.send({type:'input',seq:2,inputEpoch:epoch,cancel:true,input:{}});
  await c.wait(f=>f.type==='snapshot'&&f.acks?.[0]===2);
  c.send({type:'campaign-action',action:'restart',inputEpoch:epoch});
  const restarted=await c.wait(f=>f.type==='start'&&f.inputEpoch>epoch);
  c.send({type:'input',seq:99,inputEpoch:epoch,input:{x:1,fire:true}});
  c.send({type:'input',seq:1,inputEpoch:restarted.inputEpoch,input:{}});
  const next=await c.wait(f=>f.type==='snapshot'&&f.inputEpoch===restarted.inputEpoch&&f.acks?.[0]===1);
  assert.equal(next.nativeArenaInput.receivedSeq,1);
  assert.equal(next.state.campaign.stepIndex,0);
  assert.ok(c.observed.some(e=>e.direction==='step'&&e.inputSeq===2&&!e.controls.fire&&!e.controls.x));
});
test('stale held controls expire, advance epoch, and never remain firing',async t=>{
  const c=await connect(t);
  c.send({type:'input',seq:1,inputEpoch:c.start.inputEpoch,input:{fire:true,x:1}});
  const reset=await c.wait(f=>f.type==='native-arena-input-reset'&&f.reason==='stale-input');
  assert.ok(reset.inputEpoch>c.start.inputEpoch);
  const frame=await c.wait(f=>f.type==='snapshot'&&f.inputEpoch===reset.inputEpoch);
  assert.equal(frame.nativeArenaInput.queueDepth,0);
  assert.ok(c.observed.some(e=>e.direction==='step'&&e.inputEpoch===reset.inputEpoch&&!e.controls.fire&&!e.controls.x));
});
test('wire cannot select arbitrary geometry or non-finite controls',async t=>{
  const c=await connect(t);
  const closed=once(c.ws,'close');
  c.ws.send(`{"type":"input","seq":1,"inputEpoch":${c.start.inputEpoch},"input":{"x":1e999}}`);
  await closed;
  assert.ok(c.observed.some(e=>e.direction==='transport-error'&&e.reason.includes('Non-finite')));
});
test('final Continue emits fresh same-map start then terminal results without reconstruction',async t=>{
  let constructions=0,phase='playing';
  const fake={actors:[{id:0,health:100}],events:[],time:17,over:false,
    step(){phase='level-complete';this.over=true;},
    completeCampaign(){phase='campaign-complete';},
    snapshot(){return {campaign:{mapId:'crown-array',phase,nextMapId:null,elapsed:17,totalElapsed:83,kills:27}};}};
  const c=await connect(t,{mapId:'crown-array',matchFactory:()=>{constructions++;return fake;}});
  const completed=await c.wait(f=>f.type==='results'&&f.state.campaign.phase==='level-complete');
  c.send({type:'campaign-action',action:'continue',inputEpoch:completed.inputEpoch});
  const final=await c.wait(f=>f.type==='results'&&f.state.campaign.phase==='campaign-complete');
  const index=c.frames.indexOf(final),start=c.frames[index-1];
  assert.equal(start.type,'start');assert.equal(start.mapId,'crown-array');
  assert.equal(start.geometryHash,c.start.geometryHash);
  assert.ok(start.inputEpoch>completed.inputEpoch);assert.ok(start.roundRevision>c.start.roundRevision);
  assert.equal(final.inputEpoch,start.inputEpoch);assert.equal(final.seq,1);
  assert.equal(final.state.campaign.totalElapsed,83);assert.equal(final.state.campaign.kills,27);
  assert.equal(constructions,1);
  // A stale duplicate cannot start another terminal round.
  c.send({type:'campaign-action',action:'continue',inputEpoch:completed.inputEpoch});
  c.send({type:'ping',t:5678});await c.wait(f=>f.type==='pong'&&f.t===5678);
  assert.equal(c.frames.filter(f=>f.type==='start').length,2);
});

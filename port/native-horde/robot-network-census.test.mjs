import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createAuthority,HORDE_MAPS} from './authority.mjs';
import {ROBOT_FOR_ROLE,ROBOT_SILHOUETTE} from './robot-roles.mjs';

async function connect(authority,mapId,waves=10){
 const socket=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}`);
 const frames=[];const pending=new Set();
 socket.on('message',bytes=>{
  const frame=JSON.parse(String(bytes));
  frames.push(frame);
  for(const waiter of pending)if(waiter.predicate(frame)){pending.delete(waiter);waiter.resolve(frame);}
 });
 await once(socket,'open');
 const wait=(predicate,timeoutMs=14000)=>{
  const seen=frames.find(predicate);if(seen)return Promise.resolve(seen);
  return new Promise((resolve,reject)=>{
   const waiter={predicate,resolve:frame=>{clearTimeout(timer);resolve(frame)}};
   const timer=setTimeout(()=>{pending.delete(waiter);reject(Error(`Horde wire timeout ${mapId}: ${frames.at(-1)?.type??'no frames'}`));},timeoutMs);
   pending.add(waiter);
  });
 };
 const send=frame=>socket.send(JSON.stringify(frame));
 send({type:'create',v:3});
 await wait(f=>f.type==='lobby');
 send({type:'host',mapId,config:{mode:'horde',fragLimit:waves}});
 await wait(f=>f.type==='lobby'&&f.mapId===mapId&&f.config);
 send({type:'start'});
 const start=await wait(f=>f.type==='start');
 return {socket,frames,wait,start,send,close:async()=>{
  if(socket.readyState!==WebSocket.CLOSED){socket.close();await once(socket,'close');}
  for(const waiter of pending)waiter.resolve({type:'closed'});
 }};
}

test('live network census: every Horde arena sends only six-class robots for source NPCs',
 {timeout:110000},async()=>{
  for(const mapId of HORDE_MAPS){
   const authority=createAuthority();
   await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
   let client;
   try{
    client=await connect(authority,mapId);
    const snap=await client.wait(f=>f.type==='snapshot'&&f.inputEpoch===client.start.inputEpoch&&
      f.state.actors.some(a=>a.isNpc),12000);
    const npcs=snap.state.actors.filter(a=>a.isNpc),human=snap.state.actors.find(a=>a.id===0);
    assert(npcs.length>=2,mapId+' lacked a real source wave');
    assert(human&&!human.npcModel&&!human.isNpc,mapId+' replaced the operator');
    for(const actor of npcs){
     assert.equal(actor.npcModel,ROBOT_FOR_ROLE[actor.npcType],mapId);
     assert.equal(actor.hitScale,ROBOT_SILHOUETTE[actor.npcType].hitScale,mapId);
     assert.equal(actor.npcProfile.scale,ROBOT_SILHOUETTE[actor.npcType].scale,mapId);
     assert(actor.health>0&&actor.maxHealth>0,mapId);
    }
    if(mapId==='blackwater-reclamation')assert.equal(snap.state.blackwater.version,1);
   }finally{if(client)await client.close();await authority.close();}
  }
});

test('solo reconnect starts a new authoritative Blackwater session; it is not a late join',
 {timeout:10000},async()=>{
  const authority=createAuthority();
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  let first,second;
  try{
   first=await connect(authority,'blackwater-reclamation');
   const before=await first.wait(f=>f.type==='snapshot');
   assert.deepEqual(before.state.blackwater.completed,[]);
   await first.close();
   second=await connect(authority,'blackwater-reclamation');
   const after=await second.wait(f=>f.type==='snapshot');
   assert.deepEqual(after.state.blackwater.completed,[]);
   assert.equal(after.state.blackwater.serial,0);
   assert.equal(after.state.singleplayer.stage.stageId,'A');
   assert(after.inputEpoch>before.inputEpoch,'new session must invalidate old input epoch');
  }finally{if(second)await second.close();if(first)await first.close();await authority.close();}
});

test('Blackwater feeder can be armed and restored by actual loopback movement + E input',
 {timeout:40000},async()=>{
  const authority=createAuthority();
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  let client,timer,seq=0,armed=false;
  try{
   client=await connect(authority,'blackwater-reclamation');
   const initial=await client.wait(f=>f.type==='snapshot');
   const target={x:-170,z:78};
   // One reviewed human spawn is south of the five-metre gantry. Approach its
   // real south ramp head-on before climbing instead of steering into the rail.
   const approach=initial.state.actors[0].z < -8 ? {x:-170,z:-40} : null;
   let rampReached=!approach;
   timer=setInterval(()=>{
    const frame=client.frames.findLast(f=>f.type==='snapshot'&&f.inputEpoch===client.start.inputEpoch);
    if(!frame)return;
    const p=frame.state.actors.find(a=>a.id===0);
    if(!p||p.health<=0)return;
    if(!rampReached&&Math.hypot(approach.x-p.x,approach.z-p.z)<2.5)rampReached=true;
    const waypoint=rampReached?target:approach;
    const dx=waypoint.x-p.x,dz=waypoint.z-p.z,distance=Math.hypot(dx,dz);
    const near=rampReached&&distance<4.5;
    const interact=near&&!armed;
    if(interact)armed=true;
    client.send({type:'input',seq:++seq,inputEpoch:client.start.inputEpoch,input:{
      x:near?0:dx/distance,z:near?0:dz/distance,sprint:!near,interact,
      yaw:Math.atan2(-dx,-dz),pitch:0}});
   },40);
   let done;
   try{done=await client.wait(f=>f.type==='snapshot'&&f.state.blackwater?.completed?.includes('north-feeder'),35000);}
   catch(error){
    const last=client.frames.findLast(f=>f.type==='snapshot');
    throw Error(`${error.message} ${JSON.stringify({armed,seq,player:last?.state?.actors?.[0]&&{
     x:last.state.actors[0].x,y:last.state.actors[0].y,z:last.state.actors[0].z,
     vx:last.state.actors[0].vx,vz:last.state.actors[0].vz,grounded:last.state.actors[0].grounded,health:last.state.actors[0].health},
     phase:last?.state?.singleplayer?.phase,wave:last?.state?.singleplayer?.wave,
     station:last?.state?.blackwater?.stations?.[0],input:last?.hordeInput,
     events:client.frames.filter(f=>f.type==='events').flatMap(f=>f.items.map(e=>e.type)).slice(-12)})}`);
   }
   assert(armed,'human must reach and arm the station');
   assert(done.state.actors[0].health>0,'human survived the genuine approach and hold');
   assert(done.state.blackwater.serial>=1);
   assert(client.frames.some(f=>f.type==='events'&&f.items.some(e=>e.type==='blackwater-station-armed')));
   assert(client.frames.some(f=>f.type==='events'&&f.items.some(e=>e.type==='blackwater-station-restored')));
   assert(done.hordeInput.appliedSeq>0,'input went through the authority FIFO');
   const priorEpoch=done.inputEpoch;
   clearInterval(timer);timer=null;
   await client.close();
   client=await connect(authority,'blackwater-reclamation');
   const restarted=await client.wait(f=>f.type==='snapshot');
   assert.deepEqual(restarted.state.blackwater.completed,[],'confirmed repair cannot leak into a new solo session');
   assert(restarted.inputEpoch>priorEpoch);
  }finally{if(timer)clearInterval(timer);if(client)await client.close();await authority.close();}
});

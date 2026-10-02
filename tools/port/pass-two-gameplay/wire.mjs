// Source-only real-wire journey. Scripted Node clients, NOT native/human proof.
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {WebSocket} from 'ws';
import {createGameServer} from '../../../server/game-server.mjs';
const out=resolve(process.env.EVIDENCE_DIR??'/home/mojo/.tmp-on-disk/cocs-pass-two-gameplay-evidence-20261002/wire');
mkdirSync(out,{recursive:true});
const game=createGameServer({random:()=>.5,tickMs:4,historyPath:null,progressionPath:null});
const sockets=[],trace=[];
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
async function connect(name) {
  const ws=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);sockets.push(ws);
  const queue=[],waiters=[];
  let sequence=0;
  const client={ws,onSnapshot:null,send(frame){trace.push({name,direction:'input',frame:{...frame,token:frame.token?'REDACTED':undefined}});ws.send(JSON.stringify(frame));},input(input){client.send({type:'input',seq:++sequence,input});},until(predicate){
    const i=queue.findIndex(predicate);if(i>=0)return Promise.resolve(queue.splice(i,1)[0]);
    return new Promise((resolve,reject)=>{const waiter={predicate,resolve,timer:setTimeout(()=>{waiters.splice(waiters.indexOf(waiter),1);reject(Error(name+' frame deadline'));},20000)};waiters.push(waiter);});
  }};
  ws.on('message',raw=>{
    const frame=JSON.parse(raw),redacted={...frame};
    for(const key of ['token','progressToken'])if(key in redacted)redacted[key]='REDACTED';
    trace.push({name,direction:'source',frame:redacted});
    if(frame.type==='snapshot')client.onSnapshot?.(frame);
    const i=waiters.findIndex(w=>w.predicate(frame));
    if(i>=0){const w=waiters.splice(i,1)[0];clearTimeout(w.timer);w.resolve(frame);}else{queue.push(frame);if(queue.length>200)queue.shift();}
  });
  await new Promise((r,j)=>{ws.once('open',r);ws.once('error',j);});
  return client;
}
const report={label:'SCRIPTED NODE SOURCE WIRE; NOT NATIVE OR HUMAN',clock:'tickMs=4, unchanged source dt=1/60; not performance evidence'};
try {
  let host=await connect('host');
  host.send({type:'create',name:'Second pass rope',playerName:'Owner',character:'qwen',harness:'codex',v:3,delta:0});
  const welcome=await host.until(f=>f.type==='welcome');
  const guest=await connect('guest');
  guest.send({type:'join',roomId:welcome.roomId,name:'Rider',character:'mistral',harness:'codex',v:3,delta:0});
  await guest.until(f=>f.type==='welcome');
  host.send({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0,timeLimit:180,fragLimit:100}});
  await host.until(f=>f.type==='lobby'&&f.mapId==='meridian-exchange'&&f.config?.botCount===0);
  const route=[{x:44,z:-34},{x:-44,z:-34}];
  let waypoint=0,placed=false,ride=null,last=null;
  guest.onSnapshot=frame=>{
    last=frame;
    const owner=frame.state.actors[0],rider=frame.state.actors[1];
    if(!placed&&Math.hypot(rider.x-owner.x,rider.z-owner.z)<25){placed=true;host.input({yaw:0,pitch:-.35,mobility:true,power:true});}
    else if(placed)host.input({yaw:0,pitch:-.35});
    if(rider.zipRide?.id?.startsWith('rope-'))ride??={time:frame.state.time,owner:owner.id,rider:rider.id,id:rider.zipRide.id};
    const target=route[waypoint];
    let input={};
    if(target&&!ride){const dx=target.x-rider.x,dz=target.z-rider.z,d=Math.hypot(dx,dz);if(d<.4)waypoint++;else input={x:dx/d,z:dz/d};}
    guest.input(input);
  };
  host.send({type:'start'});
  await guest.until(f=>f.type==='snapshot'&&ride!==null&&f.state.actors[1].zipRide===null);
  assert.notEqual(ride.owner,ride.rider);report.ride=ride;
  guest.onSnapshot=null;
  host.ws.terminate();
  host=await connect('owner-resumed');
  host.send({type:'join',roomId:welcome.roomId,token:welcome.token,v:3,delta:0});
  const resumed=await host.until(f=>f.type==='snapshot');
  assert.ok(resumed.state.actors[0].movement.anchor,'source reconnect retains live owner anchor');
  report.resumed=true;
  // Walk the rider off the endpoint before ordinary aimed primary fire.
  const until=last.state.time+.5;
  guest.onSnapshot=frame=>{
    const [owner,rider]=frame.state.actors;
    if(frame.state.time<until){guest.input({x:1});return;}
    const dx=owner.x-rider.x,dz=owner.z-rider.z,dy=(owner.y+owner.eyeHeight)-(rider.y+rider.eyeHeight);
    guest.input({yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(dy,Math.hypot(dx,dz)),fire:true,reload:rider.ammo[rider.weapon]<=0});
  };
  const death=await guest.until(f=>f.type==='snapshot'&&f.state.actors[0].health<=0);
  assert.equal(death.state.actors[0].movement.anchor,null,'death clears source rope anchor');
  report.death={time:death.state.time,owner:death.state.actors[0].id,anchor:null};
  guest.onSnapshot=null;
  guest.input({});
  console.log('SECOND_PASS_WIRE_OK',JSON.stringify(report));
} catch(error) {
  report.failure=String(error.stack??error);throw error;
} finally {
  writeFileSync(resolve(out,'trace.json'),JSON.stringify(trace));
  writeFileSync(resolve(out,'report.json'),JSON.stringify(report,null,2));
  for(const socket of sockets)socket.terminate();
  await game.close();
}

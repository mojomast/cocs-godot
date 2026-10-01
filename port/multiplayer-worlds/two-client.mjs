#!/usr/bin/env node
// Network transport proof: two distinct WebSockets, real source Room/Match,
// snapshot-driven objective deltas, spectator late join, and fresh-round reset.
import assert from 'node:assert/strict';
import {WebSocket} from 'ws';
import {createGameServer} from './derived/game-server.mjs';
import {readWorld,worldEntry} from './catalog.mjs';

const game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
const url=`ws://127.0.0.1:${game.server.address().port}`;
const peers=[];
async function peer(){
 const ws=new WebSocket(url);await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject)});
 const messages=[],waiters=[];ws.on('message',bytes=>{const item=JSON.parse(String(bytes));messages.push(item);for(const wake of waiters.splice(0))wake();});
 const client={ws,messages,send:frame=>ws.send(JSON.stringify(frame)),async next(type,after=0,ms=20000){
  const until=Date.now()+ms;
  while(Date.now()<until){const found=messages.slice(after).find(m=>m.type===type);if(found)return found;
   await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>{const i=waiters.indexOf(resolve);if(i>=0)waiters.splice(i,1);resolve()},Math.min(500,until-Date.now()));waiters.push(()=>{clearTimeout(timeout);resolve()});});}
  throw Error(`Timeout waiting for ${type}, latest=${JSON.stringify(messages.slice(-3)).slice(0,300)}`);
 }};
 peers.push(client);return client;
}
const evidence=[];
try {
 for(const [id,mode] of [['switchyard-ward','ctf'],['switchyard-ward','domination'],['rainmarket-exchange','payload']]){
  worldEntry(id,mode);
  const hash=readWorld(id).geometryHash,host=await peer(),guest=await peer();
  host.send({type:'create',v:3,name:'Urban test',playerName:'Host',character:'chatgpt',harness:'openclaw'});
  const welcome=await host.next('welcome');
  guest.send({type:'join',v:3,roomId:welcome.roomId,name:'Guest',character:'gemini',harness:'openclaw'});
  const guestWelcome=await guest.next('welcome');
  assert.notEqual(welcome.peerId,guestWelcome.peerId);
  host.send({type:'host',mapId:id,config:{mode,botCount:0,timeLimit:60,fragLimit:mode==='ctf'?2:mode==='payload'?3:mode==='domination'?30:3}});
  await host.next('lobby',host.messages.length-1);
  host.send({type:'start'});
  const start=await host.next('start'),guestStart=await guest.next('start');
  assert.equal(start.geometryHash,hash);assert.equal(guestStart.geometryHash,hash);
  const a=await host.next('snapshot'),b=await guest.next('snapshot');
  assert.equal(a.state.mapId,id);assert.equal(b.state.mapId,id);
  assert.equal(a.state.actors.length,2);assert.equal(b.state.actors.length,2);
  const late=await peer();late.send({type:'join',v:3,roomId:welcome.roomId,name:'Late'});
  const lateWelcome=await late.next('welcome');assert.equal(lateWelcome.spectate,true);
  const lateStart=await late.next('start');assert.equal(lateStart.geometryHash,hash);
  const lateSnapshot=await late.next('snapshot');assert.equal(lateSnapshot.state.mapId,id);
  // A controlled authority-only objective exercise keeps the socket tests
  // bounded. Simulation rules still own every transition: no wire packet can
  // inject positions/objectives. Movement-to-objective is audited separately.
  const room=game.registry.get(welcome.roomId),match=room.match;
  let before,after;
  if(mode==='ctf'){
   before=match.snapshot().teamScores[0];
   const carrier=match.actors[0],enemy=match.flagSpawns[1],home=match.flagSpawns[0];
   carrier.x=enemy[0];carrier.z=enemy[1];carrier.y=0;
   match.objective(carrier);
   assert.equal(match.flags[1].state,'carried');
   carrier.x=home[0];carrier.z=home[1];carrier.y=0;
   match.objective(carrier);
   after=match.snapshot().teamScores[0];assert.ok(after>before);
  } else if(mode==='domination'){
   const actor=match.actors[0],zone=match.objectiveState.zones[1];
   before=zone.owner;actor.x=zone.x;actor.y=zone.y;actor.z=zone.z;
   match.actors[1].x=32;match.actors[1].z=30;
   for(let tick=0;tick<500&&!match.over;tick++)match.step(1/60,{0:{},1:{}});
   after=match.objectiveState.zones[1].owner;assert.equal(after,actor.team);
  } else {
   const actor=match.actors[0],cart=match.objectiveState.position;
   before=match.objectiveState.distance;
   actor.x=cart.x;actor.y=cart.y;actor.z=cart.z;
   match.actors[1].x=30;match.actors[1].z=-30;
   for(let tick=0;tick<400&&!match.over;tick++)match.step(1/60,{0:{},1:{}});
   after=match.objectiveState.distance;assert.ok(after>before);
  }
  const observed=await host.next('snapshot',host.messages.length),observedGuest=await guest.next('snapshot',guest.messages.length);
  assert.equal(observed.state.mapId,id);assert.equal(observedGuest.state.mapId,id);
  if(mode==='ctf')assert.ok(observed.state.teamScores[0]>=1&&observedGuest.state.teamScores[0]>=1);
  if(mode==='domination')assert.equal(observed.state.objectives.zones[1].owner,after);
  if(mode==='payload')assert.ok(observed.state.objectives.payload.distance>0);
  // Restart after an ended round must mint a fresh revision and reset the
  // source-created objective state; this is the host's real network command.
  match.endMatch('time');room.tick(1/60);
  const revision=room.roundRevision;
  host.send({type:'start'});
  const newStart=await host.next('start',host.messages.length-1);
  assert.ok(newStart.roundRevision>revision);assert.equal(newStart.geometryHash,hash);
  assert.equal(room.match.snapshot().mapId,id);
  if(mode==='ctf')assert.equal(room.match.teamScores[0],0);
  if(mode==='payload')assert.ok(room.match.objectiveState.distance<.25,'fresh round cart is back at start (allow one authority tick)');
  evidence.push({map:id,mode,hash,host:welcome.peerId,guest:guestWelcome.peerId,lateSpectator:lateWelcome.spectate,revision:newStart.roundRevision,objectiveBefore:before,objectiveAfter:after});
  for(const p of [host,guest,late])p.ws.close();
 }
 console.log('WORLD_TWO_CLIENT_OK '+JSON.stringify(evidence));
} finally {
 for(const p of peers)if(p.ws.readyState===WebSocket.OPEN)p.ws.terminate();
 await game.close();
}

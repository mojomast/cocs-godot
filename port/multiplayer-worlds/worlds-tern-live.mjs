#!/usr/bin/env node
// Source LATTICE round with two native render clients and third wire infantry.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {createGameServer} from './derived/game-server.mjs';
const root='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/worlds',godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(label,fn,ms=30000){const start=Date.now();while(Date.now()-start<ms){const value=fn();if(value)return value;await sleep(50);}throw Error(`${label} timeout`);}
const server=createGameServer({historyPath:null,progressionPath:null});await new Promise(ok=>server.server.listen(0,'127.0.0.1',ok));
const url=`ws://127.0.0.1:${server.server.address().port}`,children=[];
function native(name,extra){const child=spawn(godot,['--headless','--path','godot','--audio-driver','Dummy','res://multiplayer_worlds/lattice_demo.tscn','--',`--endpoint=${url}`,'--map=tern-archipelago','--mode=cocs','--world-evidence',...extra],{env:{...process.env,LP_NUM_THREADS:'1'}});let log='';for(const s of [child.stdout,child.stderr])s.on('data',b=>log+=b);const entry={name,child,get log(){return log}};children.push(entry);return entry;}
let wire=null,debug=null;
try{
 const host=native('host',['--bots=4','--time-limit=60','--world-fixture-three']);
 const room=await until('LATTICE native host',()=>[...server.registry.rooms.values()].find(r=>r.peers.size===1),45000);
 const guest=native('guest',[`--join-room=${room.id}`]);
 await until('LATTICE native guest',()=>room.peers.size===2);
 wire=new WebSocket(url);await new Promise((ok,fail)=>{wire.addEventListener('open',ok,{once:true});wire.addEventListener('error',fail,{once:true})});
 const frames=[],events=[];wire.addEventListener('message',event=>{const f=JSON.parse(String(event.data));frames.push(f);if(f.type==='events')events.push(...f.items??f.events??[]);if(frames.length>100)frames.shift();});
 wire.send(JSON.stringify({type:'join',v:3,roomId:room.id,playerName:'Tern wire infantry',character:'grok',harness:'openclaw'}));
 const welcome=await until('third LATTICE peer',()=>frames.find(f=>f.type==='welcome'));
 const match=await until('LATTICE source match',()=>room.match,45000);
 await until('both native LATTICE starts',()=>host.log.includes('WORLD_LATTICE_START ')&&guest.log.includes('WORLD_LATTICE_START '),30000);
 const actorId=room.peers.get(welcome.peerId)?.actorId;assert.ok(Number.isInteger(actorId));
 const nodes=match.objectiveState?.nodes;assert.ok(nodes?.length,'source territory nodes absent');
 let seq=0,inputs=0,travel=0,first=null;const route=[];
 const tick=setInterval(()=>{
  if(match.over)return;
  const actor=match.actors[actorId];if(!actor||actor.health<=0)return;
  first??={x:actor.x,z:actor.z};travel=Math.max(travel,Math.hypot(actor.x-first.x,actor.z-first.z));
  const target=nodes.filter(n=>n.owner!==actor.team).sort((a,b)=>Math.hypot(actor.x-a.x,actor.z-a.z)-Math.hypot(actor.x-b.x,actor.z-b.z))[0]??nodes[0];
  const dx=target.x-actor.x,dz=target.z-actor.z,d=Math.hypot(dx,dz);
  wire.send(JSON.stringify({type:'input',seq:++seq,input:{x:d>2?dx/d:0,z:d>2?dz/d:0,yaw:Math.atan2(-dx,-dz),sprint:true}}));inputs++;
  if(inputs%20===0)route.push({x:actor.x,z:actor.z,node:target.id,owner:target.owner});
  debug={inputs,travel,node:target.id,actor:{x:actor.x,z:actor.z,team:actor.team},events:events.slice(-10)};
 },50);
 try{await until('source LATTICE territory round end',()=>match.over,95000);}finally{clearInterval(tick);}
 await until('both native LATTICE results',()=>host.log.includes('WORLD_LATTICE_RESULTS ')&&guest.log.includes('WORLD_LATTICE_RESULTS '),12000);
 const snap=match.snapshot(),territory=snap.cocs;
 assert.ok(inputs>50&&travel>5);assert.ok(snap.over);assert.ok(territory?.nodes?.length);
 const eventTypes=events.map(e=>e.type);assert.ok(eventTypes.some(e=>e.startsWith('cocs-')),'no source territory event on wire: '+[...new Set(eventTypes)].join(','));
 const evidence={map:'tern-archipelago',mode:'cocs',room:room.id,actorId,inputs,travel,route,eventTypes,territory,winner:snap.winner,reason:snap.overReason};
 writeFileSync(`${root}/tern-archipelago-cocs-live.json`,JSON.stringify(evidence,null,2)+'\n');
 console.log('WORLD_LATTICE_FULLROUND '+JSON.stringify({inputs,travel,nodes:territory.nodes.length,winner:snap.winner,reason:snap.overReason,events:[...new Set(eventTypes)]}));
}finally{
 if(debug)writeFileSync(`${root}/tern-archipelago-cocs-debug.json`,JSON.stringify(debug,null,2)+'\n');
 if(wire?.readyState===WebSocket.OPEN)wire.close();
 for(const entry of children){writeFileSync(`${root}/tern-archipelago-cocs-${entry.name}.log`,entry.log);entry.child.kill('SIGTERM');}
 await server.close();
}

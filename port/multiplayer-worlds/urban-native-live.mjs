#!/usr/bin/env node
// Urban CTF/Payload: two native clients and a third wire-controlled human
// traverse source navigation without directly modifying source state.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {existsSync,mkdirSync,writeFileSync} from 'node:fs';
import {createGameServer} from './derived/game-server.mjs';
import {readWorld} from './catalog.mjs';

const map=process.argv[2]??'switchyard-ward',mode=process.argv[3]??'ctf';
if(![['switchyard-ward','ctf'],['rainmarket-exchange','payload']].some(pair=>pair[0]===map&&pair[1]===mode))throw Error('Urban native journey supports Switchyard CTF or Rainmarket Payload');
const root='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/urban/post-art';
mkdirSync(root,{recursive:true});
const godot=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const visual=process.env.URBAN_NATIVE_VISUAL==='1';
const capture=`${root}/${map}-${mode}-live-objective.png`;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
function routeTo(match,from,to){
 const nav=match.nav,edges=match.edges;
 const nearest=p=>{let best=0,dist=Infinity;for(let i=0;i<nav.length;i++){const d=distance(p,nav[i]);if(d<dist){best=i;dist=d;}}return best;};
 const start=nearest(from),end=nearest(to),open=new Set([start]),cost=new Float64Array(nav.length).fill(Infinity),prev=new Int32Array(nav.length).fill(-1);
 cost[start]=0;
 while(open.size){let current=-1;for(const index of open)if(current<0||cost[index]+distance(nav[index],nav[end])<cost[current]+distance(nav[current],nav[end]))current=index;
  open.delete(current);if(current===end)break;
  for(const next of edges[current]??[]){const proposal=cost[current]+distance(nav[current],nav[next]);if(proposal>=cost[next])continue;cost[next]=proposal;prev[next]=current;open.add(next);}
 }
 if(!Number.isFinite(cost[end]))throw Error(`No source bot path from ${JSON.stringify(from)} to ${JSON.stringify(to)}`);
 const result=[];for(let i=end;i!==-1;i=prev[i])result.unshift(nav[i]);
 result.push(to);return result;
}
async function until(label,condition,ms=30000){
 const start=Date.now();while(Date.now()-start<ms){const value=condition();if(value)return value;await sleep(50);}
 throw Error(`${label} timed out after ${ms}ms`);
}
const game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
 const url=`ws://127.0.0.1:${game.server.address().port}`,native=[];
 const startClient=(role,extra=[])=>{
  const args=[...(visual&&role==='host'?['--rendering-driver','opengl3']:['--headless']),'--path','godot','--audio-driver','Dummy','res://multiplayer_worlds/demo.tscn','--',
   `--endpoint=${url}`,`--map=${map}`,`--mode=${mode}`,'--bots=0','--world-evidence',...(visual&&role==='host'?[`--urban-fixture-capture=${capture}`]:[]),...extra];
  const child=visual&&role==='host'
   ?spawn('xvfb-run',['-a','-s','-screen 0 1280x800x24',godot,...args],{env:{...process.env,LP_NUM_THREADS:'1'},detached:true})
   :spawn(godot,args,{env:{...process.env,LP_NUM_THREADS:'1'}});
 let output='';child.stdout.on('data',b=>{output+=String(b);});child.stderr.on('data',b=>{output+=String(b);});
 const entry={role,child,get output(){return output}};native.push(entry);
 return entry;
};
 let ws=null,late=null,debug=null;
try{
  const host=startClient('host',['--world-fixture-three','--urban-fixture-restart']);
 const room=await until('native host room',()=>[...game.registry.rooms.values()].find(r=>r.peers?.size===1));
  const guest=startClient('guest',[`--join-room=${room.id}`,'--urban-fixture-move-guest']);
 await until('two native peers',()=>room.peers.size===2);
 ws=new WebSocket(url);
  await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true})});
  const messages=[];ws.addEventListener('message',event=>messages.push(JSON.parse(String(event.data))));
 ws.send(JSON.stringify({type:'join',v:3,roomId:room.id,name:'World fixture',playerName:'Wire driver',character:'grok',harness:'openclaw'}));
 const welcome=await until('driver welcome',()=>messages.find(m=>m.type==='welcome'));
 await until('source match start',()=>room.match,45000);
  await until('both native start frames',()=>host.output.includes('WORLD_NATIVE ')&&guest.output.includes('WORLD_NATIVE '),30000);
  late=new WebSocket(url);
  await new Promise((resolve,reject)=>{late.addEventListener('open',resolve,{once:true});late.addEventListener('error',reject,{once:true})});
  const lateMessages=[];late.addEventListener('message',event=>lateMessages.push(JSON.parse(String(event.data))));
  late.send(JSON.stringify({type:'join',v:3,roomId:room.id,name:'Late urban spectator'}));
  const lateWelcome=await until('late spectator welcome',()=>lateMessages.find(m=>m.type==='welcome'));
  assert.equal(lateWelcome.spectate,true);
  const lateStart=await until('late spectator start',()=>lateMessages.find(m=>m.type==='start'));
  assert.equal(lateStart.geometryHash,readWorld(map).geometryHash);
  await until('late spectator snapshot',()=>lateMessages.find(m=>m.type==='snapshot'));
 const actorId=room.peers.get(welcome.peerId)?.actorId;
 assert.ok(Number.isInteger(actorId),`missing third actor ${welcome.peerId}`);
  const match=room.match;
 assert.equal(match.config.mode,mode);assert.equal(match.snapshot().mapId,map);
  assert.equal(match.actors.filter(a=>!a.bot).length,3);
  const guestActor=match.actors[room.peers.get([...room.peers.keys()].find(id=>id!==welcome.peerId&&id!==room.hostId))?.actorId??1];
  const guestStart={x:guestActor.x,z:guestActor.z};
  await until('native guest movement packet',()=>guest.output.includes('"sent":30'),10000);
  await until('native guest authoritative displacement',()=>distance(guestStart,guestActor)>3,10000);
  const guestDistance=distance(guestStart,guestActor);
 let seq=0,controls=0,route=[],path=[],index=0,lastGoal='',stages=[];
 const team=match.actors[actorId].team;
 if(team!==0)throw Error(`Fixture driver joined defending team ${team}`);
 const destination=()=>{
   if(mode==='ctf')return match.flags[1].state==='carried'?{x:match.flagSpawns[0][0],z:match.flagSpawns[0][1]}:{x:match.flagSpawns[1][0],z:match.flagSpawns[1][1]};
   return match.objectiveState.position;
 };
 const tick=()=>{
  const actor=match.actors[actorId];
  if(!actor||actor.health<=0||match.over)return;
   const target=destination();
   const key=mode==='ctf'?`flag-${match.flags[1].state}`:`cart-${Math.floor(match.objectiveState.distance/5)}`;
  if(!path.length||key!==lastGoal){path=routeTo(match,actor,target);index=0;lastGoal=key;stages.push({key,at:controls,position:{x:actor.x,z:actor.z}});}
  while(index<path.length-1&&distance(actor,path[index])<2.2)index++;
  const node=distance(actor,target)<3?target:path[index];
  const dx=node.x-actor.x,dz=node.z-actor.z,d=Math.hypot(dx,dz);
   const input={type:'input',seq:++seq,input:{x:d>1?dx/d:0,z:d>1?dz/d:0,yaw:Math.atan2(-dx,-dz),sprint:true}};
  ws.send(JSON.stringify(input));controls++;
  if(controls%20===0)route.push({x:actor.x,z:actor.z,stage:key,owner:target.owner,cart:match.objectiveState?.distance,health:actor.health});
   debug={controls,actor:{x:actor.x,y:actor.y,z:actor.z,team:actor.team,health:actor.health,dead:actor.dead},target:{x:target.x,z:target.z,progress:target.progress},stages:stages.slice(-12),route:route.slice(-12),over:match.over};
 };
 const timer=setInterval(tick,50);
 try{
   await until(`${mode} full round source outcome`,()=>match.over,mode==='payload'?240000:160000);
 }finally{clearInterval(timer);}
 await until('both native result receipts',()=>host.output.includes('WORLD_NATIVE_RESULTS ')&&guest.output.includes('WORLD_NATIVE_RESULTS '),12000);
  const snap=match.snapshot();
 assert.ok(controls>20,'driver did not send meaningful wire controls');
  if(mode==='ctf')assert.ok(snap.teamScores[team]>=1,'flag was not carried home');
  if(mode==='payload')assert.ok(snap.objectives.payload.delivered,'escort did not deliver');
  if(mode==='payload')assert.equal(snap.objectives.payload.progress,100);
 assert.ok(match.over,'source did not end match');
  assert.ok(host.output.includes('WORLD_NATIVE ')&&guest.output.includes('WORLD_NATIVE '));
  if(visual){
   await until('live native objective capture',()=>host.output.includes('URBAN_NATIVE_CAPTURE '),10000);
   assert.ok(existsSync(capture));
  }
  const oldRevision=room.roundRevision;
  await until('native host restart',()=>room.roundRevision>oldRevision&&host.output.includes('"round":2')&&guest.output.includes('"round":2'),20000);
  assert.ok(host.output.includes(`"hash":"${readWorld(map).geometryHash}"`)&&guest.output.includes(`"hash":"${readWorld(map).geometryHash}"`));
  const evidence={map,mode,room:room.id,geometryHash:readWorld(map).geometryHash,driverPeer:welcome.peerId,actor:actorId,controls,stages,route,guestNativeControls:30,guestAuthoritativeDisplacement:guestDistance,lateSpectator:lateWelcome.spectate,oldRevision,newRevision:room.roundRevision,objective:snap.objectives,winner:snap.winner,over:match.over,native:[host.role,guest.role],nativeObjectiveCapture:visual?capture:null};
 writeFileSync(`${root}/${map}-${mode}-live.json`,JSON.stringify(evidence,null,2)+'\n');
  console.log('URBAN_NATIVE_FULLROUND '+JSON.stringify({map,mode,controls,guestAuthoritativeDisplacement:guestDistance,routePoints:route.length,winner:snap.winner,lateSpectator:lateWelcome.spectate,restartRevision:room.roundRevision,stages:stages.map(s=>s.key),objective:snap.objectives.kind}));
}finally{
 if(debug)writeFileSync(`${root}/${map}-${mode}-debug.json`,JSON.stringify(debug,null,2)+'\n');
  if(ws&&ws.readyState===WebSocket.OPEN)ws.close();
  if(late&&late.readyState===WebSocket.OPEN)late.close();
  for(const item of native){writeFileSync(`${root}/${map}-${mode}-${item.role}.log`,item.output);if(visual&&item.role==='host')process.kill(-item.child.pid,'SIGTERM');else item.child.kill('SIGTERM');}
 await game.close();
}

#!/usr/bin/env node
// Bounded end-to-end fixture: TWO actual Godot native clients remain connected
// while a third WebSocket human sends source-valid directional input. The
// harness reads authority positions for steering/assertions but NEVER mutates
// Match actors, objective state, flags, vehicles, clocks or scores.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createGameServer} from './derived/game-server.mjs';
import {readWorld} from './catalog.mjs';

const map=process.argv[2]??'thermal-divide',mode=process.argv[3]??'domination';
const root='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/worlds';
mkdirSync(root,{recursive:true});
const godot=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
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
const url=`ws://127.0.0.1:${game.server.address().port}`,native=[],logs=[];
const startClient=(role,extra=[])=>{
 const args=['--headless','--path','godot','--audio-driver','Dummy','res://multiplayer_worlds/demo.tscn','--',
  `--endpoint=${url}`,`--map=${map}`,`--mode=${mode}`,'--bots=0','--world-evidence',...extra];
 const child=spawn(godot,args,{env:{...process.env,LP_NUM_THREADS:'1'}});
 let output='';child.stdout.on('data',b=>{output+=String(b);});child.stderr.on('data',b=>{output+=String(b);});
 const entry={role,child,get output(){return output}};native.push(entry);
 return entry;
};
let ws=null,debug=null;
try{
 const host=startClient('host',['--world-fixture-three']);
 const room=await until('native host room',()=>[...game.registry.rooms.values()].find(r=>r.peers?.size===1));
 const guest=startClient('guest',[`--join-room=${room.id}`,...(mode==='payload'?['--world-fixture-retreat']:[])]);
 await until('two native peers',()=>room.peers.size===2);
 ws=new WebSocket(url);
  await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true})});
  const messages=[];ws.addEventListener('message',event=>messages.push(JSON.parse(String(event.data))));
 ws.send(JSON.stringify({type:'join',v:3,roomId:room.id,name:'World fixture',playerName:'Wire driver',character:'grok',harness:'openclaw'}));
 const welcome=await until('driver welcome',()=>messages.find(m=>m.type==='welcome'));
 await until('source match start',()=>room.match,45000);
 await until('both native start frames',()=>host.output.includes('WORLD_NATIVE ')&&guest.output.includes('WORLD_NATIVE '),30000);
 const actorId=room.peers.get(welcome.peerId)?.actorId;
 assert.ok(Number.isInteger(actorId),`missing third actor ${welcome.peerId}`);
 const match=room.match;
 assert.equal(match.config.mode,mode);assert.equal(match.snapshot().mapId,map);
 assert.equal(match.actors.filter(a=>!a.bot).length,3);
 let seq=0,controls=0,route=[],path=[],index=0,lastGoal='',stages=[],vehicleMounted=false,vehicleDistance=0,vehicleStart=null;
 if(!['domination','ctf','assault','payload','combined-arms'].includes(mode))throw Error(`Unsupported infantry fixture ${mode}`);
 const team=match.actors[actorId].team;
 if(team!==0)throw Error(`Fixture driver joined defending team ${team}`);
 const destination=()=>{
  if(mode==='domination'||mode==='combined-arms')return match.objectiveState.zones[0];
  if(mode==='ctf')return match.flags[1].state==='carried'?{x:match.flagSpawns[0][0],z:match.flagSpawns[0][1]}:{x:match.flagSpawns[1][0],z:match.flagSpawns[1][1]};
  if(mode==='assault')return match.objectiveState.zones[match.objectiveState.active]??match.objectiveState.zones.at(-1);
  return match.objectiveState.position;
 };
 const tick=()=>{
  const actor=match.actors[actorId];
  if(!actor||actor.health<=0||match.over)return;
  const vehicle=match.vehicles.find(v=>v.kind==='scout'&&v.position.x<0);
  const vehicleApproach=mode==='combined-arms'&&!vehicleMounted;
  const vehicleDrive=mode==='combined-arms'&&actor.vehicleSeat==='driver'&&vehicle?.driver===actorId;
  if(vehicleDrive){vehicleMounted=true;vehicleStart??={...vehicle.position};vehicleDistance=Math.max(vehicleDistance,distance(vehicleStart,vehicle.position));}
  const target=vehicleApproach?vehicle.position:vehicleDrive?{x:-86,z:-13}:destination();
  const key=vehicleApproach?'vehicle-approach':vehicleDrive?'vehicle-drive':mode==='ctf'?`flag-${match.flags[1].state}`:mode==='assault'?`sector-${match.objectiveState.active}`:mode==='payload'?`cart-${Math.floor(match.objectiveState.distance/5)}`:'zone';
  if(!path.length||key!==lastGoal){path=routeTo(match,actor,target);index=0;lastGoal=key;stages.push({key,at:controls,position:{x:actor.x,z:actor.z}});}
  while(index<path.length-1&&distance(actor,path[index])<2.2)index++;
  const node=distance(actor,target)<3?target:path[index];
  const dx=node.x-actor.x,dz=node.z-actor.z,d=Math.hypot(dx,dz);
  const action=vehicleApproach&&distance(actor,vehicle.position)<2.2||vehicleDrive&&vehicleDistance>25;
  const input={type:'input',seq:++seq,input:{x:d>1?dx/d:0,z:d>1?dz/d:0,yaw:Math.atan2(-dx,-dz),sprint:true,interact:action}};
  ws.send(JSON.stringify(input));controls++;
  if(controls%20===0)route.push({x:actor.x,z:actor.z,stage:key,owner:target.owner,cart:match.objectiveState?.distance,health:actor.health});
  debug={controls,actor:{x:actor.x,y:actor.y,z:actor.z,team:actor.team,health:actor.health,dead:actor.dead,vehicleId:actor.vehicleId},vehicleDistance,target:{x:target.x,z:target.z,owner:target.owner,progress:target.progress},stages:stages.slice(-12),route:route.slice(-12),over:match.over};
 };
 const timer=setInterval(tick,50);
 try{
  await until(`${mode} full round source outcome`,()=>match.over,mode==='payload'?240000:mode==='ctf'?160000:mode==='assault'?150000:mode==='combined-arms'?145000:90000);
 }finally{clearInterval(timer);}
 await until('both native result receipts',()=>host.output.includes('WORLD_NATIVE_RESULTS ')&&guest.output.includes('WORLD_NATIVE_RESULTS '),12000);
 const snap=match.snapshot();
 assert.ok(controls>20,'driver did not send meaningful wire controls');
 if(mode==='domination'||mode==='combined-arms')assert.ok(snap.objectives.zones.some(z=>z.owner===team),'driver team captured no zone');
 if(mode==='combined-arms')assert.ok(vehicleMounted&&vehicleDistance>25,`driver did not traverse source vehicle path: ${vehicleDistance}`);
 if(mode==='ctf')assert.ok(snap.teamScores[team]>=1,'flag was not carried home');
 if(mode==='payload')assert.ok(snap.objectives.payload.delivered,'escort did not deliver');
 let authoredWaypoints=[];
 if(mode==='payload'){
  authoredWaypoints=readWorld(map).arena.payloadPath;
  assert.equal(authoredWaypoints.length,7,'Breakwater route has seven authored waypoints');
  for(const waypoint of authoredWaypoints)assert.ok(match.objectiveState.path.some(p=>distance(p,waypoint)<.2),`source cart path omitted authored waypoint ${JSON.stringify(waypoint)}`);
  assert.equal(snap.objectives.payload.progress,100);
 }
 if(mode==='assault')assert.ok(snap.objectives.assault?.winner===team||match.objectiveState.winner===team,'assault sector attack did not win');
 assert.ok(match.over,'source did not end match');
 assert.ok(host.output.includes('WORLD_NATIVE ')&&guest.output.includes('WORLD_NATIVE '));
 const evidence={map,mode,room:room.id,geometryHash:room.geometryHash??snap.geometryHash,driverPeer:welcome.peerId,actor:actorId,controls,stages,route,authoredWaypoints,vehicleMounted,vehicleDistance,objective:snap.objectives,winner:snap.winner,over:match.over,native:[host.role,guest.role]};
 writeFileSync(`${root}/${map}-${mode}-live.json`,JSON.stringify(evidence,null,2)+'\n');
 console.log('WORLD_NATIVE_FULLROUND '+JSON.stringify({map,mode,controls,routePoints:route.length,winner:snap.winner,stages:stages.map(s=>s.key),objective:snap.objectives.kind}));
}finally{
 if(debug)writeFileSync(`${root}/${map}-${mode}-debug.json`,JSON.stringify(debug,null,2)+'\n');
 if(ws&&ws.readyState===WebSocket.OPEN)ws.close();
 for(const item of native){writeFileSync(`${root}/${map}-${mode}-${item.role}.log`,item.output);item.child.kill('SIGTERM');}
 await game.close();
}

#!/usr/bin/env node
// Two connected native Puma scenes plus a third wire-controlled driver. Bot
// opponents are source AI, and all goals/gates/finishes come from real ticks.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {createGameServer} from './derived/game-server.mjs';
const map=process.argv[2]??'sirocco-circuit',race=map==='sirocco-circuit';
assert.ok(race||map==='copper-bowl');
const mode=race?'puma-race':'puma-soccer',root='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/worlds';
const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(label,fn,ms=30000){const start=Date.now();while(Date.now()-start<ms){const found=fn();if(found)return found;await sleep(50);}throw Error(`${label} timeout (${ms}ms)`);}
const server=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});
await new Promise(ok=>server.server.listen(0,'127.0.0.1',ok));
const url=`ws://127.0.0.1:${server.server.address().port}`,children=[];
function client(name,extra){const child=spawn(godot,['--headless','--path','godot','--audio-driver','Dummy','res://multiplayer_worlds/sports_demo.tscn','--',`--endpoint=${url}`,`--map=${map}`,`--bots=${race?0:1}`,'--time-limit=240','--round-target=1','--world-evidence',...extra],{env:{...process.env,LP_NUM_THREADS:'1'}});let log='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>log+=b);const entry={name,child,get log(){return log}};children.push(entry);return entry;}
let wire=null,debug=null;
try{
 const host=client('host',['--world-fixture-three']);
 const room=await until('host room',()=>[...server.registry.rooms.values()].find(r=>r.peers.size===1));
 const guest=client('guest',[`--join-room=${room.id}`]);
 await until('native guest',()=>room.peers.size===2);
 wire=new WebSocket(url);await new Promise((ok,fail)=>{wire.addEventListener('open',ok,{once:true});wire.addEventListener('error',fail,{once:true})});
 const frames=[];wire.addEventListener('message',event=>frames.push(JSON.parse(String(event.data))));
 wire.send(JSON.stringify({type:'join',v:3,roomId:room.id,playerName:'Puma wire driver',character:'grok',harness:'openclaw'}));
 const welcome=await until('third peer welcome',()=>frames.find(f=>f.type==='welcome'));
 const match=await until('sports match',()=>room.match,45000);
 await until('both native starts',()=>host.log.includes('WORLD_SPORTS_START ')&&guest.log.includes('WORLD_SPORTS_START '),30000);
 const actorId=room.peers.get(welcome.peerId)?.actorId;
 assert.ok(Number.isInteger(actorId));assert.equal(match.config.mode,mode);
 const records=[];let seq=0,inputs=0,furthest=0,gateIndices=new Set(),goals=[];
 const timer=setInterval(()=>{
  if(match.over)return;
  const vehicle=match.vehicles.find(v=>v.driver===actorId),r=match.race;
  if(!vehicle||!r)return;
  const p=vehicle.position;let target,throttle=.85,steer=0;
  if(race){
   const racer=r.racers.find(v=>v.actorId===actorId);if(!racer)return;
   gateIndices.add(racer.nextGate);furthest=Math.max(furthest,racer.completedLaps*r.gates.length+racer.nextGate);
   const line=r.centerline,n=line.length,next=racer.nextGate,prev=(next+n-1)%n;
   const a=line[prev],b=line[next],dx=b.x-a.x,dz=b.z-a.z,length=Math.hypot(dx,dz);
   let along=Math.max(0,Math.min(length,((p.x-a.x)*dx+(p.z-a.z)*dz)/length));
   let look=Math.max(5,Math.abs(vehicle.speed)*.65),index=prev;
   for(let i=0;i<n;i++){
    const from=line[index],to=line[(index+1)%n],len=Math.hypot(to.x-from.x,to.z-from.z);
    if(along+look<=len){const t=(along+look)/len;target={x:from.x+(to.x-from.x)*t,z:from.z+(to.z-from.z)*t};break;}
    look-=len-along;along=0;index=(index+1)%n;
   }
   target??=b;
  }else target=r.ball;
  if(!target)return;
  const desired=Math.atan2(target.x-p.x,target.z-p.z);
  const error=Math.atan2(Math.sin(desired-vehicle.heading),Math.cos(desired-vehicle.heading));
  steer=Math.max(-1,Math.min(1,error*1.8));throttle=Math.abs(error)>1?.35:.85;
  const yaw=vehicle.heading-Math.PI,fx=-Math.sin(yaw),fz=-Math.cos(yaw),rx=Math.cos(yaw),rz=-Math.sin(yaw);
  wire.send(JSON.stringify({type:'input',seq:++seq,input:{x:fx*throttle-rx*steer,z:fz*throttle-rz*steer,yaw,sprint:Math.abs(error)<.08}}));inputs++;
  if(inputs%20===0)records.push({x:p.x,z:p.z,heading:vehicle.heading,gate:race?r.racers.find(v=>v.actorId===actorId)?.nextGate:undefined,goals:race?undefined:{...r.scores}});
  debug={inputs,furthest,gates:[...gateIndices],position:{...p},phase:r.phase,score:r.scores};
 },50);
 try{await until('source sports round finish',()=>match.over,245000);}finally{clearInterval(timer);}
 await until('both native results',()=>host.log.includes('WORLD_SPORTS_RESULTS ')&&guest.log.includes('WORLD_SPORTS_RESULTS '),12000);
 const snap=match.snapshot();assert.ok(inputs>30);assert.ok(snap.race);
 if(race){assert.equal(snap.race.standings[0]?.actorId,actorId,'wire driver did not win full lap');assert.ok(snap.race.standings[0].completedLaps>=1,'no actual full lap');assert.equal(match.race.gates.length,14);assert.equal(gateIndices.size,14);}
 else {assert.ok(Object.values(match.race.scores).some(s=>s>=1),'no real goal');assert.equal(snap.race.standings[0]?.actorId,actorId,'wire driver did not score winning goal');}
 const evidence={map,mode,room:room.id,driverPeer:welcome.peerId,actorId,inputs,furthest,gates:[...gateIndices],records,winner:snap.winner,over:snap.over,race:snap.race};
 writeFileSync(`${root}/${map}-${mode}-live.json`,JSON.stringify(evidence,null,2)+'\n');
 console.log('WORLD_SPORTS_FULLROUND '+JSON.stringify({map,mode,inputs,furthest,gateCount:gateIndices.size,winner:snap.winner,phase:snap.race.phase,score:snap.race.scores}));
}finally{
 if(debug)writeFileSync(`${root}/${map}-${mode}-debug.json`,JSON.stringify(debug,null,2)+'\n');
 if(wire?.readyState===WebSocket.OPEN)wire.close();
 for(const entry of children){writeFileSync(`${root}/${map}-${mode}-${entry.name}.log`,entry.log);entry.child.kill('SIGTERM');}
 await server.close();
}

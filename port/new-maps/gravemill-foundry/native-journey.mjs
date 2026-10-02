// Two PRODUCTION native peers send ordinary wire input. Node only reads the
// authority for route following and writes test stimulus files for the clients.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createGameServer} from '../../multiplayer-worlds/derived/game-server.mjs';
import {readWorld} from '../../multiplayer-worlds/catalog.mjs';
import {visible} from '../../../game/core.mjs';

const requested=process.argv[2]??'payload',walk=requested==='walkthrough',mode=walk?'deathmatch':requested;
const visual=walk||process.env.FOUNDRY_VISUAL==='1';
const root=process.env.FOUNDRY_EVIDENCE??'/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/native';
fs.mkdirSync(root,{recursive:true});
const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const geometryHash=readWorld('gravemill-foundry').geometryHash;
const started=performance.now(),native=[],timers=[];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const until=async(label,fn,ms=40000)=>{const at=Date.now();while(Date.now()-at<ms){const v=fn();if(v)return v;const bad=native.find(n=>n.code!==null);if(bad)throw Error(`${bad.role} exited ${bad.code}: ${bad.output.slice(-5000)}`);await sleep(50);}throw Error(`Timeout ${label}`);};
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
function route(match,a,b){const closest=p=>{let d=Infinity,best=0;match.nav.forEach((n,i)=>{const k=distance(p,n);if(k<d){d=k;best=i;}});return best;};const from=closest(a),to=closest(b),queue=[from],prev=new Map([[from,-1]]);for(let i=0;i<queue.length&&!prev.has(to);i++)for(const n of match.edges[queue[i]])if(!prev.has(n)){prev.set(n,queue[i]);queue.push(n);}assert.ok(prev.has(to));const out=[b];for(let i=to;i!==-1;i=prev.get(i))out.push(match.nav[i]);return out.reverse();}
function follow(match,actor,target){const points=route(match,actor,target);return ()=>{while(points.length>1&&distance(actor,points[0])<1)points.shift();const p=points[0],dx=p.x-actor.x,dz=p.z-actor.z,d=Math.hypot(dx,dz);return d>.45?{x:dx/d,z:dz/d,yaw:Math.atan2(-dx,-dz)}:{};};}
const game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
const stimulus=(role,command)=>{const path=`${root}/${requested}-${role}-controls.json`;fs.writeFileSync(path+'.tmp',JSON.stringify(command));fs.renameSync(path+'.tmp',path);};
function launch(role,extra=[]){stimulus(role,{input:{}});const args=[...(visual&&role==='host'?['--rendering-method','gl_compatibility','--resolution','1280x800']:['--headless']),'--path','godot','--audio-driver','Dummy','res://tests/new_maps/gravemill_foundry/journey.tscn','--',`--endpoint=${endpoint}`,'--map=gravemill-foundry',`--mode=${mode}`,'--bots=0',`--foundry-role=${role}`,`--foundry-controls=${root}/${requested}-${role}-controls.json`,...(visual&&role==='host'?[`--foundry-capture=${root}/${requested}-frames`]:[]),...extra];const child=spawn(godot,args,{env:{...process.env,LP_NUM_THREADS:'1',OMP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1'}});const n={role,child,output:'',code:null};child.stdout.on('data',b=>n.output+=b);child.stderr.on('data',b=>n.output+=b);child.on('exit',code=>n.code=code);native.push(n);return n;}
let debug={},match=null,result=null;
try{
 const host=launch('host');const room=await until('native room',()=>[...game.registry.rooms.values()].find(r=>r.peers.size===1));const guest=launch('guest',[`--join-room=${room.id}`]);
 match=await until('source match',()=>room.match,60000);await until('native start receipts',()=>host.output.includes('FOUNDRY_NATIVE_INPUT ')&&guest.output.includes('FOUNDRY_NATIVE_INPUT '));
 const a=match.actors[0],enemy=match.actors[1],retreat=follow(match,enemy,{x:166,y:12,z:25+.14*166});
 const vehicle=match.vehicles.find(v=>v.kind==='puma'&&v.position.x<0),driveLine=match.arena.payloadPath.slice(0,3);
 let mounted=false,exited=false,driveDistance=0,driveSector=0,key='',controller=null,controls=0,distanceMoved=0,last={x:a.x,z:a.z},stage=0,walkDone=false,shotAt=0;
 const stages=[],positions=[],events=[],walkTargets=[[-112,-38,'crusher',[-60,15,-15]],[-80,36,'cooling-entry',[-48,16,29]],[-52,36,'cooling-nave',[-78,17,25]],[66,36,'assay-vault',[90,17,48]],[0,109,'crown-gantry',[80,24,20]],[88,-38,'furnace-apron',[66,20,1]]].map(([x,q,id,look])=>({x,z:q+.14*x,id,look}));
 const tick=()=>{
  if(match.over||walkDone)return;let input={},target=null,nextKey='',shot='',clip=false;
  const moved=distance(a,last);distanceMoved+=moved;if(a.vehicleId!==null)driveDistance+=moved;last={x:a.x,z:a.z};
  if(walk){target=walkTargets[stage];nextKey=`walk-${stage}`;if(distance(a,target)<1.5){shotAt++;if(shotAt>20)shot=target.id;const [x,y,z]=target.look,dx=x-a.x,dz=z-a.z;input={yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(y-a.y-1.45,Math.hypot(dx,dz))};target=null;if(shotAt>30){stages.push({stage:nextKey,x:a.x,y:a.y,z:a.z});stage++;shotAt=0;key='';if(stage>=walkTargets.length)walkDone=true;}}clip=stage===2;}
  else if(mode==='combined-arms'&&!exited){
   if(!mounted){target=vehicle.position;nextKey='mount-approach';if(distance(a,target)<2.15){input={interact:true};target=null;}}
   else if(a.vehicleId!==null){const v=match.vehicleById(a.vehicleId),p=driveLine[driveSector+1],dx=p.x-v.position.x,dz=p.z-v.position.z;if(Math.hypot(dx,dz)<5){driveSector++;if(driveSector>=driveLine.length-1)input={interact:true};}if(!input.interact){const error=Math.atan2(Math.sin(Math.atan2(dx,dz)-v.heading),Math.cos(Math.atan2(dx,dz)-v.heading)),steer=Math.max(-1,Math.min(1,error*1.5)),throttle=v.speed<7?1:0,yaw=v.heading-Math.PI,x=-Math.sin(yaw)*throttle-Math.cos(yaw)*steer,z=-Math.cos(yaw)*throttle+Math.sin(yaw)*steer,k=Math.max(1,Math.abs(x),Math.abs(z));input={x:x/k,z:z/k,yaw,jump:v.speed>9};}}
   else{exited=true;key='';stages.push({stage:'dismounted',driveDistance});}
  }else if(mode==='payload'){target=match.objectiveState.position;nextKey=distance(a,target)>5?'cart-approach':'cart-follow';if(visual){clip=match.objectiveState.distance>30&&match.objectiveState.distance<40;if(match.objectiveState.distance>35)shot='payload-push';}}
  else if(mode==='assault'){target=match.objectiveState.zones[match.objectiveState.active]??match.objectiveState.zones.at(-1);nextKey=`sector-${match.objectiveState.active}`;}
  else if(mode==='domination'||mode==='combined-arms'){target=match.objectiveState.zones[0];nextKey='capture-zone';}
  else{target=enemy;nextKey=`combat-${enemy.health>0}`;}
  if(target){if(mode==='payload'&&nextKey==='cart-follow'){const dx=target.x-a.x,dz=target.z-a.z,d=Math.hypot(dx,dz);input=d>(visual?2.3:.65)?{x:dx/d,z:dz/d,yaw:Math.atan2(-dx,-dz)}:{};}else{if(key!==nextKey){key=nextKey;controller=follow(match,a,target);stages.push({stage:key,x:a.x,y:a.y,z:a.z});}input=controller();}
   if(!walk&&['deathmatch','teamdeathmatch'].includes(mode)&&distance(a,enemy)<25&&visible({x:a.x,y:a.y+1.45,z:a.z},{x:enemy.x,y:enemy.y+1,z:enemy.z},match.arena)){const dx=enemy.x-a.x,dz=enemy.z-a.z;input={yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(enemy.y-a.y-.45,Math.hypot(dx,dz)),fire:true,reload:a.ammo[a.weapon]===0};}}
  if(a.vehicleId!==null)mounted=true;
  stimulus('host',{input,shot,clip});stimulus('guest',{input:walk||!['deathmatch','teamdeathmatch'].includes(mode)?retreat():{}});controls++;
  if(controls%20===0)positions.push({t:match.time,x:a.x,y:a.y,z:a.z,health:a.health,vehicle:a.vehicleId,stage:key,cart:match.objectiveState?.distance});
  debug={mode,walk,controls,key,stage,actor:{x:a.x,y:a.y,z:a.z,health:a.health,team:a.team},driveSector,driveDistance,mounted,exited,position:match.objectiveState?.position,over:match.over};
 };
 timers.push(setInterval(tick,50));await until('native controlled journey',()=>walk?walkDone:match.over,walk?300000:mode==='payload'?260000:300000);
 if(!walk){await until('both native result receipts',()=>native.every(n=>n.output.includes('FOUNDRY_NATIVE_RESULTS ')),15000);if(mode==='payload')assert.ok(match.objectiveState.delivered&&match.objectiveState.checkpointsReached===3);if(mode==='assault')assert.equal(match.objectiveState.winner,a.team);if(mode==='combined-arms')assert.ok(mounted&&exited&&driveDistance>60&&match.objectiveState.zones.some(z=>z.owner===a.team));if(mode==='domination')assert.ok(match.objectiveState.zones.some(z=>z.owner===a.team));if(['deathmatch','teamdeathmatch'].includes(mode))assert.ok(match.stats.kills>=5);}
 for(const n of native){assert.ok(!n.output.includes('SCRIPT ERROR:')&&!n.output.includes('FOUNDRY_NATIVE_ERROR'));assert.ok(n.output.includes(geometryHash));}
 result={id:'gravemill-foundry',mode:requested,geometryHash,label:'controlled two-production-native-peer fixture; ordinary client input only; passive opponent',seconds:match.time,wallSeconds:(performance.now()-started)/1000,controls,distanceMoved,mounted,exited,driveDistance,stages,positions,teamScores:match.teamScores,kills:match.stats.kills,objective:match.snapshot().objectives,nativeReceipts:native.map(n=>({role:n.role,inputs:n.output.split('FOUNDRY_NATIVE_INPUT ').length-1,results:n.output.includes('FOUNDRY_NATIVE_RESULTS ')}))};
 fs.writeFileSync(`${root}/${requested}-result.json`,JSON.stringify(result,null,2)+'\n');console.log('FOUNDRY_NATIVE_PASSED',JSON.stringify({...result,positions:positions.length,objective:result.objective?.kind}));
}finally{
 for(const timer of timers)clearInterval(timer);fs.writeFileSync(`${root}/${requested}-debug.json`,JSON.stringify(debug,null,2)+'\n');
 for(const n of native){fs.writeFileSync(`${root}/${requested}-${n.role}.log`,n.output);if(n.code===null)n.child.kill('SIGTERM');}
 await Promise.all(native.map(n=>n.code!==null?null:new Promise(resolve=>{n.child.once('exit',resolve);setTimeout(()=>{n.child.kill('SIGKILL');resolve();},5000).unref();})));
 await game.close();
}

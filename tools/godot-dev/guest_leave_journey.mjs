// Scripted native Settings/Leave over a real externally owned source room.
// Run under xvfb_run.py; the host is a protocol WebSocket, not another native human.
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, mkdirSync, mkdtempSync, chmodSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {setTimeout as sleep} from 'node:timers/promises';
import {WebSocket} from 'ws';
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../godot-export/semantic.mjs';
import {resolveActiveDerivative} from './active_source.mjs';

const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));
const derivative=resolveActiveDerivative(process.env.COCS_SOURCE_DERIVATIVE).contract;
verifySource(lock,derivative);
const binary=process.env.GODOT_BIN;
assert.ok(binary && process.env.DISPLAY,'Set pinned GODOT_BIN and run with a private Xvfb display');
assert.equal(execFileSync(binary,['--version'],{encoding:'utf8',timeout:10000}).trim(),lock.godot_version);
mkdirSync('.port-runtime/guest-leave',{recursive:true});
const output=mkdtempSync(resolve('.port-runtime/guest-leave/attempt-'));
const wrapper=join(output,'godot-wrapper.mjs');
writeFileSync(wrapper,`#!${process.execPath}
import {spawn} from 'node:child_process';
let args=process.argv.slice(2);
if(!args.includes('--version')){
 const scene=args.find(a=>a.startsWith('res://')&&a.endsWith('.tscn'));
 if(scene!=='res://lattice/world_demo.tscn')throw Error('Expected canonical LATTICE world scene: '+scene);
 args=args.filter(a=>a!==scene);
 const split=args.indexOf('--');
 args.splice(split<0?args.length:split,0,'--audio-driver','Dummy','--script','res://tests/product_journey/guest_leave.gd');
 process.env.COCS_GUEST_SCENE=scene;
}
const child=spawn(process.env.COCS_GUEST_GODOT,args,{env:process.env,stdio:'inherit'});
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>child.kill(signal));
child.once('error',e=>{console.error(e);process.exitCode=1;});
child.once('exit',(code,signal)=>{process.exitCode=code??(signal?1:0);});
`);
chmodSync(wrapper,0o755);
const game=createGameServer({historyPath:null,progressionPath:null});
let host, child, consoleText='', exitCode=null, signalName=null, interrupted=false;
const interrupt=()=>{interrupted=true; if(child?.pid)try{process.kill(-child.pid,'SIGTERM');}catch{}};
process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
const log=line=>{if(consoleText.length<1000000)consoleText+=line;};
const marker=name=>{const found=consoleText.match(new RegExp(`^${name} ([^\\n]+)\\r?\\n`,'m'));return found?JSON.parse(found[1]):null;};
async function until(check,ms,label,allowExit=false){
 const deadline=Date.now()+ms;
 while(Date.now()<deadline){
   if(interrupted)throw Error('Interrupted');
   const value=check();if(value)return value;
   if(exitCode!==null&&!allowExit)throw Error(`Launcher exited before ${label}: ${exitCode}`);
  await sleep(50);
 }
 throw Error(`Deadline: ${label}`);
}
const frames=[];
let guestPeer=null,guestSocket=null,guestClosed=false,guestJoins=0,connections=0;
const evidence={scope:'scripted native guest Settings/Back/Leave in one source room; protocol host, not two native humans or a natural round outcome',
 port_commit:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
 source_commit:lock.source_commit,...(derivative?{source_derivative_commit:derivative.derivative_commit}:{}),output,passed:false};
try{
 await new Promise((ok,bad)=>{game.server.once('error',bad);game.server.listen(0,'127.0.0.1',ok);});
 const port=game.server.address().port, endpoint=`ws://127.0.0.1:${port}`;
 evidence.endpoint=endpoint;
  const initialHealth=await (await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)})).json();
  assert.equal(initialHealth.players,0);
  evidence.initial_rooms=initialHealth.rooms;
 game.wss.on('connection',socket=>{
  // First connection is the protocol host; second belongs to the launched guest.
  if(++connections!==2)return;
  guestSocket=socket;
  socket.on('message',raw=>{const frame=JSON.parse(raw.toString());if(frame.type==='join')guestJoins++;});
  socket.once('close',()=>{guestClosed=true;});
 });
 host=new WebSocket(endpoint);
 host.on('error',error=>{log(`HOST_ERROR ${error.message}\n`);});
 host.on('message',raw=>{
  const frame=JSON.parse(raw.toString());
  if(['welcome','lobby','start','snapshot','snapshot-delta','error'].includes(frame.type)){
   if(frame.type==='snapshot'||frame.type==='snapshot-delta'){
    evidence.host_snapshots=(evidence.host_snapshots??0)+1;
    evidence.last_host_snapshot_type=frame.type;
   }else if(frames.length<300)frames.push(frame);
  }
 });
 await until(()=>host.readyState===WebSocket.OPEN,5000,'host socket open');
 host.send(JSON.stringify({type:'create',name:'External guest leave journey',playerName:'Protocol host',character:'chatgpt',harness:'openclaw',v:3,delta:0}));
 const welcome=await until(()=>frames.find(f=>f.type==='welcome'),5000,'create welcome');
 const room=welcome.roomId;evidence.room=room;evidence.host_peer=welcome.peerId;
 host.send(JSON.stringify({type:'host',mapId:'asterion-relay',config:{mode:'cocs',botCount:0,timeLimit:900}}));
 await until(()=>frames.find(f=>f.type==='lobby'&&f.config?.mode==='cocs'),5000,'host configuration');
 const env={...process.env,GODOT_BIN:wrapper,COCS_GUEST_GODOT:binary,
   COCS_SETTINGS_PATH:join(output,'local_settings.json'),COCS_CAREER_ROOT:join(output,'career'),PORT:'0'};
 for(const [name,dir] of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]){
  env[name]=join(output,dir);mkdirSync(env[name],{recursive:true});
 }
 child=spawn(process.execPath,['tools/godot-dev/launch.mjs','--experience=lattice-world',`--endpoint=${endpoint}`,`--join-room=${room}`],{env,detached:true,stdio:['ignore','pipe','pipe']});
 child.once('error',error=>{log(`LAUNCH_ERROR ${error.stack}\n`);exitCode=1;});
 child.once('exit',(code,signal)=>{exitCode=code??1;signalName=signal;});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>log(chunk.toString()));
 const waiting=await until(()=>marker('GUEST_LEAVE_WAITING'),25000,'native guest waiting');
 assert.equal(waiting.room,room);
 guestPeer=waiting.peer;
  const joinedRoster=await until(()=>frames.find(f=>f.type==='lobby'&&f.players?.some(p=>p.peerId===guestPeer)),5000,'host-observed guest roster');
  const joinedRosterIndex=frames.indexOf(joinedRoster);
 host.send(JSON.stringify({type:'start'}));
 await until(()=>frames.some(f=>f.type==='start')&&(evidence.host_snapshots??0)>2,10000,'host live source snapshots');
 evidence.guest=await until(()=>marker('GUEST_LEAVE_READY'),30000,'guest Settings Back Leave ready');
 assert.equal(evidence.guest.room,room);
 assert.ok(evidence.guest.actor>=0 && evidence.guest.source_snapshots>0);
 assert.equal(evidence.guest.settings_path,env.COCS_SETTINGS_PATH);
  await until(()=>guestClosed,10000,'guest socket close',true);
  const departedRoster=await until(()=>frames.slice(joinedRosterIndex+1).find(f=>f.type==='lobby'
    &&f.players?.find(p=>p.peerId===welcome.peerId)?.connected===true
    &&f.players?.find(p=>p.peerId===guestPeer)?.connected===false),10000,'source-observed disconnected guest',true);
 // Await the supervisor's child exit as well: a detached script quit is insufficient.
 const exitDeadline=Date.now()+10000;
 while(exitCode===null&&Date.now()<exitDeadline)await sleep(50);
 assert.equal(exitCode,0,'external dev launcher must exit successfully');
 assert.equal(signalName,null);
  assert.equal(guestJoins,1);
  assert.equal(connections,2,'host plus one guest socket only');
  assert.doesNotMatch(consoleText,/SCRIPT ERROR|ERROR:/);
 assert.equal(host.readyState,WebSocket.OPEN);
 const before=evidence.host_snapshots??0;
 await until(()=>evidence.host_snapshots>before,5000,'continuing host snapshot after launcher exit',true);
 const health=await (await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)})).json();
  // The source intentionally retains a disconnected peer for its reconnect
  // grace interval. A client leave must not invent immediate roster deletion.
  assert.equal(health.players,departedRoster.players.length);
   assert.equal(health.rooms,initialHealth.rooms+1,'the created room and source default rooms survive guest leave');
  evidence.health_after_leave={players:health.players,rooms:health.rooms};
  evidence.source_roster_after_leave=departedRoster.players.map(p=>({peer:p.peerId,connected:p.connected}));
  evidence.guest_retained_by_source_grace=true;
 evidence.guest_joins=guestJoins;evidence.guest_disconnected=guestClosed;
 evidence.launcher_exit=exitCode;evidence.host_open_after_leave=true;evidence.passed=true;
}catch(error){evidence.error=error.stack;process.exitCode=1;}
finally{
 if(child?.pid){try{process.kill(-child.pid,'SIGTERM');}catch{}
  if(exitCode===null){
   const deadline=Date.now()+3000;while(exitCode===null&&Date.now()<deadline)await sleep(50);
   if(exitCode===null)try{process.kill(-child.pid,'SIGKILL');}catch{}
  }
 }
 host?.terminate();for(const socket of game.wss.clients)socket.terminate();
  game.server.closeAllConnections();await game.close();
  evidence.fixture_authority_closed=!game.server.listening;
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
 writeFileSync(join(output,'console.log'),consoleText);
 writeFileSync(join(output,'summary.json'),JSON.stringify(evidence,null,2)+'\n');
 console.log('GUEST_LEAVE_JOURNEY '+JSON.stringify(evidence));
}

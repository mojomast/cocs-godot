#!/usr/bin/env node
// Run ONLY after the orchestrator grants this lane the engine. Two real native
// clients plus a late wire spectator; normal source clock and ordinary inputs.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,createWriteStream,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {WebSocket} from 'ws';
import {createGameServer} from '../../../server/game-server.mjs';
const godot=process.env.GODOT_BIN??process.env.GODOT;
if(!godot)throw Error('Set GODOT_BIN or GODOT explicitly after the engine grant');
const mode=process.argv.find(x=>x.startsWith('--mode='))?.slice(7)??'juggernaut';
const map={'arsenal':'meridian-exchange','juggernaut':'meridian-exchange','team-elimination':'tidal-citadel','vip-escort':'sunscar-convoy'}[mode];
assert.ok(map,'known mode');
const bots=Number(process.env.MODE_BOTS??0);assert.ok(Number.isInteger(bots)&&bots>=0&&bots<=8);
const out=resolve(process.env.MODE_EVIDENCE??`/tmp/opencode/mode-proof-${Date.now()}`,mode);
mkdirSync(out,{recursive:true});
const game=createGameServer({historyPath:null,progressionPath:null,graceMs:15000}),children=[],logs={};
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,label,timeout=25000){const end=Date.now()+timeout;while(Date.now()<end){const value=predicate();if(value)return value;await sleep(100);}throw Error(`Timeout: ${label}`);}
function native(name,args,resolution){
 const log=createWriteStream(resolve(out,`${name}.log`));logs[name]='';
 const child=spawn(godot,['--audio-driver','Dummy','--path','godot','--resolution',resolution,'res://mode_expansion/demo.tscn','--',`--endpoint=${endpoint}`,`--map=${map}`,`--mode=${mode}`,'--mode-evidence','--mode-fixture-input',`--mode-capture=${resolve(out,name)}`,...args],{env:{...process.env,LP_NUM_THREADS:'1'},stdio:['ignore','pipe','pipe']});
 child.on('error',error=>{logs[name]+=String(error);log.write(String(error));});
 for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>{logs[name]+=String(bytes);log.write(bytes);});
 child.on('close',()=>log.end());children.push(child);return child;
}
let viewer;
try{
 native('host',[`--bots=${bots}`,'--time-limit=60','--wait-for-players=2','--mode-fixture-restart','--mode-fixture-leave'],'1280x720');
 const room=await until(()=>[...game.registry.rooms.values()].find(r=>r.mapId===map&&r.config.mode===mode&&r.peers.size===1),'native host configured');
 native('guest',[`--join-room=${room.id}`,'--mode-fixture-reconnect','--mode-fixture-leave'],'960x640');
 await until(()=>logs.host.includes('MODE_NATIVE ')&&logs.guest.includes('MODE_NATIVE '),'both native snapshot projections');
 viewer=new WebSocket(endpoint);const messages=[];viewer.on('message',bytes=>messages.push(JSON.parse(String(bytes))));
 await new Promise((resolve,reject)=>{viewer.once('open',resolve);viewer.once('error',reject);});
 viewer.send(JSON.stringify({type:'join',v:3,delta:0,roomId:room.id,name:'Mode proof viewer'}));
 const welcome=await until(()=>messages.find(f=>f.type==='welcome'),'viewer welcome');assert.equal(welcome.spectate,true);
 native('spectator',[`--join-room=${room.id}`,'--mode-fixture-leave'],'960x640');
 await until(()=>logs.spectator.includes('"spectating":true'),'native late spectator');
 const started=Date.now();
 await until(()=>logs.guest.includes('MODE_NATIVE_RECONNECT '),'native guest reconnect',20000);
 const result=await until(()=>messages.find(f=>f.type==='results'),'normal source result',100000);
 await until(()=>['host','guest','spectator'].every(name=>logs[name].includes('"phase":4')),'all native results');
 assert.match(logs.guest,/MODE_NATIVE_RECONNECT .*"resumed":true/);
 assert.ok(result.state.actors.filter(a=>!a.isNpc).every(a=>a.shots>0),'both real native players emitted ordinary input');
 await until(()=>['host','guest','spectator'].every(name=>logs[name].includes('"round":2')),'native host restart reaches native guest and spectator');
 assert.ok(messages.filter(f=>f.type==='start').length>=2,'spectator observes restart');
 await until(()=>['host','guest','spectator'].every(name=>logs[name].includes('MODE_NATIVE_HOME ')),'all native Leave/Home and route selection');
 for(const [name,text] of Object.entries(logs)){
  assert.ok(!/SCRIPT ERROR|Parse Error|Invalid call|^ERROR:|MODE_NATIVE_ERROR/m.test(text),`${name} native error`);
  const boundaries=text.split('\n').filter(line=>line.startsWith('MODE_NATIVE_BOUNDARY ')).map(line=>JSON.parse(line.slice(21)));
  assert.deepEqual(boundaries.map(x=>x.kind),['results','leave']);assert.ok(boundaries.every(x=>!x.controls&&x.pointerReleased));
 }
 const events=messages.filter(f=>f.type==='events').flatMap(f=>f.items??[]);
 writeFileSync(resolve(out,'wire-events.json'),JSON.stringify(events,null,2)+'\n');
 const proof={kind:'two-native-players-and-native-spectator-normal-rate',mode,map,bots,wallMs:Date.now()-started,sourceSeconds:result.state.time,winner:result.state.winner,objectives:result.state.objectives,players:result.state.actors.map(a=>({id:a.id,name:a.name,shots:a.shots,npc:a.isNpc===true})),crownTransfers:events.filter(e=>e.type==='juggernaut-transfer'),spectator:true,nativeSpectator:true,reconnect:true,restart:true,home:true,controlBoundaries:true};
 writeFileSync(resolve(out,'acceptance.json'),JSON.stringify(proof,null,2)+'\n');console.log('MODE_NATIVE_PROOF_OK '+JSON.stringify(proof));
}catch(error){
 writeFileSync(resolve(out,'failure.log'),String(error.stack??error)+'\n');throw error;
}finally{
 viewer?.terminate();
 await Promise.all(children.map(async child=>{
  if(child.exitCode!==null||child.signalCode!==null)return;
  const closed=new Promise(resolve=>child.once('close',resolve));
  child.kill('SIGTERM');const timer=setTimeout(()=>child.kill('SIGKILL'),5000);
  await closed;clearTimeout(timer);
 }));
 await game.close();
 writeFileSync(resolve(out,'teardown.json'),JSON.stringify(children.map(child=>({pid:child.pid,exitCode:child.exitCode,signalCode:child.signalCode})),null,2)+'\n');
}

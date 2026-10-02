#!/usr/bin/env node
// Run ONLY after the orchestrator grants this lane the engine. Two real native
// clients plus a late wire spectator; normal source clock and ordinary inputs.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,createWriteStream,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {WebSocket} from 'ws';
import {createGameServer} from '../../../server/game-server.mjs';
if(!process.env.GODOT)throw Error('Set GODOT explicitly after the engine grant');
const mode=process.argv.find(x=>x.startsWith('--mode='))?.slice(7)??'juggernaut';
const map={'arsenal':'meridian-exchange','juggernaut':'meridian-exchange','team-elimination':'tidal-citadel','vip-escort':'sunscar-convoy'}[mode];
assert.ok(map,'known mode');
const out=resolve(process.env.MODE_EVIDENCE??'/home/mojo/.tmp-on-disk/cocs-port-modes-evidence-20261001',mode);
mkdirSync(out,{recursive:true});
const game=createGameServer({historyPath:null,progressionPath:null,graceMs:15000}),children=[],logs={};
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,label,timeout=25000){const end=Date.now()+timeout;while(Date.now()<end){const value=predicate();if(value)return value;await sleep(100);}throw Error(`Timeout: ${label}`);}
function native(name,args,resolution){
 const log=createWriteStream(resolve(out,`${name}.log`));logs[name]='';
 const child=spawn(process.env.GODOT,['--path','godot','--resolution',resolution,'res://mode_expansion/demo.tscn','--',`--endpoint=${endpoint}`,`--map=${map}`,`--mode=${mode}`,'--mode-evidence','--mode-fixture-input',`--mode-capture=${resolve(out,name)}`,...args],{env:{...process.env,LP_NUM_THREADS:'1'},stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>{logs[name]+=String(bytes);log.write(bytes);});
 child.on('close',()=>log.end());children.push(child);return child;
}
let viewer;
try{
 native('host',['--bots=0','--time-limit=60','--wait-for-players=2','--mode-fixture-restart'],'1280x720');
 const room=await until(()=>[...game.registry.rooms.values()].find(r=>r.mapId===map&&r.config.mode===mode&&r.peers.size===1),'native host configured');
 native('guest',[`--join-room=${room.id}`,'--mode-fixture-reconnect'],'960x640');
 await until(()=>logs.host.includes('MODE_NATIVE ')&&logs.guest.includes('MODE_NATIVE '),'both native snapshot projections');
 viewer=new WebSocket(endpoint);const messages=[];viewer.on('message',bytes=>messages.push(JSON.parse(String(bytes))));
 await new Promise((resolve,reject)=>{viewer.once('open',resolve);viewer.once('error',reject);});
 viewer.send(JSON.stringify({type:'join',v:3,delta:0,roomId:room.id,name:'Mode proof viewer'}));
 const welcome=await until(()=>messages.find(f=>f.type==='welcome'),'viewer welcome');assert.equal(welcome.spectate,true);
 const started=Date.now();
 const result=await until(()=>messages.find(f=>f.type==='results'),'normal source result',100000);
 await until(()=>logs.host.includes('"phase":4')&&logs.guest.includes('"phase":4'),'both native results');
 assert.match(logs.guest,/MODE_NATIVE_RECONNECT .*"resumed":true/);
 assert.ok(result.state.actors.filter(a=>!a.isNpc).every(a=>a.shots>0),'both real native players emitted ordinary input');
 await until(()=>logs.host.includes('"round":2')&&logs.guest.includes('"round":2'),'native host restart reaches native guest');
 assert.ok(messages.filter(f=>f.type==='start').length>=2,'spectator observes restart');
 for(const [name,text] of Object.entries(logs))assert.ok(!/SCRIPT ERROR|Parse Error|Invalid call/.test(text),`${name} native error`);
 const proof={kind:'two-native-normal-rate',mode,map,wallMs:Date.now()-started,sourceSeconds:result.state.time,winner:result.state.winner,objectives:result.state.objectives,players:result.state.actors.map(a=>({id:a.id,name:a.name,shots:a.shots,npc:a.isNpc===true})),spectator:true,reconnect:true,restart:true};
 writeFileSync(resolve(out,'acceptance.json'),JSON.stringify(proof,null,2)+'\n');console.log('MODE_NATIVE_PROOF_OK '+JSON.stringify(proof));
}finally{
 viewer?.terminate();for(const child of children)child.kill('SIGTERM');
 await Promise.all(children.map(child=>new Promise(resolve=>{if(child.exitCode!==null)return resolve();child.once('close',resolve);setTimeout(()=>{child.kill('SIGKILL');resolve();},5000).unref();})));
 await game.close();
}

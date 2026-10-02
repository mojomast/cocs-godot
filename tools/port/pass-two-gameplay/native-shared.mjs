// Native guest with a scripted source-wire owner. Engine slot required.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {WebSocket} from 'ws';
import {createGameServer} from '../../../server/game-server.mjs';
assert.equal(process.env.PLAYER_GAMEPLAY_ENGINE_GRANTED,'1','parent exclusive engine grant required');
assert.ok(process.env.GODOT_BIN,'pinned Godot 4.5.2 required');
const out=resolve(process.env.EVIDENCE_DIR??'/home/mojo/.tmp-on-disk/cocs-pass-two-gameplay-evidence-20261002/native-shared');mkdirSync(out,{recursive:true});
const game=createGameServer({random:()=>.5,historyPath:null,progressionPath:null});
const trace=[];
game.wss.on('connection',socket=>{
  socket.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')trace.push({direction:'input',frame:f});});
  const send=socket.send;socket.send=function(raw,...args){const f=JSON.parse(raw);if(['snapshot','events'].includes(f.type))trace.push({direction:'source',frame:f});return send.call(this,raw,...args);};
});
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
const owner=new WebSocket(endpoint);
let room='',configured=false,started=false,placed=false,seq=0,child,log='';
const send=f=>owner.send(JSON.stringify(f));
try {
  owner.on('message',raw=>{
    const frame=JSON.parse(raw);
    if(frame.type==='welcome')room=frame.roomId;
    if(frame.type==='lobby'&&frame.players.length>=2&&!configured){configured=true;send({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0,timeLimit:180,fragLimit:100}});}
    else if(frame.type==='lobby'&&configured&&!started&&frame.mapId==='meridian-exchange'&&frame.config?.botCount===0){started=true;send({type:'start'});}
    if(frame.type==='snapshot'){
      const [host,guest]=frame.state.actors;
      const cast=!placed&&Math.hypot(host.x-guest.x,host.z-guest.z)<25;
      if(cast)placed=true;
      send({type:'input',seq:++seq,input:{yaw:0,pitch:-.35,mobility:cast,power:cast}});
    }
  });
  await new Promise((r,j)=>{owner.once('open',r);owner.once('error',j);});
  send({type:'create',name:'Native shared rope',playerName:'Source owner',character:'qwen',harness:'codex',v:3,delta:0});
  const deadline=Date.now()+5000;
  while(!room&&Date.now()<deadline)await new Promise(r=>setTimeout(r,10));assert.ok(room);
  child=spawn('xvfb-run',['-a',process.env.GODOT_BIN,'--audio-driver','Dummy','--path',resolve('godot'),'--script','res://tests/player_gameplay/second_pass_shared.gd','--','--operator=mistral','--harness=codex',`--join-room=${room}`,`--endpoint=${endpoint}`,`--evidence=${out}`],{detached:true,env:{...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1'},stdio:['ignore','pipe','pipe']});
  child.stdout.on('data',x=>log+=x);child.stderr.on('data',x=>log+=x);
  const timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch(e){if(e.code!=='ESRCH')throw e;}},80000);
  const code=await new Promise((r,j)=>{child.once('error',j);child.once('close',r);});clearTimeout(timer);
  assert.equal(code,0,'native guest journey');assert.doesNotMatch(log,/SCRIPT ERROR|ERROR:/);
  assert.match(log,/SECOND_PASS_SHARED .*"ok":true/);
  console.log('SECOND_PASS_NATIVE_SHARED_OK');
} finally {
  writeFileSync(resolve(out,'native.log'),log);writeFileSync(resolve(out,'trace.json'),JSON.stringify(trace));
  owner.terminate();for(const socket of game.wss.clients)socket.terminate();await game.close();
}

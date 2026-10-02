import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {createGameServer} from '../../../server/game-server.mjs';
const binary=process.env.GODOT_BIN;
assert.ok(binary,'GODOT_BIN required');
const out=resolve(process.env.EVIDENCE_DIR??'/home/mojo/.tmp-on-disk/cocs-port-gameplay-evidence-20261001/live');
mkdirSync(out,{recursive:true});
const server=createGameServer({historyPath:null,progressionPath:null});
await new Promise(r=>server.server.listen(0,'127.0.0.1',r));
const wire=[];
const snapshots=[];
server.wss.on('connection',socket=>{
 socket.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')wire.push(f);});
 const send=socket.send;
 socket.send=function(raw,...args){
  const f=JSON.parse(raw);
  if(f.type==='snapshot')snapshots.push({seq:f.seq,acks:f.acks,actors:f.state.actors.map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,cooldown:a.cooldown,active:a.active,movement:a.movement,zipRide:a.zipRide}))});
  return send.call(this,raw,...args);
 };
});
const results=[];
try{
 for(const operator of (process.env.OPERATORS??'kimi,qwen,chatgpt').split(',')){
  const start=wire.length;
  const snapshotStart=snapshots.length;
  const args=['-a',binary,'--audio-driver','Dummy','--path',resolve('godot'),'--script','res://player_gameplay/live.gd','--','--bots=0',`--operator=${operator}`,'--harness=codex',`--endpoint=ws://127.0.0.1:${server.server.address().port}`,`--evidence=${out}`];
  const child=spawn('xvfb-run',args,{env:{...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1'},stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='';child.stdout.on('data',x=>stdout+=x);child.stderr.on('data',x=>stderr+=x);
  const timer=setTimeout(()=>child.kill('SIGKILL'),45000);
  const code=await new Promise((r,j)=>{child.on('error',j);child.on('close',r);});clearTimeout(timer);
  writeFileSync(resolve(out,operator+'.log'),stdout+'\nSTDERR\n'+stderr);
  writeFileSync(resolve(out,operator+'-wire.json'),JSON.stringify(wire.slice(start),null,2));
  const observations=snapshots.slice(snapshotStart);
  writeFileSync(resolve(out,operator+'-snapshots.json'),JSON.stringify(observations,null,2));
  const summary=stdout.split('\n').find(l=>l.startsWith('JOURNEY_RESULT '));
  results.push({operator,code,summary:summary?JSON.parse(summary.slice(15)):null});
  console.log(operator,code,summary??stderr.slice(-500));
  assert.equal(code,0,operator+' native journey');
  assert.ok(wire.slice(start).some(f=>f.input.mobility===true),'wire accepted X pulse');
  assert.ok(observations.some(s=>s.actors[0].cooldown>0),'authority accepted power cooldown');
  assert.ok(observations.some(s=>s.actors[0].movement?.cooldown>0),'authority spent movement cooldown');
  const first=observations[0].actors[0];
  assert.ok(observations.some(s=>Math.hypot(s.actors[0].x-first.x,s.actors[0].z-first.z)>0.5),'source displacement after native X');
  if(operator==='qwen'){
   assert.ok(observations.some(s=>s.actors[0].zipRide!==null),'source rope ride');
   assert.ok(results.at(-1).summary.max_cables>0,'native cable presented');
  }
 }
}finally{
 writeFileSync(resolve(out,'results.json'),JSON.stringify(results,null,2));
 for(const socket of server.wss.clients)socket.terminate();
 await server.close();
}

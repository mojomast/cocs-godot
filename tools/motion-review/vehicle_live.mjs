import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {createGameServer} from '../../port/multiplayer-worlds/derived/game-server.mjs';

const [binary,output]=process.argv.slice(2);
assert.ok(binary&&output,'explicit engine/output required');
mkdirSync(output,{recursive:true});
const game=createGameServer({historyPath:null,progressionPath:null});
const wire=[];
game.wss.on('connection',socket=>socket.on('message',raw=>{
  const frame=JSON.parse(raw);if(frame.type==='input')wire.push(frame);
}));
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
let child,timer,text='';
try {
  child=spawn('python3',['tools/godot-dev/xvfb_run.py',binary,'--path','godot',
    '--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/sports/view_live.gd','--',
    `--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--map=stormglass-causeway','--bots=0','--time-limit=60',
    '--compact',`--evidence-out=${resolve(output)}`],{stdio:['ignore','pipe','pipe'],env:{...process.env,LP_NUM_THREADS:'1'}});
  for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>text+=chunk);
  timer=setTimeout(()=>child.kill('SIGTERM'),110000);
  const code=await new Promise((r,j)=>{child.on('error',j);child.on('close',r);});
  writeFileSync(resolve(output,'native.log'),text);
  assert.equal(code,0);assert.ok(!/SCRIPT ERROR|ERROR:|instances leaked/.test(text));
  assert.ok(wire.length>0,'native input reached authority');
  assert.equal(JSON.parse(readFileSync(resolve(output,'native.json'))).passed,true);
  console.log('VEHICLE_VIEW_LIVE_OK');
} finally {
  clearTimeout(timer);
  writeFileSync(resolve(output,'wire.json'),JSON.stringify(wire));
  for(const client of game.wss.clients)client.terminate();
  await game.close();
  writeFileSync(resolve(output,'teardown.json'),JSON.stringify({nativeExit:child?.exitCode,authorityClosed:true}));
}

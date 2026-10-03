// N supplemental ordinary-input probe; source authority is never mutated.
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {createGameServer} from '../../server/game-server.mjs';

const [binary, directory, route] = process.argv.slice(2);
assert.ok(binary && directory && ['combined','world'].includes(route));
const output = resolve(directory);
mkdirSync(output, {recursive:true});
const game = createGameServer({historyPath:null,progressionPath:null,random:()=>.37});
const wire=[];
game.wss.on('connection',socket=>socket.on('message',raw=>{
  const frame=JSON.parse(raw); if(frame.type==='input')wire.push(frame);
}));
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
let child,timer,text='';
try {
  child=spawn('python3',['tools/godot-dev/xvfb_run.py',binary,'--path','godot',
    '--rendering-method','gl_compatibility','--audio-driver','Dummy',
    '--script','res://tests/combined_arms/ordinary_views.gd','--',
    `--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--map=sunscar-convoy',
    `--mode=${route==='world'?'teamdeathmatch':'combined-arms'}`,'--bots=0',`--view-route=${route}`,`--evidence-out=${output}`],
    {stdio:['ignore','pipe','pipe'],env:{...process.env,LP_NUM_THREADS:'1'}});
  for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>text+=chunk);
  timer=setTimeout(()=>child.kill('SIGTERM'),145000);
  const code=await new Promise((r,j)=>{child.on('error',j);child.on('close',r);});
  writeFileSync(output+'/native.log',text);
  assert.equal(code,0);
  assert.doesNotMatch(text,/SCRIPT ERROR|ERROR:|instances leaked|resources still in use|RID[^\n]*leak/i);
  assert.equal(JSON.parse(readFileSync(output+'/native.json')).passed,true);
  assert.ok(wire.some(f=>f.input?.interact),'actual interact packet reached authority');
  console.log('ORDINARY_VEHICLE_OK',route);
}finally{
  clearTimeout(timer);
  writeFileSync(output+'/wire.json',JSON.stringify(wire));
  for(const socket of game.wss.clients)socket.terminate();
  await game.close();
  writeFileSync(output+'/teardown.json',JSON.stringify({nativeExit:child?.exitCode,authorityClosed:true}));
}

// Narrow actual host-scene integration after graphical capability acceptance.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createGameServer} from '../../server/game-server.mjs';
const root=resolve(import.meta.dirname,'../..');
const output=resolve(process.argv.find(arg=>arg.startsWith('--output='))?.slice('--output='.length)||resolve(import.meta.dirname,'evidence'));
const binary=process.env.GODOT_BIN;
assert.equal(execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),'4.5.2.stable.official.6ce3de25a');
mkdirSync(output,{recursive:true});
const game=createGameServer({historyPath:null,progressionPath:null});
const children=new Set();
await new Promise(ok=>game.server.listen(0,'127.0.0.1',ok));
try{
  for(const map of ['meridian-exchange','verdant-reliquary','ember-crucible']){
    const child=spawn(binary,['--headless','--audio-driver','Dummy','--path',resolve(root,'godot'),'res://world/session.tscn','--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,`--map=${map}`,'--mode=rockets','--session-smoke','--mute'],{cwd:root,stdio:['ignore','pipe','pipe']});
    children.add(child);let text='';
    const collect=data=>{text+=data;if(text.length>100000)child.kill('SIGKILL');};
    child.stdout.on('data',collect);child.stderr.on('data',collect);
    const timer=setTimeout(()=>child.kill('SIGKILL'),30000);
    const code=await new Promise((ok,fail)=>{child.once('error',fail);child.once('exit',ok);});
    clearTimeout(timer);children.delete(child);writeFileSync(resolve(output,map+'-smoke.log'),text);
    assert.equal(code,0,map);assert.ok(!/SCRIPT ERROR|ERROR:|leaked at exit/.test(text),map);
    const line=text.split('\n').find(l=>l.startsWith('PORT_SESSION_SMOKE_OK '));
    assert.ok(line&&/local_launches=[1-9]/.test(line),map);console.log(line);
  }
}finally{
  for(const child of children)child.kill('SIGKILL');
  for(const ws of game.wss.clients)ws.terminate();
  await game.close();
}

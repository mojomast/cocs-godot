import {spawn} from 'node:child_process';
import fs from 'node:fs';
import {createGameServer} from '../../server/game-server.mjs';

// Short grace is intentional: exercise the source's refused reattach/fresh
// spectator admission without waiting 20 seconds in the fixture.
const game=createGameServer({port:0,graceMs:1000});
const engine=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const credentials=`/tmp/opencode/native-reconnect-identity-${process.pid}.json`;
let child,timer;
try {
 await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 fs.writeFileSync(credentials,JSON.stringify({version:1,scopes:{}}),{mode:0o600});
 child=spawn(engine,['--headless','--path','godot','--script','res://tests/protocol/reconnect.gd','--',endpoint],{
  cwd:new URL('../../',import.meta.url).pathname,
  env:{...process.env,COCS_CAREER_ROOT:`/tmp/opencode/native-reconnect-career-${process.pid}`,COCS_CAREER_CREDENTIALS_PATH:credentials,COCS_CAREER_SCOPE:'reconnect-fixture',COCS_CAREER_ENDPOINT:endpoint},stdio:['ignore','pipe','pipe']});
 let output='';
 for(const stream of [child.stdout,child.stderr])stream.on('data',data=>{output=(output+data.toString()).slice(-65536);});
 timer=setTimeout(()=>child.kill('SIGKILL'),30000);
 const code=await new Promise((resolve,reject)=>{child.on('exit',(exit,signal)=>resolve(exit??(signal?1:0)));child.on('error',reject);});
 const pass=output.match(/PORT_NATIVE_RECONNECT_OK checks=(\d+) genuine_source_socket=true/);
 if(code!==0||/SCRIPT ERROR|ERROR:|Parse Error|Assertion failed/i.test(output)||!pass||Number(pass[1])<59)throw Error('native reconnect journey did not pass (exit, engine diagnostic or marker)');
 console.log(`PORT_NATIVE_RECONNECT_OK checks=${pass[1]} genuine_source_socket=true`);
} finally {
 clearTimeout(timer);
 if(child&&!child.killed&&child.exitCode===null)child.kill('SIGKILL');
 fs.rmSync(credentials,{force:true});
 await game.close();
}

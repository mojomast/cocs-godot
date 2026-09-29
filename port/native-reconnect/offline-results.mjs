import {spawn} from 'node:child_process';
import fs from 'node:fs';
import {createGameServer} from '../../server/game-server.mjs';

const flag=`/tmp/opencode/native-reconnect-results-${process.pid}.ready`;
fs.rmSync(flag,{force:true});
const game=createGameServer({port:0,graceMs:20000});
const engine=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
let child,timer,stepped=false,output='',clockError=false;
try {
 await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
 child=spawn(engine,['--headless','--path','godot','--script','res://tests/protocol/reconnect_results.gd','--',`ws://127.0.0.1:${game.server.address().port}`,flag],{
  cwd:new URL('../../',import.meta.url).pathname,
  env:{...process.env,COCS_CAREER_ROOT:`/tmp/opencode/native-reconnect-results-career-${process.pid}`},stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',data=>{
  output=(output+data.toString()).slice(-65536);
  if(!stepped&&output.includes('PORT_RESULTS_SOURCE_CLOCK_READY')){
   stepped=true;
   setImmediate(()=>{
    try {
     const room=[...game.registry.rooms.values()].find(value=>value.match&&!value.roundOver);
     if(!room)throw Error('no live source room');
     // Accelerate genuine fixed steps; never inject score, winner or results.
     for(let i=0;i<900&&!room.roundOver;i++)room.tick(0.25);
     if(!room.roundOver)throw Error('source clock did not settle');
     fs.writeFileSync(flag,'settled\n');
    } catch {clockError=true;child.kill('SIGKILL');}
   });
  }
 });
 child.stderr.on('data',data=>{output=(output+data.toString()).slice(-65536);});
 timer=setTimeout(()=>child.kill('SIGKILL'),30000);
 const code=await new Promise((resolve,reject)=>{child.on('exit',(exit,signal)=>resolve(exit??(signal?1:0)));child.on('error',reject);});
 if(code!==0||clockError||!stepped||/SCRIPT ERROR|ERROR:|Parse Error|Assertion failed/i.test(output)||!output.includes('PORT_RECONNECT_OFFLINE_RESULTS_OK source_settlement=true result_frames=1'))throw Error('offline source-results journey did not pass (exit, engine diagnostic or marker)');
 console.log('PORT_RECONNECT_OFFLINE_RESULTS_OK source_settlement=true result_frames=1');
} finally {
 clearTimeout(timer);
 if(child&&!child.killed&&child.exitCode===null)child.kill('SIGKILL');
 fs.rmSync(flag,{force:true});
 await game.close();
}

import {spawn} from 'node:child_process';
import fs from 'node:fs';
import {createGameServer} from '../../server/game-server.mjs';

const flag=`/tmp/opencode/native-reconnect-results-${process.pid}.ready`;
fs.rmSync(flag,{force:true});
const game=createGameServer({port:0,graceMs:20000});
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
const engine=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const child=spawn(engine,['--headless','--path','godot','--script','res://tests/protocol/reconnect_results.gd','--',`ws://127.0.0.1:${game.server.address().port}`,flag],{
 cwd:new URL('../../',import.meta.url).pathname,
 env:{...process.env,COCS_CAREER_ROOT:process.env.COCS_CAREER_ROOT??'/tmp/opencode/native-reconnect-career'},stdio:['ignore','pipe','inherit']});
let stepped=false;
child.stdout.on('data',data=>{
 process.stdout.write(data);
 if(!stepped&&String(data).includes('PORT_RESULTS_SOURCE_CLOCK_READY')){
  stepped=true;
  setImmediate(()=>{
   const room=[...game.registry.rooms.values()].find(value=>value.match&&!value.roundOver);
   if(!room){child.kill('SIGKILL');return;}
   // The source simulation itself settles its time limit through fixed steps.
   // This accelerates its clock while the native socket remains disconnected;
   // no result frame, winner, score or terminal state is injected.
   for(let i=0;i<900&&!room.roundOver;i++)room.tick(0.25);
   if(!room.roundOver){child.kill('SIGKILL');return;}
   fs.writeFileSync(flag,'settled\n');
  });
 }
});
const timer=setTimeout(()=>child.kill('SIGKILL'),30000);
const code=await new Promise(resolve=>child.on('exit',(exit,signal)=>resolve(exit??(signal?1:0))));
clearTimeout(timer);
fs.rmSync(flag,{force:true});
await game.close();
if(code!==0||!stepped)process.exitCode=1;

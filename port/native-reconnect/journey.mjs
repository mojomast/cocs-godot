import {spawn} from 'node:child_process';
import {createGameServer} from '../../server/game-server.mjs';

// Short grace is intentional: exercise the source's refused reattach/fresh
// spectator admission without waiting 20 seconds in the fixture.
const game=createGameServer({port:0,graceMs:1000});
await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
const engine=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
const child=spawn(engine,['--headless','--path','godot','--script','res://tests/protocol/reconnect.gd','--',endpoint],{
 cwd:new URL('../../',import.meta.url).pathname,
 env:{...process.env,COCS_CAREER_ROOT:process.env.COCS_CAREER_ROOT??'/tmp/opencode/native-reconnect-career'},stdio:'inherit'});
const timer=setTimeout(()=>child.kill('SIGKILL'),30000);
const code=await new Promise(resolve=>child.on('exit',(exit,signal)=>resolve(exit??(signal?1:0))));
clearTimeout(timer);
await game.close();
if(code!==0)process.exitCode=code;

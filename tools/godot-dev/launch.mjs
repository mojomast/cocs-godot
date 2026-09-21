import {createGameServer} from '../../server/game-server.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {verifySource} from '../godot-export/semantic.mjs';
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;if(!binary)throw Error('Set GODOT_BIN to pinned Godot 4.5.2 executable');
if(execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version)throw Error('Godot version differs from lock');
const runtime=resolve('.port-runtime');mkdirSync(runtime,{recursive:true});
const env={...process.env};for(const [name,dir]of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]){env[name]=resolve(runtime,dir);mkdirSync(env[name],{recursive:true});}
const game=createGameServer({historyPath:null,progressionPath:null});let child;
const stop=()=>{child?.kill('SIGTERM');};process.once('SIGINT',stop);process.once('SIGTERM',stop);
try{
 await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(Number(process.env.PORT??0),'127.0.0.1',resolve);});
 const port=game.server.address().port;const health=await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)});if(!health.ok)throw Error('Server readiness failed');
 const smoke=process.argv.includes('--network-smoke');
 const sessionSmoke=process.argv.includes('--session-smoke');
 const play=sessionSmoke||process.argv.includes('--play');
 const args=smoke?['--headless','--path','godot','--script','res://tests/protocol/live.gd']: [...(sessionSmoke?['--headless']:[]),'--path','godot',...(play?['res://world/session.tscn']:[])];
 args.push('--',`--endpoint=ws://127.0.0.1:${port}`,...(sessionSmoke?['--session-smoke']:[]));
 console.log(`Owned local server ready on loopback:${port}; ${smoke?'native transport smoke':play?'native diagnostic gameplay session':'semantic viewer'}`);
 child=spawn(binary,args,{env,stdio:'inherit'});
 process.exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code)=>resolve(code??1));});
}finally{stop();await game.close();process.removeListener('SIGINT',stop);process.removeListener('SIGTERM',stop);}

import {createGameServer} from '../../server/game-server.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {verifySource} from '../godot-export/semantic.mjs';
import {launchOptions,HELP} from './launch_options.mjs';
if(process.argv.includes('--help')){console.log(HELP);process.exit(0);}
const plan=launchOptions(process.argv.slice(2),JSON.parse(readFileSync('port/contracts/map-selection.json')));
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
 const args=[...plan.args,'--',`--endpoint=ws://127.0.0.1:${port}`,...plan.sessionOptions];
 console.log(`Owned local server ready on loopback:${port}; ${plan.smoke??plan.experience}`);
 child=spawn(binary,args,{env,stdio:'inherit'});
 process.exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code)=>resolve(code??1));});
}finally{stop();await game.close();process.removeListener('SIGINT',stop);process.removeListener('SIGTERM',stop);}

import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
import {verifySource} from '../godot-export/semantic.mjs';
import {launchOptions,HELP} from './launch_options.mjs';
if(process.argv.length===3&&process.argv[2]==='--help'){console.log(HELP);process.exit(0);}
const plan=launchOptions(process.argv.slice(2),JSON.parse(readFileSync('port/contracts/map-selection.json')));
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;if(!binary)throw Error('Set GODOT_BIN to pinned Godot 4.5.2 executable');
if(execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version)throw Error('Godot version differs from lock');
const factory=plan.nativeOnly||plan.endpoint ? null : plan.experience==='horde'
 ? (await import('../../port/native-horde/authority.mjs')).createAuthority
 : (await import('../../server/game-server.mjs')).createGameServer;
const runtime=plan.nativeOnly?mkdtempSync(join(tmpdir(),'cocs-native-')):resolve('.port-runtime');mkdirSync(runtime,{recursive:true});
const env={...process.env};for(const [name,dir]of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]){env[name]=resolve(runtime,dir);mkdirSync(env[name],{recursive:true});}
let game,child,childDone,stopping=false,signalCode=0,serverFailure,killTimer;
const stop=()=>{stopping=true;if(child&&child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');killTimer??=setTimeout(()=>child.kill('SIGKILL'),3000);killTimer.unref();}};
const interrupt=()=>{signalCode=130;stop();},terminate=()=>{signalCode=143;stop();},serverError=error=>{serverFailure=error;stop();};
process.once('SIGINT',interrupt);process.once('SIGTERM',terminate);
try{
 game=factory?.(plan.experience==='horde'?{}:{historyPath:null,progressionPath:null});
 game?.server.on('error',serverError);
 let endpoint=plan.endpoint;
 if(game){
  await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(Number(process.env.PORT??0),'127.0.0.1',()=>{game.server.removeListener('error',reject);resolve();});});
  const port=game.server.address().port;const health=await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)});if(!health.ok)throw Error('Server readiness failed');
  if(plan.experience==='horde'){
   const status=await health.json();
   if(status?.service!=='cocs-local-horde'||status.transport!==1||status.localOnly!==true||status.port!==port)throw Error('Horde readiness identity failed');
  }
  endpoint=`ws://127.0.0.1:${port}`;
  console.log(`Owned local server ready at ${endpoint}; ${plan.smoke??plan.experience}`);
 }else if(plan.nativeOnly)console.log(`Native-only ${plan.experience}; no authority; this launcher owns the native client`);
 else console.log('Using existing authority; this launcher owns only the native client');
 const args=[...plan.args,'--',...(plan.nativeOnly?[]:[`--endpoint=${endpoint}`]),...plan.sessionOptions];
 if(!stopping){
  child=spawn(binary,args,{env,stdio:'inherit'});
  childDone=new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code)=>resolve(code??1));});
  process.exitCode=await childDone;
 }
 if(serverFailure)throw serverFailure;
 if(signalCode)process.exitCode=signalCode;
}finally{
 stop();if(childDone)await childDone.catch(()=>{});clearTimeout(killTimer);
 if(game){for(const socket of game.wss.clients)socket.terminate();game.server.closeAllConnections();await game.close();game.server.removeListener('error',serverError);}
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',terminate);
 if(plan.nativeOnly)rmSync(runtime,{recursive:true,force:true,maxRetries:5,retryDelay:100});
}

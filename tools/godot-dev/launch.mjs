import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
import {verifySource} from '../godot-export/semantic.mjs';
import {launchOptions,HELP} from './launch_options.mjs';
if(process.argv.length===3&&process.argv[2]==='--help'){console.log(HELP);process.exit(0);}
const catalog=JSON.parse(readFileSync('port/contracts/map-selection.json'));
const plan=launchOptions(process.argv.slice(2),catalog);
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;if(!binary)throw Error('Set GODOT_BIN to pinned Godot 4.5.2 executable');
if(execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version)throw Error('Godot version differs from lock');

// One direct route run: authority selection, spawn and cleanup exactly as the
// pre-menu body; only the exit code is returned instead of assigned.
async function runRoute(plan){
  const debug=plan.sessionOptions.includes('--debug-panel'),previousDebug=process.env.COCS_DEBUG;
  if(debug)process.env.COCS_DEBUG='1';
  const factory=plan.nativeOnly||plan.endpoint ? null : plan.nativeArena
 ? (await import('../../port/native-arenas/authority.mjs')).createNativeArenaAuthority
 : plan.identityZone
 ? (await import('../../port/native-identity-zones/authority.mjs')).createIdentityZoneAuthority
 : plan.experience==='horde'
 ? (await import('../../port/native-horde/authority.mjs')).createAuthority
 : (await import('../../server/game-server.mjs')).createGameServer;
 const privateRuntime=plan.nativeOnly||plan.nativeArena;
 const runtime=privateRuntime?mkdtempSync(join(tmpdir(),'cocs-native-')):resolve('.port-runtime');mkdirSync(runtime,{recursive:true});
 const env={...process.env};for(const [name,dir] of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]){env[name]=resolve(runtime,dir);mkdirSync(env[name],{recursive:true});}
 let game,child,childDone,stopping=false,signalCode=0,serverFailure,killTimer,smokeTimer;
 const stop=()=>{stopping=true;if(child&&child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');killTimer??=setTimeout(()=>child.kill('SIGKILL'),3000);killTimer.unref();}};
 const interrupt=()=>{signalCode=130;stop();},terminate=()=>{signalCode=143;stop();},serverError=error=>{serverFailure=error;stop();};
 process.once('SIGINT',interrupt);process.once('SIGTERM',terminate);
 try{
  game=await factory?.(plan.nativeArena?{port:0,host:'127.0.0.1',mapId:plan.map,mode:plan.mode,bots:plan.bots,roundSeconds:plan.roundSeconds}:plan.identityZone?{port:0,host:'127.0.0.1',mode:plan.mode,bots:plan.bots,roundSeconds:plan.roundSeconds,fragLimit:plan.scoreLimit}:plan.experience==='horde'?{}:{historyPath:null,progressionPath:null});
  game?.server?.on('error',serverError);
  let endpoint=plan.endpoint;
  if(game){
   if(!(plan.nativeArena||plan.identityZone) || (!game.endpoint && !game.server?.listening))await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(plan.nativeArena?0:Number(process.env.PORT??0),'127.0.0.1',()=>{game.server.removeListener('error',reject);resolve();});});
   const ownedEndpoint=(plan.nativeArena||plan.identityZone)&&game.endpoint?game.endpoint:`ws://127.0.0.1:${game.server.address().port}`;
   const owned=new URL(ownedEndpoint);
   // Each owned authority supports exactly its own documented routes. Check the
   // original spelling too: URL normalization must not admit other paths.
   const allowedPath=plan.nativeArena?[owned.origin,`${owned.origin}/`,`${owned.origin}/native-arenas`].includes(ownedEndpoint)
    :plan.identityZone?[owned.origin,`${owned.origin}/`,`${owned.origin}/native-zones`].includes(ownedEndpoint)
    :owned.pathname==='/';
   if(owned.protocol!=='ws:'||owned.hostname!=='127.0.0.1'||!owned.port||owned.username||owned.password||!allowedPath||owned.search||owned.hash)throw Error('Owned authority must use a private loopback endpoint');
   const port=Number(owned.port);const health=await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)});if(!health.ok)throw Error('Server readiness failed');
   if(plan.nativeArena){
    const status=await health.json();
    if(status?.localOnly!==true||status.port!==port)throw Error('Native DM readiness identity failed');
   }else if(plan.identityZone){
    const status=await health.json();
    if(status?.localOnly!==true||status.port!==port||status?.mode!=='domination')throw Error('Identity zone readiness identity failed');
   }else if(plan.experience==='horde'){
    const status=await health.json();
    if(status?.service!=='cocs-local-horde'||status.transport!==1||status.localOnly!==true||status.port!==port)throw Error('Horde readiness identity failed');
   }
   endpoint=`ws://127.0.0.1:${port}${plan.nativeArena&&owned.pathname==='/native-arenas'?'/native-arenas':''}`;
   console.log(`Owned local server ready at ${endpoint}; ${plan.smoke??plan.experience}`);
  }else if(plan.nativeOnly)console.log(`Native-only ${plan.experience}; no authority; this launcher owns the native client`);
  else console.log('Using existing authority; this launcher owns only the native client');
  const args=[...plan.args,'--',...(plan.nativeOnly?[]:[`--endpoint=${endpoint}`]),...plan.sessionOptions];
  let code=0;
  if(!stopping){
    child=spawn(binary,args,{env,stdio:'inherit'});
    childDone=new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code)=>resolve(code??1));});
    if(plan.nativeArena&&plan.smoke)smokeTimer=setTimeout(()=>serverError(Error('Native DM smoke exceeded 20 seconds')),20000);
   code=await childDone;
  }
  if(serverFailure)throw serverFailure;
  if(signalCode)code=signalCode;
  return code;
  }finally{
   stop();if(childDone)await childDone.catch(()=>{});clearTimeout(killTimer);clearTimeout(smokeTimer);
   if(game){for(const socket of game.wss?.clients??[])socket.terminate();game.server?.closeAllConnections();await game.close();game.server?.removeListener('error',serverError);}
   process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',terminate);
   if(privateRuntime)rmSync(runtime,{recursive:true,force:true,maxRetries:5,retryDelay:100});
   if(previousDebug===undefined)delete process.env.COCS_DEBUG;else process.env.COCS_DEBUG=previousDebug;
  }
}

// Spawn the menu child (same binary and project path, no authority) with
// stdout/stderr piped and tee'd line-by-line to ours. Resolves the raw
// MENU_ROUTE payload string, or null when the menu quits or exits without one.
function spawnMenu(menuPlan,env){
 return new Promise((resolve,reject)=>{
  const child=spawn(binary,[...menuPlan.args,'--',...menuPlan.sessionOptions],{env,stdio:['inherit','pipe','pipe']});
  let payload=null;
  const onLine=line=>{const clean=line.endsWith('\r')?line.slice(0,-1):line;if(clean.startsWith('MENU_ROUTE '))payload=clean.slice('MENU_ROUTE '.length);};
  const tee=(stream,write)=>{let buffer='';stream.setEncoding('utf8');
   stream.on('data',chunk=>{buffer+=chunk;let index;while((index=buffer.indexOf('\n'))!==-1){const line=buffer.slice(0,index);buffer=buffer.slice(index+1);write(line);onLine(line);}});
   stream.on('end',()=>{if(buffer!==''){write(buffer);onLine(buffer);buffer='';}});};
  tee(child.stdout,line=>console.log(line));
  tee(child.stderr,line=>console.error(line));
  child.once('error',reject);
  child.once('exit',()=>resolve(payload));
 });
}

// Supervisor semantics identical to tools/godot-package/run.mjs: revalidate the
// picked argv with the SAME launchOptions() validator, print
// MENU_ROUTE_REJECTED and respawn on a bad pick, throw after 3 consecutive
// rejections, return null for MENU_QUIT / exit without a route.
async function menuPick(menuPlan,catalog,env){
 let rejections=0;
 for(;;){
  const payload=await spawnMenu(menuPlan,env);
  if(payload===null)return null;
  try{
   const parsed=JSON.parse(payload);
   if(!parsed||!Array.isArray(parsed.args))throw Error('MENU_ROUTE payload must be {"args":[...]}');
   launchOptions(parsed.args,catalog);
   return parsed.args.map(String);
  }catch(error){
   console.log('MENU_ROUTE_REJECTED '+JSON.stringify({error:error.message}));
   if(++rejections>=3)throw Error(`menu route rejected three consecutive times: ${error.message}`);
  }
 }
}

if(plan.experience==='menu'&&!plan.smoke){
 // Supervisor loop: boot menu → pick route → run it → boot menu again.
 // MENU_QUIT/close without a route ends it; crash loops end with exit 1.
 const menuEnv={...process.env};
 for(const [name,dir] of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]){menuEnv[name]=resolve('.port-runtime',dir);mkdirSync(menuEnv[name],{recursive:true});}
 let fastFailures=0;
 for(;;){
  const args=await menuPick(plan,catalog,menuEnv);
  if(args===null){process.exitCode=0;break;}
  const routePlan=launchOptions(args,catalog);
  const started=Date.now();
  const code=await runRoute(routePlan);
  if(code===130||code===143){process.exitCode=code;break;}
  if(code!==0&&Date.now()-started<2000){if(++fastFailures>=3){process.exitCode=1;break;}}else fastFailures=0;
 }
}else process.exitCode=await runRoute(plan);

import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,cpSync,symlinkSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {createInterface} from 'node:readline';
import http from 'node:http';
import {randomUUID,createHash} from 'node:crypto';
import {until,sleep,parseSample,assertRole,assertPositive,stopChild} from './lib.mjs';
const here=dirname(fileURLToPath(import.meta.url)), root=resolve(here,'../../..');
const binary=process.env.GODOT_BIN, deps=process.env.GUEST_NODE_MODULES;
assert.ok(binary && deps,'Set GODOT_BIN and GUEST_NODE_MODULES (existing node_modules directory)');
const lock=JSON.parse(readFileSync(resolve(root,'port/contracts/source-lock.json')));
const version=execFileSync(binary,['--version'],{encoding:'utf8',timeout:10000}).trim();
assert.equal(version,lock.godot_version);
const runId=randomUUID(), out=resolve(root,'port/guest-session-integration/evidence',runId);
mkdirSync(out,{recursive:true});
const temp=mkdtempSync(resolve(tmpdir(),'cocs-guest-'));
const report={runId,base:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8',timeout:5000}).trim(),version,clock:'unchanged createGameServer defaults: 1/60 tickDt, 1000/60 tickMs',cases:[],cleanup:{}};
report.harnessSha256=Object.fromEntries(['run.mjs','lib.mjs','observe.gd','test.mjs'].map(f=>[f,createHash('sha256').update(readFileSync(resolve(here,f))).digest('hex')]));
let activeChild, activeGame, activeHost, activeRejectServer;
let interrupted=false;
const interrupt=()=>{interrupted=true; activeChild?.kill('SIGTERM');};
process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8'};
for(const key of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']) {env[key]=resolve(temp,key);mkdirSync(env[key]);}
function launch(args, name, deadline) {
 const child=spawn(binary,args,{env,stdio:['ignore','pipe','pipe']});activeChild=child;
 const lines=[];child.samples=[];child.failure=null;
 child.on('error',e=>child.failure=e.message);
 for(const stream of [child.stdout,child.stderr]) createInterface({input:stream}).on('line',line=>{
  if(lines.length<400) lines.push(line.slice(0,2000));
  try {const s=parseSample(line);if(s)child.samples.push(s);}catch(e){child.failure=e.message;}
 });
 const timer=setTimeout(()=>{child.failure='subprocess deadline';child.kill('SIGKILL');},deadline);
 child.once('exit',()=>{clearTimeout(timer);writeFileSync(resolve(out,`${name}.log`),lines.join('\n')+'\n');});
 return child;
}
async function wait(predicate,ms,label,child=null) {
 await until(()=>{if(interrupted)throw Error('Interrupted');if(child?.failure)throw Error(child.failure);if(child && (child.exitCode!==null || child.signalCode!==null))throw Error(`Native exited before ${label}`);return predicate();},ms,label);
}
async function listen(server) {
 let error;server.once('error',e=>error=e);server.listen(0,'127.0.0.1');
 await wait(()=>{if(error)throw error;return server.listening;},5000,'loopback listen');
 return server.address().port;
}
async function closeServer(server) {
 if(!server)return;
 server.closeAllConnections?.();let done=false,error;
 server.close(e=>{error=e;done=true;});
 await until(()=>done,5000,'rejector close');
 if(error && error.code!=='ERR_SERVER_NOT_RUNNING')throw error;
 assert.equal(server.listening,false);
}
try {
 for(const dir of ['godot','game','server']) cpSync(resolve(root,dir),resolve(temp,dir),{recursive:true,filter:p=>!p.includes('/.godot')});
 const exportLog=execFileSync(process.execPath,[resolve(root,'tools/godot-export/semantic.mjs'),resolve(temp,'godot/content/generated')],{cwd:root,encoding:'utf8',timeout:60000,env});
 writeFileSync(resolve(out,'semantic-export.log'),exportLog.slice(0,8000));
 symlinkSync(resolve(deps),resolve(temp,'node_modules'),'dir');
 const req=createRequire(resolve(temp,'entry.cjs'));
 const {WebSocket}=req('ws');
 const {createGameServer}=await import(pathToFileURL(resolve(temp,'server/game-server.mjs')));
 const {MESSAGE,PROTOCOL_VERSION}=await import(pathToFileURL(resolve(temp,'game/protocol.mjs')));
 const importer=launch(['--headless','--path',resolve(temp,'godot'),'--editor','--import'],'import',60000);
 await until(()=>importer.exitCode!==null || importer.signalCode!==null || importer.failure,65000,'import');
 assert.equal(importer.failure,null);assert.equal(importer.exitCode,0);report.cleanup.import=await stopChild(importer);activeChild=null;
 for(const name of ['positive','invalid-room','host-not-starting','connection-failure']) {
  const result={name,status:'FAIL',wire:{guest:{},snapshots:0,starts:0,positiveAcks:0},samples:[],cleanup:{}};report.cases.push(result);
  let game,host,child,rejectServer;
  try {
   game=createGameServer({historyPath:null,progressionPath:null});activeGame=game;
   const port=await listen(game.server);result.serverPort=port;
   assert.ok((await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)})).ok);
   // Passive observation on this owned server, attached before any clients.
   // No packet alteration or synthetic gameplay. Only bounded metadata is retained.
   let connections=0;
   game.wss.on('connection',socket=>{
    const guest=++connections===2; // first socket is the owned host; second is native
    socket.on('message',raw=>{const f=JSON.parse(raw.toString());if(guest)result.wire.guest[f.type]=(result.wire.guest[f.type]??0)+1;});
    const send=socket.send;
    socket.send=function(data,...args){if(guest){const f=JSON.parse(data.toString());if(f.type===MESSAGE.START)result.wire.starts++;if(f.type===MESSAGE.SNAPSHOT){result.wire.snapshots++;if(Object.values(f.acks??{}).some(v=>v>0))result.wire.positiveAcks++;}if(f.type===MESSAGE.ERROR)result.wire.error=f.message;}return send.call(this,data,...args);};
   });
   const frames=[];host=new WebSocket(`ws://127.0.0.1:${port}`);activeHost=host;
   host.on('error',()=>{});host.on('message',raw=>{const f=JSON.parse(raw.toString());if(frames.length<100)frames.push(f);});
   await wait(()=>host.readyState===WebSocket.OPEN,5000,'host connect');
   host.send(JSON.stringify({type:MESSAGE.CREATE,name:`guest-integration-${runId}-${name}`,playerName:'Harness host',v:PROTOCOL_VERSION,delta:0}));
   await wait(()=>frames.some(f=>f.type===MESSAGE.WELCOME),5000,'host welcome');
   const room=frames.find(f=>f.type===MESSAGE.WELCOME).roomId;result.roomId=room;
   host.send(JSON.stringify({type:MESSAGE.HOST,mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0}}));
   await wait(()=>frames.some(f=>f.type===MESSAGE.LOBBY && f.config),5000,'host configure');
   let endpoint=`ws://127.0.0.1:${port}`;
   if(name==='connection-failure') {
    // A held ephemeral loopback HTTP rejector avoids a free-port TOCTOU race.
    rejectServer=http.createServer((req,res)=>{res.writeHead(503);res.end();});activeRejectServer=rejectServer;
    endpoint=`ws://127.0.0.1:${await listen(rejectServer)}`;
   }
   const joinedRoom=name==='invalid-room'?`absent-${runId}`:room;
   child=launch(['--headless','--path',resolve(temp,'godot'),'--script',resolve(here,'observe.gd'),'--',`--endpoint=${endpoint}`,`--join-room=${joinedRoom}`],name,145000);
   if(name==='positive' || name==='host-not-starting') await wait(()=>child.samples.some(s=>s.phase===11),20000,'guest waiting',child);
   if(name==='positive') {
    await sleep(2200);assert.equal(child.samples.at(-1).phase,11);
    result.hostStartAfterSampleSeconds=child.samples.at(-1).seconds+0.001;
    host.send(JSON.stringify({type:MESSAGE.START}));
    await wait(()=>child.samples.some(s=>s.phase===3 && s.pose && s.snapshots>=5 && s.ack>5),20000,'active native snapshots',child);
    assertPositive(child.samples,result.wire,result.hostStartAfterSampleSeconds);
   } else {
    await wait(()=>child.samples.some(s=>s.phase===-1),name==='host-not-starting'?130000:25000,'native error state',child);
    const error=child.samples.find(s=>s.phase===-1);result.observedError=error;
    if(name==='invalid-room'){assert.match(error.error,/room not found/);assertRole(result.wire.guest);}
    if(name==='host-not-starting'){assert.match(error.error,/timed out/);assert.ok(child.samples.filter(s=>s.phase===11).at(-1).phase_seconds>=119.0);assert.ok(error.seconds>=120);assertRole(result.wire.guest);}
    if(name==='connection-failure'){assert.match(error.error,/timed out|Disconnected/);assert.equal(result.wire.guest.join,undefined);}
    assert.equal(result.wire.starts,0);assert.equal(result.wire.snapshots,0);
   }
   result.status='PASS';
  }catch(e){result.error=e.stack;}
  finally {
   result.samples=child?.samples??[];
   result.cleanup.native=await stopChild(child);activeChild=null;
   host?.terminate();activeHost=null;
   if(game){for(const s of game.wss.clients)s.terminate();await game.close();await until(()=>!game.server.listening && game.wss.clients.size===0,5000,'server cleanup');result.cleanup.serverClosed=true;}activeGame=null;
   await closeServer(rejectServer);activeRejectServer=null;result.cleanup.rejectorClosed=!rejectServer?.listening;
   writeFileSync(resolve(out,`${name}.json`),JSON.stringify(result,null,2)+'\n');
   console.log(`${name}: ${result.status}${result.error?' '+result.error.split('\n')[0]:''}`);
  }
 }
 assert.ok(report.cases.every(c=>c.status==='PASS'),'one or more live cases failed');
}catch(e){report.error=e.stack;process.exitCode=1;}
finally {
 if(activeChild)report.cleanup.emergencyChild=await stopChild(activeChild);
 activeHost?.terminate();if(activeGame){for(const s of activeGame.wss.clients)s.terminate();await activeGame.close();}
 await closeServer(activeRejectServer);
 rmSync(temp,{recursive:true,force:true});report.cleanup.privateTempRemoved=true;
 writeFileSync(resolve(out,'summary.json'),JSON.stringify(report,null,2)+'\n');
 console.log(`Evidence: ${out}`);
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
}

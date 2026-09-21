// Startup/cleanup patterns adapted from guest_session_integration/run.mjs
// at 389561510ac7c2223a22897c963f3440304ec928. Runtime sources remain unmodified.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,cpSync,symlinkSync,mkdirSync,readFileSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {randomUUID,createHash} from 'node:crypto';
import {until,sleep,parseSample,stopChild} from './guest_helpers.mjs';
import {parseTrace,parseObservations,correlate} from './validate.mjs';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../../..');
const binary=process.env.GODOT_BIN,deps=process.env.GUEST_NODE_MODULES;
assert.ok(binary&&deps,'Set GODOT_BIN and GUEST_NODE_MODULES');
const out=resolve(root,'port/native-trace-correlation/evidence',randomUUID());mkdirSync(out,{recursive:true,mode:0o700});
const temp=mkdtempSync(resolve(tmpdir(),'cocs-trace-'));
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8'};
for(const k of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
const report={base:'6071da714cf8123da14d1947bd3e099e2c040503',guestHarness:'389561510ac7c2223a22897c963f3440304ec928',branch:'subagent/native-trace-correlation',cases:[],cleanup:{},normalRate:true,completionProven:false};
report.sourceHashes=Object.fromEntries(['run.mjs','observe.gd','validate.mjs','guest_helpers.mjs','test.mjs'].map(f=>[f,createHash('sha256').update(readFileSync(resolve(here,f))).digest('hex')]));
report.commands={live:`GODOT_BIN=${binary} GUEST_NODE_MODULES=${deps} node port/tools/native_trace_correlation/run.mjs${process.argv.includes('--fault-timeout')?' --fault-timeout':''}`,offline:'node --test port/tools/native_trace_correlation/test.mjs'};
let child,game,host,interrupted=false;
const interrupt=()=>{interrupted=true;child?.kill('SIGTERM');};process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
async function wait(pred,ms,label){await until(()=>{if(interrupted)throw Error('interrupted');if(child?.failure)throw Error(child.failure);return pred();},ms,label);}
function launch(args,name,deadline){
 const c=spawn(binary,args,{env,stdio:['ignore','pipe','pipe']});child=c;c.stdoutText='';c.stderrText='';c.failure=null;
 c.on('error',e=>c.failure=e.message);
 for(const [s,k] of [[c.stdout,'stdoutText'],[c.stderr,'stderrText']])s.on('data',d=>{c[k]+=d.toString();if(c[k].length>4000000){c.failure='output cap exceeded';c.kill('SIGTERM');}});
 const timer=setTimeout(()=>{c.failure='child deadline';c.kill('SIGKILL');},deadline);
 c.closed=new Promise(r=>c.once('close',()=>{clearTimeout(timer);writeFileSync(resolve(out,`${name}.stdout.log`),c.stdoutText,{mode:0o600});writeFileSync(resolve(out,`${name}.stderr.log`),c.stderrText,{mode:0o600});r();}));return c;
}
function samples(c){return c.stdoutText.split('\n').filter(l=>l.endsWith('}')).map(parseSample).filter(Boolean);}
async function cleanup(result){
 const errors=[];result.cleanup??={};
 try{if(child){result.cleanup.native=await stopChild(child);await child.closed;}}catch(e){errors.push(e.message);}child=null;
 try{host?.terminate();if(game){for(const s of game.wss.clients)s.terminate();await Promise.race([game.close(),sleep(5000).then(()=>{throw Error('server close deadline');})]);await until(()=>!game.server.listening&&game.wss.clients.size===0,5000,'server closed');result.cleanup.serverClosed=true;result.cleanup.socketCount=game.wss.clients.size;}}catch(e){errors.push(e.message);}host=null;game=null;
 if(errors.length)throw Error(errors.join('; '));
}
try{
 report.version=execFileSync(binary,['--version'],{encoding:'utf8',timeout:10000}).trim();assert.equal(report.version,JSON.parse(readFileSync(resolve(root,'port/contracts/source-lock.json'))).godot_version);
 for(const dir of ['godot','game','server'])cpSync(resolve(root,dir),resolve(temp,dir),{recursive:true,filter:p=>!p.includes('/.godot')});
 writeFileSync(resolve(out,'export.log'),execFileSync(process.execPath,[resolve(root,'tools/godot-export/semantic.mjs'),resolve(temp,'godot/content/generated')],{cwd:root,env,encoding:'utf8',timeout:60000}));
 symlinkSync(resolve(deps),resolve(temp,'node_modules'),'dir');
 const req=createRequire(resolve(temp,'entry.cjs')), {WebSocket}=req('ws');
 const {createGameServer}=await import(pathToFileURL(resolve(temp,'server/game-server.mjs')));
 const importer=launch(['--headless','--path',resolve(temp,'godot'),'--editor','--import'],'import',60000);
 await wait(()=>importer.exitCode!==null||importer.signalCode!==null,65000,'import');assert.equal(importer.exitCode,0);report.cleanup.import=await stopChild(importer);await importer.closed;child=null;
 for(const enabled of (process.argv.includes('--fault-timeout')?[true]:[true,false])){
  const name=enabled?'enabled':'disabled',result={name,status:'FAIL',wire:{starts:[],snapshots:[],inputs:[],joins:0,actor:null},cleanup:{}};report.cases.push(result);
  try{
   game=createGameServer({historyPath:null,progressionPath:null});let listenError;game.server.once('error',e=>listenError=e);game.server.listen(0,'127.0.0.1');await wait(()=>{if(listenError)throw listenError;return game.server.listening;},5000,'listen');
   const port=game.server.address().port;result.port=port;
   let connections=0,peerId=null;
   game.wss.on('connection',socket=>{
    const guest=++connections===2;
    socket.on('message',raw=>{if(!guest)return;const f=JSON.parse(raw.toString());if(f.type==='join')result.wire.joins++;else if(f.type==='input')result.wire.inputs.push({seq:f.seq,input:f.input});else result.wire.unexpected=f.type;});
    const send=socket.send;socket.send=function(data,...args){
     if(guest){const f=JSON.parse(data.toString());if(f.type==='welcome')peerId=f.peerId;
      if(f.type==='lobby'&&peerId!==null){const p=f.players.find(p=>p.peerId===peerId);if(p?.actorId!=null)result.wire.actor=p.actorId;}
      if(f.type==='start')result.wire.starts.push({mapId:f.mapId,roundRevision:f.roundRevision});
      if(f.type==='snapshot'){const a=f.state.actors.find(a=>a.id===result.wire.actor);result.wire.snapshots.push({seq:f.seq,actor:result.wire.actor,ack:f.acks[String(result.wire.actor)]??0,health:a?.health??null,dead:a?.dead??null});}
     }return send.call(this,data,...args);
    };
   });
   const frames=[];host=new WebSocket(`ws://127.0.0.1:${port}`);host.on('error',()=>{});host.on('message',raw=>frames.push(JSON.parse(raw.toString())));
   await wait(()=>host.readyState===WebSocket.OPEN,5000,'host open');host.send(JSON.stringify({type:'create',name:`native-trace-${randomUUID()}`,playerName:'Trace host',v:3,delta:0}));
   await wait(()=>frames.some(f=>f.type==='welcome'),5000,'host welcome');const room=frames.find(f=>f.type==='welcome').roomId;result.room=room;
   host.send(JSON.stringify({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0}}));await wait(()=>frames.some(f=>f.type==='lobby'&&f.config),5000,'configuration');
   const args=['--headless','--path',resolve(temp,'godot'),'--script',resolve(here,'observe.gd'),'--',`--endpoint=ws://127.0.0.1:${port}`,`--join-room=${room}`,...(enabled?['--native-trace']:[])];result.nativeCommand=[binary,...args];
   const c=launch(args,name,25000);
   await wait(()=>samples(c).some(s=>s.phase===11),10000,'guest joined before start');await sleep(600);
   result.waiting=samples(c).filter(s=>s.phase===11);assert.ok(result.waiting.length>=2);assert.ok(result.waiting.every(s=>!s.pose&&s.starts===0&&s.snapshots===0));assert.equal(result.wire.starts.length,0);
   if(process.argv.includes('--fault-timeout'))await wait(()=>false,100,'intentional harness timeout after live join');
   host.send(JSON.stringify({type:'start'}));
   await wait(()=>c.exitCode!==null||c.signalCode!==null,16000,'bounded native observation');await c.closed;assert.equal(c.exitCode,0);
   // Guest has exited; drain only the owned server receive queue, not a moving capture boundary.
   await sleep(200);result.samples=samples(c);assert.ok(result.samples.some(s=>s.phase===3&&s.pose&&s.snapshots>=5&&s.ack>0));
   const records=parseTrace(c.stdoutText,`${name}.stdout.log`);result.traceCount=records.length;
   result.observations=parseObservations(c.stdoutText,records,`${name}.stdout.log`);
   assert.equal(parseTrace(c.stderrText,`${name}.stderr.log`).length,0);assert.equal(result.wire.joins,1);assert.equal(result.wire.unexpected,undefined);
   if(enabled){result.correlation=correlate(records,result.wire,result.observations);assert.equal(result.correlation.status,'PASS');assert.ok(result.correlation.snapshotMatches.length>=5);assert.ok(result.correlation.inputMatches.length>=5);}
   else{assert.equal(records.length,0);assert.ok(result.observations.filter(o=>o.event==='snapshot').length>=5);assert.equal(result.wire.starts.length,1);}
   result.status='PASS';
  }catch(e){result.error=e.stack;process.exitCode=1;}finally{await cleanup(result);writeFileSync(resolve(out,`${name}.json`),JSON.stringify(result,null,2)+'\n',{mode:0o600});console.log(`${name}: ${result.status}${result.error?' '+result.error:''}`);}
 }
 assert.ok(report.cases.every(c=>c.status==='PASS'));
}catch(e){report.error=e.stack;process.exitCode=1;}
finally{
 try{await cleanup(report);}catch(e){report.cleanupError=e.stack;process.exitCode=1;}
 rmSync(temp,{recursive:true,force:true});report.cleanup.privateTempRemoved=!existsSync(temp);
 report.status=process.exitCode?'FAIL':'PASS';writeFileSync(resolve(out,'summary.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});console.log(`Evidence: ${out}`);
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
}

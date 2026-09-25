/** Single, bounded ordinary attempt. Never automatically asserts natural acceptance. */
import {existsSync, readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync, createWriteStream} from 'node:fs';
import {spawn,execFileSync} from 'node:child_process';
import {createHash,randomUUID} from 'node:crypto';
import {resolve,join} from 'node:path';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';
import {audit} from './audit.mjs';

const root=resolve(fileURLToPath(new URL('../../../',import.meta.url)));
const marker='/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted';
const args=Object.fromEntries(process.argv.slice(2).filter(s=>s.startsWith('--') && s.includes('=')).map(s=>s.slice(2).split(/=(.*)/s).slice(0,2)));
const engineDriver=process.argv.includes('--engine-driver'), idle=process.argv.includes('--driver-idle'),render=process.argv.includes('--render');
if (!existsSync(marker) || !process.env.GODOT_BIN) throw Error(`Refusing engine/server work without ${marker} and GODOT_BIN`);
if (!['asterion-relay','monsoon-foundry'].includes(args.map) || !['cocs','cocs-coop'].includes(args.mode)) throw Error('Specify --map and --mode');
if(render&&(!engineDriver||!process.env.DISPLAY))throw Error('--render requires --engine-driver on an owned display');
const lock=JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
if (execFileSync(process.env.GODOT_BIN,['--version'],{encoding:'utf8',timeout:10000}).trim()!==lock.godot_version) throw Error('Wrong Godot version');
const {createGameServer}=await import('../../../server/game-server.mjs');
const dir=join(root,'port/native-lattice/evidence/flagship',`ordinary-${Date.now()}-${randomUUID()}`);
mkdirSync(dir,{recursive:true});
const sha=p=>createHash('sha256').update(readFileSync(join(root,p))).digest('hex');
const manifest={schema_version:1,evidence_class:'ordinary-wire',source_commit:lock.source_commit,
 port_commit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),
  input_sha256:Object.fromEntries(['godot/lattice/world_demo.gd','port/tools/native_lattice_flagship/run.mjs','port/tools/native_lattice_flagship/audit.mjs',...(engineDriver?['godot/tests/lattice/driver_flagship.gd']:[])].map(p=>[p,sha(p)])),
 map:args.map,mode:args.mode,requested:{bots:Number(args.bots??2),time_limit:Number(args.limit??900),rung:args.rung??null},
  input_method:engineDriver?'engine-scripted ordinary movement/order; no OS or human input':'native engine; operator must observe UI',rendered:render,attempt_id:dir.split('/').at(-1), note:'Never infer native UI/participant intent from wire alone'};
writeFileSync(join(dir,'manifest.json'),JSON.stringify(manifest,null,2));
const maxRows=20000,maxBytes=128*1024*1024;let rows=0,bytes=0,dropped=0,latestSourceRevision=null,lastSnapshotAt=-1000,lastSnapshotRevision=null,lastInputAt=-1000,lastNativeInputAt=-1000,lastNativeSnapshotAt=-1000;
const wire=createWriteStream(join(dir,'wire.jsonl'));
const native=createWriteStream(join(dir,'native.jsonl'));
const log=createWriteStream(join(dir,'native.log'));
const runtime=mkdtempSync('/home/mojo/.tmp-on-disk/lattice-attempt-');
const env={...process.env};for(const k of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {env[k]=join(runtime,k);mkdirSync(env[k]);}
let game,child,serverClosed=false,childrenWaited=false,reason='deadline',error=null;const start=Date.now(),driverReports=[];
const onStop=()=>{reason='interrupted';child?.kill('SIGTERM');};process.once('SIGINT',onStop);process.once('SIGTERM',onStop);
try {
 game=createGameServer({historyPath:null,progressionPath:null});
 await new Promise((ok,no)=>{game.server.once('error',no);game.server.listen(0,'127.0.0.1',ok)});
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 manifest.endpoint=endpoint;writeFileSync(join(dir,'manifest.json'),JSON.stringify(manifest,null,2));
 game.wss.on('connection',socket=>{
   socket.on('message',raw=>{try {const f=JSON.parse(raw.toString());if(['input','host','start','join','create','order','economy'].includes(f.type)) record('client',f);}catch {}});
  const send=socket.send;
  socket.send=function(data,...rest){try{record('recipient',JSON.parse(data.toString()));}catch{}return send.call(this,data,...rest)};
 });
  function record(direction,frame) {
    if(direction==='recipient' && frame.type==='start' && Number.isInteger(frame.roundRevision))latestSourceRevision=frame.roundRevision;
    const elapsed=Date.now()-start;
    if(direction==='client'&&frame.type==='input'){
     if(elapsed-lastInputAt<1000)return;
     lastInputAt=elapsed;
    }
    if(direction==='recipient'&&frame.type==='snapshot'){
     const rev=frame.state?.cocs?.roundRevision;
     if(rev===lastSnapshotRevision&&elapsed-lastSnapshotAt<3000)return;
     lastSnapshotRevision=rev;lastSnapshotAt=elapsed;
    }
   if(rows>=maxRows){dropped++;return}
   const line=JSON.stringify({kind:frame.type,direction,elapsed_ms:elapsed,frame})+'\n';
   if(bytes+Buffer.byteLength(line)>maxBytes){dropped++;return}
  rows++;bytes+=Buffer.byteLength(line);wire.write(line);
 }
  const nativeArgs=engineDriver?['--audio-driver','Dummy',...(render?['--rendering-method','gl_compatibility']:['--headless']),'--path','godot','--script','res://tests/lattice/driver_flagship.gd','--',`--endpoint=${endpoint}`,`--map=${args.map}`,`--mode=${args.mode}`,`--time-limit=${args.limit??900}`,`--driver-limit=${args.limit??900}`,'--native-trace',...(render?[`--capture-dir=${dir}`]:[]),...(idle?['--driver-idle']:[])]:['--audio-driver','Dummy','--path','godot','res://lattice/world_demo.tscn','--',`--endpoint=${endpoint}`,`--map=${args.map}`,`--mode=${args.mode}`,`--time-limit=${args.limit??900}`,'--native-trace'];
 if(!args.rung)nativeArgs.push(`--bots=${args.bots??2}`);
 if(args.rung)nativeArgs.push(`--rung=${args.rung}`);
 child=spawn(process.env.GODOT_BIN,nativeArgs,{cwd:root,env,stdio:['ignore','pipe','pipe']});
  for(const stream of [child.stdout,child.stderr]) createInterface({input:stream}).on('line',line=>{
    if(!line.startsWith('PORT_NATIVE_TRACE '))log.write(line.slice(0,4000)+'\n');
    if(line.startsWith('LATTICE_NATURAL_DRIVER '))try {driverReports.push(JSON.parse(line.slice('LATTICE_NATURAL_DRIVER '.length)))}catch{}
   // Keep only explicitly versioned native trace records; logs are not source outcomes.
   if(line.startsWith('PORT_NATIVE_TRACE '))try {const payload=JSON.parse(line.slice(18));const elapsed=Date.now()-start;
    if(payload.event==='input_queue'){if(elapsed-lastNativeInputAt<1000)return;lastNativeInputAt=elapsed}
    if(payload.event==='snapshot'){if(elapsed-lastNativeSnapshotAt<3000)return;lastNativeSnapshotAt=elapsed}
    payload.method='engine';payload.source_revision=latestSourceRevision;payload.revision_correlated_by='witness latest recipient start (derived)';native.write(JSON.stringify(payload)+'\n')}catch{}
 });
  let deadline;
  await Promise.race([new Promise((ok,no)=>{child.once('error',no);child.once('exit',(code,signal)=>{reason=signal??`exit ${code}`;ok()})}),new Promise(ok=>{deadline=setTimeout(()=>{child.kill('SIGTERM');ok()},20*60*1000)})]);
  clearTimeout(deadline);
 if(child.exitCode===null && child.signalCode===null)await new Promise(ok=>{child.once('exit',ok);setTimeout(()=>{child.kill('SIGKILL')},3000)});
 childrenWaited=true;
}catch(e){error=String(e.stack??e)}finally{
 if(child && child.exitCode===null && child.signalCode===null) {child.kill('SIGKILL');await new Promise(ok=>child.once('exit',ok))}childrenWaited=true;
 if(game){for(const peer of game.wss.clients)peer.terminate();await game.close();serverClosed=!game.server.listening}
 await Promise.all([new Promise(ok=>wire.end(ok)),new Promise(ok=>native.end(ok)),new Promise(ok=>log.end(ok))]);
 rmSync(runtime,{recursive:true,force:true});
  const cleanup={children_waited:childrenWaited,server_closed:serverClosed,temp_removed:!existsSync(runtime),stop_reason:reason,error};
  writeFileSync(join(dir,'capture.json'),JSON.stringify({schema_version:1,wire_rows:rows,wire_bytes:bytes,max_rows:maxRows,max_bytes:maxBytes,capacity_drops:dropped,input_sampling_ms:1000,snapshot_sampling_ms:3000,native_input_sampling_ms:1000,native_snapshot_sampling_ms:3000},null,2));
 writeFileSync(join(dir,'cleanup.json'),JSON.stringify(cleanup,null,2));
 const readLines=file=>readFileSync(join(dir,file),'utf8').split('\n').filter(Boolean).map(JSON.parse);
 // A live witness is intentionally incomplete without human-reviewed UI,
 // source result and restart. Never manufacture a PASS from the process exit.
  const summary=audit({manifest,wire:readLines('wire.jsonl'),native:readLines('native.jsonl'),cleanup});
   summary.engine_driver=engineDriver?driverReports:[];
   summary.capture_complete=dropped===0;
   if(dropped){summary.claim='BLOCKED';summary.failures.push(`capture_capacity: ${dropped} records dropped`)}
 writeFileSync(join(dir,'summary.json'),JSON.stringify(summary,null,2));
 console.log(`${dir}: ${summary.claim} (${reason}; ${summary.failures.join('; ')})`);
 process.removeListener('SIGINT',onStop);process.removeListener('SIGTERM',onStop);
 if(error)process.exitCode=1;
}

#!/usr/bin/env node
/** Marker-gated host/guest native witness. Start is deliberately human-clicked. */
import {existsSync, mkdirSync, writeFileSync, readFileSync, createWriteStream, rmSync} from 'node:fs';
import {spawn, execFileSync} from 'node:child_process';
import {createHash, randomUUID} from 'node:crypto';
import {resolve, join} from 'node:path';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';

export function evaluatePair(sockets) {
 const host=sockets.host, guest=sockets.guest;
  const lobby=guest.filter(x=>x.direction==='recipient'&&x.frame.type==='lobby').at(-1)?.frame;
  const welcome=host.find(x=>x.direction==='recipient'&&x.frame.type==='welcome')?.frame;
  const hostConfig=host.filter(x=>x.direction==='recipient'&&x.frame.type==='lobby'&&x.frame.config).at(-1)?.frame?.config;
  const peers=(lobby?.players??[]).filter(x=>x.connected===true&&x.spectate!==true).map(x=>x.peerId).filter(Number.isInteger);
  const assignments=[host,guest].map(rows=>rows.filter(x=>x.direction==='recipient'&&x.frame.type==='lobby').at(-1)?.frame?.players?.find(p=>p.peerId===rows.find(x=>x.direction==='recipient'&&x.frame.type==='welcome')?.frame?.peerId)?.actorId);
  return {room_match:!!welcome?.roomId&&lobby?.roomId===welcome.roomId,
   host_config_echoed:!!hostConfig&&['cocs','cocs-coop'].includes(hostConfig.mode),
  guest_published_presence:!!lobby&&lobby.roomId===welcome?.roomId&&lobby.players?.some(p=>p.peerId!==welcome?.peerId),
   two_distinct_peers:new Set(peers).size>=2,
   two_distinct_actors:assignments.every(Number.isInteger)&&new Set(assignments).size===2,
   host_start_observed:host.some(x=>x.direction==='recipient'&&x.frame.type==='start'),
   guest_start_observed:guest.some(x=>x.direction==='recipient'&&x.frame.type==='start'),
  guest_start_messages:guest.filter(x=>x.direction==='client'&&['start','host'].includes(x.frame.type)).length};
}

const root=resolve(fileURLToPath(new URL('../../../',import.meta.url))), marker='/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted';
const args=Object.fromEntries(process.argv.slice(2).filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>x.slice(2).split(/=(.*)/s).slice(0,2)));
if(import.meta.url===`file://${process.argv[1]}`) await main();
async function main(){
 if(!existsSync(marker)||!process.env.GODOT_BIN)throw Error(`Refusing Godot/server work without ${marker} and GODOT_BIN`);
 if(!['asterion-relay','monsoon-foundry'].includes(args.map)||!['cocs','cocs-coop'].includes(args.mode))throw Error('Specify --map and --mode');
 const lock=JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
 if(execFileSync(process.env.GODOT_BIN,['--version'],{encoding:'utf8',timeout:10000}).trim()!==lock.godot_version)throw Error('Wrong Godot version');
 const {createGameServer}=await import('../../../server/game-server.mjs');
 const dir=join(root,'port/native-lattice/evidence/flagship',`two-client-${Date.now()}-${randomUUID()}`);mkdirSync(dir,{recursive:true});
  const manifest={schema_version:1,evidence_class:'ordinary-wire-two-native',source_commit:lock.source_commit,port_commit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),map:args.map,mode:args.mode,input_method:'human clicks host Start / restart in native window; Enter in terminal only records operator acknowledgement and never sends protocol data',start_gate:'recipient-observed guest lobby presence and two distinct peers before human click; then recipient-observed source start and distinct assigned actors for both clients',guest_start_security:'UNVERIFIED: recorded guest outgoing frames are inspectable but absence alone does not prove authorization/security',hashes:Object.fromEntries(['godot/lattice/world_demo.gd','godot/lattice/session_options.gd','port/tools/native_lattice_flagship/two_client.mjs'].map(p=>[p,createHash('sha256').update(readFileSync(join(root,p))).digest('hex')]))};
  const wire=createWriteStream(join(dir,'wire.jsonl')), traces=createWriteStream(join(dir,'native.jsonl')), logs=createWriteStream(join(dir,'native.log'));
  let rows=0,bytes=0;const sockets={host:[],guest:[]},children=[];let game,runtime,serverClosed=false,childrenWaited=false,reason='blocked-awaiting-human-click',error=null;
  const controller=new AbortController();const interrupt=()=>controller.abort();process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
 const record=(who,direction,frame)=>{const row={client:who,direction,elapsed_ms:Date.now()-started,frame};const line=JSON.stringify(row)+'\n';if(rows<12000&&bytes+Buffer.byteLength(line)<=16*1024*1024){rows++;bytes+=Buffer.byteLength(line);sockets[who].push(row);wire.write(line)}};
 const started=Date.now();
 try{game=createGameServer({historyPath:null,progressionPath:null});await new Promise((ok,no)=>{game.server.once('error',no);game.server.listen(0,'127.0.0.1',ok)});const endpoint=`ws://127.0.0.1:${game.server.address().port}`;manifest.endpoint=endpoint;writeFileSync(join(dir,'manifest.json'),JSON.stringify(manifest,null,2));
  let next=0;game.wss.on('connection',ws=>{const who=next++===0?'host':'guest';ws.on('message',raw=>{try{record(who,'client',JSON.parse(raw.toString()))}catch{}});const send=ws.send;ws.send=function(data,...rest){try{record(who,'recipient',JSON.parse(data.toString()))}catch{}return send.call(this,data,...rest)}});
  runtime=join(dir,'xdg');mkdirSync(runtime);const env={...process.env,XDG_DATA_HOME:join(runtime,'data'),XDG_CONFIG_HOME:join(runtime,'config'),XDG_CACHE_HOME:join(runtime,'cache')};for(const p of [env.XDG_DATA_HOME,env.XDG_CONFIG_HOME,env.XDG_CACHE_HOME])mkdirSync(p);
   const launch=(who,extra=[])=>{const argv=['--audio-driver','Dummy','--path','godot','res://lattice/world_demo.tscn','--',`--endpoint=${endpoint}`,`--map=${args.map}`,`--mode=${args.mode}`,'--native-trace',...extra];const c=spawn(process.env.GODOT_BIN,argv,{cwd:root,env,stdio:['ignore','pipe','pipe'],detached:true});children.push(c);for(const stream of [c.stdout,c.stderr])createInterface({input:stream}).on('line',l=>{logs.write(`${who}: ${l.slice(0,4000)}\n`);if(l.startsWith('PORT_NATIVE_TRACE '))try{traces.write(JSON.stringify({client:who,...JSON.parse(l.slice(18))})+'\n')}catch{}});return c};
   const host=launch('host',['--time-limit=900']);await until(()=>sockets.host.some(x=>x.direction==='recipient'&&x.frame.type==='welcome')&&sockets.host.some(x=>x.direction==='recipient'&&x.frame.type==='lobby'),60000,controller.signal);const welcome=sockets.host.find(x=>x.frame.type==='welcome').frame;
   const guest=launch('guest',[`--join-room=${welcome.roomId}`]);await until(()=>{const e=evaluatePair(sockets);return e.room_match&&e.host_config_echoed&&e.guest_published_presence&&e.two_distinct_peers},60000,controller.signal);
   const gate=evaluatePair(sockets);writeFileSync(join(dir,'start-gate.json'),JSON.stringify({...gate,status:'READY_FOR_HUMAN_CLICK',instruction:'Click Start / restart (host) in host Godot window now. Do not type protocol commands.'},null,2));console.log(`Both clients joined room ${welcome.roomId}. Click Start / restart (host) in host window; press Enter here only after the click.`);
   await new Promise((ok,no)=>{const rl=createInterface({input:process.stdin,output:process.stdout});let settled=false;const done=error=>{if(settled)return;settled=true;clearTimeout(deadline);controller.signal.removeEventListener('abort',abort);rl.close();error?no(error):ok()};const abort=()=>done(Error('interrupted'));const deadline=setTimeout(()=>done(Error('human start deadline')),10*60*1000);controller.signal.addEventListener('abort',abort,{once:true});rl.question('After clicking host Start, press Enter: ',()=>done())});
   await until(()=>{const e=evaluatePair(sockets);return e.host_start_observed&&e.guest_start_observed&&e.two_distinct_actors},30000,controller.signal);reason='source-start-observed-both';await new Promise(r=>setTimeout(r,5000));
 }catch(e){error=String(e.stack??e);reason=reason==='blocked-awaiting-human-click'?'BLOCKED':reason}finally{
  for(const c of children)if(c.exitCode===null&&c.signalCode===null)try{process.kill(-c.pid,'SIGTERM')}catch{};
  await Promise.all(children.map(c=>c.exitCode!==null||c.signalCode!==null?Promise.resolve():new Promise(ok=>{c.once('exit',ok);setTimeout(()=>{try{process.kill(-c.pid,'SIGKILL')}catch{}},3000)})));childrenWaited=true;
   if(game){for(const ws of game.wss.clients)ws.terminate();await game.close();serverClosed=!game.server.listening}await Promise.all([new Promise(r=>wire.end(r)),new Promise(r=>traces.end(r)),new Promise(r=>logs.end(r))]);
   if(runtime)rmSync(runtime,{recursive:true,force:true});process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
   const evaluation=evaluatePair(sockets);writeFileSync(join(dir,'results.json'),JSON.stringify({status:reason==='source-start-observed-both'?'OBSERVED':'BLOCKED',reason,evaluation,guest_start_authorization:'UNVERIFIED',guest_outgoing:sockets.guest.filter(x=>x.direction==='client'),cleanup:{children_waited:childrenWaited,server_closed:serverClosed,temp_removed:!runtime||!existsSync(runtime)},error},null,2));
   const hashes={};for(const f of ['manifest.json','wire.jsonl','native.jsonl','native.log','results.json'])hashes[f]=createHash('sha256').update(readFileSync(join(dir,f))).digest('hex');writeFileSync(join(dir,'evidence-manifest.json'),JSON.stringify({schema_version:1,pin:lock.source_commit,evidence_class:'ordinary-wire-two-native',labels:{wire:'per-socket recipient and outgoing frames; bounded 12000 rows / 16 MiB',native:'per-client PORT_NATIVE_TRACE lines; logs are not outcomes',start:'human click only; source start must be observed',security:'guest cannot-start assertion unverified'},hashes,elapsed_ms:Date.now()-started,cleanup:{children_waited:childrenWaited,server_closed:serverClosed,temp_removed:!runtime||!existsSync(runtime)}},null,2));if(error)console.error(error);console.log(`${dir}: ${reason}`);
 }
}
function until(predicate,ms,signal){return new Promise((ok,no)=>{const end=Date.now()+ms;const tick=()=>signal?.aborted?no(Error('interrupted')):predicate()?ok():Date.now()>end?no(Error('bounded wait expired')):setTimeout(tick,100);tick()})}

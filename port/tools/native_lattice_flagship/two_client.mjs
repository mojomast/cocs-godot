#!/usr/bin/env node
/** Marker-gated host/guest native witness. Ordinary Start is deliberately human-clicked.
 * The opt-in `--engine-driver --full-round` path is a bounded scripted round; see l5/ROUND_WITNESS.md. */
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

// Full-round terminal classification. This only reads a recipient-published
// `results` frame; it never constructs one. Scripted engine input can never be
// upgraded to a human identity or a five-wave claim here.
export function classifyTerminal(frame) {
 const state=frame?.state;
 if(!state||state.over!==true)return null;
 const winnerRaw=state.winner,winner=winnerRaw===0||winnerRaw===1?winnerRaw:null;
 const reason=typeof state.overReason==='string'&&state.overReason.length>0?state.overReason:null;
 const board=state.cocs&&typeof state.cocs==='object'?state.cocs:{};
 const outcome=board.outcome&&typeof board.outcome==='object'?board.outcome:null;
 const mode=outcome?.mode==='operations'?'operations':outcome?.mode==='pvp'?'pvp':null;
 const waves=outcome?.waves&&typeof outcome.waves==='object'?outcome.waves:null;
 const hq=outcome?.hq&&typeof outcome.hq==='object'?outcome.hq:null;
 const operations=mode==='operations';
 const failureReasons=['operation-failed','hq-destroyed','hq-lost','team-wipe'];
 const complete=operations&&winner===0&&reason==='operation-complete';
 const failed=operations&&(winner===1||failureReasons.includes(reason));
 return {over:true,winner,draw:winner===null,reason,mode,
  waves_cleared:Number.isInteger(waves?.cleared)?waves.cleared:null,
  waves_total:Number.isInteger(waves?.total)?waves.total:null,
  hq_health:Number.isFinite(hq?.health)?hq.health:null,hq_max:Number.isFinite(hq?.max)?hq.max:null,
  terminal_class:winner===0?'source-winner-team-0':winner===1?'source-winner-team-1':'draw',
  operations_outcome:operations?(complete?'operations-complete':failed?'operations-failure':'operations-unknown'):'not-operations',
  claims:{source_winner:winner===0||winner===1,five_wave_win:false,human_identity:false,scripted_input:true}};
}

// Native probe reports must independently agree with the recipient socket: same
// peer/actor, scripted engine input (never human), a recipient result present,
// and the same source winner. This is what makes the two clients independent
// witnesses rather than one wire read twice.
export function correlateNativeRound(per, reports) {
 const failures=[];
 for(const who of ['host','guest']){
  const rows=Array.isArray(reports?.[who])?reports[who]:[];
  const terminal=rows.find(r=>r?.status==='terminal');
  const restarted=rows.find(r=>r?.status==='restarted');
  const actor=per[who]?.actorId,peer=per[who]?.peerId;
  if(!terminal)failures.push(`${who}: no scripted native terminal report`);
  else {
   if(terminal.engine_input!==true||terminal.human_input!==false)failures.push(`${who}: native terminal report is not scripted engine input`);
   if(terminal.actor!==actor||terminal.peer!==peer)failures.push(`${who}: native terminal report identity does not match the recipient socket`);
   if(terminal.result_present!==true)failures.push(`${who}: native terminal report carries no recipient result`);
   else if(terminal.result_winner!==(per[who]?.terminal?.winner??null))failures.push(`${who}: native terminal winner does not match the recipient result`);
  }
  if(!restarted)failures.push(`${who}: no scripted native restart report`);
  else if(restarted.actor!==actor||restarted.peer!==peer)failures.push(`${who}: native restart report identity does not match the recipient socket`);
 }
 return failures;
}

// Bounded full-round evidence gate over the retained recipient rows of two
// independent native clients. Requires, per socket, a terminal result on the
// running round revision plus a clean restart (a later `start` revision that a
// post-restart snapshot confirms). `snapshotRevisions` is the per-socket set of
// revision numbers seen on recipient snapshots; it is passed separately because
// the recorder intentionally does not retain every snapshot body. `reports`,
// when supplied, additionally requires each independent native client to confirm
// the same identity and result. A dropped record makes the wire incomplete, so
// the run can only fail, never pass.
export function evaluateFullRound(sockets, {dropped=0,snapshotRevisions={},reports=null}={}) {
 const failures=[],per={};
 for(const who of ['host','guest']){
  const rows=Array.isArray(sockets?.[who])?sockets[who].filter(r=>r?.direction==='recipient'):[];
  const welcome=rows.find(r=>r.frame?.type==='welcome')?.frame;
  const results=rows.filter(r=>r.frame?.type==='results'&&r.frame?.state?.over===true).at(-1);
  const starts=rows.filter(r=>r.frame?.type==='start'&&Number.isInteger(r.frame?.roundRevision));
  const terminal=results?classifyTerminal(results.frame):null;
  const terminalRevision=results?(starts.filter(r=>r.elapsed_ms<=results.elapsed_ms).map(r=>r.frame.roundRevision).at(-1)??null):null;
  const peerId=Number.isInteger(welcome?.peerId)?welcome.peerId:null;
  const assignments=peerId===null?null:rows.filter(r=>r.frame?.type==='lobby'&&(!results||r.elapsed_ms<=results.elapsed_ms))
   .flatMap(r=>Array.isArray(r.frame?.players)?r.frame.players:[]).find(p=>p?.peerId===peerId);
  const actorId=Number.isInteger(assignments?.actorId)?assignments.actorId:null;
  const revs=Array.isArray(snapshotRevisions?.[who])?snapshotRevisions[who]:[];
  const identity=peerId!==null&&actorId!==null&&terminalRevision!==null&&revs.includes(terminalRevision);
  const restartStarts=terminalRevision===null?[]:starts.filter(r=>r.frame.roundRevision>terminalRevision);
  const restartRevision=restartStarts.map(r=>r.frame.roundRevision).sort((a,b)=>a-b).at(-1)??null;
  const restarted=restartRevision!==null&&revs.some(r=>Number.isInteger(r)&&r>terminalRevision);
  per[who]={peerId,actorId,terminalRevision,restartRevision,terminal_observed:!!terminal,terminal,identity,restart_observed:restarted};
  if(!terminal)failures.push(`${who}: no recipient terminal results frame`);
  if(!identity)failures.push(`${who}: recipient peer/actor/round identity not established`);
  if(terminal&&!restarted)failures.push(`${who}: no clean restart (later start revision and post-restart snapshot required)`);
 }
 const nativeFailures=reports?correlateNativeRound(per,reports):[];
 for(const f of nativeFailures)failures.push(f);
 const nativeCorrelated=nativeFailures.length===0;
 const distinctActors=per.host.actorId!==null&&per.guest.actorId!==null&&per.host.actorId!==per.guest.actorId;
 if(!distinctActors)failures.push('two distinct recipient-assigned actors not observed');
 const captureComplete=dropped===0;
 if(!captureComplete)failures.push(`capture capacity: ${dropped} records dropped; full-round wire is incomplete`);
 const bothTerminal=per.host.terminal_observed&&per.guest.terminal_observed;
 const bothRestarted=per.host.restart_observed&&per.guest.restart_observed;
 const agreement=bothTerminal&&per.host.terminal.terminal_class===per.guest.terminal.terminal_class;
 if(bothTerminal&&!agreement)failures.push('recipient terminal results disagree on the source winner');
 const witnessStatus=!captureComplete?'CAPTURE_CAPPED':(bothTerminal&&bothRestarted&&distinctActors&&agreement&&nativeCorrelated?'ROUND_OBSERVED':'INCOMPLETE');
 const terminal=per.host.terminal??per.guest.terminal??null;
 return {schema_version:1,witness_status:witnessStatus,both_terminal:bothTerminal,both_restarted:bothRestarted,
  distinct_actors:distinctActors,agreement,native_correlated:nativeCorrelated,native_required:!!reports,
  terminal_class:terminal?.terminal_class??null,operations_outcome:terminal?.operations_outcome??null,
  winner:terminal?.winner??null,reason:terminal?.reason??null,waves_cleared:terminal?.waves_cleared??null,
  waves_total:terminal?.waves_total??null,hq_health:terminal?.hq_health??null,hq_max:terminal?.hq_max??null,
  claim:witnessStatus==='ROUND_OBSERVED'?'ENGINE_FULL_ROUND_OBSERVED':witnessStatus,
  // These claims can never be earned by scripted engine input.
  claims:{source_winner:terminal?.claims?.source_winner===true&&witnessStatus==='ROUND_OBSERVED',five_wave_win:false,human_identity:false,scripted_input:true},
  sockets:per,failures};
}

const root=resolve(fileURLToPath(new URL('../../../',import.meta.url))), marker='/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted';
const args=Object.fromEntries(process.argv.slice(2).filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>x.slice(2).split(/=(.*)/s).slice(0,2)));
if(import.meta.url===`file://${process.argv[1]}`) await main();
async function main(){
 if(!existsSync(marker)||!process.env.GODOT_BIN)throw Error(`Refusing Godot/server work without ${marker} and GODOT_BIN`);
 if(!['asterion-relay','monsoon-foundry'].includes(args.map)||!['cocs','cocs-coop'].includes(args.mode))throw Error('Specify --map and --mode');
  const engineDriver=process.argv.includes('--engine-driver');
  // Opt-in bounded full-round witness. Scripted engine input is the only safe
  // way to reach a terminal result and a scripted restart without a human at
  // the window, so this path is deliberately engine-driven and never claims
  // human identity or a five-wave win.
  const fullRound=process.argv.includes('--full-round');
  if(fullRound&&!engineDriver)throw Error('--full-round requires --engine-driver (bounded scripted round with scripted restart)');
  const roundLimit=Math.max(60,Math.min(900,Number(args.limit)||900));
  const probeTimeoutMs=fullRound?Math.min(20*60*1000,roundLimit*1000+120000):30000;
  const terminalWaitMs=fullRound?Math.min(20*60*1000,roundLimit*1000+120000):0;
  const restartWaitMs=fullRound?120000:0;
  const maxRows=fullRound?Math.max(50000,Number(args.max_rows)||500000):12000;
  const maxBytes=fullRound?Math.max(16*1024*1024,Number(args.max_bytes)||512*1024*1024):16*1024*1024;
  const evidenceClass=fullRound?'engine-driven-two-native-full-round':engineDriver?'engine-driven-two-native-smoke':'ordinary-wire-two-native';
 const lock=JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
 if(execFileSync(process.env.GODOT_BIN,['--version'],{encoding:'utf8',timeout:10000}).trim()!==lock.godot_version)throw Error('Wrong Godot version');
 const {createGameServer}=await import('../../../server/game-server.mjs');
 const dir=join(root,'port/native-lattice/evidence/flagship',`two-client-${Date.now()}-${randomUUID()}`);mkdirSync(dir,{recursive:true});
  const manifest={schema_version:1,evidence_class:evidenceClass,source_commit:lock.source_commit,port_commit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),map:args.map,mode:args.mode,full_round:fullRound,round_limit_seconds:fullRound?roundLimit:null,input_method:fullRound?'engine-scripted ordinary inputs across a full source round plus a scripted host restart request; no OS/human input':engineDriver?'engine-scripted Start and ordinary source inputs; no OS/human input':'human clicks host Start / restart in native window; Enter in terminal only records operator acknowledgement and never sends protocol data',start_gate:'recipient-observed guest lobby presence and two distinct peers before start; then recipient-observed source start and distinct assigned actors for both clients',terminal_gate:fullRound?'BOTH recipient sockets must publish a terminal results state on the running round and then a clean restart (later start revision confirmed by a post-restart snapshot)':'not-applicable',guest_start_security:'UNVERIFIED: recorded guest outgoing frames are inspectable but absence alone does not prove authorization/security',hashes:Object.fromEntries(['godot/lattice/world_demo.gd','godot/lattice/session_options.gd','port/tools/native_lattice_flagship/two_client.mjs',...(engineDriver?['godot/tests/lattice/probe_pair_flagship.gd']:[])].map(p=>[p,createHash('sha256').update(readFileSync(join(root,p))).digest('hex')]))};
  const wire=createWriteStream(join(dir,'wire.jsonl')), traces=createWriteStream(join(dir,'native.jsonl')), logs=createWriteStream(join(dir,'native.log'));
  let rows=0,bytes=0,dropped=0;const sockets={host:[],guest:[]},reports={host:[],guest:[]},children=[],snapshotRevisions={host:[],guest:[]};let game,runtime,serverClosed=false,childrenWaited=false,reason='blocked-awaiting-human-click',error=null,observation=null,roundEvidence=null;
  const controller=new AbortController();const interrupt=()=>controller.abort();process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
 // The wire file stays complete up to a hard cap; anything past it is counted,
 // never silently truncated. The full-round path additionally fails on any drop
 // so a cap can only produce CAPTURE_CAPPED, never an observed round.
 const essential=new Set(['welcome','lobby','start','results','host','create','join','leave','order','economy','rematch','warmup','ready','map-vote','cocs-reject','error']);
 const record=(who,direction,frame)=>{const row={client:who,direction,elapsed_ms:Date.now()-started,frame};
  if(direction==='recipient'&&frame.type==='snapshot'){const rev=frame.state?.cocs?.roundRevision;if(Number.isInteger(rev)&&!snapshotRevisions[who].includes(rev))snapshotRevisions[who].push(rev)}
  const line=JSON.stringify(row)+'\n',size=Buffer.byteLength(line);if(rows>=maxRows||bytes+size>maxBytes){dropped++;return}
  rows++;bytes+=size;wire.write(line);if(!fullRound||essential.has(frame.type))sockets[who].push(row)};
 const started=Date.now();
 try{game=createGameServer({historyPath:null,progressionPath:null});await new Promise((ok,no)=>{game.server.once('error',no);game.server.listen(0,'127.0.0.1',ok)});const endpoint=`ws://127.0.0.1:${game.server.address().port}`;manifest.endpoint=endpoint;writeFileSync(join(dir,'manifest.json'),JSON.stringify(manifest,null,2));
  let next=0;game.wss.on('connection',ws=>{const who=next++===0?'host':'guest';ws.on('message',raw=>{try{record(who,'client',JSON.parse(raw.toString()))}catch{}});const send=ws.send;ws.send=function(data,...rest){try{record(who,'recipient',JSON.parse(data.toString()))}catch{}return send.call(this,data,...rest)}});
  runtime=join(dir,'xdg');mkdirSync(runtime);const env={...process.env,XDG_DATA_HOME:join(runtime,'data'),XDG_CONFIG_HOME:join(runtime,'config'),XDG_CACHE_HOME:join(runtime,'cache')};for(const p of [env.XDG_DATA_HOME,env.XDG_CONFIG_HOME,env.XDG_CACHE_HOME])mkdirSync(p);
   const startFile=join(dir,'start.trigger'),stopFile=join(dir,'stop.trigger');
   const probeArgs=fullRound?['--full-round',`--probe-timeout-ms=${probeTimeoutMs}`]:[];
   const launch=(who,extra=[])=>{const argv=engineDriver?['--audio-driver','Dummy','--headless','--path','godot','--script','res://tests/lattice/probe_pair_flagship.gd','--',`--endpoint=${endpoint}`,`--map=${args.map}`,`--mode=${args.mode}`,`--pair-role=${who}`,`--start-file=${startFile}`,`--stop-file=${stopFile}`,'--native-trace',...probeArgs,...extra]:['--audio-driver','Dummy','--path','godot','res://lattice/world_demo.tscn','--',`--endpoint=${endpoint}`,`--map=${args.map}`,`--mode=${args.mode}`,'--native-trace',...extra];const c=spawn(process.env.GODOT_BIN,argv,{cwd:root,env,stdio:['ignore','pipe','pipe'],detached:true});children.push(c);for(const stream of [c.stdout,c.stderr])createInterface({input:stream}).on('line',l=>{logs.write(`${who}: ${l.slice(0,4000)}\n`);if(l.startsWith('LATTICE_PAIR_PROBE '))try{reports[who].push(JSON.parse(l.slice(19)))}catch{};if(l.startsWith('PORT_NATIVE_TRACE '))try{traces.write(JSON.stringify({client:who,...JSON.parse(l.slice(18))})+'\n')}catch{}});return c};
   const host=launch('host',[`--time-limit=${fullRound?roundLimit:900}`]);await until(()=>sockets.host.some(x=>x.direction==='recipient'&&x.frame.type==='welcome')&&sockets.host.some(x=>x.direction==='recipient'&&x.frame.type==='lobby'),60000,controller.signal);const welcome=sockets.host.find(x=>x.frame.type==='welcome').frame;
   const guest=launch('guest',[`--join-room=${welcome.roomId}`]);await until(()=>{const e=evaluatePair(sockets);return e.room_match&&e.host_config_echoed&&e.guest_published_presence&&e.two_distinct_peers},60000,controller.signal);
   const gate=evaluatePair(sockets);writeFileSync(join(dir,'start-gate.json'),JSON.stringify({...gate,status:'READY_FOR_HUMAN_CLICK',instruction:'Click Start / restart (host) in host Godot window now. Do not type protocol commands.'},null,2));console.log(`Both clients joined room ${welcome.roomId}. Click Start / restart (host) in host window; press Enter here only after the click.`);
   if(engineDriver)writeFileSync(startFile,'engine-scripted Start after recipient peer gate\n');
   else await new Promise((ok,no)=>{const rl=createInterface({input:process.stdin,output:process.stdout});let settled=false;const done=error=>{if(settled)return;settled=true;clearTimeout(deadline);controller.signal.removeEventListener('abort',abort);rl.close();error?no(error):ok()};const abort=()=>done(Error('interrupted'));const deadline=setTimeout(()=>done(Error('human start deadline')),10*60*1000);controller.signal.addEventListener('abort',abort,{once:true});rl.question('After clicking host Start, press Enter: ',()=>done())});
   await until(()=>{const e=evaluatePair(sockets);return e.host_start_observed&&e.guest_start_observed&&e.two_distinct_actors},30000,controller.signal);
   if(engineDriver){
     await until(()=>reports.host.some(r=>r.status==='active'&&r.input_sent>=45)&&reports.guest.some(r=>r.status==='active'&&r.input_sent>=45),30000,controller.signal);
     observation=evaluatePair(sockets);
     if(!observation.two_distinct_peers||!observation.two_distinct_actors)throw Error('Two simultaneously connected source actors not observed');
     if(fullRound){
       // Wait for the source terminal result on BOTH independent recipient
       // sockets. These are recipient-observed states; the witness never
       // constructs or replays an authoritative event.
       await until(()=>evaluateFullRound(sockets,{dropped,snapshotRevisions,reports}).both_terminal,terminalWaitMs,controller.signal);
       // A clean restart means each socket receives a later `start` revision
       // and a snapshot bearing it. The host probe only issues the ordinary
       // restart request; the server mints the authoritative restart.
       await until(()=>evaluateFullRound(sockets,{dropped,snapshotRevisions,reports}).both_restarted,restartWaitMs,controller.signal);
       roundEvidence=evaluateFullRound(sockets,{dropped,snapshotRevisions,reports});
       if(roundEvidence.witness_status!=='ROUND_OBSERVED')throw Error(`Full-round evidence incomplete: ${roundEvidence.failures.join('; ')}`);
     }
     writeFileSync(stopFile,'pair observation complete\n');
   }
   reason=fullRound?'engine-driven-two-native-full-round-observed':engineDriver?'engine-driven-two-client-observed':'source-start-observed-both';if(!engineDriver)await new Promise(r=>setTimeout(r,5000));
 }catch(e){error=String(e.stack??e);reason=reason==='blocked-awaiting-human-click'?'BLOCKED':reason}finally{
  for(const c of children)if(c.exitCode===null&&c.signalCode===null)try{process.kill(-c.pid,'SIGTERM')}catch{};
  await Promise.all(children.map(c=>c.exitCode!==null||c.signalCode!==null?Promise.resolve():new Promise(ok=>{c.once('exit',ok);setTimeout(()=>{try{process.kill(-c.pid,'SIGKILL')}catch{}},3000)})));childrenWaited=true;
   if(game){for(const ws of game.wss.clients)ws.terminate();await game.close();serverClosed=!game.server.listening}await Promise.all([new Promise(r=>wire.end(r)),new Promise(r=>traces.end(r)),new Promise(r=>logs.end(r))]);
   if(runtime)rmSync(runtime,{recursive:true,force:true});process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
   const evaluation=observation??evaluatePair(sockets);
   if(fullRound&&!roundEvidence)roundEvidence=evaluateFullRound(sockets,{dropped,snapshotRevisions,reports});
   const capture={rows,bytes,max_rows:maxRows,max_bytes:maxBytes,dropped,capture_complete:dropped===0};
   if(roundEvidence)writeFileSync(join(dir,'round.json'),JSON.stringify(roundEvidence,null,2));
   const status=fullRound?(roundEvidence?.claim??'BLOCKED'):reason==='source-start-observed-both'?'OBSERVED':reason==='engine-driven-two-client-observed'?'ENGINE_SMOKE_OBSERVED':'BLOCKED';
   writeFileSync(join(dir,'results.json'),JSON.stringify({status,reason,evaluation,full_round:fullRound,round:roundEvidence,capture,reports,guest_start_authorization:'UNVERIFIED',guest_outgoing:sockets.guest.filter(x=>x.direction==='client'),cleanup:{children_waited:childrenWaited,server_closed:serverClosed,temp_removed:!runtime||!existsSync(runtime)},error},null,2));
   const files=['manifest.json','wire.jsonl','native.jsonl','native.log','results.json',...(roundEvidence?['round.json']:[])];
   const hashes={};for(const f of files)hashes[f]=createHash('sha256').update(readFileSync(join(dir,f))).digest('hex');writeFileSync(join(dir,'evidence-manifest.json'),JSON.stringify({schema_version:1,pin:lock.source_commit,evidence_class:evidenceClass,labels:{wire:`per-socket recipient and outgoing frames; complete up to ${maxRows} rows / ${maxBytes} bytes, drops counted and fatal for a full round`,native:'per-client PORT_NATIVE_TRACE lines; logs are not outcomes',start:fullRound?'engine-scripted Start and scripted restart request; no human click or identity':'human click only; source start must be observed',round:fullRound?'both independent recipient sockets must show a terminal result and a clean restart; never a five-wave or human claim':'not-applicable',security:'guest cannot-start assertion unverified'},hashes,elapsed_ms:Date.now()-started,cleanup:{children_waited:childrenWaited,server_closed:serverClosed,temp_removed:!runtime||!existsSync(runtime)}},null,2));if(error)console.error(error);console.log(`${dir}: ${status} (${reason})`);
 }
}
function until(predicate,ms,signal){return new Promise((ok,no)=>{const end=Date.now()+ms;const tick=()=>signal?.aborted?no(Error('interrupted')):predicate()?ok():Date.now()>end?no(Error('bounded wait expired')):setTimeout(tick,100);tick()})}

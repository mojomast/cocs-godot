import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,cpSync,symlinkSync,mkdirSync,readFileSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {until,sleep,stopChild} from '../native_trace_correlation/guest_helpers.mjs';
import {planRoute} from './route.mjs';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../../..');
const binary=process.env.GODOT_BIN,deps=process.env.GUEST_NODE_MODULES;
assert.ok(binary&&deps,'Set GODOT_BIN and GUEST_NODE_MODULES');
const out=resolve(root,'port/native-pickup-acceptance/evidence',new Date().toISOString().replaceAll(':','-'));
mkdirSync(out,{recursive:true,mode:0o700});
const temp=mkdtempSync('/tmp/opencode/cocs-pickup-runtime-');
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8',LIBGL_ALWAYS_SOFTWARE:'1'};
for(const k of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']) {env[k]=resolve(temp,k);mkdirSync(env[k]);}
const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8',timeout:5000}).trim();
const report={scenario:'PICKUP-WEAPON',base:git('rev-parse','HEAD'),branch:git('branch','--show-current'),executionCheckout:root,
  normalRate:true,tickDt:1/60,tickMs:1000/60,completionProven:false,status:'INCONCLUSIVE',cleanup:{},
  command:`GODOT_BIN=${binary} GUEST_NODE_MODULES=${deps} node port/tools/native_pickup_acceptance/run.mjs`,
  runtimeTrees:Object.fromEntries(['godot','game','server'].map(p=>[p,git('rev-parse',`HEAD:${p}`)])),
  sourceStatus:git('status','--porcelain','--','godot','game','server','port/tools/native_pickup_acceptance'),
  hashes:Object.fromEntries(['run.mjs','observe.gd','route.mjs'].map(p=>[p,createHash('sha256').update(readFileSync(resolve(here,p))).digest('hex')]))};
const children=[],wire=[],observations=[];
let game,host,native,display,timeout,interrupted=false,captureStart;
const interrupt=()=>{interrupted=true;native?.kill('SIGTERM');};
process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
function launch(command,args,name,deadline,extra={}) {
  const child=spawn(command,args,{env,stdio:['ignore','pipe','pipe'],...extra});
  children.push(child);child.text='';child.errors='';child.failure=null;
  child.on('error',e=>child.failure=e.message);
  child.stdout.on('data',d=>{child.text+=d;if(child.text.length>16000000){child.failure='stdout cap';child.kill('SIGKILL');}});
  child.stderr.on('data',d=>{child.errors+=d;if(child.errors.length>1000000){child.failure='stderr cap';child.kill('SIGKILL');}});
  const timer=setTimeout(()=>{child.failure='owned child deadline';child.kill('SIGKILL');},deadline);
  child.closed=new Promise(r=>child.once('close',()=>{clearTimeout(timer);writeFileSync(resolve(out,`${name}.stdout.log.gz`),gzipSync(child.text));writeFileSync(resolve(out,`${name}.stderr.log`),child.errors);r();}));
  return child;
}
async function wait(p,ms,label) {await until(()=>{if(interrupted)throw Error('interrupted');if(native?.failure)throw Error(native.failure);return p();},ms,label);}
try {
  assert.equal(report.sourceStatus,'','Commit execution sources before live capture');
  report.version=execFileSync(binary,['--version'],{encoding:'utf8',timeout:10000}).trim();
  assert.equal(report.version,JSON.parse(readFileSync(resolve(root,'port/contracts/source-lock.json'))).godot_version);
  for(const dir of ['godot','game','server'])cpSync(resolve(root,dir),resolve(temp,dir),{recursive:true,filter:p=>!p.includes('/.godot')});
  writeFileSync(resolve(out,'export.log'),execFileSync(process.execPath,[resolve(root,'tools/godot-export/semantic.mjs'),resolve(temp,'godot/content/generated')],{cwd:root,env,encoding:'utf8',timeout:60000}));
  symlinkSync(resolve(deps),resolve(temp,'node_modules'),'dir');
  const importer=launch(binary,['--headless','--path',resolve(temp,'godot'),'--editor','--import'],'import',60000);
  await wait(()=>importer.exitCode!==null||importer.signalCode!==null,65000,'import');await importer.closed;assert.equal(importer.exitCode,0);
  // Linux abstract local socket avoids changing shared /tmp/.X11-unix permissions.
  display=launch('Xvfb',['-displayfd','3','-screen','0','960x640x24','-nolisten','tcp','-nolisten','unix'],'xvfb',115000,{stdio:['ignore','pipe','pipe','pipe']});
  let displayNumber='';display.stdio[3].on('data',d=>displayNumber+=d);
  await wait(()=>/^\d+\n$/.test(displayNumber),5000,'private Xvfb display');
  env.DISPLAY=`:${displayNumber.trim()}`;report.privateDisplay=env.DISPLAY;
  const req=createRequire(resolve(temp,'entry.cjs')),{WebSocket}=req('ws');
  const {createGameServer}=await import(pathToFileURL(resolve(temp,'server/game-server.mjs')));
  const {DESTINATION_COMBAT_MAPS}=await import(pathToFileURL(resolve(temp,'game/destination-combat-maps.mjs')));
  game=createGameServer({historyPath:null,progressionPath:null});
  captureStart=performance.now();report.captureStartedAt=new Date().toISOString();
  timeout=setTimeout(()=>{interrupted=true;native?.kill('SIGKILL');},105000);
  game.server.listen(0,'127.0.0.1');await wait(()=>game.server.listening,5000,'loopback listen');
  const endpoint=`ws://127.0.0.1:${game.server.address().port}`;report.endpoint=endpoint;
  let connections=0,peer=null,actorId=null,planned=false;
  game.wss.on('connection',socket=>{
    const guest=++connections===2;if(!guest)return;
    socket.on('message',raw=>wire.push({direction:'client',wallMs:performance.now()-captureStart,frame:JSON.parse(raw)}));
    const send=socket.send;socket.send=function(data,...args) {
      const f=JSON.parse(data);
      if(f.type==='welcome')peer=f.peerId;
      if(f.type==='lobby'&&peer!==null)actorId=f.players.find(p=>p.peerId===peer)?.actorId??actorId;
      const wallMs=performance.now()-captureStart;
      if(f.type==='snapshot') {
        const actor=f.state.actors.find(a=>a.id===actorId),pickup=f.state.pickups.find(p=>p.kind==='rocket'&&p.x===-14&&p.z===-19);
        wire.push({direction:'server',wallMs,frame:{type:f.type,seq:f.seq,acks:f.acks,time:f.state.time,over:f.state.over,actor,pickup}});
        if(actor&&!planned) {
          report.config=f.state.config;report.actorId=actorId;report.initialActor=actor;report.initialPickup=pickup;
          try {report.route=planRoute(DESTINATION_COMBAT_MAPS[0],actor);writeFileSync(resolve(temp,'route.json'),JSON.stringify(report.route));}
          catch(e){report.routeError=e.message;}
          planned=true;
        }
      } else wire.push({direction:'server',wallMs,frame:f});
      return send.call(this,data,...args);
    };
  });
  const frames=[];host=new WebSocket(endpoint);host.on('error',()=>{});host.on('message',raw=>frames.push(JSON.parse(raw)));
  await wait(()=>host.readyState===WebSocket.OPEN,5000,'host open');
  host.send(JSON.stringify({type:'create',name:'Isolated native pickup',playerName:'Passive host',v:3,delta:0}));
  await wait(()=>frames.some(f=>f.type==='welcome'),5000,'host welcome');
  report.room=frames.find(f=>f.type==='welcome').roomId;
  host.send(JSON.stringify({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0}}));
  await wait(()=>frames.some(f=>f.type==='lobby'&&f.config),5000,'configuration');
  const args=['--path',resolve(temp,'godot'),'--rendering-method','gl_compatibility','--resolution','960x640','--max-fps','60','--script',resolve(here,'observe.gd'),'--',`--endpoint=${endpoint}`,`--join-room=${report.room}`,'--native-trace',`--evidence=${out}`,`--route=${resolve(temp,'route.json')}`];
  report.nativeCommand=[binary,...args];native=launch(binary,args,'native',95000);
  await wait(()=>wire.some(r=>r.direction==='client'&&r.frame.type==='join')||native.exitCode!==null,15000,'native joined');
  assert.equal(native.exitCode,null,'Native exited during startup');await sleep(500);
  host.send(JSON.stringify({type:'start'}));report.hostStartWallMs=performance.now()-captureStart;
  await wait(()=>native.exitCode!==null||native.signalCode!==null,92000,'bounded native pickup capture');await native.closed;
  report.nativeExit={code:native.exitCode,signal:native.signalCode};
  for(const line of native.text.split('\n'))if(line.startsWith('PICKUP_OBSERVE '))observations.push(JSON.parse(line.slice(15)));
  const snaps=observations.filter(o=>o.event==='snapshot');
  const consumed=snaps.findIndex(o=>o.pickup.wait>0&&o.stage==='approach');
  const before=snaps[consumed-1],after=snaps[consumed],returned=snaps.find(o=>o.stage==='waiting_return'&&o.pickup.wait===0);
  const left=snaps.find(o=>o.stage==='waiting_return'&&o.distance>1.05);
  report.transitions={before,after,left,returned};
  report.harnessEnd=observations.find(o=>o.event==='harness_end')??null;
  report.counts={wire:wire.length,observations:observations.length,nativeSnapshots:snaps.length,nativeTrace:native.text.split('\n').filter(l=>l.startsWith('PORT_NATIVE_TRACE ')).length};
  assert.ok(before&&after&&left&&returned,'Missing before/contact/leave/server-return transition');
  assert.equal(before.pickup.wait,0);assert.equal(before.marker_visible,true);assert.equal(after.marker_visible,false);assert.equal(returned.marker_visible,true);
  assert.equal(before.pickup.id,returned.pickup.id);assert.equal(before.marker_instance,returned.marker_instance);
  assert.ok(after.actor.ammo[1]>before.actor.ammo[1],'Rocket ammo must increase');
  if(before.actor.weapon===0)assert.equal(after.actor.weapon,1);
  assert.ok(returned.time-after.time>=14.8&&returned.time-after.time<=15.2,'Normal 15-second authority return bracket');
  assert.ok(after.pickup.wait>14.8&&after.pickup.wait<=15);
  const same=snaps.slice(consumed,snaps.indexOf(returned)+1);
  assert.ok(same.every(o=>o.marker_visible===(o.pickup.wait<=0)),'Marker wait correspondence');
  assert.ok(same.every(o=>o.pickup.id===after.pickup.id&&o.actor_id===after.actor_id),'Same authority identities');
  assert.ok(same.filter(o=>o.stage==='waiting_return').every(o=>o.distance>1.05),'Leave radius during return wait');
  const pickupEvents=wire.filter(r=>r.direction==='server'&&r.frame.type==='events').flatMap(r=>r.frame.items??[]).filter(e=>e.type==='pickup'&&e.actor===report.actorId&&e.kind==='rocket');
  report.pickupEvents=pickupEvents;assert.equal(pickupEvents.length,1,'One native-actor rocket event');
  const authoritative=new Map(wire.filter(r=>r.frame.type==='snapshot').map(r=>[r.frame.seq,r.frame]));
  for(const o of snaps) {const f=authoritative.get(o.seq);assert.ok(f);assert.deepEqual(o.pickup,f.pickup);assert.equal(o.actor.weapon,f.actor.weapon);assert.deepEqual(o.actor.ammo,f.actor.ammo);}
  assert.ok(wire.some(r=>r.direction==='client'&&r.frame.type==='input'&&Math.hypot(r.frame.input.x,r.frame.input.z)>.5),'Real guest movement input received');
  for(const name of ['available','hidden','left_radius','returned'])assert.ok(existsSync(resolve(out,`${name}.png`)),`Missing ${name} screenshot`);
  report.status='PASS';
} catch(e) {report.error=e.stack;process.exitCode=1;}
finally {
  clearTimeout(timeout);
  for(const child of [...children].reverse())try{const state=await stopChild(child);await child.closed;(report.cleanup.children??=[]).push(state);}catch(e){report.cleanup.error=e.stack;process.exitCode=1;}
  host?.terminate();
  if(game)try{for(const s of game.wss.clients)s.terminate();await Promise.race([game.close(),sleep(5000).then(()=>{throw Error('server cleanup deadline');})]);report.cleanup.serverClosed=!game.server.listening;report.cleanup.socketCount=game.wss.clients.size;}catch(e){report.cleanup.serverError=e.stack;process.exitCode=1;}
  report.captureWallMs=captureStart?performance.now()-captureStart:null;
  rmSync(temp,{recursive:true,force:true});report.cleanup.privateTempRemoved=!existsSync(temp);
  writeFileSync(resolve(out,'wire.jsonl.gz'),gzipSync(wire.map(r=>JSON.stringify(r)).join('\n')+'\n'));
  writeFileSync(resolve(out,'observations.jsonl.gz'),gzipSync(observations.map(r=>JSON.stringify(r)).join('\n')+'\n'));
  writeFileSync(resolve(out,'summary.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({status:report.status,error:report.error,evidence:out,captureWallMs:report.captureWallMs}));
  process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
}

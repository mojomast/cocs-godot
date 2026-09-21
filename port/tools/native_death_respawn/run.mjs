// Private-copy setup, observer, and cleanup patterns adapted from
// native_trace_correlation/run.mjs at fbc8345 and guest_session_integration
// 389561510ac7c2223a22897c963f3440304ec928. Runtime is copied without edits.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,cpSync,symlinkSync,mkdirSync,readFileSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {randomUUID,createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {until,sleep,stopChild} from './helpers.mjs';
import {analyze} from './analyze.mjs';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../../..');
const binary=process.env.GODOT_BIN,deps=process.env.GUEST_NODE_MODULES;
assert.ok(binary&&deps,'Set GODOT_BIN and GUEST_NODE_MODULES');
const id=randomUUID(),out=resolve(root,'port/native-death-respawn/evidence',id);
mkdirSync(out,{recursive:true,mode:0o700});
const temp=mkdtempSync('/tmp/opencode/cocs-death-live-');
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8',LIBGL_ALWAYS_SOFTWARE:'1'};
for(const k of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
const hash=b=>createHash('sha256').update(b).digest('hex');
const report={schema:1,id,base:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),normalRate:true,completionProven:false,started:new Date().toISOString(),cleanup:{},artifacts:{}};
report.command=`GODOT_BIN=${binary} GUEST_NODE_MODULES=${deps} node port/tools/native_death_respawn/run.mjs`;
report.sourceHashes=Object.fromEntries(['run.mjs','observe.gd','helpers.mjs','analyze.mjs'].map(f=>[f,hash(readFileSync(resolve(here,f)))]));
report.runtimeHashes=Object.fromEntries(['godot/world/session.gd','godot/net/client.gd','godot/world/presentation.gd','godot/world/local_lifecycle.gd','server/game-server.mjs','server/room.mjs','game/core.mjs','game/bots.mjs','game/destination-combat-maps.mjs'].map(f=>[f,hash(readFileSync(resolve(root,f)))]));
const wire={connections:0,joins:0,actor:null,mappingChanges:0,unexpected:[],starts:[],snapshots:[],inputs:[],events:[],results:0,attackerInputs:[],navigationSamples:[]};
let wireBytes=0;
function retain(array,value){wireBytes+=Buffer.byteLength(JSON.stringify(value));if(wireBytes>8000000){childFailure='wire evidence cap';return;}array.push(value);}
let game,host,native,xvfb,attackerTimer,childFailure=null,interrupted=false,startWall=null;
const children=[];
const interrupt=()=>{interrupted=true;};process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
function save(name,bytes){writeFileSync(resolve(out,name),bytes,{mode:0o600});report.artifacts[name]={bytes:bytes.length,sha256:hash(bytes)};}
function launch(command,args,name,deadline){
 const c=spawn(command,args,{env,stdio:['ignore','pipe','pipe']});children.push({c,name});c.stdoutText='';c.stderrText='';
 c.on('error',e=>childFailure=`${name}: ${e.message}`);
 for(const [s,k] of [[c.stdout,'stdoutText'],[c.stderr,'stderrText']])s.on('data',d=>{if(c[k].length+d.length>8000000){childFailure=`${name} output cap`;c.kill('SIGTERM');}else c[k]+=d.toString();});
 const timer=setTimeout(()=>{childFailure=`${name} deadline`;c.kill('SIGKILL');},deadline);
 c.closed=new Promise(r=>c.once('close',()=>{clearTimeout(timer);save(`${name}.stdout.log.gz`,gzipSync(c.stdoutText));save(`${name}.stderr.log.gz`,gzipSync(c.stderrText));r();}));return c;
}
async function wait(pred,ms,label){await until(()=>{if(interrupted)throw Error('interrupted');if(childFailure)throw Error(childFailure);return pred();},ms,label);}
const lines=(c,prefix)=>c.stdoutText.split('\n').filter(l=>l.startsWith(prefix)&&l.endsWith('}')).map(l=>JSON.parse(l.slice(prefix.length)));
try{
 report.version=execFileSync(binary,['--version'],{encoding:'utf8',timeout:10000}).trim();assert.equal(report.version,JSON.parse(readFileSync(resolve(root,'port/contracts/source-lock.json'))).godot_version);
 for(const dir of ['godot','game','server'])cpSync(resolve(root,dir),resolve(temp,dir),{recursive:true,filter:p=>!p.includes('/.godot')});
 save('export.log.gz',gzipSync(execFileSync(process.execPath,[resolve(root,'tools/godot-export/semantic.mjs'),resolve(temp,'godot/content/generated')],{cwd:root,env,encoding:'utf8',timeout:60000,maxBuffer:1000000})));
 symlinkSync(resolve(deps),resolve(temp,'node_modules'),'dir');
 const req=createRequire(resolve(temp,'entry.cjs')),{WebSocket}=req('ws');
 const {createGameServer}=await import(pathToFileURL(resolve(temp,'server/game-server.mjs')));
 const {navigation,walkEdge,visible,eye}=await import(pathToFileURL(resolve(temp,'game/core.mjs')));
 const {getMap}=await import(pathToFileURL(resolve(temp,'game/maps.mjs')));
 const {path}=await import(pathToFileURL(resolve(temp,'game/bots.mjs')));
 const arena=getMap('meridian-exchange'),nav=navigation(arena);report.navigationNodes=nav.nodes.length;
 const importer=launch(binary,['--headless','--path',resolve(temp,'godot'),'--editor','--import'],'import',60000);
 await wait(()=>importer.exitCode!==null||importer.signalCode!==null,65000,'import');await importer.closed;assert.equal(importer.exitCode,0);assert.ok(!/SCRIPT ERROR|Parse Error/.test(importer.stderrText));
 // Keep Linux abstract-local transport; disable filesystem UNIX sockets because
 // /tmp/.X11-unix can be an unwritable shared-desktop mount. Never alter it.
 xvfb=launch('Xvfb',['-displayfd','1','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix','-noreset'],'xvfb',150000);
 await wait(()=>/^\d+\n/.test(xvfb.stdoutText),5000,'private Xvfb display');env.DISPLAY=`:${parseInt(xvfb.stdoutText,10)}`;report.privateDisplay=env.DISPLAY;
 game=createGameServer({historyPath:null,progressionPath:null});let listenError;
 game.server.once('error',e=>listenError=e);game.server.listen(0,'127.0.0.1');await wait(()=>{if(listenError)throw listenError;return game.server.listening;},5000,'listen');
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;report.endpoint=endpoint;
 let guestPeer=null,hostPeer=null,hostActor=null,latest=null,room=null,configured=false,attackerSeq=0;
 game.wss.on('connection',socket=>{
  const guest=++wire.connections===2;
  socket.on('message',raw=>{
   if(!guest)return;const f=JSON.parse(raw.toString());
   if(f.type==='join')wire.joins++;else if(f.type==='input')retain(wire.inputs,{seq:f.seq,input:f.input});else retain(wire.unexpected,f.type);
  });
  const send=socket.send;socket.send=function(data,...args){
   if(guest){const f=JSON.parse(data.toString());
    if(f.type==='welcome')guestPeer=f.peerId;
    if(f.type==='lobby'&&guestPeer!==null){const p=f.players.find(p=>p.peerId===guestPeer);if(wire.actor!==null&&p?.actorId!==wire.actor)wire.mappingChanges++;if(p?.actorId!=null)wire.actor=p.actorId;}
    if(f.type==='start')retain(wire.starts,{mapId:f.mapId,roundRevision:f.roundRevision});
    if(f.type==='results')wire.results++;
    if(f.type==='events')for(const e of f.items)retain(wire.events,e);
    if(f.type==='snapshot'){const a=f.state.actors.find(a=>a.id===wire.actor);retain(wire.snapshots,{seq:f.seq,time:f.state.time,over:f.state.over,actor:wire.actor,ack:f.acks[String(wire.actor)]??0,health:a?.health??null,dead:a?.dead??null,pose:a?[a.x,a.y,a.z]:null,eyeHeight:a?.eyeHeight??1.45,yaw:a?.yaw,pitch:a?.pitch});}
   }return send.call(this,data,...args);
  };
 });
 host=new WebSocket(endpoint);host.on('error',()=>{});host.on('message',raw=>{
  const f=JSON.parse(raw.toString());
  if(f.type==='welcome'){hostPeer=f.peerId;room=f.roomId;}
  if(f.type==='lobby'){hostActor=f.players.find(p=>p.peerId===hostPeer)?.actorId??null;wire.attackerActor=hostActor;configured=!!f.config;wire.config=f.config;}
  if(f.type==='snapshot')latest=f.state;
 });
 await wait(()=>host.readyState===WebSocket.OPEN,5000,'host open');host.send(JSON.stringify({type:'create',name:`native-death-${id}`,playerName:'Protocol attacker',v:3,delta:0}));
 await wait(()=>room!==null,5000,'host welcome');
 host.send(JSON.stringify({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0,timeLimit:180,fragLimit:100}}));await wait(()=>configured,5000,'host configuration');
 const args=['--audio-driver','Dummy','--path',resolve(temp,'godot'),'--script',resolve(here,'observe.gd'),'--',`--endpoint=${endpoint}`,`--join-room=${room}`,'--native-trace'];report.nativeCommand=[binary,...args];
 native=launch(binary,args,'native',125000);
 await wait(()=>lines(native,'HARNESS_SAMPLE ').some(s=>s.phase===11),12000,'native joined');
 report.waiting=lines(native,'HARNESS_SAMPLE ').find(s=>s.phase===11);assert.equal(wire.starts.length,0);
 host.send(JSON.stringify({type:'start'}));startWall=performance.now();
 let route=[],replanAt=-1,lastSample=-1,killed=false;
 attackerTimer=setInterval(()=>{
  try {
   if(!latest||host.readyState!==WebSocket.OPEN)return;
   const a=latest.actors.find(a=>a.id===hostActor),v=latest.actors.find(a=>a.id===wire.actor);if(!a||!v)return;
   if(v.dead>0)killed=true;
   let x=0,z=0;const target={x:v.x,y:v.y+(v.eyeHeight??1.45)*0.7,z:v.z},origin=eye(a),distance=Math.hypot(v.x-a.x,v.z-a.z),los=visible(origin,target,arena);
   if(!killed&&(!los||distance>7)){
    if(latest.time>=replanAt){route=path(a,v,nav.nodes,nav.edges);replanAt=latest.time+1;}
    while(route.length>1&&Math.hypot(a.x-nav.nodes[route[0]].x,a.z-nav.nodes[route[0]].z)<1)route.shift();
    const dest=walkEdge(a,v,arena)?v:(route.length?nav.nodes[route[0]]:v),d=Math.hypot(dest.x-a.x,dest.z-a.z);
    if(d>0.25){x=(dest.x-a.x)/d;z=(dest.z-a.z)/d;}
   }
   const dy=target.y-origin.y,yaw=Math.atan2(-(target.x-origin.x),-(target.z-origin.z)),pitch=Math.atan2(dy,distance);
   const input={x,z,yaw,pitch,fire:!killed&&los&&distance<20,sprint:!los||distance>20,weapon:0};
   const packet={type:'input',seq:++attackerSeq,input};host.send(JSON.stringify(packet));retain(wire.attackerInputs,packet);
   if(latest.time-lastSample>=1){lastSample=latest.time;retain(wire.navigationSamples,{time:latest.time,attacker:[a.x,a.y,a.z],victim:[v.x,v.y,v.z],distance,los,routeLength:route.length,health:v.health,dead:v.dead});}
  }catch(e){childFailure=`attacker: ${e.stack}`;}
 },50);
 await wait(()=>native.exitCode!==null||native.signalCode!==null,118000,'bounded gameplay');await native.closed;
 report.gameplayWallSeconds=(performance.now()-startWall)/1000;assert.ok(report.gameplayWallSeconds<=120);assert.equal(native.exitCode,0);
 clearInterval(attackerTimer);attackerTimer=null;await sleep(200);
 assert.ok(!/SCRIPT ERROR|Parse Error|ERROR:/.test(native.stderrText),'Godot engine errors');
 report.acceptance=analyze(native.stdoutText,wire);report.status=report.acceptance.status;
 if(report.status!=='PASS')process.exitCode=2;
}catch(e){report.status='FAIL';report.error=e.stack;process.exitCode=1;}
finally{
 clearInterval(attackerTimer);
 if(startWall&&report.gameplayWallSeconds===undefined)report.gameplayWallSeconds=(performance.now()-startWall)/1000;
 const errors=[];
 for(const {c,name} of [...children].reverse())try{report.cleanup[name]=await stopChild(c);await c.closed;}catch(e){errors.push(`${name}: ${e.stack}`);}
 try{host?.terminate();if(game){for(const s of game.wss.clients)s.terminate();await Promise.race([game.close(),sleep(5000).then(()=>{throw Error('server close deadline');})]);await until(()=>!game.server.listening&&game.wss.clients.size===0,5000,'server closed');report.cleanup.serverClosed=true;report.cleanup.socketCount=game.wss.clients.size;}}catch(e){errors.push(e.stack);}
 save('wire.json.gz',gzipSync(JSON.stringify(wire)));
 rmSync(temp,{recursive:true,force:true});report.cleanup.privateTempRemoved=!existsSync(temp);
 if(errors.length){report.cleanupErrors=errors;report.status='FAIL';process.exitCode=1;}
 report.finished=new Date().toISOString();writeFileSync(resolve(out,'summary.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
 console.log(JSON.stringify({status:report.status,evidence:out,error:report.error,acceptance:report.acceptance},null,2));
}

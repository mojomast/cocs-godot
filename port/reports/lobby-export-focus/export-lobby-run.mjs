// New follow-up captures only. No authority writes or direct widget/session calls.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,mkdtempSync,readFileSync,writeFileSync,renameSync,rmSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {gzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {createGameServer} from "file:///tmp/opencode/lead-native-linux-package/builds/1790054125934591826/cocs-native-linux/runtime/server/game-server.mjs";
import {sleep,until,stopChild} from "file:///home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/port/tools/native_trace_correlation/guest_helpers.mjs";
const releaseBinary="/tmp/opencode/lead-native-linux-package/builds/1790054125934591826/cocs-native-linux/cocs.x86_64";
const debugComparison=process.argv[2]==='targeted-debug';
const binary=debugComparison?'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64':releaseBinary;
const packageDir=resolve(releaseBinary,'..'),manifestPath=resolve(packageDir,'manifest.json'),manifestBytes=readFileSync(manifestPath),manifest=JSON.parse(manifestBytes);
const hash=b=>createHash('sha256').update(b).digest('hex');
assert.equal(hash(manifestBytes),'8f602b1cc48ab07a05378365a5890d96efea6b8b3d90e9d1c8a916ee085f40cc');
function verifyBytes(){for(const [name,digest] of Object.entries(manifest.files))assert.equal(hash(readFileSync(resolve(packageDir,name))),digest,'artifact '+name);assert.equal(hash(readFileSync(manifestPath)),hash(manifestBytes));}
verifyBytes();
const targeted=['targeted','targeted-debug'].includes(process.argv[2]),startup=false,map='meridian-exchange',mode='teamdeathmatch';
const out=resolve('port/reports/lobby-export-focus',debugComparison?'targeted-debug':(targeted?'targeted':'full-flow'));
assert.ok(!existsSync(out),'Preserve existing captures');mkdirSync(out);
const temp=mkdtempSync('/tmp/opencode/export-lobby-focus-'),children=[],wire=[],actions=[],witnesses=[];
const env={...process.env,HOME:temp,LIBGL_ALWAYS_SOFTWARE:'1',PORT:'0'};
for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']){env[key]=resolve(temp,key);mkdirSync(env[key],{mode:0o700});}
const summary={map,mode,startupOnly:startup,normalRate:true,input:'Godot engine events; Window.grab_focus/size for test-window management, not OS input',baseline:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),checks:[],milestones:[],cleanup:[]};
let game,timer,host,guest,expired=false,commandId=0,connection=0;const began=Date.now();
let stage='startup',policy=targeted?'always':'needed';
const pass=(name,value=true)=>{assert.ok(value,name);summary.checks.push(name);};
function spawnOwned(name,cmd,args,options){const p=spawn(cmd,args,options);p.name=name;p.text='';p.err='';p.samples=[];p.done=new Promise((res,rej)=>{p.once('error',rej);p.once('close',res);});children.push(p);if(p.stdout){let buffer='';p.stdout.on('data',b=>{p.text+=b;buffer+=b;let i;while((i=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,i);buffer=buffer.slice(i+1);if(line.startsWith('LOBBY_SAMPLE '))p.samples.push(JSON.parse(line.slice(13)));if(line.startsWith('EXPORT_WITNESS ')){p.witness=JSON.parse(line.slice(15));witnesses.push({receivedWall:Date.now(),client:name,kind:'engine',...p.witness});}}if(p.text.length>32*1024*1024)p.kill('SIGTERM');});}p.stderr?.on('data',b=>{p.err+=b;witnesses.push({receivedWall:Date.now(),client:name,kind:'stderr',text:b.toString(),stage,currentCommand:p.current,latestUI:latest(p),latestEngine:p.witness});});return p;}
const latest=p=>p.samples.at(-1);
async function wait(pred,ms,label){await until(()=>{if(expired)throw Error('120s deadline');for(const p of [host,guest])if(p&&(p.exitCode!==null||p.signalCode!==null))throw Error(`${p.name} exited: ${p.err}`);return pred();},ms,label);}
async function cmd(p,c){c={id:++commandId,stage,...c};p.current=c;actions.push({wall:Date.now(),client:p.name,...c});writeFileSync(p.inbox+'.next',JSON.stringify(c));renameSync(p.inbox+'.next',p.inbox);await wait(()=>latest(p)?.command===c.id,3000,'command '+c.op);}
async function focus(p){await cmd(p,{op:'focus',policy});await wait(()=>latest(p)?.focused,3000,'focus');}
async function key(p,name){await cmd(p,{op:'key',key:name,pressed:true});await cmd(p,{op:'key',key:name,pressed:false});}
async function clickXY(p,x,y){await cmd(p,{op:'mouse',x,y,pressed:true});await cmd(p,{op:'mouse',x,y,pressed:false});}
async function click(p,name){await focus(p);let ui=latest(p).ui[name],r=ui.rect;assert.ok(ui.visible,'visible '+name);for(let n=0;ui.in_form&&n<8&&(r[1]<32||r[1]+r[3]>p.height-32);n++){const button=r[1]<32?4:5;await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,button,pressed:true});await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,button,pressed:false});r=latest(p).ui[name].rect;}assert.ok(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=p.width&&r[1]+r[3]<=p.height,'actual viewport bounds '+name);await clickXY(p,r[0]+r[2]/2,r[1]+r[3]/2);}
async function fill(p,name,text){await click(p,name);await cmd(p,{op:'key',key:'A',pressed:true,ctrl:true});await cmd(p,{op:'key',key:'A',pressed:false,ctrl:true});await cmd(p,{op:'text',text});await wait(()=>latest(p)?.ui[name].text===text,3000,'text '+name);}
async function capture(p,name){await cmd(p,{op:'capture',name});await wait(()=>existsSync(resolve(out,name+'.png')),3000,'PNG '+name);summary.milestones.push({name,wall:Date.now(),client:p.name,sample:latest(p)});}
const intersects=(a,b)=>a[0]<b[0]+b[2]&&a[0]+a[2]>b[0]&&a[1]<b[1]+b[3]&&a[1]+a[3]>b[1];
function layout(p,label){const s=latest(p);pass(label+' HUD phase visibility',s.layout.hud.visible===[3,4,20].includes(s.phase));for(const name of ['leave_button','restart_button']){const b=s.ui[name];if(!b.visible)continue;for(const content of ['top','score','status','board'])if(s.layout[content].visible)pass(label+' '+name+' avoids '+content,!intersects(b.rect,s.layout[content].rect));}if(s.ui.restart_button.visible)pass(label+' actions separate',!intersects(s.ui.leave_button.rect,s.ui.restart_button.rect));}
async function gameplay(p,label){await focus(p);await wait(()=>latest(p)?.eligible,10000,'living eligible '+p.name);await clickXY(p,p.width/2,p.height/2);await wait(()=>latest(p)?.captured,3000,'fresh capture');await cmd(p,{op:'key',key:'W',pressed:true});await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,pressed:true});await sleep(1500);await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,pressed:false});await cmd(p,{op:'key',key:'W',pressed:false});await capture(p,label+'-captured');await key(p,'Escape');await capture(p,label+'-paused');layout(p,label);}
async function leave(p,label){await click(p,'leave_button');await wait(()=>latest(p)?.phase===-3,4000,label);const s=latest(p);pass(label+' clean state',s.actor===-1&&s.peer===-1&&!s.room&&!s.pose&&s.actors===0&&s.pickups===0&&!s.captured&&s.ack===0&&s.input_seq===0);const count=connection;await sleep(1200);pass(label+' no auto reconnect',connection===count&&latest(p).phase===-3);await capture(p,label);layout(p,label);}
async function choose(p,name,index){await click(p,name);await wait(()=>latest(p)?.ui[name].popup_visible,2000,'popup '+name);for(let i=0;i<30&&latest(p).ui[name].popup_focused!==index;i++)await key(p,'Down');pass(stage+' '+name+' focused item',latest(p).ui[name].popup_focused===index);await key(p,'Enter');await wait(()=>latest(p)?.ui[name].selected===index&&!latest(p).ui[name].popup_visible,2000,'selected '+name);}
try{
 summary.manifestSha256=hash(manifestBytes);summary.manifestFiles=Object.keys(manifest.files).length;summary.runtimeModules=Object.keys(manifest.files).filter(n=>n.startsWith('runtime/')&&n.endsWith('.mjs')&&!n.includes('/node_modules/')).length;summary.artifact=packageDir;summary.binary=binary;summary.binarySha256=hash(readFileSync(binary));summary.debugComparison=debugComparison;summary.observerSha256=hash(readFileSync('port/reports/lobby-export-focus/export-lobby-observer.gd'));summary.runnerSha256=hash(readFileSync('port/reports/lobby-export-focus/export-lobby-run.mjs'));summary.source='unchanged packaged authority';summary.godot=execFileSync(binary,['--version'],{encoding:'utf8'}).trim();assert.equal(summary.godot,'4.5.2.stable.official.6ce3de25a');
 timer=setTimeout(()=>{expired=true;for(const p of children)p.kill('SIGTERM');},targeted?45000:120000);
 const display=spawnOwned('xvfb','Xvfb',['-displayfd','3','-screen','0','2300x900x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
 const number=await new Promise((res,rej)=>{let text='';const timeout=setTimeout(()=>rej(Error('Xvfb startup')),5000);display.stdio[3].on('data',b=>{text+=b;if(text.includes('\n')){clearTimeout(timeout);res(text.trim());}});});env.DISPLAY=':'+number;summary.display=env.DISPLAY;
 game=createGameServer({historyPath:null,progressionPath:null});
 game.wss.on('connection',socket=>{const recipient=connection++;let revision=-1,peer=null,actor=null;
  socket.on('message',raw=>wire.push({wall:Date.now(),recipient,revision,type:'received',frame:JSON.parse(String(raw))}));
  socket.on('close',()=>wire.push({wall:Date.now(),recipient,revision,type:'socket-close'}));
  const send=socket.send;socket.send=function(data,...args){const f=JSON.parse(String(data));if(f.type==='welcome')peer=f.peerId;if(f.type==='lobby'){actor=f.players.find(p=>p.peerId===peer)?.actorId??null;revision=f.roundRevision;}if(f.type==='start')revision=f.roundRevision;
   wire.push({wall:Date.now(),recipient,peer,revision,...(['snapshot','results'].includes(f.type)?{type:f.type,seq:f.seq,acks:f.acks,actor,state:{mapId:f.state.mapId,config:f.state.config,time:f.state.time,over:f.state.over,teamScores:f.state.teamScores,actors:f.state.actors.map(a=>({id:a.id,name:a.name,bot:!!a.bot,x:a.x,y:a.y,z:a.z,health:a.health,dead:a.dead,shots:a.shots,weapon:a.weapon,ammo:a.ammo}))}}:f)});return send.call(this,data,...args);};});
 await new Promise((res,rej)=>{game.server.once('error',rej);game.server.listen(0,'127.0.0.1',res);});summary.port=game.server.address().port;pass('owned ephemeral port avoids 4332',summary.port!==4332);
 function native(name,width,height,position){const inbox=resolve(temp,name+'.json');const p=spawnOwned(name,binary,['--main-pack',resolve(packageDir,'cocs.pck'),'--audio-driver','Dummy','--max-fps','60','--resolution',`${width}x${height}`,'--position',position,'--script',resolve('port/reports/lobby-export-focus/export-lobby-observer.gd'),'--','--lobby-menu',`--map=${map}`,`--mode=${mode}`,`--endpoint=ws://127.0.0.1:${summary.port}`,`--lobby-inbox=${inbox}`,`--lobby-out=${out}`],{env,stdio:['ignore','pipe','pipe']});Object.assign(p,{inbox,width,height});return p;}
 host=native('host',960,640,'0,0');await wait(()=>latest(host)?.phase===-3,20000,'host menu');await capture(host,'01-host-menu-960x640');layout(host,'host menu');
 guest=native('guest',1280,800,'980,0');await wait(()=>latest(guest)?.phase===-3,20000,'guest menu');await capture(guest,'02-guest-menu-1280x800');layout(guest,'guest menu');
 if(targeted){
  stage='baseline-always-focus';await fill(host,'player_name','Focus Host');await fill(guest,'player_name','Focus Guest');await choose(guest,'role',1);await fill(guest,'room','TEST');await capture(guest,'03-always-after-role');
  stage='needed-focus-role';policy='needed';await focus(host);await focus(guest);await choose(guest,'role',0);await fill(guest,'player_name','Needed Guest');await capture(guest,'04-needed-after-role');
  stage='needed-focus-map';await choose(guest,'maps',latest(guest).ui.maps.selected);await choose(guest,'modes',latest(guest).ui.modes.selected);await capture(guest,'05-needed-map-mode');
  stage='popup-open-redundant-root-focus';await click(guest,'role');await wait(()=>latest(guest)?.ui.role.popup_visible,2000,'open for redundant focus');await cmd(guest,{op:'focus',policy:'always'});await sleep(500);await key(guest,'Escape');await capture(guest,'06-after-open-popup-focus');
  stage='final-normal-switch';await focus(host);await focus(guest);await sleep(500);pass('targeted no room connections',connection===0);summary.status='TARGETED COMPLETE';
 }else{
 stage='create-map';await choose(host,'maps',latest(host).ui.maps.selected);await choose(host,'modes',latest(host).ui.modes.selected);
 await fill(host,'player_name','Followup Host');await click(host,'connect_button');await wait(()=>latest(host)?.phase===12,10000,'host lobby');summary.room=latest(host).room;pass('no automatic host Start',!wire.some(f=>f.type==='start'));await capture(host,'03-host-created');
 await fill(guest,'player_name','Followup Guest');await click(guest,'role');for(let i=0;i<3&&latest(guest).ui.role.popup_focused!==1;i++)await key(guest,'Down');pass('guest popup target observed',latest(guest).ui.role.popup_focused===1);await key(guest,'Enter');await wait(()=>latest(guest)?.ui.role.text.startsWith('Guest'),3000,'guest role');await fill(guest,'room',summary.room);await click(guest,'connect_button');await wait(()=>latest(guest)?.phase===11,10000,'guest lobby');await wait(()=>latest(host)?.roster.includes('Followup Guest'),4000,'roster');await capture(guest,'04-guest-roster');
 await click(host,'start_button');await wait(()=>latest(host)?.phase===3&&latest(guest)?.phase===3&&latest(host)?.pose&&latest(guest)?.pose,10000,'both actors');pass('expected authoritative map/mode',latest(host).map===map&&latest(guest).map===map&&latest(guest).mode===mode);await capture(host,'05-host-start');layout(host,'host start');await capture(guest,'06-guest-start');layout(guest,'guest start');
 if(!startup){
  await gameplay(host,'07-host-play');await gameplay(guest,'08-guest-play');
  await cmd(guest,{op:'key',key:'Tab',pressed:true});await wait(()=>latest(guest)?.layout.board.visible,3000,'guest scoreboard');await capture(guest,'09-guest-scoreboard');layout(guest,'guest scoreboard');await cmd(guest,{op:'key',key:'Tab',pressed:false});
  summary.originalGuestPeer=latest(guest).peer;summary.originalGuestActor=latest(guest).actor;
  await leave(guest,'10-guest-active-leave');await wait(()=>wire.some(f=>f.recipient===0&&f.type==='lobby'&&f.players.every(p=>p.peerId!==summary.originalGuestPeer)),4000,'source removes departed guest');pass('authority converts departed actor to bot',wire.some(f=>f.recipient===0&&f.type==='snapshot'&&f.state.actors.some(a=>a.id===summary.originalGuestActor&&a.bot&&a.name.endsWith(' · BOT'))));
  await click(guest,'connect_button');await wait(()=>latest(guest)?.phase===-1||latest(guest)?.phase===3,10000,'active-room join outcome');
  if(latest(guest).phase===-1){pass('active join spectator notice fails closed',latest(guest).error.includes('spectator')&&latest(guest).actor===-1&&!latest(guest).pose&&!latest(guest).room);summary.spectator='UNSUPPORTED in native client: source spectator assignment followed by fatal error notice';await capture(guest,'11-active-rejoin-error');const count=connection;await sleep(1000);pass('active join failure never auto reconnects',connection===count);}
  else{pass('active rejoin remains non-controlling spectator',latest(guest).actor===-1&&!latest(guest).eligible);summary.spectator='supported, observed neutral spectator';await capture(guest,'11-active-rejoin-spectator');await leave(guest,'11b-spectator-leave');}
  pass('source actually assigned spectator',wire.some(f=>f.recipient===2&&f.type==='welcome'&&f.spectate===true));
  await wait(()=>latest(host)?.phase===4,75000,'natural 60s host results');await capture(host,'12-host-results-960x640');layout(host,'results 960x640');
  await cmd(host,{op:'resize',width:1280,height:800});host.width=1280;host.height=800;await wait(()=>latest(host)?.viewport[0]===1280,3000,'actual window resize');await capture(host,'13-host-results-1280x800');layout(host,'results 1280x800');
  await click(guest,'connect_button');await wait(()=>latest(guest)?.phase===11,10000,'explicit post-results guest join');await capture(guest,'14-guest-post-results-wait');const before=wire.filter(f=>f.type==='received'&&f.frame.type==='start').length;await focus(guest);await key(guest,'Enter');await sleep(400);pass('guest cannot restart',wire.filter(f=>f.type==='received'&&f.frame.type==='start').length===before&&!latest(guest).ui.restart_button.visible);
  await click(host,'restart_button');await wait(()=>latest(host)?.revision===2&&latest(guest)?.revision===2&&latest(host)?.pose&&latest(guest)?.pose,10000,'authoritative restart');pass('both restart uncaptured',!latest(host).captured&&!latest(guest).captured);await capture(guest,'15-guest-restarted-uncaptured');
  await gameplay(guest,'16-guest-fresh-recapture');
 }
 await leave(guest,'17-guest-final-active-leave');await leave(host,'18-host-final-active-leave');
 const received=wire.filter(f=>f.type==='received');const guestRecipients=[...new Set(received.filter(f=>f.recipient!==0).map(f=>f.recipient))];for(const r of guestRecipients)pass('guest authority boundary '+r,received.filter(f=>f.recipient===r).every(f=>['join','leave','input'].includes(f.frame.type)));
 if(!startup){const result=wire.find(f=>f.recipient===0&&f.type==='results');pass('natural source clock',result?.state.time>=60&&result.state.time<61);summary.sourceResultsTime=result.state.time;}
 pass('no native script errors',[host,guest].every(p=>!/SCRIPT ERROR|Parse Error|ERROR:/.test(p.text+p.err)));summary.status='PASS';if(summary.spectator?.startsWith('UNSUPPORTED'))summary.status='PASS bounded checks; native active spectator rejoin OPEN';
 }
}catch(e){summary.status='PARTIAL/FAIL';summary.error=e.stack;process.exitCode=1;}
finally{
 clearTimeout(timer);for(const p of children.toReversed()){summary.cleanup.push({name:p.name,...await stopChild(p)});await p.done;if(p.name!=='xvfb'){writeFileSync(resolve(out,p.name+'.stdout.log.gz'),gzipSync(p.text));writeFileSync(resolve(out,p.name+'.stderr.log'),p.err);}}
 if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();summary.serverClosed=!game.server.listening;summary.sockets=game.wss.clients.size;}
 for(const [name,text] of Object.entries({'wire.jsonl':wire.map(f=>JSON.stringify(f)).join('\n')+'\n','actions.jsonl':actions.map(f=>JSON.stringify(f)).join('\n')+'\n','witnesses.jsonl':witnesses.map(f=>JSON.stringify(f)).join('\n')+'\n'})){writeFileSync(resolve(out,name+'.gz'),gzipSync(text));summary[name]={bytes:Buffer.byteLength(text),sha256:createHash('sha256').update(text).digest('hex')};}
 verifyBytes();summary.packageBytesUnchanged=true;summary.nativeErrorLines=children.flatMap(p=>p.err.split('\n').filter(l=>l.includes('ERROR:')).map(text=>({client:p.name,text})));summary.cleanLogs=summary.nativeErrorLines.length===0;
 rmSync(temp,{recursive:true,force:true});summary.tempRemoved=!existsSync(temp);summary.wallMs=Date.now()-began;writeFileSync(resolve(out,'summary.json'),JSON.stringify(summary,null,2)+'\n');console.log(JSON.stringify({...summary,milestones:summary.milestones.map(m=>m.name)},null,2));
}

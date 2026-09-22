// Bounded independent native two-client lobby exercise. Input.parse_input_event
// drives shipped widgets and controls; source hooks observe only, never mutate.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,mkdtempSync,readFileSync,writeFileSync,renameSync,rmSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {gzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../../server/game-server.mjs';
import {verifySource} from '../../../tools/godot-export/semantic.mjs';
import {sleep,until,stopChild} from '../../tools/native_trace_correlation/guest_helpers.mjs';
const binary='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const map=process.argv.includes('--ember')?'ember-crucible':'meridian-exchange';
const mode=map==='ember-crucible'?'rockets':'teamdeathmatch';
const out=resolve('port/reports/multiplayer-lobby-independent',map);
assert.ok(!existsSync(out),'One attempt only; preserve prior evidence');mkdirSync(out);
const temp=mkdtempSync('/tmp/opencode/lobby-live-'),children=[],wire=[],actions=[];
const env={...process.env,HOME:temp,LIBGL_ALWAYS_SOFTWARE:'1',PORT:'0'};
for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']){env[key]=resolve(temp,key);mkdirSync(env[key],{mode:0o700});}
const summary={map,mode,normalRate:true,input:'Godot Input.parse_input_event (engine input, not OS/XTest)',baseline:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),checks:[],cleanup:[]};
let game,deadline,host,guest,expired=false;const began=Date.now();
const pass=(name,value=true)=>{assert.ok(value,name);summary.checks.push(name);};
function spawnOwned(name,cmd,args,options){const p=spawn(cmd,args,options);p.name=name;p.text='';p.err='';p.samples=[];p.done=new Promise((res,rej)=>{p.once('error',rej);p.once('close',res);});children.push(p);if(p.stdout){let buffer='';p.stdout.on('data',b=>{p.text+=b;buffer+=b;let i;while((i=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,i);buffer=buffer.slice(i+1);if(line.startsWith('LOBBY_SAMPLE '))p.samples.push(JSON.parse(line.slice(13)));}if(p.text.length>48*1024*1024)p.kill('SIGTERM');});}p.stderr?.on('data',b=>p.err+=b);return p;}
const latest=p=>p.samples.at(-1);
async function wait(pred,ms,label){await until(()=>{if(expired)throw Error('180s scenario deadline');for(const p of [host,guest])if(p&&p.exitCode!==null)throw Error(`${p.name} exited ${p.exitCode}: ${p.err}`);return pred();},ms,label);}
let commandId=0;
async function cmd(p,c){c={id:++commandId,...c};actions.push({wall:Date.now(),client:p.name,...c});writeFileSync(p.inbox+'.next',JSON.stringify(c));renameSync(p.inbox+'.next',p.inbox);await wait(()=>latest(p)?.command===c.id,3000,'input command '+c.op);}
async function focus(p){await cmd(p,{op:'focus'});await wait(()=>latest(p)?.focused,3000,'engine window focus');}
async function key(p,code){await cmd(p,{op:'key',code,pressed:true});await cmd(p,{op:'key',code,pressed:false});}
async function clickXY(p,x,y){await cmd(p,{op:'mouse',x,y,pressed:true});await cmd(p,{op:'mouse',x,y,pressed:false});}
async function click(p,name){await focus(p);let r=latest(p).ui[name].rect;const overlay=['leave_button','restart_button'].includes(name);for(let n=0;!overlay&&n<8 && (r[1]+r[3]>p.height-25||r[1]<25);n++){await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,button:r[1]<25?4:5,pressed:true});await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,button:r[1]<25?4:5,pressed:false});r=latest(p).ui[name].rect;}assert.ok(r[1]>=(overlay?0:20)&&r[1]+r[3]<=p.height-10,`control in viewport: ${name} ${r}`);await clickXY(p,r[0]+r[2]/2,r[1]+r[3]/2);}
async function capture(p,name){await cmd(p,{op:'capture',name});await wait(()=>existsSync(resolve(out,name+'.png')),3000,'PNG');}
async function fill(p,name,text){await click(p,name);await cmd(p,{op:'key',code:65,pressed:true,ctrl:true});await cmd(p,{op:'key',code:65,pressed:false,ctrl:true});await cmd(p,{op:'text',text});await sleep(text.length*30+200);}
async function gameplay(p){await focus(p);await wait(()=>latest(p)?.eligible,10000,'living actor eligible');await clickXY(p,p.width/2,p.height/2);await wait(()=>latest(p)?.captured,2000,'fresh capture');await cmd(p,{op:'key',code:87,pressed:true});await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,pressed:true});await sleep(1500);await cmd(p,{op:'mouse',x:p.width/2,y:p.height/2,pressed:false});await cmd(p,{op:'key',code:87,pressed:false});await key(p,4194305);}
try{
 const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);summary.source=lock.source_commit;summary.godot=execFileSync(binary,['--version'],{encoding:'utf8'}).trim();assert.equal(summary.godot,lock.godot_version);
 deadline=setTimeout(()=>{expired=true;for(const p of children)p.kill('SIGTERM');},180000);
 const display=spawnOwned('xvfb','Xvfb',['-displayfd','3','-screen','0','2300x900x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
 const displayNumber=await new Promise((res,rej)=>{let text='';const timer=setTimeout(()=>rej(Error('Xvfb startup')),5000);display.stdio[3].on('data',b=>{text+=b;if(text.includes('\n')){clearTimeout(timer);res(text.trim());}});});env.DISPLAY=':'+displayNumber;summary.display=env.DISPLAY;
 game=createGameServer({historyPath:null,progressionPath:null});let connection=0;
 game.wss.on('connection',socket=>{const recipient=connection++;let round=0,peer=null,actor=null;
  socket.on('message',raw=>wire.push({wall:Date.now(),recipient,round,type:'received',frame:JSON.parse(String(raw))}));
  const send=socket.send;socket.send=function(data,...args){const f=JSON.parse(String(data));if(f.type==='welcome')peer=f.peerId;if(f.type==='lobby')actor=f.players.find(p=>p.peerId===peer)?.actorId??null;if(f.type==='start')round++;
   wire.push({wall:Date.now(),recipient,round,...(['snapshot','results'].includes(f.type)?{type:f.type,seq:f.seq,acks:f.acks,actor,state:{mapId:f.state.mapId,config:f.state.config,time:f.state.time,over:f.state.over,teamScores:f.state.teamScores,actors:f.state.actors.map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,health:a.health,dead:a.dead,shots:a.shots,weapon:a.weapon,ammo:a.ammo}))}}:f)});return send.call(this,data,...args);};});
 await new Promise((res,rej)=>{game.server.once('error',rej);game.server.listen(0,'127.0.0.1',res);});summary.port=game.server.address().port;
 function native(name,width,height,position){const inbox=resolve(temp,name+'.json');const p=spawnOwned(name,binary,['--path','godot','--audio-driver','Dummy','--max-fps','60','--resolution',`${width}x${height}`,'--position',position,'--script','res://tests/protocol/lobby_independent_observer.gd','--','--lobby-menu',`--map=${map}`,`--mode=${mode}`,`--endpoint=ws://127.0.0.1:${summary.port}`,`--lobby-inbox=${inbox}`,`--lobby-out=${out}`],{env,stdio:['ignore','pipe','pipe']});Object.assign(p,{inbox,width,height});return p;}
 host=native('host',960,640,'0,0');await wait(()=>latest(host)?.phase===-3,20000,'host menu');await capture(host,'01-host-menu-960x640');
 guest=native('guest',1280,800,'980,0');await wait(()=>latest(guest)?.phase===-3,20000,'guest menu');await capture(guest,'02-guest-menu-1280x800');
 await fill(host,'player_name','Independent Host');await click(host,'connect_button');await wait(()=>latest(host)?.phase===12,10000,'host waiting lobby');summary.room=latest(host).room;pass('host waits for explicit Start',wire.every(f=>f.type!=='start'));await capture(host,'03-host-created');
 await fill(guest,'player_name','Independent Guest');await click(guest,'role');await key(guest,4194322);await key(guest,4194322);await key(guest,4194309);await wait(()=>latest(guest)?.ui.role.text.startsWith('Guest'),3000,'guest role selected');await fill(guest,'room',summary.room);await click(guest,'connect_button');await wait(()=>latest(guest)?.phase===11,10000,'guest joined');await wait(()=>latest(host)?.roster.includes('Independent Guest'),4000,'authoritative two-human roster');await capture(guest,'04-guest-roster');
 await click(guest,'back_button');await wait(()=>latest(guest)?.phase===-3,4000,'guest explicit Leave');pass('Leave clears identity/pose/entities',latest(guest).actor===-1&&!latest(guest).pose&&latest(guest).actors===0&&latest(guest).pickups===0&&!latest(guest).room);const connectionsAfterLeave=connection;await sleep(1000);pass('no automatic reconnect during disconnected observation',connection===connectionsAfterLeave);await capture(guest,'05-guest-left');
 await click(guest,'connect_button');await wait(()=>latest(guest)?.phase===11,10000,'guest explicit rejoin');await click(host,'start_button');await wait(()=>latest(host)?.phase===3&&latest(guest)?.phase===3&&latest(host)?.pose&&latest(guest)?.pose,10000,'two live actors');await capture(host,'06-host-start');
 await gameplay(host);await capture(host,'07-host-gameplay');await gameplay(guest);await capture(guest,'08-guest-gameplay');
 await wait(()=>latest(host)?.phase===4&&latest(guest)?.phase===4,75000,'natural 60s results');await capture(host,'09-host-results');await capture(guest,'10-guest-results');pass('results release both pointers',!latest(host).captured&&!latest(guest).captured);
 const starts=wire.filter(f=>f.type==='start').length;await focus(guest);await key(guest,4194309);await sleep(500);pass('guest Enter cannot restart',wire.filter(f=>f.type==='start').length===starts&&latest(guest).phase===4);pass('guest restart button hidden',!latest(guest).ui.restart_button.visible);
 await click(host,'restart_button');await wait(()=>latest(host)?.starts===2&&latest(guest)?.starts===2&&latest(host)?.pose&&latest(guest)?.pose,10000,'host-only restart');pass('restart requires new capture',!latest(host).captured&&!latest(guest).captured);await capture(host,'11-host-restarted');await gameplay(host);await capture(host,'12-host-fresh-capture');
 await click(host,'leave_button');await wait(()=>latest(host)?.phase===-3,4000,'host gameplay Leave');pass('active Leave clears local gameplay state',latest(host).actors===0&&latest(host).pickups===0&&!latest(host).pose&&latest(host).actor===-1);await capture(host,'13-host-left');
 const received=wire.filter(f=>f.type==='received');for(const r of [1,2])pass(`guest connection ${r} authority boundary`,received.filter(f=>f.recipient===r).every(f=>['join','leave','input'].includes(f.frame.type)));
 const results=wire.filter(f=>f.type==='results');pass('natural source time 60s',results.length===2&&results.every(f=>f.state.time>=60&&f.state.time<61));
 for(const [name,r,p] of [['host',0,host],['guest',2,guest]]){
  const inputs=received.filter(f=>f.recipient===r&&f.round===1&&f.frame.type==='input');pass(name+' movement/fire received',inputs.some(f=>f.frame.input.fire&&(Math.abs(f.frame.input.x)+Math.abs(f.frame.input.z)>0)));
  const snaps=wire.filter(f=>f.recipient===r&&f.round===1&&f.type==='snapshot');const actors=snaps.map(f=>f.state.actors.find(a=>a.id===f.actor)).filter(Boolean);
  pass(name+' source actual movement',actors.some(a=>Math.hypot(a.x-actors[0].x,a.z-actors[0].z)>.5));pass(name+' source actual shots',actors.some(a=>a.shots>0));
  const applied=p.text.split('\n').filter(l=>l.startsWith('LOBBY_APPLIED ')).map(l=>JSON.parse(l.slice(14))).filter(f=>f.round===1);
  let matches=0;for(const f of applied){const s=snaps.find(s=>s.seq===f.seq);const a=s?.state.actors.find(a=>a.id===f.actor);if(a&&a.x===f.local.x&&a.z===f.local.z&&a.shots===f.local.shots)matches++;}
  pass(name+' native applied source poses/shots',matches>10&&applied.some(f=>f.local.shots>0));summary[name]={receivedInputs:inputs.length,sourceSnapshots:snaps.length,appliedMatches:matches,maxAck:Math.max(...snaps.map(s=>s.acks?.[s.actor]??0)),maxShots:Math.max(...actors.map(a=>a.shots??0))};
 }
 summary.status='PASS';
}catch(e){summary.status='PARTIAL/FAIL';summary.error=e.stack;process.exitCode=1;}
finally{
 clearTimeout(deadline);for(const p of children.toReversed()){summary.cleanup.push({name:p.name,...await stopChild(p)});await p.done;if(p.name!=='xvfb'){writeFileSync(resolve(out,p.name+'.stdout.log.gz'),gzipSync(p.text));writeFileSync(resolve(out,p.name+'.stderr.log'),p.err);}}
 if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();summary.serverClosed=!game.server.listening;summary.sockets=game.wss.clients.size;}
 for(const [name,text] of Object.entries({'wire.jsonl':wire.map(f=>JSON.stringify(f)).join('\n')+'\n','actions.jsonl':actions.map(f=>JSON.stringify(f)).join('\n')+'\n'})){writeFileSync(resolve(out,name+'.gz'),gzipSync(text));summary[name]={bytes:Buffer.byteLength(text),sha256:createHash('sha256').update(text).digest('hex')};}
 rmSync(temp,{recursive:true,force:true});summary.tempRemoved=!existsSync(temp);summary.wallMs=Date.now()-began;writeFileSync(resolve(out,'summary.json'),JSON.stringify(summary,null,2)+'\n');console.log(JSON.stringify(summary,null,2));
}

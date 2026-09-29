// Scripted native UI observer plus an external source host. No room tokens,
// credential fields, raw wire frames, or identity hashes enter output.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,writeFileSync,renameSync,existsSync,rmSync,readFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import WebSocket from 'ws';
import {createGameServer} from '../../server/game-server.mjs';

const binary=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const temp=mkdtempSync('/tmp/opencode/native-reconnect-ui-');
const evidence=resolve(process.env.COCS_RECONNECT_EVIDENCE??`/tmp/opencode/native-reconnect-evidence-${process.pid}`);
assert.ok(!existsSync(evidence),'Preserve existing evidence directory');
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));
const summary={port_commit:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),source_commit:lock.source_commit,
 derivative_commit:process.env.COCS_SOURCE_DERIVATIVE?JSON.parse(readFileSync(process.env.COCS_SOURCE_DERIVATIVE)).derivative_commit:null,
 engine:execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),checks:[],status:'RUNNING',scope:'scripted native GUI and real source; not human acceptance'};
assert.equal(summary.engine,lock.godot_version,'pinned engine');
const env={...process.env,HOME:temp,LIBGL_ALWAYS_SOFTWARE:'1',COCS_CAREER_ROOT:resolve(temp,'career'),COCS_CAREER_CREDENTIALS_PATH:'',COCS_CAREER_SCOPE:'',COCS_CAREER_ENDPOINT:''};
for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']){env[key]=resolve(temp,key);mkdirSync(env[key],{recursive:true,mode:0o700});}
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,ms,label){const end=Date.now()+ms;while(Date.now()<end){const value=predicate();if(value)return value;await sleep(60);}throw Error(`timeout: ${label}`);}
function check(label,value){assert.ok(value,label);summary.checks.push(label);}
let xvfb,native,host,game,timeout=false,guestSocket=null,commandId=0,output='',samples=[],lastCommand=-1,received=[];
const inbox=resolve(temp,'command.json'),shot=resolve(temp,'disconnected.png');
const timer=setTimeout(()=>{timeout=true;native?.kill('SIGKILL');xvfb?.kill('SIGKILL');},105000);
try {
 xvfb=spawn('Xvfb',['-displayfd','3','-screen','0','1600x900x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
 const display=await new Promise((resolveDisplay,reject)=>{let text='';const deadline=setTimeout(()=>reject(Error('Xvfb startup')),5000);xvfb.stdio[3].on('data',data=>{text+=data;if(text.includes('\n')){clearTimeout(deadline);resolveDisplay(text.trim());}});xvfb.on('error',reject);});
 env.DISPLAY=':'+display;
 game=createGameServer({graceMs:20000,progressionPath:resolve(temp,'progression.json')});
 game.wss.on('connection',socket=>{
  socket.on('message',raw=>{try{const frame=JSON.parse(String(raw));if(frame.type==='join'&&frame.roomId===room)guestSocket=socket;}catch{}});
 });
 await new Promise(resolveListen=>game.server.listen(0,'127.0.0.1',resolveListen));
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 host=new WebSocket(endpoint);
 host.on('message',data=>{try{const frame=JSON.parse(String(data));if(['welcome','lobby','start','snapshot'].includes(frame.type))received.push(frame);}catch{}});
 await new Promise((res,rej)=>{host.once('open',res);host.once('error',rej);});
 host.send(JSON.stringify({type:'create',name:'Reconnect fixture',playerName:'Host',character:'chatgpt',harness:'openclaw',v:3,delta:0}));
 const welcome=await until(()=>received.find(f=>f.type==='welcome'),5000,'host welcome');
 const room=welcome.roomId;
 host.send(JSON.stringify({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0,timeLimit:60}}));
 await until(()=>received.find(f=>f.type==='lobby'&&f.config?.mode==='deathmatch'),5000,'host config');
 native=spawn(binary,['--path','godot','--audio-driver','Dummy','--max-fps','60','--resolution','960x640','--script','res://tests/protocol/reconnect_observer.gd','--','--lobby-menu',`--endpoint=${endpoint}`,'--map=meridian-exchange',`--reconnect-inbox=${inbox}`,`--reconnect-shot=${shot}`],{env,stdio:['ignore','pipe','pipe']});
 let buffer='';
 native.stdout.on('data',data=>{output=(output+data.toString()).slice(-200000);buffer+=data.toString();let index;while((index=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,index);buffer=buffer.slice(index+1);if(line.startsWith('RECONNECT_SAMPLE ')){try{samples.push(JSON.parse(line.slice(17)));if(samples.length>800)samples.shift();}catch{}}}});
 native.stderr.on('data',data=>{output=(output+data.toString()).slice(-200000);});
 const latest=()=>samples.at(-1);
 async function command(op,fields={}){const record={id:++commandId,op,...fields};writeFileSync(inbox+'.next',JSON.stringify(record));renameSync(inbox+'.next',inbox);await until(()=>latest()?.command===record.id,4000,`command ${op}`);}
 async function click(name){await command('click',{name});}
 await until(()=>latest()?.phase===-3,30000,'native menu');
 await command('setup_guest',{room});
 await click('connect_button');
 await until(()=>latest()?.phase===11&&latest()?.room_seated,15000,'native guest lobby');
 check('guest joined as a player',latest().actor===-1&&latest().profile_present);
 host.send(JSON.stringify({type:'start'}));
 await until(()=>latest()?.phase===3&&latest()?.pose&&latest()?.ack>0,15000,'native live guest');
 await until(()=>guestSocket,5000,'guest source socket');
 const before=latest();
 check('source round revision observed',before.revision>0&&before.actor>=0&&before.seq>0);
 await command('scale',{value:1.5});
 await command('resize',{width:960,height:640});
 guestSocket.terminate(); // Authority-controlled genuine transport loss.
 await until(()=>latest()?.phase===-5,5000,'visible disconnected route');
 const dropped=latest(),view=dropped.viewport;
 for(const name of ['reconnect_button','back_button']){
  const item=dropped.controls[name], [x,y,w,h]=item.rect;
  check(`${name} visible and fits 960x640 @150%`,item.visible&&x>=-1&&y>=-1&&x+w<=view[0]+1&&y+h<=view[1]+1);
 }
 check('pointer released and source cache cleared on drop',!dropped.pointer&&!dropped.pose&&dropped.chat_count===0&&dropped.chat_draft===0);
 await command('capture');
 await until(()=>existsSync(shot),3000,'disconnected screenshot');
 check('disconnected native screen captured',existsSync(shot));
 guestSocket=null;
 await click('reconnect_button');
 await until(()=>latest()?.phase===3&&latest()?.pose&&latest()?.ack>before.ack,10000,'resumed guest and fresh ACK');
 const after=latest();
 check('same actor and revision with monotonic native sequence',after.actor===before.actor&&after.revision===before.revision&&after.seq>before.seq);
 check('source career identity stable and pointer not recaptured',after.profile_stable&&!after.pointer);
 check('host authority remains live',game.registry.get(room)?.roundOver===false&&host.readyState===WebSocket.OPEN);
 // Drop again, then use the actual Leave button instead of calling session.
 await until(()=>guestSocket,5000,'new source guest socket');
 guestSocket.terminate();
 await until(()=>latest()?.phase===-5,5000,'second disconnected route');
 await click('back_button');
 await until(()=>latest()?.phase===-3&&!latest()?.ticket,5000,'explicit Leave');
 check('Leave forgets reconnect ticket',!latest().ticket);
 check('external host still running',game.registry.get(room)?.roundOver===false&&host.readyState===WebSocket.OPEN);
 if(timeout||/SCRIPT ERROR|ERROR:|Parse Error|Assertion failed/i.test(output))throw Error('native observer emitted an engine diagnostic');
 summary.status='PASS';
 console.log(`PORT_RECONNECT_RENDERED_OK checks=${summary.checks.length} scripted_ui=true`);
} catch (error) {
 summary.status='FAIL';
 summary.failure='Native journey failed; see named check or timeout in runner output.';
 throw error;
} finally {
 clearTimeout(timer);
 native?.kill('SIGKILL');
 host?.terminate();
 await game?.close();
 xvfb?.kill('SIGKILL');
 mkdirSync(evidence,{recursive:true});
 writeFileSync(resolve(evidence,'summary.json'),JSON.stringify(summary,null,2));
 if(existsSync(shot))writeFileSync(resolve(evidence,'disconnected.png'),readFileSync(shot));
 console.log(`RECONNECT_EVIDENCE ${evidence}`);
 rmSync(temp,{recursive:true,force:true});
}

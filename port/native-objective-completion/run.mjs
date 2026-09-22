import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
import {opposingPeer} from './peer.mjs';
import {validate} from './validate.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,mkdtempSync,rmSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomUUID,createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
const args=process.argv.slice(2),map='sunscar-convoy';
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;
if(!binary||execFileSync(binary,['--version'],{encoding:'utf8',timeout:5000}).trim()!==lock.godot_version)throw Error('Pinned GODOT_BIN required');
const seconds=180,deadline=235000;
const out=resolve('port/native-objective-completion/evidence',randomUUID());mkdirSync(out,{recursive:true});
const temp=mkdtempSync('/tmp/opencode/objective-completion-runtime-');
const env={...process.env};for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=resolve(temp,key);mkdirSync(env[key]);}
const files=['godot/objectives/demo.gd','godot/objectives/renderer.gd','godot/objectives/hud.gd','godot/tests/objectives/completion_live.gd','godot/world/session.gd','godot/net/client.gd','game/core.mjs','game/payload.mjs','game/objectives.mjs','game/destination-objective-maps.mjs','server/room.mjs','server/game-server.mjs','port/native-objective-completion/run.mjs','port/native-objective-completion/peer.mjs','port/native-objective-completion/validate.mjs'];
const runtimeHashes=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(readFileSync(p)).digest('hex')]));
let game,child,guest,timer,exit=1,reason='not started',stdout='',stderr='',wire=[],bytes=0,connection=0;
const children=[];
function witness(record){const line=JSON.stringify({wall:Date.now(),...record});bytes+=line.length;if(bytes>96*1024*1024)throw Error('Evidence cap');wire.push(line);}
function tracked(cmd,argv,options){const p=spawn(cmd,argv,options);children.push(p);p.completion=new Promise((r,j)=>{p.once('error',j);p.once('exit',(code,signal)=>r({code,signal}));});return p;}
async function terminate(p){if(p.exitCode===null&&p.signalCode===null){p.kill('SIGTERM');const k=setTimeout(()=>p.kill('SIGKILL'),3000);await p.completion;clearTimeout(k);}}
const stop=()=>{reason='interrupted';if(child)void terminate(child);};process.on('SIGINT',stop);process.on('SIGTERM',stop);
try{
 const display=tracked('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
 const number=await Promise.race([new Promise((res,rej)=>{let text='';display.stdio[3].on('data',b=>{text+=b;if(text.includes('\n'))/^\d+\n$/.test(text)?res(text.trim()):rej(Error('Invalid display'));});}),display.completion.then(()=>{throw Error('Display failed');}),new Promise((_,rej)=>{const t=setTimeout(()=>rej(Error('Display deadline')),5000);t.unref();})]);
 env.DISPLAY=':'+number;
 game=createGameServer({historyPath:null,progressionPath:null});
 game.wss.on('connection',socket=>{
  const id=connection++;let round=0;
  const send=socket.send;socket.send=function(data,...rest){
   const f=JSON.parse(String(data));
   if(f.type==='start')round++;
   if(f.type==='welcome'&&id===0)queueMicrotask(()=>{guest=opposingPeer(endpoint,f.roomId,map,witness);});
   if(['welcome','lobby','start','results','events'].includes(f.type))witness({connection:id,round,...(f.type==='results'?{type:f.type,state:compact(f.state)}:f)});
   if(f.type==='snapshot')witness({connection:id,round,type:f.type,seq:f.seq,acks:f.acks,state:compact(f.state)});
   return send.call(this,data,...rest);
  };
  socket.on('message',data=>{const f=JSON.parse(String(data));witness({type:'received',connection:id,round,frame:f});});
 });
 await new Promise((res,rej)=>{game.server.once('error',rej);game.server.listen(0,'127.0.0.1',res);});
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 const response=await fetch(endpoint.replace('ws:','http:'),{signal:AbortSignal.timeout(5000)});if(!response.ok)throw Error('Readiness failed');
 const argv=['--audio-driver','Dummy','--resolution',args.includes('--small')?'960x640':'1280x800','--path','godot','res://tests/objectives/completion_live.tscn','--',`--map=${map}`,`--endpoint=${endpoint}`,'--objective-evidence','--objective-peer',`--round-seconds=${seconds}`,`--screenshot=${out}/gameplay.png`];
 writeFileSync(resolve(out,'launch.json'),JSON.stringify({binary,version:lock.godot_version,binarySHA256:createHash('sha256').update(readFileSync(binary)).digest('hex'),argv,display:env.DISPLAY,command:process.argv,cwd:process.cwd(),base:'ffa6aac0bc4a61a0b5e1721dbb4000066c22a474'},null,2));
 child=tracked(binary,argv,{env,stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',b=>{stdout+=b;if(stdout.length>48*1024*1024){reason='stdout cap';child.kill('SIGTERM');}});child.stderr.on('data',b=>stderr+=b);
 reason='running';timer=setTimeout(()=>{reason='outer deadline';void terminate(child);},deadline);
 const result=await child.completion;clearTimeout(timer);
 if(result.code===0&&!/SCRIPT ERROR|Parse Error|ERROR:/.test(stdout+stderr)){
  const validation=validate(wire.map(JSON.parse),stdout,map,seconds);
  writeFileSync(resolve(out,'validation.json'),JSON.stringify(validation,null,2));exit=0;reason='source-correlated completion passed';
 }else if(reason==='running')reason='native attempt failed';
}catch(error){reason=error.stack;exit=1;}
finally{
 clearTimeout(timer);guest?.terminate();
 for(const p of [...children].reverse())await terminate(p);
 if(game){for(const s of game.wss.clients)s.terminate();await game.close();}
 const logs={'wire.jsonl':wire.join('\n')+'\n','native.stdout.log':stdout,'native.stderr.log':stderr};
 const archive={};for(const [name,text]of Object.entries(logs)){const raw=Buffer.from(text);writeFileSync(resolve(out,name+'.gz'),gzipSync(raw));archive[name]={bytes:raw.length,sha256:createHash('sha256').update(raw).digest('hex')};}
 writeFileSync(resolve(out,'archive.json'),JSON.stringify(archive,null,2));
 rmSync(temp,{recursive:true,force:true});
 const cleanup=children.map(p=>{let absent=false;try{process.kill(p.pid,0);}catch(e){absent=e.code==='ESRCH';}return{pid:p.pid,reaped:p.exitCode!==null||p.signalCode!==null,absent};});
 if(cleanup.some(p=>!p.absent||!p.reaped)||game?.server.listening||game?.wss.clients.size||existsSync(temp))exit=1;
 writeFileSync(resolve(out,'summary.json'),JSON.stringify({map,seconds,deadline,base:'ffa6aac',source:lock.source_commit,runtimeHashes,exit,reason,normalRate:true,nativeCompletionProven:false,cleanup,serverClosed:!game?.server.listening,sockets:game?.wss.clients.size??0,temporaryTreeRemoved:!existsSync(temp)},null,2));
 console.log(JSON.stringify({exit,reason,evidence:out,cleanup}));process.exitCode=exit;
 process.off('SIGINT',stop);process.off('SIGTERM',stop);
}
function compact(s){return{config:s.config,mapId:s.mapId,time:s.time,over:s.over,winner:s.winner,actors:s.actors.map(a=>({id:a.id,team:a.team,x:a.x,y:a.y,z:a.z,health:a.health,carryingFlag:a.carryingFlag})),flags:s.flags,objectives:s.objectives,teamScores:s.teamScores};}

import {validate} from './validate.mjs';
import {createGameServer} from '../../../server/game-server.mjs';
import {verifySource} from '../../../tools/godot-export/semantic.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,mkdtempSync,rmSync,createWriteStream,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomUUID,createHash} from 'node:crypto';
import {once} from 'node:events';
const args=process.argv.slice(2), map=args.find(x=>x.startsWith('--map='))?.slice(6);
const pairs={'tidal-citadel':'ctf','sunscar-convoy':'payload'};
const catalog=JSON.parse(readFileSync('port/contracts/map-selection.json'));
if(!pairs[map] || !catalog.maps.find(x=>x.id===map)?.supported_modes.includes(pairs[map])) throw Error('Choose --map=tidal-citadel or --map=sunscar-convoy');
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;
if(!binary || execFileSync(binary,['--version'],{encoding:'utf8',timeout:5000}).trim()!==lock.godot_version) throw Error('Pinned GODOT_BIN required');
const acceptance=args.includes('--acceptance');
const deadline=Number(args.find(x=>x.startsWith('--timeout-ms='))?.split('=')[1]??180000);
if(!Number.isInteger(deadline)||deadline<100||deadline>180000)throw Error('timeout-ms must be 100..180000; outer harness deadline only');
const runtimeHashes=Object.fromEntries(['godot/objectives/demo.gd','godot/objectives/renderer.gd','godot/tests/objectives/live.gd','godot/world/session.gd','godot/world/viewer.gd','godot/world/presentation.gd','godot/net/client.gd','game/core.mjs','game/payload.mjs'].map(p=>[p,createHash('sha256').update(readFileSync(p)).digest('hex')]));
const out=resolve('port/native-objective-gameplay/evidence',randomUUID());mkdirSync(out,{recursive:true});
const temp=mkdtempSync('/tmp/opencode/objective-runtime-');
const env={...process.env};for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {env[key]=resolve(temp,key);mkdirSync(env[key]);}
const children=[];let game,child,display,timer,exit=1,reason='not started';
const stream=createWriteStream(resolve(out,'wire.jsonl'),{flags:'wx'});
let snapshots=0,inputs=0,bytes=0;
function witness(record){const line=JSON.stringify(record)+'\n';bytes+=Buffer.byteLength(line);if(bytes>24*1024*1024){reason='evidence limit';child?.kill('SIGTERM');return;}stream.write(line);}
function tracked(command,argv,options){const p=spawn(command,argv,options);children.push(p);p.completion=new Promise((r,j)=>{p.once('error',j);p.once('exit',(code,signal)=>r({code,signal}));});return p;}
async function terminate(p){if(p.exitCode===null && p.signalCode===null){p.kill('SIGTERM');const kill=setTimeout(()=>p.kill('SIGKILL'),3000);await p.completion;clearTimeout(kill);}}
const stop=()=>{reason='interrupted';if(child)void terminate(child);};process.on('SIGINT',stop);process.on('SIGTERM',stop);
try{
 if(acceptance){
  display=tracked('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
  let error='';display.stderr.on('data',b=>error+=b);
  const number=await Promise.race([new Promise((res,rej)=>{let text='';display.stdio[3].on('data',b=>{text+=b;if(text.includes('\n'))/^\d+\n$/.test(text)?res(text.trim()):rej(Error('Invalid display response'));});}),display.completion.then(()=>{throw Error('Display startup failed: '+error);}),new Promise((_,rej)=>{const t=setTimeout(()=>rej(Error('Display deadline')),5000);t.unref();})]);
  env.DISPLAY=':'+number;
 }
 game=createGameServer({historyPath:null,progressionPath:null});
 game.wss.on('connection',socket=>{
  const send=socket.send;socket.send=function(data,...rest){const f=JSON.parse(String(data));if(f.type==='snapshot'){snapshots++;witness({type:'snapshot',seq:f.seq,acks:f.acks,state:{config:f.state.config,time:f.state.time,actors:f.state.actors.map(a=>({id:a.id,team:a.team,x:a.x,y:a.y,z:a.z,carryingFlag:a.carryingFlag})),flags:f.state.flags,objectives:f.state.objectives,teamScores:f.state.teamScores}});}else if(f.type==='events')witness({type:f.type,items:f.items});else if(f.type==='start')witness({type:f.type,mapId:f.mapId});return send.call(this,data,...rest);};
  socket.on('message',data=>{const f=JSON.parse(String(data));if(f.type==='input'){inputs++;witness({type:'input_received',seq:f.seq,input:f.input});}});
 });
 await new Promise((res,rej)=>{game.server.once('error',rej);game.server.listen(0,'127.0.0.1',res);});
 const port=game.server.address().port;
 const response=await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)});if(!response.ok)throw Error('Readiness failed');
 const scene=acceptance?'res://tests/objectives/live.tscn':'res://objectives/demo.tscn';
 child=tracked(binary,['--audio-driver','Dummy','--resolution',args.includes('--small')?'960x640':'1280x800','--path','godot',scene,'--',`--map=${map}`,`--endpoint=ws://127.0.0.1:${port}`,...(acceptance?['--objective-evidence',`--screenshot=${out}/gameplay.png`]:[])],{env,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='';child.stdout.on('data',b=>{stdout+=b;if(stdout.length>24*1024*1024){reason='stdout limit';child.kill('SIGTERM');}});child.stderr.on('data',b=>stderr+=b);
 reason='running';timer=setTimeout(()=>{reason='outer deadline';void terminate(child);},deadline);
 const result=await child.completion;clearTimeout(timer);
 writeFileSync(resolve(out,'native.stdout.log'),stdout);writeFileSync(resolve(out,'native.stderr.log'),stderr);
 exit=result.code===0 && !/SCRIPT ERROR|Parse Error|ERROR:/.test(stdout+stderr) && (!acceptance || stdout.includes('OBJECTIVE_ATTEMPT_OK'))?0:1;
 if(reason==='running')reason=exit===0?'bounded observation passed':'native attempt failed';
}catch(error){reason=error.message;exit=1;}
finally{
 clearTimeout(timer);
 for(const p of [...children].reverse())await terminate(p);
 if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();}
 stream.end();await once(stream,'finish');
 if(acceptance && exit===0){try{
  const wire=readFileSync(resolve(out,'wire.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
  const native=readFileSync(resolve(out,'native.stdout.log'),'utf8').split('\n').filter(x=>x.startsWith('OBJECTIVE_NATIVE ')).map(x=>JSON.parse(x.slice('OBJECTIVE_NATIVE '.length)));
  writeFileSync(resolve(out,'validation.json'),JSON.stringify(validate(wire,native,map),null,2));
 }catch(error){exit=1;reason='Correlation failed: '+error.message;}}
 rmSync(temp,{recursive:true,force:true});
 const cleanup=children.map(p=>{let absent=false;try{process.kill(p.pid,0);}catch(e){absent=e.code==='ESRCH';}return {pid:p.pid,reaped:p.exitCode!==null||p.signalCode!==null,absent};});
 if(cleanup.some(p=>!p.absent||!p.reaped)||game?.server.listening||game?.wss.clients.size||existsSync(temp))exit=1;
 writeFileSync(resolve(out,'summary.json'),JSON.stringify({map,runtimeHashes,deadline,base:'8e91969ca0d55938c25198c34ff158dd7195be20',source:catalog.source_commit,acceptance,exit,reason,snapshots,inputs,normalRate:true,nativeCompletionProven:false,cleanup,serverClosed:!game?.server.listening,temporaryTreeRemoved:!existsSync(temp),sockets:game?.wss.clients.size??0},null,2));
 console.log(JSON.stringify({exit,reason,evidence:out,cleanup}));process.exitCode=exit;
 process.off('SIGINT',stop);process.off('SIGTERM',stop);
}

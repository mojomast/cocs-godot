import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,mkdtempSync,rmSync,existsSync,readdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomUUID,createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {connect} from 'node:net';
const sha=b=>createHash('sha256').update(b).digest('hex');
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;
if(!binary||execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version)throw Error('Pinned Godot required');
const size=process.argv.includes('--small')?'960x640':'1280x800';
const out=resolve('port/native-payload-guidance/evidence',randomUUID());mkdirSync(out,{recursive:true});
const temp=mkdtempSync('/tmp/opencode/payload-guidance-runtime-');
const env={...process.env,PORT:'0'};
for(const k of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
// Hash every runtime script/resource plus the complete locked source set.
const files=execFileSync('git',['ls-files','game','server','godot','port/contracts','tools/godot-export'],{encoding:'utf8'}).trim().split('\n');
for(const dir of ['godot/objectives','godot/tests/objectives','port/native-payload-guidance'])for(const name of readdirSync(dir))if(/\.(gd|tscn|mjs)$/.test(name))files.push(`${dir}/${name}`);
const hashes=Object.fromEntries([...new Set(files)].filter(f=>existsSync(f)).map(f=>[f,sha(readFileSync(f))]));
let game,child,timer,port,stdout='',stderr='',wire=[],reason='not started',exit=1;
const children=[],start=Date.now();
function tracked(command,args,options){const p=spawn(command,args,options);children.push(p);p.done=new Promise((r,j)=>{p.once('error',j);p.once('exit',(code,signal)=>r({code,signal}));});return p;}
async function terminate(p){if(p.exitCode===null&&p.signalCode===null){p.kill('SIGTERM');const t=setTimeout(()=>p.kill('SIGKILL'),3000);await p.done;clearTimeout(t);}}
const interrupt=()=>{reason='interrupted';if(child)void terminate(child);};process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
try{
 const xv=tracked('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
 xv.stderr.on('data',b=>stderr+=b);
 const display=await Promise.race([new Promise(r=>{let s='';xv.stdio[3].on('data',b=>{s+=b;if(/^\d+\n$/.test(s))r(s.trim());});}),xv.done.then(()=>{throw Error('Xvfb exited');}),new Promise((_,j)=>{const t=setTimeout(()=>j(Error('Xvfb timeout')),5000);t.unref();})]);
 env.DISPLAY=':'+display;
 game=createGameServer({historyPath:null,progressionPath:null});
 game.wss.on('connection',socket=>{
  const send=socket.send;socket.send=function(data,...rest){const f=JSON.parse(String(data));if(['snapshot','events','results','start'].includes(f.type))wire.push({wall:Date.now(),...f});return send.call(this,data,...rest);};
  socket.on('message',data=>wire.push({wall:Date.now(),type:'received',frame:JSON.parse(String(data))}));
 });
 await new Promise((r,j)=>{game.server.once('error',j);game.server.listen(0,'127.0.0.1',r);});port=game.server.address().port;
 const args=['--audio-driver','Dummy','--resolution',size,'--path','godot','res://tests/objectives/guidance_live.tscn','--','--map=sunscar-convoy',`--endpoint=ws://127.0.0.1:${port}`,'--objective-evidence',`--screenshot=${out}/guidance.png`];
 writeFileSync(resolve(out,'launch.json'),JSON.stringify({binary,binarySHA256:sha(readFileSync(binary)),version:lock.godot_version,args,display:env.DISPLAY,port,size,revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),source:lock.source_commit,hashes},null,2));
 child=tracked(binary,args,{env,stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',b=>{stdout+=b;if(stdout.length>32*1024*1024)void terminate(child);});child.stderr.on('data',b=>stderr+=b);
 timer=setTimeout(()=>{reason='115s deadline';void terminate(child);},Math.max(1,115000-(Date.now()-start)));
 const result=await child.done;
 const done=stdout.split('\n').filter(x=>x.startsWith('GUIDANCE_DONE ')).map(x=>JSON.parse(x.slice(14)));
 if(result.code===0&&!/SCRIPT ERROR|Parse Error|ERROR:/.test(stdout+stderr)&&done.length===1&&done[0].ok&&done[0].controls_released){exit=0;reason='observation complete';}
 else reason='native observation failed';
}catch(e){reason=e.stack;}
finally{
 clearTimeout(timer);for(const p of [...children].reverse())await terminate(p);
 if(game){for(const s of game.wss.clients)s.terminate();await game.close();}
 const archive={};for(const [name,text]of Object.entries({'wire.jsonl':wire.map(x=>JSON.stringify(x)).join('\n')+'\n','native.stdout.log':stdout,'native.stderr.log':stderr})){const raw=Buffer.from(text);writeFileSync(resolve(out,name+'.gz'),gzipSync(raw));archive[name]={bytes:raw.length,sha256:sha(raw)};}
 writeFileSync(resolve(out,'archive.json'),JSON.stringify(archive,null,2));
 rmSync(temp,{recursive:true,force:true});
 const cleanup=children.map(p=>{let absent=false;try{process.kill(p.pid,0);}catch(e){absent=e.code==='ESRCH';}return {pid:p.pid,absent,reaped:p.exitCode!==null||p.signalCode!==null};});
 const portClosed=port?await new Promise(r=>{const s=connect(port,'127.0.0.1');s.once('connect',()=>{s.destroy();r(false);});s.once('error',()=>r(true));}):null;
 if(cleanup.some(p=>!p.absent||!p.reaped)||!portClosed||existsSync(temp))exit=1;
 writeFileSync(resolve(out,'summary.json'),JSON.stringify({exit,reason,elapsed:(Date.now()-start)/1000,deadline:115,normalRate:true,cleanup,port,portClosed,serverClosed:!game?.server.listening,sockets:game?.wss.clients.size??0,temporaryTreeRemoved:!existsSync(temp)},null,2));
 console.log(JSON.stringify({out,exit,reason}));process.exitCode=exit;
 process.off('SIGINT',interrupt);process.off('SIGTERM',interrupt);
}

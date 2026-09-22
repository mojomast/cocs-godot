// Owned-process/evidence lifecycle adapted from native-objective-completion/run.mjs.
import {createAuthority,MAPS} from './authority.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync,mkdtempSync,rmSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomUUID,createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
const args=process.argv.slice(2),option=(k,d)=>args.find(x=>x.startsWith(k+'='))?.slice(k.length+1)??d;
const map=option('--map','meridian-exchange'),scenario=option('--scenario','startup'),manual=args.includes('--manual');
if(!MAPS.includes(map)||!['startup','combat','death'].includes(scenario))throw Error('Invalid map/scenario');
const binary=process.env.GODOT_BIN,lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));
if(!binary||execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version)throw Error('Pinned GODOT_BIN required');
const out=resolve('port/native-horde/evidence',randomUUID());mkdirSync(out,{recursive:true});
const temp=mkdtempSync('/tmp/opencode/horde-runtime-'),env={...process.env};
for(const k of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']){env[k]=resolve(temp,k);mkdirSync(env[k],{mode:0o700});}
const children=[];let game,child,timer,stdout='',stderr='',wire=[],bytes=0,reason='setup',exit=1;
function tracked(cmd,argv,opts){const p=spawn(cmd,argv,opts);children.push(p);p.done=new Promise((r,j)=>{p.once('error',j);p.once('exit',(code,signal)=>r({code,signal}));});return p;}
async function stop(p){if(p.exitCode===null&&p.signalCode===null){p.kill('SIGTERM');const t=setTimeout(()=>p.kill('SIGKILL'),2500);await p.done;clearTimeout(t);}}
const interrupted=()=>{reason='interrupted';if(child)void stop(child);};process.on('SIGTERM',interrupted);process.on('SIGINT',interrupted);
try{
 if(!manual){
  const display=tracked('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
  const number=await Promise.race([new Promise(r=>{let s='';display.stdio[3].on('data',b=>{s+=b;if(/^\d+\n$/.test(s))r(s.trim());});}),display.done.then(()=>{throw Error('Xvfb exited');}),new Promise((_,j)=>{const t=setTimeout(()=>j(Error('display timeout')),5000);t.unref();})]);env.DISPLAY=':'+number;
 }
 game=createAuthority({observe(record){if(manual)return;const s=JSON.stringify(record);bytes+=s.length;if(bytes>64*1024*1024){reason='evidence cap';void stop(child);return;}wire.push(s);}});
 await new Promise((r,j)=>{game.server.once('error',j);game.server.listen(0,'127.0.0.1',r);});
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 if(!(await fetch(endpoint.replace('ws:','http:'))).ok)throw Error('readiness failed');
 const argv=[...(manual?[]:['--audio-driver','Dummy']),'--resolution',option('--resolution','1280x800'),'--path','godot',manual?'res://horde/demo.tscn':'res://tests/horde/live.tscn','--',`--map=${map}`,`--endpoint=${endpoint}`,`--waves=${manual?option('--waves','10'):1}`,...(manual?[]:['--horde-evidence','--native-trace',`--scenario=${scenario}`,`--screenshot=${out}/gameplay.png`])];
 const files=['game/core.mjs','game/singleplayer.mjs','game/enemy-types.mjs','game/config.mjs','godot/horde/demo.gd','godot/horde/model.gd','godot/tests/horde/live.gd','port/native-horde/authority.mjs','port/native-horde/run.mjs'];
 writeFileSync(resolve(out,'launch.json'),JSON.stringify({base:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),source:lock.source_commit,binary,engineSHA256:createHash('sha256').update(readFileSync(binary)).digest('hex'),hashes:Object.fromEntries(files.map(p=>[p,createHash('sha256').update(readFileSync(p)).digest('hex')])),argv,normalRate:true,localOnly:true,scenario,map},null,2));
 child=tracked(binary,argv,{env,stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',b=>{stdout+=b;if(stdout.length>32*1024*1024)void stop(child);});child.stderr.on('data',b=>{stderr+=b;if(stderr.length>4*1024*1024)void stop(child);});
 reason='running';timer=setTimeout(()=>{reason='180 second deadline';void stop(child);},manual?1800000:180000);
 const result=await child.done;clearTimeout(timer);
 exit=result.code===0&&!/SCRIPT ERROR|Parse Error|ERROR:/.test(stdout+stderr)?0:1;
 reason=exit===0?'native scenario completed':reason==='running'?'native scenario failed':reason;
} catch(e){reason=e.stack;}
finally{
 clearTimeout(timer);for(const p of [...children].reverse())await stop(p);if(game)await game.close();
 for(const [name,text]of Object.entries({'wire.jsonl':wire.join('\n'),'native.stdout.log':stdout,'native.stderr.log':stderr}))writeFileSync(resolve(out,name+'.gz'),gzipSync(text));
 rmSync(temp,{recursive:true,force:true});
 const cleanup=children.map(p=>{let absent=false;try{process.kill(p.pid,0);}catch(e){absent=e.code==='ESRCH';}return{pid:p.pid,reaped:p.exitCode!==null||p.signalCode!==null,absent};});
 if(cleanup.some(p=>!p.absent||!p.reaped)||game?.server.listening||game?.wss.clients.size||existsSync(temp))exit=1;
 writeFileSync(resolve(out,'summary.json'),JSON.stringify({exit,reason,map,scenario,cleanup,serverClosed:!game?.server.listening,sockets:game?.wss.clients.size??0,temporaryTreeRemoved:!existsSync(temp)},null,2));
 console.log(JSON.stringify({exit,reason,evidence:out,cleanup}));process.exitCode=exit;
}

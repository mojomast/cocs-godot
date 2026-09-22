// Own private normal-rate authority/display, recipient wire witness and cleanup.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdirSync,mkdtempSync,readFileSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash,randomUUID} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
import {DESTINATION_COMBAT_MAPS} from '../../game/destination-combat-maps.mjs';
import {objectiveTemplate} from '../../game/mode-data.mjs';
import {zoneRouter,bindRoute} from './route.mjs';
import {validate} from './validate.mjs';
const map=process.argv.find(a=>a.startsWith('--map='))?.slice(6), mode={'meridian-exchange':'domination','verdant-reliquary':'koth'}[map];
assert.ok(mode,'--map=meridian-exchange or verdant-reliquary required');
const binary=process.env.GODOT_BIN, lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));
const base=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
verifySource(lock);assert.equal(execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),lock.godot_version);
const out=resolve('port/native-zone-modes/evidence',map+'-'+randomUUID());mkdirSync(out,{recursive:true});
const temp=mkdtempSync('/tmp/opencode/zone-runtime-');
const env={...process.env,HOME:temp,LIBGL_ALWAYS_SOFTWARE:'1'};
for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=resolve(temp,key);mkdirSync(env[key]);}
const runtimeHashes={};
for(const p of ['game/core.mjs','game/objectives.mjs','game/mode-data.mjs','game/config.mjs','server/room.mjs','server/game-server.mjs','godot/world/session.gd','godot/net/client.gd','godot/ui/game_hud.gd','godot/ui/scoreboard.gd','godot/zone_modes/demo.gd','godot/zone_modes/adapter.gd','godot/zone_modes/renderer.gd','godot/zone_modes/hud.gd','godot/tests/zone_modes/live.gd','port/native-zone-modes/run.mjs','port/native-zone-modes/route.mjs','port/native-zone-modes/validate.mjs','port/native-projectile-combat/route.mjs'])runtimeHashes[p]=createHash('sha256').update(readFileSync(p)).digest('hex');
const children=[],wire=[];let game,child,stdout='',stderr='',timer,exit=1,reason='not started',bytes=0;
const started=Date.now();
function tracked(cmd,args,options){const p=spawn(cmd,args,options);children.push(p);p.done=new Promise((r,j)=>{p.once('error',j);p.once('close',(code,signal)=>r({code,signal}));});return p;}
async function terminate(p){if(p.exitCode===null&&p.signalCode===null){p.kill('SIGTERM');const t=setTimeout(()=>p.kill('SIGKILL'),2000);await p.done;clearTimeout(t);}}
function record(value){const line=JSON.stringify({wall:Date.now(),...value});bytes+=line.length;if(bytes>48*1024*1024){void terminate(child);throw Error('wire cap');}wire.push(line);}
const stop=()=>{reason='interrupted';if(child)void terminate(child);};process.on('SIGINT',stop);process.on('SIGTERM',stop);
try{
  // Source geometry planning before any live clock. No selected seeds or state writes.
  const arena=DESTINATION_COMBAT_MAPS.find(m=>m.id===map),router=zoneRouter(arena),zones=objectiveTemplate(mode,arena,{mode}).zones,routes=new Map();
  for(const [x,z] of arena.spawns)routes.set(`${x},${z}`,router({x,y:0,z},zones));
  const display=tracked('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],{stdio:['ignore','ignore','pipe','pipe']});
  const number=await Promise.race([new Promise((res,rej)=>{let s='';display.stdio[3].on('data',b=>{s+=b;if(s.includes('\n'))/^\d+\n$/.test(s)?res(s.trim()):rej(Error('display ID'));});}),display.done.then(()=>{throw Error('display stopped');}),new Promise((_,rej)=>{setTimeout(()=>rej(Error('display timeout')),5000).unref();})]);
  env.DISPLAY=':'+number;
  game=createGameServer({historyPath:null,progressionPath:null});let connection=0;
  game.wss.on('connection',socket=>{
    const recipient=connection++;let round=0,planned=false;
    const original=socket.send;socket.send=function(data,...args){const f=JSON.parse(String(data));
      if(f.type==='start')round++;
      if(f.type==='snapshot'&&!planned){planned=true;const a=f.state.actors[0],cached=routes.get(`${a.x},${a.z}`)||{error:'Uncached live spawn: bounded attempt',start:[a.x,a.y,a.z]},route=bindRoute(cached,f.state.objectives.zones);writeFileSync(resolve(temp,'route.json'),JSON.stringify(route));record({type:'route',recipient,round,route});}
      if(['welcome','lobby','start','results','events','snapshot'].includes(f.type))record({recipient,round,...(['results','snapshot'].includes(f.type)?{type:f.type,seq:f.seq,acks:f.acks,state:compact(f.state)}:f)});
      return original.call(this,data,...args);
    };
    socket.on('message',b=>record({type:'received',recipient,round,frame:JSON.parse(String(b))}));
  });
  await new Promise((res,rej)=>{game.server.once('error',rej);game.server.listen(0,'127.0.0.1',res);});
  const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
  const response=await fetch(endpoint.replace('ws:','http:'),{signal:AbortSignal.timeout(5000)});assert.ok(response.ok);
  child=tracked(binary,['--path','godot','--audio-driver','Dummy','--max-fps','60','--resolution',map==='meridian-exchange'?'960x640':'1280x800','--script','res://tests/zone_modes/live.gd','--',`--endpoint=${endpoint}`,`--map=${map}`,`--mode=${mode}`,'--bots=0','--round-seconds=60','--native-trace','--zone-evidence',`--route=${temp}/route.json`,`--output=${out}`],{env,stdio:['ignore','pipe','pipe']});
  child.stdout.on('data',b=>{stdout+=b;if(stdout.length>32*1024*1024)void terminate(child);});child.stderr.on('data',b=>stderr+=b);
  timer=setTimeout(()=>{reason='150s deadline';void terminate(child);},150000);
  const result=await child.done;clearTimeout(timer);
  assert.equal(result.code,0,'native exit');assert.ok(!/SCRIPT ERROR|ERROR:|Parse Error/.test(stdout+stderr),'native output');
  const validation=validate(wire.map(JSON.parse),stdout,map,mode);writeFileSync(resolve(out,'validation.json'),JSON.stringify(validation,null,2));
  assert.ok(validation.nativeCapture&&validation.nativeHeldScore&&validation.captureTransition&&validation.scoredInside,'capture and held-score acceptance');
  reason='source-correlated capture + held score + natural results/restart';exit=0;
}catch(error){reason=error.stack;}
finally{
  clearTimeout(timer);for(const p of children.toReversed())await terminate(p);
  if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();}
  const archive={};for(const [name,text]of Object.entries({'wire.jsonl':wire.join('\n')+'\n','native.stdout.log':stdout,'native.stderr.log':stderr})){const raw=Buffer.from(text);writeFileSync(resolve(out,name+'.gz'),gzipSync(raw));archive[name]={bytes:raw.length,sha256:createHash('sha256').update(raw).digest('hex')};}
  writeFileSync(resolve(out,'archive.json'),JSON.stringify(archive,null,2));rmSync(temp,{recursive:true,force:true});
  const cleanup=children.map(p=>{let absent=false;try{process.kill(p.pid,0);}catch(e){absent=e.code==='ESRCH';}return{pid:p.pid,reaped:p.exitCode!==null||p.signalCode!==null,absent};});
  if(cleanup.some(p=>!p.absent||!p.reaped)||game?.server.listening||game?.wss.clients.size||existsSync(temp))exit=1;
  writeFileSync(resolve(out,'summary.json'),JSON.stringify({map,mode,exit,reason,base,source:lock.source_commit,runtimeHashes,wall_ms:Date.now()-started,normalRate:true,botCount:0,timeLimit:60,cleanup,serverClosed:!game?.server.listening,sockets:game?.wss.clients.size??0,temporaryTreeRemoved:!existsSync(temp)},null,2));
  console.log(JSON.stringify({exit,reason,evidence:out}));process.exitCode=exit;process.off('SIGINT',stop);process.off('SIGTERM',stop);
}
function compact(s){return{mapId:s.mapId,config:s.config,time:s.time,over:s.over,winner:s.winner,teamScores:s.teamScores,objectives:s.objectives,actors:s.actors.map(a=>({id:a.id,team:a.team,x:a.x,y:a.y,z:a.z,health:a.health,scoreStats:a.scoreStats}))};}

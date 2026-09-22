// Owned ephemeral loopback authority and private Xvfb, shipped graphical session.
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {WebSocket} from 'ws';
import {createGameServer} from '../../server/game-server.mjs';
import {DESTINATION_COMBAT_MAPS} from '../../game/destination-combat-maps.mjs';
import {planRoute,groundRouteGeometry} from './route.mjs';

const root=resolve(import.meta.dirname,'../..'), here=import.meta.dirname;
const output=resolve(process.argv.find(arg=>arg.startsWith('--output='))?.slice('--output='.length)||resolve(here,'evidence')); mkdirSync(output,{recursive:true});
const selectedCase=process.argv.find(arg=>arg.startsWith('--case='))?.slice('--case='.length)||'all';
assert.ok(['all','rockets','deathmatch'].includes(selectedCase),'--case must be all, rockets, or deathmatch');
const binary=process.env.GODOT_BIN;
assert.equal(execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),'4.5.2.stable.official.6ce3de25a');
const temp=mkdtempSync('/tmp/opencode/projectile-play-');
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8',LIBGL_ALWAYS_SOFTWARE:'1'};
for(const k of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
const children=[];
let game,host;
const summary={status:'FAIL',normal_rate:true,trace_complete:false,sourceHashes:{},runs:[]};
for(const file of ['godot/world/session.gd','godot/world/projectiles.gd','godot/world/combat_feedback.gd','godot/world/audio_feedback.gd','godot/ui/match_setup.gd','port/native-projectile-combat/live.gd','port/native-projectile-combat/run.mjs','port/native-projectile-combat/route.mjs'])summary.sourceHashes[file]=createHash('sha256').update(readFileSync(resolve(root,file))).digest('hex');
function launch(command,args,name,ms,stdio=['ignore','pipe','pipe']){
  const child=spawn(command,args,{env,cwd:root,stdio}); children.push(child);
  child.text=''; child.failure=null; child.logName=name;
  const timer=setTimeout(()=>{child.failure='deadline';child.kill('SIGKILL');},ms);
  const collect=d=>{child.text+=d;if(child.text.length>100000){child.failure='output cap';child.kill('SIGKILL');}};
  child.stdout.on('data',collect);child.stderr.on('data',collect);
  child.on('error',()=>{child.failure='spawn error';});
  child.done=new Promise(ok=>child.once('close',code=>{clearTimeout(timer);ok(code);}));
  child.check=async()=>{
    const code=await child.done;writeFileSync(resolve(output,name+'.log'),child.text);
    assert.equal(child.failure,null,name);assert.equal(code,0,name);
    assert.ok(!/SCRIPT ERROR|ERROR:|leaked at exit/.test(child.text),name);
    return child.text;
  };
  return child;
}
async function until(fn,ms=10000){const end=Date.now()+ms;while(!fn()){if(Date.now()>end)throw Error('Bounded wait expired');await new Promise(r=>setTimeout(r,20));}}
try{
  // Precompute each authored spawn BEFORE starting the normal-rate authority.
  // A live off-grid/nudged spawn gets a bounded plan from the same source queries.
  const ground=groundRouteGeometry(DESTINATION_COMBAT_MAPS[0]),routes=new Map();
  if(selectedCase!=='rockets')for(const [x,z] of DESTINATION_COMBAT_MAPS[0].spawns)routes.set(`${x},${z}`,planRoute(DESTINATION_COMBAT_MAPS[0],{x,z},undefined,ground));
  const display=launch('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],'display',230000,['ignore','pipe','pipe','pipe']);
  let number='';display.stdio[3].on('data',d=>number+=d);await until(()=>/^\d+\n$/.test(number));env.DISPLAY=':'+number.trim();
  game=createGameServer({historyPath:null,progressionPath:null});
  await new Promise(ok=>game.server.listen(0,'127.0.0.1',ok));
  const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
  for(const [map,mode] of [...['meridian-exchange','verdant-reliquary','ember-crucible'].map(m=>[m,'rockets']),['meridian-exchange','deathmatch']]){
    if(selectedCase!=='all'&&selectedCase!==mode)continue;
    let joined=false, count=0, planned=false, actorId, peer;
    const inputs={count:0,fire:0,movement:0}; const sourceEvents={launches:0,pickups:0,switches:[]};
    const routePath=resolve(temp,'route.json');
    const onConnection=socket=>{
      if(++count!==2)return;
      socket.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='join')joined=true;if(f.type==='input'){inputs.count++;if(f.input.fire)inputs.fire++;if(Math.hypot(f.input.x,f.input.z)>.5)inputs.movement++;}});
      const send=socket.send;
      socket.send=function(data,...args){
        const f=JSON.parse(data);
        if(f.type==='welcome')peer=f.peerId;
        if(f.type==='lobby'&&peer!=null)actorId=f.players.find(p=>p.peerId===peer)?.actorId??actorId;
        if(f.type==='events')for(const e of f.items){if(e.actor===actorId&&e.type==='launch')sourceEvents.launches++;if(e.actor===actorId&&e.type==='pickup'&&e.kind==='rocket')sourceEvents.pickups++;if(e.actor===actorId&&e.type==='weapon-switch'&&e.source==='request')sourceEvents.switches.push(e.weapon);}
        if(mode==='deathmatch'&&f.type==='snapshot'&&!planned){const a=f.state.actors.find(a=>a.id===actorId);if(a){
          planned=true;
          try{const route=routes.get(`${a.x},${a.z}`)||planRoute(DESTINATION_COMBAT_MAPS[0],a,undefined,ground);summary.route={start:[a.x,a.y,a.z],waypoints:route};writeFileSync(routePath,JSON.stringify(route));}
          catch(error){writeFileSync(routePath,JSON.stringify({error:String(error.message)}));}
        }}
        return send.call(this,data,...args);
      };
    };
    game.wss.on('connection',onConnection);
    const frames=[];host=new WebSocket(endpoint);host.on('error',()=>{});
    host.on('message',raw=>{const f=JSON.parse(raw);if(['welcome','lobby'].includes(f.type))frames.push(f);});
    await until(()=>host.readyState===WebSocket.OPEN);
    host.send(JSON.stringify({type:'create',name:'Native projectile verification',playerName:'Passive host',v:3,delta:0}));
    await until(()=>frames.some(f=>f.type==='welcome'));const room=frames.find(f=>f.type==='welcome').roomId;
    host.send(JSON.stringify({type:'host',mapId:map,config:{mode,botCount:mode==='rockets'?2:0,timeLimit:60,fragLimit:100}}));
    await until(()=>frames.some(f=>f.type==='lobby'&&f.config));
    const name=map+'-'+mode;
    const native=launch(binary,['--path',resolve(root,'godot'),'--audio-driver','Dummy','--max-fps','60','--script',resolve(here,'live.gd'),'--',`--endpoint=${endpoint}`,`--join-room=${room}`,`--map=${map}`,`--output=${resolve(output,name+'.png')}`,...(mode==='deathmatch'?[`--route=${routePath}`]:[])],name,65000);
    await until(()=>joined,15000);host.send(JSON.stringify({type:'start'}));
    const text=await native.check();const line=text.split('\n').find(l=>l.startsWith('PORT_PROJECTILE_LIVE_OK '));assert.ok(line,name);
    const result=JSON.parse(line.slice('PORT_PROJECTILE_LIVE_OK '.length));
    assert.equal(result.local_launches,sourceEvents.launches);assert.ok(inputs.fire>100&&inputs.movement>5);
    if(mode==='deathmatch'){assert.equal(sourceEvents.pickups,1);assert.deepEqual(sourceEvents.switches,[0,1]);}
    summary.runs.push({...result,inputs,sourceEvents});console.log(line);
    host.terminate();host=null;game.wss.off('connection',onConnection);
    await until(()=>game.wss.clients.size===0);
  }
  summary.status='PASS';
}catch(error){summary.error=String(error.message);process.exitCode=1;}
finally{
  for(const child of children.reverse())if(child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');const timer=setTimeout(()=>child.kill('SIGKILL'),2000);await child.done;clearTimeout(timer);}
  for(const child of children)writeFileSync(resolve(output,child.logName+'.log'),child.text);
  host?.terminate();if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();await until(()=>game.wss.clients.size===0);}
  summary.cleanup={childrenReaped:children.every(c=>c.exitCode!==null||c.signalCode!==null),serverClosed:!game?.server.listening,sockets:game?.wss.clients.size??0};
  rmSync(temp,{recursive:true,force:true});writeFileSync(resolve(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
  console.log(JSON.stringify({status:summary.status,error:summary.error}));
}

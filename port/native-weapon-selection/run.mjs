// Bounded private native regression + normal-rate gameplay. No server state edits.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,cpSync,symlinkSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {planRoute} from '../tools/native_pickup_acceptance/route.mjs';

const root=resolve(import.meta.dirname,'../..'), here=import.meta.dirname;
const binary=process.env.GODOT_BIN, deps=process.env.GUEST_NODE_MODULES;
assert.ok(binary&&deps,'Set pinned GODOT_BIN and read-only GUEST_NODE_MODULES');
const temp=mkdtempSync('/tmp/opencode/weapon-session-');
const out=resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9)??resolve(here,'evidence'));
mkdirSync(out,{recursive:true});
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8',LIBGL_ALWAYS_SOFTWARE:'1'};
for(const k of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
const children=[], inputs=[], snapshots=[], events=[];
let game, host;
const report={status:'FAIL',normalRate:true,tickDt:1/60,tickMs:1000/60,sourceHashes:{}};
for(const p of ['godot/world/session.gd','godot/world/weapon_selection.gd','godot/tests/protocol/weapon_selection.gd','port/native-weapon-selection/live.gd','port/native-weapon-selection/run.mjs'])
  report.sourceHashes[p]=createHash('sha256').update(readFileSync(resolve(root,p))).digest('hex');
function launch(command,args,name,ms,extra={}){
  const child=spawn(command,args,{env,stdio:['ignore','pipe','pipe'],...extra});children.push(child);
  child.text='';child.failure=null;
  const timer=setTimeout(()=>{child.failure='deadline';child.kill('SIGKILL');},ms);
  child.stdout.on('data',d=>{child.text+=d;if(child.text.length>8000000){child.failure='output cap';child.kill('SIGKILL');}});
  child.stderr.on('data',d=>child.text+=d);
  child.on('error',e=>child.failure=e.message);
  child.done=new Promise(res=>child.once('close',code=>{clearTimeout(timer);res(code);}));
  child.check=async()=>{
    const code=await child.done;
    const lines=child.text.split('\n').filter(l=>!l.startsWith('PORT_NATIVE_TRACE ')||l.includes('"weapon":'));
    writeFileSync(resolve(out,name+'.log'),lines.join('\n'));
    assert.equal(child.failure,null,name);assert.equal(code,0,name);
    assert.ok(!/^(SCRIPT ERROR:|ERROR:)/m.test(child.text),name+' Godot errors');
    return child.text;
  };
  return child;
}
async function until(fn,ms=5000){const end=Date.now()+ms;while(!fn()){if(Date.now()>end)throw Error('Wait timeout');await new Promise(r=>setTimeout(r,20));}}
try{
  report.version=execFileSync(binary,['--version'],{encoding:'utf8',timeout:10000}).trim();
  assert.equal(report.version,'4.5.2.stable.official.6ce3de25a');
  for(const dir of ['godot','game','server'])cpSync(resolve(root,dir),resolve(temp,dir),{recursive:true,filter:p=>!p.includes('/.godot')});
  symlinkSync(resolve(deps),resolve(temp,'node_modules'),'dir');
  execFileSync(process.execPath,[resolve(root,'tools/godot-export/semantic.mjs'),resolve(temp,'godot/content/generated')],{cwd:root,env,timeout:60000});
  await launch(binary,['--headless','--path',resolve(temp,'godot'),'--editor','--import'],'import',60000).check();
  const xvfb=launch('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],'display',130000,{stdio:['ignore','pipe','pipe','pipe']});
  let display='';xvfb.stdio[3].on('data',d=>display+=d);
  await until(()=>/^\d+\n$/.test(display));env.DISPLAY=':'+display.trim();
  const common=['--path',resolve(temp,'godot'),'--audio-driver','Dummy','--max-fps','60'];
  await launch(binary,[...common,'--script','res://tests/protocol/weapon_selection.gd'],'regression',15000).check();
  const {WebSocket}=createRequire(resolve(temp,'entry.cjs'))('ws');
  const {createGameServer}=await import(pathToFileURL(resolve(temp,'server/game-server.mjs')));
  const {DESTINATION_COMBAT_MAPS}=await import(pathToFileURL(resolve(temp,'game/destination-combat-maps.mjs')));
  game=createGameServer({historyPath:null,progressionPath:null});
  await new Promise(res=>game.server.listen(0,'127.0.0.1',res));
  const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
  let count=0, peer, actorId, planned=false, prior=-1, joined=false;
  game.wss.on('connection',socket=>{
    if(++count!==2)return;
    socket.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')inputs.push(f);if(f.type==='join')joined=true;});
    const send=socket.send;
    socket.send=function(data,...args){
      const f=JSON.parse(data);
      if(f.type==='welcome')peer=f.peerId;
      if(f.type==='lobby'&&peer!=null)actorId=f.players.find(p=>p.peerId===peer)?.actorId??actorId;
      if(f.type==='events')events.push(...f.items.filter(e=>e.actor===actorId&&['pickup','weapon-switch'].includes(e.type)));
      if(f.type==='snapshot'){
        const a=f.state.actors.find(a=>a.id===actorId);
        if(a&&!planned){report.route=planRoute(DESTINATION_COMBAT_MAPS[0],a);writeFileSync(resolve(temp,'route.json'),JSON.stringify(report.route));report.config=f.state.config;planned=true;}
        if(a&&a.weapon!==prior){snapshots.push({seq:f.seq,ack:f.acks[actorId],actorId,weapon:a.weapon,ammo:a.ammo,health:a.health});prior=a.weapon;}
      }
      return send.call(this,data,...args);
    };
  });
  const frames=[];host=new WebSocket(endpoint);host.on('message',raw=>{const f=JSON.parse(raw);if(['welcome','lobby'].includes(f.type))frames.push({type:f.type,roomId:f.roomId,config:f.config});});host.on('error',()=>{});
  await until(()=>host.readyState===WebSocket.OPEN);
  host.send(JSON.stringify({type:'create',name:'Native weapon selection',playerName:'Passive host',v:3,delta:0}));
  await until(()=>frames.some(f=>f.type==='welcome'));
  const room=frames.find(f=>f.type==='welcome').roomId;
  host.send(JSON.stringify({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0}}));
  await until(()=>frames.some(f=>f.type==='lobby'&&f.config));
  const native=launch(binary,[...common,'--script',resolve(here,'live.gd'),'--',`--endpoint=${endpoint}`,`--join-room=${room}`,'--native-trace',`--route=${resolve(temp,'route.json')}`,`--output=${resolve(out,'native.png')}`],'native',70000);
  await until(()=>joined,15000);
  host.send(JSON.stringify({type:'start'}));
  const text=await native.check();
  assert.ok(text.includes('PORT_WEAPON_LIVE_OK'));
  assert.deepEqual(snapshots.map(s=>s.weapon),[0,1,0,1,0,1,0]);
  assert.equal(events.filter(e=>e.type==='pickup'&&e.kind==='rocket').length,1);
  assert.equal(events.filter(e=>e.type==='weapon-switch'&&e.source==='request').length,5);
  const commands=inputs.filter(f=>Object.hasOwn(f.input,'weapon'));
  assert.ok(commands.length>=5&&commands.length<50);
  assert.ok(inputs.some(f=>Math.hypot(f.input.x,f.input.z)>.5));
  const nativeCommands=text.split('\n').filter(l=>l.startsWith('PORT_NATIVE_TRACE ')).map(l=>JSON.parse(l.slice(18))).filter(f=>f.event==='input_queue'&&Object.hasOwn(f.controls,'weapon'));
  assert.deepEqual(nativeCommands.map(f=>f.controls.weapon),commands.map(f=>f.input.weapon));
  report.inputsReceived=inputs.length;report.commands=commands.map(f=>({seq:f.seq,weapon:f.input.weapon}));
  report.transitions=snapshots;report.events=events;report.status='PASS';
}catch(e){report.error=e.stack;process.exitCode=1;}
finally{
  for(const child of children.reverse())if(child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');const timer=setTimeout(()=>child.kill('SIGKILL'),2000);await child.done;clearTimeout(timer);}
  host?.terminate();
  if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();await until(()=>game.wss.clients.size===0);}
  report.cleanup={childrenReaped:children.every(c=>c.exitCode!==null||c.signalCode!==null),serverClosed:game?!game.server.listening:true,sockets:game?.wss.clients.size??0};
  rmSync(temp,{recursive:true,force:true});
  writeFileSync(resolve(out,'summary.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({status:report.status,error:report.error,output:out}));
}

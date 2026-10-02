import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createGameServer} from '../../../../port/multiplayer-worlds/derived/game-server.mjs';
import {readWorld} from '../../../../port/multiplayer-worlds/catalog.mjs';
const mode=process.argv[2]??'ctf',out=path.resolve(process.argv[3]);fs.mkdirSync(out,{recursive:true});
const root=path.resolve(new URL('../../../../',import.meta.url).pathname),godot=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(label,predicate,ms=30000){const end=Date.now()+ms;while(Date.now()<end){const result=predicate();if(result)return result;await sleep(50);}throw Error(label+' timeout');}
const game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
let room,guest,child,seq=0,timer,watchdog,logs='',lastGuide={},pathStates={},wire=[],trace=[],events={},lastEvent=0;
const dist=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
function route(m,from,to){const nearest=p=>m.nav.reduce((best,n,i)=>dist(n,p)<dist(m.nav[best],p)?i:best,0),start=nearest(from),end=nearest(to),prev=new Map([[start,null]]),q=[start];for(let k=0;k<q.length&&!prev.has(end);k++)for(const j of m.edges[q[k]])if(!prev.has(j)){prev.set(j,q[k]);q.push(j);}assert.ok(prev.has(end));const nodes=[];for(let i=end;i!==null;i=prev.get(i))nodes.unshift(m.nav[i]);return [...nodes,to];}
function steer(m,a,target,key){let s=pathStates[a.id];if(!s||s.key!==key||s.deaths!==a.deaths){s=pathStates[a.id]={key,deaths:a.deaths,route:route(m,a,target),index:0};}
 while(s.index<s.route.length-1&&dist(a,s.route[s.index])<.85)s.index++;
 const p=dist(a,target)<1.6?target:s.route[s.index],dx=p.x-a.x,dz=p.z-a.z;
 return {yaw:Math.atan2(-dx,-dz),pitch:0,move:dist(a,target)>.65,crouch:Math.hypot(dx,dz)<3,x:dx,z:dz};}
function guide(){const m=room?.match;if(!m)return {move:false};const a=m.actors[0],b=m.actors[1];
 if(a.health<=0||m.over)return {move:false};
 if(mode==='ctf'){const enemy=m.flags[1],target=enemy.carrier===a.id?{x:-86,z:0}:{x:86,z:0};return steer(m,a,target,enemy.carrier===a.id?'return':'steal');}
 if(['domination','koth'].includes(mode)){const z=m.objectiveState.zones[0];return steer(m,a,z,'zone-'+z.x+':'+z.z);}
 const result=steer(m,a,{x:-3,z:0},'duel');if(dist(a,{x:-3,z:0})<1&&b.health>0&&dist(b,{x:3,z:0})<1){result.move=false;result.fire=true;result.yaw=Math.atan2(a.x-b.x,a.z-b.z);result.pitch=Math.atan2(b.y+1-a.y-a.eyeHeight,dist(a,b));}return result;
}
const control=createServer((req,res)=>{try{assert.equal(req.url,'/guide');lastGuide=guide();res.setHeader('content-type','application/json');res.end(JSON.stringify(lastGuide));}catch(e){res.statusCode=500;res.end(String(e));}});await new Promise(r=>control.listen(0,'127.0.0.1',r));
game.wss.on('connection',s=>s.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')wire.push({peer:s.peerId??null,...f});}));
try{
 const args=['-a',godot,'--path',path.join(root,'godot'),'--audio-driver','Dummy','res://multiplayer_worlds/art/helix-conservatory/journey.tscn','--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--map=helix-conservatory',`--mode=${mode}`,'--bots=0',`--helix-out=${out}`,`--helix-guide=http://127.0.0.1:${control.address().port}`];
 child=spawn('xvfb-run',args,{cwd:root,detached:true,env:{...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1',COCS_SETTINGS_PATH:path.join(out,'settings.json')},stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',b=>logs+=b);
 const closed=new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
 room=await until('native host',()=>[...game.registry.rooms.values()].find(r=>r.peers.size===1));
 guest=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);await new Promise(r=>guest.addEventListener('open',r,{once:true}));
 guest.send(JSON.stringify({type:'join',v:3,roomId:room.id,name:'Helix controlled opponent',character:'chatgpt',harness:'openclaw'}));
 await until('source match',()=>room.match);const m=room.match;
 timer=setInterval(()=>{if(!m.over&&['deathmatch','teamdeathmatch'].includes(mode)){const b=m.actors[1];if(b.health>0){const g=steer(m,b,{x:3,z:0},'duel-guest');const l=Math.hypot(g.x,g.z);guest.send(JSON.stringify({type:'input',seq:++seq,input:{x:g.move?g.x/l:0,z:g.move?g.z/l:0,yaw:g.yaw}}));}}
  if(trace.length===0||m.time-trace.at(-1).time>=1)trace.push({time:m.time,actors:m.actors.map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,health:a.health})),scores:{...m.teamScores},guide:lastGuide});
  for(const e of m.events)if(e.id>lastEvent){events[e.type]=(events[e.type]??0)+1;lastEvent=Math.max(lastEvent,e.id);}
 },50);
 const code=await Promise.race([closed,new Promise((_,reject)=>{watchdog=setTimeout(()=>reject(Error('native process timeout')),220000);})]);
 assert.equal(code,0,logs.slice(-5000));assert.ok(!/SCRIPT ERROR|Parse Error|^ERROR:/m.test(logs),logs.slice(-5000));assert.equal(m.over,true);assert.notEqual(m.overReason,'time');
 if(mode==='ctf')assert.ok(m.actors[0].scoreStats.captures>=1);
 if(['domination','koth'].includes(mode))assert.ok(m.actors[0].scoreStats.objectiveCaptures>=1);
 if(['deathmatch','teamdeathmatch'].includes(mode))assert.equal(m.actors[0].frags,5);
 assert.ok(wire.length>30);const native=JSON.parse(fs.readFileSync(path.join(out,'native-journey.json')));assert.equal(native.geometryHash,readWorld('helix-conservatory').geometryHash);
 fs.writeFileSync(path.join(out,'source-outcome.json'),JSON.stringify({classification:'graphical native Input.parse_input_event -> production websocket -> source Match -> native HUD; controlled wire opponent; no actor position/score/state writes',mode,geometryHash:native.geometryHash,frames:wire.length,seconds:m.time,endReason:m.overReason,events,stats:m.actors.map(a=>({id:a.id,frags:a.frags,scoreStats:a.scoreStats})),trace},null,2));
 console.log('HELIX_HOSTED_NATIVE_OK',mode,m.time,wire.length,native.geometryHash);
}finally{
 clearInterval(timer);clearTimeout(watchdog);fs.writeFileSync(path.join(out,'native.log'),logs);fs.writeFileSync(path.join(out,'wire-input.json'),JSON.stringify(wire));fs.writeFileSync(path.join(out,'last-guide.json'),JSON.stringify({lastGuide,trace:trace.slice(-10)}));
 if(child&&child.exitCode===null){try{process.kill(-child.pid,'SIGTERM');}catch{}}
 guest?.close();for(const s of game.wss.clients)s.terminate();await game.close();await new Promise(r=>control.close(r));
 fs.writeFileSync(path.join(out,'teardown.json'),JSON.stringify({pid:child?.pid,exitCode:child?.exitCode,signal:child?.signalCode}));
}

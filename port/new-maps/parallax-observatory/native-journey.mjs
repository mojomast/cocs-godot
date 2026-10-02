import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createGameServer} from '../../multiplayer-worlds/derived/game-server.mjs';
import {readWorld} from '../../multiplayer-worlds/catalog.mjs';
const requested=process.argv[2]??'ctf',walk=requested==='walkthrough',mode=walk?'deathmatch':requested;
const out=path.resolve(process.argv[3]??`/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/native-${requested}`),visual=process.env.PARALLAX_VISUAL==='1'||walk;
fs.mkdirSync(out,{recursive:true});
const root=path.resolve(new URL('../../../',import.meta.url).pathname),godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let logs='',child,room,guest,timer,watchdog,seq=0,lastGuide={},trace=[],wire=[],pathStates={},stage=0,holdSince=0,visits=[];
async function until(label,predicate,ms=50000){const end=Date.now()+ms;while(Date.now()<end){const result=predicate();if(result)return result;if(child?.exitCode!==null&&child?.exitCode!==undefined)throw Error(logs);await sleep(50);}throw Error(label+' timeout\n'+logs.slice(-2000));}
const game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
const data=readWorld('parallax-observatory'),dist=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
function route(m,from,to){const nearest=p=>m.nav.reduce((best,n,i)=>dist(n,p)<dist(m.nav[best],p)?i:best,0),start=nearest(from),end=nearest(to),prev=new Map([[start,null]]),q=[start];for(let k=0;k<q.length&&!prev.has(end);k++)for(const j of m.edges[q[k]])if(!prev.has(j)){prev.set(j,q[k]);q.push(j);}assert.ok(prev.has(end));const nodes=[];for(let i=end;i!==null;i=prev.get(i))nodes.unshift(m.nav[i]);return [...nodes,to];}
function steer(m,a,target,key){let s=pathStates[a.id];if(!s||s.key!==key||s.deaths!==a.deaths)s=pathStates[a.id]={key,deaths:a.deaths,route:route(m,a,target),index:0};while(s.index<s.route.length-1&&dist(a,s.route[s.index])<2)s.index++;const p=dist(a,target)<3?target:s.route[s.index],dx=p.x-a.x,dz=p.z-a.z;return {yaw:Math.atan2(-dx,-dz),pitch:0,move:dist(a,target)>.6,crouch:visual||Math.hypot(dx,dz)<3,x:dx,z:dz};}
const upper=data.routes.find(r=>r.id==='armillary-arc').points,lower=[...data.routes.find(r=>r.id==='tidal-cistern').points].reverse();
const walkTargets=[{x:-36,z:0,id:'archive',look:[-22,15,4]},{x:0,z:-84,id:'polar',look:[14,29,-80]},{x:69,z:0,id:'arcade',look:[96,17,0]},{x:24,z:78,id:'pump',look:[35,3,81]},{x:0,z:0,id:'lens',look:[-60,40,-90]}];
function guide(){const m=room?.match;if(!m)return {move:false};const a=m.actors[0],b=m.actors[1];if(a.health<=0||m.over)return {move:false};
 if(walk){const p=walkTargets[stage];if(!p)return {move:false,finished:true};if(dist(a,p)<2.5||holdSince){if(!holdSince)holdSince=m.time;const [x,y,z]=p.look;const g={move:false,yaw:Math.atan2(a.x-x,a.z-z),pitch:Math.atan2(y-a.y-1.45,Math.hypot(x-a.x,z-a.z)),shot:p.id,clip:true};if(m.time-holdSince>2){visits.push({id:p.id,time:m.time,x:a.x,y:a.y,z:a.z});stage++;holdSince=0;}return g;}return {...steer(m,a,p,'walk-'+stage),clip:true};}
 if(mode==='ctf'){const carrying=m.flags[1].carrier===a.id,points=carrying?lower:upper,key=carrying?'carry-lower':'outbound-upper';if(lastGuide.route!==key)stage=0;while(stage<points.length-1&&dist(a,points[stage])<1.2)stage++;return {...steer(m,a,points[stage],key+'-'+stage),route:key,clip:carrying&&a.z>60,shot:carrying?'flag-carried':''};}
 if(['koth','uplink','holdout'].includes(mode)){const zones=m.objectiveState.zones,target=mode==='holdout'?(zones.find(z=>z.owner!==a.team)??zones[0]):zones[0];return {...steer(m,a,target,'zone-'+target.id+'-'+target.x+':'+target.z),clip:dist(a,target)<10,shot:dist(a,target)<2?'objective-live':''};}
 const target={x:-6,z:0},g=steer(m,a,target,'duel');if(dist(a,target)<(visual?2.5:1)&&b.health>0&&dist(b,{x:6,z:0})<1){g.move=false;g.fire=true;g.yaw=Math.atan2(a.x-b.x,a.z-b.z);g.pitch=Math.atan2(b.y+1-a.y-a.eyeHeight,dist(a,b));g.clip=true;g.shot='combat-live';}return g;
}
const control=createServer((req,res)=>{try{assert.equal(req.url,'/guide');lastGuide=guide();res.setHeader('content-type','application/json');res.end(JSON.stringify(lastGuide));}catch(e){res.statusCode=500;res.end(String(e));}});await new Promise(r=>control.listen(0,'127.0.0.1',r));
game.wss.on('connection',s=>s.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')wire.push(f);}));
try{
 const args=['--rendering-method','gl_compatibility','--single-threaded-scene','--path',path.join(root,'godot'),'--audio-driver','Dummy','--max-fps','60','res://tests/new_maps/parallax_observatory/journey.tscn','--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--map=parallax-observatory',`--mode=${mode}`,'--bots=0',`--parallax-out=${out}`,`--parallax-guide=http://127.0.0.1:${control.address().port}`,...(visual?['--parallax-visual']:[])];
 child=spawn('xvfb-run',['-a',godot,...args],{cwd:root,detached:true,env:{...process.env,LP_NUM_THREADS:'1',OMP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1',COCS_SETTINGS_PATH:path.join(out,'settings.json')},stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',b=>logs+=b);
 const closed=new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
 room=await until('native host',()=>[...game.registry.rooms.values()].find(r=>r.peers.size===1));
 guest=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);await new Promise(r=>guest.addEventListener('open',r,{once:true}));guest.send(JSON.stringify({type:'join',v:3,roomId:room.id,name:'Parallax controlled passive peer',character:'chatgpt',harness:'openclaw'}));
 await until('source match',()=>room.match);const m=room.match;
 timer=setInterval(()=>{if(!walk&&!m.over&&['deathmatch','teamdeathmatch'].includes(mode)){const b=m.actors[1];if(b.health>0){const g=steer(m,b,{x:6,z:0},'guest-duel'),l=Math.hypot(g.x,g.z);guest.send(JSON.stringify({type:'input',seq:++seq,input:{x:g.move?g.x/l:0,z:g.move?g.z/l:0,yaw:g.yaw}}));}}
  if(!trace.length||m.time-trace.at(-1).time>=1){trace.push({time:m.time,actors:m.actors.map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,health:a.health})),scores:{...m.teamScores},guide:lastGuide});fs.writeFileSync(path.join(out,'live-progress.json'),JSON.stringify(trace.at(-1)));}
 },50);
 const code=await Promise.race([closed,new Promise((_,reject)=>{watchdog=setTimeout(()=>reject(Error('native timeout')),610000);})]);
 assert.equal(code,0,logs.slice(-5000));assert.ok(!/SCRIPT ERROR|Parse Error|^ERROR:/m.test(logs),logs.slice(-5000));
 if(!walk){assert.equal(m.over,true);assert.notEqual(m.overReason,'time');if(mode==='ctf')assert.equal(m.actors[0].scoreStats.captures,1);if(['koth','uplink','holdout'].includes(mode))assert.ok(m.actors[0].scoreStats.objectiveCaptures>0);if(['deathmatch','teamdeathmatch'].includes(mode))assert.equal(m.actors[0].frags,5);}else assert.equal(visits.length,walkTargets.length);
 const native=JSON.parse(fs.readFileSync(path.join(out,'native-journey.json')));assert.equal(native.geometryHash,data.geometryHash);assert.ok(native.inputEvents>30&&native.lastAck>30);
 if(visual){assert.equal(native.uiChecks.length,4);assert.ok(native.uiChecks.every(c=>c.rows.every(r=>r.fits)),'Native wide/compact HUD overflow');}
 fs.writeFileSync(path.join(out,'source-outcome.json'),JSON.stringify({classification:'native Input.parse_input_event -> ordinary production sampler -> WebSocket -> source Match -> native presentation; passive wire peer; no actor/score/position injection',mode:requested,geometryHash:data.geometryHash,wireFrames:wire.length,seconds:m.time,endReason:m.overReason,stats:m.actors.map(a=>({id:a.id,frags:a.frags,scoreStats:a.scoreStats})),visits,trace},null,2));
 console.log('PARALLAX_HOSTED_NATIVE_OK',requested,m.time,wire.length,data.geometryHash);
}finally{
 clearInterval(timer);clearTimeout(watchdog);fs.writeFileSync(path.join(out,'native.log'),logs);fs.writeFileSync(path.join(out,'wire-input.json'),JSON.stringify(wire));fs.writeFileSync(path.join(out,'last-guide.json'),JSON.stringify({lastGuide,trace:trace.slice(-15)}));
 if(child&&child.exitCode===null){try{process.kill(-child.pid,'SIGTERM');}catch{}}
 guest?.close();for(const s of game.wss.clients)s.terminate();await game.close();await new Promise(r=>control.close(r));
 fs.writeFileSync(path.join(out,'teardown.json'),JSON.stringify({pid:child?.pid,exitCode:child?.exitCode,signal:child?.signalCode}));
}

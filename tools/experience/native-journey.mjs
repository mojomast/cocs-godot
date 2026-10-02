import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
import {createGameServer} from '../../server/game-server.mjs';
import {createAuthority} from '../../port/native-campaign/authority.mjs';
import {createCampaignMatch} from '../../port/native-campaign/match.mjs';
const binary=process.env.GODOT_BIN;assert.ok(binary);
const scenario=process.env.SCENARIO??'mode',mode=process.env.MODE??'arsenal',operator=process.env.OPERATOR??'chatgpt',compact=process.env.COMPACT==='1';
const out=resolve(process.env.EVIDENCE_DIR);mkdirSync(out,{recursive:true});
let campaignMatch;
const game=scenario==='campaign'?createAuthority({mapId:'rootfall-verge',matchFactory:options=>(campaignMatch=createCampaignMatch(options))}):createGameServer({historyPath:null,progressionPath:null});
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
const actions=[],wire=[];
let silence=false;
let boundaryStart=0;
game.wss.on('connection',s=>{
 s.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')wire.push(f);});
 const send=s.send;s.send=function(raw,...rest){const f=JSON.parse(String(raw));if(silence&&['snapshot','events'].includes(f.type))return;return send.call(this,raw,...rest);};
});
const control=createServer((req,res)=>{
 try{
  const m=campaignMatch??[...game.registry.rooms.values()].find(r=>r.match)?.match;assert.ok(m,'live source match');
  const a=m.actors.find(a=>a.id===0),other=m.actors.find(b=>b!==a);
  if(req.url==='/boundary-start'){
   boundaryStart=wire.length;
  }else if(req.url==='/boundary-end'){
   const frames=wire.slice(boundaryStart);assert.ok(frames.every(f=>!['fire','power','mobility','grenade','jump','interact','melee','x','z'].some(k=>f.input[k])),'modal controls remain neutral');
   actions.push({method:'real-input modal wire neutrality',frames:frames.length,time:m.time});
  }else if(req.url==='/stale'||req.url==='/resume'){
   silence=req.url==='/stale';actions.push({method:'transport snapshot/event suppression',silence,time:m.time});
  }else if(req.url==='/respawn'){
   m.spawn(a);actions.push({method:'Match.spawn controlled respawn',time:m.time});
  }else if(req.url==='/pickup'){
   a.protection=0;a.armor=0;
   // Crown shields are real source mechanics: spend them through damage before
   // asking the genuine health-pickup path to collect a useful supply.
   for(let hit=0;hit<100&&a.health>=a.maxHealth;hit++)m.damage(a,10,null);
   const p=m.pickups.find(p=>p.kind==='health');assert.ok(p,'source health supply');
   assert.equal(m.collect(a,p),true,'source accepted useful pickup');actions.push({method:'Match.damage + Match.collect',time:m.time,eventIds:m.events.slice(-3).map(e=>e.id)});
  }else if(req.url==='/damage'){
   a.protection=0;a.armor=0;m.damage(a,12,other);m.damage(a,9,other);actions.push({method:'Match.damage twice',time:m.time});
  }else if(req.url==='/death'){
   a.protection=0;a.armor=0;m.damage(a,999,other);actions.push({method:'Match.damage lethal',time:m.time});
  }else if(req.url==='/kill'){
   assert.ok(other,'source opponent');other.protection=0;other.armor=0;m.damage(other,999,a);
   actions.push({method:'Match.damage attributed local kill',time:m.time});
  }else if(req.url==='/story'){
   const npc=m.snapshot().campaign.story.entities.find(e=>e.kind==='operator');assert.ok(npc);
   Object.assign(a,{x:npc.x,y:npc.y,z:npc.z,vx:0,vy:0,vz:0});
   actions.push({method:'position at source story entity; ordinary step triggers dialogue',time:m.time,entity:npc.id});
  }else throw Error('unknown stage');
  res.end('ok');
 }catch(e){res.statusCode=500;res.end(String(e));}
});
await new Promise(r=>control.listen(0,'127.0.0.1',r));
const map={arsenal:'meridian-exchange',juggernaut:'meridian-exchange','team-elimination':'tidal-citadel','vip-escort':'sunscar-convoy'}[mode];
const args=['-a',binary,'--audio-driver','Dummy','--path',resolve('godot'),'--script','res://tests/experience/native_journey.gd','--',`--experience-out=${out}`,`--experience-control=http://127.0.0.1:${control.address().port}`,`--experience-scenario=${scenario}`,`--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--bots=0',`--operator=${operator}`,'--harness=codex'];
if(scenario==='campaign')args[args.findIndex(a=>a.startsWith('--endpoint='))]+='/native-campaign';
if(process.env.BOTS)args[args.indexOf('--bots=0')]='--bots='+process.env.BOTS;
if(process.env.BOTS)args.push('--experience-kill');
if(process.env.VERBOSE==='1')args.splice(2,0,'--verbose');
if(compact)args.push('--experience-compact');
if(scenario==='mode')args.push(`--map=${map}`,`--mode=${mode}`,'--time-limit=180');
if(scenario==='campaign')args.push('--map=rootfall-verge');
if(scenario==='sports')args.push('--map=ion-speedway');
if(scenario==='combined_arms')args.push('--map=sunscar-convoy');
const child=spawn('xvfb-run',args,{detached:true,env:{...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1',COCS_SETTINGS_PATH:resolve(out,'settings.json')},stdio:['ignore','pipe','pipe']});
const stop=()=>{try{process.kill(-child.pid,'SIGTERM');}catch{}};
let text='';for(const s of [child.stdout,child.stderr])s.on('data',x=>{text+=x;if(text.includes('Parse Error:'))stop();});
const timeout=setTimeout(stop,90000);
try{
 const code=await new Promise((r,j)=>{child.on('error',j);child.on('close',r);});
 writeFileSync(resolve(out,'native.log'),text);
 writeFileSync(resolve(out,'source-actions.json'),JSON.stringify(actions,null,2));
 writeFileSync(resolve(out,'wire-input.json'),JSON.stringify(wire,null,2));
 console.log(text.split('\n').filter(l=>l.includes('EXPERIENCE_NATIVE')||l.includes('SCRIPT ERROR')).join('\n'));
 assert.equal(code,0,'native exit');assert.ok(!/SCRIPT ERROR|Parse Error|^ERROR:/m.test(text),'native log contains errors: '+out);
 assert.ok(wire.some(f=>['sports','combined_arms'].includes(scenario)?Object.keys(f.input).length>0:f.input.fire),'real native input');
 const report=JSON.parse(readFileSync(resolve(out,'native.json')));assert.equal(report.failures.length,0);
 console.log('EXPERIENCE_JOURNEY_OK',scenario,mode,operator,compact?'compact':'wide',out);
}finally{
 clearTimeout(timeout);stop();for(const s of game.wss.clients)s.terminate();
 await game.close();await new Promise(r=>control.close(r));
 writeFileSync(resolve(out,'teardown.json'),JSON.stringify({pid:child.pid,exitCode:child.exitCode,signalCode:child.signalCode}));
}

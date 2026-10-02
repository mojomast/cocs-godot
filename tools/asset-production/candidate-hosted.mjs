// Grant-only serial two-native-client hosted journey. No source authority is
// constructed by source tests. Every movement/fire/reset enters native transport.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,renameSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {ROOT,CANDIDATES,identity,prepare,sha} from './candidate-admission.mjs';
import {controller,distance,drive,assertOutcome} from './candidate-guidance.mjs';

const [id,mode]=process.argv.slice(2);
assert.ok(process.argv.includes('--granted'),'Explicit heavy grant required');
assert.ok(CANDIDATES[id]?.includes(mode),'Unknown candidate pair');
const plan=JSON.parse(readFileSync(resolve(ROOT,'port/finish/ASSET_PRODUCTION.json')));
const out=resolve(plan.evidenceRoot,'hosted',new Date().toISOString().replaceAll(':','-')+'-'+id+'-'+mode);
mkdirSync(out,{recursive:true});
const permit=identity(id,mode),art=resolve(ROOT,`godot/multiplayer_worlds/art/worlds/${id}.glb`);
assert.ok(existsSync(art),'Build/reopen/receipt/import the actual candidate first');
writeFileSync(resolve(out,'asset-receipt.log'),execFileSync(process.execPath,['tools/asset-production/receipt.mjs',id],{cwd:ROOT,timeout:60000,encoding:'utf8'}));
const derived=prepare(resolve(out,'private-authority'),permit);
const {createGameServer}=await import(pathToFileURL(derived.server));
const {visible}=await import(pathToFileURL(resolve(ROOT,'game/core.mjs')));
const game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
const endpoint=`ws://127.0.0.1:${game.server.address().port}`,peers=[],wire=[],trace=[],respawn={};
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let timer,tickError,room,m,success=false;
const until=async(label,predicate,ms=45000)=>{
 const end=Date.now()+ms;while(Date.now()<end){
  if(tickError)throw tickError;
  for(const p of peers)if(p.closed||/SCRIPT ERROR|Parse Error|FOUNDRY_NATIVE_ERROR/.test(p.log))throw Error(`${p.role}: ${p.log.slice(-5000)}`);
  const value=predicate();if(value)return value;await sleep(50);
 }throw Error('Timeout '+label);
};
const stimulus=(role,input,clip=false)=>{
 const path=resolve(out,role+'-controls.json');writeFileSync(path+'.tmp',JSON.stringify({input,clip}));renameSync(path+'.tmp',path);
};
function launch(role,extra=[]){
 stimulus(role,{});
 const compact=process.argv.includes('--compact');
 const args=['--path',resolve(ROOT,'godot'),'--audio-driver','Dummy',
  ...(role==='guest'?['--headless']:['--resolution',compact?'760x520':'1280x800']),
  'res://tests/asset_production/hosted.tscn','--',`--endpoint=${endpoint}`,`--map=${id}`,`--mode=${mode}`,'--bots=0','--candidate-private',
  `--candidate-sha=${permit.expectedSha}`,`--candidate-geometry=${permit.data.geometryHash}`,
  `--foundry-role=${role}`,`--foundry-controls=${resolve(out,role+'-controls.json')}`,
  ...(role==='host'?[`--foundry-capture=${resolve(out,'frames')}`]:[]),...(compact?['--foundry-compact']:[]),...extra];
 const child=spawn(plan.tools.godot,args,{cwd:ROOT,env:{...process.env,LP_NUM_THREADS:'1',COCS_SETTINGS_PATH:resolve(out,role+'-settings.json')},stdio:['ignore','pipe','pipe']});
 const peer={role,child,log:'',closed:false};peers.push(peer);
 child.on('error',e=>{tickError=e;});child.on('close',code=>{peer.closed=true;peer.code=code;});
 for(const stream of [child.stdout,child.stderr])stream.on('data',b=>{peer.log+=b;});
}
game.wss.on('connection',socket=>socket.on('message',raw=>{const f=JSON.parse(raw);if(['input','host','join','start'].includes(f.type))wire.push({at:new Date().toISOString(),...f});}));
try{
 launch('host');room=await until('native host',()=>[...game.registry.rooms.values()].find(r=>r.mapId===id&&r.peers.size===1));
 launch('guest',[`--join-room=${room.id}`]);m=await until('native join and source start',()=>room.match);
 assert.equal(m.arena.id,id);assert.equal(m.config.mode,mode);assert.equal(m.actors.filter(a=>!a.bot).length,2);
 const follow=controller();let samples=0,resetSent=false;
 const avoid=[...Object.values(m.flags??{}),...(m.objectiveState?.zones??[])];
 const retreat=avoid.length?m.nav.reduce((best,p)=>Math.min(...avoid.map(q=>distance(p,q)))>Math.min(...avoid.map(q=>distance(best,q)))?p:best,m.nav[0]):null;
 function aim(a,b){return {yaw:Math.atan2(a.x-b.x,a.z-b.z),pitch:Math.atan2(b.y+1-a.y-(a.eyeHeight??1.45),distance(a,b)),fire:true,reload:a.ammo?.[a.weapon]===0};}
 function hunt(a,b,key){
  if(a.health<=0||b.health<=0)return {};
  if(distance(a,b)<22&&visible({x:a.x,y:a.y+(a.eyeHeight??1.45),z:a.z},{x:b.x,y:b.y+1,z:b.z},m.arena))return aim(a,b);
  // Replan only when the target has respawned, not at each control sample.
  return follow(m,a,b,key+'-'+b.deaths);
 }
 const tick=()=>{
  if(m.over)return;
  const a=m.actors[0],b=m.actors[1];let host={},guest={};
  if(mode==='puma-race'){
   host=drive(m,a.id);guest=drive(m,b.id);
   const r=m.race.racers.find(r=>r.actorId===b.id);
   if(m.race.phase==='countdown')respawn.countdownObserved=true;
   if(m.race.phase==='racing'&&!resetSent){resetSent=true;respawn.resetPassed=r.passed;}
   if(resetSent&&!respawn.raceReset)guest={interact:true};
   if(resetSent&&r.resetWait>0){respawn.raceReset=true;assert.equal(r.passed,respawn.resetPassed,'Reset awarded gate progress');}
   if(respawn.raceReset&&r.resetWait===0)respawn.raceRecovered=true;
  }else{
   if(a.health<=0)respawn.dead=true;
   if(respawn.dead&&a.health>0)respawn.alive=true;
   if(!respawn.alive){guest=hunt(b,a,'respawn-contact');}
   else if(['deathmatch','teamdeathmatch'].includes(mode)){host=hunt(a,b,'combat');}
   else if(mode==='ctf'){
    guest=follow(m,b,retreat,'opponent-retreat');
    const enemy=Object.values(m.flags).find(f=>f.team!==a.team),home=Object.values(m.flags).find(f=>f.team===a.team);
    const carrying=enemy.carrier===a.id;host=follow(m,a,carrying?home:enemy,carrying?'flag-return':'flag-pickup');
   }else{
    guest=follow(m,b,retreat,'opponent-retreat');
    const zones=m.objectiveState.zones;
    const target=mode==='holdout'?(zones.find(z=>z.owner!==a.team)??zones[0]):zones[0];
    host=follow(m,a,target,'objective-'+target.id+':'+target.x+':'+target.z);
   }
  }
  stimulus('host',host,m.time>=10&&m.time<32);stimulus('guest',guest);
  if(samples++%20===0)trace.push({wall:new Date().toISOString(),time:m.time,actors:m.actors.map(a=>({id:a.id,x:a.x,y:a.y,z:a.z,health:a.health,deaths:a.deaths})),respawn:{...respawn},race:m.race?{phase:m.race.phase,standings:m.race.racers.map(r=>({id:r.actorId,passed:r.passed,laps:r.completedLaps}))}:null});
 };
 timer=setInterval(()=>{try{tick();}catch(e){tickError=e;}},50);
 await until('ordinary-input completed round',()=>m.over,720000);
 await until('both native results',()=>peers.every(p=>p.log.includes('CANDIDATE_RESULTS ')),20000);
 const state=assertOutcome(m,mode,respawn);
 if(mode==='puma-race')assert.ok(respawn.countdownObserved,'Native clients must join before countdown completes');
 for(const peer of peers){
  const result=JSON.parse(peer.log.split('\n').find(l=>l.startsWith('CANDIDATE_RESULTS ')).slice('CANDIDATE_RESULTS '.length));
  assert.equal(result.hash,permit.data.geometryHash);assert.equal(result.state.overReason,state.overReason);assert.equal(result.state.winner,state.winner);assert.ok(result.sent>30&&result.ack>0);
 }
 assert.ok(wire.some(f=>f.type==='join'));assert.ok(wire.filter(f=>f.type==='input').length>60);
 success=true;
 writeFileSync(resolve(out,'outcome.json'),JSON.stringify({id,mode,success,accepted:false,geometryHash:permit.data.geometryHash,recipeSha:permit.expectedSha,artSha:sha(readFileSync(art)),derivation:derived.records,respawn,state,classification:'two real native peers; ordinary send_input; no actor/objective writes; public registration unchanged'},null,2));
 console.log('CANDIDATE_HOSTED_OK',id,mode,out);
}finally{
 clearInterval(timer);
 for(const p of peers){writeFileSync(resolve(out,p.role+'.log'),p.log);if(!p.closed)p.child.kill('SIGTERM');}
 await Promise.all(peers.map(async p=>{for(let i=0;i<40&&!p.closed;i++)await sleep(50);if(!p.closed){p.child.kill('SIGKILL');await new Promise(r=>p.child.once('close',r));}}));
 for(const socket of game.wss.clients)socket.terminate();await game.close();
 writeFileSync(resolve(out,'wire.json'),JSON.stringify(wire));writeFileSync(resolve(out,'trace.json'),JSON.stringify(trace));
 writeFileSync(resolve(out,'teardown.json'),JSON.stringify({success,accepted:false,peers:peers.map(p=>({role:p.role,pid:p.child.pid,closed:p.closed,code:p.code})),at:new Date().toISOString()}));
}

// ENGINE SLOT REQUIRED. Three isolated native transports, normal-rate Tern
// authority. Graphical window/input/compact review is a separate acceptance.
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {once} from 'node:events';
import {mkdirSync,mkdtempSync,writeFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {createInterface} from 'node:readline';
import {createGameServer} from '../../../port/multiplayer-worlds/derived/game-server.mjs';

assert.equal(process.env.LATTICE_ENGINE_GRANTED,'1','Explicit engine slot grant required');
const binary=process.env.GODOT_BIN;
assert.ok(binary,'Pinned GODOT_BIN required');
assert.match(execFileSync(binary,['--version'],{encoding:'utf8',timeout:5000}),/^4\.5\.2\.stable/);
const base=process.env.LATTICE_EVIDENCE??'/home/mojo/.tmp-on-disk/cocs-expansion-three-lattice-evidence-20261002';
mkdirSync(base,{recursive:true}); const output=mkdtempSync(join(resolve(base),'native-'));
const game=createGameServer({historyPath:null,progressionPath:null});
const children=[], results=[], logs=[]; let stopping=false, configured=false;
let resolveDone,rejectDone;
const done=new Promise((ok,bad)=>{resolveDone=ok;rejectDone=bad;});
// Mark the promise handled while the server opens.
done.catch(()=>{});
function launch(role,room='') {
 const env={...process.env,LP_NUM_THREADS:'1',COCS_CAREER_ROOT:join(output,role,'career')};
 for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=join(output,role,key);mkdirSync(env[key],{recursive:true});}
 const child=spawn(binary,['--headless','--path','godot','--script','res://tests/lattice/expansion_connected.gd','--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,`--role=${role}`,`--room=${room}`],{env,stdio:['ignore','pipe','pipe']});
 children.push(child); child.once('error',rejectDone);
 child.once('exit',code=>{if(!stopping&&code!==0)rejectDone(Error(`${role} exited ${code}`));});
 for(const stream of [child.stdout,child.stderr])createInterface({input:stream}).on('line',line=>{
  if(logs.length>=15000){rejectDone(Error('Log bound exceeded'));return;}
  logs.push(`[${role}] ${line}`);
  if(line.startsWith('EXPANSION_ROOM ')&&role==='host') {game.fixtureRoom=line.slice(15).trim();launch('guest',game.fixtureRoom);}
  if(line==='EXPANSION_LIVE'&&role==='host')launch('spectator',game.fixtureRoom);
  if(line.startsWith('EXPANSION_NATIVE_RESULT ')) {
   try {
    const result=JSON.parse(line.slice(24));results.push(result);
    if(!result.passed)rejectDone(Error(`${role} native checks failed`));
    if(results.length===3)resolveDone();
   } catch(error) {rejectDone(error);}
  }
 });
}
const deadline=setTimeout(()=>rejectDone(Error('Native fixture deadline 45 seconds')),45000);
const setup=setInterval(()=>{
 const room=game.registry.get(game.fixtureRoom);
 if(!configured&&room?.match) {
  for(const actor of room.match.actors){actor.req=200;actor.reqSpent=0;}
  room.match.objectiveState.reqMult=0;room.match.objectiveState.cuts=[];configured=true;
  logs.push('CONTROLLED SOURCE SETUP: actors REQ=200, reqSpent=0, reqMult=0, cuts=[]');
 }
},20);
const interrupt=()=>rejectDone(Error('Interrupted'));
process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
const evidence={passed:false,scope:'three native transport processes, controlled source wallet, no UI/human acceptance'};
try {
 game.server.listen(0,'127.0.0.1');await once(game.server,'listening');
 launch('host');await done;
 assert.equal(results.filter(r=>r.role!=='spectator').length,2);
 assert.notEqual(results.find(r=>r.role==='host').actor,results.find(r=>r.role==='guest').actor);
 evidence.passed=true;
} catch(error) {evidence.error=error.stack;process.exitCode=1;}
finally {
 stopping=true;clearTimeout(deadline);clearInterval(setup);
 await Promise.all(children.map(async child=>{
  if(child.exitCode!==null||child.signalCode!==null)return;
  const exited=once(child,'exit');child.kill('SIGTERM');
  const kill=setTimeout(()=>child.kill('SIGKILL'),2000);
  try {await exited;} finally {clearTimeout(kill);}
 }));
 const closed=game.server.listening?once(game.server,'close'):Promise.resolve();
 const wsClosed=once(game.wss,'close');await game.close();await Promise.all([closed,wsClosed]);
 writeFileSync(join(output,'native.log'),logs.join('\n')+'\n');
 writeFileSync(join(output,'result.json'),JSON.stringify({...evidence,results},null,2)+'\n');
 process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
 console.log(JSON.stringify({output,...evidence,results},null,2));
}

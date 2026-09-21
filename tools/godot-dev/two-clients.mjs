import {createGameServer} from '../../server/game-server.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createInterface} from 'node:readline';
import assert from 'node:assert/strict';
import {verifySource} from '../godot-export/semantic.mjs';
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;
assert.ok(binary,'Set GODOT_BIN');
assert.equal(execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),lock.godot_version);
const game=createGameServer({historyPath:null,progressionPath:null});
const children=[];const results=[];let stopping=false;let timer;
let resolveDone,rejectDone;
const done=new Promise((resolve,reject)=>{resolveDone=resolve;rejectDone=reject;});
function launch(room=''){
 const index=children.length;const env={...process.env};
 for(const [key,suffix] of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]){
  env[key]=resolve('.port-runtime',`client-${index}`,suffix);mkdirSync(env[key],{recursive:true});
 }
 const child=spawn(binary,['--headless','--path','godot','--script','res://tests/protocol/two_clients.gd','--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,...(room?[`--join=${room}`]:[])],{env,stdio:['ignore','pipe','pipe']});
 children.push(child);
 child.once('error',rejectDone);
 child.once('exit',(code)=>{if(!stopping)rejectDone(Error(`Client ${index} exited early: ${code}`));});
 for(const stream of [child.stdout,child.stderr])createInterface({input:stream}).on('line',line=>{
  console.log(`[native ${index}] ${line}`);
  if(line.includes('ERROR:'))rejectDone(Error(line));
  if(index===0&&line.startsWith('PORT_ROOM ')&&children.length===1)launch(line.slice(10).trim());
  if(line.startsWith('PORT_TWO_OK ')){
   if(results[index])return;
   try{results[index]=JSON.parse(line.slice(12));}catch(error){rejectDone(error);return;}
   if(results.filter(Boolean).length===2)resolveDone();
  }
 });
}
const interrupt=()=>rejectDone(Error('Interrupted'));
process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
try{
 await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
 assert.ok((await fetch(`http://127.0.0.1:${game.server.address().port}`,{signal:AbortSignal.timeout(5000)})).ok);
 timer=setTimeout(()=>rejectDone(Error('Two native clients timed out')),25000);
 launch();await done;
 assert.notEqual(results[0].actor_id,results[1].actor_id);
 for(const result of results){assert.equal(result.actors,4);assert.equal(result.both_moved,true);assert.ok(result.ack>15);assert.deepEqual([...result.humans].sort(),results.map(r=>r.actor_id).sort());}
 const report={source_commit:lock.source_commit,godot_version:lock.godot_version,map_id:'meridian-exchange',native_clients:2,bots:2,clock:'normal server rate, loopback only',results};
 writeFileSync('port/reports/two-native-clients.json',JSON.stringify(report,null,2)+'\n');
 console.log('PORT_TWO_NATIVE_CLIENTS_OK');
}finally{
 stopping=true;clearTimeout(timer);
 await Promise.all(children.map(child=>new Promise(resolve=>{if(child.exitCode!==null||child.signalCode!==null)return resolve();child.once('exit',resolve);child.kill('SIGTERM');})));
 await game.close();process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
}

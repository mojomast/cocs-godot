// Unexecuted until the parent explicitly grants the exclusive engine slot.
import {createGameServer} from '../../../server/game-server.mjs';
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const binary=process.env.GODOT_BIN,output=process.env.COCS_REPLAY_EVIDENCE;
assert.ok(binary&&output&&process.env.DISPLAY,'Set GODOT_BIN/COCS_REPLAY_EVIDENCE and run under an approved display');
mkdirSync(output,{recursive:true});
const game=createGameServer({historyPath:null,progressionPath:null});
await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
let left=false,violations=0,inputs=0;const packets=[];
game.wss.on('connection',socket=>socket.on('message',bytes=>{
  const msg=JSON.parse(bytes);packets.push({type:msg.type,afterLeave:left});
  if(msg.type==='input')inputs++;
  if(left)violations++;
}));
const child=spawn(binary,['--audio-driver','Dummy','--path',resolve('godot'),'--script','res://tests/replay/journey.gd','--','--endpoint=ws://127.0.0.1:'+game.server.address().port,'--map=meridian-exchange','--mode=deathmatch'],{env:{...process.env,LP_NUM_THREADS:'1'},stdio:['ignore','pipe','pipe']});
let text='';child.stdout.on('data',bytes=>{const line=bytes.toString();text+=line;process.stdout.write(line);if(text.includes('REPLAY_AUTHORITY_LEFT'))left=true;});child.stderr.on('data',b=>{text+=b;process.stderr.write(b);});
const timeout=setTimeout(()=>child.kill('SIGKILL'),180000);
let code;
try {code=await new Promise((r,j)=>{child.once('exit',r);child.once('error',j);});}
finally {clearTimeout(timeout);game.close();writeFileSync(resolve(output,'native.log'),text);writeFileSync(resolve(output,'wire-summary.json'),JSON.stringify({inputs,afterLeavePackets:violations,packets,exit:code},null,2));}
assert.equal(code,0);assert.ok(inputs>0);assert.ok(left);assert.equal(violations,0);assert.match(text,/REPLAY_NATIVE_DONE/);

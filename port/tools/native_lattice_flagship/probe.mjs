/** Bounded engine-driven World host/Start smoke; not a natural round. */
import {existsSync, mkdirSync, writeFileSync, readFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createGameServer} from '../../../server/game-server.mjs';

const root=resolve(fileURLToPath(new URL('../../../',import.meta.url)));
const marker='/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted';
const options=Object.fromEntries(process.argv.slice(2).filter(x=>x.startsWith('--')&&x.includes('=')).map(x=>x.slice(2).split(/=(.*)/s).slice(0,2)));
if(!existsSync(marker)||!process.env.GODOT_BIN)throw Error('Engine slot and GODOT_BIN required');
if(!['asterion-relay','monsoon-foundry'].includes(options.map)||!['cocs','cocs-coop'].includes(options.mode))throw Error('--map and --mode required');
const lock=JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
const dir=join(root,'port/native-lattice/evidence/flagship',`engine-smoke-${Date.now()}-${randomUUID()}`);mkdirSync(dir,{recursive:true});
const game=createGameServer({historyPath:null,progressionPath:null});
const frames=[];let child=null,exit=null,error=null,closed=false;
try{
 await new Promise((ok,no)=>{game.server.once('error',no);game.server.listen(0,'127.0.0.1',ok)});
 const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
 game.wss.on('connection',socket=>{socket.on('message',raw=>{try{if(frames.length<500)frames.push({direction:'client',frame:JSON.parse(raw.toString())})}catch{}});const send=socket.send;socket.send=function(data,...extra){try{if(frames.length<500)frames.push({direction:'recipient',frame:JSON.parse(data.toString())})}catch{}return send.call(this,data,...extra)}});
 const argv=['--audio-driver','Dummy','--headless','--path','godot','--script','res://tests/lattice/probe_flagship.gd','--',`--endpoint=${endpoint}`,`--map=${options.map}`,`--mode=${options.mode}`,'--bots=2','--time-limit=900'];
 child=spawn(process.env.GODOT_BIN,argv,{cwd:root,stdio:['ignore','pipe','pipe'],detached:true});
 let output='';for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>{if(output.length<1024*1024)output+=chunk.toString()});
 exit=await new Promise((ok,no)=>{const deadline=setTimeout(()=>ok({code:124,signal:'timeout'}),40000);child.once('error',e=>{clearTimeout(deadline);no(e)});child.once('close',(code,signal)=>{clearTimeout(deadline);ok({code,signal})})});
 if(exit.code===124&&child.exitCode===null)try{process.kill(-child.pid,'SIGTERM')}catch{}
 writeFileSync(join(dir,'native.log'),output);writeFileSync(join(dir,'wire.jsonl'),frames.map(f=>JSON.stringify(f)).join('\n')+'\n');
 const reports=output.split('\n').filter(line=>line.startsWith('LATTICE_PROBE ')).map(line=>JSON.parse(line.slice('LATTICE_PROBE '.length)));
 const start=frames.find(f=>f.direction==='recipient'&&f.frame.type==='start')?.frame;
 const pass=exit.code===0&&reports.some(r=>r.status==='active'&&r.map===options.map&&r.mode===options.mode&&r.nodes>0&&r.actor>=0&&r.requested_start)&&!!start;
 writeFileSync(join(dir,'result.json'),JSON.stringify({evidence_class:'engine-smoke',source_commit:lock.source_commit,map:options.map,mode:options.mode,command:[process.env.GODOT_BIN,...argv],exit,reported:reports,source_start:start?{mapId:start.mapId,roundRevision:start.roundRevision,config:start.config}:null,passed:pass,note:'Engine-driven button method; not OS/human input and not a natural result'},null,2));
 if(!pass)process.exitCode=1;
}catch(e){error=String(e.stack??e);process.exitCode=1}finally{
 if(child&&child.exitCode===null&&child.signalCode===null)try{process.kill(-child.pid,'SIGKILL')}catch{}
 if(game){for(const peer of game.wss.clients)peer.terminate();await game.close();closed=!game.server.listening}
 writeFileSync(join(dir,'cleanup.json'),JSON.stringify({server_closed:closed,child_waited:!!exit,error},null,2));
 console.log(`${dir}: ${process.exitCode?'FAIL':'PASS'} (engine smoke only)`);
}

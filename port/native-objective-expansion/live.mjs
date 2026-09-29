#!/usr/bin/env node
// Real normal-rate Room wire, native scene and source timeout/rematch. No source mutation.
import {createGameServer} from '../../server/game-server.mjs';
import {spawn} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {floorAt} from '../../game/core.mjs';

const mode = process.argv.find(x=>x.startsWith('--mode='))?.slice(7);
const map = process.argv.find(x=>x.startsWith('--map='))?.slice(6);
const controlled=process.argv.includes('--controlled-completion');
const valid = mode === 'assault' ? ['tidal-citadel','sunscar-convoy'] : ['meridian-exchange','verdant-reliquary','ember-crucible'];
if (!['uplink','holdout','assault'].includes(mode) || !valid.includes(map)) throw Error('Select an eligible --mode and --map');
const bin = process.env.GODOT_BIN;
if (!bin) throw Error('GODOT_BIN required');
const temp = mkdtempSync('/tmp/opencode/objective-live-');
const env = {...process.env, HOME:temp};
for (const key of ['XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_DATA_HOME']) {env[key]=join(temp,key);mkdirSync(env[key]);}
let game, child, timer, placement, output='', error='', result='unstarted', exit=1, placements=0;
const received=[],sent=[];
try {
  game = createGameServer({historyPath:null,progressionPath:null});
  game.wss.on('connection',socket=>{
    const original=socket.send;
    socket.send=function(data,...extra) {
      const frame=JSON.parse(String(data));
      if (['welcome','lobby','start','results'].includes(frame.type)) sent.push({type:frame.type, winner:frame.state?.winner, reason:frame.state?.overReason, time:frame.state?.time, mode:frame.state?.config?.mode});
      if (frame.type==='snapshot' && (sent.length<50 || frame.seq%120===0)) sent.push({type:'snapshot',seq:frame.seq,ack:frame.acks,time:frame.state?.time,over:frame.state?.over,mode:frame.state?.config?.mode});
      return original.call(this,data,...extra);
    };
    socket.on('message',raw=>{
      const frame=JSON.parse(String(raw));
      if (frame.type!=='input' || received.length<12 || received.length%120===0) received.push({type:frame.type, config:frame.config, mapId:frame.mapId, seq:frame.seq});
    });
  });
  await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
  if (controlled) {
    // Explicit controlled server-side placement for a scoring edge, never
    // evidence of natural human traversal. Room tick/rules/wire remain real.
    placement=setInterval(()=>{
      for (const room of game.registry.rooms.values()) {
        const match=room.match;
        if (!match || match.over || match.config.mode!==mode) continue;
        const actor=match.actors[0], objective=match.objectiveState;
        const zone=mode==='assault'?objective.sectors[objective.active]:mode==='uplink'?objective.zones[0]:objective.zones.find(z=>z.owner!==0);
        if (!actor || !zone) continue;
        Object.assign(actor,{x:zone.x,z:zone.z,y:floorAt(zone.x,zone.z,match.arena)??zone.y,health:100,dead:0,vx:0,vy:0,vz:0,vehicleId:null});
        actor.lastValid={x:actor.x,y:actor.y,z:actor.z};
        placements++;
      }
    },20);
  }
  const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
  const args=['--headless','--audio-driver','Dummy','--path','godot','--script','res://tests/objective_live.gd','--',`--endpoint=${endpoint}`,`--map=${map}`,`--mode=${mode}`,'--bots=0','--round-seconds=60',`--score-limit=${mode==='assault'?3:100}`,...(controlled?['--controlled-completion']:[])];
  child=spawn(bin,args,{env,stdio:['ignore','pipe','pipe']});
  child.stdout.on('data',chunk=>output+=chunk.toString());
  child.stderr.on('data',chunk=>error+=chunk.toString());
  timer=setTimeout(()=>child.kill('SIGTERM'),115000);
  const {code,signal}=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});
  if (code!==0 || signal || !output.includes('OBJECTIVE_LIVE_OK') || /SCRIPT ERROR|ERROR:|Parse Error/.test(output+error)) throw Error(`native exit ${code}/${signal}: ${output.slice(-2600)} ${error.slice(-600)}`);
  if (sent.filter(frame=>frame.type==='start').length<2 || !sent.some(frame=>frame.type==='results')) throw Error('No source results and rematch start on wire');
  result=controlled?'source objective completion/result/rematch accepted (controlled fixture placement)':'source timeout/result/rematch accepted';exit=0;
} catch (failure) { result=failure.stack??String(failure); }
finally {
  clearTimeout(timer);
  clearInterval(placement);
  if (child && child.exitCode===null && child.signalCode===null) {child.kill('SIGTERM');await new Promise(resolve=>child.once('close',resolve));}
  if (game) {for (const socket of game.wss.clients) socket.terminate();await game.close();}
  const path=join('/tmp/opencode',`objective-${mode}-${map}-${randomUUID()}.json`);
  writeFileSync(path,JSON.stringify({mode,map,controlled_fixture_placement:controlled,placements,result,exit,received,sent,stdout:output,stderr:error},null,2));
  rmSync(temp,{recursive:true,force:true});
  console.log(JSON.stringify({mode,map,exit,result,evidence:path}));
  process.exitCode=exit;
}

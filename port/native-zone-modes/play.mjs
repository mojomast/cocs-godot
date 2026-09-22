// Standalone owned convenience entry until the common launcher hook is integrated.
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {resolve} from 'node:path';
const args=process.argv.slice(2), values={map:'meridian-exchange',mode:'domination',bots:'2','round-seconds':'60'},seen=new Set();
for(const arg of args){const m=/^--(map|mode|bots|round-seconds)=(.+)$/.exec(arg);if(!m||seen.has(m[1]))throw Error('Use --map=ID --mode=koth|domination --bots=0..8 --round-seconds=60..180, once each');seen.add(m[1]);values[m[1]]=m[2];}
const catalog=JSON.parse(readFileSync('port/contracts/map-selection.json'));
if(!['koth','domination'].includes(values.mode)||!catalog.maps.find(m=>m.id===values.map)?.supported_modes.includes(values.mode))throw Error('Unsupported locked zone map/mode');
for(const [key,min,max]of [['bots',0,8],['round-seconds',60,180]])if(!/^\d+$/.test(values[key])||+values[key]<min||+values[key]>max)throw Error(`Invalid ${key}`);
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json'));verifySource(lock);
const binary=process.env.GODOT_BIN;if(!binary||execFileSync(binary,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version)throw Error('Pinned GODOT_BIN required');
const temp=mkdtempSync('/tmp/opencode/zone-play-'),env={...process.env};
for(const k of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
const game=createGameServer({historyPath:null,progressionPath:null});let child,done;
const stop=()=>child?.kill('SIGTERM');process.on('SIGINT',stop);process.on('SIGTERM',stop);
try{
  await new Promise((r,j)=>{game.server.once('error',j);game.server.listen(0,'127.0.0.1',r);});
  const endpoint=`ws://127.0.0.1:${game.server.address().port}`;
  console.log(`Native zones: ${values.map} / ${values.mode}; close window to stop owned authority.`);
  child=spawn(binary,['--path','godot','res://zone_modes/demo.tscn','--',`--endpoint=${endpoint}`,...Object.entries(values).map(([k,v])=>`--${k}=${v}`)],{env,stdio:'inherit'});
  done=new Promise((r,j)=>{child.once('error',j);child.once('close',code=>r(code??1));});process.exitCode=await done;
}finally{
  if(child&&child.exitCode===null&&child.signalCode===null){stop();const timer=setTimeout(()=>child.kill('SIGKILL'),2000);await done;clearTimeout(timer);}
  for(const socket of game.wss.clients)socket.terminate();await game.close();rmSync(temp,{recursive:true,force:true});process.off('SIGINT',stop);process.off('SIGTERM',stop);
}

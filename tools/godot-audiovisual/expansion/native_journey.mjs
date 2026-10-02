// Requires explicit slot grant. Controlled INITIAL encounter setup, then the
// unchanged production authority, normal source clock, real native wire client.
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {root} from './telegraph_pack.mjs';
import {createAuthority} from '../../../port/native-campaign/authority.mjs';
import {createCampaignMatch} from '../../../port/native-campaign/match.mjs';
import {deployEncounter} from '../../../port/native-campaign/enemies.mjs';
if(process.env.THREE_AUDIO_ENGINE_GRANT!=='1') throw Error('Explicit engine slot grant required');
const driver=process.env.AUDIO_DRIVER||'PulseAudio';
if(driver==='Dummy') throw Error('Native recording journey requires a real mixer driver');
const out=process.env.AUDIO_EVIDENCE_DIR||'/home/mojo/.tmp-on-disk/cocs-expansion-three-audio-evidence-20261002/native';
fs.mkdirSync(out,{recursive:true});
const frames=[];
const authority=createAuthority({random:()=>.5,matchFactory:options=>{
 const match=createCampaignMatch(options);
 // Trusted setup seam; records must not be described as an ordinary-input run.
 const point=options.mapData.campaign.anchors['encounter-1'];
 Object.assign(match.actors[0],{...point,protection:90,lastValid:{...point}});
 deployEncounter(match,match.modeState,{roster:{mortar:1,warden:1}},point);
 return match;
},observe:r=>{
 if(r.direction==='out'&&['events','snapshot','start'].includes(r.frame?.type)) frames.push(r.frame);
}});
await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
const binary=process.env.GODOT_BIN||'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const args=['--path',path.join(root,'godot'),'--audio-driver',driver,'--script','res://tests/audio_expansion/wire_journey.gd','--',`--endpoint=ws://127.0.0.1:${authority.server.address().port}`,`--audio-evidence=${out}`];
let output='',timedOut=false;
const child=spawn(binary,args,{cwd:root,env:{...process.env,LP_NUM_THREADS:'1'}});
child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
const timer=setTimeout(()=>{timedOut=true;child.kill('SIGKILL');},65000);
const code=await new Promise(resolve=>{child.once('exit',resolve);child.once('error',e=>{output+=e.stack;resolve(-1);});});
clearTimeout(timer);
await authority.close();
fs.writeFileSync(path.join(out,'native.log'),output);
fs.writeFileSync(path.join(out,'wire.json'),JSON.stringify({controlledInitialSetup:true,normalClock:true,timedOut,code,frames},null,2));
const tells=frames.flatMap(f=>f.type==='events'?f.items:[]).filter(e=>e.type==='enemy-telegraph');
const passed=code===0&&!timedOut&&tells.length>0&&output.includes('THREAT_WIRE_OK')&&!/SCRIPT ERROR|ERROR:/.test(output);
console.log({passed,code,timedOut,sourceWindups:tells.length,out});
process.exitCode=passed?0:1;

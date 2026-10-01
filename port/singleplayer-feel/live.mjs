// Run ONLY after obtaining the centrally serialized native-engine slot.
// No matchFactory, control server, actor injection or synthetic combat events.
import {spawn,execFileSync} from 'node:child_process';
import {mkdir,mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join,resolve} from 'node:path';
import {createAuthority} from '../native-campaign/authority.mjs';
import {createAuthority as createHordeAuthority} from '../native-horde/authority.mjs';

const root=fileURLToPath(new URL('../../',import.meta.url));
const args=process.argv.slice(2);
const horde=args.includes('--horde');
if(!args.includes('--run-native'))throw Error('Requires explicit --run-native after the engine-slot grant');
const outputArg=args.find(a=>a.startsWith('--output='));
const base=resolve(outputArg?.slice(9)||'/home/mojo/.tmp-on-disk/cocs-singleplayer-feel-evidence-20261001');
await mkdir(base,{recursive:true});
const output=await mkdtemp(join(base,'live-'));
const runtime=await mkdtemp('/tmp/opencode/campaign-feel-settings-');
console.log('CAMPAIGN_FEEL_LIVE_OUTPUT',output);
const baseline=execFileSync('git',['show','6e2c6a32:godot/world/audio_feedback.gd'],{cwd:root,encoding:'utf8'});
await writeFile(join(output,'audio_before.gd'),baseline.replace('class_name PortAudioFeedback','# Published-baseline comparison, diagnostic only'));
let seed=42,child,done,timer,log='',result,ui;
const journal=[],commands=[],shots=new Map();let snapshotCount=0;
const observe=record=>{
  const frame=record.frame;if(!frame)return;
  if(record.direction==='in'&&frame.type==='solo-cheat')commands.push(frame);
  if(record.direction==='out'&&frame.type==='events')for(const event of frame.items){
    if(['shot','launch'].includes(event.type)&&event.actor===0)shots.set(event.weapon,(shots.get(event.weapon)||0)+1);
  }
  if(journal.length>=20000)return;
  if(frame.type==='snapshot'){
    if(++snapshotCount%6!==0)return;
    const p=frame.state.actors.find(a=>a.id===0);
    journal.push({direction:'out',type:'snapshot',seq:frame.seq,inputEpoch:frame.inputEpoch,sourceTime:frame.state.time,acks:frame.acks,
      player:p?{x:p.x,y:p.y,z:p.z,vx:p.vx,vy:p.vy,vz:p.vz,health:p.health,armor:p.armor,weapon:p.weapon,shots:p.shots,ammo:p.ammo}:null,
      cheats:frame.state.soloCheats,enemies:frame.state.campaign?.enemiesRemaining??frame.state.singleplayer?.enemiesAlive});
  }else journal.push(record);
};
const authority=horde?createHordeAuthority({debug:false,observe}):createAuthority({difficulty:'normal',random:()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296),observe});
try{
  await new Promise((resolve,reject)=>{authority.server.once('error',reject);authority.server.listen(0,'127.0.0.1',resolve);});
  const env={...process.env,LP_NUM_THREADS:'1'};
  for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=join(runtime,key);await mkdir(env[key]);}
  const command=['--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','960x600','--path',join(root,'godot'),
    '--script',horde?'res://tests/campaign/feel_live_horde.gd':'res://tests/campaign/feel_live.gd','--',horde?'--map=meridian-exchange':'--map=rootfall-verge',horde?'--mode=horde':'--mode=campaign','--difficulty=normal',
    `--endpoint=ws://127.0.0.1:${authority.server.address().port}${horde?'':'/native-campaign'}`,`--feel-output=${output}`];
  await writeFile(join(output,'invocation.json'),JSON.stringify({command,scriptedInput:true,actorStateInjection:false,naturalHumanPlaythrough:false},null,2));
  done=new Promise((resolve,reject)=>{
    child=spawn(process.env.GODOT_BIN||'godot',command,{cwd:root,env,stdio:['ignore','pipe','pipe']});
    child.stdout.on('data',b=>{log+=b;});child.stderr.on('data',b=>{log+=b;});
    child.once('error',reject);child.once('exit',(code,signal)=>resolve({code,signal}));
    timer=setTimeout(()=>child.kill('SIGKILL'),210000);
  });
  result=await done;
  try{ui=JSON.parse(await readFile(join(output,'live-report.json'),'utf8'));}catch{}
  const required=horde?['pause','invulnerable','weapons','clear']:['pause','invulnerable','unlimitedAmmo','flight','weapons','heal','clear'];
  const wireOK=required.every(action=>commands.some(c=>c.action===action))&&(horde||shots.size===10)&&commands.filter(c=>c.action==='pause').length>=(horde?2:4);
  const passed=result.code===0&&ui?.passed===true&&wireOK&&!/SCRIPT ERROR|^ERROR:/m.test(log);
  await writeFile(join(output,'acceptance.json'),JSON.stringify({passed,result,wireOK,commands,shots:Object.fromEntries(shots),ui,
    audioPlayback:'Dummy device; generated real-event samples exported for listening, no human auditory acceptance',
    actorStateInjection:false,naturalHumanPlaythrough:false,renderedPerformanceAcceptance:false},null,2));
  if(!passed)process.exitCode=1;
  console.log('CAMPAIGN_FEEL_LIVE_COMPLETE',JSON.stringify({passed,output,result,wireOK,failures:ui?.failures}));
}finally{
  clearTimeout(timer);
  if(child&&child.exitCode===null&&child.signalCode===null)child.kill('SIGKILL');
  if(done)await done.catch(()=>{});
  await authority.close();
  await writeFile(join(output,'godot.log'),log);
  await writeFile(join(output,'authority-journal.json'),JSON.stringify(journal,null,2));
  await rm(runtime,{recursive:true,force:true});
}

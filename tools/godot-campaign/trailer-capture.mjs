#!/usr/bin/env node
// Prepare deterministic replay, then render only with the explicitly granted slot.
import {readFile,mkdir,open,writeFile,readdir} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
const root=fileURLToPath(new URL('../../',import.meta.url));
const args=process.argv.slice(2),opt=k=>args.find(a=>a.startsWith(`--${k}=`))?.slice(k.length+3);
if(args.some(a=>!['output','shot','frames'].some(k=>a.startsWith(`--${k}=`))&&!['--render','--prepare','--slot-granted','--resume'].includes(a)))throw Error('Unknown trailer option');
const manifest=JSON.parse(await readFile(new URL('./trailer.json',import.meta.url)));
const total=manifest.shots.reduce((n,s)=>n+s.seconds*manifest.fps,0);
if(total>1440||manifest.fps!==24)throw Error('Frame budget exceeded');
if(!opt('output'))throw Error('--output=/absolute/evidence/directory required');
const out=resolve(opt('output'));
if(out===resolve(root)||out.startsWith(resolve(root)+'/'))throw Error('Evidence must live outside repository');
const shots=manifest.shots.filter(s=>!opt('shot')||s.id===opt('shot'));
if(!shots.length)throw Error('Unknown shot');
const limit=opt('frames')?Number(opt('frames')):0;
if(!Number.isSafeInteger(limit)||limit<0||limit>1440)throw Error('Invalid frame limit');
if(args.includes('--render')&&!args.includes('--slot-granted'))throw Error('Rendering requires the exclusive heavy-slot grant');
if(!args.includes('--prepare')&&!args.includes('--render'))throw Error('Choose --prepare and/or --render');
await mkdir(out,{recursive:true});
await writeFile(join(out,'edit-manifest.json'),JSON.stringify(manifest,null,2));
for(const shot of shots){
 const directory=join(out,shot.id), replay=join(directory,'replay.jsonl');
 await mkdir(directory,{recursive:true});
 if(args.includes('--prepare')){
  const {createTrailerFixture}=await import('./trailer-fixture.mjs');
  const fixture=createTrailerFixture(shot,manifest.seed),file=await open(replay,'w');
  const hash=createHash('sha256');let pets=0,damage=0,melee=0,tells=0;
  const interactions=[];
  const lines=async value=>{const line=JSON.stringify(value)+'\n';hash.update(line);await file.write(line);};
  try{
   await lines(fixture.header);
   for(let frame=0;frame<shot.seconds*manifest.fps;frame++){
    const record=fixture.step(frame,manifest.fps);
    if(record.state.campaign.story.pets>pets)interactions.push({frame,seconds:frame/manifest.fps,
      input:record.input,appliedSeq:record.acks[0],pets:record.state.campaign.story.pets,
      reactionSerial:record.state.campaign.story.entities.find(e=>e.kind==='puppy')?.reactionSerial});
    pets=Math.max(pets,record.state.campaign.story.pets);
    for(const event of record.events){
     if(event.type==='damage'&&event.source===0&&event.actor!==0&&event.amount>0)damage++;
     if(event.type==='melee'&&event.actor===0&&event.outcome==='hit')melee++;
     if(event.type==='enemy-telegraph'&&event.kind==='artillery')tells++;
    }
    await lines(record);
   }
  }finally{await file.close();}
  const receipt={shot:shot.id,frames:shot.seconds*manifest.fps,sha256:hash.digest('hex'),pets,damage,melee,tells,interactions,
   scripted:true,networkCapture:false,authority:'production CampaignMatch + validated InputBuffer, offline fixed-step',status:'requires visual review'};
  await writeFile(join(directory,'receipt.json'),JSON.stringify(receipt,null,2));
  if(shot.kind==='pet'&&pets<1)throw Error('Patch E input was not accepted; inspect replay serial/ACK');
  if(['combat','melee'].includes(shot.kind)&&damage<1)throw Error(`${shot.id}: no actual damage; staging must be repaired`);
  if(shot.kind==='melee'&&melee<1)throw Error('No actual melee event');
  if(shot.kind==='artillery'&&tells<1)throw Error('No actual artillery danger ring');
 }
 if(args.includes('--render')){
  const pngs=join(directory,'frames');await mkdir(pngs,{recursive:true});
  if(args.includes('--resume')){
   const prior=await readFile(join(directory,'godot.log'),'utf8').catch(()=> '');
   const count=(await readdir(pngs)).filter(n=>/^\d{6}\.png$/.test(n)).length;
   if(count===shot.seconds*manifest.fps&&prior.includes(`frames=${count}`)&&prior.includes('TRAILER_CAPTURE_OK')&&!/SCRIPT ERROR|^ERROR:/m.test(prior)){
    console.log('TRAILER_SHOT_RESUMED',shot.id);continue;
   }
  }
  const command=['--path',join(root,'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--fixed-fps','24',
   '--resolution','960x540','--script',join(root,'godot/tests/campaign/trailer_capture.gd'),'--',
   `--map=${shot.map}`,'--mode=campaign','--mute','--endpoint=ws://127.0.0.1:1/native-campaign',
   `--trailer-source=${replay}`,`--trailer-output=${pngs}`,`--trailer-limit=${limit}`];
  await writeFile(join(directory,'invocation.json'),JSON.stringify(command,null,2));
  const log=await open(join(directory,'godot.log'),'w');
  try{await new Promise((done,fail)=>{
   const child=spawn(process.env.GODOT_BIN||'godot',command,{cwd:root,stdio:['ignore',log.fd,log.fd]});
   const timer=setTimeout(()=>child.kill('SIGKILL'),10*60*1000);
   child.on('error',e=>{clearTimeout(timer);fail(e);});child.on('exit',code=>{clearTimeout(timer);code===0?done():fail(Error(`Godot exited ${code}`));});
  });}finally{await log.close();}
  const text=await readFile(join(directory,'godot.log'),'utf8');
  if(!text.includes('TRAILER_CAPTURE_OK')||/SCRIPT ERROR|^ERROR:/m.test(text))throw Error(`${shot.id}: Godot errors; inspect log before editing`);
 }
 console.log('TRAILER_SHOT_READY',shot.id,directory);
}

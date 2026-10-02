#!/usr/bin/env node
import {readFile,writeFile,mkdir,open} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {manifest} from './manifest.mjs';
import {root,plan,sha256,outside,verifyFrames} from './contracts.mjs';
import {createFixture} from './fixture.mjs';
import {runProcess} from './process.mjs';
const json=(path,value)=>writeFile(path,JSON.stringify(value,null,2)+'\n',{flag:'wx'});

export async function prepare(out,p) {
  await mkdir(out,{recursive:true});
  await json(join(out,'plan.json'),p); // Exclusive marker: a failed attempt cannot be overwritten.
  for(const shot of p.shots) {
    const directory=join(out,shot.id);await mkdir(directory);
    const fixture=createFixture(shot,p.seed),file=await open(join(directory,'replay.jsonl'),'wx');
    const header={...fixture.header,shot,provenance:{revision:p.provenance.revision,runtimeIndexSHA256:p.provenance.runtimeIndexSHA256}};
    const summary={shot:shot.id,frames:0,eventCounts:{},damage:0,melee:0,pets:0,airborneFrames:0,distance:0,sourceClockHz:60,outputTimelineFPS:p.fps,
      networkCapture:false,humanInput:false,setup:header.setup,captions:[],status:'source records only; native rendering pending'};
    const {createHash}=await import('node:crypto');const hash=createHash('sha256');let previous;
    const line=async value=>{const text=JSON.stringify(value)+'\n';hash.update(text);await file.write(text);};
    try {
      await line(header);
      for(let i=0;i<shot.seconds*p.fps;i++) {
        const record=fixture.step(i,p.fps),actor=record.state.actors[0];
        summary.frames++;
        if(previous)summary.distance+=Math.hypot(actor.x-previous.x,actor.y-previous.y,actor.z-previous.z);
        previous=actor;
        if(Math.abs(actor.vy??0)>.1)summary.airborneFrames++;
        summary.pets=Math.max(summary.pets,record.state.campaign.story.pets);
        const caption=record.state.campaign.story.caption;
        if(caption&&!summary.captions.some(c=>c.id===caption.id))summary.captions.push(caption);
        for(const e of record.events){summary.eventCounts[e.type]=(summary.eventCounts[e.type]??0)+1;
          if(e.type==='damage'&&e.source===0&&e.amount>0)summary.damage++;
          if(e.type==='melee'&&e.actor===0&&e.outcome==='hit')summary.melee++;}
        await line(record);
      }
    } finally {await file.close();}
    summary.sha256=hash.digest('hex');
    await json(join(directory,'receipt.json'),summary);
    if(shot.kind==='traverse'&&summary.distance<8)throw Error(`${shot.id}: traversal failed`);
    if(shot.jump&&summary.airborneFrames<1)throw Error(`${shot.id}: jump did not leave terrain`);
    if(shot.kind==='pet'&&summary.pets<1)throw Error('Missing accepted Patch input');
    if(shot.kind==='npc'&&!summary.captions.some(c=>c.speaker.toLowerCase()===shot.subject))throw Error(`${shot.id}: source comms missing`);
    if(['played-combat','combat','melee'].includes(shot.kind)&&summary.damage<1)throw Error(`${shot.id}: no source damage`);
    if(shot.kind==='melee'&&summary.melee<1)throw Error('Missing source melee hit');
    if(shot.kind==='artillery'&&!(summary.eventCounts['enemy-telegraph']>0&&summary.eventCounts['enemy-artillery']>0))throw Error('Missing source artillery/tell');
    console.log('SOURCE_READY',shot.id,summary.frames,`damage=${summary.damage}`,`distance=${summary.distance.toFixed(2)}`);
  }
  await exportAttract(out,p);
}

export async function exportAttract(out,p) {
  const clips=[],audit=[];
  for(const shot of p.shots.filter(s=>s.menu)) {
    const directory=join(out,shot.id),bytes=await readFile(join(directory,'replay.jsonl'));
    const receipt=JSON.parse(await readFile(join(directory,'receipt.json')));
    if(sha256(bytes)!==receipt.sha256)throw Error('Replay changed before menu export');
    const [header,...records]=bytes.toString().trim().split('\n').map(JSON.parse),frames=[];
    let events=0;
    for(let i=0;i<records.length;i+=2){const group=records.slice(i,i+2),last=group.at(-1),items=group.flatMap(r=>r.events);events+=items.length;
      frames.push({t:i/p.fps,state:{time:last.state.time,actors:last.state.actors,campaign:last.state.campaign},events:items});}
    if(frames.some(f=>f.events.length>48||f.state.actors.length>24))throw Error('Menu public snapshot exceeds existing bounds');
    // Scene-local focus, not the old distant overview. Terrain stays a bounded crop.
    const focus=shot.path?Object.fromEntries(['x','y','z'].map((k,i)=>[k,shot.path.target[i]])):header.focus;
    clips.push({id:shot.id,map:shot.map,kind:shot.kind==='played-combat'?'combat':shot.kind,camera:'orbit',duration:shot.seconds,focus,frames});
    audit.push({id:shot.id,sha256:receipt.sha256,events,frames:frames.length});
  }
  const data={version:1,fps:12,provenance:{scripted:true,authorityRevision:p.provenance.revision,
    description:'V3 recorded public campaign snapshots; controlled setup/validated inputs; no live authority. Candidate pending native acceptance.',
    runtimeIndexSHA256:p.provenance.runtimeIndexSHA256},clips};
  const bytes=JSON.stringify(data)+'\n';
  if(Buffer.byteLength(bytes)>4*1024*1024)throw Error('Menu replay exceeds conservative 4 MiB budget');
  await writeFile(join(out,'attract-candidate.json'),bytes,{flag:'wx'});
  await json(join(out,'attract-audit.json'),{bytes:Buffer.byteLength(bytes),sha256:sha256(bytes),clips:audit,
    install:'Only after native candidate/menu lifecycle acceptance; parent owns production installation'});
}

async function verifyPlan(out) {
  const saved=JSON.parse(await readFile(join(out,'plan.json'))),current=await plan(manifest);
  if(saved.manifestSHA256!==current.manifestSHA256||saved.provenance.runtimeIndexSHA256!==current.provenance.runtimeIndexSHA256||JSON.stringify(saved.provenance.files)!==JSON.stringify(current.provenance.files))throw Error('Source/assets changed since preparation; use a new evidence directory');
  return saved;
}
export async function capture(out,p,{shotID,godot,deadlineSeconds=1800,budgetSeconds=14400}={}) {
  const shots=p.shots.filter(s=>!shotID||s.id===shotID);
  if(!shots.length)throw Error('Unknown shot');
  const started=Date.now();
  for(const shot of shots) {
    const remaining=budgetSeconds*1000-(Date.now()-started);
    if(remaining<=0)throw Error('Overall capture deadline reached');
    const directory=join(out,shot.id),replay=join(directory,'replay.jsonl');
    const receipt=JSON.parse(await readFile(join(directory,'receipt.json')));
    if(sha256(await readFile(replay))!==receipt.sha256)throw Error(`${shot.id}: replay hash changed`);
    await mkdir(join(directory,'frames')); // Never silently resume/overwrite old frames.
    const args=['--path',join(root,'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy',
      '--fixed-fps',String(p.fps),'--resolution','1280x720','--script','res://tests/cinematic_v3/capture.gd','--',
      `--map=${shot.map}`,'--mode=campaign','--mute','--endpoint=ws://127.0.0.1:1/native-campaign',
      `--trailer-source=${replay}`,`--trailer-output=${join(directory,'frames')}`];
    await json(join(directory,'invocation.json'),{godot,args,environment:{LP_NUM_THREADS:1},deadlineSeconds,budgetSeconds});
    await runProcess(godot,args,{cwd:root,log:join(directory,'godot.log'),timeoutMs:Math.min(deadlineSeconds*1000,remaining)});
    const log=await readFile(join(directory,'godot.log'),'utf8');
    if(!log.includes(`CINEMATIC_V3_OK ${shot.id} frames=${shot.seconds*p.fps}`)||/SCRIPT ERROR|^ERROR:/m.test(log))throw Error(`${shot.id}: native failure; retain logs`);
    await json(join(directory,'capture-receipt.json'),await verifyFrames(directory,shot,p.fps));
  }
}
export async function main(args=process.argv.slice(2)) {
  const flags=new Set(['--plan','--prepare','--capture','--menu-check','--edit-plan','--edit','--slot-granted']);
  const keys=['output','shot','godot','deadline-seconds','budget-seconds'];
  for(const a of args)if(!flags.has(a)&&!keys.some(k=>a.startsWith(`--${k}=`)))throw Error(`Unknown option ${a}`);
  const value=k=>args.find(a=>a.startsWith(`--${k}=`))?.slice(k.length+3);
  const modes=args.filter(a=>flags.has(a)&&a!=='--slot-granted');
  if(modes.length!==1)throw Error('Choose exactly one --plan / --prepare / --capture / --menu-check / --edit-plan / --edit');
  if(['--capture','--menu-check','--edit'].includes(modes[0])&&!args.includes('--slot-granted'))throw Error('Explicit exclusive heavy-slot grant required');
  const p=await plan(manifest);
  if(modes[0]==='--plan'){console.log(JSON.stringify({...p,provenance:{...p.provenance,runtimeIndex:'See prepare plan.json for exact tracked runtime inventory'}},null,2));return;}
  if(!value('output'))throw Error('--output=/absolute/new/evidence/directory required');
  const out=outside(value('output'));
  if(modes[0]==='--prepare')return prepare(out,p);
  const saved=await verifyPlan(out);
  if(modes[0]==='--menu-check') {
    const directory=join(out,'menu-native');await mkdir(directory);
    const godot=value('godot')??process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
    await runProcess(godot,['--path',join(root,'godot'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x800',
      '--script','res://tests/cinematic_v3/attract_candidate.gd'],{cwd:root,log:join(directory,'godot.log'),timeoutMs:600000,
      env:{COCS_ATTRACT_EVIDENCE:directory,COCS_ATTRACT_CANDIDATE:join(out,'attract-candidate.json')}});
    const log=await readFile(join(directory,'godot.log'),'utf8');
    if(!/CINEMATIC_V3_ATTRACT checks=\d+ failures=0/.test(log)||/SCRIPT ERROR|^ERROR:/m.test(log))throw Error('Native menu candidate failed; preserve evidence');
    return;
  }
  if(modes[0]==='--capture'){
    const number=(key,fallback)=>{const n=Number(value(key)??fallback);if(!Number.isFinite(n)||n<1||n>28800)throw Error('Invalid wall deadline');return n;};
    return capture(out,saved,{shotID:value('shot'),godot:value('godot')??process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64',
      deadlineSeconds:number('deadline-seconds',1800),budgetSeconds:number('budget-seconds',14400)});
  }
  const {edit}=await import('./edit.mjs');return edit(out,saved,modes[0]==='--edit');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)main().catch(e=>{console.error(e.stack);process.exitCode=1;});

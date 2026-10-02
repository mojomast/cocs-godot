import {mkdir,writeFile,readFile,readdir} from 'node:fs/promises';
import {join} from 'node:path';
import {root,sha256,verifyFrames} from './contracts.mjs';
import {runProcess} from './process.mjs';
import {readProof,writeProof} from './proof.mjs';
import {assetInputs,assertAssetIdentity} from './assets.mjs';
import {checkBoundIdentity} from './receipt.mjs';
// Picture is native PNGs only. Music is the existing original, phase-locked 80 BPM score.
// No synthetic gameplay, frame interpolation, victory cards or pending-map insertions.
export async function edit(out,p,execute=false) {
  if(execute){await checkBoundIdentity(p);assertAssetIdentity(p.assets,assetInputs({strict:true}));}
  const work=join(out,execute?'edit':'edit-plan');await mkdir(work);
  const commands=[],timeline=[],cuts=[],clips=[];
  let start=0;
  const run=async(command,args,label)=>{
    const item={command,args,label,deadlineSeconds:1800};commands.push(item);
    await writeFile(join(work,'commands.json'),JSON.stringify(commands,null,2));
    if(execute)await runProcess(command,args,{cwd:root,log:join(work,`${String(commands.length).padStart(3,'0')}-${label}.log`),timeoutMs:1800000});
    return join(work,`${String(commands.length).padStart(3,'0')}-${label}.log`);
  };
  const ff=async(args,label)=>run('ffmpeg',['-hide_banner','-nostdin','-n','-threads','1','-filter_threads','1','-filter_complex_threads','1',...args],label);
  const esc=path=>path.replaceAll('\\','\\\\').replaceAll(':','\\:').replaceAll("'","'\\''");
  const font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  for(const shot of p.shots) {
    const directory=join(out,shot.id);
    if(execute){await verifyFrames(directory,shot,p.fps);const proof=await readProof(join(directory,'capture-receipt.json'),'native-shot');
      if(proof.manifestSHA256!==p.manifestSHA256||proof.assetSHA256!==p.assets.sha256)throw Error('Native capture identity differs from edit');}
    const text=join(work,`${shot.id}-title.txt`),credit=join(work,`${shot.id}-credit.txt`);
    await writeFile(text,shot.text||'');
    await writeFile(credit,shot.kind==='traverse'||shot.kind==='played-combat'
      ?'RENDERED IN-ENGINE / SCRIPTED SOURCE INPUTS / CONTROLLED SETUP'
      :'RENDERED IN-ENGINE / STAGED CAMERA AND SOURCE SETUP');
    const filters=[];
    if(!shot.hud){filters.push('drawbox=x=0:y=0:w=iw:h=34:color=black:t=fill','drawbox=x=0:y=ih-34:w=iw:h=34:color=black:t=fill');
      if(shot.text)filters.push(`drawtext=fontfile='${esc(font)}':textfile='${esc(text)}':fontsize=25:fontcolor=white:shadowcolor=black:shadowx=2:shadowy=2:x=(w-tw)/2:y=56`);}
    // Credit on top of FP footage, leaving bottom gameplay health/ammo untouched.
    filters.push(`drawtext=fontfile='${esc(font)}':textfile='${esc(credit)}':fontsize=12:fontcolor=white:box=1:boxcolor=black@0.65:x=12:y=${shot.hud?'5':'h-24'}`);
    const clip=join(work,`${shot.id}.mp4`);
    await ff(['-framerate',String(p.fps),'-start_number','0','-i',join(directory,'frames/%06d.png'),'-frames:v',String(shot.seconds*p.fps),
      '-vf',filters.join(','),'-an','-c:v','libx264','-preset','fast','-crf','16','-pix_fmt','yuv420p','-threads','1',clip],shot.id);
    clips.push(clip);cuts.push(start*p.fps,(start+shot.seconds)*p.fps-1);
    timeline.push({id:shot.id,start,end:start+shot.seconds,evidence:shot.evidence,setup:(JSON.parse(await readFile(join(directory,'receipt.json')))).setup,
      camera:shot.camera,crop:shot.hud?'none; full 1280x720 HUD':'34px presentation bars; full source retained',transition:'hard cut on 80 BPM bar'});
    start+=shot.seconds;
  }
  const list=join(work,'concat.txt');await writeFile(list,clips.map(c=>`file '${c.replaceAll("'","'\\''")}'`).join('\n')+'\n');
  const picture=join(work,'picture.mp4');
  await ff(['-f','concat','-safe','0','-i',list,'-c','copy',picture],'concat');
  const input=[],filters=[];
  // Original 48s phrase loops on its sixteen-bar boundary at 48s; no tempo change.
  const gain=['0.50','0.06+0.22*clip((t-21)/3,0,1)','0.04+0.22*clip((t-39)/3,0,1)','0.24*clip((t-63)/3,0,1)'];
  for(const [i,name] of ['strings','motion','brass','warden'].entries()) {
    input.push('-stream_loop','-1','-i',join(root,p.music.path,`${name}.wav`));
    filters.push(`[${i}:a]atrim=duration=${p.duration},asetpts=PTS-STARTPTS,volume='${gain[i]}':eval=frame[a${i}]`);
  }
  filters.push(`[a0][a1][a2][a3]amix=inputs=4:normalize=0:duration=shortest,afade=t=in:d=0.5,afade=t=out:st=${p.duration-3}:d=3[mix]`);
  const mix=join(work,'score-mix.wav');
  await ff([...input,'-filter_complex',filters.join(';'),'-map','[mix]','-ar','48000','-c:a','pcm_s24le',mix],'score');
  const base=`loudnorm=I=${p.music.integratedLUFS}:TP=${p.music.encodeTruePeakDBTP}:LRA=9`;
  const measured=await ff(['-i',mix,'-af',base+':print_format=json','-f','null','-'],'measure');
  let norm=base;
  if(execute){const text=await readFile(measured,'utf8'),values=JSON.parse(text.slice(text.lastIndexOf('{'),text.lastIndexOf('}')+1));
    for(const [key,field]of [['measured_I','input_i'],['measured_TP','input_tp'],['measured_LRA','input_lra'],['measured_thresh','input_thresh'],['offset','target_offset']]){
      if(!Number.isFinite(Number(values[field])))throw Error('Invalid music loudness');norm+=`:${key}=${values[field]}`;}
    norm+=':linear=true';}
  const master=join(work,'quiet-relay-v3-master.mkv'),publicVideo=join(work,'quiet-relay-trailer-v3.mp4');
  await ff(['-i',picture,'-i',mix,'-map','0:v:0','-map','1:a:0','-c:v','copy','-af',norm,'-ar','48000','-c:a','pcm_s24le','-t',String(p.duration),master],'master');
  await ff(['-i',master,'-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart',publicVideo],'delivery');
  const probe=await run('ffprobe',['-v','error','-show_format','-show_streams','-of','json',publicVideo],'probe');
  await ff(['-v','error','-i',publicVideo,'-f','null','-'],'decode');
  const loudness=await ff(['-i',publicVideo,'-af',base+':print_format=json','-f','null','-'],'delivery-loudness');
  await ff(['-i',publicVideo,'-vf',`select='${cuts.map(n=>`eq(n,${n})`).join('+')}',scale=320:180,tile=4x8`,'-frames:v','1',join(work,'cut-continuity.png')],'contact-sheet');
  const result={executed:execute,timeline,sourceFrames:p.frames,encodedFPS:p.fps,captureCadence:'See per-shot cadence.jsonl and capture-receipt.json; offline rendered, not hardware FPS',
    audio:'Original game score only; no live captured effects/comms audio claimed. Source captions remain visible.',
    musicLicense:p.provenance.music.sources,normalization:execute?'measured two-pass':'execution inserts measured values',
    master:'H264 CRF16 picture + PCM24 audio; lossless source PNGs retained separately',
    pending:['Inspect cut-continuity.png and every shot for occlusion/robot motion/weather/cast/HUD','Listen on speakers/headphones at normal level','Inspect native menu wide/compact loop and lifecycle evidence','Parent publication approval; preserve v2']};
  if(execute) {
    const data=JSON.parse(await readFile(probe,'utf8')),video=data.streams.find(s=>s.codec_type==='video');
    if(video.width!==p.width||video.height!==p.height||Math.abs(Number(data.format.duration)-p.duration)>.15)throw Error('Delivery dimensions/duration mismatch');
    const text=await readFile(loudness,'utf8'),values=JSON.parse(text.slice(text.lastIndexOf('{'),text.lastIndexOf('}')+1));
    if(!Number.isFinite(Number(values.input_i))||Math.abs(Number(values.input_i)-p.music.integratedLUFS)>1||Number(values.input_tp)>p.music.truePeakDBTP)throw Error('Delivery loudness/true peak outside target');
    result.loudness=values;result.publicSHA256=sha256(await readFile(publicVideo));
  }
  await writeFile(join(work,'edit-receipt.json'),JSON.stringify(result,null,2));
  if(execute){
    await checkBoundIdentity(p);assertAssetIdentity(p.assets,assetInputs({strict:true}));
    const paths=Object.fromEntries((await readdir(work)).map(name=>[name,join(work,name)]));
    await writeProof(join(work,'production-proof.json'),{kind:'encoded-master',status:'passed',executed:true,
      manifestSHA256:p.manifestSHA256,assetSHA256:p.assets.sha256,checks:['full-decode','dimensions','duration','loudness','true-peak','cut-sheet'],
      pendingHumanReview:true},paths);
  }
  console.log(execute?'EDIT_RENDERED_REVIEW_PENDING':'EDIT_PLAN_ONLY',work);
}

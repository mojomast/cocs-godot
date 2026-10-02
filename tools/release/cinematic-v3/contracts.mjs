import {readFile,readdir} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {join,resolve,sep} from 'node:path';
import {loadCampaignMap} from '../../../port/native-campaign/maps.mjs';
import {floorAt,obstructed} from '../../../port/native-campaign/core.generated.mjs';
export const root=fileURLToPath(new URL('../../../',import.meta.url));
export const sha256=bytes=>createHash('sha256').update(bytes).digest('hex');
export const git=(...args)=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
export function outside(path) {
  const out=resolve(path);
  if(out===resolve(root)||out.startsWith(resolve(root)+sep))throw Error('Evidence must be outside checkout');
  return out;
}
export function validateManifest(m) {
  if(m.version!==3||m.fps!==24||m.width!==1280||m.height!==720)throw Error('Unsupported capture contract');
  if(m.optionalAssets.length)throw Error('Optional map assets require a separately reviewed adapter, parent approval, matching geometry/art SHA256 and native provenance; none accepted by this baseline');
  const duration=m.shots.reduce((n,s)=>n+s.seconds,0),ids=new Set();
  if(duration<60||duration>90)throw Error('Trailer must be 60–90 seconds');
  for(const s of m.shots){
    if(!/^[a-z][a-z0-9-]*$/.test(s.id)||ids.has(s.id))throw Error('Invalid/duplicate shot');ids.add(s.id);
    if(![3,6,9].includes(s.seconds)||!m.chapters.some(c=>c.id===s.map))throw Error('Shot chapter/duration');
    if(!['terrain','npc','pet','traverse','played-combat','combat','melee','artillery','warden'].includes(s.kind))throw Error('Shot kind');
    if(s.camera==='fp'&&!s.hud)throw Error('Input footage requires readable HUD');
    if(!['fp','spline','external'].includes(s.camera))throw Error('Camera');
  }
  for(const chapter of m.chapters)if(!m.shots.some(s=>s.map===chapter.id&&s.menu))throw Error('Missing menu chapter');
  for(const id of ['mara','ivo','patch'])if(!m.shots.some(s=>s.subject===id))throw Error('Missing cast');
  return duration;
}
export function cameraPath(shot,data) {
  if(shot.kind!=='terrain')return null;
  const route=data.routes.find(r=>r.id===shot.route);
  if(!route)throw Error(`Missing authored route ${shot.route}`);
  const a=route.points[0],b=route.points.at(-1),focus=route.points[Math.floor(route.points.length/2)];
  const length=Math.hypot(b.x-a.x,b.z-a.z),dx=(b.x-a.x)/length,dz=(b.z-a.z)/length;
  for(const lift of [0,4,8,12])for(const sideSign of [1,-1]) {
  const controls=[[-26,20,13],[-17,16,9],[-7,13,6],[6,17,8]].map(([along,side,height])=>{
    side*=sideSign;
    const x=focus.x+dx*along-dz*side,z=focus.z+dz*along+dx*side;
    const y=Math.max(focus.y+height+lift,floorAt(x,z,data.arena)+3+lift);
    return [x,y,z];
  });
  // Bezier is checked against source terrain/blocks every 1/120 of the shot.
  // Native art can still occlude it: contact-sheet/continuity review is mandatory.
  let safe=true;
  for(let i=0;i<=120;i++) {
    const t=i/120,u=1-t,p=[0,1,2].map(k=>u**3*controls[0][k]+3*u*u*t*controls[1][k]+3*u*t*t*controls[2][k]+t**3*controls[3][k]);
    const {minX,maxX,minZ,maxZ}=data.arena.bounds;
    if(p[0]<minX||p[0]>maxX||p[2]<minZ||p[2]>maxZ||!Number.isFinite(p[1])||p[1]<floorAt(p[0],p[2],data.arena)+1.2||obstructed(p[0],p[1],p[2],.35,data.arena)){safe=false;break;}
  }
  if(safe)return {controls,target:[focus.x,focus.y+2,focus.z],glance:[dx*5,1,dz*5],fov:58,lift,sideSign,
    validation:'121 source clearance samples; native art occlusion pending'};
  }
  throw Error(`${shot.id}: no safe composed source camera path`);
}
export async function plan(m) {
  const duration=validateManifest(m);
  const runtimePaths=['godot','game','port/native-campaign','port/native-arenas','port/native-horde','port/source',
    'tools/release/cinematic-v3','tools/godot-campaign/trailer-fixture.mjs','tools/godot-package/production_resources.mjs',
    'tools/godot-package/production_requirements.json','port/multiplayer-worlds/catalog.mjs'];
  if(git('diff','HEAD','--name-only','--',...runtimePaths))throw Error('Dirty runtime dependencies: commit before preparing evidence');
  const index=git('ls-files','-s','--',...runtimePaths);
  const chapters=m.chapters.map(c=>{const data=loadCampaignMap(c.id);if(data.geometryHash!==c.geometryHash)throw Error(`${c.id}: geometry revision changed`);return {...c,data};});
  const shots=m.shots.map(s=>({...s,path:cameraPath(s,chapters.find(c=>c.id===s.map).data)}));
  const music=JSON.parse(await readFile(join(root,m.music.path,'manifest.json')));
  if(music.original_composition!==true||music.bpm!==m.music.bpm||music.sources.some(s=>s.license!=='CC0-1.0'))throw Error('Music provenance changed');
  for(const stem of music.stems)if(sha256(await readFile(join(root,m.music.path,stem.file)))!==stem.sha256)throw Error('Music bytes changed');
  const dependencyFiles=(await readdir(join(root,'tools/release/cinematic-v3'))).filter(p=>/\.(mjs|py)$/.test(p)).sort().map(p=>`tools/release/cinematic-v3/${p}`).concat([
    'tools/godot-campaign/trailer-fixture.mjs','godot/tests/cinematic_v3/capture.gd','godot/tests/cinematic_v3/attract_candidate.gd',
    'tools/godot-package/production_resources.mjs','tools/godot-dev/finish_runner.py','tools/godot-dev/finish_receipts.py','tools/godot-dev/gate_runner.py',
    'godot/tests/campaign/trailer_session.gd','godot/ui/attract/demo.json',...m.chapters.map(c=>`godot/campaign/generated/${c.id}.json`)]);
  const files=Object.fromEntries(await Promise.all(dependencyFiles.map(async p=>[p,sha256(await readFile(join(root,p)))])));
  const {assetInputs}=await import('./assets.mjs');
  const result={...m,shots,duration,frames:duration*m.fps,manifestSHA256:sha256(JSON.stringify(m)),assets:assetInputs(),
    provenance:{revision:git('rev-parse','HEAD'),runtimeIndexSHA256:sha256(index),runtimeIndex:index,files,music,
      status:'source plan only; native frames, cast visibility, art/weather motion and menu acceptance pending'}};
  result.inputSHA256=sha256(JSON.stringify({manifest:result.manifestSHA256,shots,files,runtime:result.provenance.runtimeIndexSHA256,assets:result.assets.sha256}));
  return result;
}
export async function verifyFrames(directory,shot,fps,inputSHA256=null) {
  const names=(await readdir(join(directory,'frames'))).filter(n=>n.endsWith('.png')).sort();
  const rows=(await readFile(join(directory,'cadence.jsonl'),'utf8')).trim().split('\n').map(JSON.parse);
  const expected=shot.seconds*fps;
  if(names.length!==expected||rows.length!==expected)throw Error(`${shot.id}: incomplete capture`);
  const invocation=JSON.parse(await readFile(join(directory,'invocation.json')));
  if(!/^[a-f0-9]{64}$/.test(invocation.captureToken??''))throw Error('Missing native invocation nonce');
  const replay=(await readFile(join(directory,'replay.jsonl'),'utf8')).trimEnd().split('\n');
  const header=JSON.parse(replay[0]);
  if(inputSHA256&&header.provenance?.inputSHA256!==inputSHA256)throw Error('Source input identity mismatch');
  if(header.shot?.id!==shot.id||header.shot?.map!==shot.map||header.shot?.seconds!==shot.seconds)throw Error('Replay shot identity mismatch');
  const records=replay.slice(1).map(JSON.parse);
  if(records.length!==expected)throw Error('Source replay length mismatch');
  rows.forEach((r,i)=>{if(names[i]!==`${String(i).padStart(6,'0')}.png`||r.frame!==i||r.saveError!==0||r.sourceFrame!==i||r.width!==1280||r.height!==720||!Number.isFinite(r.wallUsec)||i&&r.wallUsec<=rows[i-1].wallUsec)throw Error(`${shot.id}: cadence/sequence invalid`);});
  for(const [i,r]of rows.entries()) {
    const record=records[i],bytes=await readFile(join(directory,'frames',names[i]));
    if(bytes.length<33||bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a'||bytes.toString('ascii',12,16)!=='IHDR'||bytes.readUInt32BE(16)!==1280||bytes.readUInt32BE(20)!==720||sha256(bytes)!==r.pngSHA256)throw Error('Actual PNG bytes/dimensions/hash mismatch');
    if(r.captureToken!==invocation.captureToken||record.frame!==i||record.input?.seq!==i+1||record.acks?.[0]!==i+1||r.sourceRecordSHA256!==sha256(replay[i+1])||!Number.isFinite(r.sourceTime)||Math.abs(r.sourceTime-record.state.time)>1e-9||Math.abs(r.sourceTime-Math.floor((i+1)*60/fps)/60)>1e-9||r.saveFinishedUsec<r.wallUsec||!Number.isFinite(r.saveFinishedUsec))throw Error('Native source-clock/nonce/hash mismatch');
    if(i&&Math.abs((r.sourceTime-rows[i-1].sourceTime)-(Math.floor((i+1)*60/fps)-Math.floor(i*60/fps))/60)>1e-6)throw Error('Source clock does not advance at recorded 60 Hz ticks');
  }
  const seconds=(rows.at(-1).wallUsec-rows[0].wallUsec)/1e6;
  return {frames:expected,sourceSeconds:shot.seconds,wallSeconds:seconds,observedWallFPS:(expected-1)/seconds,
    missingOutputFrames:0,realtimeCapture:false,encodedFPS:fps,sourceRateHz:60,
    framesOverRealtimeBudget:rows.slice(1).filter((r,i)=>r.wallUsec-rows[i].wallUsec>1e6/fps).length,
    engineFrameIncrements:[...new Set(rows.slice(1).map(r=>r.engineProcessFrames))],
    note:'Each PNG rendered offline; encodedFPS is timeline sampling, not measured hardware frame rate',
    maxWallGapMs:Math.max(...rows.slice(1).map((r,i)=>(r.wallUsec-rows[i].wallUsec)/1000))};
}

import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const root=path.resolve(new URL('../../../../',import.meta.url).pathname),evidence=process.argv[2];
const read=p=>JSON.parse(fs.readFileSync(p)),sha=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const authority=read(path.join(root,'godot/multiplayer_worlds/generated/helix-conservatory.json'));
const dirs={ctf:'revision-2-ctf-03',deathmatch:'revision-2-deathmatch-02',teamdeathmatch:'revision-2-teamdeathmatch-01',domination:'revision-2-domination-01',koth:'revision-2-koth-01'};
const journeys=Object.entries(dirs).map(([mode,dir])=>{
 const p=path.join(evidence,dir),native=read(path.join(p,'native-journey.json')),source=read(path.join(p,'source-outcome.json')),times=read(path.join(p,'capture-times.json')).monotonicMs;
 assert.equal(native.geometryHash,authority.geometryHash);assert.equal(source.geometryHash,authority.geometryHash);assert.deepEqual(native.failures,[]);assert.notEqual(source.endReason,'time');
 const gaps=times.slice(1).map((t,i)=>t-times[i]),sorted=[...gaps].sort((a,b)=>a-b),cadence={frames:times.length,durationSeconds:(times.at(-1)-times[0])/1000,actualCaptureHz:1000*(times.length-1)/(times.at(-1)-times[0]),medianGapMs:sorted[Math.floor(sorted.length/2)],p95GapMs:sorted[Math.floor(sorted.length*.95)],maxGapMs:Math.max(...gaps),window:[760,520],uiScale:150,renderScale3D:.5,shadows:false};
 if(mode==='ctf'){
  const lines=['ffconcat version 1.0'];times.forEach((t,i)=>{lines.push(`file '${path.join(p,`frame-${String(i+1).padStart(4,'0')}.png`)}'`,`duration ${((times[i+1]??t+cadence.medianGapMs)-t)/1000}`);});
  fs.writeFileSync(path.join(evidence,'revision-2-ctf.ffconcat'),lines.join('\n')+'\n');
 }
 return {mode,directory:p,native,cadence,source:{seconds:source.seconds,endReason:source.endReason,events:source.events,stats:source.stats,wireInputs:source.frames}};
});
const physics=read(path.join(evidence,'revision-2-final/native-physics.json'));assert.deepEqual(physics.failures,[]);assert.equal(physics.geometryHash,authority.geometryHash);
const art=read(path.join(root,'godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory-art-report.json'));
const glb='godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb',master='tools/godot-multiplayer/new-maps/helix-conservatory/masters/revision-2/helix-conservatory.blend';
art.files={[glb]:sha(path.join(root,glb)),[master]:sha(path.join(root,master))};
fs.writeFileSync(path.join(root,'godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory-art-report.json'),JSON.stringify(art,null,2)+'\n');
const report={revision:2,status:'hosted-native-five-mode-functional-pass-visual-review-completed',geometryHash:authority.geometryHash,recipeHash:authority.recipeHash,acceptedNativeModes:Object.keys(dirs),art,physics,inspection:read(path.join(evidence,'revision-2-final/inspection.json')),journeys,limits:['Software llvmpipe capture; not human balance or real-GPU proof','Actual continuous capture cadence below 15Hz in some runs; no encoded-fps substitution','Parent package closure/export verification remains pending','Historical autonomous CTF 0:0 timeout remains; no revised autonomous completion claim','Arsenal/Juggernaut remain source-only']};
fs.writeFileSync(path.join(root,'port/new-maps/helix-conservatory/revision-2/production-validation.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({geometryHash:report.geometryHash,files:art.files,physics,journeys:journeys.map(j=>({mode:j.mode,seconds:j.source.seconds,cadence:j.cadence}))},null,2));

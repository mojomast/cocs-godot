// Offline artifact checks. Optional second argument compares a fresh rebake.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {loadTool} from './tool.mjs';
const {decodePng}=await loadTool('decoders/png.mjs');
const dir=path.resolve(process.argv[2]??'assets/moth/map-variety-20261003/candidate-v2');
const other=process.argv[3]?path.resolve(process.argv[3]):null;
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json')));
const quality=JSON.parse(fs.readFileSync(path.join(dir,'quality.json')));
const sha=b=>createHash('sha256').update(b).digest('hex');
const seen=new Set(),warnings=[];
let decoded=0,rebakeCompared=0,maxBaseSeamRatio=0,maxNormalError=0;
for(const [key,t]of Object.entries(manifest.textures)){
  if(seen.has(t.path)||t.path.includes('..')||path.isAbsolute(t.path))throw new Error(`Invalid/duplicate texture path ${key}`);seen.add(t.path);
  const b=fs.readFileSync(path.join(dir,t.path));if(sha(b)!==t.sha256||b.length!==t.bytes)throw new Error(`Hash/length mismatch ${key}`);
  const png=decodePng(b);if(png.width!==512||png.height!==512||t.colorSpace!=='linear')throw new Error(`Bad channel contract ${key}`);
  if(other){if(!b.equals(fs.readFileSync(path.join(other,t.path))))throw new Error(`Nondeterministic PNG ${key}`);rebakeCompared++;}decoded++;
}
for(const m of manifest.materials){
  for(const c of ['albedo','normal','roughness','height','wear'])if(!manifest.textures[m.channels[c]])throw new Error(`Missing ${m.id}.${c}`);
  if(!m.provenance.jobId||!m.provenance.raw.sha256||!m.provenance.http.sha256)throw new Error(`Missing provenance ${m.id}`);
  for(const [channel,q]of Object.entries(quality.checks[m.id])){
    maxBaseSeamRatio=Math.max(maxBaseSeamRatio,q.mipGradientReports[0].ratio);
    maxNormalError=Math.max(maxNormalError,q.maxNormalError);
    if(q.mipGradientReports[0].ratio>3)throw new Error(`Base seam ratio >3: ${m.id}.${channel}`);
    if(q.maxNormalError>.015)throw new Error(`Non-unit normal: ${m.id}`);
    for(const level of q.mipGradientReports)if(level.size<512&&level.ratio>3)warnings.push({id:m.id,channel,...level,note:'coarse-mip diagnostic; inspect structural joints at world scale in Blender'});
  }
}
// Unique base families may share individual flat channels; whole-family hashes may not.
const signatures=manifest.materials.filter(m=>!m.derivedVariant).map(m=>Object.values(m.channels).map(k=>manifest.textures[k].sha256).join(':'));
if(new Set(signatures).size!==30)throw new Error('Duplicate base family');
if(quality.providerChanges.some(c=>!(c.normalizedMeanAbsoluteChange>0)))throw new Error('Provider transform had no numerical effect');
if(other)for(const file of ['manifest.json','quality.json'])if(!fs.readFileSync(path.join(dir,file)).equals(fs.readFileSync(path.join(other,file))))throw new Error(`Nondeterministic ${file}`);
const report={status:'offline-checks-passed',decoded,rebakeCompared,baseFamilies:signatures.length,materials:manifest.materials.length,maxBaseSeamRatio,maxNormalError,coarseMipWarnings:warnings,blenderReview:'pending next authorized stage',runtimeImport:'not run',remoteCalls:0};
fs.writeFileSync(path.join(dir,'verification.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,coarseMipWarnings:warnings.length}));

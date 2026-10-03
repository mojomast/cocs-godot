// Offline comparison from real archived provider PNGs. No network or source mutation.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {loadTool,pin} from './tool.mjs';
import {sheet,srgbByte} from './raster.mjs';
const {decodePng,encodePng}=await loadTool('decoders/png.mjs');
const {bakeImageMaterial}=await loadTool('image-material.mjs');
const {bakeGridMaterial,tileGradientReport}=await loadTool('grid-material.mjs');
const {resizeBilinear}=await loadTool('image.mjs');
const root=path.dirname(fileURLToPath(import.meta.url)),out=path.join(root,'comparison');fs.mkdirSync(out,{recursive:true});
const fields=JSON.parse(fs.readFileSync(path.join(root,'fields.json'))),baseline=JSON.parse(fs.readFileSync(path.join(root,'../candidate-v2/manifest.json')));
const jobs=JSON.parse(fs.readFileSync(path.join(root,'live.json'))).jobs;
const intensityFile=path.join(root,'intensity.json');if(fs.existsSync(intensityFile))jobs.push(...JSON.parse(fs.readFileSync(intensityFile)).jobs.map(j=>({...j,archiveRoot:'intensity-provider'})));
const concurrencyFile=path.join(root,'concurrency/plan.json');if(fs.existsSync(concurrencyFile))jobs.push(...JSON.parse(fs.readFileSync(concurrencyFile)).definitions);
const sha=b=>createHash('sha256').update(b).digest('hex');
const linear=v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4;
function gray(image){const a=[];for(let i=0;i<image.data.length;i+=4)a.push(.2126*linear(image.data[i]/255)+.7152*linear(image.data[i+1]/255)+.0722*linear(image.data[i+2]/255));return a;}
function correlation(a,b){const ma=a.reduce((s,v)=>s+v,0)/a.length,mb=b.reduce((s,v)=>s+v,0)/b.length;let aa=0,bb=0,ab=0;for(let i=0;i<a.length;i++){const x=a[i]-ma,y=b[i]-mb;aa+=x*x;bb+=y*y;ab+=x*y;}return aa*bb?ab/Math.sqrt(aa*bb):null;}
function gradients(a,n){const mags=[];let sx=0,sy=0,checker=0;for(let y=0;y<n;y++)for(let x=0;x<n;x++){const i=y*n+x,dx=a[y*n+(x+1)%n]-a[i],dy=a[((y+1)%n)*n+x]-a[i];mags.push(Math.hypot(dx,dy));sx+=Math.abs(dx);sy+=Math.abs(dy);checker+=a[i]*((x+y)%2?1:-1);}return {mags,axisRatio:sx/Math.max(sy,1e-12),checkerAlternation:Math.abs(checker)/a.length};}
const records=[],byId=new Map();
for(const job of jobs){
  const role=Object.keys(fields).find(id=>job.id.startsWith(id+'-'));if(!role)continue;
  const archiveRoot=job.archiveRoot??(job.batch?'concurrency':'provider'),dir=path.join(root,archiveRoot,'raw',job.raw??job.id),file=path.join(dir,'.mothbake-archive.json');
  if(!fs.existsSync(file)){records.push({id:job.id,role,engine:job.engine,status:'no-archive; consult journal for upload/worker status'});continue;}
  const archive=JSON.parse(fs.readFileSync(file)),blob=archive.outputs.find(o=>o.contentType==='image/png');
  if(!blob){records.push({id:job.id,role,engine:job.engine,status:'non-image output archived; separate evaluation'});continue;}
  const bytes=fs.readFileSync(path.join(dir,blob.file));if(sha(bytes)!==blob.sha256)throw new Error('Provider raw hash mismatch');
  const native=decodePng(bytes),source=decodePng(fs.readFileSync(path.join(root,`sources/${role}-source.png`)));
  if(native.width!==native.height||native.width<4||native.width>128)throw new Error(`Unexpected comparison size ${job.id}`);
  const image=native.width===64?native:{width:64,height:64,data:resizeBilinear(native.data,native.width,native.height,64,64)};
  const r=baseline.materials.find(m=>m.id===role),options={size:128,structureGrid:fields[role].height,structureMix:.9,maskGrid:fields[role].mask,roughness:r.authored.roughness,tileMeters:r.tileMeters,heightMeters:r.heightMeters};
  const baked=bakeImageMaterial({source:image,...options}),normalBase=bakeGridMaterial({grid:fields[role].height,...options}).maps.normal;
  const g=gray(image),s=gray(source),dg=gradients(g,64),ds=gradients(s,64);let mae=0,saturation=0,angle=0;
  for(let i=0;i<image.data.length;i+=4){for(let c=0;c<3;c++)mae+=Math.abs(linear(image.data[i+c]/255)-linear(source.data[i+c]/255));if(Math.max(...image.data.slice(i,i+3))>=250)saturation++;}
  for(let i=0;i<normalBase.data.length;i+=4){const a=[0,1,2].map(c=>normalBase.data[i+c]/127.5-1),b=[0,1,2].map(c=>baked.maps.normal.data[i+c]/127.5-1);angle+=Math.acos(Math.max(-1,Math.min(1,a.reduce((v,x,c)=>v+x*b[c],0)/(Math.hypot(...a)*Math.hypot(...b)))))*180/Math.PI;}
  const metrics={linearRGBMeanAbsoluteChange:mae/(64*64*3),sourceLuminanceCorrelation:correlation(s,g),gradientFeatureCorrelation:correlation(ds.mags,dg.mags),sourceAxisRatio:ds.axisRatio,resultAxisRatio:dg.axisRatio,sourceCheckerAlternation:ds.checkerAlternation,resultCheckerAlternation:dg.checkerAlternation,saturatedPixelFraction:saturation/(64*64),rawSeam:tileGradientReport(native.data,native.width),comparisonSeam:tileGradientReport(image.data,64),repairedAlbedoSeam:baked.quality.albedo,normalMeanAngularChangeDegrees:angle/(128*128)};
  const record={id:job.id,role,engine:job.engine,jobId:archive.jobId,params:job.params,inputHashes:Object.fromEntries(Object.entries(job.inputs??{}).map(([slot,p])=>[slot,{path:p,sha256:sha(fs.readFileSync(path.join(root,p)))}])),raw:{path:path.relative(root,path.join(dir,blob.file)),sha256:blob.sha256,bytes:blob.bytes,width:native.width,height:native.height},comparisonResample:native.width===64?'none':'provider downscaled output; bilinear to 64 only for same-coordinate diagnostics',status:'decoded-real-provider-output',metrics};records.push(record);byId.set(job.id,{record,image:native,baked});
}
const mainRaw=[],mainBaked=[];
for(const role of Object.keys(fields)){
  const source=decodePng(fs.readFileSync(path.join(root,`sources/${role}-source.png`))),old=decodePng(fs.readFileSync(path.join(root,'../candidate-v2',baseline.textures[`${role}.albedo`].path)));
  const items=[{label:`${role}\nSOURCE SRGB`,image:source},{label:`${role}\nBLUR CORE BASELINE`,image:old,linear:true}];
  mainRaw.push(...items);mainBaked.push(...items);
  for(const tag of ['image-rx','kernel-low','tele-vertical','tessa-palette']){const e=byId.get(`${role}-${tag}`);mainRaw.push({label:`${role}\n${tag}${e?'':' MISSING'}`,image:e?.image});mainBaked.push({label:`${role}\n${tag}${e?'':' MISSING'}`,image:e?.baked.maps.albedo,linear:true});}
}
for(const [name,items]of [['comparison-raw',mainRaw],['comparison-repaired',mainBaked],['all-variants',[...byId.values()].map(e=>({label:e.record.id.replace(/-(image|kernel|tele|tessa)/,'\n$1'),image:e.baked.maps.albedo,linear:true}))],['all-variants-tiled',[...byId.values()].map(e=>({label:e.record.id.replace(/-(image|kernel|tele|tessa)/,'\n$1'),image:e.baked.maps.albedo,linear:true,repeat:3}))]]){
  const image=sheet(items);fs.writeFileSync(path.join(out,`${name}.png`),encodePng(image.width,image.height,image.data,{alpha:true}));
}
fs.writeFileSync(path.join(out,'metrics.json'),JSON.stringify({version:1,tool:pin,method:'same source RGB per role; raw sRGB decoded to linear for metrics; image-adapter structureMix .9; 128px preview maps; no metric alone establishes artistic usefulness',records},null,2)+'\n');
console.log(JSON.stringify({archivedImageTrials:byId.size,records:records.length,comparison:out}));

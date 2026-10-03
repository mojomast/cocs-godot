// Offline only. All provider inputs are hash-verified; candidate pointer last.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {recipes} from './recipes.mjs';
import {loadTool} from './tool.mjs';
const {bakeGridMaterial,periodicGrid,tileGradientReport}=await loadTool('grid-material.mjs');
const {encodePng,decodePng}=await loadTool('decoders/png.mjs');
const {writeFileAtomic}=await loadTool('publish.mjs');
const root=path.dirname(fileURLToPath(import.meta.url));
const out=path.resolve(process.argv[2]??path.join(root,'candidate-v2'));
if(out===root)throw new Error('Output must be a separate candidate directory');
const sha=b=>createHash('sha256').update(b).digest('hex');
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p)));
const pin=read('tool-pin.json'), schema=read('contracts/schema-identity.json');
const jobs=['live.json','supplemental.json','refined.json'].flatMap(p=>read(p).jobs);
const http=read('provider/http-manifest.json');
fs.mkdirSync(path.join(out,'textures'),{recursive:true});
fs.mkdirSync(path.join(out,'sources'),{recursive:true});
const textures={},materials=[],sources=[],quality={};
const clamp=v=>Math.max(0,Math.min(1,v));
const rgba=values=>{const b=new Uint8Array(values.length*4);values.forEach((v,i)=>{b.fill(Math.round(clamp(v)*255),i*4,i*4+3);b[i*4+3]=255;});return b;};
function png(relative,map){
  const b=encodePng(map.width,map.height,map.data,{alpha:true});
  const file=path.join(out,relative);
  // Same content is reused; no misleading rewrite of evidence on offline rebake.
  if(fs.existsSync(file)&&!fs.readFileSync(file).equals(b))throw new Error(`Immutable candidate conflict: ${relative}; choose a fresh output directory`);
  if(!fs.existsSync(file))writeFileAtomic(file,b);
  const decoded=decodePng(b);
  if(decoded.width!==map.width||decoded.height!==map.height||!Buffer.from(decoded.data).equals(Buffer.from(map.data)))throw new Error(`PNG round-trip failed: ${relative}`);
  return {path:relative,sha256:sha(b),bytes:b.length,width:map.width,height:map.height,format:'rgba8',colorSpace:'linear'};
}
function inspect(map,normal=false){
  const levels=[];let data=map.data,size=map.width,min=255,max=0,maxNormalError=0;
  for(let i=0;i<data.length;i+=4){min=Math.min(min,data[i]);max=Math.max(max,data[i]);if(data[i+3]!==255)throw new Error('Unexpected alpha in base material');if(normal)maxNormalError=Math.max(maxNormalError,Math.abs(Math.hypot(data[i]/127.5-1,data[i+1]/127.5-1,data[i+2]/127.5-1)-1));}
  while(size>=4){levels.push({size,...tileGradientReport(data,size)});const next=size/2,b=new Uint8Array(next*next*4);
    for(let y=0;y<next;y++)for(let x=0;x<next;x++) {const i=(y*next+x)*4;for(let c=0;c<4;c++) b[i+c]=Math.round((data[((y*2)*size+x*2)*4+c]+data[((y*2)*size+x*2+1)*4+c]+data[((y*2+1)*size+x*2)*4+c]+data[((y*2+1)*size+x*2+1)*4+c])/4);
      if(normal){const n=[b[i]/127.5-1,b[i+1]/127.5-1,b[i+2]/127.5-1],len=Math.hypot(...n);for(let c=0;c<3;c++)b[i+c]=Math.round((n[c]/len+1)*127.5);}
    }data=b;size=next;
  }
  if(normal&&maxNormalError>.015)throw new Error('Non-unit normal');
  return {min,max,maxNormalError,mipGradientReports:levels};
}
const variants=[
  {id:'masonry-coping',source:'trim-wear',low:[.24,.235,.20],high:[.40,.385,.31],roughness:.83,maps:['Helix','Vesper','Stormglass'],role:'cornice/stringcourse/coping/quoins/drip'},
  {id:'shopfront-opaque',source:'ceramic-enamel',low:[.018,.025,.028],high:[.055,.065,.062],roughness:.33,maps:['Vesper'],role:'opaque dark shopfront panels'},
  {id:'optical-mirror-opaque',source:'anodized-brush',low:[.035,.045,.055],high:[.07,.085,.105],roughness:.12,heightMeters:.0004,maps:['Parallax'],role:'opaque dark optical instrument insert'},
  {id:'grotto-wet-rock',source:'basalt-strata',low:[.035,.06,.055],high:[.095,.13,.105],roughness:.32,maps:['Helix','Abyssal'],role:'damp grotto rock'},
  {id:'pool-scum',source:'deep-silt',low:[.04,.07,.02],high:[.14,.17,.055],roughness:.48,maps:['Helix','Abyssal'],role:'pool perimeter scum/soil-bed overlay'},
  {id:'forge-steel',source:'ribbed-steel',low:[.055,.065,.07],high:[.12,.13,.135],roughness:.61,maps:['Gravemill'],role:'forge wall and machine casing'},
];
for(const r of recipes){
  const job=jobs.find(j=>j.id===`${r.id}-x-refined`)??jobs.find(j=>j.id===r.id);
  const seedFile=`seeds/${r.id}.json`,seedBytes=fs.readFileSync(path.join(root,seedFile)),seed=JSON.parse(seedBytes);
  const archive=read(`provider/raw/${job.raw}/.mothbake-archive.json`), rawFile=`provider/raw/${job.raw}/inline-result.json`,raw=fs.readFileSync(path.join(root,rawFile));
  if(sha(raw)!==archive.result.sha256)throw new Error(`Raw hash mismatch: ${r.id}`);
  const response=http.records.find(j=>j.id===job.id),responseBytes=fs.readFileSync(path.join(root,response.path));
  if(sha(responseBytes)!==response.sha256)throw new Error(`HTTP hash mismatch: ${r.id}`);
  const grid=JSON.parse(raw).output, envelope=JSON.parse(responseBytes);
  if(JSON.stringify(grid)!==JSON.stringify(envelope.result.output))throw new Error('Canonical/exact HTTP grid mismatch');
  if(JSON.stringify(job.params.values)!==JSON.stringify(seed.height))throw new Error('Seed/job mismatch');
  const {values,...params}=job.params;
  const provenance={engine:archive.engine,engineVersion:null,jobId:archive.jobId,requestedMode:null,observedBackend:'not exposed; no hardware claim',estimatedCredits:1,actualCredits:null,params,values:{path:seedFile,field:'height'},source:{path:seedFile,sha256:sha(seedBytes),seed:r.seed,pattern:r.pattern},raw:{path:rawFile,sha256:sha(raw)},http:response,schemaSha256:schema.sha256,generationToolCommit:job.id.endsWith('-x-refined')?pin.commit:pin.generationCommit,bakeToolCommit:pin.commit,generationFingerprint:archive.generationFingerprint};
  const seedPng=png(`sources/${r.id}-height.png`,{width:128,height:128,data:rgba(seed.height.flat())});
  const maskPng=png(`sources/${r.id}-mask.png`,{width:128,height:128,data:rgba(seed.mask.flat())});
  sources.push({id:r.id,height:seedPng,mask:maskPng});
  for(const v of [r,...variants.filter(v=>v.source===r.id).map(v=>({...r,...v}))]){
    const family=bakeGridMaterial({grid,maskGrid:seed.mask,size:512,low:v.low,high:v.high,roughness:v.roughness,tileMeters:v.tileMeters,heightMeters:v.heightMeters});
    const channels={},checks={};
    for(const [name,map]of Object.entries(family.maps)){
      const key=`${v.id}.${name}`;
      textures[key]={...png(`textures/${v.id}-${name}.png`,map),semantic:name,normalConvention:name==='normal'?'OpenGL +Y':undefined};
      channels[name]=key;checks[name]=inspect(map,name==='normal');
    }
    if(v.id==='fern-frond'){
      const mask=periodicGrid(seed.mask,512),height=periodicGrid(grid,512);
      const alpha=rgba(Array.from(mask,(m,i)=>clamp((m-.16)*2.5)*(.82+.18*height[i])));
      const key=`${v.id}.alpha`;textures[key]={...png(`textures/${v.id}-alpha.png`,{width:512,height:512,data:alpha}),semantic:'coverage mask in RGB; use red channel for alpha clip'};channels.alpha=key;
    }
    materials.push({id:v.id,baseFamily:r.id,derivedVariant:v.id!==r.id,maps:v.maps,role:v.role??v.pattern,channels,...family.metadata,densityTag:v.tileMeters>=3?'macro-128-171px-per-meter':v.tileMeters===2?'surface-256px-per-meter':'detail-512px-per-meter',frequency:{macroCyclesPerTile:r.macro,microCyclesPerTile:r.micro,providerGrid:128,outputPixels:512},authored:{low:v.low,high:v.high,roughness:v.roughness},provenance});
    quality[v.id]=checks;
  }
}
// Report provider change, not a claim of independent image synthesis.
const providerChanges=recipes.map(r=>{const job=jobs.find(j=>j.id===`${r.id}-x-refined`)??jobs.find(j=>j.id===r.id);const seed=read(`seeds/${r.id}.json`).height.flat(),raw=read(`provider/raw/${job.raw}/inline-result.json`).output.flat();const max=Math.max(...raw),min=Math.min(...raw),smax=Math.max(...seed),smin=Math.min(...seed);let sum=0;for(let i=0;i<raw.length;i++)sum+=Math.abs((raw[i]-min)/(max-min)-(seed[i]-smin)/(smax-smin));return {id:r.id,normalizedMeanAbsoluteChange:sum/raw.length};});
const manifest={schema:'moth-map-material-pack/v1',status:'candidate-awaiting-Blender-and-parent-review',packId:'map-variety-20261003',tool:pin,materials,textures,sources,providerChanges,roleBindings:{'linear-oxide':'oxidized-iron.wear','damp-watermark':'quay-waterline.wear','paint-chip':'trim-wear.wear','calibration-paint':'decal-stencil.wear','glass-grime':'frosted-glass.roughness','calcite-barnacle':'salt-limestone.wear','cosmetic-seawater-normal':'sea-flow.normal','cosmetic-seawater-flow':'sea-flow.wear','fern-alpha':'fern-frond.alpha','ore-aggregate':'road-gravel.height','soil-bed':'deep-silt.albedo','root-fibers':'bark-fibers.normal'},channelRules:{albedo:'linear RGB, not sRGB encoded; Blender Non-Color, connect to base color',normal:'linear RGB OpenGL +Y; Blender Non-Color -> Normal Map tangent',roughness:'linear scalar in RGB, opaque alpha',height:'linear 8-bit detail only; never collision authority',wear:'linear synthesized mask; thresholds are consumer art controls',alpha:'separate linear scalar in RGB; use red for alpha clip; base albedo alpha remains opaque'},publication:'isolated candidate; merge after review; existing full registry not rewritten'};
manifest.pathBases={textures:'.',sources:'.',provenance:'..'};
manifest.consumerSources=Object.fromEntries(['recipes.mjs','bake.mjs','tool.mjs'].map(p=>[p,sha(fs.readFileSync(path.join(root,p)))]));
manifest.refinement={supersedes:'../candidate/manifest.json',reason:'15 xy-gate responses had grid artifacts; replaced by separately archived x-only jobs'};
writeFileAtomic(path.join(out,'quality.json'),JSON.stringify({version:1,checks:quality,providerChanges},null,2)+'\n');
writeFileAtomic(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({materials:materials.length,textures:Object.keys(textures).length,bytes:Object.values(textures).reduce((s,t)=>s+t.bytes,0),out}));

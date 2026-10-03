import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {loadTool,pin} from './tool.mjs';
import {sheet} from './raster.mjs';
const {bakeImageMaterial}=await loadTool('image-material.mjs');
const {encodePng,decodePng}=await loadTool('decoders/png.mjs');
const {unzip}=await loadTool('decoders/zip.mjs');
const {periodicGrid}=await loadTool('grid-material.mjs');
const {bake:rawGridBake}=await loadTool('bakers/raw-grid.mjs');
const {writeFileAtomic}=await loadTool('publish.mjs');
const root=path.dirname(fileURLToPath(import.meta.url)),packRoot=path.dirname(root),out=path.resolve(process.argv[2]??path.join(packRoot,'candidate-v3'));
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p))),sha=b=>createHash('sha256').update(b).digest('hex');
const selection=read('selection.json'),metrics=read('comparison/metrics.json'),fields=read('fields.json');
const baseBytes=fs.readFileSync(path.join(packRoot,'candidate-v2/manifest.json')),base=JSON.parse(baseBytes);
const schemaBytes=fs.readFileSync(path.join(packRoot,'engine-review/contracts.json'));
fs.mkdirSync(path.join(out,'textures'),{recursive:true});
const materials=[],textures={},contacts=[],normals=[];
const auxiliaryResources={};
for(const selected of selection.materials){
  const record=metrics.records.find(r=>r.id===selected.trial);if(!record?.raw)throw new Error('Selected trial has no completed image output');
  const raw=fs.readFileSync(path.join(root,record.raw.path));if(sha(raw)!==record.raw.sha256)throw new Error('Raw hash mismatch');
  for(const source of Object.values(record.inputHashes)){if(sha(fs.readFileSync(path.join(root,source.path)))!==source.sha256)throw new Error('Source hash mismatch');}
  const old=base.materials.find(r=>r.id===selected.role),result=bakeImageMaterial({source:decodePng(raw),sourceColorSpace:'srgb',structureGrid:fields[selected.role].height,structureMix:.9,maskGrid:fields[selected.role].mask,size:512,roughness:old.authored.roughness,tileMeters:old.tileMeters,heightMeters:old.heightMeters});
  const channels={};
  for(const [channel,map]of Object.entries(result.maps)){
    const key=`${selected.id}.${channel}`,relative=`textures/${selected.id}-${channel}.png`,bytes=encodePng(512,512,map.data,{alpha:true}),file=path.join(out,relative);
    if(fs.existsSync(file)&&!fs.readFileSync(file).equals(bytes))throw new Error('Immutable overlay conflict; choose a fresh destination');
    if(!fs.existsSync(file))writeFileAtomic(file,bytes);
    if(!Buffer.from(decodePng(bytes).data).equals(Buffer.from(map.data)))throw new Error('PNG round-trip failed');
    if(result.quality[channel].ratio>3)throw new Error('Base seam gate failed');
    channels[channel]=key;textures[key]={path:relative,sha256:sha(bytes),bytes:bytes.length,width:512,height:512,format:'rgba8',colorSpace:'linear',semantic:channel,...channel==='normal'?{normalConvention:'OpenGL +Y'}:{}};
  }
  materials.push({...selected,baseFamily:selected.role,derivedVariant:true,channels,...result.metadata,densityTag:old.densityTag,quality:result.quality,comparisonMetrics:record.metrics,provenance:{engine:record.engine,jobId:record.jobId,params:record.params,inputs:record.inputHashes,raw:record.raw,contractSnapshotSha256:sha(schemaBytes),bakeToolCommit:pin.commit,structureFields:{path:'fields.json',sha256:sha(fs.readFileSync(path.join(root,'fields.json'))),role:selected.role},imageInterpretation:'actual provider RGB retained, decoded sRGB to linear; height is explicit .9 authored structure + .1 provider luminance, not measured PBR'}});
  contacts.push({label:selected.id,image:result.maps.albedo,linear:true});normals.push({label:selected.id,image:result.maps.normal});
}
const auxiliary=read('comparison/fields-luts.json');
const scalarHTTP=read('http-scalar/manifest.json'),liveJobs=read('live.json').jobs;
function writeAux(relative,bytes){const file=path.join(out,relative);fs.mkdirSync(path.dirname(file),{recursive:true});if(fs.existsSync(file)&&!fs.readFileSync(file).equals(bytes))throw new Error('Immutable companion conflict');if(!fs.existsSync(file))writeFileAtomic(file,bytes);return {path:relative,sha256:sha(bytes),bytes:bytes.length};}
for(const mask of auxiliary.masks){
  const raw=fs.readFileSync(path.join(root,`provider/raw/${mask.id}/inline-result.json`));if(sha(raw)!==mask.rawSha256)throw new Error('Measured-mask raw hash mismatch');
  const values=periodicGrid(rawGridBake({id:mask.id},{result:JSON.parse(raw),bake:{width:64,height:64}}).value.values,512),data=new Uint8Array(512*512*4);for(let i=0;i<values.length;i++){data.fill(Math.round(values[i]*255),i*4,i*4+3);data[i*4+3]=255;}
  const bytes=encodePng(512,512,data,{alpha:true});if(sha(bytes)!==mask.sha256)throw new Error('Measured-mask offline rebuild mismatch');
  const exact=scalarHTTP.records.find(r=>r.id===mask.id);if(sha(fs.readFileSync(path.join(root,exact.path)))!==exact.sha256)throw new Error('Exact scalar HTTP hash mismatch');
  const {values:inputValues,...params}=liveJobs.find(j=>j.id===mask.id).params;
  if(JSON.stringify(inputValues)!==JSON.stringify(fields[mask.id.replace(/-qpixl$/,'')].mask.flat()))throw new Error('Measured-mask source field mismatch');
  auxiliaryResources[mask.id]={kind:'measured-coverage-mask',file:{...writeAux(`auxiliary/${mask.id}.png`,bytes),width:512,height:512,colorSpace:'linear'},engine:mask.engine,jobId:mask.jobId,params,values:{path:'fields.json',role:mask.id.replace(/-qpixl$/,''),field:'mask',flatten:'row-major'},observedBackend:mask.observedBackend,raw:{path:`provider/raw/${mask.id}/inline-result.json`,sha256:mask.rawSha256},exactHTTP:exact,contractSnapshotSha256:sha(schemaBytes),thresholdHalfIoU:mask.thresholdHalfIoU,usage:'optional boundary-stipple coverage; not collision geometry'};
}
for(const lut of auxiliary.luts){
  const raw=fs.readFileSync(path.join(root,lut.rawZip.path));if(sha(raw)!==lut.rawZip.sha256)throw new Error('LUT companion raw hash mismatch');
  const entries=unzip(raw),files=[];
  for(const name of ['R_lut.hdr','T_lut.hdr','R_lut.exr','T_lut.exr','entanglement_texture.osl','entanglement_texture.glsl','entanglement_texture.mtlx']){const bytes=entries.get(name);if(!bytes)throw new Error('Missing provider LUT master');files.push(writeAux(`auxiliary/${lut.id}/${name}`,bytes));}
  auxiliaryResources[lut.id]={kind:'view-dependent-lut-review-companion',engine:lut.engine,jobId:lut.jobId,params:liveJobs.find(j=>j.id===lut.id).params,rawArchive:lut.rawZip,contractSnapshotSha256:sha(schemaBytes),files,axes:lut.axes,ranges:{reflectance:lut.reflectance,transmittance:lut.transmittance},usage:'raw linear HDR/EXR plus provider shader references; not direct albedo/roughness; no runtime compatibility claim'};
}
const manifest={schema:'moth-map-material-overlay/v1',status:'candidate-awaiting-Blender-review',packId:'map-variety-20261003-image-overlay',basePack:{manifest:'../candidate-v2/manifest.json',sha256:sha(baseBytes)},tool:pin,materials,textures,auxiliaryResources,pathBases:{textures:'.',auxiliaryFiles:'.',provenance:'../engine-trials'},channelRules:base.channelRules,sourceHashes:Object.fromEntries(['bake-overlay.mjs','selection.json','tool.mjs','comparison/fields-luts.json'].map(p=>[p,sha(fs.readFileSync(path.join(root,p)))])),publication:'additive overlay only; base family IDs and files are inherited unchanged'};
for(const [name,items]of [['contact-albedo',contacts],['contact-normal',normals],['contact-tiled',contacts.map(item=>({...item,repeat:3}))]]){const image=sheet(items,4,192);writeFileAtomic(path.join(out,`${name}.png`),encodePng(image.width,image.height,image.data,{alpha:true}));}
writeFileAtomic(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log(JSON.stringify({materials:materials.length,textures:Object.keys(textures).length,textureBytes:Object.values(textures).reduce((n,t)=>n+t.bytes,0),out}));

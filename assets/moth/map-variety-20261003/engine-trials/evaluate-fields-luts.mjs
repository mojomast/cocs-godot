// Offline inspection/export of genuine archived scalar and HDR results.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {loadTool,pin} from './tool.mjs';
import {sheet} from './raster.mjs';
const {encodePng}=await loadTool('decoders/png.mjs');
const {decodeHdr}=await loadTool('decoders/hdr.mjs');
const {unzip}=await loadTool('decoders/zip.mjs');
const {periodicGrid,tileGradientReport}=await loadTool('grid-material.mjs');
const {bake:rawGridBake}=await loadTool('bakers/raw-grid.mjs');
const root=path.dirname(fileURLToPath(import.meta.url)),out=path.join(root,'comparison'),fields=JSON.parse(fs.readFileSync(path.join(root,'fields.json')));
fs.mkdirSync(out,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex');
const rgba=a=>{const b=new Uint8Array(a.length*4);a.forEach((v,i)=>b.set([Math.round(Math.max(0,Math.min(1,v))*255),Math.round(Math.max(0,Math.min(1,v))*255),Math.round(Math.max(0,Math.min(1,v))*255),255],i*4));return b;};
const masks=[],lutRecords=[],maskContact=[],lutContact=[];
for(const role of ['moss-lichen','quay-waterline']){
  const id=`${role}-qpixl`,dir=path.join(root,'provider/raw',id),archive=JSON.parse(fs.readFileSync(path.join(dir,'.mothbake-archive.json'))),bytes=fs.readFileSync(path.join(dir,'inline-result.json'));
  if(sha(bytes)!==archive.result.sha256)throw new Error('Scalar archive hash mismatch');
  const result=JSON.parse(bytes),grid=rawGridBake({id},{result,bake:{width:64,height:64}}).value.values,source=fields[role].mask.flat(),values=grid.flat();
  let mae=0,intersection=0,union=0;for(let i=0;i<values.length;i++){mae+=Math.abs(values[i]-source[i]);if(values[i]>=.5&&source[i]>=.5)intersection++;if(values[i]>=.5||source[i]>=.5)union++;}
  const image={width:512,height:512,data:rgba(periodicGrid(grid,512))},file=`${id}-mask.png`,png=encodePng(512,512,image.data,{alpha:true});fs.writeFileSync(path.join(out,file),png);
  masks.push({id,jobId:archive.jobId,engine:archive.engine,observedBackend:result.backend,qpuSeconds:result.qpu_seconds,rawSha256:sha(bytes),meanAbsoluteError:mae/values.length,thresholdHalfIoU:union?intersection/union:1,file,sha256:sha(png),colorSpace:'linear',role:'optional coverage/wear reconstruction; do not use as collision',seam:tileGradientReport(image.data,512),shapeRepair:'explicit 64x64 row-major, no new API call'});
  maskContact.push({label:`${role}\nAUTHORED MASK`,image:{width:64,height:64,data:rgba(source)}},{label:`${role}\nQPIXL MEASURED`,image:{width:64,height:64,data:rgba(values)}},{label:`${role}\nPERIODIC 512`,image});
}
for(const style of ['3-body','frustrated']){
  const id=`instrument-lut-${style}`,dir=path.join(root,'provider/raw',id),archive=JSON.parse(fs.readFileSync(path.join(dir,'.mothbake-archive.json'))),entry=archive.outputs[0],bytes=fs.readFileSync(path.join(dir,entry.file));
  if(sha(bytes)!==entry.sha256)throw new Error('LUT ZIP hash mismatch');
  const zip=unzip(bytes),r=decodeHdr(zip.get('R_lut.hdr')),t=decodeHdr(zip.get('T_lut.hdr'));
  const range=a=>({min:Math.min(...a.data),max:Math.max(...a.data)});
  // Reproduce only the published shader's phase/angle sampling, not a scene render.
  const sample=(lut,u,v)=>{const x=((u%1+1)%1)*lut.width-.5,y=Math.max(0,Math.min(lut.height-1,v*lut.height-.5)),ix=Math.floor(x),iy=Math.floor(y),fx=x-ix,fy=y-iy,at=(xx,yy)=>lut.data[(Math.min(lut.height-1,yy)*lut.width+((xx%lut.width)+lut.width)%lut.width)*3];return (at(ix,iy)*(1-fx)+at(ix+1,iy)*fx)*(1-fy)+(at(ix,iy+1)*(1-fx)+at(ix+1,iy+1)*fx)*fy;};
  for(const [kind,lut]of [['reflectance',r],['transmittance',t]]){
    const image={width:256,height:128,data:new Uint8Array(256*128*4)};
    for(let y=0;y<128;y++)for(let x=0;x<256;x++){const theta=y/127*Math.PI/2,thickness=x/255*800,D=-4*Math.PI*thickness*Math.cos(theta),i=(y*256+x)*4;for(let c=0;c<3;c++){const value=sample(lut,D/[650,530,470][c]/(2*Math.PI),y/127),mapped=value/(1+value);image.data[i+c]=Math.round((mapped<=.0031308?mapped*12.92:1.055*mapped**(1/2.4)-.055)*255);}image.data[i+3]=255;}
    const filename=`${id}-${kind}-parameter-preview.png`;fs.writeFileSync(path.join(out,filename),encodePng(image.width,image.height,image.data,{alpha:true}));lutContact.push({label:`${style}\n${kind}`,image});
  }
  lutRecords.push({id,jobId:archive.jobId,engine:archive.engine,rawZip:{path:`provider/raw/${id}/${entry.file}`,sha256:entry.sha256},dimensions:{width:r.width,height:r.height},reflectance:range(r),transmittance:range(t),preview:'fixed Reinhard then sRGB; x thickness 0..800 nm, y angle 0..pi/2; parameter-space diagnostic, not a rendered surface',axes:'provider GLSL: s phase periodic, t incident angle clamped; do not flip stored row order',decision:'retain immutable HDR/EXR/shader masters as review companions; no direct albedo/roughness binding; values above one remain in raw masters'});
}
for(const [name,items,cols]of [['mask-comparison',maskContact,3],['lut-comparison',lutContact,4]]){const image=sheet(items,cols,192);fs.writeFileSync(path.join(out,`${name}.png`),encodePng(image.width,image.height,image.data,{alpha:true}));}
const report={version:1,tool:pin,masks,luts:lutRecords,remoteCalls:0};fs.writeFileSync(path.join(out,'fields-luts.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({masks,luts:lutRecords.map(r=>({id:r.id,reflectance:r.reflectance,transmittance:r.transmittance}))}));

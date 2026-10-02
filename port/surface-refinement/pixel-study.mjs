// Source-only immutable PNG study. No engine, import, bake or asset writes.
// node port/surface-refinement/pixel-study.mjs
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {decodePng} from '../../scripts/moth-bake.mjs';
const root=new URL('../../godot/',import.meta.url);
const read=p=>readFileSync(new URL(p,root));
const manifest=JSON.parse(read('moth/generated/manifest.json'));
const derived=JSON.parse(read('moth/derived/manifest.json')).derived;
const linear=v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4;
const srgb=v=>v<=.0031308?v*12.92:1.055*v**(1/2.4)-.055;
const study=(record)=>{
  const bytes=read(record.path.slice(6));
  const sha=createHash('sha256').update(bytes).digest('hex');
  if(sha!==record.png_sha256) throw Error('PNG identity mismatch '+record.path);
  const {width,height,data}=decodePng(bytes),mean=[0,0,0],meanLinear=[0,0,0];
  for(let i=0;i<data.length;i+=4) for(let c=0;c<3;c++) {mean[c]+=data[i+c]/(width*height);meanLinear[c]+=linear(data[i+c]/255)/(width*height);}
  const chunks=[];for(let i=8;i<bytes.length;){const n=bytes.readUInt32BE(i);chunks.push(bytes.toString('ascii',i+4,i+8));i+=n+12;}
  return {path:record.path,sha256:sha,width,height,color_space:record.color_space,chunks,first_pixel:[...data.slice(0,4)],mean_rgb:mean,mean_decoded_linear:record.color_space==='srgb'?meanLinear:null};
};
const keys=['diamond_plate','hex_paneling','weathered_concrete','weathered_concrete-worn','brushed_metal','rock','rock-moss','sand','metal-oxide','grass'];
const results=keys.map(key=>({key,albedo:study(manifest.textures[key]),normal:manifest.normals[key]?study(manifest.normals[key]):null,data:study(derived['data--'+key])}));
// Exact per-pixel family albedo multiplication before scalar AO/crease/light.
// Averaging pixels after shader math avoids applying nonlinear conversion to a mean.
const bytes=decodePng(read(manifest.textures.diamond_plate.path.slice(6))).data;
const tint=[0x87,0x91,0x99].map(v=>linear(v/255));
const math=saturation=>{
  const mean=[0,0,0];for(let i=0;i<bytes.length;i+=4){const rgb=[0,1,2].map(c=>linear(bytes[i+c]/255));const l=rgb.reduce((s,v,c)=>s+v*[.2126,.7152,.0722][c],0);for(let c=0;c<3;c++)mean[c]+=tint[c]*(.28+.72*Math.min(1.25,(l*(1-saturation)+rgb[c]*saturation)*1.9))/(bytes.length/4);}
  return {saturation,mean_linear_before_scalar_ao_and_lighting:mean,srgb_of_mean:mean.map(v=>srgb(v)*255)};
};
console.log(JSON.stringify({scope:'source pixels and shader algebra, not native rendered proof',results,foundry_soot:{tint:'879199',texture_strength:.72,albedo_gain:1.9,current:math(.32),neutral_texture_control:math(0)}},null,2));

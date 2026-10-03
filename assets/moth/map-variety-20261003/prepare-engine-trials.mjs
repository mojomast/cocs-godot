import fs from 'node:fs';
import {recipes} from './recipes.mjs';
import {loadTool} from './tool.mjs';
const {encodePng}=await loadTool('decoders/png.mjs');
const {validateJobsAgainstContracts}=await loadTool('engine-contracts.mjs');
const root=new URL('./engine-trials/',import.meta.url);
fs.mkdirSync(new URL('sources/',root),{recursive:true});
if(fs.existsSync(new URL('live.json',root)))throw new Error('Existing trial intent: reuse its IDs');
const ids=['copper-patina','terracotta','prismatic-etch','quay-waterline','moss-lichen'];
const srgb=v=>Math.round(Math.max(0,Math.min(1,v<=.0031308?12.92*v:1.055*v**(1/2.4)-.055))*255);
const fields={};
for(const id of ids){
  const r=recipes.find(r=>r.id===id),seed=JSON.parse(fs.readFileSync(new URL(`./seeds/${id}.json`,import.meta.url)));
  const down=g=>Array.from({length:64},(_,y)=>Array.from({length:64},(_,x)=>(g[y*2][x*2]+g[y*2][x*2+1]+g[y*2+1][x*2]+g[y*2+1][x*2+1])/4));
  const h=down(seed.height),m=down(seed.mask);fields[id]={height:h,mask:m};
  for(const mode of ['source','target','mask']){
    const rgb=new Uint8Array(64*64*3);
    for(let y=0;y<64;y++)for(let x=0;x<64;x++)for(let c=0;c<3;c++){
      const base=r.low[c]+(r.high[c]-r.low[c])*h[y][x];
      // Target is a role-specific authored weathering endpoint, not another engine.
      const tint=id==='copper-patina'?[.035,.19,.13]:id==='moss-lichen'?[.19,.23,.07]:id==='prismatic-etch'?[.08,.17,.20]:[.06,.075,.06];
      rgb[(y*64+x)*3+c]=mode==='mask'?Math.round((.15+.85*m[y][x])*255):srgb(mode==='source'?base:base*(1-.55*m[y][x])+tint[c]*.55*m[y][x]);
    }
    fs.writeFileSync(new URL(`sources/${id}-${mode}.png`,root),encodePng(64,64,rgb));
  }
}
fs.writeFileSync(new URL('fields.json',root),JSON.stringify(fields)+'\n');
const jobs=[];
const add=(id,tag,engine,params,inputs)=>jobs.push({id:`${id}-${tag}`,engine,credits:1,raw:`${id}-${tag}`,params,inputs,bake:{type:'texture-tile',name:`${id}-${tag}`,size:64}});
for(const id of ids){
  const image=`sources/${id}-source.png`,mask=`sources/${id}-mask.png`;
  add(id,'image-rx','blur-v1',{style:'rx',strength:.22,reach:0,size:64,downscale:true},{image,mask});
  add(id,'kernel-low','deep-fryer-v1',{gates:[['rx',.10]],tile_size:2},{image,mask});
  add(id,'tele-vertical','telablur-v1',{strength:.3,direction:'vertical',size:64,downscale:true},{image1:image,image2:`sources/${id}-target.png`,mask});
  add(id,'tessa-palette','tessa-image-v1',{machine:'aer',shots:4096,fixed_palette:true,distortion:0,range_correction:false},{image});
}
add('terracotta','image-ry','blur-v1',{style:'ry',strength:.12,reach:0,size:64},{image:'sources/terracotta-source.png',mask:'sources/terracotta-mask.png'});
add('copper-patina','kernel-mid','deep-fryer-v1',{gates:[['rx',.3]],tile_size:2},{image:'sources/copper-patina-source.png',mask:'sources/copper-patina-mask.png'});
add('quay-waterline','tele-horizontal','telablur-v1',{strength:.3,direction:'horizontal',size:64},{image1:'sources/quay-waterline-source.png',image2:'sources/quay-waterline-target.png',mask:'sources/quay-waterline-mask.png'});
add('copper-patina','tessa-noisy','tessa-image-v1',{machine:'fake_fez',shots:4096,fixed_palette:false,distortion:0,range_correction:true},{image:'sources/copper-patina-source.png'});
for(const id of ['moss-lichen','quay-waterline'])jobs.push({id:`${id}-qpixl`,engine:'qpixl-v1',credits:1,raw:`${id}-qpixl`,params:{values:fields[id].mask.flat(),mode:'emu',machine:'aer',shots:4096,discretize:0,dynamic_range:'percentile'},bake:{type:'raw-grid',name:`${id}-qpixl`}});
for(const style of ['3-body','frustrated'])jobs.push({id:`instrument-lut-${style}`,engine:'entanglement-shader-v1',credits:1,raw:`instrument-lut-${style}`,params:{layers:2,incoming_rays:4,reflectance:.35,absorption:.8,interaction:.5,resolution:16,style},bake:{type:'material-lut',name:`instrument-lut-${style}`}});
const config={version:1,contractSnapshot:'../engine-review/contracts.json',jobs,emitters:[]};
const checks=validateJobsAgainstContracts(config,JSON.parse(fs.readFileSync(new URL('./engine-review/contracts.json',import.meta.url))),new URL('.',root).pathname);
if(checks.errors.length)throw new Error(JSON.stringify(checks));
fs.writeFileSync(new URL('live.json',root),JSON.stringify(config)+'\n');
console.log(`Validated ${jobs.length} live trials across ${new Set(jobs.map(j=>j.engine)).size} engines. All image methods share exact 64² source bytes per role.`);

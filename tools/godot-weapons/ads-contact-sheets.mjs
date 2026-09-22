// Review sheets only; individual native PNG captures remain unmodified.
import sharp from 'sharp';
import {join} from 'node:path';
const directory=process.argv[2];
if(!directory)throw new Error('Usage: node tools/godot-weapons/ads-contact-sheets.mjs <evidence-directory>');
const names=['Pulse Rifle','Rocket Launcher','Rail Lance','Scattergun','Plasma Driver','Grenade Launcher','Shock Beam','Flak Cannon','Marksman Rifle','SMG'];
async function sheet(size,states,width,height,file){
  const composite=[];
  for(const [weapon,name] of names.entries())for(const [column,state] of states.entries()){
    const top=weapon*(height+24),left=column*width;
    const label=Buffer.from(`<svg width="${width}" height="24"><text x="8" y="17" font-family="sans-serif" font-size="13" fill="#62deca">${weapon}: ${name} | ${state.toUpperCase()} | ${size}</text></svg>`);
    composite.push({input:label,top,left});
    composite.push({input:await sharp(join(directory,`${size}-weapon-${weapon}-${state}.png`)).resize(width,height,{fit:'contain',background:'#101a22'}).png().toBuffer(),top:top+24,left});
  }
  await sharp({create:{width:width*states.length,height:(height+24)*10,channels:3,background:'#101a22'}}).composite(composite).jpeg({quality:90}).toFile(join(directory,file));
}
await sheet('960x640',['hip','ads'],480,320,'contact-960x640-hip-ads.jpg');
await sheet('1280x800',['hip','ads'],480,300,'contact-1280x800-hip-ads.jpg');
await sheet('1280x800',['hip','enter','ads','recoil','exit','reload'],320,200,'contact-animated-poses.jpg');

// Small CPU-only PNG contact sheets. Thumbnail albedo is converted linear->sRGB.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {loadTool} from './tool.mjs';
const {encodePng,decodePng}=await loadTool('decoders/png.mjs');
const dir=path.resolve(process.argv[2]??path.join(path.dirname(fileURLToPath(import.meta.url)),'candidate-v2'));
const manifest=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json')));
const font={A:['010','101','111','101','101'],B:['110','101','110','101','110'],C:['011','100','100','100','011'],D:['110','101','101','101','110'],E:['111','100','110','100','111'],F:['111','100','110','100','100'],G:['011','100','101','101','011'],H:['101','101','111','101','101'],I:['111','010','010','010','111'],J:['001','001','001','101','010'],K:['101','101','110','101','101'],L:['100','100','100','100','111'],M:['101','111','111','101','101'],N:['101','111','111','111','101'],O:['010','101','101','101','010'],P:['110','101','110','100','100'],Q:['010','101','101','111','011'],R:['110','101','110','101','101'],S:['011','100','010','001','110'],T:['111','010','010','010','010'],U:['101','101','101','101','111'],V:['101','101','101','101','010'],W:['101','101','111','111','101'],X:['101','101','010','101','101'],Y:['101','101','010','010','010'],Z:['111','001','010','100','111'],'-':['000','000','111','000','000'],' ':['000','000','000','000','000']};
const display=v=>Math.round((v/255<=.0031308?12.92*v/255:1.055*(v/255)**(1/2.4)-.055)*255);
function make(channel,file,repeats=1){
  const cols=6,cell=176,rows=Math.ceil(manifest.materials.length/cols),w=cols*cell,h=rows*200;
  const data=new Uint8Array(w*h*4);for(let i=0;i<data.length;i+=4)data.set([25,28,31,255],i);
  for(const [index,m]of manifest.materials.entries()){
    const dx=(index%cols)*cell+8,dy=Math.floor(index/cols)*200+8;
    const img=decodePng(fs.readFileSync(path.join(dir,manifest.textures[m.channels[channel]].path)));
    for(let y=0;y<160;y++)for(let x=0;x<160;x++){
      const sx=Math.floor(x*img.width*repeats/160)%img.width,sy=Math.floor(y*img.height*repeats/160)%img.height,i=(sy*img.width+sx)*4,j=((dy+y)*w+dx+x)*4;
      for(let c=0;c<3;c++)data[j+c]=channel==='albedo'?display(img.data[i+c]):img.data[i+c];
    }
    for(const [ci,char]of [...m.id.toUpperCase()].entries())for(const [y,row]of (font[char]??font[' ']).entries())for(let x=0;x<3;x++)if(row[x]==='1'){
      const px=dx+ci*4+x,py=dy+169+y;
      if(px<(index%cols+1)*cell-3)data.set([220,225,224,255],(py*w+px)*4);
    }
  }
  fs.writeFileSync(path.join(dir,file),encodePng(w,h,data,{alpha:true}));
}
make('albedo','contact-albedo.png');make('normal','contact-normal.png');make('wear','contact-masks.png');make('albedo','contact-tiled.png',3);
console.log('Four 1056×1200 CPU-only labeled PNG contact sheets written.');

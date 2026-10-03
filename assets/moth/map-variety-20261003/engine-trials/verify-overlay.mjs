import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {loadTool} from './tool.mjs';
const {decodePng}=await loadTool('decoders/png.mjs');
const {tileGradientReport}=await loadTool('grid-material.mjs');
const dir=path.resolve(process.argv[2]),rebake=path.resolve(process.argv[3]);
const sha=b=>createHash('sha256').update(b).digest('hex');
const m=JSON.parse(fs.readFileSync(path.join(dir,'manifest.json'))),base=fs.readFileSync(path.join(dir,m.basePack.manifest));
for(const id of ['moss-lichen-qpixl','quay-waterline-qpixl','instrument-lut-3-body','instrument-lut-frustrated'])if(!m.auxiliaryResources?.[id])throw new Error(`Missing selected auxiliary resource ${id}`);
if(sha(base)!==m.basePack.sha256)throw new Error('Inherited baseline hash mismatch');
let count=0,auxiliaryFilesVerified=0,maxNormalError=0,maxBaseSeamRatio=0;const mipWarnings=[];
for(const [key,t]of Object.entries(m.textures)){
  const bytes=fs.readFileSync(path.join(dir,t.path));if(sha(bytes)!==t.sha256||bytes.length!==t.bytes)throw new Error('Texture hash mismatch');
  if(!bytes.equals(fs.readFileSync(path.join(rebake,t.path))))throw new Error('Rebake differs');
  const image=decodePng(bytes);if(image.width!==512||image.height!==512||t.colorSpace!=='linear')throw new Error('Channel contract mismatch');
  const isNormal=t.semantic==='normal';let data=image.data,n=512;
  for(let i=0;i<data.length;i+=4){if(data[i+3]!==255)throw new Error('Base channel not opaque');if(isNormal)maxNormalError=Math.max(maxNormalError,Math.abs(Math.hypot(data[i]/127.5-1,data[i+1]/127.5-1,data[i+2]/127.5-1)-1));}
  while(n>=4){const report=tileGradientReport(data,n);if(n===512)maxBaseSeamRatio=Math.max(maxBaseSeamRatio,report.ratio);else if(report.ratio>3)mipWarnings.push({key,size:n,...report});
    const next=n/2,b=new Uint8Array(next*next*4);
    for(let y=0;y<next;y++)for(let x=0;x<next;x++){const i=(y*next+x)*4;for(let c=0;c<4;c++)b[i+c]=Math.round((data[(2*y*n+2*x)*4+c]+data[(2*y*n+2*x+1)*4+c]+data[((2*y+1)*n+2*x)*4+c]+data[((2*y+1)*n+2*x+1)*4+c])/4);if(isNormal){const v=[0,1,2].map(c=>b[i+c]/127.5-1),len=Math.hypot(...v);for(let c=0;c<3;c++)b[i+c]=Math.round((v[c]/len+1)*127.5);}}
    data=b;n=next;
  }
  count++;
}
for(const name of ['manifest.json','contact-albedo.png','contact-normal.png','contact-tiled.png'])if(!fs.readFileSync(path.join(dir,name)).equals(fs.readFileSync(path.join(rebake,name))))throw new Error(`Rebake differs: ${name}`);
for(const resource of Object.values(m.auxiliaryResources??{}))for(const file of resource.files??[resource.file]){const bytes=fs.readFileSync(path.join(dir,file.path));if(sha(bytes)!==file.sha256||bytes.length!==file.bytes||!bytes.equals(fs.readFileSync(path.join(rebake,file.path))))throw new Error('Companion hash/rebake mismatch');auxiliaryFilesVerified++;}
if(maxBaseSeamRatio>3||maxNormalError>.015)throw new Error('Channel quality gate failed');
const report={version:1,status:'offline-checks-passed',pngsDecodedAndHashVerified:count,pngsByteIdenticalOnFreshRebake:count,auxiliaryFilesHashVerifiedAndByteIdentical:auxiliaryFilesVerified,contactsAndManifestByteIdentical:true,baseManifestVerifiedUnchanged:true,maxNormalError,maxBaseSeamRatio,mipWarnings,apiCalls:0,blenderReview:'pending next authorized stage'};
fs.writeFileSync(path.join(dir,'verification.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,mipWarnings:mipWarnings.length}));

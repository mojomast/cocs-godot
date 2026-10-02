import fs from 'node:fs';
import {createHash} from 'node:crypto';
const root='/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002';
const read=p=>JSON.parse(fs.readFileSync(p));
const data=read('godot/multiplayer_worlds/generated/parallax-observatory.json');
const asset=read('godot/multiplayer_worlds/art/parallax-observatory/asset-manifest.json');
const images=[];
for(const dir of ['blender-review','native-review','native-walkthrough','visual-ctf-final','visual-koth','visual-deathmatch']){
 for(const name of fs.readdirSync(root+'/'+dir).filter(n=>n.endsWith('.png')&&!n.startsWith('frame-'))){
  const path=root+'/'+dir+'/'+name,b=fs.readFileSync(path);
  images.push({path,bytes:b.length,sha256:createHash('sha256').update(b).digest('hex'),width:b.readUInt32BE(16),height:b.readUInt32BE(20)});
 }
}
const sessions=['native-walkthrough','visual-ctf-final','visual-koth','visual-deathmatch'].map(dir=>{
 const proof=read(root+'/'+dir+'/native-journey.json');
 if(proof.geometryHash!==data.geometryHash||proof.glbSha256!==asset.glbSha256||proof.uiChecks.length!==4||!proof.uiChecks.every(c=>c.rows.every(r=>r.fits)))throw Error('Invalid visual session '+dir);
 const clip=read(root+'/'+dir+'/clip.json');
 return {dir,frameMsP50:proof.frameMsP50,frameMsP95:proof.frameMsP95,drawCalls:proof.drawCalls,renderer:proof.renderer,roundResults:proof.roundResults,uiChecks:proof.uiChecks,clip};
});
const report={geometryHash:data.geometryHash,asset:read('godot/multiplayer_worlds/art/parallax-observatory/asset-manifest.json'),inspection:read(root+'/native-review/inspection.json'),sessions,images,limits:'llvmpipe software renderer; shadow-disabled gameplay, 0.65 3D scale; encoded 15 fps duplicates frames and is not a 15 fps rendering claim. Controlled native Input-event steering, passive opposition. Human visual inspection is documented in VISUAL.md.'};
fs.writeFileSync('port/new-maps/parallax-observatory/visual-validation.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({images:images.length,sessions:sessions.map(s=>({dir:s.dir,clip:s.clip}))},null,2));

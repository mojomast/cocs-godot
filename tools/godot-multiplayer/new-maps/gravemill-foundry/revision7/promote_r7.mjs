// Promote the reviewed Foundry R7/Y artifact into the runtime world paths.
// Copies the staged revision GLB over art/worlds/gravemill-foundry.glb and
// renames the extracted PNG + sidecar set from revisions/gravemill-foundry-r7_*
// to worlds/gravemill-foundry_* (sidecar source_file rewritten). The staged
// revision files are removed by the caller with git rm after this succeeds.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('../../../../../',import.meta.url);
const hash=b=>createHash('sha256').update(b).digest('hex');
const manifest=JSON.parse(fs.readFileSync(new URL('evidence/Y/final-manifest.json',import.meta.url)));
const nativeCandidate=p=>p.startsWith('godot/')&&!['godot/tests/','godot/content/','godot/.godot/'].some(prefix=>p.startsWith(prefix))&&!['godot/.gitignore','godot/export_presets.cfg'].includes(p);
const files=Object.entries(manifest.files).filter(([p])=>nativeCandidate(p));
const staged=Object.entries(manifest.files).filter(([p])=>p.startsWith('godot/tests/'));
if(files.length!==74)throw Error('Unexpected R7 native scope: '+files.length);
if(staged.length!==19)throw Error('Unexpected R7 test scope: '+staged.length);
for(const [p,r] of files){
  const bytes=fs.readFileSync(new URL(p,root));
  if(bytes.length!==r.bytes||hash(bytes)!==r.sha256)throw Error('Staged byte identity: '+p);
}
const GLB='godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7.glb';
const EXPECTED_GLB='6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f';
if(hash(fs.readFileSync(new URL(GLB,root)))!==EXPECTED_GLB)throw Error('R7 GLB identity');
fs.copyFileSync(new URL(GLB,root),new URL('godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb',root));
let pngs=0,sidecars=0;
for(const [p] of files){
  if(!/gravemill-foundry-r7_.*\.png(\.import)?$/.test(p))continue;
  const target=p.replace('art/revisions/gravemill-foundry-r7_','art/worlds/gravemill-foundry_');
  let bytes=fs.readFileSync(new URL(p,root));
  if(p.endsWith('.import')){
    bytes=Buffer.from(bytes.toString().replaceAll(
      'res://multiplayer_worlds/art/revisions/gravemill-foundry-r7_',
      'res://multiplayer_worlds/art/worlds/gravemill-foundry_'));
    sidecars++;
  } else pngs++;
  fs.writeFileSync(new URL(target,root),bytes);
}
if(pngs!==36||sidecars!==36)throw Error(`Promoted PNG/sidecar scope: ${pngs}/${sidecars}`);
for(const [p,r] of files){
  if(!/gravemill-foundry-r7_.*\.png$/.test(p))continue;
  const target=p.replace('art/revisions/gravemill-foundry-r7_','art/worlds/gravemill-foundry_');
  const bytes=fs.readFileSync(new URL(target,root));
  if(bytes.length!==r.bytes||hash(bytes)!==r.sha256)throw Error('Promoted PNG identity: '+target);
}
console.log('PROMOTED foundry-r7:',pngs,'PNGs +',sidecars,'sidecars + GLB',EXPECTED_GLB.slice(0,12));

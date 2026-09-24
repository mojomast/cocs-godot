// Geometry identity gate over the actual exported GLBs. Regenerate after.json
// with silhouette-report.mjs before running this check.
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const root=new URL('../../',import.meta.url);
const load=async path=>JSON.parse(await readFile(new URL(path,root)));
const [before,after,manifest,pinned]=await Promise.all([
  load('port/native-world-weapon-identity/before.json'),
  load('port/native-world-weapon-identity/after.json'),
  load('godot/source_operators/generated/world_weapons/manifest.json'),
  load('port/native-weapon-detail-world/anchors-before.json'),
]);
const fail=message=>{throw new Error(`world weapon identity: ${message}`);};
if(before.pairCount!==45||after.pairCount!==45||after.weapons.length!==10||manifest.weapons.length!==10)fail('incomplete ten-weapon / 45-pair census');
for(const view of ['side','top']){
  const a=after.summary[view],b=before.summary[view];
  if(!(a.maxIoU<b.maxIoU-.02&&a.minDifferentPixels>b.minDifferentPixels+100))
    fail(`${view} silhouette separation regressed (${JSON.stringify({before:b,after:a})})`);
  if(after.pairs.length!==45||after.pairs.some(pair=>!(pair.views[view].differentPixels>0)))fail(`${view} contains duplicate silhouettes`);
}
for(let id=0;id<10;id++){
  const actual=after.weapons[id],entry=manifest.weapons[id],reference=pinned.weapons[id];
  if(actual.id!==id||entry.id!==id||entry.file!==actual.file)fail(`weapon ${id} catalog order mismatch`);
  const bytes=await readFile(new URL(`godot/source_operators/generated/world_weapons/${entry.file}`,root));
  const hash=createHash('sha256').update(bytes).digest('hex');
  if(hash!==actual.sha256||hash!==entry.sha256)fail(`weapon ${id} stale report or manifest`);
  if(actual.triangles!==entry.triangles||actual.primitives!==entry.draws||entry.draws<3||entry.draws>4||entry.triangles<1200||entry.triangles>2500)
    fail(`weapon ${id} draw or triangle budget`);
  for(const name of ['Muzzle','WeaponGripLeft','WeaponGripRight']){
    if(entry.anchors[name].some((n,i)=>Math.abs(n-reference.anchors[name][i])>1e-6))fail(`weapon ${id} ${name} moved`);
  }
}
console.log('World weapon identity PASS: 10 GLBs, 45 pairs, side/top separation improved, 3-4 draws, 1200-2500 triangles, pinned grips/muzzles unchanged.');

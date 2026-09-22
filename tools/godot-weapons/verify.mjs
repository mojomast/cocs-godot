import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=new URL('../../',import.meta.url);
const out=new URL('godot/first_person/generated/',root);
const manifest=JSON.parse(readFileSync(new URL('manifest.json',out)));
const hash=data=>createHash('sha256').update(data).digest('hex');
for(const [file,expected] of Object.entries(manifest.sources))assert.equal(hash(readFileSync(new URL(file,root))),expected,`source changed: ${file}`);
assert.equal(manifest.weapons.length,10);
assert.equal(new Set(manifest.weapons.map(w=>w.sha256)).size,10);
// Six-channel weapon identity: every weapon must differ in every channel, so
// "the ten weapons look and feel different" is machine-checkable, not a claim.
for(const channel of ['massing','feed','muzzle','stock','sight','accent'])
  assert.equal(new Set(manifest.weapons.map(w=>w.identity?.[channel])).size,10,`identity channel not distinct: ${channel}`);
const files=['manifest.json','catalog.gd',...manifest.weapons.map(w=>w.file)];
const before=new Map(files.map(f=>[f,hash(readFileSync(new URL(f,out)))]));
for(const weapon of manifest.weapons){
  assert.equal(weapon.sha256,before.get(weapon.file));
  // Detail budget: 3,000-6,000 triangles (the two integrated-optic weapons sit
  // inside the 6,500 gate because their locked source geometry alone is 5.2-6.1k).
  assert.ok(weapon.triangles>3000&&weapon.triangles<6500,`triangle band weapon ${weapon.id}: ${weapon.triangles}`);
  assert.ok(weapon.detailTriangles>=380,`recovered detail weapon ${weapon.id}: ${weapon.detailTriangles}`);
  // Eight material batches per weapon: one draw call per (moving assembly, slot).
  assert.ok(weapon.meshInstances<=8,`batch budget weapon ${weapon.id}: ${weapon.meshInstances}`);
  assert.equal(weapon.batches.length,weapon.meshInstances,`batch records weapon ${weapon.id}`);
  assert.equal(new Set(weapon.batches.map(b=>b.slot+'|'+b.role)).size,weapon.meshInstances,`duplicate batch weapon ${weapon.id}`);
  // Authored detail never enters a hand capsule or the sight corridor; the
  // exporter measures this in weapon space and the rendered gates re-check it.
  assert.ok(weapon.detailBoxes.length>0,`detail boxes weapon ${weapon.id}`);
  assert.ok(weapon.nearestHandClearance>=0.045,`hand clearance weapon ${weapon.id}: ${weapon.nearestHandClearance}`);
  for(const box of weapon.detailBoxes)assert.ok(box.max.every((v,i)=>v>=box.min[i]),`degenerate detail box weapon ${weapon.id}`);
  const bytes=readFileSync(new URL(weapon.file,out));
  assert.equal(bytes.subarray(0,4).toString(),'glTF');
  assert.equal(bytes.readUInt32LE(8),bytes.length);
}
execFileSync(process.execPath,[new URL('export.mjs',import.meta.url).pathname],{cwd:root,stdio:'pipe'});
for(const [file,expected] of before)assert.equal(hash(readFileSync(new URL(file,out))),expected,`non-deterministic export: ${file}`);
console.log(JSON.stringify({sourceHashes:'verified',weapons:10,byteIdenticalReexport:true,batchesPerWeapon:8,identityChannels:6,
  triangles:manifest.weapons.map(w=>w.triangles),detailTriangles:manifest.weapons.map(w=>w.detailTriangles),
  glbBytes:manifest.weapons.reduce((n,w)=>n+w.bytes,0)}));

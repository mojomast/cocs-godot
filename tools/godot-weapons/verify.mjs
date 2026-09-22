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
const files=['manifest.json','catalog.gd',...manifest.weapons.map(w=>w.file)];
const before=new Map(files.map(f=>[f,hash(readFileSync(new URL(f,out)))]));
for(const weapon of manifest.weapons){
  assert.equal(weapon.sha256,before.get(weapon.file));
  assert.ok(weapon.triangles>3000&&weapon.triangles<6500);
  assert.ok(weapon.meshInstances<=11);
  const bytes=readFileSync(new URL(weapon.file,out));
  assert.equal(bytes.subarray(0,4).toString(),'glTF');
  assert.equal(bytes.readUInt32LE(8),bytes.length);
}
execFileSync(process.execPath,[new URL('export.mjs',import.meta.url).pathname],{cwd:root,stdio:'pipe'});
for(const [file,expected] of before)assert.equal(hash(readFileSync(new URL(file,out))),expected,`non-deterministic export: ${file}`);
console.log(JSON.stringify({sourceHashes:'verified',weapons:10,byteIdenticalReexport:true,glbBytes:manifest.weapons.reduce((n,w)=>n+w.bytes,0)}));

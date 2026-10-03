import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
import {identity,authorize,prepare,sha,ROOT,CANDIDATES} from '../../../tools/asset-production/candidate-admission.mjs';
import {worldEntry} from '../../../port/multiplayer-worlds/catalog.mjs';
test('six Abyssal capabilities remain private; promoted Vesper uses public admission',()=>{
 for(const mode of CANDIDATES['abyssal-pressureworks']){
  const r=identity('abyssal-pressureworks',mode),bytes=fs.readFileSync(ROOT+'godot/multiplayer_worlds/generated/abyssal-pressureworks.json');
  assert.throws(()=>worldEntry(r.id,mode));assert.throws(()=>authorize({...r,enabled:false},bytes));assert.throws(()=>authorize({...r,expectedSha:'0'.repeat(64)},bytes));
  const bad=structuredClone(r.data);bad.geometryHash='0'.repeat(64);const changed=JSON.stringify(bad);assert.throws(()=>authorize({...r,expectedSha:sha(changed)},changed));
 }
 assert.equal(worldEntry('vesper-viaduct','ctf').name,'Vesper Viaduct');
});
test('current private cloner imports actual new broadphase dependency and ws without constructing authority',async()=>{
 const dir=fs.mkdtempSync('/tmp/opencode/abyssal-private-import-');
 try{
  const r=identity('abyssal-pressureworks','ctf'),d=prepare(dir,r);
  const imported=await import(pathToFileURL(d.server));assert.equal(typeof imported.createGameServer,'function');
  for(const name of ['core','payload','room','rooms','game-server','match']){
   const original=ROOT+(name==='match'?`port/multiplayer-worlds/${name}.mjs`:`port/multiplayer-worlds/derived/${name}.mjs`);
   const strip=s=>s.replace(/(from\s*|import\s*)(['"])[^'"]+\2/g,'$1"IMPORT"');
   assert.equal(strip(fs.readFileSync(`${dir}/${name}.mjs`,'utf8')),strip(fs.readFileSync(original,'utf8')));
  }
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('frozen authority, shared finish, public catalogs and other producer receipts preserve merged canonical bytes',()=>{
 const protectedPaths=['game/','port/contracts/source-lock.json','port/multiplayer-worlds/catalog.mjs','port/multiplayer-worlds/derived/','port/multiplayer-worlds/wall_candidates.mjs','godot/multiplayer_worlds/catalog.gd','tools/asset-production/moth_finish.py','tools/godot-package/production_receipts/',':(exclude)tools/godot-package/production_receipts/abyssal-pressureworks.json'];
 assert.equal(execFileSync('git',['diff','99a4f597','--',...protectedPaths],{cwd:ROOT,encoding:'utf8'}),'');
});
test('actual Godot-extracted images match embedded export bytes and keep lossless normal policies',()=>{
 const base=ROOT+'godot/multiplayer_worlds/art/worlds/abyssal-pressureworks',bytes=fs.readFileSync(base+'.glb'),size=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+size)),bin=bytes.subarray(28+size);
 assert.equal(doc.images.length,5);
 for(const image of doc.images){
  const view=doc.bufferViews[image.bufferView],start=view.byteOffset??0,path=base+'_'+image.name+'.png';
  assert.equal(sha(fs.readFileSync(path)),sha(bin.subarray(start,start+view.byteLength)),image.name);
  const policy=fs.readFileSync(path+'.import','utf8');assert.match(policy,/compress\/mode=0/);assert.match(policy,/mipmaps\/generate=true/);assert.match(policy,/process\/normal_map_invert_y=false/);
 }
});

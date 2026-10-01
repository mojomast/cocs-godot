import {readFileSync,writeFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {readImportedTriangles} from './structure-rays.mjs';
const directory=new URL('../../godot/campaign/art/structures/',import.meta.url);
const models={};
for(const name of readdirSync(directory).filter(n=>n.endsWith('-0.glb')).sort()) {
  const key=name.slice(0,-6);
  models[key]={sha256:createHash('sha256').update(readFileSync(new URL(name,directory))).digest('hex'),faces:readImportedTriangles(key)};
}
const text=JSON.stringify({version:1,source:'committed LOD0 GLB POSITION/indices with node rotation applied',models})+'\n';
const target=new URL('./structure-faces.json',import.meta.url);
if(process.argv.includes('--check')) {
  if(readFileSync(target,'utf8')!==text)throw Error('Facade collision bake differs from imported art');
} else writeFileSync(target,text);
console.log(`${Object.keys(models).length} facade prototypes, ${Object.values(models).reduce((s,m)=>s+m.faces.length,0)} triangles, ${text.length} bytes`);

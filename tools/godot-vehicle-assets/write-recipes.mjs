import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {recipe,contracts} from './recipe.mjs';
const out=resolve(process.argv[2]||'tools/godot-vehicle-assets/generated');
mkdirSync(out,{recursive:true});
for(const kind of Object.keys(contracts))for(let lod=0;lod<3;lod++)
  writeFileSync(resolve(out,`${kind}-lod${lod}.json`),JSON.stringify(recipe(kind,lod))+'\n');
console.log(`Wrote nine deterministic authoring recipes to ${out}`);

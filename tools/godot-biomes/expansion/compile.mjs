import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {recipes,palette,SEED,maps,faces} from './recipe.mjs';
import {structurePlacements} from '../../../port/edge-effects/structure-rays.mjs';
export const root = fileURLToPath(new URL('../../../',import.meta.url));
export const sha = bytes => createHash('sha256').update(bytes).digest('hex');
export const readChapter = id => JSON.parse(readFileSync(`${root}godot/campaign/generated/${id}.json`));
export function compile() {
  const assets=recipes(),chapters={};
  for(const id of maps) {
    const data=readChapter(id),source=structurePlacements(data),placements=[];
    for(const asset of assets.filter(a=>a.chapter===id)) {
      const segments=source.filter(p=>p.block.id===asset.block);
      if(!segments.length)throw Error(`Missing reviewed block ${asset.block}`);
      const first=segments[0],b=first.block;
      placements.push({asset:asset.id,block:b.id,role:asset.role,
        origin:[b.x,first.origin.y,b.z],scale:[b.w,b.h-first.origin.y,b.d],
        lodTriangles:[faces(asset).length,faces(asset,1).length],materials:[...new Set(asset.parts.map(p=>p.material))]});
    }
    chapters[id]={geometryHash:data.geometryHash,recipeSha256:sha(readFileSync(`${root}godot/campaign/generated/${id}.json`)),placements};
  }
  const recipe={schemaVersion:1,pack:'campaign-biome-expansion-four',seed:SEED,palette,assets};
  const recipeText=JSON.stringify(recipe)+'\n';
  const catalog={schemaVersion:1,pack:recipe.pack,recipeSha256:sha(recipeText),
    collision:'none; retain all original facade triangles, frames, props and IDs',
    materialAllowlist:Object.keys(palette).map(name=>'biome4_'+name),lodDistance:85,chapters};
  return {recipeText,catalogText:JSON.stringify(catalog,null,2)+'\n'};
}
if(process.argv[1]===fileURLToPath(import.meta.url)) {
  const {recipeText,catalogText}=compile();
  const outputs=[['tools/godot-biomes/expansion/meshes.json',recipeText],['godot/biomes/expansion/catalog.json',catalogText]];
  for(const [path,text] of outputs) {
    if(process.argv.includes('--check')) {if(readFileSync(root+path,'utf8')!==text)throw Error(`Stale ${path}`);}
    else {mkdirSync(root+path.slice(0,path.lastIndexOf('/')),{recursive:true});writeFileSync(root+path,text);}
  }
  console.log(`SCENERY_RECIPE ${sha(recipeText)} assets=12 chapters=4`);
}

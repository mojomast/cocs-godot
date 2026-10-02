import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical} from '../../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';
import {recipe} from './recipe.mjs';
const arena=recipe(),hash=s=>createHash('sha256').update(s).digest('hex'),body=JSON.stringify(arena)+'\n';
const data={schemaVersion:1,id:arena.id,name:arena.name,recipeHash:hash(body),geometryHash:hash(canonical(arena)),spawnPoints:arena.spawns.map(([x,z])=>({x,y:terrainSupportAt(x,z,arena.terrain,.8).y,z})),arena};
const probes={geometryHash:data.geometryHash,points:arena.navNodes.map(p=>({...p,y:terrainSupportAt(p.x,p.z,arena.terrain,.8).y}))};
for(const [name,value] of [['arena.json',body],['candidate.json',JSON.stringify(data)+'\n'],['probes.json',JSON.stringify(probes)+'\n']]){
 const path=new URL(name,import.meta.url);if(process.argv.includes('--check')){if(fs.readFileSync(path,'utf8')!==value)throw Error('Stale candidate '+name);}else fs.writeFileSync(path,value);
}
console.log(JSON.stringify({geometryHash:data.geometryHash,recipeHash:data.recipeHash,surfaces:arena.terrain.surfaces.length,walls:arena.terrain.walls.length,routeVariants:arena.routes.length}));

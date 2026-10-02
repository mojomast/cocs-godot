import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {recipe,ID} from './recipe.mjs';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
import {floorAt} from '../../../../game/core.mjs';
export const hash=value=>createHash('sha256').update(value).digest('hex');
export function build(){const arena=recipe(),body=JSON.stringify(arena)+'\n';return {schemaVersion:1,id:ID,name:arena.name,recipeHash:hash(body),geometryHash:hash(canonical(arena)),spawnPoints:arena.spawns.map(([x,z])=>({x,y:floorAt(x,z,arena),z})),arena};}
if(process.argv[1]===new URL(import.meta.url).pathname){
 const data=build();
 for(const [relative,body] of [[`port/native-multiplayer-worlds/worlds/${ID}.json`,JSON.stringify(data.arena)+'\n'],[`godot/multiplayer_worlds/generated/${ID}.json`,JSON.stringify(data)+'\n']]){
  const file=new URL('../../../../'+relative,import.meta.url);
  if(process.argv.includes('--check')){if(fs.readFileSync(file,'utf8')!==body)throw Error(`Stale ${relative}`);}else fs.writeFileSync(file,body);
 }
 console.log(JSON.stringify({id:ID,hash:data.geometryHash,surfaces:data.arena.terrain.surfaces.length,walls:data.arena.terrain.walls.length,blocks:data.arena.blocks.length,nav:data.arena.navNodes.length}));
}

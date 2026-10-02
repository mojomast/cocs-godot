import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {recipe,ID} from './recipe.mjs';
import {validateMapSchema} from '../../../../game/map-schema.mjs';
import {floorAt} from '../../../../game/core.mjs';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
const arena=recipe(),validation=validateMapSchema(arena);
if(validation.length)throw Error(validation.join('\n'));
const hash=s=>createHash('sha256').update(s).digest('hex'),body=JSON.stringify(arena)+'\n';
const data={schemaVersion:1,id:ID,name:arena.name,geometryHash:hash(canonical(arena)),recipeHash:hash(body),spawnPoints:arena.spawns.map(([x,z])=>({x,y:floorAt(x,z,arena),z})),arena};
for(const [relative,text] of [[`port/native-multiplayer-worlds/worlds/${ID}.json`,body],[`godot/multiplayer_worlds/generated/${ID}.json`,JSON.stringify(data)+'\n']]){
 const file=new URL('../../../../'+relative,import.meta.url);
 if(process.argv.includes('--check')){if(readFileSync(file,'utf8')!==text)throw Error('Stale '+relative);}else{mkdirSync(new URL('.',file),{recursive:true});writeFileSync(file,text);}
}
console.log(JSON.stringify({id:ID,geometryHash:data.geometryHash,recipeHash:data.recipeHash,walls:arena.terrain.walls.length,surfaces:arena.terrain.surfaces.length,routes:arena.routes.length,rooms:arena.structures.length*3,warnings:validation.warnings}));

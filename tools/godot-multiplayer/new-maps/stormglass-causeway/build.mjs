import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {ID,makeStormglass} from './recipe.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../../..');
const arena=makeStormglass(),body=JSON.stringify(arena)+'\n';
const sha=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const wrapper={schemaVersion:1,id:ID,name:arena.name,geometryHash:sha(arena.terrain),recipeHash:sha(arena),spawnPoints:arena.spawns.map(([x,z])=>({x,y:0,z})),arena};
for(const [rel,data] of [[`port/native-multiplayer-worlds/worlds/${ID}.json`,body],[`godot/multiplayer_worlds/generated/worlds/${ID}.json`,body],[`godot/multiplayer_worlds/generated/${ID}.json`,JSON.stringify(wrapper)+'\n']]){
  const dest=path.join(root,rel);
  if(process.argv.includes('--check')){if(fs.readFileSync(dest,'utf8')!==data)throw Error(`Stale ${rel}`);}
  else {fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,data);}
}
console.log(JSON.stringify({id:ID,...arena.metrics,geometryHash:wrapper.geometryHash,meshes:arena.art.meshes.length,walls:arena.terrain.walls.length}));

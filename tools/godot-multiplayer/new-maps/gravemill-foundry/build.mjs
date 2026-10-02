import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
import {recipe,ID} from './recipe.mjs';
const root=new URL('../../../../',import.meta.url),arena=recipe();
const body=JSON.stringify(arena)+'\n',recipeHash=createHash('sha256').update(body).digest('hex');
const data={schemaVersion:1,id:ID,name:arena.name,geometryHash:createHash('sha256').update(canonical(arena)).digest('hex'),recipeHash,spawnPoints:arena.spawns.map(([x,z])=>({x,y:terrainSupportAt(x,z,arena.terrain,arena.terrain.maxSlope).y,z})),arena};
const probes={geometryHash:data.geometryHash,points:[]};
for(const r of arena.routes)for(let i=1;i<r.points.length;i++){const a=r.points[i-1],b=r.points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);for(let j=0;j<=n;j++){const x=a[0]+(b[0]-a[0])*j/n,z=a[1]+(b[1]-a[1])*j/n;probes.points.push({route:r.id,x,y:terrainSupportAt(x,z,arena.terrain,.8).y,z});}}
for(const [path,text] of [[`port/native-multiplayer-worlds/worlds/${ID}.json`,body],[`godot/multiplayer_worlds/generated/worlds/${ID}.json`,body],[`godot/multiplayer_worlds/generated/${ID}.json`,JSON.stringify(data)+'\n'],[`godot/multiplayer_worlds/generated/${ID}-probes.json`,JSON.stringify(probes)+'\n']]){
 const file=new URL(path,root);fs.mkdirSync(new URL('.',file),{recursive:true});if(process.argv.includes('--check')){if(fs.readFileSync(file,'utf8')!==text)throw Error(`Stale ${path}`);}else fs.writeFileSync(file,text);
}
console.log(JSON.stringify({id:ID,recipeHash,geometryHash:data.geometryHash,surfaces:arena.terrain.surfaces.length,walls:arena.terrain.walls.length,navNodes:arena.navNodes.length},null,2));

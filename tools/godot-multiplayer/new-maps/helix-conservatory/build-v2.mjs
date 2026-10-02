import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {recipe,hash} from './recipe-v2.mjs';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
const root=new URL('../../../../port/new-maps/helix-conservatory/revision-2/',import.meta.url);
const body=JSON.stringify(recipe)+'\n',recipeHash=createHash('sha256').update(body).digest('hex'),geometryHash=createHash('sha256').update(canonical(recipe)).digest('hex');
const authority={schemaVersion:1,id:recipe.id,name:recipe.name,recipeHash,geometryHash,spawnPoints:recipe.spawns.map(([x,z])=>({x,y:terrainSupportAt(x,z,recipe.terrain,.8).y,z})),arena:recipe};
const report={id:recipe.id,revision:2,status:'ready-for-second-Blender-pass-source-only',recipeHash,geometryHash,meshHash:hash(recipe.art.meshes),sourceLock:'515daf',reviewedDerivative:'0326',nativeAcceptedModes:[],supersedesVisualBriefOnly:'becef6b4 + 96174a63 preserved functional checkpoint',parts:recipe.art.meshes.length,triangles:recipe.art.meshes.reduce((n,p)=>n+p.triangles.length,0),bodyWallTriangles:recipe.terrain.walls.length,plannedMeshBatches:new Set(recipe.art.meshes.map(p=>`${p.material}/${p.collision}/${p.walkable}`)).size,materials:[...new Set(recipe.art.meshes.map(p=>p.material))],primaryRoutes:recipe.verification.primaryRouteIds,interiorRoutes:recipe.verification.interiorRouteIds,districts:recipe.structures};
fs.mkdirSync(root,{recursive:true});
for(const [name,bytes]of Object.entries({'recipe.json':body,'authority.json':JSON.stringify(authority)+'\n','provenance.json':JSON.stringify(report,null,2)+'\n'})){
 const dest=new URL(name,root);if(process.argv.includes('--check')){if(fs.readFileSync(dest,'utf8')!==bytes)throw Error('Stale '+name);}else fs.writeFileSync(dest,bytes);
}
console.log(JSON.stringify(report,null,2));

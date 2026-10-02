import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {recipe,hash} from './recipe-v2.mjs';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
import {createHash} from 'node:crypto';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
const root=new URL('../../../../',import.meta.url);
const bytes=JSON.stringify(recipe)+'\n';
const recipeHash=createHash('sha256').update(bytes).digest('hex');
const geometryHash=createHash('sha256').update(canonical(recipe)).digest('hex');
const data={schemaVersion:1,id:recipe.id,name:recipe.name,geometryHash,recipeHash,spawnPoints:recipe.spawns.map(([x,z])=>({x,z,y:terrainSupportAt(x,z,recipe.terrain,.8).y})),arena:recipe};
const outputs={
 'port/native-multiplayer-worlds/worlds/helix-conservatory.json':bytes,
 'godot/multiplayer_worlds/generated/helix-conservatory.json':JSON.stringify(data)+'\n',
 'port/new-maps/helix-conservatory/provenance.json':JSON.stringify({id:recipe.id,recipeHash,geometryHash,meshHash:hash(recipe.art.meshes),sourceLock:'515daf',reviewedDerivative:'0326',status:'native-scene-accepted-package-pending',modes:['deathmatch','teamdeathmatch','ctf','domination','koth'],sourceOnlyModes:['arsenal','juggernaut'],candidateModes:recipe.candidateModes,artPath:'res://multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb',visualCoverage:'complete-terrain',blendMaster:'tools/godot-multiplayer/new-maps/helix-conservatory/masters/helix-conservatory.blend',meshCount:recipe.art.meshes.length,triangles:recipe.art.meshes.reduce((n,m)=>n+m.triangles.length,0)},null,2)+'\n'};
const provenance=JSON.parse(outputs['port/new-maps/helix-conservatory/provenance.json']);
provenance.revision=2;
provenance.blendMaster='tools/godot-multiplayer/new-maps/helix-conservatory/masters/revision-2/helix-conservatory.blend';
provenance.acceptance='port/new-maps/helix-conservatory/revision-2/production-validation.json';
outputs['port/new-maps/helix-conservatory/provenance.json']=JSON.stringify(provenance,null,2)+'\n';
for(const [path,body]of Object.entries(outputs)){const url=new URL(path,root);if(process.argv.includes('--check')){if(fs.readFileSync(url,'utf8')!==body)throw Error(`Stale ${path}`);}else{fs.mkdirSync(fileURLToPath(new URL('.',url)),{recursive:true});fs.writeFileSync(url,body);}}
console.log(JSON.parse(outputs['port/new-maps/helix-conservatory/provenance.json']));

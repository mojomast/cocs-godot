import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical} from '../../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';
import {recipe} from '../revision3/recipe.mjs';
const root=new URL('../../../../../',import.meta.url),here=new URL('./',import.meta.url);
const shapes=JSON.parse(fs.readFileSync(new URL('shapes.json',here))),arena=recipe();
const acceptedWalls=arena.terrain.walls.length;
for(const shape of shapes.shapes)for(const [faceIndex,face] of shape.faces.entries())
 arena.terrain.walls.push({id:`r5-${shape.id}-${faceIndex}`,material:'soot',vertices:face.map(n=>shape.vertices[n])});
arena.art.revision5={status:'staged-corrective-production',sharedShapeSpecSha256:createHash('sha256').update(fs.readFileSync(new URL('shapes.json',here))).digest('hex'),
 sourceRevision:3,rejectedRevision:4,acceptedWalls,addedWallPolygons:arena.terrain.walls.length-acceptedWalls,
 addedWallTriangles:shapes.shapes.reduce((n,s)=>n+s.faces.reduce((m,f)=>m+f.length-2,0),0),walkableGrades:'unchanged',extraWalkableDecks:0};
const sha=s=>createHash('sha256').update(s).digest('hex'),body=JSON.stringify(arena)+'\n';
const candidate={schemaVersion:1,id:arena.id,name:arena.name,recipeHash:sha(body),geometryHash:sha(canonical(arena)),
 spawnPoints:arena.spawns.map(([x,z])=>({x,y:terrainSupportAt(x,z,arena.terrain,.8).y,z})),arena};
for(const url of [new URL('candidate.json',here),new URL('godot/multiplayer_worlds/generated/revisions/gravemill-foundry-r5.json',root)]){
 const text=JSON.stringify(candidate)+'\n';if(process.argv.includes('--check')){if(fs.readFileSync(url,'utf8')!==text)throw Error('Stale candidate');}else fs.writeFileSync(url,text);
}
console.log(JSON.stringify({hash:candidate.geometryHash,shapes:shapes.shapes.length,...arena.art.revision5}));

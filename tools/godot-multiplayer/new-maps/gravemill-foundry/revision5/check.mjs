import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {canonical,worldEntry} from '../../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';
import {rayWorld} from '../../../../../game/core.mjs';
const here=new URL('./',import.meta.url),read=n=>JSON.parse(fs.readFileSync(new URL(n,here)));
const data=read('candidate.json'),a=data.arena,old=JSON.parse(fs.readFileSync(new URL('../../../../../godot/multiplayer_worlds/generated/gravemill-foundry.json',here))).arena;
assert.equal(data.geometryHash,createHash('sha256').update(canonical(a)).digest('hex'));
assert.deepEqual(a.terrain.surfaces,old.terrain.surfaces);assert.deepEqual(a.routes,old.routes);
const modes=['deathmatch','teamdeathmatch','domination','assault','payload','combined-arms'];for(const mode of modes)worldEntry(a.id,mode);
const sub=(a,b)=>a.map((v,i)=>v-b[i]),dot=(a,b)=>a.reduce((v,x,i)=>v+x*b[i],0),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const visual=read('visual-triangles.json');
function visualRay(o,d,max){let best=max;for(const [a,b,c]of visual){const e1=sub(b,a),e2=sub(c,a),p=cross(d,e2),det=dot(e1,p);if(Math.abs(det)<1e-8)continue;const t=sub(o,a),u=dot(t,p)/det,q=cross(t,e1),v=dot(d,q)/det,dist=dot(e2,q)/det;if(u>=0&&v>=0&&u+v<=1&&dist>=0&&dist<best)best=dist;}return best;}
const rays=[
 ['bunker-0-upper',[-139,5.5,-112.48],[1,0,0],14,true],['bunker-2-upper',[-57,4,-101],[1,0,0],14,true],
 ['tipple-left-jamb',[44,2,-30],[1,0,0],2.2,true],['tipple-right-jamb',[56,2,-30],[1,0,0],2.2,true],
 ['old-unsheared-conveyor',[-45,33,-6.5],[0,0,1],5,false],['sheared-conveyor',[-45,33,-12.8],[0,0,1],5,true],
 ['tipple-51-clear-aperture',[51,1.3,-32],[0,0,1],4,false],['tipple-82-clear-aperture',[82,1.3,-34],[0,0,1],4,false]];
const rayResults=rays.map(([id,o,d,max,blocked])=>{const visual=visualRay(o,d,max),authority=rayWorld({x:o[0],y:o[1],z:o[2]},{x:d[0],y:d[1],z:d[2]},max,a);assert.equal(visual<max,blocked,id);assert.equal(authority<max,blocked,id);assert.ok(Math.abs(visual-authority)<.04,`${id}: ${visual} vs ${authority}`);return{id,origin:o,direction:d,max,visual,authority,blocked};});
const points=[];const put=(id,x,z)=>{const s=terrainSupportAt(x,z,a.terrain,a.terrain.maxSlope);assert.ok(s,id);points.push({id,x,y:s.y,z});};
a.navNodes.forEach((p,i)=>put('nav-'+i,p.x,p.z));a.spawns.forEach(([x,z],i)=>put('spawn-'+i,x,z));
for(const [team,pool]of Object.entries(a.teamSpawns))pool.forEach(([x,z],i)=>put(`team-${team}-${i}`,x,z));
a.objectiveZones.forEach((p,i)=>put('objective-'+i,p.x,p.z));
for(const route of a.routes)for(let i=1;i<route.points.length;i++){
 const [a,b]=[route.points[i-1],route.points[i]],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1]));
 for(let j=0;j<=n;j++)put(`route-${route.id}-${i}-${j}`,a[0]+(b[0]-a[0])*j/n,a[1]+(b[1]-a[1])*j/n);
}
const cameras=[['overview',[250,185,-250],[0,14,0]],['crusher-eye',[-94,1.45,-51.16],[-49,8,-27]],
 ['crusher-maintenance',[-88,11.53,4.68],[-65,14,-8]],['furnace-eye',[88,1.45,-25.68],[64,10,-10]],
 ['transfer-eye',[0,1.45,-64],[27,5,-58]],['kiln-eye',[75,2,-57],[79,12,-26]],
 ['crusher-roofline',[-148,49,-85],[-78,37,-18]],['furnace-skyline',[143,50,-85],[73,32,9]],
 ['cooling-eye',[-82,13.45,24.52],[-46,16,29.56]],['bunker-player',[-145,1.45,-123],[-132,5,-112.48]],
 ['tipple-player',[51,1.45,-37],[51,6,-30]]];
const cameraChecks=cameras.map(([id,eye,target])=>({id,eye,target,ground:terrainSupportAt(eye[0],eye[2],a.terrain,.8)?.y??null}));
for(const c of cameraChecks)if(c.ground!==null)assert.ok(c.eye[1]>c.ground,c.id);
for(const c of cameraChecks)if(c.ground!==null&&c.eye[1]-c.ground<2.1)put('camera-'+c.id,c.eye[0],c.eye[2]);
const report={geometryHash:data.geometryHash,modes,rayResults,cameraChecks,clearancePoints:points.length,navPoints:a.navNodes.length,
 authority:{acceptedWalls:old.terrain.walls.length,rejectedR4Walls:2368,currentWalls:a.terrain.walls.length,walkableSurfacesUnchanged:true},nativeCapsules:'pending'};
fs.writeFileSync(new URL('source-validation.json',here),JSON.stringify(report,null,2)+'\n');
fs.mkdirSync(new URL('../../../../../godot/tests/new_maps/gravemill_foundry/revision5/',here),{recursive:true});
fs.writeFileSync(new URL('../../../../../godot/tests/new_maps/gravemill_foundry/revision5/probes.json',here),JSON.stringify({geometryHash:data.geometryHash,points,rays:rayResults,cameras:cameraChecks})+'\n');
console.log(JSON.stringify(report));

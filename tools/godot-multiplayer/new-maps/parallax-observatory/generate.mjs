#!/usr/bin/env node
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
export const id='parallax-observatory';
const root=new URL('../../../../',import.meta.url);
const height=z=>z<-60?24:z<-12?12+(-z-12)/4:z<=12?12:z<60?12-(z-12)/4:0;
const surfaces=[],walls=[],blocks=[],overhead=[],navNodes=[];
const routes=[
 {id:'meridian-lens',points:[[-108,0],[-72,0],[-36,0],[0,0],[36,0],[72,0],[108,0]],width:18},
 {id:'armillary-arc',points:[[-108,0],[-96,-24],[-66,-60],[-32,-78],[0,-84],[32,-78],[66,-60],[96,-24],[108,0]],width:14},
 {id:'tidal-cistern',points:[[-108,0],[-90,30],[-60,66],[-24,78],[24,78],[42,78],[60,66],[90,30],[108,0]],width:14},
 {id:'west-calibration',points:[[-60,-66],[-54,-36],[-54,0],[-54,36],[-60,66]],width:12},
 {id:'east-instrument',points:[[60,-66],[54,-36],[54,0],[54,36],[60,66]],width:12},
 {id:'polar-crosslink',points:[[0,-84],[0,-48],[0,0],[0,42],[0,78]],width:12},
];
// Every surface shares this piecewise plane. Intersecting routes cannot create
// competing heights under the source's highest-XZ-floor semantics.
function clip(poly,z,less){const out=[];for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],da=(a[1]-z)*(less?-1:1),db=(b[1]-z)*(less?-1:1);if(da>=-1e-8)out.push(a);if(da*db<0){const t=da/(da-db);out.push([a[0]+t*(b[0]-a[0]),z]);}}return out;}
function floor(name,poly,material='saltstone'){
 for(const [lo,hi] of [[-200,-60],[-60,-12],[-12,12],[12,60],[60,200]]){
  const p=clip(clip(poly,lo,false),hi,true);if(p.length<3)continue;
  const area=p.reduce((s,a,i)=>s+a[0]*p[(i+1)%p.length][1]-p[(i+1)%p.length][0]*a[1],0);if(Math.abs(area)<1e-7)continue;
  if(area>0)p.reverse();surfaces.push({id:`${name}-${lo}`,material,walkable:true,vertices:p.map(([x,z])=>[x,height(z),z]),triangles:Array.from({length:p.length-2},(_,i)=>[0,i+1,i+2])});
 }
}
function disk(name,x,z,r,n=12,material='saltstone'){floor(name,Array.from({length:n},(_,i)=>[x+Math.cos(i*2*Math.PI/n)*r,z+Math.sin(i*2*Math.PI/n)*r]),material);}
for(const route of routes){
 route.points.forEach(([x,z],i)=>disk(`${route.id}-joint-${i}`,x,z,route.width/2,12,route.id==='tidal-cistern'?'cistern':'saltstone'));
 for(let i=1;i<route.points.length;i++){
  const a=route.points[i-1],b=route.points[i],dx=b[0]-a[0],dz=b[1]-a[1],l=Math.hypot(dx,dz),nx=-dz/l*route.width/2,nz=dx/l*route.width/2;
  floor(`${route.id}-span-${i}`,[[a[0]+nx,a[1]+nz],[b[0]+nx,b[1]+nz],[b[0]-nx,b[1]-nz],[a[0]-nx,a[1]-nz]],route.id==='tidal-cistern'?'cistern':'saltstone');
  for(let j=0;j<=Math.ceil(l/3);j++){const t=j/Math.ceil(l/3);navNodes.push([a[0]+dx*t,a[1]+dz*t]);}
 }
}
disk('arrival-plaza',-108,0,20,12);disk('vault-district',108,0,18,8,'metal');disk('central-lens-dais',0,0,19,16,'mirror');
const box=(id,x,z,w,d,baseY,h,material='metal')=>blocks.push({id,kind:'structure',x,z,w,d,baseY,h,material});
function slab(id,x,z,w,d,minY,maxY){
 overhead.push({id,x,z,w,d,minY,maxY});
 const v=[[x-w/2,minY,z-d/2],[x-w/2,minY,z+d/2],[x+w/2,minY,z+d/2],[x+w/2,minY,z-d/2]];
 surfaces.push({id:`${id}-underside`,material:'metal',walkable:false,vertices:v,triangles:[[0,2,1],[0,3,2]]},{id:`${id}-top`,material:'saltstone',walkable:false,vertices:v.map(([x,,z])=>[x,maxY,z]),triangles:[[0,1,2],[0,2,3]]});
 for(let i=0;i<4;i++){const a=v[i],b=v[(i+1)%4];walls.push({id:`${id}-edge-${i}`,material:'metal',vertices:[a,b,[b[0],maxY,b[2]],[a[0],maxY,a[2]]]});}
}
// Two through-interiors. Both short ends are actual open arch mouths; the
// ceiling slab begins 4.8m above the floor, never a full-height proxy AABB.
for(const [name,x,z,y] of [['ephemeris-vault',-36,0,12],['tidal-pump-vault',24,78,0]]){
 floor(name,[[x-13,z-8],[x+13,z-8],[x+13,z+8],[x-13,z+8]],'cistern');
 for(const side of [-1,1]){
  box(`${name}-wall-${side}`,x,z+side*7.6,26,.8,y,y+4.8,'saltstone');
  for(const end of [-1,1])box(`${name}-jamb-${side}-${end}`,x+end*12.6,z+side*5.4,.8,4.4,y,y+4.8,'saltstone');
  box(`${name}-console-${side}`,x+side*6,z+side*5.9,3,1,y,y+1.3,'metal');
 }
 slab(name+'-ceiling',x,z,26,16,y+4.8,y+5.4);
}
// Overhead instrument-service bridges are sealed maintenance structures, not
// advertised stacked walkable routes (unsupported by highest-floor authority).
slab('meridian-service-gallery',36,0,8,24,18,19);
for(const z of [-11,11])box(`gallery-pier-${z}`,36,z,2,2,12,18,'saltstone');
// Monumental polar instrument hall: four open axial mouths retain the upper
// arc and central crosslink. This is a third real, walkable enclosed interior.
floor('polar-hall-foundation',[[-19,-97],[19,-97],[19,-71],[-19,-71]],'paving');
for(const side of [-1,1]){
 for(const half of [-1,1]){
  box(`polar-hall-end-${side}-${half}`,side*18, -84+half*9,1,8,24,32,'saltstone');
  box(`polar-hall-side-${side}-${half}`,half*12,-84+side*12,12,1,24,32,'saltstone');
 }
}
slab('polar-hall-ceiling',0,-84,37,25,32,33);
// Public/instrument street wings: source-solid inhabited masses, recessed
// mirror panels and roof machinery will be authored against these footprints.
for(const [x,z,w,d,h] of [[-84,10,12,5,23],[-66,-10,10,5,25],[-18,-10,9,5,22],[18,10,9,5,24],[84,-10,12,5,25],[82,10,10,5,23]]){
 box(`institute-wing-${x}-${z}`,x,z,w,d,-17,h,z<0?'saltstone':'metal');
}
// Deep eastern optical arcade; broad axial passage and open sides connect
// the instrument district to the east crosslink without phantom openings.
slab('optical-arcade-ceiling',69,0,30,17,19,20);
for(const x of [56,64,72,80])for(const z of [-7.6,7.6])box(`arcade-column-${x}-${z}`,x,z,1,1,12,19,'saltstone');
// Instrument masses and cover stay off the authored route center lines.
for(const side of [-1,1]){
 box(`district-baffle-${side}`,side*114,10,9,2,12,15,'saltstone');
 box(`flag-cover-${side}`,side*115,-6,3,5,12,14.5,'metal');
 for(const x of [-78,-18,18,78])box(`meridian-calibrator-${side}-${x}`,x,side*6.5,3,2,12,14.2,side<0?'mirror':'metal');
 for(const x of [-54,54])box(`slope-buttress-${side}-${x}`,x+7.5,side*36,2,8,height(side*36+4),height(side*36-4)+2,'saltstone');
}
// Railings on the exposed north and south viewing decks; ramp edges are
// visually marked in the art recipe, while the broad lanes permit recovery.
for(const z of [-89.5,84])for(const x of [-18,18])box(`sea-rail-${x}-${z}`,x,z,26,.35,height(z),height(z)+1.2,'ochre');
const west=[[-116,0],[-108,-8],[-101,7],[-120,5]],east=[[116,0],[108,-8],[101,7],[120,3]];
const arena={id,name:'Parallax Observatory',description:'Chalk-island astronomical institute: armillary arc, lens meridian, tidal cistern and three crosslinks.',tag:'COAST / ASTRONOMICAL',color:'#c5b9a1',background:'#141b32',bounds:{minX:-160,maxX:160,minZ:-128,maxZ:128},spawns:west.flatMap((p,i)=>[p,east[i]]),teamSpawns:{0:west,1:east},flagSpawns:{0:{x:-108,z:0},1:{x:108,z:0}},objectiveZones:[{id:'lens-dais',x:0,y:12,z:0,radius:7},{id:'armillary',x:0,y:24,z:-84,radius:5},{id:'cistern',x:0,y:0,z:78,radius:5}],pickups:[['health',-36,0],['health',24,78],['armor',-54,-36],['armor',54,36],['rail',0,-84],['rocket',0,0],['plasma',0,78],['scatter',54,0]],navNodes,blocks,overhead,terrain:{maxSlope:.48,surfaces,walls},voidY:-18,ceilingY:100,raised:false,nextGen:true};
// Boundary parapets are emitted only when the outward point lacks support.
// No rail crosses a route union, door mouth, or ramp/landing seam.
for(const surface of surfaces.filter(s=>s.walkable))for(let i=0;i<surface.vertices.length;i++){
 const a=surface.vertices[i],b=surface.vertices[(i+1)%surface.vertices.length],dx=b[0]-a[0],dz=b[2]-a[2],l=Math.hypot(dx,dz),n=Math.ceil(l/3);
 if(l<.01)continue;const nx=-dz/l,nz=dx/l;
 for(let j=0;j<n;j++){
  const t=(j+.5)/n,x=a[0]+dx*t,z=a[2]+dz*t;
  if(terrainSupportAt(x+nx*.8,z+nz*.8,arena.terrain))continue;
  const p=[a[0]+dx*j/n,height(a[2]+dz*j/n),a[2]+dz*j/n],q=[a[0]+dx*(j+1)/n,height(a[2]+dz*(j+1)/n),a[2]+dz*(j+1)/n];
  walls.push({id:`parapet-${surface.id}-${i}-${j}`,material:'saltstone',vertices:[p,q,[q[0],q[1]+1.1,q[2]],[p[0],p[1]+1.1,p[2]]]});
  walls.push({id:`cliff-${surface.id}-${i}-${j}`,material:'saltstone',vertices:[[p[0],-17,p[2]],[q[0],-17,q[2]],q,p]});
 }
}
// terrainWallSegments consumes polygon perimeter edges, not face area. A quad
// taller than the actor exposes only horizontal edges outside the body span.
// Individual triangles retain the diagonal's full height for source movement,
// while preserving exactly the same rendered/ray geometry and slab openings.
walls.splice(0,walls.length,...walls.flatMap(w=>Array.from({length:w.vertices.length-2},(_,i)=>({...w,id:`${w.id}-tri-${i}`,vertices:[w.vertices[0],w.vertices[i+1],w.vertices[i+2]]}))));
const geometryHash=createHash('sha256').update(canonical(arena)).digest('hex');
const art={seed:20261002,palette:{saltstone:'#b9b5a4',paving:'#8e919a',metal:'#242a38',ochre:'#ba863d',mirror:'#707d99',cistern:'#565b74',sea:'#242c49'},landmarks:[{id:'tilting-primary-dish',kind:'dish',x:-68,y:37,z:-94,r:27,tilt:.57},{id:'eastern-spectrograph',kind:'dish',x:79,y:29,z:-83,r:16,tilt:-.38},{id:'polar-armillary',kind:'armillary',x:0,y:42,z:-84,r:14},{id:'arrival-dome',kind:'dome',x:-116,y:19,z:19,r:14},{id:'instrument-dome',kind:'dome',x:115,y:19,z:18,r:12}],cameras:[{id:'arrival-eye',eye:[-111,13.65,-3],target:[0,20,-60]},{id:'lens-eye',eye:[8,13.65,5],target:[-50,30,-85]},{id:'cistern-eye',eye:[-10,1.65,78],target:[24,2,78]},{id:'overview',eye:[185,160,210],target:[0,10,0]}],budgets:{triangles:160000,materialBatches:7,glbBytes:16000000}};
art.cameras.push({id:'archive-interior',eye:[-45,13.65,0],target:[-25,14,3]},{id:'polar-interior',eye:[-12,25.65,-84],target:[13,28,-80]},{id:'arcade-eye',eye:[54,13.65,0],target:[89,16,0]},{id:'pump-interior',eye:[15,1.65,78],target:[34,2.5,81]});
const recipe={schemaVersion:1,...arena,art,routes:routes.map(r=>({...r,points:r.points.map(([x,z])=>({x,y:height(z),z}))}))};
const recipeBytes=JSON.stringify(recipe,null,2)+'\n';
const data={schemaVersion:1,id,name:arena.name,geometryHash,recipeHash:createHash('sha256').update(recipeBytes).digest('hex'),arena,spawnPoints:arena.spawns.map(([x,z])=>({x,y:terrainSupportAt(x,z,arena.terrain)?.y,z})),routes:recipe.routes,art};
for(const [path,bytes] of [[`port/native-multiplayer-worlds/worlds/${id}.json`,recipeBytes],[`godot/multiplayer_worlds/generated/${id}.json`,JSON.stringify(data,null,2)+'\n']]){
 const url=new URL(path,root);if(process.argv.includes('--check')){if(readFileSync(url,'utf8')!==bytes)throw Error(`Stale ${path}`);}else{mkdirSync(new URL('.',url),{recursive:true});writeFileSync(url,bytes);}
}
console.log(JSON.stringify({id,geometryHash,surfaces:surfaces.length,blocks:blocks.length,navNodes:navNodes.length}));

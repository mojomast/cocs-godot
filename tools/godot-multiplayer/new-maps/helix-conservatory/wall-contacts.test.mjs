// Regression for terrainWallSegments' perimeter-only body collision contract.
// Production geometry is unchanged; the quad version below is a negative control.
import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {recipe,hash} from './recipe.mjs';
import {moveActor,floorAt,obstructed,rayWorld} from '../../../../game/core.mjs';
import {terrainWallSegments} from '../../../../game/terrain.mjs';
import {RULES} from '../../../../game/data.mjs';
const rows=[];
const part=id=>{const p=recipe.art.meshes.find(m=>m.id===id);assert.ok(p,id);return p;};
function body(x,z,arena){const y=floorAt(x,z,arena);assert.notEqual(y,null);assert.ok(!obstructed(x,y,z,RULES.radius,arena),'fixture starts clear');return {x,y,z,vx:0,vy:0,vz:0,grounded:true,moveSpeed:7,health:100};}
function push(arena,a,input,frames){let maxStep=0;for(let i=0;i<frames;i++){const old={x:a.x,z:a.z};moveActor(a,input,1/60,arena);assert.ok([a.x,a.y,a.z].every(Number.isFinite));maxStep=Math.max(maxStep,Math.hypot(a.x-old.x,a.z-old.z));}return maxStep;}
function bounds(p){return {minX:Math.min(...p.vertices.map(v=>v[0])),maxX:Math.max(...p.vertices.map(v=>v[0])),minZ:Math.min(...p.vertices.map(v=>v[2])),maxZ:Math.max(...p.vertices.map(v=>v[2])),minY:Math.min(...p.vertices.map(v=>v[1])),maxY:Math.max(...p.vertices.map(v=>v[1]))};}
function contact(id,axis,side,crossOverride){
 const b=bounds(part(id)),min=axis==='x'?b.minX:b.minZ,max=axis==='x'?b.maxX:b.maxZ,face=side<0?min:max;
 const cross=crossOverride??(axis==='x'?(b.minZ+b.maxZ)/2:(b.minX+b.maxX)/2),start=face+side*3;
 const a=body(axis==='x'?start:cross,axis==='z'?start:cross,recipe),initial={x:a.x,y:a.y,z:a.z};
 const maxStep=push(recipe,a,{[axis]:-side},600),gap=side*(a[axis]-face);
 // Ten seconds is >60m unobstructed travel: enough to expose thin-wall leakage.
 assert.ok(gap>=RULES.radius-1e-6,`${id} side ${side} penetrated: ${gap}`);
 assert.ok(gap<RULES.radius+.16,`${id} stopped before tested wall: ${gap}`);
 assert.ok(Math.abs(a.y-floorAt(a.x,a.z,recipe))<.01,'actor remains on real support');
 assert.ok(!obstructed(a.x,a.y,a.z,RULES.radius,recipe),'stopped actor is clear');
 const end={x:a.x,y:a.y,z:a.z};push(recipe,a,{[axis]:-side},120);
 assert.ok(Math.hypot(a.x-end.x,a.z-end.z)<.005,'sustained pressure stays stopped');
 rows.push({id,axis,side,frames:720,initial,end,gap,maxStep});
}

test('all 712 production walls are triangles with full-height projected diagonal segments',()=>{
 assert.equal(recipe.terrain.walls.length,712);
 for(const w of recipe.terrain.walls){assert.equal(w.vertices.length,3);const segments=terrainWallSegments({surfaces:[],walls:[w]});const low=Math.min(...w.vertices.map(v=>v[1])),high=Math.max(...w.vertices.map(v=>v[1]));assert.ok(segments.some(s=>Math.min(s.a.y,s.b.y)===low&&Math.max(s.a.y,s.b.y)===high),w.id);}
});

test('ground pier, archive walls, low parapets and crown feet stop both-side continuous input',()=>{
 for(const side of [-1,1]){
  contact('aqueduct-pier-1-14','x',side);
  // z=7 is the clear space beyond the seed drawers; avoids testing a shelf by mistake.
  contact('irrigation-laboratory-side--1','x',side,7);
  contact('planter-20-7','x',side);
  contact('planter-57-3','x',side);
  contact('planter-91-0','x',side);
  contact('rib-foot-0','z',side);
 }
 assert.ok(rows.some(r=>Math.abs(r.initial.y-r.end.y)>.1),'at least one sloped-ground wall approach exercised');
});

test('open archive portal and aqueduct underpass admit sustained movement',()=>{
 for(const dir of [-1,1]){
  const a=body(52,-dir*13,recipe);push(recipe,a,{z:dir},240);assert.ok(dir*a.z>11,`portal crossing ${dir}`);assert.ok(Math.abs(a.y-8)<.01);
  const b=body(0,16-dir*5,recipe);push(recipe,b,{z:dir},100);assert.ok(dir*(b.z-16)>5,`underpass ${dir}`);assert.ok(Math.abs(b.y)<.01);
  rows.push({id:'portal-and-underpass',direction:dir,portalEnd:{x:a.x,y:a.y,z:a.z},underpassEnd:{x:b.x,y:b.y,z:b.z}});
 }
});

test('negative-control merged quads reproduce standing-body leakage while shots still block',()=>{
 const target=part('aqueduct-pier-1-14');
 const quads=[];for(let i=0;i<target.triangles.length;i+=2){const a=target.triangles[i],b=target.triangles[i+1];quads.push({id:target.id,vertices:[a[0],a[1],a[2],b[2]].map(j=>target.vertices[j])});}
 const broken={...recipe,id:'helix-wall-negative-control',terrain:{...recipe.terrain,walls:[...recipe.terrain.walls.filter(w=>w.id!==target.id),...quads]}};
 const start=body(10,16,broken),shot=rayWorld({x:10,y:1.45,z:16},{x:1,y:0,z:0},10,broken);
 assert.ok(shot<4,'quad control still blocks source shots');
 push(broken,start,{x:1},120);assert.ok(start.x>16,`control must cross the solid wall, got ${start.x}`);
 const correct=body(10,16,recipe);push(recipe,correct,{x:1},120);assert.ok(correct.x<=13.35-RULES.radius+1e-6);
 rows.push({id:'same-wall-triangles-vs-quad-control',frames:120,shotDistance:shot,quadControlEnd:{x:start.x,y:start.y,z:start.z},productionEnd:{x:correct.x,y:correct.y,z:correct.z},productionGap:13.35-correct.x});
});

after(()=>{
 console.log(JSON.stringify({recipeContentHash:hash(recipe),wallPolygons:recipe.terrain.walls.length,rows}));
 if(process.env.HELIX_WRITE_CONTACT_REPORT==='1'&&rows.length===15)fs.writeFileSync(new URL('../../../../port/new-maps/helix-conservatory/wall-contact-validation.json',import.meta.url),JSON.stringify({id:recipe.id,classification:'source-only continuous-input wall contacts; quad negative control is test-only',recipeContentHash:hash(recipe),wallPolygons:712,productionGeometryChanged:false,rows},null,2)+'\n');
});

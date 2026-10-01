#!/usr/bin/env node
// Deterministic urban source-Match geometry. Run with --check to verify bytes.
import {createHash} from 'node:crypto';
import {readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const root = new URL('../../../godot/multiplayer_worlds/generated/', import.meta.url);
const canonical = value => Array.isArray(value) ? `[${value.map(canonical).join(',')}]` : value && typeof value === 'object'
  ? `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}` : JSON.stringify(value);
const rect = (id,x0,x1,z0,z1,y0,y1,material='concrete') => ({id,material,walkable:true,
  vertices:[[x0,y0,z0],[x0,y0,z1],[x1,y1,z1],[x1,y1,z0]],triangles:[[0,1,2],[0,2,3]]});
const box = (id,x,z,w,d,h,material='concrete',baseY=0) => ({id,kind:'structure',x,z,w,d,h,baseY,material});
const wall = (id,x0,z0,x1,z1,y0=0,y1=4,material='concrete') => ({id,material,vertices:[[x0,y0,z0],[x1,y0,z1],[x1,y1,z1],[x0,y1,z0]]});
const perimeter = (blocks,spec) => {
  const {id,x,z,w,d,open='south',accent='concrete'}=spec, left=x-w/2,right=x+w/2,near=z-d/2,far=z+d/2;
  const side = .55, door=2.1;
  if(open !== 'north') blocks.push(box(`${id}-north`,x,far-side/2,w,side,3.8,accent));
  if(open !== 'south') blocks.push(box(`${id}-south`,x,near+side/2,w,side,3.8,accent));
  if(open !== 'west') blocks.push(box(`${id}-west`,left+side/2,z,side,d,3.8,accent));
  if(open !== 'east') blocks.push(box(`${id}-east`,right-side/2,z,side,d,3.8,accent));
  if(open === 'north'||open === 'south') {
    const zz=open==='north'?far-side/2:near+side/2;
    blocks.push(box(`${id}-entry-l`,(left+x-door)/2,zz,x-door-left,side,3.8,accent));
    blocks.push(box(`${id}-entry-r`,(x+door+right)/2,zz,right-x-door,side,3.8,accent));
  } else {
    const xx=open==='east'?right-side/2:left+side/2;
    blocks.push(box(`${id}-entry-n`,xx,(near+z-door)/2,side,z-door-near,3.8,accent));
    blocks.push(box(`${id}-entry-s`,xx,(z+door+far)/2,side,far-z-door,3.8,accent));
  }
};
function switchyard(){
  const id='switchyard-ward',name='Switchyard Ward',surfaces=[rect('asphalt-city-grid',-38,38,-34,34,0,0,'asphalt')],blocks=[];
  // Four accessible roofs are SOLID roof decks, not an upper floor over an
  // enterable shop: source floorAt deliberately chooses highest support in XZ.
  for(const [n,side,z] of [['nw',-1,-19],['sw',-1,19],['ne',1,-19],['se',1,19]]){
    const x=side*27,inner=side*20,edge=side*9.5;
    surfaces.push(rect(`${n}-roof`,x-7,x+7,z-6,z+6,3.2,3.2,'roof'));
    surfaces.push(rect(`${n}-ramp`,Math.min(inner,edge),Math.max(inner,edge),z-3,z+3,side<0?3.2:0,side<0?0:3.2,'grating'));
    // Body under the elevated deck provides visible occupied mass without
    // obstructing actors atop the deck. Upper ramp remains a true terrain face.
    // Set structural footprint back from the roof/ramp join by > actor radius;
    // an under-ramp corner cannot become an invisible blocker at y=3.15.
    blocks.push(box(`${n}-mass`,x,z,11,11.5,3.19,'brick'));
    blocks.push(box(`${n}-roof-cover-a`,x-3,z-3.8,2.2,1.1,4.4,'steel',3.2));
    blocks.push(box(`${n}-roof-cover-b`,x+3,z+3.8,2.2,1.1,4.4,'steel',3.2));
  }
  // Shops are single floor, truly enterable through their 4.2m doorway;
  // architectural canopy/upper trim is decoration, never phantom support.
  for(const spec of [
    {id:'west-toolshop',x:-18,z:0,w:11,d:9,open:'east',accent:'brick'},
    {id:'east-service',x:18,z:0,w:11,d:9,open:'west',accent:'concrete'},
    {id:'north-ticket',x:0,z:-24,w:10,d:9,open:'south',accent:'brick'},
    {id:'south-depot',x:0,z:24,w:10,d:9,open:'north',accent:'concrete'}
  ])perimeter(blocks,spec);
  // Staggered rail furniture interrupts the 76m streets while keeping
  // symmetric >3m service, flank and flag routes around each courtyard.
  for(const [n,x,z,w,d] of [['rail-w',-5,-12,2,5],['rail-e',5,12,2,5],['shed-w',-5,11,3,2],['shed-e',5,-11,3,2],['island-n',0,-7,2.4,2],['island-s',0,7,2.4,2]])
    blocks.push(box(n,x,z,w,d,1.7,n.startsWith('rail')?'steel':'brick'));
  const nav=[];
  for(let x=-36;x<=36;x+=3)for(let z=-30;z<=30;z+=3)nav.push([x,z]);
  // Deliberate supported spawn positions clear of door mouths and cover.
  const west=[[-31,-10],[-31,10],[-20,-30],[-20,30],[-10,-27],[-10,27]];
  const east=west.map(([x,z])=>[-x,-z]);
  const spawns=west.flatMap((p,i)=>[p,east[i]]);
  const zones=[{id:'west-arch',x:-11,z:0,y:0,radius:3.5},{id:'station',x:0,z:0,y:0,radius:4},{id:'east-arch',x:11,z:0,y:0,radius:3.5}];
  return {id,name,arena:{id,name,description:'Roof circuits, four enterable service bays and a readable street/rail intersection.',tag:'URBAN / ROOF FLANKS',color:'#d6a87d',background:'#162432',bounds:{minX:-38,maxX:38,minZ:-34,maxZ:34},spawns,teamSpawns:{0:west,1:east},flagSpawns:{0:{x:-31,z:0},1:{x:31,z:0}},objectiveZones:zones,
    pickups:[['health',-22,0],['health',22,0],['armor',0,16],['rail',0,-18],['rocket',0,0],['scatter',-10,0],['plasma',10,0],['haste',-27,19],['overcharge',27,-19]],navNodes:nav,blocks,terrain:{maxSlope:.48,surfaces,walls:[]},voidY:-20,ceilingY:32,raised:false,nextGen:true},
    palette:['4f5860','94664f','b4aba0','d9ac5e'], art:[]};
}
function rainmarket(){
  const id='rainmarket-exchange',name='Rainmarket Exchange',surfaces=[rect('rainmarket-pavement',-39,39,-35,35,0,0,'wet-stone')],blocks=[];
  // Diagonal-feeling zigzag through broad offset transit plazas; only the
  // west arcade is raised. Opposite underpass is ground-level and traversable.
  surfaces.push(rect('arcade-overlook',-34,-19,-10,1,2.7,2.7,'roof'));
  surfaces.push(rect('arcade-ramp',-19,-9,-8,-2,2.7,0,'grating'));
  blocks.push(box('arcade-mass',-26.5,-4.5,13,10.5,2.69,'brick'));
  for(const spec of [
    {id:'east-kiosk',x:26,z:19,w:13,d:11,open:'west',accent:'concrete'},
    {id:'west-foodhall',x:-25,z:20,w:12,d:9,open:'east',accent:'brick'},
    {id:'north-station',x:11,z:-25,w:15,d:11,open:'south',accent:'steel'},
    {id:'east-warehouse',x:28,z:-17,w:12,d:11,open:'west',accent:'brick'}
  ])perimeter(blocks,spec);
  for(const [n,x,z,w,d,h] of [
    ['tram-platform',0,-17,18,2,1.1],['route-wall-west',-12,12,2,13,3],['route-wall-east',12,-3,2,13,3],
    ['stall-a',-5,13,3.2,2.2,1.6],['stall-b',2,17,3.2,2.2,1.6],['stall-c',8,11,3.2,2.2,1.6],
    ['tram-baffle-a',-7,-6,3,1.4,1.6],['tram-baffle-b',6,-10,3,1.4,1.6]
  ])blocks.push(box(n,x,z,w,d,h,n.startsWith('stall')?'brick':'steel'));
  const west=[[-34,-27],[-33,4],[-34,13],[-22,-30],[-16,-27]];
  const east=[[34,27],[33,5],[34,-5],[22,30],[16,27]];
  const nav=[];for(let x=-36;x<=36;x+=3)for(let z=-33;z<=33;z+=3)nav.push([x,z]);
  const zones=[{id:'tram',x:-8,z:-22,y:0,radius:4},{id:'exchange',x:0,z:0,y:0,radius:4},{id:'bazaar',x:13,z:17,y:0,radius:4}];
  return {id,name,arena:{id,name,description:'Asymmetric market lanes connect covered shops, a transit spine and an elevated western overlook.',tag:'URBAN / TRANSIT',color:'#78b8be',background:'#111e2b',bounds:{minX:-39,maxX:39,minZ:-35,maxZ:35},spawns:west.flatMap((p,i)=>[p,east[i]]),teamSpawns:{0:west,1:east},flagSpawns:{0:{x:-34,z:-19},1:{x:34,z:19}},objectiveZones:zones,
    pickups:[['health',-25,20],['health',26,19],['armor',-16,-15],['armor',17,13],['rail',-4,-25],['rocket',7,4],['scatter',-8,8],['plasma',13,-17],['haste',-30,-13]],navNodes:nav,blocks,terrain:{maxSlope:.5,surfaces,walls:[]},voidY:-20,ceilingY:32,raised:false,nextGen:true},
    palette:['3f5662','817566','5ba3aa','e3aa67'], art:[]};
}
for(const item of [switchyard(),rainmarket()]){
  const data={schemaVersion:1,id:item.id,name:item.name,geometryHash:createHash('sha256').update(canonical(item.arena)).digest('hex'),arena:item.arena,
    palette:item.palette,art:item.art,spawnPoints:item.arena.spawns.map(([x,z])=>({x,y:0,z})),routes:[{id:'cross-town',points:[{x:item.arena.teamSpawns[0][0][0],y:0,z:item.arena.teamSpawns[0][0][1]},{x:0,y:0,z:0},{x:item.arena.teamSpawns[1][0][0],y:0,z:item.arena.teamSpawns[1][0][1]}]}]};
  const output=JSON.stringify(data,null,2)+'\n',path=new URL(item.id+'.json',root);
  if(process.argv.includes('--check')){if(readFileSync(path,'utf8')!==output)throw Error(`Stale authored geometry: ${item.id}`);}
  else writeFileSync(path,output);
  console.log(`${item.id} ${data.geometryHash} ${item.arena.terrain.surfaces.length} surfaces ${item.arena.blocks.length} blocks`);
}

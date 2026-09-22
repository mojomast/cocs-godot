import {writeFileSync,mkdirSync} from 'node:fs';
import {art} from './art.mjs';
import {fileURLToPath} from 'node:url';
import {nativeArenaGeometryHash} from '../../port/native-arenas/schema.mjs';
const out=new URL('../../godot/identity_maps/generated/',import.meta.url);
const p=(x,y,z)=>[x,y,z];
function surface(id,x0,z0,x1,z1,y0=0,y1=y0){return {id,material:'floor',walkable:true,vertices:[p(x0,y0,z0),p(x0,y1,z1),p(x1,y1,z1),p(x1,y0,z0)],triangles:[[0,1,2],[0,2,3]]};}
function make(id,name,mode,w,d,palette){
 const a={id,name,bounds:{minX:-w/2,maxX:w/2,minZ:-d/2,maxZ:d/2},spawns:[],pickups:[],navNodes:[],blocks:[],terrain:{maxSlope:.65,surfaces:[surface('court',-w/2,-d/2,w/2,d/2)],walls:[]},voidY:-10,ceilingY:40,raised:false,nextGen:false};
 const data={schemaVersion:1,id,name,mode,arena:a,palette,routes:[],cameras:[],landmarks:[]};
 data.box=(id,x,z,bw,bd,h,material='shell',baseY=0)=>a.blocks.push({id,x,z,w:bw,d:bd,h,baseY,material});
 data.route=(id,pts)=>data.routes.push({id,points:pts.map(([x,z])=>({x,y:0,z}))});
 data.box('north-boundary',0,-d/2-1,w+4,2,7,'enamel');data.box('south-boundary',0,d/2+1,w+4,2,7,'enamel');
 data.box('west-boundary',-w/2-1,0,2,d,7,'enamel');data.box('east-boundary',w/2+1,0,2,d,7,'enamel');
 return data;
}
export function recipes(){
 const l=make('lacuna-court','Lacuna Court','deathmatch',56,48,['ded4bd','b7b0a0','202c59','ad7045']);
 for(const sx of [-1,1])for(const sz of [-1,1]){
  l.arena.spawns.push([sx*24,sz*20]);
  l.box(`pocket-side-${sx}-${sz}`,sx*20,sz*19,2,4,3.4);
  l.box(`pocket-front-${sx}-${sz}`,sx*24,sz*16,4,2,3.4);
  for(const [x,z] of [[24,23],[18,23],[18,14],[27,20],[27,14]])l.arena.navNodes.push([sx*x,sz*z]);
 }
 for(const sz of [-1,1])l.box(`gallery-divider-${sz}`,0,sz*21,4,6,4);
 for(const sx of [-1,1])l.box(`lane-divider-${sx}`,sx*25,0,6,4,3.6);
 l.box('resonator-west',-5,-3,5,9,4.5); l.box('resonator-east',5,3,5,9,4.5);
 l.arena.pickups=[['health',-14,0],['armor',14,0],['rocket',0,-13],['health',0,13]];
 l.route('outer-loop',[[-16,-12],[0,-12],[16,-12],[16,12],[0,12],[-16,12],[-16,-12]]);
 l.route('court-crossing',[[-14,0],[-10,7],[0,9],[10,9],[14,0],[10,-7],[0,-9],[-10,-9],[-14,0]]);
 // Terraces are solid infill. Floor replacement prevents overlapping floor layers.
 // Broad 1:6 ascent on north/south edges, isolated from the protected spawn doors.
 for(const sign of [-1,1]){
  const x0=sign<0?-16:8,x1=x0+8;
  l.arena.terrain.surfaces.push(surface(`terrace-ramp-${sign}`,x0,-22,x1,-13,1.5,0));
  l.arena.terrain.surfaces.push(surface(`terrace-${sign}`,x0,-24,x1,-22,1.5));
  l.route(`terrace-ascent-${sign}`,[[x0+4,-12],[x0+4,-22],[x0+4,-23]]);
 }
 l.landmarks=[{kind:'resonator',at:[0,7,0],scale:[1,1,1]},{kind:'sail',at:[-12,14,-31],scale:[1,1,1]}];
 l.cameras=[{id:'entrance',at:[-16,1.7,12],target:[0,5,0]},{id:'landmark',at:[17,5,17],target:[0,6,0]},{id:'combat',at:[0,1.7,12],target:[0,2,-12]},{id:'objective',at:[-13,2,-11],target:[0,1,-13]},{id:'worst',at:[31,30,33],target:[0,0,0]}];
 const v=make('vermilion-fold','Vermilion Fold','domination',64,56,['e3dcc8','beaa93','244d48','b84a38']);
 v.arena.spawns=[[-27,-21],[27,-21],[-27,21],[27,21],[-27,0],[27,0]];
 v.arena.teamSpawns={0:[[-27,-21],[-27,21],[-27,0]],1:[[27,-21],[27,21],[27,0]]};
 for(const sx of [-1,1]){
  v.box(`start-shield-${sx}`,sx*22,0,2,9,3.4,'enamel');
  for(const sz of [-1,1]){
   v.box(`pavilion-retainer-${sx}-${sz}`,sx*10,sz*9,12,3,3.2);
   v.box(`spawn-shield-${sx}-${sz}`,sx*23,sz*21,2,7,3.4,'enamel');
  }
 }
 v.arena.objectiveZones=[{x:0,z:-17,y:0,radius:3.5},{x:0,z:0,y:0,radius:3.5},{x:0,z:17,y:0,radius:3.5}];
 v.arena.navNodes=v.arena.objectiveZones.map(({x,z})=>[x,z]);
 v.arena.pickups=[['health',-18,-17],['health',18,17],['armor',-18,17],['armor',18,-17]];
 v.route('west-rotation',[[-18,-17],[-18,0],[-18,17]]);v.route('east-rotation',[[18,-17],[18,0],[18,17]]);
 v.route('objective-axis',[[0,-17],[0,0],[0,17]]);
 for(const sx of [-1,1])for(const z of [-17,0,17])v.route(`approach-${sx}-${z}`,[[sx*27,z<0?-21:z>0?21:0],[sx*27,z<0?-26:z>0?26:-7],[sx*18,z<0?-26:z>0?26:-7],[sx*18,z],[0,z]]);
 v.landmarks=[{kind:'fan',at:[0,8,-17],scale:[1,1,1]},{kind:'crown',at:[0,10,0],scale:[1,1,1]},{kind:'pleat',at:[0,8,17],scale:[1,1,1]}];
 v.cameras=[{id:'entrance',at:[-18,1.7,-17],target:[0,7,-4]},{id:'landmark',at:[13,4,13],target:[0,10,0]},{id:'combat',at:[-18,1.7,0],target:[0,2,0]},{id:'objective',at:[-10,2,-24],target:[0,5,-17]},{id:'worst',at:[37,34,38],target:[0,0,0]}];
 const n=make('nacre-engine','Nacre Engine','horde',60,52,['d3cbbc','a6a49c','142b4a','b88b43']);
 n.arena.spawns=[[-23,-19],[23,19],[-23,19],[23,-19],[0,-21],[0,21]];
 n.box('memory-housing',0,0,12,12,6,'enamel');
 for(const sx of [-1,1])for(const sz of [-1,1])n.box(`shell-pocket-${sx}-${sz}`,sx*17,sz*10,5,3,3.2);
 n.arena.pickups=[['health',-23,0],['health',23,0],['armor',0,-18],['rocket',0,18],['ammo',-12,-19],['ammo',12,19]];
 n.route('retreat-loop',[[-24,-20],[0,-20],[24,-20],[24,0],[24,20],[0,20],[-24,20],[-24,0],[-24,-20]]);
 n.route('inner-retreat',[[-10,-16],[10,-16],[10,0],[10,16],[-10,16],[-10,0],[-10,-16]]);
 n.landmarks=[{kind:'drum',at:[0,8,0],scale:[1,1,1]},{kind:'vault',at:[0,0,0],scale:[1,1,1]}];
 n.cameras=[{id:'entrance',at:[-23,1.7,19],target:[0,7,0]},{id:'landmark',at:[19,4,17],target:[0,8,0]},{id:'combat',at:[-23,1.7,0],target:[0,3,-15]},{id:'objective',at:[0,2,-21],target:[0,8,0]},{id:'worst',at:[32,25,34],target:[0,0,0]}];
 return [l,v,n].map(r=>{delete r.box;delete r.route;r.grayboxHash=nativeArenaGeometryHash(r.arena);r.art=art(r);r.arena.terrain.walls=r.art.flatMap(s=>s.triangles.map((t,i)=>({id:`${s.id}-${i}`,material:s.material,walkable:false,vertices:t.map(j=>s.vertices[j]),triangles:[[0,1,2]]})));r.geometryHash=nativeArenaGeometryHash(r.arena);return r;});
}
export function compile(){mkdirSync(out,{recursive:true});for(const r of recipes()){writeFileSync(new URL(r.id+'.json',out),JSON.stringify(r)+'\n');console.log(`${r.id} ${r.geometryHash}`);}}
if(process.argv[1]===fileURLToPath(import.meta.url))compile();

import {createHash} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

export const canonical=value=>Array.isArray(value)?`[${value.map(canonical).join(',')}]`:value!==null&&typeof value==='object'?`{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`:JSON.stringify(value);
export const hash=value=>createHash('sha256').update(canonical(value)).digest('hex');
const surface=(id,x0,z0,x1,z1)=>({id,material:'floor',walkable:true,vertices:[[x0,0,z0],[x0,0,z1],[x1,0,z1],[x1,0,z0]],triangles:[[0,1,2],[0,2,3]]});

/** New drydock footprint. Rectangular union is partitioned once: no overlapping
 * floor triangles, no invisible floor beneath the solid inaccessible hull. */
export function cinderwake(){
 const id='cinderwake-drydock',name='Cinderwake Drydock';
 const footprints=[[-20,52,20,62],[-24,24,32,52],[-6,16,6,24],[-18,-22,18,16],[-6,-30,6,-22],[-32,-64,32,-30],[-40,-58,-34,58],[-40,53,-20,59],[-40,43,-24,49],[-40,3,-18,9],[-40,-39,-32,-33]];
 const arena={id,name,bounds:{minX:-44,maxX:44,minZ:-66,maxZ:62},voidY:-10,ceilingY:40,raised:false,nextGen:true,spawns:[[-8,57],[8,57]],teamSpawns:{},navNodes:[],pickups:[],blocks:[],terrain:{maxSlope:.65,surfaces:[],walls:[]}};
 const box=(id,x,z,w,d,h=8,material='shell',baseY=0)=>arena.blocks.push({id,x,z,w,d,h,baseY,material});
 const xs=[...new Set([-44,44,...footprints.flatMap(r=>[r[0],r[2]])])].sort((a,b)=>a-b),zs=[...new Set([-66,62,...footprints.flatMap(r=>[r[1],r[3]])])].sort((a,b)=>a-b);
 const inside=(x,z)=>footprints.some(([x0,z0,x1,z1])=>x>=x0&&x<=x1&&z>=z0&&z<=z1);
 let serial=0;
 for(let j=0;j<zs.length-1;j++){
  let start=0;
  while(start<xs.length-1){
   const playable=inside((xs[start]+xs[start+1])/2,(zs[j]+zs[j+1])/2);let end=start+1;
   while(end<xs.length-1&&inside((xs[end]+xs[end+1])/2,(zs[j]+zs[j+1])/2)===playable)end++;
   const x0=xs[start],x1=xs[end],z0=zs[j],z1=zs[j+1];
   if(playable)arena.terrain.surfaces.push(surface(`deck-${serial++}`,x0,z0,x1,z1));
   else box(`hull-${serial++}`,(x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0);
   start=end;
  }
 }
 box('north-shell',0,-67,90,2);box('south-shell',0,63,90,2);box('west-shell',-45,-2,2,130);box('east-shell',45,-2,2,130);
 // Screened embarkation with a six-metre central doorway and west E exit.
 box('embarkation-west',-11.5,52,17,1,5,'enamel');box('embarkation-east',11.5,52,17,1,5,'enamel');
 for(const x of [-8,8])box(`start-shield-${x}`,x,54,4,2,3,'enamel');
 for(const [id,x,z,w,d,h] of [['cargo-west',-10,37,6,4,2.4],['cargo-east',14,40,6,4,2.4],['cradle-barrier',2,29,6,2,1.1],['keel-rib-west',-8,4,4,8,3],['keel-rib-east',8,-9,4,8,3],['apron-plinth-west',-14,-46,6,4,2.4],['apron-plinth-east',14,-46,6,4,2.4]])box(id,x,z,w,d,h,'cut');
 const stages=[
  {id:'B',arrival:{minX:-8,maxX:8,minZ:42,maxZ:49},humanSpawns:[[-8,58],[8,58]],enemySpawns:[[-20,28],[26,28],[-20,46],[26,46]]},
  {id:'C',arrival:{minX:-7,maxX:7,minZ:10,maxZ:14},humanSpawns:[[-12,10],[-12,2]],enemySpawns:[[-13,-17],[13,-17],[-13,11],[13,11]]},
  {id:'D',arrival:{minX:-10,maxX:10,minZ:-39,maxZ:-32},humanSpawns:[[-24,-35],[-24,-43]],enemySpawns:[[-27,-58],[27,-58],[-27,-34],[27,-34]]},
 ];
 for(const stage of stages)for(const [i,[x,z]] of stage.enemySpawns.entries()){
  // Face room centre, retain >= 2.8m pod clearance (source max body is smaller).
  const bx=x+(x<0?1:-1)*(stage.id==='D'?6:4);
  box(`pod-${stage.id}-${i}`,bx,z,2,4,3,'enamel');
 }
 arena.teamSpawns={0:stages[0].humanSpawns,1:stages[0].enemySpawns};
 arena.spawns=[...stages[0].humanSpawns,...stages[0].enemySpawns];
 arena.pickups=[['health',-3,58],['ammo',3,58],['scatter',0,54],['armor',22,38],['health',-17,42],['plasma',-4,27],['health',-12,-5],['armor',12,6],['shock',0,-17],['rocket',20,-53],['flak',-20,-53],['health',-22,-40],['ammo',22,-40],['megahealth',0,-58],['ammo',-37,6],['health',-37,-36]];
 const gates=[{id:'G_BC',x:0,z:20,w:12,d:1,h:5,baseY:0,material:'accent'},{id:'G_CD',x:0,z:-26,w:12,d:1,h:5,baseY:0,material:'accent'}];
 const transitions=[[2,'B','C'],[5,'C','D'],[10,'D','B'],[13,'B','C'],[15,'C','D'],[20,'D','B'],[22,'B','C'],[24,'C','D']].map(([afterWave,from,to])=>({afterWave,from,to,open:to==='B'?['G_BC','G_CD']:to==='C'?['G_BC']:['G_CD'],close:to==='D'?['G_BC']:[]}));
 arena.hordeStagePlan={version:1,initialStage:'B',stages,gates,transitions};
 // Dense authored anchors preserve the 6m service passage through source's
 // nearest-neighbour edge builder. Core removes obstructed nodes itself.
 for(let x=-40;x<=32;x+=2)for(let z=-64;z<=60;z+=2)if(inside(x,z))arena.navNodes.push([x,z]);
 const routes=[{id:'A-B',points:[[0,58],[0,46]]},{id:'B-C',points:[[0,46],[-4,34],[-4,24],[0,20],[0,12]]},{id:'C-D',points:[[0,12],[0,-26],[0,-35]]},{id:'D-B',points:[[0,-35],[0,-26],[0,12],[0,20],[-4,24],[-4,34],[0,46]]},{id:'D-B-emergency',points:[[0,-35],[-18,-40],[-28,-40],[-28,-36],[-37,-36],[-37,46],[-22,46],[-22,42],[0,42],[0,46]]},{id:'E-A',points:[[-37,46],[-37,56],[-23,56],[-23,57.5],[0,57.5],[0,58]]},{id:'E-C',points:[[-37,6],[-14,6],[-14,14.5],[-5,14.5],[0,12]]}].map(r=>({...r,points:r.points.map(([x,z])=>({x,y:0,z}))}));
 const data={schemaVersion:1,id,name,mode:'horde',arena,palette:['b7b6ad','6c7377','182c38','ed7437'],art:[],routes,cameras:[],landmarks:[],presentation:{stages:{B:'01 · LOADING CRADLE',C:'02 · KEEL TRENCH',D:'03 · PROPELLER APRON'},emergency:'E · LIFEBOAT PASSAGE'},provenance:{compiler:'tools/godot-horde-maps/cinderwake.mjs',sourceBase:'515daf07589150dd3241f4ae1425cc1b093912f5',sourceRequired:'48264858af820c69a833ef8b15c09ebac69e8cc3',geometry:'new rectangular union; no inherited arena recipe',gateContract:1}};
 data.planHash=hash(arena.hordeStagePlan);data.geometryHash=hash(arena);return data;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const out=new URL('../../godot/horde_maps/generated/',import.meta.url);mkdirSync(out,{recursive:true});
 const data=cinderwake();writeFileSync(new URL('cinderwake-drydock.json',out),JSON.stringify(data,null,2)+'\n');console.log(`${data.id}: geometry ${data.geometryHash}; plan ${data.planHash}`);
}

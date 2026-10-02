// A single-valued radial landscape: the frozen source cannot select stacked floors.
// Every solid mesh below is also source collision; glass/leaves are explicitly visual.
import {createHash} from 'node:crypto';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
export const ID='helix-conservatory';
const N=96,TAU=Math.PI*2;
export const polar=(r,a)=>[r*Math.cos(a),r*Math.sin(a)];
export function makeRecipe(){
 const m={id:ID,name:'Helix Conservatory',seed:61002,nextGen:true,raised:false,scatter:false,
  bounds:{minX:-120,maxX:120,minZ:-120,maxZ:120},sky:'day',floorColor:'#b2b9a5',background:'#203b40',color:'#d5bd75',
  description:'A terraced botanical arcology around an open lightwell; ivory seed archives face copper irrigation galleries across three radial circulation bands.',
  blocks:[],structures:[],props:[],spawns:[],pickups:[],navNodes:[],routes:[],objectiveZones:[],
  modeBindings:{},candidateModes:['deathmatch','teamdeathmatch','arsenal','juggernaut','ctf','domination','koth'],
  terrain:{maxSlope:.8,base:0,amplitude:24,surfaces:[],walls:[]},art:{meshes:[],palette:'ivory-verdigris-botanical'},
  provenance:{sourceLock:'515daf',reviewedDerivative:'0326',generator:'tools/godot-multiplayer/new-maps/helix-conservatory/recipe.mjs',stackedFloors:false}};
 const mesh=(id,vertices,triangles,material,collision='surface',walkable=false)=>{
  m.art.meshes.push({id,vertices,triangles,material,collision,walkable});
  if(collision==='surface')m.terrain.surfaces.push({id,vertices,triangles,material,walkable});
  if(collision==='wall')for(const t of triangles)m.terrain.walls.push({id,material,vertices:t.map(i=>vertices[i])});
 };
 const quad=(id,v,mat,collision='surface',walk=false)=>mesh(id,v,[[0,1,2],[0,2,3]],mat,collision,walk);
 const rings=[[0,0],[25,0],[45,8],[60,8],[80,16],[94,16],[112,24],[120,24]];
 for(let j=1;j<rings.length;j++)for(let i=0;i<N;i++){
  const [r0,h0]=rings[j-1],[r1,h1]=rings[j],a=i*TAU/N,b=(i+1)*TAU/N;
  const p=(r,h,t)=>{const [x,z]=polar(r,t);return[x,h,z];};
  if(!r0)mesh(`lightwell-${i}`,[p(0,0,a),p(r1,h1,b),p(r1,h1,a)],[[0,1,2]],'ceramic','surface',true);
  else quad(`terrace-${j}-${i}`,[p(r0,h0,a),p(r0,h0,b),p(r1,h1,b),p(r1,h1,a)],j%2?'ceramic':'stone','surface',true);
 }
 // Exact polygon-interpolated height for architectural foundations.
 const height=(r)=>r<=25?0:r<=45?(r-25)*.4:r<=60?8:r<=80?8+(r-60)*.4:r<=94?16:r<=112?16+(r-94)*8/18:24;
 const prism=(id,x,y,z,w,h,d,mat)=>{
  const v=[[x-w/2,y,z-d/2],[x+w/2,y,z-d/2],[x+w/2,y,z+d/2],[x-w/2,y,z+d/2],
   [x-w/2,y+h,z-d/2],[x+w/2,y+h,z-d/2],[x+w/2,y+h,z+d/2],[x-w/2,y+h,z+d/2]];
  mesh(id,v,[[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]],mat,'wall');
  quad(`${id}-cap`,[v[4],v[7],v[6],v[5]],mat);quad(`${id}-under`,[v[0],v[1],v[2],v[3]],mat);
 };
 const beam=(id,a,b,r,mat,collision='surface')=>{
  const dx=b[0]-a[0],dy=b[1]-a[1],dz=b[2]-a[2],l=Math.hypot(dx,dz)||1;
  const u=[-dz/l,0,dx/l],len=Math.hypot(dx,dy,dz),v=[-dy*dx/(len*l),l/len,-dy*dz/(len*l)],verts=[];
  for(const p of [a,b])for(let k=0;k<6;k++){const t=k*TAU/6;verts.push(p.map((c,j)=>c+r*(u[j]*Math.cos(t)+v[j]*Math.sin(t))));}
  const tris=[];for(let k=0;k<6;k++){const n=(k+1)%6;tris.push([k,n,n+6],[k,n+6,k+6]);}
  mesh(id,verts,tris,mat,collision);
 };
 // Ribs form a scalloped crown, leaving the central lightwell fully open.
 for(let i=0;i<16;i++){
  const a=(i+.5)*TAU/16,points=[];
  for(let j=0;j<=12;j++){const t=j/12,r=116-84*t,[x,z]=polar(r,a);points.push([x,28+18*Math.sin(t*Math.PI*.8),z]);}
  for(let j=1;j<points.length;j++)beam(`rib-${i}-${j}`,points[j-1],points[j],.42,'verdigris');
  const [x,z]=polar(119,a);prism(`rib-foot-${i}`,x,24,z,1.8,4,1.8,'verdigris');
 }
 // Discontinuous planter crescents create cover and split ring balconies.
 for(const r of [20,57,91])for(let i=0;i<16;i++){
  const a=(i+.5)*TAU/16,[x,z]=polar(r,a),y=height(r);
  prism(`planter-${r}-${i}`,x,y,z,3.4,1.4,3.4,'stone');
  for(let leaf=0;leaf<7;leaf++){
   const t=leaf*TAU/7,tip=[x+2.4*Math.cos(t),y+3.8+(leaf%3)*.5,z+2.4*Math.sin(t)];
   mesh(`leaf-${r}-${i}-${leaf}`,[[x,y+1.4,z],[x+.7*Math.cos(t+.9),y+2.5,z+.7*Math.sin(t+.9)],tip,[x+.7*Math.cos(t-.9),y+2.5,z+.7*Math.sin(t-.9)]],[[0,1,2],[0,2,3]],'botanical','none');
  }
 }
 // Two through-chambers at opposite ends of the level-eight terrace.
 for(const s of [-1,1]){
  const x=s*52,id=s<0?'seed-archive':'irrigation-laboratory';
  for(const side of [-1,1]){
   prism(`${id}-side-${side}`,x+side*5,8,0,1,7,18,'ceramic');
   for(const end of [-1,1])prism(`${id}-door-${side}-${end}`,x+side*4,8,end*9,2,7,1,'stone');
  }
  prism(`${id}-vault`,x,15,0,11,1,19,'verdigris');
  for(const side of [-1,1])for(let i=-2;i<=2;i++)prism(`${id}-seed-drawer-${side}-${i}`,x+side*3.8,8,i*2.5,1,3.8,1.5,'gold');
  m.structures.push({id,type:'room',x,z:0,w:10,d:18,height:7,doors:'ns',roofY:15});
 }
 // Non-walkable irrigation bridges: lower terrace passes underneath.
 for(const s of [-1,1]){
  prism(`aqueduct-${s}`,0,7,s*16,28,.8,3,'verdigris');
  for(const x of [-14,14])prism(`aqueduct-pier-${s}-${x}`,x,0,s*16,1.3,7,3,'stone');
 }
 // Glazed lanterns have visible frames, but transparent panes never block shots.
 for(const s of [-1,1])for(const k of [-1,1]){
  const x=s*6,z=k*6;
  prism(`lantern-base-${s}-${k}`,x,0,z,.5,1.1,.5,'ceramic');
  quad(`lantern-glass-${s}-${k}`,[[x-1,1.1,z],[x+1,1.1,z],[x+1,5,z],[x-1,5,z]],'glass','none');
 }
 const route=(id,points)=>{m.routes.push({id,width:5,points});for(let j=1;j<points.length;j++){const a=points[j-1],b=points[j],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);for(let k=0;k<=n;k++)m.navNodes.push({x:a[0]+(b[0]-a[0])*k/n,z:a[1]+(b[1]-a[1])*k/n});}};
 for(const [id,r] of [['lightwell-loop',12],['archive-ring',52],['canopy-ring',86],['crown-ring',116]])route(id,Array.from({length:97},(_,i)=>polar(r,i*TAU/96)));
 for(let i=0;i<8;i++){const a=i*TAU/8+TAU/24;route(`garden-ramp-${i}`,Array.from({length:29},(_,j)=>polar(4+j*4,a)));}
 // Curved ascending avenues express the helix in the navigable route network.
 for(const s of [-1,1])route(`spiral-promenade-${s}`,Array.from({length:65},(_,i)=>polar(12+i*1.625,s*.12+i*Math.PI/128)));
 m.teamSpawns={0:[[-86,0],[-85,5],[-85,-5]],1:[[86,0],[85,5],[85,-5]]};
 m.spawns=[...m.teamSpawns[0],...m.teamSpawns[1],[0,86],[0,-86],[0,12],[0,-12]];
 m.flagSpawns={0:{x:-86,z:0},1:{x:86,z:0}};
 m.objectiveZones=[{x:0,y:0,z:0,radius:7,label:'LIGHTWELL'},{x:0,y:16,z:86,radius:6,label:'CANOPY NORTH'},{x:0,y:16,z:-86,radius:6,label:'CANOPY SOUTH'}];
 m.pickups=[['health',-86,10],['health',86,-10],['armor',0,52],['armor',0,-52],['rail',0,116],['rocket',0,-12]];
 route('lightwell-axis',[[0,-12],[0,0],[0,12]]);
 for(const p of [...m.spawns,...Object.values(m.flagSpawns).map(p=>[p.x,p.z]),...m.objectiveZones.map(p=>[p.x,p.z])])m.navNodes.push({x:p[0],z:p[1]});
 // Reserve a continuous corridor before committing planters to the recipe.
 const distance=(p,a,b)=>{const dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)));return Math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz);};
 const removed=new Set();
 for(const r of [20,57,91])for(let i=0;i<16;i++){const p=polar(r,(i+.5)*TAU/16);if(m.routes.some(route=>route.points.slice(1).some((b,j)=>distance(p,route.points[j],b)<4.5)))removed.add(`${r}-${i}`);}
 const keep=id=>![...removed].some(key=>id===`planter-${key}`||id.startsWith(`planter-${key}-`)||id.startsWith(`leaf-${key}-`));
 m.art.meshes=m.art.meshes.filter(s=>keep(s.id));m.terrain.surfaces=m.terrain.surfaces.filter(s=>keep(s.id));m.terrain.walls=m.terrain.walls.filter(s=>keep(s.id));
 // Production art pass: explicit recipe-authored details. Inlays, glass and
 // botanical blades are visual-only; elevated metal hoops have matching rays.
 // Query a construction snapshot so terrain.mjs never caches the final arena
 // before the later overhead hoop surfaces have been appended.
 const floorTerrain={...m.terrain,surfaces:[...m.terrain.surfaces]};
 const floor=(x,z)=>terrainSupportAt(x,z,floorTerrain,.8)?.y??24;
 const floorPoint=(r,a,offset=.025)=>{const [x,z]=polar(r,a);return[x,floor(x,z)+offset,z];};
 for(const [ring,r] of [[0,12],[1,52],[2,86],[3,116]]){
  for(let i=0;i<192;i++)for(const side of [-1,1]){
   const a=i*TAU/192,b=(i+.88)*TAU/192,edge=r+side*2.4;
   quad(`ring-inlay-${ring}-${i}-${side}`,[floorPoint(edge-.09,a),floorPoint(edge-.09,b),floorPoint(edge+.09,b),floorPoint(edge+.09,a)],ring%2?'gold':'verdigris','none');
  }
 }
 // Stone joint grid follows the circular masonry, rather than Cartesian tiles.
 for(let r=5;r<119;r+=3)for(let i=0;i<96;i++){
  const a=i*TAU/96,b=(i+1)*TAU/96;
  quad(`masonry-joint-${r}-${i}`,[floorPoint(r-.025,a,.012),floorPoint(r-.025,b,.012),floorPoint(r+.025,b,.012),floorPoint(r+.025,a,.012)],'joint','none');
 }
 for(const route of m.routes.filter(r=>r.id.startsWith('garden-ramp')||r.id.startsWith('spiral-'))){
  for(let i=1;i<route.points.length;i++){
   const a=route.points[i-1],b=route.points[i],dx=b[0]-a[0],dz=b[1]-a[1],len=Math.hypot(dx,dz),nx=-dz/len,nz=dx/len;
   const p=(v,w)=>[v[0]+nx*w,floor(v[0]+nx*w,v[1]+nz*w)+.035,v[1]+nz*w];
   for(const side of [-1,1])quad(`${route.id}-inlay-${i}-${side}`,[p(a,side*2-.12),p(b,side*2-.12),p(b,side*2+.12),p(a,side*2+.12)],route.id.startsWith('spiral')?'gold':'verdigris','none');
  }
 }
 const crownHeight=r=>28+18*Math.sin((116-r)/84*Math.PI*.8);
 for(const r of [34,48,66,86,104,116])for(let i=0;i<96;i++){
  const a=(i+3)*TAU/96,b=(i+4)*TAU/96,p=t=>{const [x,z]=polar(r,t);return[x,crownHeight(r),z];};
  beam(`hoop-${r}-${i}`,p(a),p(b),.18,'verdigris');
 }
 for(let i=0;i<16;i++)for(const [r0,r1]of [[66,86],[86,104],[104,116]]){
  const a=(i+.5)*TAU/16+.006,b=(i+1.5)*TAU/16-.006;
  for(let j=0;j<8;j++){const c=a+(b-a)*j/8,d=a+(b-a)*(j+1)/8;
   const p=(r,t)=>{const [x,z]=polar(r,t);return[x,crownHeight(r)-.06,z];};
   quad(`greenhouse-pane-${i}-${r0}-${j}`,[p(r0,c),p(r0,d),p(r1,d),p(r1,c)],'glass','none');
  }
 }
 // Fern fronds: tapered folded strips, deterministic whorls at existing planters.
 for(const plant of [...m.art.meshes].filter(p=>p.id.startsWith('planter-')&&p.collision==='wall')){
  const x=(plant.vertices[0][0]+plant.vertices[1][0])/2,z=(plant.vertices[0][2]+plant.vertices[2][2])/2,y=plant.vertices[4][1];
  for(let frond=0;frond<16;frond++){
   const a=frond*2.399963,r=1.8+(frond%4)*.3,verts=[],tris=[];
   for(let j=0;j<=8;j++){const t=j/8,w=.3*Math.sin(t*Math.PI),cx=x+Math.cos(a)*r*t,cz=z+Math.sin(a)*r*t,h=y+Math.sin(t*Math.PI*.7)*(1.3+(frond%3)*.45);
    verts.push([cx-Math.sin(a)*w,h,cz+Math.cos(a)*w],[cx,h+.08,cz],[cx+Math.sin(a)*w,h,cz-Math.cos(a)*w]);
    if(j)for(let k=0;k<2;k++){const q=(j-1)*3+k;tris.push([q,q+3,q+4],[q,q+4,q+1]);}
   }
   mesh(`${plant.id}-fern-${frond}`,verts,tris,frond%3?'botanical':'leaflight','none');
  }
 }
 // Drawer fascia lines sit on existing solid faces, never across open doorways.
 for(const s of [-1,1])for(const side of [-1,1])for(let i=-2;i<=2;i++)for(let shelf=0;shelf<6;shelf++){
  const x=s*52+side*3.28,z=i*2.5,y=8.3+shelf*.55;
  quad(`drawer-fascia-${s}-${side}-${i}-${shelf}`,[[x,y,z-.68],[x,y,z+.68],[x,y+.06,z+.68],[x,y+.06,z-.68]],'joint','none');
 }
 m.art.labels=[
  {text:'HELIX / 00',x:0,y:.055,z:5,size:2.2,floor:true,material:'verdigris'},
  {text:'LIGHTWELL',x:0,y:.055,z:8,size:1.1,floor:true,material:'verdigris'},
  {text:'01  SEED ARCHIVE',x:-52,y:13,z:-9.56,size:.75,yaw:Math.PI,material:'gold'},
  {text:'02  IRRIGATION LAB',x:52,y:13,z:9.56,size:.65,yaw:0,material:'gold'},
  {text:'CANOPY  /  +16',x:0,y:16.06,z:86,size:1.1,floor:true,material:'gold'},
  {text:'CROWN  /  +24',x:0,y:24.06,z:-116,size:1.2,floor:true,material:'verdigris'}];
 m.art.visualCoverage='complete-terrain';
 return m;
}
export const hash=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
export const recipe=makeRecipe();

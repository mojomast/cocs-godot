// Staged second architectural pass. The shipped/checkpoint JSON and GLB are not
// overwritten until an explicit heavy-slot grant and visual/native acceptance.
import {makeRecipe as checkpoint,hash,polar} from './recipe.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
export {hash,polar};
export const ID='helix-conservatory';
const TAU=Math.PI*2,D=Math.PI/180;
const mix=(a,b,t)=>a+(b-a)*t;
export function makeRecipe(){
 const m=checkpoint();
 m.provenance.artRevision=2;
 m.provenance.status='source-candidate-not-native-accepted';
 m.art.revision=2;
 m.art.labels=[];
 m.structures=[];
 const remove=id=>/^(seed-archive|irrigation-laboratory|drawer-fascia|planter-|leaf-|rib-|hoop-|greenhouse-pane|lantern-|masonry-joint)/.test(id)||id.includes('inlay');
 m.art.meshes=m.art.meshes.filter(p=>!remove(p.id));
 m.terrain.surfaces=m.terrain.surfaces.filter(p=>!remove(p.id));
 m.terrain.walls=m.terrain.walls.filter(p=>!remove(p.id));
 const ground={surfaces:m.terrain.surfaces.filter(s=>s.walkable),walls:[]};
 const floor=(x,z)=>terrainSupportAt(x,z,ground,.8)?.y??24;
 const p=(r,a,y)=>{const [x,z]=polar(r,a);return[x,y??floor(x,z),z];};
 const mesh=(id,vertices,triangles,material,collision='surface',walkable=false)=>{
  // Avoid degenerate leaf tips and zero-area architectural bevels.
  triangles=triangles.filter(t=>{const [a,b,c]=t.map(i=>vertices[i]),u=b.map((v,i)=>v-a[i]),v=c.map((v,i)=>v-a[i]);return Math.hypot(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])>1e-8;});
  if(!triangles.length)return;
  m.art.meshes.push({id,vertices,triangles,material,collision,walkable});
  if(collision==='surface')m.terrain.surfaces.push({id,vertices,triangles,material,walkable});
  if(collision==='wall')for(const t of triangles)m.terrain.walls.push({id,material,vertices:t.map(i=>vertices[i])});
 };
 const quad=(id,v,mat,collision='surface')=>mesh(id,v,[[0,1,2],[0,2,3]],mat,collision);
 const box=(id,x,y,z,w,h,d,mat)=>{
  const v=[[x-w/2,y,z-d/2],[x+w/2,y,z-d/2],[x+w/2,y,z+d/2],[x-w/2,y,z+d/2],[x-w/2,y+h,z-d/2],[x+w/2,y+h,z-d/2],[x+w/2,y+h,z+d/2],[x-w/2,y+h,z+d/2]];
  mesh(id,v,[[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]],mat,'wall');
  quad(id+'-top',[v[4],v[7],v[6],v[5]],mat);quad(id+'-bottom',[v[0],v[1],v[2],v[3]],mat);
 };
 const distance=(q,a,b)=>{const dx=b[0]-a[0],dz=b[1]-a[1],t=Math.max(0,Math.min(1,((q[0]-a[0])*dx+(q[1]-a[1])*dz)/(dx*dx+dz*dz)));return Math.hypot(q[0]-a[0]-dx*t,q[1]-a[1]-dz*t);};
 const primary=m.routes.map(r=>({...r,points:r.points.map(p=>[...p])}));
 const clearance=q=>Math.min(...primary.flatMap(r=>r.points.slice(1).map((b,i)=>distance(q,r.points[i],b))));
 // Every district deliberately leaves the existing 5m primary ribbons open.
 const reserved=(r0,r1,a,b,pad=3.2)=>[r0,(r0+r1)/2,r1].some(r=>[a,(a+b)/2,b].some(t=>clearance(polar(r,t))<pad));
 const solidSector=(id,r0,r1,a,b,h,mat,base=null)=>{
  const bottom=[p(r0,a),p(r0,b),p(r1,b),p(r1,a)];
  for(const v of bottom)v[1]=base??v[1]-.08;
  const v=[...bottom,...bottom.map(q=>[q[0],q[1]+h,q[2]])];
  mesh(id,v,[[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]],mat,'wall');
  quad(id+'-top',[v[4],v[5],v[6],v[7]],mat);quad(id+'-under',[v[0],v[3],v[2],v[1]],mat);
 };
 const arcWall=(id,r,a,b,h,mat,w=.65,open=true)=>{
  const n=Math.ceil((b-a)/(3*D));
  for(let i=0;i<n;i++){const u=mix(a,b,i/n),v=mix(a,b,(i+1)/n);if(open&&reserved(r-w/2,r+w/2,u,v))continue;solidSector(`${id}-${i}`,r-w/2,r+w/2,u,v,h,mat);}
 };
 const beam=(id,a,b,w,d,mat='verdigris',profile='i')=>{
  const dir=b.map((v,i)=>v-a[i]),len=Math.hypot(...dir),n=dir.map(v=>v/len),ref=Math.abs(n[1])>.95?[1,0,0]:[0,1,0];
  const cross=(x,y)=>[x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0]],u0=cross(n,ref),ul=Math.hypot(...u0),u=u0.map(v=>v/ul),v=cross(n,u);
  const shape=profile==='i'?[[-w/2,-d/2],[w/2,-d/2],[w/2,-d*.30],[w*.13,-d*.30],[w*.13,d*.30],[w/2,d*.30],[w/2,d/2],[-w/2,d/2],[-w/2,d*.30],[-w*.13,d*.30],[-w*.13,-d*.30],[-w/2,-d*.30]]:[[-w/2,-d/2],[w/2,-d/2],[w/2,d/2],[-w/2,d/2]];
  const verts=[a,b].flatMap(q=>shape.map(([s,t])=>q.map((x,i)=>x+u[i]*s+v[i]*t))),tris=[],c=shape.length;
  for(let i=0;i<c;i++){const j=(i+1)%c;tris.push([i,j,j+c],[i,j+c,i+c]);}
  // All use cases are overhead structure or machinery outside pedestrian paths.
  mesh(id,verts,tris,mat,'surface');
 };
 const cylinder=(id,x,z,r,h,mat,base=null,sides=16)=>{
  const y=base??floor(x,z)-r*.5;
  for(let i=0;i<sides;i++){const a=i*TAU/sides,b=(i+1)*TAU/sides;quad(`${id}-shell-${i}`,[[x+r*Math.cos(a),y,z+r*Math.sin(a)],[x+r*Math.cos(b),y,z+r*Math.sin(b)],[x+r*Math.cos(b),y+h,z+r*Math.sin(b)],[x+r*Math.cos(a),y+h,z+r*Math.sin(a)]],mat,'wall');}
  const vertices=[[x,y+h,z],...Array.from({length:sides},(_,i)=>[x+r*Math.cos(i*TAU/sides),y+h,z+r*Math.sin(i*TAU/sides)])];
  mesh(id+'-lid',vertices,Array.from({length:sides},(_,i)=>[0,i+1,(i+1)%sides+1]),mat);
 };
 const glazing=(id,r,a,b,low,high)=>{const n=Math.ceil((b-a)/(3*D));for(let i=0;i<n;i++){const u=mix(a,b,i/n),v=mix(a,b,(i+1)/n);if(reserved(r-.1,r+.1,u,v))continue;
  quad(`${id}-pane-${i}`,[p(r,u,low),p(r,v,low),p(r,v,high),p(r,u,high)],'glass','none');
  beam(`${id}-transom-${i}`,p(r,u,high),p(r,v,high),.18,.24,'verdigris','box');
 }};
 const roof=(id,r0,r1,a,b,base,rise,mat='ceramic')=>{
  const n=Math.ceil((b-a)/(3*D));
  for(let i=0;i<n;i++)for(let j=0;j<8;j++){
   const u=mix(a,b,i/n),v=mix(a,b,(i+1)/n),r=mix(r0,r1,j/8),s=mix(r0,r1,(j+1)/8),y=q=>base+rise*Math.sin((q-r0)/(r1-r0)*Math.PI);
   quad(`${id}-${i}-${j}`,[p(r,u,y(r)),p(r,v,y(r)),p(s,v,y(s)),p(s,u,y(s))],mat);
  }
 };
 const route=(id,points,width=2.5)=>{m.routes.push({id,width,points});for(let j=1;j<points.length;j++){const a=points[j-1],b=points[j],n=Math.ceil(Math.hypot(a[0]-b[0],a[1]-b[1])/2);for(let i=0;i<=n;i++)m.navNodes.push({x:mix(a[0],b[0],i/n),z:mix(a[1],b[1],i/n)});}};
 const curve=(r,a,b)=>{const n=Math.ceil(Math.abs(b-a)/(2*D));return Array.from({length:n+1},(_,i)=>polar(r,mix(a,b,i/n)));};
 const loop=(id,r,a,b)=>route(id,[polar(52,a),polar(r,a),...curve(r,a,b).slice(1),polar(52,b)]);

 // DISTRICT 01: segmented archive crescent, ~60m long, three vaulted chambers.
 arcWall('archive-inner-retaining',44.5,156*D,220*D,7.5,'stone',.8);
 arcWall('archive-outer-retaining',60.5,156*D,220*D,3.2,'brick',.9);
 glazing('archive-clerestory',60.5,156*D,220*D,11.1,15.7);
 for(const [bay,a,b] of [[0,156,176],[1,176,198],[2,198,220]]){
  roof(`archive-vault-${bay}`,44,61,a*D,b*D,15.5,3.5,'ceramic');
  roof(`archive-spine-${bay}`,48,57,(a+3)*D,(b-3)*D,18.2,1.2,'verdigris');
  for(const t of [a,b])beam(`archive-rib-${bay}-${t}`,p(44,t*D,15.4),p(61,t*D,15.4),.5,.8);
 }
 // Stack walls divide a public ring aisle from two usable research/service aisles.
 for(const [a,b]of [[157,164],[172,181],[190,191],[202,204],[212,219]])for(const r of [48.5,55.5]){
  arcWall(`archive-stack-${r}-${a}`,r,a*D,b*D,4.4,'gold',.75,false);
  for(let tier=0;tier<5;tier++)glazing(`archive-stack-label-${r}-${a}-${tier}`,r-.39,a*D,b*D,8.4+tier*.75,8.52+tier*.75);
 }
 loop('archive-inner-research-loop',46.7,168*D,186*D);
 loop('archive-outer-service-loop',57.8,168*D,208*D);
 for(const [i,a,b]of [[0,164,181],[1,204,216]]){
  arcWall(`archive-deep-alcove-${i}`,70,a*D,b*D,9.5,'brick',1.2);
  roof(`archive-alcove-roof-${i}`,61,71,a*D,b*D,20.5,2.7,'brick');
 }
 m.structures.push({id:'seed-archive-crescent',type:'room',district:'archive',chambers:3,innerRadius:44.5,outerRadius:70,angles:[156,220],routeIds:['archive-ring','archive-inner-research-loop','archive-outer-service-loop'],roofWalkable:false});

 // DISTRICT 02: asymmetric stepped filtration works, not an archive mirror.
 arcWall('irrigation-inner-wall',44.5,-24*D,25*D,6.4,'verdigris',.8);
 arcWall('irrigation-filter-wall-south',60.5,-24*D,-3*D,2.7,'stone',.8);
 arcWall('irrigation-filter-wall-north',60.5,3*D,25*D,2.7,'stone',.8);
 glazing('irrigation-glazed-facade',60.5,-24*D,25*D,10.6,16.5);
 for(const [bay,a,b,y]of [[0,-24,-7,16.2],[1,-7,9,19.0],[2,9,25,16.0]]){
  roof(`irrigation-sawtooth-${bay}`,44.5,61,a*D,b*D,y,1.8,'solar');
  quad(`irrigation-rooflight-${bay}`,[p(44.5,b*D,y),p(61,b*D,y),p(61,b*D,y+1.7),p(44.5,b*D,y+1.7)],'glass','none');
 }
 for(const [id,r,a,h,rad]of [['settling-vault',69,-17,12,3.8],['filter-vault',72,-4,17,3.2],['water-pressure-tower',68,5,22,2.4]]){
  const [x,z]=polar(r,a*D);cylinder(id,x,z,rad,h,'verdigris');
  for(let band=0;band<4;band++)roof(`${id}-collar-${band}`,r-rad,r+rad,(a-2)*D,(a+2)*D,floor(x,z)+band*2.7+1.8,.3,'gold');
 }
 // Paired pump machinery islands leave a curved, walkable maintenance passage.
 for(const [i,a]of [[0,-21],[1,-12],[2,-3]]){
  const [x,z]=polar(66,a*D);box(`pump-bank-${i}`,x,floor(x,z)-.4,z,2.2,4.5,2.2,'gold');
  for(let tube=0;tube<3;tube++)beam(`pipe-bank-${i}-${tube}`,p(63,(a-.6)*D,17+tube*.55),p(71,(a-.6)*D,17+tube*.55),.3,.35,'verdigris','box');
 }
 route('irrigation-maintenance-bypass',[polar(52,-22*D),polar(57,-22*D),...curve(57,-22*D,8*D).slice(1),polar(52,8*D)],3);
 route('irrigation-external-service',[polar(52,-26*D),polar(62.5,-26*D),...curve(62.5,-26*D,0).slice(1),polar(57,0),polar(52,0)],2);
 m.structures.push({id:'irrigation-filtration-works',type:'room',district:'irrigation',chambers:3,innerRadius:44.5,outerRadius:76,angles:[-24,25],routeIds:['archive-ring','irrigation-maintenance-bypass','irrigation-external-service'],roofWalkable:false});

 // DISTRICT 03: north canopy pavilion; capture socket remains inside its nave.
 arcWall('pavilion-inner-plinth',80,68*D,96*D,2.8,'brick',.75);
 arcWall('pavilion-outer-plinth',94,68*D,96*D,2.8,'brick',.75);
 glazing('pavilion-inner-glass',80,68*D,96*D,18.7,24.5);
 glazing('pavilion-outer-glass',94,68*D,96*D,18.7,24.5);
 roof('pavilion-ribbed-roof',79.5,94.5,68*D,96*D,24.8,5.8,'glass');
 // Glazed roof is intentionally not a shot blocker; metal framing is authoritative.
 for(const part of m.art.meshes.filter(s=>s.id.startsWith('pavilion-ribbed-roof')))part.collision='none';
 m.terrain.surfaces=m.terrain.surfaces.filter(s=>!s.id.startsWith('pavilion-ribbed-roof'));
 for(const a of [68,75,82,89,96])for(let j=0;j<8;j++){
  const r=mix(79.5,94.5,j/8),s=mix(79.5,94.5,(j+1)/8),y=q=>24.8+5.8*Math.sin((q-79.5)/15*Math.PI);
  beam(`pavilion-truss-${a}-${j}`,p(r,a*D,y(r)),p(s,a*D,y(s)),.45,.7);
 }
 for(const [i,a]of [[0,72],[1,85],[2,93]])for(const r of [92.2]){const [x,z]=polar(r,a*D);if(clearance([x,z])>3.8)box(`pavilion-bench-${i}-${r}`,x,16,z,1.2,1.1,2.2,'gold');}
 route('pavilion-inner-chamber-aisle',[polar(86,70*D),polar(83,70*D),...curve(83,70*D,94*D).slice(1),polar(86,94*D)],2);
 m.structures.push({id:'north-germination-pavilion',type:'room',district:'canopy',chambers:3,innerRadius:80,outerRadius:94,angles:[68,96],routeIds:['canopy-ring','pavilion-inner-chamber-aisle'],roofWalkable:false});

 // LIGHTWELL: four articulated roots support a specimen lantern/double helix.
 // Ground capture area and axial crossing remain open beneath the structure.
 for(const a of [37.5,127.5,217.5,307.5]){
  solidSector(`specimen-root-${a}`,8.1,8.9,(a-2)*D,(a+2)*D,5.8,'brick',0);
  const base=p(8.5,a*D,5.8),shoulder=p(5.2,(a+22)*D,10.5);
  beam(`specimen-root-branch-${a}`,base,shoulder,.9,1.3,'gold');
 }
 for(const hand of [-1,1])for(let j=0;j<40;j++){
  const point=t=>{const a=hand*t*TAU+Math.PI*(hand<0?1:0),r=4.9-1.2*Math.sin(t*Math.PI);return p(r,a,9+t*14);};
  beam(`specimen-helix-${hand}-${j}`,point(j/40),point((j+1)/40),.55,.9,'verdigris');
 }
 for(let i=0;i<24;i++){const a=i*TAU/24,b=(i+1)*TAU/24;quad(`specimen-vessel-${i}`,[p(4.2,a,11),p(4.2,b,11),p(3.8,b,21),p(3.8,a,21)],'glass','none');}
 roof('specimen-lantern-crown',.8,6,0,TAU,22.5,2.2,'gold');
 m.structures.push({id:'lightwell-specimen-lantern',type:'landmark',height:25,openBelow:5.8,routeIds:['lightwell-loop','lightwell-axis'],roofWalkable:false});

 // TERRACED BOTANICAL DISTRICTS: continuous soil masses, interrupted by actual
 // reserved route gaps. Plant masses grow from beds, not a scatter of boxes.
 const beds=[];
 for(const [band,r0,r1]of [[0,28,42],[1,64,77],[2,98,110]])for(const [district,a0,a1]of [['fern',28,48],['orchid',112,138],['cycad',202,226],['reed',292,318]]){
  for(let r=r0;r<r1;r+=4.5)for(let a=a0;a<a1;a+=4){const s=Math.min(r+4.2,r1),b=Math.min(a+4,a1);
   if(reserved(r,s,a*D,b*D,3.5))continue;
   // Machinery and archive districts own their broader footprints.
   if(band===1&&(a0===202||a0===28))continue;
   const id=`botanical-bed-${district}-${band}-${r}-${a}`;
   solidSector(id,r,s,a*D,b*D,.95,'soil');beds.push({id,r:(r+s)/2,a:(a+b)*D/2,radius:1.5});
  }
 }
 const fern=(id,x,y,z,scale,fronds=12)=>{
  for(let f=0;f<fronds;f++){const a=f*2.399963,r=scale*(.8+(f%4)*.11),vertices=[],triangles=[];
   for(let j=0;j<=7;j++){const t=j/7,w=scale*.16*Math.sin(t*Math.PI),cx=x+Math.cos(a)*r*t,cz=z+Math.sin(a)*r*t,h=y+scale*Math.sin(t*Math.PI*.82)*(.7+(f%3)*.13);
    vertices.push([cx-Math.sin(a)*w,h,cz+Math.cos(a)*w],[cx,h+.06,cz],[cx+Math.sin(a)*w,h,cz-Math.cos(a)*w]);
    if(j)for(let k=0;k<2;k++){const q=(j-1)*3+k;triangles.push([q,q+3,q+4],[q,q+4,q+1]);}
   }
   mesh(`${id}-frond-${f}`,vertices,triangles,f%3?'botanical':'leaflight','none');
  }
 };
 for(const bed of beds){const [x,z]=polar(bed.r,bed.a);fern(bed.id,x,floor(x,z)+.9,z,2.4,16);}
 fern('specimen-tree',0,11,0,6.2,32);

 // DEEP RIBS: paired tapered I-sections, triangulated web bracing, collars and
 // actual radial bearing shoes at r119.5. No wire grid masquerading as framing.
 const crown=r=>28+20*Math.sin((119.5-r)/85.5*Math.PI*.8);
 for(let i=0;i<16;i++){
  const a=(i+.5)*TAU/16;
  solidSector(`crown-bearing-${i}`,119.1,120,(a-.8*D),(a+.8*D),4,'stone',24);
  for(let j=0;j<18;j++){
   const r=mix(119.5,34,j/18),s=mix(119.5,34,(j+1)/18),w=mix(1.05,.5,j/18),h=mix(2.6,1.6,j/18);
   beam(`deep-rib-bottom-${i}-${j}`,p(r,a,crown(r)),p(s,a,crown(s)),w,.7);
   beam(`deep-rib-top-${i}-${j}`,p(r,a,crown(r)+h),p(s,a,crown(s)+h),w,.7);
   beam(`deep-rib-web-${i}-${j}`,p(r,a,crown(r)),p(s,a,crown(s)+h),.25,.32,'verdigris','box');
   if(j%3===0)beam(`deep-rib-node-${i}-${j}`,p(r,a,crown(r)-.16),p(r,a,crown(r)+h+.16),w+.2,.45,'gold','box');
  }
 }
 for(const r of [46,82,114])for(let i=0;i<96;i++){const a=(i+3)*TAU/96,b=(i+4)*TAU/96;beam(`roof-ring-truss-${r}-${i}`,p(r,a,crown(r)+1),p(r,b,crown(r)+1),.55,.8);}
 for(let i=0;i<16;i++)for(let j=0;j<6;j++){
  const a=(i+.5)*TAU/16+.012,b=(i+1.5)*TAU/16-.012,r=mix(94,116,j/6),s=mix(94,116,(j+1)/6),mat=i%3===0?'solar':'glass',collision=mat==='glass'?'none':'surface';
  for(let k=0;k<4;k++){const u=mix(a,b,k/4),v=mix(a,b,(k+1)/4);quad(`roof-bay-${i}-${j}-${k}`,[p(r,u,crown(r)+1.7),p(r,v,crown(r)+1.7),p(s,v,crown(s)+1.7),p(s,u,crown(s)+1.7)],mat,collision);}
 }

 // Large-scale material districts use the actual floor faces: no second sheet.
 for(const surface of m.terrain.surfaces.filter(s=>s.walkable)){
  const c=surface.vertices.reduce((a,v)=>a.map((n,i)=>n+v[i]/surface.vertices.length),[0,0,0]),r=Math.hypot(c[0],c[2]),a=Math.atan2(c[2],c[0])/D;
  let material='stone';
  if(r<25)material='verdigris';
  else if((r>45&&r<60)||(r>80&&r<94))material=a>140||a<-140?'brick':a>-30&&a<30?'verdigris':'ceramic';
  else if(clearance([c[0],c[2]])>4)material='soil';
  surface.material=material;m.art.meshes.find(p=>p.id===surface.id).material=material;
 }
 // Only broad, correctly draped inlays survive. Clip each strip against the
 // actual source floor triangles, eliminating the old chord/slope penetration.
 const floorTriangles=ground.surfaces.flatMap(s=>s.triangles.map(t=>t.map(i=>s.vertices[i])));
 const clip=(poly,a,b,sign)=>{const out=[],dist=v=>sign*((b[0]-a[0])*(v[2]-a[1])-(b[1]-a[1])*(v[0]-a[0]));for(let i=0;i<poly.length;i++){const u=poly[i],v=poly[(i+1)%poly.length],du=dist(u),dv=dist(v);if(du>=-1e-9)out.push(u);if((du>0&&dv<0)||(du<0&&dv>0)){const t=du/(du-dv);out.push(u.map((q,j)=>mix(q,v[j],t)));}}return out;};
 const ribbon=(id,a,b,width,mat)=>{
  const dx=b[0]-a[0],dz=b[1]-a[1],l=Math.hypot(dx,dz),nx=-dz/l*width/2,nz=dx/l*width/2,poly=[[a[0]-nx,a[1]-nz],[b[0]-nx,b[1]-nz],[b[0]+nx,b[1]+nz],[a[0]+nx,a[1]+nz]],vertices=[],triangles=[];
  const minX=Math.min(...poly.map(p=>p[0])),maxX=Math.max(...poly.map(p=>p[0])),minZ=Math.min(...poly.map(p=>p[1])),maxZ=Math.max(...poly.map(p=>p[1]));
  for(const tri of floorTriangles){if(Math.max(...tri.map(p=>p[0]))<minX||Math.min(...tri.map(p=>p[0]))>maxX||Math.max(...tri.map(p=>p[2]))<minZ||Math.min(...tri.map(p=>p[2]))>maxZ)continue;let q=tri;for(let i=0;i<4;i++)q=clip(q,poly[i],poly[(i+1)%4],1);if(q.length<3)continue;const base=vertices.length;vertices.push(...q.map(v=>[v[0],v[1]+.045,v[2]]));for(let i=1;i<q.length-1;i++)triangles.push([base,base+i,base+i+1]);}
  mesh(id,vertices,triangles,mat,'none');
 };
 for(const r of primary)for(let i=1;i<r.points.length;i++){
  const a=r.points[i-1],b=r.points[i],dx=b[0]-a[0],dz=b[1]-a[1],l=Math.hypot(dx,dz),nx=-dz/l,nz=dx/l;
  for(const side of [-1,1])ribbon(`draped-inlay-${r.id}-${i}-${side}`,[a[0]+nx*side*2.45,a[1]+nz*side*2.45],[b[0]+nx*side*2.45,b[1]+nz*side*2.45],.55,r.id.startsWith('spiral')?'gold':'ceramic');
 }
 m.art.labels=[{text:'01 / SEED ARCHIVE',x:-50,y:16.4,z:-15,size:.75,yaw:Math.PI,material:'gold'},{text:'02 / FILTRATION WORKS',x:52,y:16.6,z:0,size:.75,yaw:0,material:'gold'},{text:'03 / GERMINATION',x:0,y:24.7,z:86,size:1,yaw:0,material:'gold'}];
 m.art.districts=['seed-archive-crescent','irrigation-filtration-works','north-germination-pavilion','lightwell-specimen-lantern','terraced-botanical-banks'];
 m.art.aliasingFix={removedFineMasonry:true,inlayWidth:.55,clearance:.045,method:'clip to authoritative floor triangles'};
 m.art.reviewStatus='awaiting-second-Blender-pass';
 m.verification={primaryRouteIds:primary.map(r=>r.id),interiorRouteIds:m.routes.slice(primary.length).map(r=>r.id),districts:m.structures.map(s=>s.id)};
 return m;
}
export const recipe=makeRecipe();

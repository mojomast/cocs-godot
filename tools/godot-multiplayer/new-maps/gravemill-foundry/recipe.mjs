// Hand-authored metres, source X/Z horizontal and Y up. No registry mutation.
export const ID='gravemill-foundry';
export const SEED=0x47524156;
export const modes=['payload','assault','combined-arms','deathmatch','teamdeathmatch','domination'];
const bands=[[-180,0],[-25,0],[25,12],[55,12],[99,24],[119,24],[160,35],[180,35]];
export function height(x,z){const q=z-.14*x;for(let i=1;i<bands.length;i++)if(q<=bands[i][0]){const [a,h]=bands[i-1],[b,k]=bands[i];return h+(k-h)*(q-a)/(b-a);}return 35;}
const xyz=(x,q,y=height(x,q+.14*x))=>[x,y,q+.14*x];
export function recipe(){
 const m={id:ID,name:'Gravemill Foundry',seed:SEED,genSeed:SEED,tag:'FRACTURED CANYON / ORE PROCESSION',description:'An oblique mineral amphitheatre: crusher throat, vaulted cooling works, and copper furnace crown. Three staggered terraces and a service loop meet at four maintenance inclines.',bounds:{minX:-192,maxX:192,minZ:-144,maxZ:144},sky:'dusk',floorColor:'#a29c88',background:'#242b2d',color:'#bc7650',nextGen:true,raised:false,scatter:false,voidY:-20,blocks:[],structures:[],props:[],spawns:[],pickups:[],navNodes:[],objectiveZones:[],overhead:[],routes:[],terrain:{maxSlope:.8,base:0,amplitude:35,surfaces:[],walls:[]},art:{palette:'mineral-soot-copper',pieces:[],ground:[],landmarks:[]},modeBindings:{objectives:['payload'],assault:['assault'],'combined-arms':['combined-arms'],combat:['deathmatch','teamdeathmatch'],zones:['domination']}};
 const surf=(id,vertices,triangles,material='mineral',walkable=false)=>m.terrain.surfaces.push({id,material,walkable,vertices,triangles});
 // Source movement tests wall perimeter segments, whereas shots fan-triangulate
 // polygons. Triangles retain a low-to-high diagonal at every vertical face;
 // an untriangulated quad has only same-height horizontal edges and leaks bodies.
 const wall=(id,vertices,material='soot')=>{for(let i=1;i<vertices.length-1;i++)m.terrain.walls.push({id,vertices:[vertices[0],vertices[i],vertices[i+1]],material});};
 // Clip each oblique stratum to the exact rectangular play boundary. One
 // support surface per X/Z: overheads never participate in floor selection.
 const clip=(poly,axis,value,sign)=>{const out=[];for(let i=0;i<poly.length;i++){const a=poly[i],b=poly[(i+1)%poly.length],da=(a[axis]-value)*sign,db=(b[axis]-value)*sign;if(da>=0)out.push(a);if((da<0)!==(db<0)){const t=da/(da-db);out.push(a.map((v,k)=>v+(b[k]-v)*t));}}return out;};
 for(let i=1;i<bands.length;i++){const [q0,y0]=bands[i-1],[q1,y1]=bands[i];let p=[xyz(-192,q0,y0),xyz(-192,q1,y1),xyz(192,q1,y1),xyz(192,q0,y0)];p=clip(clip(p,2,-144,1),2,144,-1);if(p.length>=3)surf(`stratum-${i}`,p,Array.from({length:p.length-2},(_,j)=>[0,j+1,j+2]),i===3?'cooling-floor':i===5?'soot':'mineral',true);}
 const prism=(id,x,q,w,d,h,material='soot',base=null)=>{
  const y=base??Math.min(...[-1,1].flatMap(s=>[-1,1].map(t=>height(x+s*w/2,q+t*d/2+.14*(x+s*w/2))))),v=[xyz(x-w/2,q-d/2,y),xyz(x-w/2,q+d/2,y),xyz(x+w/2,q+d/2,y),xyz(x+w/2,q-d/2,y)];
  for(let i=0;i<4;i++){const a=v[i],b=v[(i+1)%4];wall(`${id}-side-${i}`,[a,b,[b[0],y+h,b[2]],[a[0],y+h,a[2]]],material);}
  surf(`${id}-top`,v.map(p=>[p[0],y+h,p[2]]),[[0,1,2],[0,2,3]],material);
  surf(`${id}-bottom`,v,[[2,1,0],[3,2,0]],material);
  return {x,q,y,w,d,h};
 };
 const cylinder=(id,x,q,r,h,material='copper',n=20)=>{const y=height(x,q-r+.14*x),profile=id.startsWith('furnace')?[[0,r],[h*.65,r],[h*.84,r*.5],[h,r*.5]]:[[0,r],[h-3,r],[h,r*.45]];let cap=[];for(let j=1;j<profile.length;j++){const ring=([dy,rr])=>Array.from({length:n},(_,i)=>xyz(x+rr*Math.cos(i*2*Math.PI/n),q+rr*Math.sin(i*2*Math.PI/n),y+dy));const a=ring(profile[j-1]),b=ring(profile[j]);for(let i=0;i<n;i++)wall(`${id}-shell-${j}-${i}`,[a[i],a[(i+1)%n],b[(i+1)%n],b[i]],material);cap=b;}surf(`${id}-cap`,cap,Array.from({length:n-2},(_,i)=>[0,i+2,i+1]),material);m.art.landmarks.push({kind:'silo',id,x,y,z:q+.14*x,r,h,material,profile});};
 const rock=(id,x,q,w,d,h)=>{const outline=[[-.5,-.5],[-.5,.2],[-.25,.5],[.5,.34],[.5,-.34],[.1,-.5]],y=height(x,q-d/2+.14*x),base=outline.map(([a,b])=>xyz(x+a*w,q+b*d,y)),top=base.map((v,i)=>[v[0],y+h*[.82,1,.86,.94,.78,.92][i],v[2]]);for(let i=0;i<6;i++)wall(`${id}-facet-${i}`,[base[i],base[(i+1)%6],top[(i+1)%6],top[i]],'mineral');surf(`${id}-crest`,top,[[0,1,2],[0,2,3],[0,3,4],[0,4,5]],'mineral');m.art.landmarks.push({id,kind:'rock',x,y,z:q+.14*x,base,top});};
 const route=(id,width,points)=>{const converted=points.map(([x,q])=>[x,q+.14*x]);m.routes.push({id,width,points:converted});for(let i=1;i<converted.length;i++){const a=converted[i-1],b=converted[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);for(let j=0;j<=n;j++)m.navNodes.push({x:a[0]+(b[0]-a[0])*j/n,z:a[1]+(b[1]-a[1])*j/n});}return converted;};
 const freight=[[-166,-62],[-126,-62],[-88,-38],[-40,-38],[0,-64],[48,-64],[88,-38],[126,-38],[166,-62]];
 m.payloadPath=route('ore-procession',18,freight).map(([x,z])=>({x,z}));
 route('service-return',20,[[166,-62],[156,-100],[126,-116],[-126,-116],[-156,-100],[-166,-62]]);
 route('cooling-gallery',10,[[-166,-62],[-166,-10],[-144,36],[-92,36],[-28,36],[28,36],[92,36],[144,36],[166,-10],[166,-62]]);
 route('crown-gantry',8,[[-144,36],[-144,74],[-118,109],[-64,109],[0,109],[64,109],[118,109],[144,74],[144,36]]);
 for(const x of [-112,-34,34,112])route(`maintenance-incline-${x}`,7,[[x,-100],[x,-62],[x,-38],[x,0],[x,36],[x,74],[x,109]]);
 // Paired protected spawn pockets; first entries are exact payload endpoints.
 m.teamSpawns={0:[[-166,-62],[-178,-78],[-174,-38],[-161,-90]].map(([x,q])=>[x,q+.14*x]),1:[[166,-62],[178,-78],[174,-38],[161,-90]].map(([x,q])=>[x,q+.14*x])};
 m.spawns=[...m.teamSpawns[0],...m.teamSpawns[1],[-70,36],[70,36],[0,109]].map((p,i)=>i<8?p:[p[0],p[1]+.14*p[0]]);
 for(const [i,x,q,label] of [[0,-88,-38,'CRUSHER THROAT'],[1,0,36,'COOLING NAVE'],[2,88,-38,'FURNACE APRON']])m.objectiveZones.push({id:`foundry-sector-${i}`,x,z:q+.14*x,y:height(x,q+.14*x),radius:8,label});
 m.vehicles=[[-158,-62,0],[158,-62,1]].map(([x,q,team])=>({id:`foundry-puma-${team}`,kind:'puma',x,z:q+.14*x,y:0,team,yaw:team===0?Math.PI/2:-Math.PI/2}));
 m.pickups=[['health',-144,36],['health',144,36],['armor',-112,-100],['armor',112,-100],['rocket',0,36],['rail',0,109]].map(([kind,x,q])=>[kind,x,q+.14*x]);
 // Cooling nave and assay vault: 3 open portals per side, continuous barrel
 // vault made of individual sloping panels, never an invisible door AABB.
 for(const [id,cx,w] of [['cooling-nave',-66,52],['assay-vault',66,52]]){
  const q=36,half=10,base=12;
  for(const side of [-1,1])for(let i=0;i<4;i++){const x=cx-w/2+i*w/3;prism(`${id}-pier-${side}-${i}`,x,q+side*half,1.6,1.6,8,'soot',base);}
  for(const side of [-1,1])for(const bay of [-1,1]){const x=cx+bay*w/3;prism(`${id}-window-sill-${side}-${bay}`,x,q+side*half,14,1.1,1.1,'mineral',base);prism(`${id}-window-header-${side}-${bay}`,x,q+side*half,14,1.1,2,'soot',base+5);}
  for(const end of [-1,1])for(const side of [-1,1])prism(`${id}-portal-jamb-${end}-${side}`,cx+end*w/2,q+side*8,1.3,3,7,'mineral',base);
  for(let s=0;s<10;s++){const a=s*Math.PI/10,b=(s+1)*Math.PI/10;const qa=q+half*Math.cos(a),qb=q+half*Math.cos(b),ya=base+7+5*Math.sin(a),yb=base+7+5*Math.sin(b);const v=[xyz(cx-w/2,qa,ya),xyz(cx+w/2,qa,ya),xyz(cx+w/2,qb,yb),xyz(cx-w/2,qb,yb)];surf(`${id}-vault-${s}`,v,[[0,1,2],[0,2,3]],'copper');}
  m.structures.push({id,type:'vaulted-gallery',x:cx,z:q+.14*cx,w,d:20,height:12,doors:'ewns',exits:4});
 }
 for(const [a,b] of [[-106,-40],[-28,28],[40,106]])for(const q of [104,114])prism(`gantry-parapet-${a}-${q}`,(a+b)/2,q,b-a,.4,1.1,'soot',24);
 // Process towers occupy islands BETWEEN the reserved routes, with exact
 // radial shell collisions. Heavy crusher drums have a solid machinery base.
 for(const [id,x,q,r,h] of [['furnace-a',64,-8,11,29],['furnace-b',94,8,8,23],['ore-silo-a',-76,76,9,20],['ore-silo-b',-54,80,7,17],['ore-silo-c',76,76,8,22]])cylinder(id,x,q,r,h);
 for(const x of [-98,-82,-62,46,98,130]){const q=Math.abs(x)>110?63:64;cylinder(`filter-bank-${x}`,x,q,4.2,10,'soot',16);}
 for(const x of [-132,-94,-50,22,96,134]){prism(`ore-hopper-${x}`,x,-94,9,8,3.5,'soot');m.art.landmarks.push({id:`hopper-detail-${x}`,kind:'hopper',x,y:0,z:-94+.14*x,w:9,d:8,h:3.5});}
 for(const [x,q] of [[-72,-7],[-48,0]]){const p=prism(`crusher-bed-${x}`,x,q,17,16,5,'soot');const cy=p.y+11,n=24;const ring=side=>Array.from({length:n},(_,i)=>xyz(x+side*8.5,q+7*Math.cos(i*2*Math.PI/n),cy+7*Math.sin(i*2*Math.PI/n)));const a=ring(-1),b=ring(1);for(let i=0;i<n;i++){const j=(i+1)%n;const v=[a[i],b[i],b[j],a[j]];surf(`crusher-drum-${x}-${i}`,v,[[0,1,2],[0,2,3]],'soot');wall(`crusher-drum-contact-${x}-${i}`,v,'soot');}wall(`crusher-cap-${x}-a`,a,'soot');wall(`crusher-cap-${x}-b`,b.toReversed(),'soot');m.art.landmarks.push({id:`crusher-drum-${x}`,kind:'crusher',x,y:cy,z:q+.14*x,r:7,length:17,material:'soot'});}
 // Broken geological buttresses screen base-to-base shots without enclosing
 // the layout in a square yard. Ends deliberately leave both reverse flanks.
 for(const [x,q,w,d,h] of [[-72,-82,14,24,9],[-72,-62,12,8,8],[64,-88,18,20,11],[-138,0,12,20,16],[132,4,12,20,19],[-14,5,12,20,17],[14,77,12,18,15],[-90,133,30,8,11],[72,132,35,8,12]])rock(`fracture-${x}-${q}`,x,q,w,d,h);
 // Low counters at asymmetric offsets give sightline relief in every tier.
 for(const q of [-48,45,117])for(const x of [-130,-92,-54,-12,52,92,130]){if(q===45&&Math.abs(x)===92)continue;prism(`ore-bin-${x}-${q}`,x,q,5,3,1.5,q===117?'copper':'soot');}
 for(const s of [-1,1]){prism(`spawn-screen-${s}`,s*180,-60,3,20,5,'mineral');prism(`spawn-baffle-${s}`,s*151,-82,7,4,3,'soot');}
 // Suspended conveyors have actual under/over slabs with separated supports.
 for(const [x,q,length] of [[-24,-68,54],[24,34,92],[-122,84,36],[122,84,36]]){
  const y=height(x,q+.14*x)+13;prism(`conveyor-${x}-${q}`,x,q,3,length,1.1,'soot',y);
  for(const dq of [-length/2,length/2])for(const dx of [-3,3])prism(`trestle-${x}-${q}-${dq}-${dx}`,x+dx,q+dq,1,1,y-height(x+dx,q+dq+.14*(x+dx)),'soot');
  m.art.landmarks.push({kind:'conveyor',id:`conveyor-detail-${x}-${q}`,x,y,z:q+.14*x,length});
 }
 for(const [q,y,length] of [[-4,33,244],[80,44,192]]){
  prism(`transverse-conveyor-${q}`,0,q,length,3,1.2,'soot',y);
  for(const s of [-1,1])for(const dq of [-3,3]){const x=s*(length/2-2),qq=q+dq,base=height(x,qq+.14*x);prism(`transverse-trestle-${q}-${s}-${dq}`,x,qq,1.2,1.2,y-base,'soot',base);}
  m.art.landmarks.push({kind:'conveyor',axis:'x',id:`transverse-belt-${q}`,x:0,y,z:q,length});
 }
 // Stopped cargo lifts are grade-continuous terrace landings, never elevators.
 for(const x of [-144,144])m.art.landmarks.push({kind:'static-lift',id:`lift-${x}`,x,y:12,z:36+.14*x,w:9,d:8});
 // Tall boundary strata remain outside traversal. Exact walls prevent falling
 // past the authored support while keeping the geology's open skyline.
 for(const [a,b] of [[[-192,-144],[192,-144]],[[192,-144],[192,144]],[[192,144],[-192,144]],[[-192,144],[-192,-144]]])wall('boundary',[[a[0],-3,a[1]],[b[0],-3,b[1]],[b[0],44,b[1]],[a[0],44,a[1]]],'mineral');
 return m;
}

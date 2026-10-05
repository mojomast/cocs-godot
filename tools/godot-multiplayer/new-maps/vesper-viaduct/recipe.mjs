// Vesper: a single-valued city hillside, never stacked playable decks.
// Height-preserving stair bevel (applied 2026-10-05). Pulls each civic tread's
// walkable top face back by STAIR_BEVEL at its ascent (-Z) edge and adds a 45 deg
// chamfer, so a 0.35 capsule rests on a 45 deg face instead of a 90 deg wall.
// The top plane Y is reused verbatim; no route, nav, spawn or objective height moves.
// See VESPER_STAIR_COLLISION_PROPOSAL_20261005.md and
// VESPER_BEVEL_REBUILD_20261005.md.
export const STAIR_BEVEL = 0.043438367470067386;
export const ID='vesper-viaduct';
export const height=z=>z<=-65?0:z<-25?(z+65)*.3:z<=25?12:z<65?12+(z-25)*.3:24;
// Bevel one authored flat tread quad in place: same Y plane, -Z edge pulled
// back by `leg`, one 45 deg chamfer quad prepended. Returns the two corner
// quads as flat vertex lists -- [walkable top (0..3), chamfer (4..7)] -- the
// same shape bevelSurfaced() builds in revisions/urban-v2/recipe-v2.mjs.
export const bevelTread=(quad,leg)=>{
  const y=quad[0][1],z0=quad[0][2],z1=quad[2][2],x0=quad[0][0],x1=quad[2][0],zl=z0+leg;
  const top=[[x0,y,zl],[x0,y,z1],[x1,y,z1],[x1,y,zl]];
  const cham=[[x0,y-leg,z0],[x0,y,zl],[x1,y,zl],[x1,y-leg,z0]];
  return [top,cham].flat();
};
export function recipe(){
 const m={id:ID,name:'Vesper Viaduct',tag:'CANAL CITY / STATION INTERCHANGE',description:'Warm brick station galleries above a cobalt canal cut; civic courtyards connect three urban street levels.',bounds:{minX:-140,maxX:140,minZ:-120,maxZ:120},sky:'dusk',floorColor:'#66515a',background:'#182239',color:'#e7aa69',nextGen:true,raised:false,scatter:false,blocks:[],props:[],structures:[],spawns:[],pickups:[],navNodes:[],routes:[],objectiveZones:[],modeBindings:{combat:['deathmatch','teamdeathmatch'],objectives:['ctf'],zones:['domination','koth','uplink']},terrain:{maxSlope:.7,base:0,amplitude:24,surfaces:[],walls:[]},art:{ground:[],pieces:[],palette:'warm-brick-charcoal-cobalt',labels:[]}};
 const face=(id,p,material='brick')=>{for(let i=1;i<p.length-1;i++)m.terrain.walls.push({id:`${id}-${m.terrain.walls.length}`,material,vertices:[p[0],p[i],p[i+1]]});};
 const roof=(id,p,material='slate',walkable=false)=>m.terrain.surfaces.push({id,material,walkable,vertices:p,triangles:Array.from({length:p.length-2},(_,i)=>[0,i+1,i+2])});
  // bevelTread() returns [top quad (0..3), chamfer quad (4..7)]. The walkable top
  // keeps the authored id and its two triangles; the 45 deg chamfer is a separate
  // non-walkable surface, so support resolution and the original collider name
  // are unchanged.
  const beveled=(id,q,mat,leg)=>{
    const p=bevelTread(q,leg);
    m.terrain.surfaces.push({id,material:mat,walkable:true,
      vertices:[p[0],p[1],p[2],p[3]],triangles:[[0,1,2],[0,2,3]]});
    m.terrain.surfaces.push({id:id+'-bevel',material:mat,walkable:false,
      vertices:[p[4],p[5],p[6],p[7]],triangles:[[0,1,2],[0,2,3]]});
  };
 const box=(id,x,z,w,d,b,t,material='brick')=>{const p=[[x-w/2,b,z-d/2],[x+w/2,b,z-d/2],[x+w/2,b,z+d/2],[x-w/2,b,z+d/2]];for(let i=0;i<4;i++){const a=p[i],c=p[(i+1)%4];face(id,[a,c,[c[0],t,c[2]],[a[0],t,a[2]]],material);}roof(id+'-cap',p.map(v=>[v[0],t,v[2]]),material);};
 const wall=(id,a,b,y,t,mat='brick')=>face(id,[[a[0],y,a[1]],[b[0],y,b[1]],[b[0],t,b[1]],[a[0],t,a[1]]],mat);
 const route=(id,points,width=5)=>{m.routes.push({id,width,points});for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/4);for(let j=0;j<=n;j++)m.navNodes.push({x:a[0]+(b[0]-a[0])*j/n,z:a[1]+(b[1]-a[1])*j/n});}};
 // Exclusive X/Z strips: no invisible base plane under the water or upper street.
 for(const [a,b,mat] of [[-104,-65,'quay'],[-65,-25,'cobbles'],[-25,25,'cobbles'],[25,65,'asphalt'],[65,120,'asphalt']])for(const [left,right] of a===25?[[-140,30],[34,140]]:[[-140,140]])roof('city-grade-'+a+'-'+left,[[left,height(a),a],[left,height(b),b],[right,height(b),b],[right,height(a),a]],mat,true);
 // Hand-authored 150 mm civic stair: its 4 m footprint replaces the sloping
 // support, rather than layering decorative treads over a hidden ramp.
 for(let i=0;i<80;i++){const z=25+i*.5,y=12+(i+1)*.15,q=[[30,y,z],[30,y,z+.5],[34,y,z+.5],[34,y,z]];
  beveled('civic-stair-'+i,q,'sandstone',STAIR_BEVEL);}
 roof('far-quay',[[-140,0,-120],[-140,0,-116],[140,0,-116],[140,0,-120]],'quay',true);
 for(const x of [-100,100]){
  roof('canal-bridge-'+x,[[x-6,0,-116],[x-6,0,-104],[x+6,0,-104],[x+6,0,-116]],'brick',true);
  box('bridge-bearing-slab',x,-110,12,12,-.7,-.05,'brick');
  for(const z of [-115.5,-104.5])box('bridge-abutment',x,z,12,1,-3,-.05,'brick');
  for(const s of [-1,1])box('bridge-parapet',x+s*6,-110,.6,12,0,1.4,'brick');
  route('canal-bridge-'+x,[[x,-85],[x,-118]],4);
 }
 // Physical quay edges interrupted only at genuine supported bridges.
 for(const z of [-104,-116])for(const [a,b] of [[-140,-106],[-94,94],[106,140]])box('quay-rail',(a+b)/2,z,b-a,.65,0,1.5,'iron');
 m.art.water={x:0,y:-2,z:-110,w:280,d:12};
 // Three through-room buildings; windows are sill/lintel apertures, not boxes.
 const hall=(id,x,z,w,d,h,material='brick')=>{
  const y=height(z),x0=x-w/2,x1=x+w/2,z0=z-d/2,z1=z+d/2;
  for(const xx of [x0,x1]){for(const [a,b] of [[z0,z-4],[z+4,z1]])wall(id+'-portal-jamb',[xx,a],[xx,b],y,y+h,material);wall(id+'-portal-lintel',[xx,z-4],[xx,z+4],y+5,y+h,material);}
  for(const zz of [z0,z1])for(let a=x0;a<x1;a+=8){const b=Math.min(a+8,x1);if(id==='platform-gallery'&&a<4&&b>-4){wall(id+'-cross-street-lintel',[a,zz],[b,zz],y+5,y+h,material);continue;}wall(id+'-window-sill',[a,zz],[b,zz],y,y+1,material);wall(id+'-window-lintel',[a,zz],[b,zz],y+3.8,y+h,material);wall(id+'-window-mullion',[a,zz],[a+.7,zz],y+1,y+3.8,'iron');}
  for(const xx of [x-w/6,x+w/6])for(const [a,b] of [[z0,z-3],[z+3,z1]])wall(id+'-room-divider',[xx,a],[xx,b],y,y+h-1,material);
  roof(id+'-roof-west',[[x0,y+h,z0],[x1,y+h,z0],[x1,y+h+4,z],[x0,y+h+4,z]],'slate');
  roof(id+'-roof-east',[[x0,y+h+4,z],[x1,y+h+4,z],[x1,y+h,z1],[x0,y+h,z1]],'slate');
  for(const xx of [x0,x1])face(id+'-gable',[[xx,y+h,z0],[xx,y+h+4,z],[xx,y+h,z1]],material);
  for(const xx of [x-w/3,x,x+w/3])for(const side of [-1,1])if(id!=='platform-gallery'||xx!==0)box(id+'-side-counter',xx,z+side*(d/2-4),5,1.5,y,y+1.1,'iron');
  m.structures.push({id,type:'three-room-through-hall',x,z,w,d,height:h,rooms:3,doors:['east','west'],windowAperture:[1,3.8]});
  m.art.labels.push({text:id.toUpperCase().replaceAll('-',' '),x,y:y+5.4,z:z0-.1});
 };
 hall('ticket-concourse',-66,85,48,28,13);
 hall('platform-gallery',0,85,36,28,18);
 hall('east-station',66,85,48,28,15);
 hall('west-courtyard',-66,0,48,30,9);
 hall('east-post-office',66,0,48,30,11);
 hall('bonded-warehouse',-66,-85,48,26,10);
 hall('canal-service',66,-85,48,26,9);
 // Tower mass touches the civic square without blocking its crosslink.
 box('clock-tower',22,20,12,12,12,58,'brick');
 box('clock-belfry',22,20,15,15,52,59,'iron');
 roof('clock-spire',[[14,59,12],[30,59,12],[22,70,20]],'slate');
 roof('clock-spire-2',[[30,59,12],[30,59,28],[22,70,20]],'slate');
 roof('clock-spire-3',[[30,59,28],[14,59,28],[22,70,20]],'slate');
 roof('clock-spire-4',[[14,59,28],[14,59,12],[22,70,20]],'slate');
 m.art.clock={x:22,y:55,z:12.4,radius:2.8};
 // Attached row-building districts terrace with the city. Breaks at every cross
 // street provide actual uphill traversal instead of painted ramp illusions.
 for(const z of [-47,45,112])for(const center of [-68,68])for(let j=0;j<5;j++){
  const x=center+(j-2)*8,y=height(z-(z===112?7:11)),h=13+(j%3)*3,front=z-(z===112?7:11);
  box(`row-${z}-${x}`,x,z,8,z===112?14:22,y,height(z+7)+h,j%2?'brick':'plaster');
  // Raised cornices, recessed facade bays and chimney groups (authoring details).
  m.art.pieces.push({kind:'cornice',x,y:height(z+7)+h-.4,z:front-.25,w:8.3,h:.45,d:.55,material:'sandstone'});
  for(const xx of [x-2,x+2])for(let level=0;level<3;level++)m.art.pieces.push({kind:'recess-window',x:xx,y:height(z+7)+3+level*3,z:front-.02,w:1.5,h:2,d:.08,material:'glass'});
  box('chimney',x+2,z,1.2,1.5,height(z+7)+h,height(z+7)+h+2,'brick');
 }
 // Close the formerly empty center of the slope with two genuinely solid mixed
 // use blocks on each tier. The five cross streets remain separate clear slots.
 for(const z of [-47,45])for(const x of [-16,16]){
  const y=height(z-11),top=height(z+11)+16;
  box('central-row-'+x+'-'+z,x,z,16,22,y,top,'brick');
  m.art.pieces.push({kind:'central-cornice',x,y:top-.25,z:z-11.25,w:16.4,h:.5,d:.6,material:'sandstone'});
  for(const dx of [-5,-1.6,1.6,5])for(let level=0;level<4;level++)m.art.pieces.push({kind:'central-window',x:x+dx,y:height(z+11)+2+level*3,z:z-11.02,w:1.5,h:2,d:.08,material:'glass'});
 }
 // Brick arcade at the northern station retaining edge. The vaulted ceiling is
 // non-walkable; piers carry it and never share a playable lower/upper footprint.
 for(const center of [-66,66]){
  for(const x of [center-24,center-12,center,center+12,center+24])box('arcade-pier',x,66,1.8,3,24,34,'brick');
  for(let bay=0;bay<4;bay++){const a=center-24+bay*12;for(let j=0;j<8;j++){const x=a+12*j/8,xx=a+12*(j+1)/8,lo=28+4*Math.sin(j*Math.PI/8),hi=28+4*Math.sin((j+1)*Math.PI/8);face('arcade-arch',[[x,lo,64.5],[xx,hi,64.5],[xx,35,64.5],[x,35,64.5]]);}}
  roof('arcade-ceiling-'+center,[[center-24,35,64.5],[center-24,35,70],[center+24,35,70],[center+24,35,64.5]],'brick');
 }
 // Broad switchback boulevards, fine-grained courtyard street, loading cut.
 route('station-boulevard',[[-120,0],[-120,38],[-108,58],[-120,85],[-96,85],[-42,85],[-20,85],[20,85],[42,85],[96,85],[120,85],[108,58],[120,38],[120,0]],8);
 route('civic-street',[[-120,0],[-96,0],[-40,0],[0,0],[40,0],[96,0],[120,0]],6);
 route('canal-cut',[[-120,0],[-120,-85],[-96,-85],[-40,-85],[0,-85],[40,-85],[96,-85],[120,-85],[120,0]],7);
 for(const x of [-100,-32,0,32,100]){
  route('lower-crosslink-'+x,[[x,-85],[x,0]],5);
  route('upper-crosslink-'+x,[[x,0],[x,85]],5);
 }
 // Low street furniture breaks lateral views but leaves centerline and exits free.
 for(const z of [-85,0,85])for(const x of [-112,-36,36,112])box('street-cover',x,z+7,3,3,height(z),height(z)+1.6,'iron');
 for(const s of [-1,1]){route('spawn-exit-'+s,[[s*127,-8],[s*120,-8],[s*120,0]]);route('spawn-flank-'+s,[[s*127,8],[s*127,25],[s*120,38]]);}
 m.teamSpawns={0:[[-127,-8],[-127,8],[-120,0]],1:[[127,-8],[127,8],[120,0]]};m.spawns=[...m.teamSpawns[0],...m.teamSpawns[1]];
 m.flagSpawns={0:{x:-120,z:0},1:{x:120,z:0}};
 m.objectiveZones=[[-100,0,'WEST STEPS'],[0,0,'CLOCK SQUARE'],[100,0,'EAST STEPS']].map(([x,z,label])=>({x,z,y:height(z),radius:7,label}));
 m.pickups=[['health',-100,-85],['health',100,-85],['armor',-32,0],['armor',32,0],['rail',0,85],['rocket',0,-85]];
 for(const [x,z] of m.spawns)m.navNodes.push({x,z});
 // Curved tram rails follow explicit control points on the supported boulevard.
 const tram=[[-120,0],[-120,38],[-108,58],[-120,85],[-96,85],[-42,85],[0,85],[42,85],[96,85],[120,85],[108,58],[120,38],[120,0]],rail=[tram[0]];
 for(let i=1;i<tram.length-1;i++){const a=tram[i-1],b=tram[i],c=tram[i+1],point=p=>{const l=Math.hypot(p[0]-b[0],p[1]-b[1]);return b.map((v,j)=>v+(p[j]-v)*Math.min(4/l,.3));},p=point(a),q=point(c);for(let j=0;j<=12;j++){const t=j/12;rail.push([0,1].map(k=>(1-t)**2*p[k]+2*t*(1-t)*b[k]+t*t*q[k]));}}
 rail.push(tram.at(-1));m.art.tram=rail.map(([x,z])=>[x,height(z)+.025,z]);
 m.art.inspectionViews=[{id:'overview',eye:[190,175,-200],target:[0,20,0]},{id:'canal',eye:[-110,1.7,-95],target:[0,12,-60]},{id:'civic',eye:[-110,13.7,-8],target:[20,28,0]},{id:'concourse',eye:[-86,25.7,85],target:[30,30,85]},{id:'arcade',eye:[-100,25.7,65],target:[0,35,70]}];
 // Design candidates are not published native bindings.
 m.candidateModes=Object.values(m.modeBindings).flat();
 m.modeBindings={};
 return m;
}

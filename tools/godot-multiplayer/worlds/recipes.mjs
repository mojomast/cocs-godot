// Port-owned, deterministic source-compatible map templates. No source registry
// is modified here. All distances are metres in the source X/Z, Y-up frame.
import {validateMapSchema} from '../../../game/map-schema.mjs';

const box=(x,z,w,d,h,kind='wall')=>({x,z,w,d,h,kind});
const point=([x,z])=>({x,z});
const zone=(x,z,label,radius=6)=>({x,z,y:0,radius,label});
const route=(id,width,points)=>({id,width,points});
const pair=(points)=>({0:points,1:points.map(([x,z])=>[-x,z])});
const vehicle=(id,x,z,team,kind='puma')=>({id,x,z,y:0,kind,team,yaw:team===0?Math.PI/2:-Math.PI/2});
const common=(id,name,bounds,sky,floorColor)=>({id,name,bounds,sky,floorColor,background:'#172638',color:'#e3b989',nextGen:true,raised:false,scatter:false,
  blocks:[],structures:[],props:[],spawns:[],pickups:[],navNodes:[],objectiveZones:[],art:{pieces:[],palette:sky}});
const piece=(map,kind,x,y,z,w,h,d,material,extra={})=>map.art.pieces.push({kind,x,y,z,w,h,d,material,...extra});
const solid=(map,x,z,w,d,h,kind,material=kind)=>{map.blocks.push(box(x,z,w,d,h,kind));piece(map,'box',x,h/2,z,w,h,d,material);};
const hall=(map,id,x,z,w,d,doors='ew',height=7)=>{
  // Four real corners and disconnected wall runs. Doors remain open at grade;
  // the roof is visually supported and has an explicit overhead collision slab.
  const t=.8,gap=6;
  for(const s of [-1,1]){
    if(doors.includes('e')||doors.includes('w'))for(const v of [-1,1])solid(map,x+s*w/2,z+v*(d+gap)/4,t,(d-gap)/2,height,'building','plaster');
    else solid(map,x+s*w/2,z,t,d,height,'building','plaster');
    if(doors.includes('n')||doors.includes('s'))for(const v of [-1,1])solid(map,x+v*(w+gap)/4,z+s*d/2,(w-gap)/2,t,height,'building','plaster');
    else solid(map,x,z+s*d/2,w,t,height,'building','plaster');
  }
  // Source's AABB blocks start at Y=0. A roof cannot be represented by one;
  // instead the shared runtime must consume the overhead collision descriptor.
  map.art.pieces.push({kind:'roof',id,x,y:height+.45,z,w,h:.9,d,material:'roof'});
  map.overhead??=[];map.overhead.push({id,x,z,w,d,minY:height,maxY:height+.9});
  map.structures.push({type:'room',id,x,z,w,d,height,doors,roofY:height,exits:doors.split('').map(side=>({side,width:gap}))});
};
const trace=(map,r)=>{
  map.routes.push(r);
  for(let i=1;i<r.points.length;i++){
    const a=r.points[i-1],b=r.points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);
    for(let j=0;j<=n;j++)map.navNodes.push({x:a[0]+(b[0]-a[0])*j/n,z:a[1]+(b[1]-a[1])*j/n});
  }
};
const frame=(map)=>{const b=map.bounds;for(const [x,z,w,d] of [[b.minX,0,1,b.maxZ-b.minZ],[b.maxX,0,1,b.maxZ-b.minZ],[0,b.minZ,b.maxX-b.minX,1],[0,b.maxZ,b.maxX-b.minX,1]])solid(map,x,z,w,d,4,'boundary','retaining');};

function breakwater(){
  const m=common('breakwater-exchange','Breakwater Exchange',{minX:-108,maxX:108,minZ:-72,maxZ:72},'dusk','#677f84');
  m.tag='TIDAL SHIPYARD / FREIGHT ASSAULT';m.description='A switchback quay between two ferry terminals; cranes and through-sheds divide the heavy freight road from the covered infantry galleries.';
  m.modeBindings={zones:['domination'],assault:['assault'],objectives:['payload'], 'combined-arms':['combined-arms'],combat:['teamdeathmatch','deathmatch']};
  m.teamSpawns=pair([[-91,-14],[-93,10],[-83,27],[-83,-30]]);m.spawns=[...m.teamSpawns[0],...m.teamSpawns[1],[-20,40],[20,-40]];
  m.objectiveZones=[zone(-72,-12,'WEST FERRY'),zone(0,19,'LOCK CONTROL'),zone(72,-12,'EAST FERRY')];
  m.vehicles=[vehicle('west-hauler',-92,-45,0),vehicle('east-hauler',92,-45,1),vehicle('west-scout',-86,44,0,'scout'),vehicle('east-scout',86,44,1,'scout')];
  m.payloadPath=[[-91,-14],[-61,-14],[-47,18],[-12,18],[12,18],[47,-14],[91,-14]].map(point);
  m.routes=[];
  trace(m,route('freight-road',12,m.payloadPath.map(p=>[p.x,p.z])));
  trace(m,route('drydock-gallery',6,[[-91,-14],[-82,41],[-51,41],[-28,41],[0,41],[28,41],[51,41],[82,41],[91,-14]]));
  trace(m,route('slipway',7,[[-91,-14],[-78,-47],[-45,-48],[-20,-48],[20,-48],[45,-48],[78,-47],[91,-14]]));
  for(const sign of [-1,1]){
    trace(m,route(`cross-passage-${sign}`,7,[[sign*55,-48],[sign*55,-14],[sign*55,18],[sign*55,41]]));
    hall(m,`warehouse-${sign}`,sign*31,41,18,16,'ew',7);
    // Dock cranes have four separated legs; suspended beam is above vehicle clearance.
    for(const x of [sign*19,sign*43])for(const z of [-60,-52])solid(m,x,z,1.4,1.4,13,'gantry-leg','iron');
    piece(m,'box',sign*31,13,-56,26,1.2,12,'iron');
    m.overhead.push({id:`crane-${sign}`,x:sign*31,z:-56,w:26,d:12,minY:12.4,maxY:13.6});
    solid(m,sign*65,8,4,9,3,'container','coral');solid(m,sign*37,-31,4,10,3,'container','teal');
    for(const x of [sign*14,sign*50,sign*75])piece(m,'box',x,1.3,66,10,2.6,5,'seawall');
  }
  // No collision across any of the three longitudinal lanes.
  hall(m,'lock-house',0,-25,16,12,'ew',8);
  // Opposing lock bulkheads break the base-to-base sightline and make the
  // escorted cart turn twice. The 14 m drydock-gallery and slipway gaps remain
  // independent infantry routes; vehicle road bends have >12 m clearance.
  solid(m,-47,-22,3,36,7,'lock-bulkhead','retaining');
  solid(m,-47,-63,3,18,7,'lock-bulkhead','retaining');
  solid(m,47,15,3,38,7,'lock-bulkhead','retaining');
  solid(m,47,60,3,24,7,'lock-bulkhead','retaining');
  for(const x of [-96,96])solid(m,x,54,5,4,3,'bollard','iron');
  frame(m);
  m.pickups=[['health',-80,35],['health',80,35],['armor',-58,-42],['armor',58,-42],['rocket',0,40],['rail',0,-47]];
  m.art.ground=[{x:0,z:0,w:216,d:144,material:'quay'},{x:0,z:58,w:216,d:18,material:'tidal-silt'}];
  return m;
}

function thermal(){
  const m=common('thermal-divide','Thermal Divide',{minX:-92,maxX:92,minZ:-68,maxZ:68},'day','#929692');
  m.tag='ALPINE GEOTHERMAL / SPAN + TUNNELS';m.description='Two geothermal stations face across a cold ravine. A broad ground spillway, paired elevated bridge approaches, and insulated through-halls form three distinct crossings.';
  m.modeBindings={objectives:['ctf'],zones:['domination','koth','uplink','holdout'],assault:['assault'],combat:['deathmatch','teamdeathmatch','instagib','rockets'],'arms-race':['armsrace']};
  m.teamSpawns=pair([[-78,-12],[-78,12],[-82,-30],[-82,30]]);m.spawns=[...m.teamSpawns[0],...m.teamSpawns[1],[0,-45],[0,42]];
  m.flagSpawns={0:{x:-82,z:0},1:{x:82,z:0}};
  m.objectiveZones=[zone(-49,0,'WEST VENT'),zone(0,-35,'SPILLWAY'),zone(49,0,'EAST VENT')];
  m.routes=[];
  trace(m,route('spillway',10,[[-82,0],[-58,0],[-42,-35],[0,-35],[42,-35],[58,0],[82,0]]));
  trace(m,route('upper-span',7,[[-82,0],[-68,39],[-44,39],[-28,39],[0,39],[28,39],[44,39],[68,39],[82,0]]));
  trace(m,route('thermal-tunnel',6,[[-82,0],[-67,15],[-49,15],[-21,15],[0,15],[21,15],[49,15],[67,15],[82,0]]));
  for(const s of [-1,1]){
    hall(m,`turbine-${s}`,s*49,15,20,15,'ew',7);
    for(const x of [s*16,s*44,s*72]){
      solid(m,x,57,7,3,8,'abutment','basalt');piece(m,'cone',x,11,61,5,18,5,'snowcap');
    }
    for(const z of [-52,53])solid(m,s*55,z,8,3,4,'retaining','basalt');
  }
  // Six ramped plates (approach -> crown -> approach) comprise one solid bridge;
  // terrain triangles provide exactly the same walkable and ray support as art.
  const vertices=[],triangles=[];
  const xs=[-44,-28,28,44],height=x=>Math.max(0,Math.min(4,(44-Math.abs(x))/4));
  for(let i=0;i<xs.length-1;i++){
    const a=xs[i],b=xs[i+1],index=vertices.length;
    vertices.push([a,height(a),35],[a,height(a),43],[b,height(b),43],[b,height(b),35]);
    triangles.push([index,index+1,index+2],[index,index+2,index+3]);
    piece(m,'ramp', (a+b)/2,(height(a)+height(b))/2,39,b-a,Math.max(1,Math.abs(height(a)-height(b))),8,'iron',{y0:height(a),y1:height(b)});
  }
  // A complete ground support remains beneath the raised span; omitting it
  // would turn the rest of the map into a void for source floorAt/walkEdge.
  m.terrain={maxSlope:.8,base:0,amplitude:4,surfaces:[
    {id:'alpine-ground',material:'granite',walkable:true,
      vertices:[[-92,0,-68],[-92,0,68],[92,0,68],[92,0,-68]],triangles:[[0,1,2],[0,2,3]]},
    {id:'upper-bridge',material:'iron',walkable:true,vertices,triangles}],walls:[]};
  m.art.ground=[{x:0,z:0,w:184,d:136,material:'granite'},{x:0,z:-35,w:72,d:18,material:'spillway'}];
  frame(m);m.pickups=[['health',-75,22],['health',75,22],['armor',-44,-34],['armor',44,-34],['rail',0,39],['rocket',0,15]];
  return m;
}

function circuit(){
  const m=common('sirocco-circuit','Sirocco Circuit',{minX:-132,maxX:132,minZ:-103,maxZ:103},'day','#ae8964');
  m.tag='CANYON MOTORSPORT / SWITCHBACK';m.description='A broad canyon road course with an offset northern hairpin, long desert acceleration straight, elevated scenic flyover, and protected inside/outside walls.';
  m.modeBindings={sports:['puma-race']};m.routes=[];
  const line=[[-58,-66],[25,-66],[76,-57],[98,-35],[98,8],[72,35],[43,35],[17,67],[-29,67],[-61,49],[-95,52],[-106,24],[-97,-26],[-79,-58]].map(point);
  const tangent=line.map((a,i)=>{const b=line[(i+1)%line.length],l=Math.hypot(b.x-a.x,b.z-a.z);return{x:(b.x-a.x)/l,z:(b.z-a.z)/l};});
  const gates=line.map((p,i)=>{const a=tangent[(i+line.length-1)%line.length],b=tangent[i],l=Math.hypot(a.x+b.x,a.z+b.z);return{...p,nx:(a.x+b.x)/l,nz:(a.z+b.z)/l,halfWidth:15};});
  const offset=distance=>gates.map((p,i)=>{const t=tangent[i],k=distance/(p.nx*t.x+p.nz*t.z);return{x:p.x-p.nz*k,z:p.z+p.nx*k};});
  const boundary={outer:offset(-16),inner:offset(16)};
  const on=(i,t,lane=0)=>{const a=line[i],b=line[(i+1)%line.length],v=tangent[i];return{x:a.x+(b.x-a.x)*t-v.z*lane,z:a.z+(b.z-a.z)*t+v.x*lane};};
  for(const [side,poly] of Object.entries(boundary))for(let i=0;i<poly.length;i++){
    const a=poly[i],b=poly[(i+1)%poly.length],n=Math.ceil(Math.max(Math.abs(b.x-a.x),Math.abs(b.z-a.z))/2);
    for(let j=0;j<n;j++){const x=a.x+(b.x-a.x)*(j+.5)/n,z=a.z+(b.z-a.z)*(j+.5)/n;solid(m,x,z,Math.abs(b.x-a.x)/n+1.5,Math.abs(b.z-a.z)/n+1.5,2.6,'race-rail',side==='outer'?'ochre':'iron');}
  }
  const grid=Array.from({length:8},(_,i)=>({x:-58-7*Math.floor(i/2),z:-66+(i%2?4:-4),heading:Math.PI/2}));
  m.spawns=grid.map(p=>[p.x,p.z]);m.vehicles=grid.map((p,i)=>({id:`sirocco-${i}`,kind:'puma',x:p.x,z:p.z,y:0,yaw:p.heading}));
  for(let i=0;i<line.length;i++)trace(m,route(`sector-${i}`,12,[[line[i].x,line[i].z],[line[(i+1)%line.length].x,line[(i+1)%line.length].z]]));
  m.race={centerline:line,gates,grid,boundary,itemBoxes:[1,3,5,7,9,11,13].map((i,n)=>({id:`sirocco-box-${n}`,...on(i,.5)})),
    boostPads:[0,2,5,8,11].map((i,n)=>({id:`sirocco-pad-${n}`,...on(i,.3)})),coins:[0,2,4,6,8,10,12].flatMap(i=>[.35,.48,.61].map(t=>({id:`sirocco-coin-${i}-${t}`,...on(i,t,4)})))};
  // Scenic bridge runs ABOVE the road, has supports outside the 32-m ribbon.
  for(const z of [-25,25])solid(m,4,z,2,2,10,'bridge-pier','basalt');
  piece(m,'box',4,11,0,3,2,48,'iron');m.overhead=[{id:'spectator-overpass',x:4,z:0,w:3,d:48,minY:10,maxY:12}];
  for(const [x,z,w,d] of [[0,0,20,12],[-45,5,16,18],[48,-5,18,16]]){
    piece(m,'cone',x,7,z,w,14,d,'sandstone');
  }
  m.art.ground=[{x:0,z:0,w:264,d:206,material:'sandstone'}];m.pickups=[];
  return m;
}

function bowl(){
  const m=common('copper-bowl','Copper Bowl',{minX:-76,maxX:76,minZ:-58,maxZ:58},'dusk','#4e978c');
  m.tag='DESERT ARENA / PUMA SOCCER';m.description='A symmetrical walled copper pitch, recessed net pockets, corner turnouts and open midfield beneath curved spectator terraces.';
  m.modeBindings={sports:['puma-soccer']};m.routes=[];
  const pitch={minX:-47,maxX:47,minZ:-27,maxZ:27};const goals=[-1,1].map((s,team)=>({team,x:s*47,z:0,nx:s,nz:0,halfWidth:8,height:5,depth:5}));
  for(const s of [-1,1]){
    solid(m,0,s*27.6,96,1.2,3,'soccer-wall','copper');
    for(const end of [-1,1])solid(m,s*47.6,end*18,1.2,19,3,'soccer-wall','copper');
    solid(m,s*52,0,1,16,5,'soccer-goal','iron');
    for(const end of [-1,1])solid(m,s*49.5,end*8,5,1,5,'soccer-goal','iron');
    for(let tier=0;tier<4;tier++){
      const z=s*(34+tier*4);
      solid(m,0,z,106,4,2.5+tier*1.7,'terrace','sandstone');
    }
    for(const x of [-62,62]){solid(m,x,s*43,2,2,15,'light-mast','iron');piece(m,'box',x,15,s*43,8,1.2,2,'copper');}
  }
  const grid=[[-34,-10],[-34,10],[34,-10],[34,10]].map(([x,z])=>({x,z,heading:x<0?Math.PI/2:-Math.PI/2}));
  m.spawns=grid.map(p=>[p.x,p.z]);m.teamSpawns={0:m.spawns.slice(0,2),1:m.spawns.slice(2)};
  m.vehicles=grid.map((p,i)=>({id:`copper-${i}`,kind:'puma',x:p.x,z:p.z,y:0,yaw:p.heading}));
  m.race={kind:'soccer',pitch,goals,ball:{x:0,y:1.1,z:0,r:1.1},centerline:[[-44,-23],[44,-23],[44,23],[-44,23]].map(point),gates:[],grid,
    boundary:{outer:[[-74,-56],[74,-56],[74,56],[-74,56]].map(point),inner:[]}};
  for(let x=-43;x<=43;x+=4)for(let z=-23;z<=23;z+=4)m.navNodes.push({x,z});
  m.art.ground=[{x:0,z:0,w:152,d:116,material:'sandstone'},{x:0,z:0,w:94,d:54,material:'pitch'}];
  return m;
}

function archipelago(){
  const m=common('tern-archipelago','Tern Archipelago',{minX:-120,maxX:120,minZ:-80,maxZ:80},'day','#4e7986');
  m.tag='LATTICE / STRATEGIC ISLAND CHAIN';m.description='Two headquarters islands, a central relay island, northern refinery keys and southern repair yards joined by three legible embanked causeways.';
  m.modeBindings={lattice:['cocs','cocs-coop'],'lattice-world':['cocs','cocs-coop']};
  m.playBounds={...m.bounds,frontage:240,laneSep:52,maxNodeSpacing:80};
  m.nodes=[['hq-0',-104,0,'hq'],['hq-1',104,0,'hq'],['front-0',-54,-8,'front'],['front-1',54,8,'front'],['econ-n',-8,-31,'economy'],['econ-s',8,31,'economy'],['relay-0',0,0,'relay']].map(([id,x,z,archetype])=>({id,x,z,r:12,archetype,label:id.toUpperCase().replaceAll('-',' '),y:0}));
  m.lattice=[['hq-0','front-0'],['hq-1','front-1'],['front-0','relay-0'],['front-1','relay-0'],['front-0','econ-n'],['front-1','econ-n'],['relay-0','econ-n'],['front-0','econ-s'],['front-1','econ-s'],['relay-0','econ-s']];
  m.terminals=[{id:'tern-relay',nodeId:'relay-0',kind:'relay',x:0,z:0,y:0},{id:'tern-west-vault',nodeId:'hq-0',kind:'vault',x:-104,z:0,y:0},{id:'tern-east-vault',nodeId:'hq-1',kind:'vault',x:104,z:0,y:0}];
  m.teamSpawns=pair([[-112,0],[-108,0],[-104,0]]);m.spawns=[...m.teamSpawns[0],...m.teamSpawns[1],[-48,38],[48,-38]];
  m.flagSpawns={0:{x:-110,z:0},1:{x:110,z:0}};
  const road=[[-112,-55],[-78,-55],[-64,-55],[-40,-55],[0,-55],[40,-55],[64,-55],[78,-55],[112,-55]];
  const spine=[[-112,0],[-96,0],[-72,-8],[-54,-8],[-31,-8],[0,0],[31,8],[54,8],[72,8],[96,0],[112,0]];
  const flank=[[-112,47],[-76,47],[-42,47],[0,47],[42,47],[76,47],[112,47]];
  m.lanes=[['causeway-road','vehicle-road',road,12],['island-spine','cqc',spine,8],['shoal-walk','zipline-flank',flank,7]].map(([id,kind,waypoints,width])=>({id,kind,identity:kind,waypoints,width,slopeCap:.3,vehicles:kind==='vehicle-road',bypassFraction:.5,chokepoints:2,landmark:id,traversal:{kind}}));
  m.depots=[['tern-west',-104,-55,0],['tern-east',104,-55,1],['tern-mid-west',-64,-55,null],['tern-mid-east',64,-55,null]].map(([id,x,z,team])=>({id,x,z,y:0,lane:'causeway-road',team,hq:team!==null,exits:2,vehicle:'puma',nodeDistanceMeters:Math.min(...m.nodes.map(n=>Math.hypot(n.x-x,n.z-z))),chokepointDistanceMeters:20}));
  m.vehicles=[vehicle('tern-puma-west',-104,-55,0),vehicle('tern-puma-east',104,-55,1)];
  m.objectiveZones=m.nodes.filter(n=>n.archetype!=='hq').map(n=>zone(n.x,n.z,n.id));
  m.routes=[];trace(m,route('causeway-road',12,road));trace(m,route('island-spine',8,spine));trace(m,route('shoal-walk',7,flank));
  for(const n of m.nodes){
    // Open-roof bastions: every command socket has four separate open entrances.
    const w=n.archetype==='hq'?23:18,d=n.archetype==='relay'?22:18;
    for(const s of [-1,1])for(const e of [-1,1]){
      solid(m,n.x+s*w/2,n.z+e*(d+8)/4,1,(d-8)/2,5,'bastion','limestone');
      solid(m,n.x+e*(w+8)/4,n.z+s*d/2,(w-8)/2,1,5,'bastion','limestone');
    }
  }
  m.art.ground=[{x:0,z:0,w:240,d:160,material:'island-ground'},...[-55,0,47].map(z=>({x:0,z,w:240,d:z===0?28:16,material:'causeway'}))];
  // Shallow low-tide flats are walkable at the source ground height. The three
  // dry causeways remain legible; no separate unmodelled swim collider exists.
  for(const z of [-32,24,66])piece(m,'box',0,.02,z,240,.02,13,'water');
  for(const x of [-92,-68,-28,28,68,92])for(const z of [-74,69]){solid(m,x,z,4,5,3,'rock','limestone');}
  frame(m);m.pickups=[['health',-92,20],['health',92,-20],['armor',-60,36],['armor',60,-36],['rocket',0,-55],['rail',0,47]];
  for(let x=-115;x<=115;x+=5)for(let z=-74;z<=74;z+=5){if(!m.blocks.some(b=>Math.abs(x-b.x)<b.w/2+1&&Math.abs(z-b.z)<b.d/2+1))m.navNodes.push({x,z});}
  for(const p of [...m.nodes,...m.depots,...m.terminals])m.navNodes.push({x:p.x,z:p.z});
  return m;
}

export const WORLD_RECIPES=[breakwater(),thermal(),circuit(),bowl(),archipelago()];
export const WORLD_IDS=WORLD_RECIPES.map(m=>m.id);
for(const map of WORLD_RECIPES){
  const errors=validateMapSchema(map);
  if(errors.length)throw Error(`${map.id}: ${errors.join('; ')}`);
}

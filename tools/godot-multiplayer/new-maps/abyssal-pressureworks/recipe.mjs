// Port-owned architecture; metres, source Y-up. No source registry mutation.
export const ID='abyssal-pressureworks';
export function recipe(){
 const m={id:ID,name:'Abyssal Pressureworks',tag:'BATHYAL RESEARCH / PRESSURE HABITAT',description:'Dry terraced pressure vessels embedded in an ocean escarpment.',bounds:{minX:-120,maxX:120,minZ:-110,maxZ:110},voidY:-24,sky:'night',background:'#081b30',floorColor:'#253849',color:'#dfb994',nextGen:true,raised:false,scatter:false,blocks:[],structures:[],props:[],spawns:[],pickups:[],navNodes:[],objectiveZones:[],routes:[],overhead:[],terrain:{base:0,amplitude:20,maxSlope:.8,surfaces:[],walls:[]},art:{ground:[],pieces:[],palette:{navy:'#142c43',coral:'#ac655c',ivory:'#cdd6c8',copper:'#9d7051',cyan:'#57c4cf',amber:'#dca45e',glass:'#286b83'},windows:[],reefs:[]},modeBindings:{combat:['deathmatch','teamdeathmatch'],objectives:['ctf'],zones:['koth','domination','holdout']}};
 const p=(x,y,z)=>[x,y,z],lerp=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
 const surface=(id,vertices,material,walkable=false)=>m.terrain.surfaces.push({id,material,walkable,vertices,triangles:Array.from({length:vertices.length-2},(_,i)=>[0,i+1,i+2])});
 const wall=(id,a,b,c,d,material='navy')=>{for(const [i,vertices] of [[0,[a,b,c]],[1,[a,c,d]]])m.terrain.walls.push({id:`${id}-${i}`,material,vertices});};
 const panel=(id,a,b,base,top,material='navy')=>wall(id,p(a[0],base,a[1]),p(b[0],base,b[1]),p(b[0],top,b[1]),p(a[0],top,a[1]),material);
 const solid=(id,x,y,z,w,h,d,material)=>{m.blocks.push({id,x,z,w,d,baseY:y,h:y+h,kind:'equipment'});m.art.pieces.push({id,kind:'box',x,y:y+h/2,z,w,h,d,material});};
 const trace=(id,width,points)=>{m.routes.push({id,width,points});for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);for(let j=0;j<=n;j++)m.navNodes.push({x:a[0]+(b[0]-a[0])*j/n,z:a[1]+(b[1]-a[1])*j/n});}};
 const rooms=[];
 const names=[['Intake quarantine','Spectrometry','Reef observation','Sample archive'],['Freight lock','Pump cathedral','Equalizer atrium','Distribution hall'],['Residential commons','Medical operations','Mission control','Emergency refuge']];
 const xs=[[-94,-34,31,91],[-91,-32,34,94],[-98,-39,26,87]];
 for(let row=0;row<3;row++)for(let col=0;col<4;col++){
  const x=xs[row][col],z=[[-68,-78,-68,-58],[0,0,0,0],[68,78,64,72]][row][col],y=row===0?6-col*2:row*10,w=[40,44,38][row],d=[40,44,36][row],h=row===1&&col===2?24:[10,15,9][row],id=`vessel-${row}-${col}`,gap=row===1?14:10,c=7;
  const r={id,name:names[row][col],district:['terraced-laboratories','pump-energy','residential-operations'][row],x,y,z,w,d,h,ports:{},silhouette:['splayed-observation-vault','tall-ribbed-pressure-vessel','low-faceted-habitat'][row]};rooms.push(r);
  const poly=[[-w/2+c,-d/2],[w/2-c,-d/2],[w/2,-d/2+c],[w/2,d/2-c],[w/2-c,d/2],[-w/2+c,d/2],[-w/2,d/2-c],[-w/2,-d/2+c]].map(([a,b])=>[x+a,z+b]);
  surface(`${id}-deck`,poly.map(([a,b])=>p(a,y,b)).reverse(),'ivory',true);
  // Eight sloped roof facets terminate at a small crown, with an exact closed underside.
  const crown=poly.map(([a,b])=>[x+(a-x)*[.8,.58,.35][row],z+(b-z)*[.8,.58,.35][row]]),rise=[3,5,1.5][row];
  surface(`${id}-crown`,crown.map(([a,b])=>p(a,y+h+rise,b)),'navy');
  for(let i=0;i<8;i++){
   const a=poly[i],b=poly[(i+1)%8],side=({0:'n',2:'e',4:'s',6:'w'})[i];
   surface(`${id}-roof-facet-${i}`,[p(a[0],y+h,a[1]),p(b[0],y+h,b[1]),p(crown[(i+1)%8][0],y+h+rise,crown[(i+1)%8][1]),p(crown[i][0],y+h+rise,crown[i][1])],'navy');
   const open=side&&((side==='n'&&row>0)||(side==='s'&&row<2)||(side==='w'&&col>0)||(side==='e'&&col<3));
   if(open){
    const len=Math.hypot(b[0]-a[0],b[1]-a[1]),t=(len-gap)/2/len,A=lerp(a,b,t),B=lerp(a,b,1-t);
    panel(`${id}-${side}-jamb-a`,a,A,y,y+h,'ivory');panel(`${id}-${side}-jamb-b`,B,b,y,y+h,'ivory');panel(`${id}-${side}-lintel`,A,B,y+7,y+h,'coral');
    r.ports[side]={a:A,b:B,center:lerp(A,B,.5),y,width:gap};
    // Thick segmented seals recede into the chamber; side stiles are solids.
    for(const end of [A,B])solid(`${id}-${side}-seal-${end===A?'a':'b'}`,end[0],y,end[1],1,7,1,'copper');
   }else if(row===0&&i===0){
    panel(`${id}-window-sill`,a,b,y,y+1.2,'coral');panel(`${id}-window-header`,a,b,y+6.5,y+h,'ivory');
    m.art.windows.push({id:`${id}-observation-glazing`,vertices:[p(a[0],y+1.2,a[1]),p(b[0],y+1.2,b[1]),p(b[0],y+6.5,b[1]),p(a[0],y+6.5,a[1])],transparent:true,blocksShots:false,blocksActors:false});
    // Outside support is void: glass is intentionally not a source shot blocker.
   }else panel(`${id}-shell-${i}`,a,b,y,y+h,i%2?'coral':'navy');
  }
  // Purposeful side bays leave the central axes and all portals clear.
  for(const sign of [-1,1]){
   solid(`${id}-workstation-${sign}`,x+sign*10,y,z-10,5,1.5,3,row===0?'ivory':'coral');
   solid(`${id}-equipment-${sign}`,x+sign*11,y,z+10,4,row===1?4:2.4,3,'navy');
   m.art.pieces.push({id:`${id}-instrument-${sign}`,kind:'box',x:x+sign*10,y:y+1.58,z:z-10,w:3,h:.12,d:1.7,material:'cyan'});
  }
  // Structural ribs are visible exact solids, deliberately outside traffic.
  for(const sign of [-1,1])solid(`${id}-rib-${sign}`,x+sign*(w/2-1),y,z+9,1,h,2,'ivory');
  if(row===1&&col===2){solid('pressure-equalizer-core',x+10,y,z+8,6,20,6,'copper');solid('core-pressure-cap',x+10,y+20,z+8,8,2,8,'amber');}
  m.structures.push(r);
  m.spawns.push([x,z]);
 }
 const connect=(a,sa,b,sb,id,width)=>{
  const A=a.ports[sa],B=b.ports[sb];
  // Opposite polygon windings yield matching corridor edges after reversal.
  const va=p(A.a[0],a.y,A.a[1]),vb=p(A.b[0],a.y,A.b[1]),vc=p(B.a[0],b.y,B.a[1]),vd=p(B.b[0],b.y,B.b[1]);
  surface(`${id}-ramp`,[va,vb,vc,vd],'ivory',true);
  const up=v=>[v[0],v[1]+7,v[2]];
  surface(`${id}-ceiling`,[up(vd),up(vc),up(vb),up(va)],'navy');
  wall(`${id}-side-a`,vb,vc,up(vc),up(vb),'coral');wall(`${id}-side-b`,vd,va,up(va),up(vd),'coral');
  m.structures.push({id,type:'angled-gallery',district:a.district,from:a.id,to:b.id,width,height:7});
  trace(id,width,[[a.x,a.z],A.center,B.center,[b.x,b.z]]);
 };
 for(let row=0;row<3;row++)for(let col=0;col<3;col++)connect(rooms[row*4+col],'e',rooms[row*4+col+1],'w',`${['low-maintenance-bypass','broad-pump-spine','operations-gallery'][row]}-${col}`,row===1?14:10);
 for(let row=0;row<2;row++)for(let col=0;col<4;col++)connect(rooms[row*4+col],'s',rooms[(row+1)*4+col],'n',`crosslink-${row}-${col}`,10);
 m.teamSpawns={0:[4,0,8].map(i=>[rooms[i].x,rooms[i].z]),1:[7,3,11].map(i=>[rooms[i].x,rooms[i].z])};m.flagSpawns={0:{x:-91,z:0},1:{x:94,z:0}};
 m.objectiveZones=[['reef',1,'REEF LAB'],['equalizer',6,'EQUALIZER'],['operations',10,'OPERATIONS']].map(([id,i,label])=>({id,x:rooms[i].x,y:rooms[i].y,z:rooms[i].z,radius:7,label}));
 m.pickups=[['health',1],['armor',10],['rocket',5],['rail',2],['health',11],['armor',0]].map(([kind,i])=>[kind,rooms[i].x,rooms[i].z]);
 for(let i=0;i<9;i++)m.art.reefs.push({x:-110+i*27,y:-12-i%3*3,z:-102-i%2*6,radius:5+i%3,height:14+i%4*3});
 m.design={walkableRelief:20,primaryRoutes:3,crosslinks:8,windowPolicy:'Transparent observation glazing is nonblocking for source shots and native physics; exterior has no walkable support.',budgets:{materials:7,triangles:100000,drawCalls:48},physics:'Dry habitat; ordinary source movement and gravity.'};
 return m;
}

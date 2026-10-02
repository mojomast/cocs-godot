// Source metres, Y up. Standalone: never imports or regenerates older recipes.
export const ID = 'stormglass-causeway';
const line = [[-130,-130],[-50,-130],[30,-115],[100,-80],[145,-25],[155,40],
  [130,85],[80,105],[45,145],[0,150],[-35,120],[-70,140],[-115,105],
  [-155,115],[-195,80],[-205,30],[-165,5],[-110,15],[-65,-15],[-90,-70],[-145,-85]];
const unit = (x,z) => {const d=Math.hypot(x,z);return {x:x/d,z:z/d};};
export function makeStormglass() {
  const m={id:ID,name:'Stormglass Causeway',bounds:{minX:-275,maxX:245,minZ:-210,maxZ:225},
    sky:'dusk',background:'#263f50',floorColor:'#435761',color:'#8db8c5',raised:false,scatter:false,nextGen:true,
    tag:'STORM BARRIER CITY / COASTAL GRAND PRIX',description:'Open seawall, arched freight bore, stepped quay chicanes and surge-gate return.',
    modeBindings:{},candidateModes:['puma-race'],blocks:[],spawns:[],pickups:[],navNodes:[],structures:[],routes:[],
    terrain:{maxSlope:.8,base:0,amplitude:0,surfaces:[],walls:[]},
    art:{palette:'stormglass',ground:[],pieces:[],meshes:[],labels:[]},
    districts:[{id:'weather-terminal',label:'Glazed Weather Terminal',sectors:[0,1,2,3,19,20]},
      {id:'freight-bore',label:'Arched Freight Bore',sectors:[4,5,6]},
      {id:'stepped-quay',label:'Stepped Quay / Surgeworks',sectors:[7,8,9,10,11,12,13,14,15,16,17,18]}]};
  const mesh=(id,vertices,triangles,material,collision='none')=>{
    m.art.meshes.push({id,vertices,triangles,material,collision});
    if(collision==='floor'||collision==='ceiling')m.terrain.surfaces.push({id,vertices,triangles,material,walkable:collision==='floor'});
    if(collision==='wall')for(const t of triangles)m.terrain.walls.push({id,vertices:t.map(i=>vertices[i]),material});
  };
  const quad=(id,v,material,collision='none')=>mesh(id,v,[[0,1,2],[0,2,3]],material,collision);
  const box=(id,c,w,h,d,material,heading=0,physical=false)=>{
    const sn=Math.sin(heading),cs=Math.cos(heading);
    const v=[[-1,-1,-1],[1,-1,-1],[1,-1,1],[-1,-1,1],[-1,1,-1],[1,1,-1],[1,1,1],[-1,1,1]].map(([x,y,z])=>[c.x+x*w/2*cs+z*d/2*sn,c.y+y*h/2,c.z-x*w/2*sn+z*d/2*cs]);
    for(const [i,f] of [[0,[0,3,2,1]],[1,[4,5,6,7]],[2,[0,1,5,4]],[3,[1,2,6,5]],[4,[2,3,7,6]],[5,[3,0,4,7]]])quad(`${id}-${i}`,f.map(j=>v[j]),material,physical?(i<2?'ceiling':'wall'):'none');
  };
  const centerline=line.map(([x,z])=>({x,z}));
  const tangents=centerline.map((a,i)=>{const b=centerline[(i+1)%line.length];return unit(b.x-a.x,b.z-a.z);});
  const gates=centerline.map((p,i)=>{const a=tangents[(i+line.length-1)%line.length],b=tangents[i],n=unit(a.x+b.x,a.z+b.z);return {...p,nx:n.x,nz:n.z,halfWidth:13.9};});
  const offset=d=>gates.map((p,i)=>{const t=tangents[i],k=d/(p.nx*t.x+p.nz*t.z);return {x:p.x-p.nz*k,z:p.z+p.nx*k};});
  const outer=offset(-14),inner=offset(14);
  const at=(i,t,lateral=0,y=0)=>{const a=centerline[i],b=centerline[(i+1)%line.length],u=tangents[i];return {x:a.x+(b.x-a.x)*t-u.z*lateral,y,z:a.z+(b.z-a.z)*t+u.x*lateral};};
  const xyz=(p,y=0)=>[p.x,y,p.z];
  const clearBuilding=(p,w,d,heading)=>{
    for(let x=-w/2;x<=w/2;x+=w/4)for(let z=-d/2;z<=d/2;z+=d/4){
      const q={x:p.x+x*Math.cos(heading)+z*Math.sin(heading),z:p.z-x*Math.sin(heading)+z*Math.cos(heading)};
      for(let i=0;i<line.length;i++){
        const a=centerline[i],b=centerline[(i+1)%line.length],dx=b.x-a.x,dz=b.z-a.z,t=Math.max(0,Math.min(1,((q.x-a.x)*dx+(q.z-a.z)*dz)/(dx*dx+dz*dz)));
        if(Math.hypot(q.x-a.x-dx*t,q.z-a.z-dz*t)<17)return false;
      }
    }
    return true;
  };
  for(let i=0;i<line.length;i++){
    const j=(i+1)%line.length,a=centerline[i],b=centerline[j],len=Math.hypot(b.x-a.x,b.z-a.z),heading=Math.atan2(tangents[i].x,tangents[i].z);
    quad(`road-${i}`,[xyz(outer[i]),xyz(inner[i]),xyz(inner[j]),xyz(outer[j])],'asphalt','floor');
    for(const [side,edge] of [['sea',outer],['city',inner]]){
      quad(`barrier-${side}-${i}`,[xyz(edge[i]),xyz(edge[j]),xyz(edge[j],2.8),xyz(edge[i],2.8)],'concrete','wall');
      for(let k=0;k<Math.ceil(len/5);k++){
        const t=(k+.5)/Math.ceil(len/5),p={x:edge[i].x+(edge[j].x-edge[i].x)*t,y:2.9,z:edge[i].z+(edge[j].z-edge[i].z)*t};
        box(`reflector-${side}-${i}-${k}`,p,.35,.2,1.5,k%2?'amber':'salt',heading);
      }
    }
    // Source and art share both mitred road edges; no broad ground fills the infield.
    for(const side of [-1,1])for(let k=0;k<Math.ceil(len/8);k++)box(`shoulder-${i}-${side}-${k}`,at(i,(k+.5)/Math.ceil(len/8),side*11.5,.015),.22,.02,4,'salt',heading);
    m.routes.push({id:`sector-${i}`,width:28,points:[[a.x,a.z],[b.x,b.z]]});
    for(let k=0;k<Math.ceil(len/6);k++){const p=at(i,k/Math.ceil(len/6));m.navNodes.push({x:p.x,z:p.z});}
    m.art.labels.push({text:i===0?'START / FINISH':`${String(i+1).padStart(2,'0')}  >`,...at(i,.8,-13,4),heading});
    // Dense street-edge modules: unequal terminal bays, quay workshops and service courts.
    if(![4,5,6,15,16].includes(i))for(let k=0;k<3;k++){
      const t=(k+.5)/3,side=i<4||i>18?1:-1,h=i<4||i>18?16+(k%2)*6:8+(i%3)*3;
      const p=at(i,t,side*25,h/2),id=`district-${i}-${k}`;
      if(!clearBuilding(p,15,len/3-2,heading))continue;
      box(`${id}-body`,p,14,h,len/3-3,i<4||i>18?'teal':'brick',heading,true);
      box(`${id}-cornice`,{...p,y:h},15,.65,len/3-2,'salt',heading);
      for(let story=0;story<Math.floor(h/4);story++)for(let bay=0;bay<3;bay++){
        const q=at(i,t+(bay-1)*3/len,side*17.9,2+story*4);
        box(`${id}-glass-${story}-${bay}`,q,.15,2,2,'glass',heading);
        box(`${id}-sill-${story}-${bay}`,{...q,y:q.y-1.2},.65,.3,2.6,'salt',heading);
      }
      for(const delta of [-.13,.13])box(`${id}-pier-${delta}`,at(i,t+delta,side*17.6,h/2),.8,h,.8,'concrete',heading);
      box(`${id}-roof-machinery`,{...p,y:h+1.7},5,3,5,'steel',heading);
      m.structures.push({id,type:i<4||i>18?'observatory-terminal':'quay-workshop',height:h});
    }
  }
  // Continuous enclosed, curved, faceted barrel vault. Lowest overhead is 7 m.
  for(const i of [4,5,6]){
    const j=i+1;
    for(let arch=0;arch<10;arch++){
      const point=(index,n)=>{const theta=Math.PI*n/10,p=outer[index],q=inner[index],t=(1-Math.cos(theta))/2;return [p.x+(q.x-p.x)*t,7+9*Math.sin(theta),p.z+(q.z-p.z)*t];};
      quad(`freight-vault-${i}-${arch}`,[point(i,arch),point(j,arch),point(j,arch+1),point(i,arch+1)],arch%2?'concrete':'steel','ceiling');
    }
    for(const edge of [outer,inner])quad(`bore-side-${i}-${edge===outer?'out':'in'}`,[xyz(edge[i],2.8),xyz(edge[j],2.8),xyz(edge[j],7),xyz(edge[i],7)],'brick','wall');
    const heading=Math.atan2(tangents[i].x,tangents[i].z);
    for(const t of [.08,.35,.65,.92])for(const side of [-1,1])box(`vault-rib-${i}-${t}-${side}`,at(i,t,side*13.7,4.8),.45,4,.6,'steel',heading);
  }
  // Monumental angled surge gates: visible road openings stay 28 m wide / 9 m high.
  for(const i of [1,14,18]){
    const heading=Math.atan2(tangents[i].x,tangents[i].z);
    for(const side of [-1,1]){
      box(`gate-${i}-buttress-${side}`,at(i,.5,side*20,12),8,24,10,'concrete',heading+.18*side,true);
      box(`gate-${i}-piston-${side}`,at(i,.5,side*17,16),2,13,3,'steel',heading);
      box(`gate-${i}-counterweight-${side}`,at(i,.5,side*23,17),5,9,7,'amber',heading);
    }
    box(`gate-${i}-raised-leaf`,at(i,.5,0,12),32,6,3,'teal',heading,true);
    box(`gate-${i}-gantry`,at(i,.5,0,23),47,2,5,'steel',heading,true);
  }
  // Bounded cosmetic ocean lies outside the supported ribbon; source floor is null.
  quad('ocean',[[-275,-4,-210],[245,-4,-210],[245,-4,225],[-275,-4,225]],'ocean');
  const grid=Array.from({length:8},(_,i)=>({x:-136-6*Math.floor(i/2),z:-130+(i%2?4:-4),heading:Math.PI/2}));
  // Grid extends backwards along the closing bend; use the actual closing sector instead.
  for(let i=0;i<8;i++){const p=at(20,.88-.09*Math.floor(i/2),i%2?4:-4);grid[i]={x:p.x,z:p.z,heading:Math.atan2(tangents[20].x,tangents[20].z)};}
  m.spawns=grid.map(p=>[p.x,p.z]);
  m.race={centerline,gates,grid,boundary:{outer,inner},itemBoxes:[],coins:[],boostPads:[]};
  m.metrics={length:centerline.reduce((sum,p,i)=>sum+Math.hypot(p.x-centerline[(i+1)%line.length].x,p.z-centerline[(i+1)%line.length].z),0),corners:line.length,roadWidth:28,roadRelief:0,architectureRelief:24};
  return m;
}

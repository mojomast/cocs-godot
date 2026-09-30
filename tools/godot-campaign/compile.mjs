import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {nativeArenaGeometryHash} from '../../port/native-arenas/schema.mjs';
import {CAMPAIGN_MAP_IDS, parseCampaignMap} from '../../port/native-campaign/maps.mjs';

export const CELL = 4;
const round = n => +n.toFixed(5);
const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const smooth = v => {v=clamp(v,0,1);return v*v*(3-2*v);};
const blendKnots=(t,values)=>{const u=clamp(t,0,1)*(values.length-1),i=Math.min(values.length-2,Math.floor(u));return values[i]+(values[i+1]-values[i])*smooth(u-i);};
const mound=(x,z,cx,cz,rx,rz,angle=0)=>{const dx=x-cx,dz=z-cz,u=(dx*Math.cos(angle)+dz*Math.sin(angle))/rx,v=(-dx*Math.sin(angle)+dz*Math.cos(angle))/rz;return Math.exp(-(u*u+v*v)*1.8);};
const chapters = [
  {name:'Rootfall Verge',w:320,h:224,base:4,rise:14,palette:['536b45','9caa72','778a80','c0bda0','476775','85f3cf'],landmarks:['Fallen relay','Root archive','Fern sluice','Ravine transformer','Siltwake gate']},
  {name:'Siltwake Crossing',w:352,h:256,base:18,rise:18,palette:['b4875d','cfad79','815e49','bab4a0','526c77','85f3cf'],landmarks:['Rootfall gate','Riverworks intake','Bridge relays','Dry spillway','Emberline lift']},
  {name:'Emberline Ascent',w:384,h:256,base:36,rise:26,palette:['4b5158','747775','373e49','ac9d85','6a7d87','85f3cf'],landmarks:['Siltwake lift','Cooling terraces','Basalt switchyard','Uplink isolator','Crown pass']},
  {name:'Crown Array',w:416,h:288,base:62,rise:10,palette:['536b54','9aaa7b','525d67','d1cabb','607889','85f3cf'],landmarks:['Emberline pass','Archive gardens','Crown capacitors','Signal cloister','Guardian court']},
];

function distance(p,a,b) {
  const dx=b[0]-a[0], dz=b[1]-a[1],t=clamp(((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz),0,1);
  return {d:Math.hypot(p[0]-a[0]-dx*t,p[1]-a[1]-dz*t),t};
}
export function routeLength(points) {return points.slice(1).reduce((n,p,i)=>n+Math.hypot(p.x-points[i].x,p.y-points[i].y,p.z-points[i].z),0);}

export function compileCampaign(id) {
  const index=CAMPAIGN_MAP_IDS.indexOf(id);if(index<0)throw Error('Unknown campaign map');
  const c=chapters[index];
  // Deliberately independent footprints, not four rescaled row mazes. These
  // are the inhabited power corridor: geology is carved around their shapes.
  const layouts=[
    [[-140,-84],[-84,-88],[-20,-52],[52,-84],[128,-56],[124,8],[60,24],[4,-4],[-60,12],[-128,-8],[-132,56],[-76,88],[-12,60],[56,88],[132,72],[136,32]],
    [[-152,-104],[-80,-108],[-56,-72],[-116,-28],[-144,36],[-96,96],[-24,92],[28,64],[112,104],[148,44],[100,8],[60,16],[56,-20],[64,-64],[144,-76],[140,-108],[40,-108],[-8,-64],[-20,-8],[-64,32]],
    [[-164,100],[-164,28],[-104,28],[-104,-36],[-160,-36],[-160,-100],[-68,-104],[-28,-64],[44,-96],[140,-96],[164,-36],[88,-36],[48,12],[124,32],[156,100],[64,100],[24,60],[-44,88],[-68,40],[-16,8],[20,-24]],
    [[-180,104],[-184,16],[-156,-84],[-76,-112],[36,-112],[148,-80],[180,16],[148,104],[52,112],[-48,96],[-116,56],[-116,-16],[-76,-56],[16,-64],[92,-32],[104,28],[56,64],[-4,44],[-32,4],[0,-12],[28,4]].map(p=>p.map(n=>n*.86)),
  ];
  const corners=layouts[index];
  const segments=[];let length=0;
  for(let i=1;i<corners.length;i++) {const a=corners[i-1],b=corners[i],len=Math.hypot(b[0]-a[0],b[1]-a[1]);segments.push({a,b,len,start:length});length+=len;}
  const nearest=(x,z)=>{
    let best={d:Infinity,s:0,i:0};for(const [i,seg]of segments.entries()) {const hit=distance([x,z],seg.a,seg.b);if(hit.d<best.d)best={d:hit.d,s:seg.start+hit.t*seg.len,i};}return best;
  };
  const at=s=>{const seg=segments.find(v=>v.start+v.len>=s)??segments.at(-1),t=clamp((s-seg.start)/seg.len,0,1);return [seg.a[0]+(seg.b[0]-seg.a[0])*t,seg.a[1]+(seg.b[1]-seg.a[1])*t];};
  const siteSegments=[[1,4,7,10,13],[2,4,8,13,17],[1,6,10,14,17],[2,5,9,13,18]][index];
  const sites=siteSegments.map(i=>at(segments[i].start+segments[i].len*.5));
  const frames=siteSegments.map(i=>{const s=segments[i];return {dx:(s.b[0]-s.a[0])/s.len,dz:(s.b[1]-s.a[1])/s.len};});
  const local=(i,u,v)=>{const [x,z]=sites[i],{dx,dz}=frames[i];return [x+u*dx-v*dz,z+u*dz+v*dx];};
  const width=s=>index===0?10+2.5*Math.sin(s*.031)**2:index===1?9+2*Math.sin(s*.017)**2:index===2?10:10+1.5*Math.sin(s*.019)**2;
  const floor=s=>{
    const t=s/length;
    if(index===2){const terrace=t*5;return c.base+c.rise*(Math.floor(terrace)+smooth((terrace%1-.5)/.35))/5+1.2*Math.sin(s*.025)*Math.sin(Math.PI*t);}
    const roll=index===0?3.4*Math.sin(t*Math.PI*6):index===1?3*Math.sin(t*Math.PI*4.4):5.5*Math.sin(t*Math.PI*3);
    return c.base+c.rise*t+roll*Math.sin(Math.PI*t);
  };
  // Broad, non-periodic geological control fields. The route floor remains
  // authoritative, but the upland no longer inherits discontinuous nearest-
  // segment elevations. Named masses are 35–100m across, not vertex noise.
  const landforms=[
    [[-91,-38,67,42,15,.3],[35,-29,62,34,23,-.25],[-44,47,58,36,10,-.5],[112,39,42,54,19,.15]],
    [[-93,8,54,76,21,-.4],[96,45,72,43,31,.25],[-10,-98,84,31,16,-.1],[35,-30,35,52,24,.55]],
    [[-115,-63,58,43,20,0],[23,-10,81,47,32,.55],[121,58,51,53,18,-.3],[-67,97,72,35,12,0]],
    [[-132,13,66,92,13,-.15],[42,-81,95,39,22,.2],[115,71,64,57,11,-.3],[-2,20,41,35,17,.25]],
  ][index];
  const crestKnots=[[15,22,12,29,18,11,25,17],[23,34,17,28,39,20,31],[26,17,35,22,31,18,28],[15,24,12,20,30,16,23]][index];
  const runKnots=[[24,34,22,29,38,23,32],[29,38,25,43,28,36,24],[22,31,20,35,24,30,21],[29,39,24,35,28,42,26]][index];
  const buttresses=index===0?[4,9,10,12].map((i,j)=>{
    const before=segments[i-1],after=segments[i],dx=(after.b[0]-after.a[0])/after.len-(before.b[0]-before.a[0])/before.len,dz=(after.b[1]-after.a[1])/after.len-(before.b[1]-before.a[1])/before.len,n=Math.hypot(dx,dz);
    return [corners[i][0]+dx/n*18,corners[i][1]+dz/n*18,[17,23,15,21][j],[23,16,25,18][j],[16,21,14,19][j],Math.atan2(dz,dx)];
  }):[];
  const geology=(x,z,hit,edge)=>{
    if(edge<=0)return floor(hit.s);
    let weighted=0,weightedCrest=0,weight=0,other=Infinity;
    for(const [i,seg]of segments.entries()){
      const q=distance([x,z],seg.a,seg.b),w=1/(q.d*q.d+64)**2;
      weighted+=floor(seg.start+q.t*seg.len)*w;weightedCrest+=blendKnots((seg.start+q.t*seg.len)/length,crestKnots)*w;weight+=w;
      if(Math.abs(i-hit.i)>1)other=Math.min(other,q.d);
    }
    const ground=floor(hit.s)*(1-smooth(edge/14))+(weighted/weight)*smooth(edge/14);
    const mass=landforms.reduce((sum,[cx,cz,rx,rz,height,angle])=>{
      const dx=x-cx,dz=z-cz,u=(dx*Math.cos(angle)+dz*Math.sin(angle))/rx,v=(-dx*Math.sin(angle)+dz*Math.cos(angle))/rz;
      const shape=index===2?1-smooth((Math.max(Math.abs(u),Math.abs(v))-.48)/.65):index===1?1-smooth((Math.hypot(u,v)-.38)/.75):Math.exp(-(u*u+v*v)*1.8);
      return sum+height*shape;
    },0);
    const crest=weightedCrest/weight;
    const upland=Math.max(ground+crest,c.base+c.rise*.5+12+mass);
    // Keep a cliff divide where two non-neighbouring route legs converge, but
    // open outward-facing shoulders into wide scree fans and weathered slopes.
    const crowded=1-smooth((other-hit.d-7)/20);
    const run=blendKnots(hit.s/length,runKnots)*(1-crowded)+14*crowded;
    const u=edge/run;
    let profile;
    if(index===0)profile=.12*smooth(edge/4)+.18*smooth(u/.6)+.70*smooth((u-.35)/.65);
    else if(index===1)profile=.20*smooth(u/.25)+.43*smooth((u-.37)/.20)+.37*smooth((u-.78)/.22);
    else if(index===2)profile=.14*smooth(edge/4)+.10*smooth(u/.32)+.76*smooth((u-.48)/.52);
    else profile=.30*smooth(u/.62)+.70*smooth((u-.35)/.65);
    // Sparse large spurs, recesses and saddles are described by the landforms;
    // there is intentionally no short-period sinusoid or modulo cliff height.
    return ground+(upland-ground)*profile;
  };
  const authoredHeight=(x,z)=>{
    const hit=nearest(x,z), clearing=Math.min(...sites.map(p=>Math.hypot(x-p[0],z-p[1])));
    const edge=Math.min(hit.d-width(hit.s),clearing-25);
    const detail=.3*Math.sin(x*.065)*Math.cos(z*.08)*Math.sin(Math.PI*hit.s/length)*(1-smooth(edge/16));
    let y=geology(x,z,hit,edge)+detail;
    // Four unequal weathered island noses hold Rootfall's required ravine
    // bends while the intervening shoulders can open into broad gentle fans.
    // This avoids restoring a uniformly steep trench wall along the whole map.
    for(const [cx,cz,rx,rz,height,angle]of buttresses)y+=height*mound(x,z,cx,cz,rx,rz,angle)*smooth(edge/5);
    // Local combat floors are coherent planes, including their full flank
    // circuits. Finer tessellation must not reveal a nearest-segment height
    // discontinuity where a loop approaches a bend in a terraced road.
    for(let i=0;i<sites.length;i++){
      const [sx,sz]=sites[i],d=Math.hypot(x-sx,z-sz);if(d>=30)continue;
      const seg=segments[siteSegments[i]],plane=floor(seg.start+seg.len*.5)+((x-sx)*frames[i].dx+(z-sz)*frames[i].dz)*.02+detail;
      const blend=smooth((d-23)/7);y=plane*(1-blend)+y*blend;
    }
    // The river drops below its bank roads. At the two actual crossings the
    // single support sheet narrows into a causeway instead of a second floor.
    if(index===1){const river=Math.abs(x-12*Math.sin(z*.023));const carve=(1-smooth((river-7)/10))*smooth((hit.d-8)/7)*smooth((clearing-26)/7);y=y*(1-carve)+(c.base-9+.012*z)*carve;}
    for(const [p,target]of [[corners[0],c.base],[corners.at(-1),c.base+c.rise]]){const blend=smooth((Math.hypot(x-p[0],z-p[1])-8)/8);y=y*blend+target*(1-blend);}
    return round(y);
  };
  const arena={id,name:c.name,description:['A fern ravine follows the fallen forest power line into Siltwake.','Riverworks terraces wind around sandstone spines and restored bridge relays.','Basalt retaining terraces climb from the riverworks to the isolated uplink.','Highland forest returns around the Crown Array and its guardian court.'][index],bounds:{minX:-c.w/2,maxX:c.w/2,minZ:-c.h/2,maxZ:c.h/2},spawns:[],pickups:[],navNodes:[],blocks:[],terrain:{maxSlope:.65,surfaces:[],walls:[]},voidY:-24,ceilingY:160,raised:false,nextGen:true};
  const heights=new Map(),key=(x,z)=>`${x},${z}`;
  for(let x=-c.w/2;x<=c.w/2;x+=CELL)for(let z=-c.h/2;z<=c.h/2;z+=CELL)heights.set(key(x,z),authoredHeight(x,z));
  // Antialias only exposed landform transitions, not traversal floors. Two
  // compact grid passes remove grid-frequency corrugation on oblique bench faces;
  // authored 20–100m shelves, saddles, mesas and island noses remain intact.
  for(let pass=0;pass<2;pass++){
    const source=new Map(heights);
    for(let x=-c.w/2;x<=c.w/2;x+=CELL)for(let z=-c.h/2;z<=c.h/2;z+=CELL){
      const hit=nearest(x,z),clearing=Math.min(...sites.map(p=>Math.hypot(x-p[0],z-p[1]))),edge=Math.min(hit.d-width(hit.s),clearing-25),amount=smooth((edge-2)/8);
      if(amount===0)continue;
      let sum=0;for(let dx=-1;dx<=1;dx++)for(let dz=-1;dz<=1;dz++)sum+=source.get(key(clamp(x+dx*CELL,-c.w/2,c.w/2),clamp(z+dz*CELL,-c.h/2,c.h/2)))*(dx===0?2:1)*(dz===0?2:1);
      heights.set(key(x,z),round(source.get(key(x,z))*(1-amount)+sum/16*amount));
    }
  }
  const h=(x,z)=>heights.get(key(x,z));
  const support=(x,z)=>{
    const ix=clamp(Math.floor((x+c.w/2)/CELL)*CELL-c.w/2,-c.w/2,c.w/2-CELL),iz=clamp(Math.floor((z+c.h/2)/CELL)*CELL-c.h/2,-c.h/2,c.h/2-CELL),u=(x-ix)/CELL,v=(z-iz)/CELL;
    const a=h(ix,iz),b=h(ix,iz+CELL),cc=h(ix+CELL,iz+CELL),d=h(ix+CELL,iz);
    return round(v>=u?a+(cc-b)*u+(b-a)*v:a+(d-a)*u+(cc-d)*v);
  };
  const point=([x,z])=>({x:round(x),y:support(round(x),round(z)),z:round(z)});
  const chunks=new Map();
  for(let x=-c.w/2;x<c.w/2;x+=CELL)for(let z=-c.h/2;z<c.h/2;z+=CELL) {
    const hit=nearest(x+CELL/2,z+CELL/2),bridge=index===1&&Math.abs(x-12*Math.sin(z*.023))<12;
    const clearing=Math.min(...sites.map(p=>Math.hypot(x+CELL/2-p[0],z+CELL/2-p[1])));
    const slope=(Math.max(h(x,z),h(x+CELL,z),h(x,z+CELL),h(x+CELL,z+CELL))-Math.min(h(x,z),h(x+CELL,z),h(x,z+CELL),h(x+CELL,z+CELL)))/CELL;
    const wooded=(index===0&&hit.s<length*.8)||index===3;
    const material=bridge&&hit.d<8?'metal':hit.d<3.5?'trail':hit.d<width(hit.s)+2||clearing<26||wooded&&slope<.5?'ground':'rock';
    const chunk=`terrain-${Math.floor((x+c.w/2)/32)}-${Math.floor((z+c.h/2)/32)}-${material}`;
    if(!chunks.has(chunk))chunks.set(chunk,{id:chunk,material,walkable:true,vertices:[],triangles:[]});
    const s=chunks.get(chunk),i=s.vertices.length;s.vertices.push([x,h(x,z),z],[x,h(x,z+CELL),z+CELL],[x+CELL,h(x+CELL,z+CELL),z+CELL],[x+CELL,h(x+CELL,z),z]);s.triangles.push([i,i+1,i+2],[i,i+2,i+3]);
  }
  arena.terrain.surfaces=[...chunks.values()];
  const routes=[];
  const route=(rid,cs)=>{const points=[];for(let i=1;i<cs.length;i++){const a=cs[i-1],b=cs[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);for(let j=0;j<n;j++)points.push(point([a[0]+(b[0]-a[0])*j/n,a[1]+(b[1]-a[1])*j/n]));}points.push(point(cs.at(-1)));routes.push({id:rid,points});return points;};
  const criticalPath=route('critical-path',corners),anchors={start:{...criticalPath[0],radius:5}};
  const art=[];
  const prop=(kind,material,x,z,sx,sy,sz,y=support(x,z))=>{
    if(kind==='crag'){
      const radius=Math.max(sx,sz)*.6;
      y=Math.min(y,...Array.from({length:8},(_,i)=>support(clamp(x+Math.cos(i*Math.PI/4)*radius,-c.w/2,c.w/2),clamp(z+Math.sin(i*Math.PI/4)*radius,-c.h/2,c.h/2))))-.15;
    }
    art.push({kind,material,position:[round(x),round(y),round(z)],scale:[sx,sy,sz]});
  };
  // Source spatial.mjs treats every block as [0,h], regardless of baseY.
  // Keep these grounded and render exactly that volume; no overhead blocks.
  const box=(bid,x,z,w,d,rise,material='stone')=>arena.blocks.push({id:bid,x:round(x),z:round(z),w,d,baseY:0,h:round(support(x,z)+rise),material});
  for(let i=0;i<5;i++) {
    const [x,z]=sites[i],a=point(sites[i]);anchors[`encounter-${i+1}`]={...a,radius:12};
    const loop=route(`encounter-${i+1}-supply-loop`,[[-22,0],[-16,14],[16,14],[22,0],[16,-14],[-16,-14],[-22,0]].map(p=>local(i,...p)));
    arena.pickups.push(['health',...local(i,-15,14)],['ammo',...local(i,15,-14)],['armor',...local(i,0,14)]);
    if(i===1||i===3)arena.pickups.push([i===1?'scatter':'rocket',...local(i,16,14)]);
    // Staggered inner cover: the side circuits go around both the entry screen
    // and target machinery. Actor deployment has a clear 8m central disk.
    for(const side of [-1,1]) {box(`fight-${i+1}-cover-${side}`,...local(i,side*11,side*8),3.5,3,1.6+index*.15,index===2?'metal':'stone');box(`fight-${i+1}-screen-${side}`,...local(i,side*5,-side*9),2.6,2.6,2.7,'metal');}
    const [lx,lz]=local(i,0,-22);
    prop('beacon','light',lx,lz,.55,6+i,.55,support(lx,lz)+4);
    if(index===0){box(`landmark-${i+1}-${c.landmarks[i]}`,lx,lz,5,3,2+i*.5,'stone');prop(i===0?'fallen-relay':'dish',i===0?'metal':'stone',lx,lz,i===0?26:8,i===0?4:5,i===0?4:8,support(lx,lz)+3);}
    if(index===1){for(const side of [-1,1]){const [px,pz]=local(i,side*8,-22);box(`pump-${i}-${side}`,px,pz,4,4,4+i,'metal');prop('pipe','metal',px,pz,3,9+i,3,support(px,pz)+3);}prop('dish','metal',lx,lz,11,5,11,support(lx,lz)+9);}
    if(index===2){for(let j=0;j<4;j++){const [px,pz]=local(i,-10+j*6,-23);box(`basalt-uplink-${i}-${j}`,px,pz,3,3,6+j*2,'metal');prop('beacon','light',px,pz,.4,2,.4,support(px,pz)+6+j*2);}if(i===3)prop('dish','metal',lx,lz,24,12,24,support(lx,lz)+15);}
    if(index===3){for(const side of [-1,1])box(`court-buttress-${i}-${side}`,...local(i,side*10,-23),3,5,8+i,'stone');if(i<4)prop('dish','metal',lx,lz,10+i,7,10+i,support(lx,lz)+9);}
    // Enemy pools are supported feet positions on each local combat circuit.
    for(const p of [loop[8],loop[20],loop[32],a])arena.spawns.push([p.x,p.z]);
  }
  anchors.exit={...criticalPath.at(-1),radius:6};arena.spawns.unshift([anchors.start.x,anchors.start.z]);
  // Biome-specific silhouettes complement (rather than recolour) the common
  // relay kit. Presentation ornaments sit on/behind solid landmark footprints.
  if(index===1) {
    for(let z=-120;z<120;z+=12)prop('water','water',12*Math.sin(z*.023),z,15,.1,15,c.base-6);
    for(const si of [6,16]){const seg=segments[si],mid=at(seg.start+seg.len*.5),dx=(seg.b[0]-seg.a[0])/seg.len,dz=(seg.b[1]-seg.a[1])/seg.len;for(const side of [-1,1]){const x=mid[0]-dz*side*12,z=mid[1]+dx*side*12;box(`bridgeworks-${si}-${side}`,x,z,3,3,15,'stone');prop('beacon','light',x,z,.6,6,.6,support(x,z)+15);}}
  }
  if(index===2) {
    // Two unequal bedrock groups, rather than four identical spikes at every
    // fight. The upright regularly spaced elements are machinery, not geology.
    for(const [i,u,v,w,h,d]of [[1,-12,-28,14,8,8],[1,9,-31,8,13,11],[3,-9,-24,18,7,11],[3,15,-23,9,10,7]]){const [x,z]=local(i,u,v);prop('crag','rock',x,z,w,h,d);}
  }
  if(index===3) {
    const [x,z]=local(4,0,-27);
    prop('dish','stone',x,z,30,12,30,support(x,z)+14);
    for(let i=0;i<7;i++) {
      const [px,pz]=local(4,-24+i*8,-28-Math.sin(i*Math.PI/6)*7);
      box(`crown-fin-${i}`,px,pz,2,3,18+8*Math.sin(i*Math.PI/6),'metal');
      prop('beacon','light',px,pz,.5,3,.5,support(px,pz)+18+8*Math.sin(i*Math.PI/6));
    }
  }
  // Buried grounded cliff cores follow the actual organic footprint, rather
  // than drawing visible rectangular maze walls. Their tops lie inside the
  // rock volume; source movement cannot jump through unsupported cliff faces.
  const coreSamples=Array.from({length:8/CELL+1},(_,i)=>-4+i*CELL);
  for(let x=-c.w/2+4;x<c.w/2;x+=8)for(let z=-c.h/2+4;z<c.h/2;z+=8){const hit=nearest(x,z),clearing=Math.min(...sites.map(p=>Math.hypot(x-p[0],z-p[1])));if(hit.d<width(hit.s)+10||hit.d>width(hit.s)+25||clearing<35)continue;const top=Math.min(...coreSamples.flatMap(dx=>coreSamples.map(dz=>support(x+dx,z+dz))))-1;arena.blocks.push({id:`cliff-core-${x}-${z}`,x,z,w:8,d:8,baseY:0,h:round(Math.max(1,top)),material:'rock'});}
  for(let s=24;s<length;s+=42) {const [x,z]=at(s),seg=segments.find(v=>v.start+v.len>=s);prop('beacon','light',x-(seg.b[1]-seg.a[1])/seg.len*6,z+(seg.b[0]-seg.a[0])/seg.len*6,.2,1.4,.2);}
  // Deterministic bounded scatter, outside route/loop clearance. Forest fades
  // into sandstone at chapter one exit and returns on chapter four's crown.
  let seed=9001+index;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  for(let n=0;n<1100;n++) {
    const x=(random()-.5)*(c.w-16),z=(random()-.5)*(c.h-16),hit=nearest(x,z);
    const shoulder=(index===0||index===3)&&hit.d>=9&&hit.d<12;
    if((hit.d<20&&!shoulder)||sites.some(p=>Math.hypot(x-p[0],z-p[1])<31))continue;
    const wooded=index===0?hit.s/length<.80:index===3?random()<.64:false;
    if(wooded){const sy=7+random()*7;prop('tree','foliage',x,z,5+random()*3,sy,5+random()*3);if(shoulder)box(`shoulder-trunk-${n}`,x,z,.7,.7,sy*.72,'rock');}
    else {
      // Outcrops cluster around a few coherent rock masses, leaving actual
      // skyline gaps. Most are broad boulders/shelves; tall crags are rare.
      const cluster=Math.max(...landforms.map(([cx,cz,rx,rz])=>mound(x,z,cx,cz,rx*.7,rz*.7)));
      if(random()>.10+cluster*.36)continue;
      const hero=random()<.07;
      prop('crag','rock',x,z,hero?8+random()*5:4+random()*7,hero?10+random()*7:1.8+random()*4.5,4+random()*6);
    }
  }
  for(let n=0;n<2400;n++) {
    const x=(random()-.5)*(c.w-16),z=(random()-.5)*(c.h-16),hit=nearest(x,z);
    if(hit.d<4||hit.d>12||sites.some(p=>Math.hypot(x-p[0],z-p[1])<28))continue;
    prop('fern','foliage',x,z,1.1+random(),.45+random()*.6,1.1+random());
  }
  // Chapter handoff landmarks repeat verbatim: same gate proportions, beacon
  // colour and floor elevation at Rootfall/Siltwake/Emberline/Crown joins.
  for(const [p,seg]of [[anchors.start,segments[0]],[anchors.exit,segments.at(-1)]])prop('beacon','light',p.x-(seg.b[1]-seg.a[1])/seg.len*6,p.z+(seg.b[0]-seg.a[0])/seg.len*6,.5,5,.5,p.y);
  // Nav samples retain ordered routes plus complete combat loops; source nav
  // owns adjacency/line-of-sight rather than trusting metadata as collision.
  const nav=new Map();for(const r of routes)for(let i=0;i<r.points.length;i+=2){const p=r.points[i];nav.set(key(p.x,p.z),[p.x,p.z]);}arena.navNodes=[...nav.values()];
  return {schemaVersion:1,id,name:c.name,geometryHash:nativeArenaGeometryHash(arena),arena,palette:c.palette,art,routes,spawnPoints:arena.spawns.map(point),cameras:[{id:'overview',at:[-c.w*.38,c.base+95,c.h*.40],target:[0,c.base+c.rise/2,0]}],campaign:{index,targetSeconds:[300,600],criticalPath,anchors,nextMapId:CAMPAIGN_MAP_IDS[index+1]??null}};
}

if(process.argv[1]===fileURLToPath(import.meta.url)) {
  const out=new URL('../../godot/campaign/generated/',import.meta.url);mkdirSync(out,{recursive:true});
  for(const id of CAMPAIGN_MAP_IDS) {
    const data=compileCampaign(id);parseCampaignMap(data,id);
    writeFileSync(new URL(`${id}.json`,out),JSON.stringify(data)+'\n');
    console.log(`${id}: ${routeLength(data.campaign.criticalPath).toFixed(1)}m ordered path; ${data.arena.terrain.surfaces.length} chunks; ${data.art.length} props; ${data.arena.terrain.surfaces.reduce((n,s)=>n+s.triangles.length,0)} triangles`);
  }
}

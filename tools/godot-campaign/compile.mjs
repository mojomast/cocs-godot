import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {nativeArenaGeometryHash} from '../../port/native-arenas/schema.mjs';
import {CAMPAIGN_MAP_IDS, parseCampaignMap} from '../../port/native-campaign/maps.mjs';

export const CELL = 4;
const round = n => +n.toFixed(5);
const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const smooth = v => {v=clamp(v,0,1);return v*v*(3-2*v);};
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
  const c=chapters[index],L=c.w/2-52,Z=c.h/2-32;
  // Four inhabited terraces follow a power/river corridor. Long rock spines
  // physically separate them; each end has a deliberate saddle/chokepoint.
  const rows=[-Z,-Z/3,Z/3,Z],corners=[];
  for(let row=0;row<4;row++) {
    const sign=row%2===0?1:-1,z=rows[row];
    corners.push([-L*sign,z],[-L*.35*sign,z+4],[L*.35*sign,z-4],[L*sign,z]);
    if(row<3) corners.push([(L+14)*sign,(z+rows[row+1])/2]);
  }
  const segments=[];let length=0;
  for(let i=1;i<corners.length;i++) {const a=corners[i-1],b=corners[i],len=Math.hypot(b[0]-a[0],b[1]-a[1]);segments.push({a,b,len,start:length});length+=len;}
  const nearest=(x,z)=>{
    let best={d:Infinity,s:0};for(const seg of segments) {const hit=distance([x,z],seg.a,seg.b);if(hit.d<best.d)best={d:hit.d,s:seg.start+hit.t*seg.len};}return best;
  };
  const at=s=>{const seg=segments.find(v=>v.start+v.len>=s)??segments.at(-1),t=clamp((s-seg.start)/seg.len,0,1);return [seg.a[0]+(seg.b[0]-seg.a[0])*t,seg.a[1]+(seg.b[1]-seg.a[1])*t];};
  // Encounter sites are chosen on straight terraces, not blindly on switchbacks.
  const sites=[[-L*.20,rows[0]], [L*.05,rows[1]],[-L*.60,rows[2]], [L*.60,rows[2]],[-L*.20,rows[3]]];
  const floor=(s)=>c.base+c.rise*s/length+1.1*Math.sin(s*.025)*Math.sin(Math.PI*s/length);
  const authoredHeight=(x,z)=>{
    const hit=nearest(x,z), clearing=Math.min(...sites.map(p=>Math.hypot(x-p[0],z-p[1])));
    const edge=Math.min(hit.d-13,clearing-25);
    const ridge=(index===0?22:index===1?28:24)*smooth(edge/10);
    // Broad supported floor, rolling shoulders, faceted unclimbable ridge crests.
    const detail=(.24*Math.sin(x*.065)*Math.cos(z*.08)*Math.sin(Math.PI*hit.s/length)+1.4*smooth(edge/8)*Math.sin(x*.07)**2);
    const bridgeGully=index===1?16*smooth((hit.d-8)/8)*smooth((22-Math.abs(z-(rows[0]+rows[1])/2))/8)*smooth((x-L+8)/12):0;
    return round(floor(hit.s)+ridge+detail-bridgeGully);
  };
  const arena={id,name:c.name,description:['A fern ravine follows the fallen forest power line into Siltwake.','Riverworks terraces wind around sandstone spines and restored bridge relays.','Basalt retaining terraces climb from the riverworks to the isolated uplink.','Highland forest returns around the Crown Array and its guardian court.'][index],bounds:{minX:-c.w/2,maxX:c.w/2,minZ:-c.h/2,maxZ:c.h/2},spawns:[],pickups:[],navNodes:[],blocks:[],terrain:{maxSlope:.65,surfaces:[],walls:[]},voidY:-24,ceilingY:160,raised:false,nextGen:true};
  const heights=new Map(),key=(x,z)=>`${x},${z}`;
  for(let x=-c.w/2;x<=c.w/2;x+=CELL)for(let z=-c.h/2;z<=c.h/2;z+=CELL)heights.set(key(x,z),authoredHeight(x,z));
  const h=(x,z)=>heights.get(key(x,z));
  const support=(x,z)=>{
    const ix=clamp(Math.floor((x+c.w/2)/CELL)*CELL-c.w/2,-c.w/2,c.w/2-CELL),iz=clamp(Math.floor((z+c.h/2)/CELL)*CELL-c.h/2,-c.h/2,c.h/2-CELL),u=(x-ix)/CELL,v=(z-iz)/CELL;
    const a=h(ix,iz),b=h(ix,iz+CELL),cc=h(ix+CELL,iz+CELL),d=h(ix+CELL,iz);
    return round(v>=u?a+(cc-b)*u+(b-a)*v:a+(d-a)*u+(cc-d)*v);
  };
  const point=([x,z])=>({x:round(x),y:support(round(x),round(z)),z:round(z)});
  const chunks=new Map();
  for(let x=-c.w/2;x<c.w/2;x+=CELL)for(let z=-c.h/2;z<c.h/2;z+=CELL) {
    const hit=nearest(x+2,z+2),bridge=index===1&&x>L-4&&z>rows[0]+10&&z<rows[1]-10;
    const material=bridge&&hit.d<8?'metal':hit.d<7?'trail':hit.d<18?'ground':'rock';
    const chunk=`terrain-${Math.floor((x+c.w/2)/32)}-${Math.floor((z+c.h/2)/32)}-${material}`;
    if(!chunks.has(chunk))chunks.set(chunk,{id:chunk,material,walkable:true,vertices:[],triangles:[]});
    const s=chunks.get(chunk),i=s.vertices.length;s.vertices.push([x,h(x,z),z],[x,h(x,z+CELL),z+CELL],[x+CELL,h(x+CELL,z+CELL),z+CELL],[x+CELL,h(x+CELL,z),z]);s.triangles.push([i,i+1,i+2],[i,i+2,i+3]);
  }
  arena.terrain.surfaces=[...chunks.values()];
  const routes=[];
  const route=(rid,cs)=>{const points=[];for(let i=1;i<cs.length;i++){const a=cs[i-1],b=cs[i],n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/3);for(let j=0;j<n;j++)points.push(point([a[0]+(b[0]-a[0])*j/n,a[1]+(b[1]-a[1])*j/n]));}points.push(point(cs.at(-1)));routes.push({id:rid,points});return points;};
  const criticalPath=route('critical-path',corners),anchors={start:{...criticalPath[0],radius:5}};
  const art=[];
  const prop=(kind,material,x,z,sx,sy,sz,y=support(x,z))=>art.push({kind,material,position:[round(x),round(y),round(z)],scale:[sx,sy,sz]});
  // Source spatial.mjs treats every block as [0,h], regardless of baseY.
  // Keep these grounded and render exactly that volume; no overhead blocks.
  const box=(bid,x,z,w,d,rise,material='stone')=>arena.blocks.push({id:bid,x:round(x),z:round(z),w,d,baseY:0,h:round(support(x,z)+rise),material});
  for(let i=0;i<5;i++) {
    const [x,z]=sites[i],a=point(sites[i]);anchors[`encounter-${i+1}`]={...a,radius:12};
    const loop=route(`encounter-${i+1}-supply-loop`,[[x-22,z],[x-16,z+14],[x+16,z+14],[x+22,z],[x+16,z-14],[x-16,z-14],[x-22,z]]);
    arena.pickups.push(['health',x-15,z+14],['ammo',x+15,z-14],['armor',x,z+14]);
    if(i===1||i===3)arena.pickups.push([i===1?'scatter':'rocket',x+16,z+14]);
    // Staggered inner cover: the side circuits go around both the entry screen
    // and target machinery. Actor deployment has a clear 8m central disk.
    for(const side of [-1,1]) {box(`fight-${i+1}-cover-${side}`,x+side*11,z+side*8,5,3,1.9);box(`fight-${i+1}-screen-${side}`,x+side*5,z-side*9,3,3,3.1,'metal');}
    box(`landmark-${i+1}-${c.landmarks[i]}`,x,z-20,5,4,7+i,'metal');
    prop('beacon','light',x,z-20,.7,12+i,.7,support(x,z-20)+6);
    // Crown ribs / relay housing piers, with no phantom support deck.
    for(const side of [-1,1])box(`relay-${i+1}-pier-${side}`,x+side*8,z-20,2,3,11+i,'stone');
    const housingY=Math.max(support(x-8,z-20),support(x+8,z-20))+7+i;
    arena.blocks.push({id:`relay-${i+1}-housing`,x:round(x),z:round(z-20),w:13.8,d:2,baseY:0,h:round(housingY+1.2),material:'metal'});
    // Enemy pools are supported feet positions on each local combat circuit.
    for(const p of [loop[8],loop[20],loop[32],a])arena.spawns.push([p.x,p.z]);
  }
  anchors.exit={...criticalPath.at(-1),radius:6};arena.spawns.unshift([anchors.start.x,anchors.start.z]);
  // Biome-specific silhouettes complement (rather than recolour) the common
  // relay kit. Presentation ornaments sit on/behind solid landmark footprints.
  if(index===0) {
    const [x,z]=sites[0];
    prop('fallen-relay','metal',x,z-23,30,4,4,support(x,z-23)+8);
    prop('dish','stone',sites[1][0],sites[1][1]-20,12,8,12,support(sites[1][0],sites[1][1]-20)+9);
  }
  if(index===1) {
    const x=L+14,z=(rows[0]+rows[1])/2;
    for(const side of [-1,1]) {
      box(`bridge-parapet-${side}`,x+side*10,z,1.5,14,1.4,'metal');
      box(`bridgeworks-tower-${side}`,x+side*13,z,3,5,18,'stone');
    }
    for(const [sx,sz]of [sites[1],sites[3]])prop('dish','metal',sx,sz-20,14,6,14,support(sx,sz-20)+10);
  }
  if(index===2) {
    for(let i=0;i<5;i++) {
      const [x,z]=sites[i];
      for(let j=0;j<4;j++)prop('crag','rock',x-14+j*8,z-24,5,12+j*2,5);
    }
    const [x,z]=sites[3];prop('dish','metal',x,z-20,22,12,22,support(x,z-20)+14);
  }
  if(index===3) {
    const [x,z]=sites[4];
    prop('dish','stone',x,z-20,30,12,30,support(x,z-20)+14);
    for(let i=0;i<7;i++) {
      const px=x-24+i*8,pz=z-24-Math.sin(i*Math.PI/6)*7;
      box(`crown-fin-${i}`,px,pz,2,3,18+8*Math.sin(i*Math.PI/6),'metal');
      prop('beacon','light',px,pz,.5,3,.5,support(px,pz)+18+8*Math.sin(i*Math.PI/6));
    }
  }
  // Closed rock ribs enforce geography even if source movement would otherwise
  // slide up a steep support sheet. Gaps alternate at the authored saddles.
  for(let row=0;row<3;row++) {
    const z=(rows[row]+rows[row+1])/2,side=row%2===0?1:-1;
    const min=side===1?-c.w/2:L*-1+31,max=side===1?L-31:c.w/2;
    for(let x=min;x<max;x+=12) {
      const w=Math.min(12,max-x),cx=x+w/2;
      box(`ridge-${row}-${round(x)}`,cx,z,w,5,5,'rock');
    }
  }
  // Boundary masses share real block collision and visually terminate the
  // exterior shelves. Passage at chapter entry/exit remains inside bounds.
  for(const side of [-1,1]) {
    for(let z=-c.h/2;z<c.h/2;z+=16)box(`edge-x-${side}-${z}`,side*(c.w/2-2),z+8,4,16,6+3*Math.sin(z*.17)**2,'rock');
    for(let x=-c.w/2+4;x<c.w/2-4;x+=16){const w=Math.min(16,c.w/2-4-x);box(`edge-z-${side}-${x}`,x+w/2,side*(c.h/2-2),w,4,6+4*Math.cos(x*.13)**2,'rock');}
  }
  for(let s=24;s<length;s+=42) {const [x,z]=at(s);prop('beacon','light',x,z+7,.25,2.4,.25);}
  // Deterministic bounded scatter, outside route/loop clearance. Forest fades
  // into sandstone at chapter one exit and returns on chapter four's crown.
  let seed=9001+index;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  for(let n=0;n<1100;n++) {
    const x=(random()-.5)*(c.w-16),z=(random()-.5)*(c.h-16),hit=nearest(x,z);
    const shoulder=(index===0||index===3)&&hit.d>=10&&hit.d<13;
    if((hit.d<20&&!shoulder)||sites.some(p=>Math.hypot(x-p[0],z-p[1])<31))continue;
    const wooded=index===0?hit.s/length<.80:index===3?random()<.64:false;
    if(wooded){const sy=7+random()*7;prop('tree','foliage',x,z,2.8+random()*1.6,sy,2.8+random()*1.6);if(shoulder)box(`shoulder-trunk-${n}`,x,z,.7,.7,sy*.72,'rock');}
    else prop('crag','rock',x,z,2+random()*3,3+random()*8,2+random()*3);
  }
  for(let n=0;n<2400;n++) {
    const x=(random()-.5)*(c.w-16),z=(random()-.5)*(c.h-16),hit=nearest(x,z);
    if(hit.d<4||hit.d>12||sites.some(p=>Math.hypot(x-p[0],z-p[1])<28))continue;
    prop('fern','foliage',x,z,1.1+random(),.45+random()*.6,1.1+random());
  }
  // Chapter handoff landmarks repeat verbatim: same gate proportions, beacon
  // colour and floor elevation at Rootfall/Siltwake/Emberline/Crown joins.
  for(const [label,p] of [['arrival',anchors.start],['departure',anchors.exit]]) {
    for(const side of [-1,1])box(`${label}-power-pylon-${side}`,p.x,p.z+side*9,3,3,15,'metal');
    prop('beacon','light',p.x,p.z+9,.6,4,.6,support(p.x,p.z+9)+15);
  }
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

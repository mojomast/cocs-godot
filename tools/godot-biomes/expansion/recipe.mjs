// Original authored Y-up mesh recipes. No runtime randomness, shader geometry,
// source terrain edits, or replacement of the reviewed facade assets.
export const SEED = 20261002;
export const maps = ['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'];
export const palette = {
  bark: ['514a38', .92, 0], moss: ['687855', .94, 0],
  sandstone: ['a78c69', .9, 0], silt: ['655f52', .96, 0],
  basalt: ['434953', .88, 0], copper: ['ad7952', .67, .55],
  ceramic: ['c8c3af', .72, .08], iron: ['465563', .74, .45],
};
const TAU = Math.PI * 2;
const add = (a,b) => a.map((v,i)=>v+b[i]);
const mul = (a,s) => a.map(v=>v*s);
const sub = (a,b) => a.map((v,i)=>v-b[i]);
const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const unit = a => mul(a,1/Math.hypot(...a));

class Assembly {
  constructor(id,chapter,role,block) { Object.assign(this,{id,chapter,role,block,parts:[]}); }
  mesh(name,material,vertices,faces,detail=false) {
    const triangles=[];
    for(const f of faces)for(let i=1;i<f.length-1;i++)triangles.push([f[0],f[i],f[i+1]]);
    this.parts.push({name,material,detail,vertices:vertices.map(p=>p.map(v=>+v.toFixed(7))),triangles});
  }
  // Closed polygon loft; rings may change shape and shift at each height.
  loft(name,mat,rings,detail=false) {
    const center=r=>mul(r.reduce((a,p)=>add(a,p),[0,0,0]),1/r.length);
    const normal=cross(sub(rings[0][1],rings[0][0]),sub(rings[0][2],rings[0][0]));
    const advance=sub(center(rings.at(-1)),center(rings[0]));
    if(normal.reduce((sum,v,i)=>sum+v*advance[i],0)<0)rings=rings.map(r=>[...r].reverse());
    const n=rings[0].length,faces=[];
    faces.push(Array.from({length:n},(_,i)=>n-1-i));
    for(let j=0;j<rings.length-1;j++)for(let i=0;i<n;i++)faces.push([j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i]);
    faces.push(Array.from({length:n},(_,i)=>(rings.length-1)*n+i));
    this.mesh(name,mat,rings.flat(),faces,detail);
  }
  beam(name,mat,a,b,r0,r1=r0,n=6,detail=false) {
    const d=unit(sub(b,a)),u=unit(cross(d,Math.abs(d[1])>.9?[1,0,0]:[0,1,0])),v=cross(d,u);
    this.loft(name,mat,[[a,r0],[b,r1]].map(([p,r])=>Array.from({length:n},(_,i)=>add(p,add(mul(u,Math.cos(i*TAU/n)*r),mul(v,Math.sin(i*TAU/n)*r))))),detail);
  }
  // Bevelled octagonal slabs, actual masonry profiles rather than cubes.
  slab(name,mat,c,w,h,d,bevel=.15,detail=false) {
    const ring=[[-.5+bevel,-.5],[.5-bevel,-.5],[.5,-.5+bevel],[.5,.5-bevel],[.5-bevel,.5],[-.5+bevel,.5],[-.5,.5-bevel],[-.5,-.5+bevel]];
    this.loft(name,mat,[-.5,.5].map(y=>ring.map(([x,z])=>[c[0]+x*w,c[1]+y*h,c[2]+z*d])),detail);
  }
  wheel(name,mat,c,r,thick,n=16) {
    // Open annulus in X/Y plane. Four rings, never a filled disk.
    const vertices=[];
    for(const [rad,z] of [[r,-thick/2],[r,thick/2],[r*.82,thick/2],[r*.82,-thick/2]])
      for(let i=0;i<n;i++)vertices.push([c[0]+Math.cos(i*TAU/n)*rad,c[1]+Math.sin(i*TAU/n)*rad,c[2]+z]);
    const faces=[];
    for(let j=0;j<4;j++)for(let i=0;i<n;i++)faces.push([j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i]);
    this.mesh(name,mat,vertices,faces);
  }
}

function root(a,kind) {
  // Paired roots spread around, never across, the retained cabin/service core.
  for(const side of [-1,1])for(const z of [-.37,.37]) {
    const rings=[[.03,.43,.06],[.28,.39,.048],[.58,.29,.038],[.86,.18,.027]].map(([y,x,r])=>
      Array.from({length:7},(_,i)=>[side*x+Math.cos(i*TAU/7)*r,y,z+Math.sin(i*TAU/7)*r]));
    a.loft(`root-buttress-${side}-${z}`,'bark',rings);
    a.beam(`root-copper-binding-${side}-${z}`,'copper',[side*.40,.25,z],[side*.28,.61,z],.012,.012,6,true);
  }
  if(kind==='canopy') {
    for(const side of [-1,1])for(let i=0;i<4;i++) {
      const y=.65+i*.07,z=-.30+i*.20;
      a.loft(`folded-canopy-${side}-${i}`,'moss',[
        [[side*.12,y,z-.065],[side*.46,y-.04,z-.065],[side*.46,y-.04,z+.065],[side*.12,y,z+.065]],
        [[side*.12,y+.035,z-.065],[side*.46,y-.005,z-.065],[side*.46,y-.005,z+.065],[side*.12,y+.035,z+.065]]]);
    }
    a.beam('split-relay-spine','copper',[-.12,.67,0],[.1,.96,0],.035,.018);
  } else if(kind==='archive') {
    for(const z of [-.45,.45])for(let i=0;i<5;i++)a.slab(`seed-archive-course-${z}-${i}`,'bark',[0,.16+i*.14,z],.75,.09,.065);
    for(const x of [-.32,.32])a.beam(`archive-lashing-${x}`,'copper',[x,.15,-.46],[x,.78,-.46],.012,.012,6,true);
  } else {
    for(let i=0;i<5;i++)a.beam(`fork-branch-${i}`,'bark',[-.13+i*.065,.45,0],[-.38+i*.17,.92, i%2?.3:-.3],.035,.018);
    a.wheel('relay-collar','copper',[0,.68,-.39],.17,.05,12);
  }
}

function silt(a,kind) {
  for(let i=0;i<7;i++) {
    const width=.94-i*.047;
    for(const z of [-1,1])a.slab(`stratified-bank-${z}-${i}`,'sandstone',[0,.06+i*.125,z*(.43-i*.014)],width,.092,.10,.13);
  }
  if(kind==='wheel') {
    for(const z of [-.42,.42]) {
      a.wheel(`mill-rim-${z}`,'copper',[0,.60,z],.32,.045,20);
      for(let i=0;i<10;i++) {
        const t=i*TAU/10;
        a.beam(`mill-spoke-${z}-${i}`,'iron',[0,.6,z],[Math.cos(t)*.31,.6+Math.sin(t)*.31,z],.011);
        a.slab(`bucket-${z}-${i}`,'silt',[Math.cos(t)*.29,.6+Math.sin(t)*.29,z],.065,.047,.12,.1,true);
      }
    }
    a.beam('mill-axle','iron',[0,.6,-.47],[0,.6,.47],.044);
    // Reviewed wheelhouse is 8 x 14.48338471015 x 5 m. Correct the relief's
    // vertical aspect explicitly so the fitted wheel remains a real circle.
    for(const part of a.parts.filter(p=>/^(mill-|bucket-)/.test(p.name)))
      for(const v of part.vertices)v[1]=+(.6+(v[1]-.6)*8/14.48338471015).toFixed(7);
  } else if(kind==='sluice') {
    for(const x of [-.38,.38])a.beam(`sluice-channel-${x}`,'iron',[x,.07,-.45],[x,.9,-.45],.028);
    for(let i=0;i<6;i++)a.slab(`closed-sluice-louver-${i}`,'copper',[0,.17+i*.1,-.46],.67,.043,.045);
  } else {
    for(const x of [-.4,.4])a.beam(`flood-abutment-${x}`,'silt',[x,.03,.36],[x*.6,.91,.3],.065,.035);
    a.slab('layered-capstone','sandstone',[0,.94,0],.85,.045,.80);
  }
  for(const x of [-.3,0,.3])a.slab(`waterline-datum-${x}`,'iron',[x,.22,-.487],.035,.12,.012,.1,true);
}

function ember(a,kind) {
  // Unequal hexagonal cooling columns create a fractured terrace silhouette.
  for(const z of [-.35,.35])for(let i=0;i<5;i++) {
    const x=-.37+i*.185,h=.28+((i*7+3)%5)*.10;
    a.beam(`basalt-column-${z}-${i}`,'basalt',[x,.025,z],[x+.015,h,z],.105,.082,6);
  }
  const count=kind==='shield'?7:kind==='terrace'?3:5;
  for(const side of [-1,1])for(let i=0;i<count;i++) {
    const y=.40+i*(.50/count),z=side*.42;
    a.loft(`folded-heatshield-${side}-${i}`,'copper',[
      [[-.40,y,z],[-.1,y+.025,z-side*.06],[.32,y,z],[.38,y+.02,z]],
      [[-.40,y+.038,z],[-.1,y+.063,z-side*.06],[.32,y+.038,z],[.38,y+.058,z]]]);
  }
  if(kind!=='terrace')for(const x of [-.41,.41])a.beam(`heat-return-${x}`,'iron',[x,.31,-.32],[x,.93,.30],.03,.022);
  if(kind==='chimney')for(let i=0;i<3;i++)a.beam(`ceramic-exhaust-${i}`,'ceramic',[-.25+i*.25,.68,0],[-.25+i*.25,.97-i*.06,0],.062,.052);
  for(let i=0;i<6;i++)a.slab(`shield-fastener-${i}`,'iron',[-.32+(i%3)*.28,.46+Math.floor(i/3)*.29,-.44],.04,.018,.025,.2,true);
}

function crown(a,kind) {
  // Recessed lightwell is a relief on a closed existing facade, not a doorway.
  for(const z of [-.42,.42]) {
    for(const x of [-.38,.38])a.beam(`ceramic-pilaster-${x}-${z}`,'ceramic',[x,.04,z],[x*.72,.91,z*.9],.062,.039,5);
    for(let i=0;i<5;i++)a.slab(`archive-lintel-${z}-${i}`,'ceramic',[0,.14+i*.17,z],.69,.045,.065);
  }
  if(kind==='antenna') {
    for(let i=0;i<3;i++)a.wheel(`faceted-antenna-${i}`,'iron',[0,.43+i*.20,-.43],.19-i*.035,.035,6);
    a.beam('antenna-feed','copper',[0,.23,-.46],[0,.96,-.46],.012,.012);
  } else if(kind==='lightwell') {
    for(const side of [-1,1])a.loft(`lightwell-reveal-${side}`,'ceramic',[
      [[side*.30,.26,-.46],[side*.18,.3,-.34],[side*.18,.78,-.34],[side*.3,.83,-.46]],
      [[side*.33,.26,-.46],[side*.21,.3,-.34],[side*.21,.78,-.34],[side*.33,.83,-.46]]]);
    a.beam('lightwell-optical-core','copper',[0,.30,-.40],[0,.77,-.40],.035,.035,8);
  } else {
    for(let i=0;i<6;i++)a.slab(`archive-folio-${i}`,'iron',[-.25+i*.10,.51,-.455],.035,.43,.038,.1,true);
    a.slab('archive-pediment','ceramic',[0,.95,0],.8,.04,.83);
  }
  for(const x of [-.22,.22])a.beam(`archive-index-rail-${x}`,'copper',[x,.19,-.46],[x,.88,-.46],.009,.009,6,true);
}

export function recipes() {
  const specs=[
    ['rootfall-canopy-relay',0,'hero','interlude-canopy-nursery-rib-2',root,'canopy'],
    ['rootfall-root-archive',0,'support','landmark-2-Root archive',root,'archive'],
    ['rootfall-root-buttress',0,'support','interlude-nursery-nursery-rib-1',root,'fork'],
    ['siltwake-strata-wheelhouse',1,'hero','interlude-waterwheel-wheel-house',silt,'wheel'],
    ['siltwake-sluice-bank',1,'support','interlude-waterwheel-dry-berth-left',silt,'sluice'],
    ['siltwake-flood-abutment',1,'support','interlude-waterwheel-dry-berth-right',silt,'abutment'],
    ['emberline-heatshield-tower',2,'hero','interlude-condenser-cooling-fin-2',ember,'shield'],
    ['emberline-basalt-terrace',2,'support','basalt-uplink-0-3',ember,'terrace'],
    ['emberline-ceramic-exhaust',2,'support','interlude-foundry-cooling-fin-3',ember,'chimney'],
    ['crown-faceted-antenna',3,'hero','interlude-choir-choir-pier-2',crown,'antenna'],
    ['crown-ceramic-lightwell',3,'support','interlude-garden-choir-pier-2',crown,'lightwell'],
    ['crown-folio-archive',3,'support','court-buttress-2--1',crown,'archive'],
  ];
  return specs.map(([id,index,role,block,build,kind])=>{const a=new Assembly(id,maps[index],role,block);build(a,kind);return a;});
}

export function faces(asset,lod=0) {
  return asset.parts.filter(p=>lod===0||!p.detail).flatMap(p=>p.triangles.map(t=>t.map(i=>p.vertices[i])));
}

// Metres, Godot/source axes: +Y up, +Z nose. Pure authoring; no authority writes.
import {PUMA, TITAN, SCOUT} from '../../game/vehicles.mjs';
export const palette = {
  armor: ['626b42', .72, .28], edge: ['aebac5', .38, .75],
  rubber: ['182126', .94, .02], recess: ['263238', .8, .2],
  seat: ['454538', .96, 0], team_accent: ['dfc98d', .65, .2],
  lamp: ['fff0ba', .3, .1], red: ['b64235', .6, .1],
};
export const contracts = {
  puma: {source:PUMA, pivot:[0,1.1,-.95], radius:.42, width:.3, xs:[-.9,.9], zs:[-1.18,1.18]},
  titan: {source:TITAN, pivot:[0,1.5,-.72], radius:.37, width:.32, xs:[-1.28,1.28], zs:Array.from({length:8},(_,i)=>-2.1+i*.6)},
  scout: {source:SCOUT, pivot:[0,.79,.04], radius:.245, width:.22, xs:[-.45,.45], zs:[-.75,.75]},
};
const add=(a,b)=>a.map((v,i)=>v+b[i]);
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const mul=(a,k)=>a.map(v=>v*k);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>mul(a,1/Math.hypot(...a));

export function recipe(kind, lod=0) {
  const c=contracts[kind]; if(!c || ![0,1,2].includes(lod)) throw Error('Unknown recipe');
  const parts=[], joints={body:[0,0,0],turret:c.pivot};
  let joint='body';
  function mesh(name,vertices,faces,material='armor', detail=0) {
    if(detail+lod>2)return;
    if(vertices.some(v=>v.length!==3 || !v.every(Number.isFinite)))throw Error(`Invalid ${kind}/${name} coordinates`);
    parts.push({name,joint,material,vertices:vertices.map(v=>sub(v,joints[joint])),faces});
  }
  // Eight-sided chamfered panel extrusion, rather than cube proxies.
  function panel(name,at,size,material='armor',detail=0) {
    const [w,h,d]=size.map(v=>v/2), b=Math.min(w,h)*.24;
    const ring=[[-w+b,-h],[w-b,-h],[w,-h+b],[w,h-b],[w-b,h],[-w+b,h],[-w,h-b],[-w,-h+b]];
    const vs=[-d,d].flatMap(z=>ring.map(([x,y])=>add(at,[x,y,z])));
    mesh(name,vs,[[7,6,5,4,3,2,1,0],[8,9,10,11,12,13,14,15],...ring.map((_,i)=>[i,(i+1)%8,(i+1)%8+8,i+8])],material,detail);
  }
  function loft(name,rows,material='armor') {
    const vs=rows.flatMap(([z,w,b,t])=>[[-w,b,z],[w,b,z],[w,t,z],[-w,t,z]]),fs=[[3,2,1,0]];
    for(let k=0;k<rows.length-1;k++)for(let i=0;i<4;i++)fs.push([k*4+i,k*4+(i+1)%4,(k+1)*4+(i+1)%4,(k+1)*4+i]);
    const end=(rows.length-1)*4;fs.push([end,end+1,end+2,end+3]);mesh(name,vs,fs,material);
  }
  function tube(name,a,b,r,material='edge',detail=0,inner=0) {
    const axis=norm(sub(b,a)), u=norm(cross(axis,Math.abs(axis[1])<.9?[0,1,0]:[1,0,0])),v=cross(axis,u);
    const n=[20,12,8][lod], verts=[];
    for(const radius of inner?[r,inner]:[r])for(const p of [a,b])for(let i=0;i<n;i++)verts.push(add(p,add(mul(u,radius*Math.cos(i*2*Math.PI/n)),mul(v,radius*Math.sin(i*2*Math.PI/n)))));
    const fs=[];
    for(let i=0;i<n;i++){const j=(i+1)%n;fs.push([i,j,n+j,n+i]);if(inner){fs.push([2*n+i,3*n+i,3*n+j,2*n+j],[i,2*n+i,2*n+j,j],[n+i,n+j,3*n+j,3*n+i]);}}
    if(!inner)fs.push(Array.from({length:n},(_,i)=>n-1-i),Array.from({length:n},(_,i)=>n+i));
    mesh(name,verts,fs,material,detail);
  }
  function arch(name,x,z,r,width,material='armor') {
    const vs=[],n=[16,10,6][lod];
    for(const xx of [x-width/2,x+width/2])for(const rr of [r,r+.055])for(let i=0;i<=n;i++){
      const a=i*Math.PI/n;vs.push([xx,c.radius+Math.sin(a)*rr,z+Math.cos(a)*rr]);
    }
    const k=n+1,fs=[];for(let i=0;i<n;i++)fs.push([i,i+1,k+i+1,k+i],[2*k+i,3*k+i,3*k+i+1,2*k+i+1],[k+i,k+i+1,3*k+i+1,3*k+i],[i,2*k+i,2*k+i+1,i+1]);
    fs.push([0,k,3*k,2*k],[n,2*k+n,3*k+n,k+n]);mesh(name,vs,fs,material);
  }
  const heavy=kind==='titan', compact=kind==='scout', w=heavy?2.28:compact?.72:1.72, len=heavy?5.05:compact?1.85:3.28;
  panel('keel',[0,heavy?.62:compact?.32:.48,0],[w*.84,.19,len],'recess');
  for(const s of [-1,1]){
    panel('chassis-rail',[s*w*.36,heavy?.78:compact?.4:.6,0],[.09,.16,len],'edge');
    for(const z of [-len*.33,0,len*.33])tube('crossmember',[-w*.4,heavy?.75:.4,z],[w*.4,heavy?.75:.4,z],.035,'recess');
  }
  if(heavy){
    loft('faceted-siege-hull',[[-2.4,.99,.705,1.255],[-1.8,1.14,.705,1.255],[1.45,1.14,.705,1.255],[2.4,1.08,.75,1.04]]);
    loft('sloping-glacis',[[1.2,1.12,1.25,1.36],[2.42,1.04,.99,1.1]],'edge');
    for(const s of [-1,1]){
      // Open wheel bays bounded by upper/lower belts and curved end shoes.
      for(const y of [.08,.82])panel('track-belt',[s*1.28,y,0],[.4,.1,4.6],'rubber');
      for(let i=0;i<26;i++)for(const y of [.045,.87])panel('track-shoe',[s*1.28,y,-2.25+i*.18],[.42,.075,.125],'recess',1);
      for(const end of [-1,1])for(let i=0;i<=10;i++){
        const a=-Math.PI/2+i*Math.PI/10, y=.435+Math.sin(a)*.36, z=end*(2.1+Math.cos(a)*.36);
        tube('track-end-shoe',[s*1.28-.2,y,z],[s*1.28+.2,y,z],.065,'recess',1);
      }
      for(let i=0;i<6;i++)panel('skirt-section',[s*1.39,1.03,-2.04+i*.81],[.16,.4,.73],i===4?'team_accent':'armor');
      panel('crew-hatch',[s*.58,1.32,.7],[.66,.09,.7]);
      panel('periscope',[s*.58,1.4,.98],[.3,.08,.12],'recess',1);
    }
  }else{
    loft('sloping-front-cowl',compact?[[.23,w*.49,.46,.69],[.64,w*.46,.43,.61],[.92,w*.31,.38,.49]]:[[.55,w*.5,.72,.95],[1.22,w*.49,.7,.9],[1.55,w*.4,.65,.78]]);
    for(const s of [-1,1]){
      const y=compact?.66:.935,z=compact?.29:.62;
      panel('hood-access-latch',[s*w*.32,y,z],[.08,.025,.16],'edge',1);
      tube('hood-hinge',[s*w*.17,y+.012,z],[s*w*.27,y+.012,z],.018,'recess',1);
    }
    for(let i=0;i<(compact?4:7);i++)panel('radiator-fin',[(i-(compact?1.5:3))*.1,compact?.43:.69,compact?.929:1.56],[.026,compact?.08:.14,.018],'recess',1);
    panel('rear-service-deck',[0,compact?.5:.72,-len*.37],[w,.18,len*.23]);
    for(const s of [-1,1]){
      const x=s*w*.42, top=compact?1.08:1.59, zfront=compact?.28:.45, zrear=compact?-.6:-.7;
      tube('cage-front',[x,.45,zfront],[x,top,zfront-(compact?.17:0)],.035);
      tube('cage-rear',[x,.45,zrear],[x,top,zrear],.035);
      tube('cage-roof',[x,top,zrear],[x,top,zfront-(compact?.17:0)],.035);
      tube('cage-brace',[x,.53,zrear-.15],[x,top,zrear],.026,'recess');
      panel('sill',[s*w*.46,.51,0],[.07,.16,len*.65],'team_accent');
      tube('rear-cage-cross',[-w*.42,top,zrear],[w*.42,top,zrear],.03);
    }
  }
  // Actual source seat anchors denote actor feet, not cushion height.
  const layout=c.source.seatLayout, seats=[['driver',layout.driver],...(layout.gunner?[['gunner',layout.gunner]]:[]),...layout.passengers.map((v,i)=>[`passenger_${i}`,v])];
  for(const [name,p] of seats){
    const width=compact?.24:.4;
    panel(`${name}-seat-pan`,[p.x,p.y+.29,p.z],[width,.09,.36],'seat');
    panel(`${name}-seat-back`,[p.x,p.y+.52,p.z-.17],[width,.43,.07],'seat');
    tube(`${name}-seat-support`,[p.x,p.y+.05,p.z],[p.x,p.y+.24,p.z],.035,'edge',1);
    for(const s of [-1,1])panel(`${name}-harness`,[p.x+s*width*.29,p.y+.53,p.z-.127],[.028,.3,.012],'recess',1);
  }
  const d=layout.driver;
  panel('instrument-dash',[d.x,d.y+.45,d.z+.39],[compact?.26:.44,.13,.045],'recess',1);
  for(const x of [-.075,.075])tube('instrument-dial',[d.x+x,d.y+.47,d.z+.36],[d.x+x,d.y+.47,d.z+.365],.037,'edge',2,.027);
  tube('steering-column',[d.x,d.y+.15,d.z+.32],[d.x,d.y+.58,d.z+.35],.024,'edge',1);
  tube('steering-rim',[d.x,d.y+.55,d.z+.34],[d.x,d.y+.55,d.z+.365],compact?.09:.14,'rubber',1,compact?.07:.115);
  for(const s of [-1,1]){
    panel('headlamp',[s*w*.33,heavy?1.02:compact?.61:.84,len/2-.04],[w*.12,.11,.06],'lamp');
    panel('tail-lamp',[s*w*.33,heavy?.95:.65,-len/2],[.13,.07,.03],'red',1);
    tube('exhaust',[s*w*.34,.55,-len*.35],[s*w*.34,.55,-len*.49],heavy?.085:.05,'recess',1,heavy?.065:.035);
    panel('cooling-bed',[s*w*.3,heavy?1.28:compact?.61:.83,-len*.35],[w*.25,.04,len*.19],'recess');
    for(let i=0;i<7;i++)panel('cooling-louver',[s*w*.3,heavy?1.315:compact?.635:.855,-len*.43+i*len*.025],[w*.23,.025,.027],'edge',1);
    panel('tow-eye',[s*w*.35,.4,len/2],[.12,.1,.08],'edge',1);
    for(let i=0;i<4;i++)panel('unit-stencil',[s*w*.47,.61,-.3+i*.075],[.014,.08,.032],'team_accent',2);
  }
  // Wheels are independent rigid assemblies with exact native rolling pivots.
  for(const x of c.xs)for(const z of c.zs){
    const idx=Object.keys(joints).filter(k=>k.startsWith('wheel_')).length, pivot=[x,c.radius,z];
    if(!heavy)arch('wheel-arch',x,z,c.radius+.035,c.width*.9);
    tube('wishbone',[x*.63,c.radius*.6,z-.14],[x,c.radius,z],.025,'edge',1);
    tube('shock-body',[x*.74,c.radius+.29,z-.13],[x*.93,c.radius+.07,z],.041,'recess',1);
    tube('shock-rod',[x*.93,c.radius+.07,z],[x,c.radius-.06,z+.07],.018,'edge',1);
    joint=`wheel_${idx}`;joints[joint]=pivot;
    tube('tire',[x-c.width/2,c.radius,z],[x+c.width/2,c.radius,z],c.radius,'rubber',0,c.radius*.6);
    tube('rim',[x-c.width*.48,c.radius,z],[x+c.width*.48,c.radius,z],c.radius*.62,'edge');
    tube('hub',[x-c.width*.49,c.radius,z],[x+c.width*.49,c.radius,z],c.radius*.22,'recess');
    const n=lod===0?20:12;
    for(let i=0;i<(heavy?0:n);i++){
      const a=i*Math.PI*2/n, y=c.radius+Math.sin(a)*c.radius*.95, zz=z+Math.cos(a)*c.radius*.95;
      tube('tread',[x-c.width*.46,y,zz],[x+c.width*.46,y,zz],c.radius*.045,'recess',1);
    }
    for(let i=0;i<6;i++){const a=i*Math.PI/3; tube('hub-bolt',[x-c.width*.5,c.radius+Math.sin(a)*c.radius*.42,z+Math.cos(a)*c.radius*.42],[x+c.width*.5,c.radius+Math.sin(a)*c.radius*.42,z+Math.cos(a)*c.radius*.42],.014,'recess',2);}
    joint='body';
  }
  // Source yaw rotates offsets about (0,0,0). Local coordinates still attach to
  // the native mount; adapter compensates its translation and hull pitch/roll.
  joint='turret';
  const gunY=c.source.muzzles[0].y;
  tube('turret-ring',[0,gunY-.23,0],[0,gunY-.15,0],heavy?.79:compact?.16:.31,'recess');
  if(heavy)loft('faceted-siege-receiver',[[-1,.62,1.24,1.65],[-.63,.85,1.22,1.78],[.18,.85,1.22,1.73],[.5,.59,1.27,1.6]]);
  else panel('receiver',[0,gunY-.04,-.16],[compact?.22:.55,.19,.42]);
  if(heavy){
    tube('commander-hatch',[0,1.69,-.35],[0,1.79,-.35],.38,'armor');
    panel('optic-housing',[.42,1.84,.12],[.27,.24,.35],'recess');
    panel('optic-window',[.42,1.87,.3],[.18,.09,.015],'lamp',1);
    for(const s of [-1,1])panel('turret-cheek',[s*.78,1.64,.18],[.23,.34,.87],'edge');
    tube('hatch-handle',[-.12,1.83,-.35],[.12,1.83,-.35],.022,'edge',1);
  }
  if(!compact)for(const s of [-1,1])panel('loader-case',[s*(heavy?.67:.3),gunY-.04,-.4],[heavy?.35:.19,.22,.35],'team_accent',1);
  for(const [i,p] of c.source.muzzles.entries()){
    const r=heavy?.12:compact?.025:.044;
    tube(`barrel-${i}`,[p.x,p.y,p.z-(heavy?1.3:.48)],[p.x,p.y,p.z],r,'edge',0,r*.68);
    tube(`barrel-jacket-${i}`,[p.x,p.y,p.z-(heavy?1.26:.44)],[p.x,p.y,p.z-.12],r*1.4,'recess',1,r*1.15);
    tube(`muzzle-collar-${i}`,[p.x,p.y,p.z-.045],[p.x,p.y,p.z],r*1.3,'edge',1,r*.68);
    tube(`gun-cradle-${i}`,[0,gunY-.1,-.22],[p.x,gunY-.1,p.z-.24],.035,'armor');
  }
  for(const s of [-1,1])tube('gun-grip',[s*.12,gunY-.07,-.45],[s*.12,gunY-.2,-.45],.022,'rubber',1);
  return {schema:1,kind,lod,units:'metres',forward:'+Z',up:'+Y',collision:'source-only',joints,parts,
    dimensions:c.source.dimensions,seats:seats.map(([name,p])=>({name,position:[p.x,p.y,p.z]})),
    muzzles:c.source.muzzles.map(p=>[p.x,p.y,p.z]),wheelRadius:c.radius,palette};
}

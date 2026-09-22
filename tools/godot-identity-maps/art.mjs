// Original procedural forms. Finite static triangles are shared by renderer and
// source ray/collision walls. No gameplay-floor flags on overhead architecture.
function geom(id,material){return {id,material,walkable:false,vertices:[],triangles:[]};}
function face(g,a,b,c,d){const i=g.vertices.length;g.vertices.push(a,b,c,d);g.triangles.push([i,i+1,i+2],[i,i+2,i+3]);}
function prism(g,points,depth){const front=points.map(p=>[p[0],p[1],p[2]-depth/2]),back=points.map(p=>[p[0],p[1],p[2]+depth/2]);face(g,...front);face(g,...back.slice().reverse());for(let i=0;i<4;i++)face(g,front[i],back[i],back[(i+1)%4],front[(i+1)%4]);}
function transform(g,at,yaw=0){const c=Math.cos(yaw),s=Math.sin(yaw);g.vertices=g.vertices.map(([x,y,z])=>[at[0]+x*c+z*s,at[1]+y,at[2]-x*s+z*c]);return g;}
function arch(id,material,at,rx,ry,width,depth,start=0,end=Math.PI,yaw=0){
 const g=geom(id,material),steps=Math.ceil((end-start)*12);
 for(let i=0;i<steps;i++){const a=start+(end-start)*i/steps,b=start+(end-start)*(i+1)/steps;prism(g,[[rx*Math.cos(a),ry*Math.sin(a),0],[(rx-width)*Math.cos(a),(ry-width)*Math.sin(a),0],[(rx-width)*Math.cos(b),(ry-width)*Math.sin(b),0],[rx*Math.cos(b),ry*Math.sin(b),0]],depth);}
 return transform(g,at,yaw);
}
function ribbon(id,at,width,length,fold,yaw){
 const g=geom(id,'accent');const strips=8;
 for(let i=0;i<strips;i++){
  const x0=-width/2+i*width/strips,x1=x0+width/strips,y0=i%2?fold:0,y1=i%2?0:fold;
  const a=[x0,y0,-length/2],b=[x1,y1,-length/2],c=[x1,y1+length*.32,length/2],d=[x0,y0+length*.32,length/2];
  face(g,a,b,c,d);face(g,d,c,b,a);
 }
 return transform(g,at,yaw);
}
export function art(r){
 const g=[];
 for(const s of r.arena.terrain.surfaces.filter(s=>s.id!=='court')){
  const infill=geom(s.id+'-infill','cut');
  for(let i=0;i<s.vertices.length;i++){
   const a=s.vertices[i],b=s.vertices[(i+1)%s.vertices.length],a0=[a[0],0,a[2]],b0=[b[0],0,b[2]];
   // Shared ramp/terrace join is internal, not an exposed wall.
   if(a[2]===-22&&b[2]===-22)continue;
   if(a[1]>0){const k=infill.vertices.length;infill.vertices.push(a,a0,b);infill.triangles.push([k,k+1,k+2]);}
   if(b[1]>0){const k=infill.vertices.length;infill.vertices.push(b,a0,b0);infill.triangles.push([k,k+1,k+2]);}
  }
  g.push(infill);
 }
 if(r.id==='lacuna-court'){
  for(const side of [-1,1]){
   g.push(arch(`split-resonator-${side}`,'shell',[side*5,5,side*3],4.3,7,1.2,2,-.2,Math.PI*1.15,Math.PI/2));
   g.push(arch(`indigo-receiver-${side}`,'enamel',[side*5+.05,5,side*3],3.15,5.6,.45,2.1,.05,Math.PI,Math.PI/2));
   g.push(arch(`copper-seam-${side}`,'accent',[side*5+.1,5,side*3],4.0,6.7,.09,2.14,0,Math.PI,Math.PI/2));
  }
  // Listening sail is outside combat bounds, never moving cover.
  g.push(arch('distant-sail','shell',[-10,12,-31],13,10,3,1,.15,Math.PI*.93,-.3));
  for(let i=0;i<8;i++)g.push(arch(`stratum-${i}`,'cut',[0,1+i*.65,-27],24,1+i*.05,.18,.3,0,Math.PI));
 }else if(r.id==='vermilion-fold'){
  for(let i=0;i<5;i++)g.push(ribbon(`crown-fold-${i}`,[0,8+i*.22,0],6,18,2.2,i*Math.PI*2/5));
  for(let i=0;i<3;i++)g.push(ribbon(`fan-${i}`,[0,7+i*.3,-17],5,15,1.6,(i-1)*.55));
  for(let i=0;i<4;i++)g.push(ribbon(`pleat-${i}`,[(i-1.5)*3,7,17],2.3,11,1.5,.2));
  for(const z of [-17,0,17])for(const side of [-1,1])g.push(arch(`ivory-tension-${z}-${side}`,'shell',[side*6,4,z],4,6,.3,.4,0,Math.PI,Math.PI/2));
 }else{
  for(let z=-24;z<=24;z+=8){g.push(arch(`vault-${z}`,'shell',[0,0,z],28,17,1.4,1.4));g.push(arch(`vault-inner-${z}`,'cut',[0,0,z+.85],26.5,15.5,.4,.3));}
  for(let z=-5;z<=5;z+=2){g.push(arch(`nacre-drum-${z}`,'shell',[0,8,z],5.9,5.5,1.3,1.5,0,Math.PI*2));g.push(arch(`drum-service-${z}`,'accent',[0,8,z+.8],4.45,4.0,.1,.2,0,Math.PI*2));}
 }
 return g;
}

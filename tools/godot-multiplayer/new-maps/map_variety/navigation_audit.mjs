// Candidate-only physical route evidence. No engine/physics modifications.
import {terrainTriangles, terrainSupportAt} from '../../../../game/terrain.mjs';
const cache = new WeakMap();
const CELL = 8, RADIUS = .42, HEAD = 1.8;
export function physicalIndex(arena) {
  if (cache.has(arena)) return cache.get(arena);
  const cells = new Map();
  const key = (x,z) => `${Math.floor(x/CELL)},${Math.floor(z/CELL)}`;
  const put = (kind, item, vertices) => {
    const xs=vertices.map(v=>v[0]), zs=vertices.map(v=>v[2]);
    for(let x=Math.floor((Math.min(...xs)-RADIUS)/CELL);x<=Math.floor((Math.max(...xs)+RADIUS)/CELL);x++)
      for(let z=Math.floor((Math.min(...zs)-RADIUS)/CELL);z<=Math.floor((Math.max(...zs)+RADIUS)/CELL);z++) {
        const k=`${x},${z}`;
        if(!cells.has(k)) cells.set(k,{surfaces:[],walls:[],boxes:[]});
        cells.get(k)[kind].push(item);
      }
  };
  for(const t of terrainTriangles(arena.terrain)) put('surfaces',{id:t.surfaceId,material:t.material,walkable:t.walkable,vertices:t.vertices,triangles:[[0,1,2]]},t.vertices);
  for(const wall of arena.terrain.walls??[]) put('walls',wall,wall.vertices);
  for(const b of [...(arena.blocks??[]).map(b=>({...b,minY:b.baseY??0,maxY:b.h})),...(arena.overhead??[])])
    put('boxes',b,[[b.x-b.w/2,b.minY,b.z-b.d/2],[b.x+b.w/2,b.maxY,b.z+b.d/2]]);
  const at=(x,z)=>cells.get(key(x,z))??{surfaces:[],walls:[],boxes:[]};
  const support=(x,z)=>terrainSupportAt(x,z,at(x,z),arena.terrain.maxSlope);
  const result={at,support};cache.set(arena,result);return result;
}
const distance=(x,z,a,b)=>{
  const dx=b[0]-a[0],dz=b[2]-a[2],d=dx*dx+dz*dz;
  const t=d?Math.max(0,Math.min(1,((x-a[0])*dx+(z-a[2])*dz)/d)):0;
  return Math.hypot(x-a[0]-t*dx,z-a[2]-t*dz);
};
function clipY(poly,y,above) {
  const out=[];
  for(let i=0;i<poly.length;i++) {
    const a=poly[i],b=poly[(i+1)%poly.length],da=(a[1]-y)*(above?1:-1),db=(b[1]-y)*(above?1:-1);
    if(da>=0)out.push(a);
    if((da<0&&db>0)||(da>0&&db<0)){const t=da/(da-db);out.push(a.map((v,k)=>v+(b[k]-v)*t));}
  }
  return out;
}
export function standingFailure(arena,x,z,y) {
  const index=physicalIndex(arena),cell=index.at(x,z);
  for(const b of cell.boxes) if(y+.05<b.maxY&&y+HEAD>b.minY&&Math.abs(x-b.x)<b.w/2+RADIUS&&Math.abs(z-b.z)<b.d/2+RADIUS) return `box:${b.id}`;
  for(const wall of cell.walls) {
    const polygon=clipY(clipY(wall.vertices,y+.16,true),y+HEAD,false);
    if(polygon.length>1&&polygon.some((a,i)=>distance(x,z,a,polygon[(i+1)%polygon.length])<RADIUS-1e-6))return `wall:${wall.id??'triangle'}`;
  }
  // Nonwalkable roofs (and other upper surfaces) must leave standing headroom.
  for(const surface of cell.surfaces) {
    const a=surface.vertices[0],b=surface.vertices[1],c=surface.vertices[2];
    const ny=(b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]);
    const ceiling=terrainSupportAt(x,z,{surfaces:[{...surface,walkable:true,triangles:[ny<0?[0,2,1]:[0,1,2]]}]});
    if(ceiling&&ceiling.y>y+.16&&ceiling.y<y+HEAD)return `ceiling:${surface.id}`;
  }
  return null;
}
export function traceRoute(arena,points,{spacing=.25,step=.3}={}) {
  const index=physicalIndex(arena),failures=[];let previous=null;
  const point=p=>Array.isArray(p)?{x:p[0],z:p[1]}:p;
  for(let j=1;j<points.length;j++) {
    const a=point(points[j-1]),b=point(points[j]),n=Math.max(1,Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/spacing));
    for(let i=0;i<=n;i++) {
      const t=i/n,x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t,support=index.support(x,z);
      const fail=reason=>failures.push({x,z,reason});
      if(!support){fail('unsupported');previous=null;continue;}
      const y=support.y;
      // Heights constrain authored waypoints; sparse endpoints do not imply
      // a single plane between them (the terrain can contain stairs/landings).
      if((i===0&&Number.isFinite(a.y)&&Math.abs(y-a.y)>.16)||(i===n&&Number.isFinite(b.y)&&Math.abs(y-b.y)>.16))fail('intended-height');
      if(previous&&Math.abs(previous.y-y)>step+Math.hypot(previous.x-x,previous.z-z)*Math.tan(arena.terrain.maxSlope??.8)+1e-6)fail('height-discontinuity');
      const obstruction=standingFailure(arena,x,z,y);if(obstruction)fail(obstruction);
      previous={x,y,z};
    }
  }
  return failures;
}

export function auditPhysicalRoutes(arena,base) {
  const old=new Map((base.routes??[]).map(r=>[r.id,r]));
  const failures=[],baseline=[];
  for(const route of arena.routes??[]) {
    const found=traceRoute(arena,route.points);
    const prior=old.get(route.id);
    // Report pre-existing defects explicitly; never count them as passing.
    const previous=prior?traceRoute(base,prior.points):[];
    baseline.push(...previous.map(f=>({route:route.id,...f})));
    const signature=f=>`${f.x.toFixed(3)},${f.z.toFixed(3)}:${f.reason.split(':')[0]}`;
    const known=new Set(previous.map(signature));
    failures.push(...found.filter(f=>!known.has(signature(f))).map(f=>({route:route.id,...f})));
    if(prior) {
      const before=physicalIndex(base),after=physicalIndex(arena);
      for(let j=1;j<prior.points.length;j++) {
        const asXZ=p=>Array.isArray(p)?p:[p.x,p.z];
        const a=asXZ(prior.points[j-1]),b=asXZ(prior.points[j]),n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/.25));
        for(let i=0;i<=n;i++){const x=a[0]+(b[0]-a[0])*i/n,z=a[1]+(b[1]-a[1])*i/n;
          if(Math.abs((before.support(x,z)?.y??NaN)-(after.support(x,z)?.y??NaN))>.16)failures.push({route:route.id,x,z,reason:'preserved-route-height-changed'});
        }
      }
    }
  }
  return {failures,baselineDefects:baseline};
}

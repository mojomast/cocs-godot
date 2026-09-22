import fs from 'node:fs';
import {Vector3} from 'three';
import {ConvexHull} from 'three/examples/jsm/math/ConvexHull.js';
import {floorAt, obstructed, walkEdge, navigation} from '../../game/core.mjs';
import {terrainSupportAt} from '../../game/terrain.mjs';
import {nativeArenaGeometryHash,parseNativeArena} from '../../port/native-arenas/schema.mjs';

const input=process.argv[2]??'/tmp/opencode/native-dm-colliders.json';
const output='godot/native_arenas/generated';
fs.mkdirSync(output,{recursive:true});
const round=n=>Math.round(n*1e6)/1e6;
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const normal=t=>{const n=cross(sub(t[1],t[0]),sub(t[2],t[0])),l=Math.hypot(...n);return n.map(v=>v/l);};
const area=t=>Math.hypot(...cross(sub(t[1],t[0]),sub(t[2],t[0])));
function hullTriangles(vertices){
  const hull=new ConvexHull().setFromPoints(vertices.map(p=>new Vector3(...p)));
  const groups=new Map();
  for(const face of hull.faces){
    const key=[face.normal.x,face.normal.y,face.normal.z,face.constant].map(v=>Math.round(v*1e5)).join(',');
    if(!groups.has(key))groups.set(key,{normal:face.normal.toArray(),points:[]});
    let edge=face.edge;do{groups.get(key).points.push(edge.head().point.toArray());edge=edge.next;}while(edge!==face.edge);
  }
  return [...groups.values()].map(({normal:n,points})=>{
    const axis=n.map(Math.abs).indexOf(Math.max(...n.map(Math.abs))),keep=[0,1,2].filter(i=>i!==axis);
    const lookup=new Map(points.map(p=>[`${p[keep[0]]},${p[keep[1]]}`,p]));
    let polygon=hullXZ(points.map(p=>[p[keep[0]],0,p[keep[1]]])).map(p=>lookup.get(`${p[0]},${p[1]}`));
    if(normal(polygon).reduce((s,v,i)=>s+v*n[i],0)<0)polygon.reverse();
    return polygon;
  });
}
function hullXZ(vertices){
  const points=[...new Map(vertices.map(p=>[`${p[0]},${p[2]}`,[p[0],p[2]]])).values()].sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
  const turn=(a,b,c)=>(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);
  const chain=ps=>{const out=[];for(const p of ps){while(out.length>1&&turn(out.at(-2),out.at(-1),p)<=1e-9)out.pop();out.push(p);}return out;};
  const lo=chain(points),hi=chain(points.slice().reverse());return lo.slice(0,-1).concat(hi.slice(0,-1));
}
function clip(poly,a,b,inside=true){
  const dist=p=>((b[0]-a[0])*(p[2]-a[1])-(b[1]-a[1])*(p[0]-a[0]))*(inside?1:-1),out=[];
  for(let i=0;i<poly.length;i++){const p=poly[i],q=poly[(i+1)%poly.length],dp=dist(p),dq=dist(q);if(dp>=-1e-8)out.push(p);if((dp>1e-8&&dq< -1e-8)||(dp< -1e-8&&dq>1e-8)){const t=dp/(dp-dq);out.push(p.map((v,k)=>v+(q[k]-v)*t));}}
  return out;
}
function subtractFootprint(poly,footprint){
  const out=[];let rest=poly;
  for(let i=0;i<footprint.length&&rest.length;i++){out.push(clip(rest,footprint[i],footprint[(i+1)%footprint.length],false));rest=clip(rest,footprint[i],footprint[(i+1)%footprint.length]);}
  return out.filter(p=>p.length>=3);
}
const specs={
  'prism-foundry':{name:'Prism Foundry DM',bounds:{minX:-36.4,maxX:36.6,minZ:-36.4,maxZ:18.5},voidY:-8,color:'#7ae1d9'},
  'aurora-basin':{name:'Aurora Basin DM',bounds:{minX:-42.5,maxX:42.5,minZ:-42.5,maxZ:42.5},voidY:-8,color:'#72d9dd'},
  'cinder-array':{name:'Cinder Array DM',bounds:{minX:-47,maxX:33,minZ:-37,maxZ:33},voidY:1,color:'#ffbd77'},
};

for(const source of JSON.parse(fs.readFileSync(input,'utf8'))){
  const spec=specs[source.id],bounds=spec.bounds;
  const boundary=[[bounds.minX,bounds.minZ],[bounds.maxX,bounds.minZ],[bounds.maxX,bounds.maxZ],[bounds.minX,bounds.maxZ]];
  const records=source.colliders.map(c=>({...c,low:[0,1,2].map(i=>Math.min(...c.vertices.map(v=>v[i]))),high:[0,1,2].map(i=>Math.max(...c.vertices.map(v=>v[i])))}));
  const solids=records.filter(c=>c.kind==='convex'&&!c.walkable).map(c=>({...c,footprint:hullXZ(c.vertices)}));
  const surfaces=[],walls=[],wallFaces=[];
  for(const collider of records){
    const triangles=collider.kind==='convex'?hullTriangles(collider.vertices):Array.from({length:collider.vertices.length/3},(_,i)=>[collider.vertices[i*3],collider.vertices[i*3+2],collider.vertices[i*3+1]]);
    const batches={true:{id:collider.id,material:'native',walkable:true,vertices:[],triangles:[]},false:{id:collider.id+'-solid',material:'native',walkable:false,vertices:[],triangles:[]}};
    const emit=(poly,walkable)=>{for(let i=1;i<poly.length-1;i++){let t=[poly[0],poly[i],poly[i+1]].map(p=>p.map(round));if(area(t)<1e-7)continue;const b=batches[walkable],start=b.vertices.length;b.vertices.push(...t);b.triangles.push([start,start+1,start+2]);}};
    for(const triangle of triangles){
      if(area(triangle)<1e-8)continue;
      const n=normal(triangle),walkable=collider.walkable&&n[1]>Math.cos(Math.PI/4);
      // Rays retain all native collision, including scenery beyond the playable
      // bounds. Only walkable support and movement-wall generation are clipped.
      emit(triangle,false);
      let polygon=triangle;
      for(let i=0;i<boundary.length;i++)polygon=clip(polygon,boundary[i],boundary[(i+1)%boundary.length]);
      if(polygon.length<3)continue;
      if(walkable){
        let pieces=[polygon];
        const lo=[0,1,2].map(i=>Math.min(...polygon.map(p=>p[i]))),hi=[0,1,2].map(i=>Math.max(...polygon.map(p=>p[i])));
        for(const solid of solids){
          if(solid.low[0]>hi[0]||solid.high[0]<lo[0]||solid.low[2]>hi[2]||solid.high[2]<lo[2]||solid.low[1]>hi[1]+1.8||solid.high[1]<lo[1]+0.2)continue;
          pieces=pieces.flatMap(p=>subtractFootprint(p,solid.footprint));
        }
        for(const p of pieces)emit(p,true);
      }
      if(Math.abs(n[1])<0.65)wallFaces.push({material:'native',vertices:polygon.map(p=>p.map(round)),source:collider.path});
    }
    for(const b of Object.values(batches))if(b.triangles.length)surfaces.push(b);
  }
  const arena={id:source.id,name:spec.name,description:'Native deathmatch adaptation; single-support routes with visible sealed foundations.',tag:'NATIVE / DM',color:spec.color,background:'#101b28',bounds,...bounds,nextGen:source.id==='aurora-basin',raised:false,voidY:spec.voidY,ceilingY:64,spawns:[],pickups:[],navNodes:[],blocks:[],terrain:{maxSlope:Math.PI/4,surfaces,walls}};
  // Source movement walls are segment-height bands, unlike triangle ray tests.
  // Split their projection into short face pieces, removing buried seams and
  // joins to nearby slope support. walkEdge still enforces source's 30cm step
  // limit independently; these movement bands never replace exact ray faces.
  const supportCache=new Map();
  const support=(x,z)=>{const key=`${round(x)},${round(z)}`;if(!supportCache.has(key))supportCache.set(key,terrainSupportAt(x,z,arena.terrain,Math.PI/4)?.y??null);return supportCache.get(key);};
  const wallStats=new Map();
  for(const face of wallFaces){
    const ps=face.vertices;let pair=[ps[0],ps[1]],length=0;
    for(const a of ps)for(const b of ps){const l=Math.hypot(a[0]-b[0],a[2]-b[2]);if(l>length){length=l;pair=[a,b];}}
    if(length<1e-6)continue;
    const [a,b]=pair,dx=(b[0]-a[0])/length,dz=(b[2]-a[2])/length,count=Math.ceil(length/.6);
    let previous=null;
    for(let i=0;i<count;i++){
      const lo=length*i/count,hi=length*(i+1)/count;
      const p=[a[0]+dx*lo,a[2]+dz*lo],q=[a[0]+dx*hi,a[2]+dz*hi];
      let piece=clip(ps,p,[p[0]+dz,p[1]-dx]);
      piece=clip(piece,q,[q[0]-dz,q[1]+dx]);
      if(piece.length<3)continue;
      const top=Math.max(...piece.map(p=>p[1]));
      let bottom=Math.min(...piece.map(p=>p[1]));
      const x=(p[0]+q[0])/2,z=(p[1]+q[1])/2;
      const left=support(x-dz*.6,z+dx*.6),right=support(x+dz*.6,z-dx*.6);
      if(left!==null&&right!==null&&Math.min(left,right)>=top-.65){previous=null;continue;}
      // One-sided burial: when a band's top sits within the source 30 cm step
      // limit of the walkable support on an adjacent side, an actor standing
      // there is never meant to be blocked (floorAt resolves the step), yet
      // source moveActor refuses every axis step from inside the 0.42 m
      // contact band: a landing there is a permanent trap. Sample the lowest
      // walkable support within the contact reach (including just past both
      // piece ends) and drop bands buried on either side. This is the class
      // that froze a live prism bot for 71 s on the west ramp skirt.
      // Perpendicular samples stay inside the source contact radius (0.42):
      // support past it can never make a standable point that the band blocks.
      // The along-piece extensions cover a mover reaching past either end.
      const sideMin=(nx,nz)=>{
        let low=null;
        for(const [sx,sz] of [[p[0]+nx*.15,p[1]+nz*.15],[p[0]+nx*.3,p[1]+nz*.3],[p[0]+nx*.42,p[1]+nz*.42],
          [q[0]+nx*.15,q[1]+nz*.15],[q[0]+nx*.3,q[1]+nz*.3],[q[0]+nx*.42,q[1]+nz*.42],
          [(p[0]+q[0])/2+nx*.3,(p[1]+q[1])/2+nz*.3],
          [p[0]-dx*.45+nx*.3,p[1]-dz*.45+nz*.3],[q[0]+dx*.45+nx*.3,p[1]+dz*.45+nz*.3]]){
          const s=support(sx,sz);if(s!==null)low=low===null?s:Math.min(low,s);
        }
        return low;
      };
      const leftLow=sideMin(-dz,dx),rightLow=sideMin(dz,-dx);
      // `low < top` keeps flat-topped sealed volumes (support level equals the
      // band top) blocking their own interior, which the delivery probes assert.
      // A flat-topped *short* solid (a raised platform edge, <= 1.5 m tall) is
      // instead a step: dropping the band is safe because the destination floor
      // is the walkable top (> 30 cm) and the source step limit refuses it.
      // Walkable-topped low barriers (kerbs, guard rails adapted for DM) carry
      // their own support: the source step limit refuses crossing, so the band
      // is redundant. Probe just inside either face so a point sample on the
      // seam still sees the cap.
      let atMid=-Infinity;
      for(const ox of [0,.15,-.15])for(const oz of [0,.15,-.15])atMid=Math.max(atMid,support(x+ox,z+oz)??-Infinity);
      const flatShort=(side)=>side!==null&&side<=top+1e-6&&top-side<=.3&&top-bottom<=2.2;
      const cappedShort=atMid>=top-.3&&top-bottom<=2.2;
      if((leftLow!==null&&leftLow<top-1e-6&&top-leftLow<=.3)||(rightLow!==null&&rightLow<top-1e-6&&top-rightLow<=.3)||flatShort(leftLow)||flatShort(rightLow)||cappedShort){previous=null;continue;}
      // Terrace skirt: a band whose inner side is walkable support at its own
      // top level is a solid volume that stands under a walkable terrace
      // (service banks, crown buttresses). Entry from the lower side is already
      // refused by the source step limit (the destination floor is the terrace
      // top), so the lower part of the band only creates an inescapable strip
      // where live bots land. Raise the band's bottom to the lower standing
      // level + body height; the band still blocks jumps and interior probes.
      // Sample several offsets per side: a pier or another solid standing in
      // front of the face must not hide the terrace or the lower floor behind
      // it. The highest and lowest walkable supports among those samples are
      // the terrace top and the lower standing level.
      let sideAbove=-Infinity,sideBelow=Infinity;
      for(const [nx,nz] of [[-dz,dx],[dz,-dx]])for(const distance of [.2,.5,.9,1.4]){
        for(const [sx,sz] of [[x+nx*distance,z+nz*distance],[p[0]+nx*distance,p[1]+nz*distance],[q[0]+nx*distance,q[1]+nz*distance]]){
          const s=support(sx,sz);if(s===null)continue;
          sideAbove=Math.max(sideAbove,s);sideBelow=Math.min(sideBelow,s);
        }
      }
      if(Number.isFinite(sideAbove)&&Number.isFinite(sideBelow)&&sideAbove>=top-.3&&sideAbove-sideBelow>1.85){
        const raised=sideBelow+1.85;
        if(raised>=top-1e-5){previous=null;continue;}
        if(raised>bottom)bottom=raised;
      } else {
        // Overhang skirt: a band whose bottom sits above a lower walkable
        // floor but within a body height of it blocks actors standing on that
        // floor, and a landing there can never escape (the wall is taller than
        // a jump). Raise the bottom to the lower standing level + body height:
        // floor-level movers stop being blocked (the wall is above them), while
        // jumping movers and the ramp side still collide. Bands whose top does
        // not clear that height are left alone so low cover stays solid.
        const lo=Math.min(left??Infinity,right??Infinity);
        if(Number.isFinite(lo)&&bottom>lo+1e-6&&bottom<lo+1.8-1e-6&&top>lo+1.85+1e-6)bottom=lo+1.85;
      }
      if(top-bottom<1e-5)continue;
      // Two-point terrain walls are movement proxies only. Full faces above
      // carry bullet, projectile, splash, ceiling and native ray collision.
      const wall={a:[round(p[0]),round(bottom),round(p[1])],b:[round(q[0]),round(top),round(q[1])],material:'native'};
      if(previous&&previous.a[1]===wall.a[1]&&previous.b[1]===wall.b[1]&&previous.b[0]===wall.a[0]&&previous.b[2]===wall.a[2])previous.b=wall.b;
      else{walls.push(wall);previous=wall;wallStats.set(face.source,(wallStats.get(face.source)??0)+1);}
    }
  }
  if(process.env.NATIVE_DM_WALL_STATS==='1')console.log('WALL_STATS',source.id,JSON.stringify([...wallStats].sort((a,b)=>b[1]-a[1]).slice(0,25)));
  const safe=(x,z,r=.65)=>{const y=floorAt(x,z,arena);return y!==null&&!obstructed(x,y,z,r,arena);};
  const point=(x,z)=>({x:round(x),y:round(floorAt(x,z,arena)),z:round(z)});
  const routes=source.routes.map(route=>{
    const points=[];
    for(let i=0;i<route.points.length-1;i++){
      const a=route.points[i],b=route.points[i+1],count=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[2]-a[2])/1.5));
      for(let j=0;j<count;j++){const t=j/count,x=round(a[0]+(b[0]-a[0])*t),z=round(a[2]+(b[2]-a[2])*t);points.push(point(x,z));}
    }
    const last=route.points.at(-1);points.push(point(last[0],last[2]));return {id:route.id,points};
  });
  // Keep the dense physics-probe routes, but remove redundant navigation nodes
  // only when the unchanged source walker proves the <=3m chord is traversable.
  // Sharp corners and narrow joins retain a node automatically.
  arena.navNodes=source.id==='aurora-basin'?routes.flatMap(route=>{
    const selected=[route.points[0]];let previous=route.points[0];
    for(const p of route.points.slice(1)){
      const last=selected.at(-1);
      if(Math.hypot(p.x-last.x,p.z-last.z)>3||!walkEdge(last,p,arena))selected.push(previous);
      previous=p;
    }
    selected.push(previous);
    return selected.filter(p=>safe(p.x,p.z)).map(p=>[p.x,p.z]);
  }):routes.flatMap(r=>r.points.filter(p=>safe(p.x,p.z)).map(p=>[p.x,p.z]));
  const spawnPoints=source.spawns.map(p=>point(p[0],p[2]));
  arena.spawns=spawnPoints.map(p=>[p.x,p.z]);
  // Source Pulse is the infinite-ammo starter; nine collectible weapons plus
  // ammunition cover the complete ten-weapon arsenal without inventing a kind.
  const kinds=['rocket','rail','scatter','plasma','grenade','shock','flak','marksman','smg','ammo','health','health','health','armor','armor','armor'];
  const candidates=routes.flatMap(r=>r.points).filter(p=>safe(p.x,p.z));
  const selected=[];
  for(let i=0;i<kinds.length;i++){
    let best=null,score=-1;
    for(const p of candidates){const distance=selected.length?Math.min(...selected.map(q=>Math.hypot(p.x-q.x,p.z-q.z))):Math.hypot(p.x,p.z);if(distance>score){best=p;score=distance;}}
    if(!best)throw new Error('No safe pickup point '+source.id);
    selected.push(best);arena.pickups.push([kinds[i],best.x,best.z]);
  }
  const geometryHash=nativeArenaGeometryHash(arena);
  const data={schemaVersion:1,id:source.id,name:spec.name,geometryHash,arena,spawnPoints,routes,colliderSources:records.map(({vertices,...record})=>({...record,vertexCount:vertices.length})),provenance:{godot:'4.5.2.stable.official.6ce3de25a',compiler:'tools/godot-native-arenas/compile.mjs',input:'strict native CollisionShape3D dump',supportModel:'highest walkable XZ support; no stacked walk-under/walk-over'}};
  // Validate through the delivered authority's actual public schema before
  // replacing an asset. No independent lookalike validator can mask drift.
  parseNativeArena(data,source.id);
  const badSpawns=spawnPoints.filter(p=>!safe(p.x,p.z));
  const badRoutes=routes.map(r=>({id:r.id,blocked:r.points.filter(p=>!safe(p.x,p.z)).length,broken:r.points.slice(1).filter((p,i)=>!walkEdge(r.points[i],p,arena)).length}));
  console.log(source.id,JSON.stringify({colliders:records.length,surfaces:surfaces.length,walls:walls.length,badSpawns,badRoutes}));
  if(badSpawns.length||badRoutes.some(r=>r.blocked||r.broken))throw new Error(`Unsafe authored route/spawn in ${source.id}; previous generated asset retained`);
  fs.writeFileSync(`${output}/${source.id}.json`,JSON.stringify(data)+'\n');
  if(process.env.NATIVE_DM_GRAPH==='1'){
    const graph=navigation(arena),seen=new Set(),components=[];
    for(let i=0;i<graph.nodes.length;i++)if(!seen.has(i)){const queue=[i];seen.add(i);for(let j=0;j<queue.length;j++)for(const k of graph.edges[queue[j]])if(!seen.has(k)){seen.add(k);queue.push(k);}components.push(queue.map(j=>graph.nodes[j]));}
    console.log('GRAPH',source.id,graph.nodes.length,components.map(c=>c.length).sort((a,b)=>b-a));
    fs.writeFileSync(`/tmp/opencode/${source.id}-graph.json`,JSON.stringify(components));
  }
}

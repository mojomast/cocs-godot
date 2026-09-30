import {readFileSync} from 'node:fs';
import {nativeArenaGeometryHash} from '../native-arenas/schema.mjs';

export const CAMPAIGN_MAP_IDS = Object.freeze(['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array']);
const grids=new WeakMap();
const fail=label=>{throw new TypeError(`Invalid campaign map: ${label}`);};
const num=(n,a=-1024,b=1024)=>{if(typeof n!=='number'||!Number.isFinite(n)||n<a||n>b)fail('number');};
const list=(v,min,max)=>{if(!Array.isArray(v)||v.length<min||v.length>max)fail('list');};
const keys=(v,names)=>{if(!v||typeof v!=='object'||Array.isArray(v)||![Object.prototype,null].includes(Object.getPrototypeOf(v))||Object.keys(v).some(k=>!names.includes(k))||names.some(k=>!(k in v)))fail('keys');};
const text=v=>{if(typeof v!=='string'||v.length<1||v.length>256||/[\x00-\x1f\x7f]/.test(v))fail('text');};
const materials=['ground','trail','rock','stone','metal','light','foliage','water'];
const vector=v=>{list(v,3,3);v.forEach(n=>num(n));};
const gridKey=(x,z)=>`${x},${z}`;

// Strict regular single-sheet format: validates cell coverage, consistent shared
// heights and precisely the same diagonal used by the source's terrain reader.
// Chunking/material splits can change freely without hardcoding any map bounds.
function indexGrid(arena) {
  const {minX,maxX,minZ,maxZ}=arena.bounds,first=arena.terrain.surfaces[0]?.vertices;
  const step=first?.[1]?.[2]-first?.[0]?.[2],heights=new Map(),cells=new Set();
  if(![2,4].includes(step))fail('reviewed terrain resolution');
  for(const s of arena.terrain.surfaces) {
    keys(s,['id','material','walkable','vertices','triangles']);text(s.id);
    if(!materials.includes(s.material)||s.walkable!==true)fail('surface material/walkable');
    list(s.vertices,4,1024);list(s.triangles,2,512);
    if(s.vertices.length%4||s.triangles.length!==s.vertices.length/2)fail('cell topology');
    for(let i=0;i<s.vertices.length;i+=4) {
      const vs=s.vertices.slice(i,i+4);vs.forEach(vector);const [x,,z]=vs[0];
      if(x<minX||x>=maxX||z<minZ||z>=maxZ||(x-minX)%step||(z-minZ)%step)fail('cell bounds');
      const expected=[[x,z],[x,z+step],[x+step,z+step],[x+step,z]];
      vs.forEach((p,j)=>{if(p[0]!==expected[j][0]||p[2]!==expected[j][1])fail('cell vertices');const k=gridKey(p[0],p[2]);if(heights.has(k)&&heights.get(k)!==p[1])fail('terrain seam');heights.set(k,p[1]);});
      if(JSON.stringify(s.triangles[i/2])!==JSON.stringify([i,i+1,i+2])||JSON.stringify(s.triangles[i/2+1])!==JSON.stringify([i,i+2,i+3]))fail('cell diagonal/winding');
      const k=gridKey(x,z);if(cells.has(k))fail('overlapping cell');cells.add(k);
    }
  }
  if(cells.size!==(maxX-minX)*(maxZ-minZ)/(step*step))fail('terrain holes');
  const grid={heights,step};grids.set(arena,grid);return grid;
}

export function campaignSupportAt(arena,x,z) {
  const {heights,step}=grids.get(arena)??indexGrid(arena),{minX,maxX,minZ,maxZ}=arena.bounds;
  if(!Number.isFinite(x)||!Number.isFinite(z)||x<minX||x>maxX||z<minZ||z>maxZ)return null;
  const ix=Math.min(maxX-step,Math.floor((x-minX)/step)*step+minX),iz=Math.min(maxZ-step,Math.floor((z-minZ)/step)*step+minZ),u=(x-ix)/step,v=(z-iz)/step;
  const a=heights.get(gridKey(ix,iz)),b=heights.get(gridKey(ix,iz+step)),c=heights.get(gridKey(ix+step,iz+step)),d=heights.get(gridKey(ix+step,iz));
  const dx=(v>=u?c-b:d-a)/step,dz=(v>=u?b-a:c-d)/step;
  if(Math.atan(Math.hypot(dx,dz))>arena.terrain.maxSlope+1e-8)return null;
  return {y:v>=u?a+(c-b)*u+(b-a)*v:a+(d-a)*u+(c-d)*v,normal:[-dx,1,-dz].map(n=>n/Math.hypot(dx,1,dz))};
}

export function parseCampaignMap(input,expectedId) {
  if(typeof input==='string'||Buffer.isBuffer(input)) {if(Buffer.byteLength(input)>12*1024*1024)fail('file size');input=JSON.parse(String(input));}
  // Inspect caller objects before cloning: JSON serialization must not silently
  // turn NaN/Infinity into null, invoke custom serializers, or drop extra keys.
  let budget=1600000;
  const json=(v,depth=0)=>{if(--budget<0||depth>14)fail('complexity');if(v===null||typeof v==='boolean')return;if(typeof v==='number'){num(v,-1e8,1e8);return;}if(typeof v==='string'){if(v.length>4096)fail('string size');return;}if(Array.isArray(v)){v.forEach(p=>json(p,depth+1));return;}if(!v||typeof v!=='object'||![Object.prototype,null].includes(Object.getPrototypeOf(v)))fail('JSON value');for(const [k,p]of Object.entries(v)){if(['__proto__','prototype','constructor'].includes(k))fail('JSON key');json(p,depth+1);}};
  json(input);const data=structuredClone(input);
  keys(data,['schemaVersion','id','name','geometryHash','arena','palette','art','routes','spawnPoints','cameras','campaign']);
  const index=CAMPAIGN_MAP_IDS.indexOf(data.id);if(index<0||expectedId!==undefined&&data.id!==expectedId||data.schemaVersion!==1)fail('identity');text(data.name);
  const a=data.arena;
  keys(a,['id','name','description','bounds','spawns','pickups','navNodes','blocks','terrain','voidY','ceilingY','raised','nextGen']);
  if(a.id!==data.id||a.name!==data.name||a.raised!==false||a.nextGen!==true)fail('arena identity');text(a.description);
  keys(a.bounds,['minX','maxX','minZ','maxZ']);Object.values(a.bounds).forEach(n=>num(n,-256,256));
  for(const axis of ['X','Z']) {const extent=a.bounds[`max${axis}`]-a.bounds[`min${axis}`];if(extent<224||extent>512||extent%4)fail('bounds extent');}
  num(a.voidY,-128,0);num(a.ceilingY,64,256);
  keys(a.terrain,['maxSlope','surfaces','walls']);num(a.terrain.maxSlope,.1,.7);list(a.terrain.surfaces,1,1024);list(a.terrain.walls,0,0);indexGrid(a);
  list(a.blocks,0,1024);const blockIds=new Set();
  for(const b of a.blocks){keys(b,['id','x','z','w','d','baseY','h','material']);text(b.id);if(blockIds.has(b.id)||!materials.includes(b.material))fail('block identity');blockIds.add(b.id);num(b.x,a.bounds.minX,a.bounds.maxX);num(b.z,a.bounds.minZ,a.bounds.maxZ);num(b.w,.1,512);num(b.d,.1,512);if(b.baseY!==0)fail('source blocks require grounded base');num(b.h,.01,256);if(b.x-b.w/2<a.bounds.minX-.001||b.x+b.w/2>a.bounds.maxX+.001||b.z-b.d/2<a.bounds.minZ-.001||b.z+b.d/2>a.bounds.maxZ+.001)fail('block footprint');}
  const supported=(x,z,y)=>{const s=campaignSupportAt(a,x,z);if(!s||s.y<=a.voidY||y!==undefined&&Math.abs(y-s.y)>.001)fail(`unsupported feet at ${x},${z}`);const block=a.blocks.find(b=>Math.abs(x-b.x)<b.w/2+.65&&Math.abs(z-b.z)<b.d/2+.65&&b.h>s.y+.15&&b.baseY<s.y+1.8);if(block)fail(`blocked feet at ${x},${z}: ${block.id}`);return s.y;};
  for(const field of ['spawns','navNodes']) {list(a[field],1,4096);for(const p of a[field]){list(p,2,2);p.forEach(n=>num(n));supported(...p);}}
  list(a.pickups,1,128);for(const p of a.pickups){list(p,3,3);if(!['health','armor','ammo','scatter','rocket','rail','plasma','megahealth'].includes(p[0]))fail('pickup kind');num(p[1]);num(p[2]);supported(p[1],p[2]);}
  const point=(p,radius=false)=>{keys(p,radius?['x','y','z','radius']:['x','y','z']);num(p.x);num(p.y);num(p.z);if(radius)num(p.radius,1,32);supported(p.x,p.z,p.y);};
  list(data.spawnPoints,a.spawns.length,a.spawns.length);data.spawnPoints.forEach((p,i)=>{point(p);if(p.x!==a.spawns[i][0]||p.z!==a.spawns[i][1])fail('spawn mismatch');});
  list(data.routes,6,32);const ids=new Set();
  for(const r of data.routes){keys(r,['id','points']);text(r.id);if(ids.has(r.id))fail('route identity');ids.add(r.id);list(r.points,2,2048);r.points.forEach(p=>point(p));for(let i=1;i<r.points.length;i++){const p=r.points[i-1],q=r.points[i],d=Math.hypot(q.x-p.x,q.z-p.z);if(d>4.1||d<.001||Math.abs(q.y-p.y)/d>Math.tan(a.terrain.maxSlope))fail('route continuity');for(const t of [.25,.5,.75])supported(p.x+(q.x-p.x)*t,p.z+(q.z-p.z)*t);}}
  keys(data.campaign,['index','targetSeconds','criticalPath','anchors','nextMapId']);const c=data.campaign;
  if(c.index!==index||c.nextMapId!==(CAMPAIGN_MAP_IDS[index+1]??null)||JSON.stringify(c.targetSeconds)!=='[300,600]')fail('campaign order/timing');
  if(JSON.stringify(c.criticalPath)!==JSON.stringify(data.routes.find(r=>r.id==='critical-path')?.points))fail('critical path');
  const anchorKeys=['start',...Array.from({length:5},(_,i)=>`encounter-${i+1}`),'exit'];keys(c.anchors,anchorKeys);anchorKeys.forEach(k=>point(c.anchors[k],true));
  if(['x','y','z'].some(k=>c.anchors.start[k]!==c.criticalPath[0][k]||c.anchors.exit[k]!==c.criticalPath.at(-1)[k]))fail('endpoints');
  const cumulative=[0];for(let i=1;i<c.criticalPath.length;i++){const p=c.criticalPath[i-1],q=c.criticalPath[i];cumulative.push(cumulative.at(-1)+Math.hypot(q.x-p.x,q.y-p.y,q.z-p.z));}
  if(cumulative.at(-1)<900||cumulative.at(-1)>1500)fail('ordered route budget');
  let previous=0;
  for(let i=1;i<=5;i++){if(!ids.has(`encounter-${i}-supply-loop`))fail('fight loop');const p=c.anchors[`encounter-${i}`];let nearest=Infinity,at=0;c.criticalPath.forEach((q,j)=>{const distance=Math.hypot(p.x-q.x,p.z-q.z);if(distance<nearest){nearest=distance;at=cumulative[j];}});if(nearest>=6||at-previous<(i===1?70:90))fail('anchor connectivity/order/spacing');previous=at;}
  list(data.palette,6,6);if(data.palette.some(p=>typeof p!=='string'||! /^[a-fA-F0-9]{6}$/.test(p)))fail('palette');
  list(data.art,1,1600);for(const p of data.art){keys(p,['kind','material','position','scale']);if(!['tree','crag','beacon','dish','fallen-relay','fern','water','pipe'].includes(p.kind)||!materials.includes(p.material))fail('prop kind');vector(p.position);vector(p.scale);p.scale.forEach(n=>num(n,.01,32));num(p.position[0],a.bounds.minX,a.bounds.maxX);num(p.position[2],a.bounds.minZ,a.bounds.maxZ);}
  list(data.cameras,1,8);for(const c of data.cameras){keys(c,['id','at','target']);text(c.id);vector(c.at);vector(c.target);}
  if(typeof data.geometryHash!=='string'||!/^[a-f0-9]{64}$/.test(data.geometryHash)||data.geometryHash!==nativeArenaGeometryHash(a))fail('geometry hash');
  return data;
}

export function loadCampaignMap(id) {
  if(!CAMPAIGN_MAP_IDS.includes(id))throw new RangeError(`Unknown campaign map: ${id}`);
  return parseCampaignMap(readFileSync(new URL(`../../godot/campaign/generated/${id}.json`,import.meta.url)),id);
}

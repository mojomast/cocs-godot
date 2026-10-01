// Campaign-only weapon cover. Movement keeps the reviewed source block contract;
// shots/swept projectiles use the actual closed imported facade, not its empty
// containing AABB. Frozen source and every other mode keep their own rayWorld.
import {readFileSync} from 'node:fs';
import {rayWorld} from '../../game/core.mjs';
import {bakeTerrainBvh,terrainRayHitFast} from '../../game/terrain-bvh.mjs';

const prototypes=new Map();
let baked;
export function facadeTriangles(key) {
  baked??=JSON.parse(readFileSync(new URL('./structure-faces.json',import.meta.url)));
  if(!baked.models[key])throw Error(`Unbaked facade ${key}`);
  return baked.models[key].faces;
}
export function styleFor(index,id) {
  if(index===0)return id.includes('Fallen relay')||id.includes('gate')?'relay':'outpost';
  if(index===1)return id.startsWith('bridgeworks')?'abutment':'pump';
  if(index===2)return id.startsWith('basalt')?'uplink':'refinery';
  return id.startsWith('crown')?'receiver':'gate';
}

// Read committed glTF triangle bytes, with the node transform applied. Deliberate
// strict subset: reject new topology/transforms rather than silently drifting.
// No Blender, Godot imports, runtime filesystem writes or generated collider art.
export function readImportedTriangles(key) {
  const bytes=readFileSync(new URL(`../../godot/campaign/art/structures/${key}-0.glb`,import.meta.url));
  if(bytes.readUInt32LE(0)!==0x46546c67||bytes.readUInt32LE(4)!==2)throw Error('Expected glTF 2 GLB');
  const length=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+length));
  const binary=bytes.subarray(28+length);
  function accessor(id) {
    const a=doc.accessors[id],view=doc.bufferViews[a.bufferView];
    const count={SCALAR:1,VEC3:3}[a.type],size={5123:2,5125:4,5126:4}[a.componentType];
    if(!count||!size||a.sparse||view.buffer!==0)throw Error('Unsupported facade accessor');
    const offset=(view.byteOffset??0)+(a.byteOffset??0),stride=view.byteStride??count*size;
    return Array.from({length:a.count},(_,i)=>Array.from({length:count},(_,j)=>{
      const at=offset+i*stride+j*size;
      return a.componentType===5126?binary.readFloatLE(at):size===2?binary.readUInt16LE(at):binary.readUInt32LE(at);
    }));
  }
  const faces=[];
  for(const node of doc.nodes) {
    if(node.mesh===undefined||node.children||node.matrix||node.translation||node.scale)throw Error('Unexpected facade hierarchy');
    const q=node.rotation??[0,0,0,1],norm=Math.hypot(...q),[x,y,z,w]=q.map(v=>v/norm);
    const rotate=([px,py,pz])=>{
      const tx=2*(y*pz-z*py),ty=2*(z*px-x*pz),tz=2*(x*py-y*px);
      return [px+w*tx+y*tz-z*ty,py+w*ty+z*tx-x*tz,pz+w*tz+x*ty-y*tx];
    };
    for(const p of doc.meshes[node.mesh].primitives) {
      if(p.mode!==undefined&&p.mode!==4)throw Error('Expected triangle facade');
      const vertices=accessor(p.attributes.POSITION).map(rotate),indices=accessor(p.indices).flat();
      for(let i=0;i<indices.length;i+=3)faces.push(indices.slice(i,i+3).map(j=>vertices[j]));
    }
  }
  return faces;
}
function prototype(key) {
  if(!prototypes.has(key)) {
    const faces=facadeTriangles(key).filter(([a,b,c])=>{
      const u=b.map((v,i)=>v-a[i]),v=c.map((v,i)=>v-a[i]);
      return Math.hypot(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])>1e-9;
    });
    const terrain={surfaces:[],walls:faces.map((vertices,i)=>({id:`${key}/${i}`,vertices,triangles:[[0,1,2]],material:'metal'}))};
    prototypes.set(key,bakeTerrainBvh(terrain));
  }
  return prototypes.get(key);
}
export function structurePlacements(data) {
  const result=[];
  // Match terrain.gd height_at exactly, including steep, non-walkable samples.
  const heights=new Map();
  for(const surface of data.arena.terrain.surfaces)for(const [x,y,z] of surface.vertices)heights.set(`${x},${z}`,y);
  const first=data.arena.terrain.surfaces[0].vertices,step=first[1][2]-first[0][2];
  const heightAt=(x,z)=>{
    const {minX,maxX,minZ,maxZ}=data.arena.bounds;
    if(x<minX||x>maxX||z<minZ||z>maxZ)return NaN;
    const ix=Math.min(maxX-step,Math.floor((x-minX)/step)*step+minX),iz=Math.min(maxZ-step,Math.floor((z-minZ)/step)*step+minZ);
    const u=(x-ix)/step,v=(z-iz)/step,a=heights.get(`${ix},${iz}`),b=heights.get(`${ix},${iz+step}`),c=heights.get(`${ix+step},${iz+step}`),d=heights.get(`${ix+step},${iz}`);
    return v>=u?a+(c-b)*u+(b-a)*v:a+(d-a)*u+(c-d)*v;
  };
  for(const block of data.arena.blocks) {
    if(block.material==='rock')continue;
    let ground=Infinity;
    for(const u of [-.5,0,.5])for(const v of [-.5,0,.5]) {
      const y=heightAt(block.x+u*block.w,block.z+v*block.d);
      if(Number.isFinite(y))ground=Math.min(ground,y);
    }
    const base=Number.isFinite(ground)?Math.max(block.baseY,Math.min(block.h-.5,ground-.25)):block.baseY;
    const style=styleFor(data.campaign.index,block.id),exposed=block.h-base;
    const count=['relay','outpost'].includes(style)?1:Math.max(1,Math.ceil(exposed/5));
    for(let i=0;i<count;i++)result.push({block,key:`${style}-${i===count-1?'top':i===0?'base':'shaft'}`,
      origin:{x:block.x,y:base+exposed*i/count,z:block.z},scale:{x:block.w,y:exposed/count,z:block.d}});
  }
  return result;
}
export function createStructureRay(data) {
  const placements=structurePlacements(data).map(p=>({...p,bvh:prototype(p.key)}));
  const arena={...data.arena,blocks:data.arena.blocks.filter(b=>b.material==='rock')};
  return (origin,direction,max=100)=>{
    let best=rayWorld(origin,direction,max,arena);
    if(best===0)return best;
    for(const p of placements) {
      const o={},d={};
      for(const axis of ['x','y','z']){o[axis]=(origin[axis]-p.origin[axis])/p.scale[axis];d[axis]=direction[axis]/p.scale[axis];}
      // Source BVH accepts nonunit directions and returns the same ray parameter.
      const hit=terrainRayHitFast(p.bvh,o,d,best);
      if(hit&&hit.distance<best)best=hit.distance;
    }
    return best;
  };
}

// Conservative broadphase only: callers retain the locked narrowphase verbatim.
// Key by terrainWallSegments' array, not terrain: stampTerrainFloor invalidates
// that array, so rebuilding terrain cannot reuse an obsolete index.
const cache=new WeakMap(),CELL=8,PAD=1e-7,LIMIT=1e6,MAX_CELLS=4096;
const safe=n=>Number.isFinite(n)&&Math.abs(n)<=LIMIT;
function range(minX,maxX,minZ,maxZ){
  if(![minX,maxX,minZ,maxZ].every(safe))return null;
  const box=[Math.floor((minX-PAD)/CELL),Math.floor((maxX+PAD)/CELL),Math.floor((minZ-PAD)/CELL),Math.floor((maxZ+PAD)/CELL)];
  return (box[1]-box[0]+1)*(box[3]-box[2]+1)<=MAX_CELLS?box:null;
}
function index(segments){
  const buckets=new Map(),global=[];
  segments.forEach(({a,b},i)=>{
    const box=range(Math.min(a.x,b.x),Math.max(a.x,b.x),Math.min(a.z,b.z),Math.max(a.z,b.z));
    // Extreme/very long segments stay eligible for every query.
    if(!box){global.push(i);return;}
    for(let x=box[0];x<=box[1];x++)for(let z=box[2];z<=box[3];z++){
      const key=`${x},${z}`;
      let bucket=buckets.get(key);if(!bucket){bucket=[];buckets.set(key,bucket);}bucket.push(i);
    }
  });
  return {buckets,global};
}
export function wallCandidates(segments,x,z,r){
  // Unusual numeric inputs use the original full scan and its exact behavior.
  if(!safe(x)||!safe(z)||!safe(r)||r<0)return segments;
  const box=range(x-r,x+r,z-r,z+r);if(!box)return segments;
  let data=cache.get(segments);if(!data){data=index(segments);cache.set(segments,data);}
  const ids=new Set(data.global);
  for(let cx=box[0];cx<=box[1];cx++)for(let cz=box[2];cz<=box[3];cz++)
    for(const i of data.buckets.get(`${cx},${cz}`)||[])ids.add(i);
  // Preserve original .some order; no graph/route tie-breaking changes.
  return [...ids].sort((a,b)=>a-b).map(i=>segments[i]);
}

// Read-only route/nav/spawn/objective sampling using frozen U height policy.
// Writes only stdout; botanical-stage/probes.mjs main is guarded by import URL.
import {readFileSync} from 'node:fs';
import {physicalIndex} from '../map_variety/navigation_audit.mjs';
const old=JSON.parse(readFileSync('port/new-maps/helix-conservatory/variety/revision-3/authority.json')).arena;
const index=physicalIndex(old),points=[];
for(const r of old.routes)for(let j=1;j<r.points.length;j++) {
  const point=p=>Array.isArray(p)?{x:p[0],z:p[1]}:p;
  const a=point(r.points[j-1]),b=point(r.points[j]),n=Math.ceil(Math.hypot(b.x-a.x,b.z-a.z)/.25);
  for(let i=0;i<=n;i++) {
    const x=a.x+(b.x-a.x)*i/n,z=a.z+(b.z-a.z)*i/n,y=index.support(x,z)?.y;
    if(!Number.isFinite(y))throw new Error('Missing U source support');
    points.push({id:r.id,x,y,z});
  }
}
for(const p of old.navNodes) {
  const x=p.x??p[0],z=p.z??p[1],y=p.y??index.support(x,z)?.y;
  if(!Number.isFinite(y))throw new Error('Missing old nav support');
  points.push({id:'nav',x,y,z});
}
console.log(JSON.stringify(points));

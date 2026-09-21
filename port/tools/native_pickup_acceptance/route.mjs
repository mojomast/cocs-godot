// Read-only map geometry navigation; this module never accesses a Match or actor mutator.
export function planRoute(map, actor, goal = [-14, -19]) {
  const clear = (x, z) => Math.abs(x) <= 49 && Math.abs(z) <= 41 && !map.blocks.some(b =>
    Math.abs(x-b.x) < b.w/2 + .85 && Math.abs(z-b.z) < b.d/2 + .85);
  const line = (a,b) => {
    const n = Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/.2);
    for(let k=0;k<=n;k++) if(!clear(a[0]+(b[0]-a[0])*k/Math.max(1,n),a[1]+(b[1]-a[1])*k/Math.max(1,n))) return false;
    return true;
  };
  const start=[Math.round(actor.x),Math.round(actor.z)], key=p=>p.join(',');
  if(!line([actor.x,actor.z],start)) throw Error('Spawn cannot reach navigation grid');
  const queue=[start], prev=new Map([[key(start),null]]);
  for(let i=0;i<queue.length;i++) {
    const p=queue[i]; if(key(p)===key(goal)) break;
    for(const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
      const q=[p[0]+dx,p[1]+dz];
      if(!prev.has(key(q))&&line(p,q)) {prev.set(key(q),p);queue.push(q);}
    }
  }
  if(!prev.has(key(goal))) throw Error('No collision-clear grid route to rocket');
  const path=[];for(let p=goal;p;p=prev.get(key(p)))path.unshift(p);
  const smooth=[[actor.x,actor.z]];
  for(let i=0;i<path.length;) {let j=path.length-1;while(j>i&&!line(smooth.at(-1),path[j]))j--;smooth.push(path[j]);i=j+1;}
  return smooth.slice(1);
}

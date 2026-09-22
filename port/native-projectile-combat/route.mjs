// Read-only, bounded ground-route planning for the native pickup acceptance.
// Source geometry owns support/collision; never access or edit a live Match.
import {floorAt, obstructed, walkEdge} from '../../game/core.mjs';

const CLEARANCE = 1.2; // Body radius plus closed-loop steering/corner tolerance.
const SAMPLE = .2;
const PICKUP_CLEARANCE = 2;
const MAX_CELLS = 16000;
const MAX_WAYPOINTS = 128;
const key = ([x,z]) => `${x},${z}`;
const distance = (a,b) => Math.hypot(a[0]-b[0],a[1]-b[1]);
const finitePoint = p => Array.isArray(p) && p.length === 2 && p.every(Number.isFinite);

export function groundRouteGeometry(map) {
  const bounds = map.bounds;
  if (!bounds || !['minX','maxX','minZ','maxZ'].every(k=>Number.isFinite(bounds[k]))) throw Error('Route requires finite source bounds');
  if ((bounds.maxX-bounds.minX)*(bounds.maxZ-bounds.minZ)>MAX_CELLS) throw Error('Route grid exceeds bounded arena budget');
  const heights = new Map(), clearCache = new Map();
  const floor = (x,z) => {
    const id = `${x.toFixed(5)},${z.toFixed(5)}`;
    if (!heights.has(id)) heights.set(id,floorAt(x,z,map));
    return heights.get(id);
  };
  const point = p => ({x:p[0],y:floor(...p),z:p[1]});
  const clear = p => {
    if (!finitePoint(p)) return false;
    const [x,z] = p, id = `${x.toFixed(5)},${z.toFixed(5)}`;
    if (clearCache.has(id)) return clearCache.get(id);
    let ok = x>=bounds.minX+CLEARANCE && x<=bounds.maxX-CLEARANCE && z>=bounds.minZ+CLEARANCE && z<=bounds.maxZ-CLEARANCE;
    // Deliberately stay on the arena's zero-height ground. This acceptance
    // needs neither ramps, causeway sides, jumps, nor stacked support layers.
    ok &&= floor(x,z) !== null && Math.abs(floor(x,z)) < .01 && !obstructed(x,0,z,CLEARANCE,map);
    if (ok) for (const [dx,dz] of [[-1,0],[1,0],[0,-1],[0,1],[-1,-1],[-1,1],[1,-1],[1,1]]) {
      const y = floor(x+dx*CLEARANCE,z+dz*CLEARANCE);
      if (y===null || Math.abs(y)>=.01) {ok=false;break;}
    }
    clearCache.set(id,ok);
    return ok;
  };
  const edge = (a,b) => {
    if (!finitePoint(a) || !finitePoint(b) || distance(a,b)>200) return false;
    const count = Math.max(1,Math.ceil(distance(a,b)/SAMPLE));
    let previous;
    for (let i=0;i<=count;i++) {
      const p = [a[0]+(b[0]-a[0])*i/count,a[1]+(b[1]-a[1])*i/count];
      if (!clear(p)) return false;
      const current = point(p);
      // walkEdge is limited to 6.5m; check successive short source edges.
      if (previous && !walkEdge(previous,current,map)) return false;
      previous = current;
    }
    return true;
  };
  return {clear,edge};
}

export function planRoute(map, actor, goal = [-14,-19], geometry = groundRouteGeometry(map)) {
  const origin = [actor.x,actor.z];
  if (!finitePoint(origin) || !finitePoint(goal)) throw Error('Route requires finite start/goal');
  const avoid = map.pickups.filter(([,x,z]) => distance([x,z],goal)>.01 && distance([x,z],origin)>=PICKUP_CLEARANCE);
  // An authored spawn may itself contain a supply (Meridian's recon spawn).
  // Departure from that unavoidable initial overlap must remain possible.
  const suppliesClear = p => !avoid.some(([,x,z])=>distance(p,[x,z])<PICKUP_CLEARANCE);
  const edge = (a,b) => {
    const count = Math.max(1,Math.ceil(distance(a,b)/SAMPLE));
    for (let i=0;i<=count;i++) if (!suppliesClear([a[0]+(b[0]-a[0])*i/count,a[1]+(b[1]-a[1])*i/count])) return false;
    return geometry.edge(a,b);
  };
  const start = origin.map(Math.round), end = goal.map(Math.round);
  if (!edge(origin,start) || !edge(end,goal)) throw Error('No supported start/goal grid connection');
  const queue = [start], previous = new Map([[key(start),null]]);
  for (let index=0;index<queue.length;index++) {
    if (queue.length>MAX_CELLS) throw Error('Route search exhausted cell budget');
    const p = queue[index];
    if (key(p)===key(end)) break;
    for (const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
      const q = [p[0]+dx,p[1]+dz];
      if (!previous.has(key(q)) && edge(p,q)) {previous.set(key(q),p);queue.push(q);}
    }
  }
  if (!previous.has(key(end))) throw Error('No supported ground route to rocket');
  const path=[];
  for (let p=end;p;p=previous.get(key(p))) path.unshift(p);
  const result=[origin];
  for (let i=0;i<path.length;) {
    let j=path.length-1;
    while (j>i && !edge(result.at(-1),path[j])) j--;
    if (!edge(result.at(-1),path[j])) throw Error('Route smoothing lost support');
    result.push(path[j]);i=j+1;
    if (result.length>MAX_WAYPOINTS) throw Error('Route exceeds waypoint budget');
  }
  if (distance(result.at(-1),goal)>.001) result.push(goal);
  return result.slice(1);
}

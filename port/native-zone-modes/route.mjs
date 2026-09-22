// Reuse the collision/support/walkEdge route implementation. Supplies are legal
// for this task; keep their source behavior and do not route around them.
import {planRoute,groundRouteGeometry} from '../native-projectile-combat/route.mjs';
export function bindRoute(route, zones) {
  if(route.error)return route;
  // Templates initially call the KOTH zone "hill". Match rotation resolves it
  // to an authored ID. Bind ONLY an exact geometric match to the received zone.
  const live=zones.find(z=>['x','y','z','radius'].every(k=>Math.abs(z[k]-route.zone[k])<1e-6));
  return live?{...route,zone:{id:live.id,x:live.x,y:live.y,z:live.z,radius:live.radius}}:{error:'Cached route does not match source active zone',start:route.start,zones};
}
export function zoneRouter(map) {
  const geometry=groundRouteGeometry(map), routeMap={...map,pickups:[]};
  return (actor,zones)=>{
    const ordered=[...zones].sort((a,b)=>Math.hypot(actor.x-a.x,actor.z-a.z)-Math.hypot(actor.x-b.x,actor.z-b.z));
    const failures=[];
    for(const zone of ordered){
      // A clear interior endpoint, never outside the authoritative capture disk.
      const goals=[[zone.x,zone.z]];
      for(const scale of [.4,.7])for(let i=0;i<8;i++)goals.push([zone.x+Math.cos(i*Math.PI/4)*zone.radius*scale,zone.z+Math.sin(i*Math.PI/4)*zone.radius*scale]);
      for(const goal of goals){
        if(!geometry.clear(goal))continue;
        try{return {zone:{id:zone.id,x:zone.x,y:zone.y,z:zone.z,radius:zone.radius},start:[actor.x,actor.y,actor.z],waypoints:planRoute(routeMap,actor,goal,geometry)};}
        catch(error){failures.push({goal,error:error.message});}
      }
    }
    return {error:'No supported ground-only route',start:[actor.x,actor.y,actor.z],zones,failures};
  };
}

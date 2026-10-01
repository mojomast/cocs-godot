// Source-physics A* paths for the TEST-ONLY native controller. Rebuild when
// Blackwater geometry changes. This reads the source nav graph and never
// supplies actor coordinates, inputs, outcomes or a clock to the authority.
import {writeFileSync} from 'node:fs';
import {createHordeMatch} from '../../port/native-horde/authority.mjs';
import {floorAt,walkEdge} from '../../game/core.mjs';
const match=createHordeMatch({mapId:'blackwater-reclamation',random:()=>.5,
 config:{mode:'horde',botCount:0,difficulty:'easy',fragLimit:10,timeLimit:900}});
const points={
 start0:[-183,0],start1:[-179,18],start2:[-179,-18],
 north:[-170,78],south:[-82,-78],arrivalB:[0,0],switch:[0,78],arrivalC:[170,0],relief:[170,-82],
};
const tasks=[['start0','north',0],['start1','north',0],['start2','north',0],
 ['north','south',0],['south','arrivalB',1],['arrivalB','switch',1],
 ['switch','arrivalC',3],['arrivalC','relief',3]];
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
function nearest(p){let best=-1,dist=Infinity;for(let i=0;i<match.nav.length;i++){
 const n=match.nav[i],d=distance(n,{x:p[0],z:p[1]});
 if(d<dist&&walkEdge({x:p[0],y:floorAt(...p,match.arena),z:p[1]},n,match.arena)){best=i;dist=d;}
 }if(best<0)throw Error(`No nav support for ${p}`);return best;}
function path(start,end){
 const source=nearest(start),target=nearest(end),nav=match.nav,edges=match.edges;
 const cost=new Float64Array(nav.length).fill(Infinity),prev=new Int32Array(nav.length).fill(-1),open=new Set([source]);cost[source]=0;
 while(open.size){let pick=-1,score=Infinity;for(const i of open){const value=cost[i]+distance(nav[i],nav[target]);if(value<score){score=value;pick=i;}}
  open.delete(pick);if(pick===target)break;
  for(const next of edges[pick]??[]){const value=cost[pick]+distance(nav[pick],nav[next]);if(value>=cost[next])continue;cost[next]=value;prev[next]=pick;open.add(next);}
 }
 if(!Number.isFinite(cost[target]))throw Error(`Disconnected nav ${start} -> ${end}`);
 const chain=[];for(let i=target;i>=0;i=prev[i]){chain.push([nav[i].x,nav[i].z]);if(i===source)break;}
 chain.reverse();
 chain.push(end);
 return {distance:cost[target],points:chain};
}
const output={schema:1,geometryHash:match.arena.id,paths:{},graphs:{}};
for(const [from,to,mask] of tasks){match.applyHordeGateMask(mask);
 if(!output.graphs[mask])output.graphs[mask]={nodes:match.nav.map(n=>[n.x,n.y,n.z]),edges:match.edges};
 const result=path(points[from],points[to]);output.paths[`${from}-${to}`]=result.points;
 console.log(`${from}-${to} gateMask=${mask} length=${result.distance.toFixed(1)}m nodes=${result.points.length} entry=${JSON.stringify(result.points.slice(0,6))}`);
}
writeFileSync('godot/tests/horde/blackwater_fixture_routes.json',JSON.stringify(output)+'\n');

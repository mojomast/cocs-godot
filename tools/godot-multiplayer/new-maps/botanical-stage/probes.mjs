// Source-only probes. Authored Y survives; accepted default Y comes from the
// accepted authority, never the candidate's highest floor.
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {physicalIndex, standingFailure} from '../map_variety/navigation_audit.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
import {canonicalGeometryHash} from '../map_variety/variety_lib.mjs';

const root = new URL('../../../../', import.meta.url);
const read = path => JSON.parse(readFileSync(new URL(path, root)));
export function support(arena, x, z, intended) {
  const index = physicalIndex(arena);
  if (Number.isFinite(intended)) {
    // Restrict the query to the intended layer; do not rewrite an authored Y.
    const cell = index.at(x,z);
    const hits = cell.surfaces.map(s=>terrainSupportAt(x,z,{surfaces:[s]},arena.terrain.maxSlope)).filter(Boolean);
    if (!hits.some(h=>Math.abs(h.y-intended)<.08)) throw Error(`Unsupported intended height ${x},${intended},${z}`);
    return intended;
  }
  const hit = index.support(x,z);
  if (!hit || !Number.isFinite(hit.y)) throw Error(`No ground ${x},${z}`);
  return hit.y;
}
const xz = p => Array.isArray(p) ? {x:p[0],z:p[1]} : p;

export function makeProbes(data, accepted) {
  if (canonicalGeometryHash(data.arena)!==data.geometryHash) throw Error('Candidate canonical hash mismatch');
  const a=data.arena, base=accepted.arena, points=[], cameras=[];
  const add=(id,p,reference,kind)=>{
    p=xz(p);const y=support(reference,p.x,p.z,p.y);
    support(a,p.x,p.z,y);
    points.push({id,x:p.x,y,z:p.z,kind});
  };
  for (const [i,p] of base.navNodes.entries()) add(`accepted-nav-${i}`,p,base,'accepted-nav');
  for (const [i,p] of a.navNodes.entries()) add(`candidate-nav-${i}`,p,a,'candidate-nav');
  const routes=(arena)=>arena.routes??[];
  const oldRoutes=routes(base).length?routes(base):(accepted.routes??[]);
  for(const [label,rs,reference] of [['accepted',oldRoutes,base],['candidate',routes(a),a]]) {
    for(const route of rs) for(let j=1;j<route.points.length;j++) {
      const p=xz(route.points[j-1]),q=xz(route.points[j]);
      const n=Math.max(1,Math.ceil(Math.hypot(q.x-p.x,q.z-p.z)/.25));
      for(let k=0;k<=n;k++) {
        const t=k/n,x=p.x+(q.x-p.x)*t,z=p.z+(q.z-p.z)*t;
        // Preserve authored endpoints, use actual piecewise support between.
        const y=k===0?p.y:(k===n?q.y:undefined);
        add(`${label}-route:${route.id}:${j}:${k}`,{x,z,y},reference,`${label}-route`);
      }
    }
  }
  for(const [group,ps] of Object.entries({spawns:a.spawns,objectives:a.objectiveZones,
      teamSpawns:Object.values(a.teamSpawns??{}).flat(),flags:Object.values(a.flagSpawns??{})}))
    for(const [i,p] of ps.entries()) add(`${group}-${i}`,p,base,group);

  const authored=a.art.cameras??a.art.inspectionViews;
  const extra={
    'helix-conservatory':[
      ['lightwell-player',0,10,0,3,-8],['archive-player',52,0,43,13,10],
      ['canopy-player',86,0,72,27,0],['crown-player',116,0,96,39,10]],
    'parallax-observatory':[
      ['well-descent',32,-34,43,12,-34],['court-relief',24,-34,10,17,-34]],
    'vesper-viaduct':[
      ['market-player',-32,0,15,15,0],['roof-player',18,45,24,26,65],
      ['canal-arch-player',33,-100,33,4,-113],['retaining-player',-108,-65,-100,9,-65]],
  }[a.id];
  const views=[...authored.map(v=>({...v})),...extra.map(([id,x,z,tx,ty,tz])=>({id,eye:[x,support(a,x,z)+1.65,z],target:[tx,ty,tz]}))];
  for(const view of views) {
    const authoredEye=view.eye.slice();
    if(a.id==='helix-conservatory'&&view.id==='botanical-eye') {
      view.eye=[-29.5,9.65,46.5];
      view.repositionReason='0.71m lateral move to clear candidate shelf rim; both variants use this same location';
    }
    const [x,y,z]=view.eye;
    if(view.id==='overview') {cameras.push({...view,beforeEye:view.eye,comparison:'matched-overview',player:false,fov:68});continue;}
    const ground=support(a,x,z);
    // Keep an authored camera only if actually player-height; record any fix.
    const eye=[x,ground+1.65,z];
    const beforeXZ=a.id==='parallax-observatory'&&['well-descent','court-relief'].includes(view.id)?[0,-34]:[x,z];
    const oldGround=support(base,...beforeXZ);
    const beforeEye=[beforeXZ[0],oldGround+1.65,beforeXZ[1]];
    const obstruction=standingFailure(a,x,z,ground);
    if(obstruction) throw Error(`Camera ${view.id}: ${obstruction}`);
    const oldObstruction=standingFailure(base,...beforeXZ,oldGround);
    if(oldObstruction) throw Error(`Before camera ${view.id}: ${oldObstruction}`);
    cameras.push({...view,eye,beforeEye,player:true,fov:68,
      authoredEye,ground,beforeGround:oldGround,
      comparison:beforeXZ[0]!==x||beforeXZ[1]!==z?'repositioned: new court/well has no accepted ground; before uses polar crosslink':(Math.abs(ground-oldGround)<1e-6?'matched-player-camera':'repositioned-height: changed candidate support'),
      sourceCameraAdjustment:Math.abs(y-eye[1])<1e-6?'none':'source-support correction; original retained in authoredEye'});
    add(`camera:${view.id}`,{x,y:ground,z},a,'camera');
  }
  return {geometryHash:data.geometryHash,acceptedGeometryHash:accepted.geometryHash,
    status:'source-probes-only-native-pending',spacingMetres:.25,capsule:{radius:.41,height:1.7},
    points,cameras,portals:a.art.portals??[],
    scope:'Native finite capsule/nav/routes/spawn/objective probes pending; hosted mode journeys not executed'};
}
if(process.argv[1]===fileURLToPath(import.meta.url)) {
  const manifest=read('godot/tests/new_maps/botanical_stage/source-manifest.json');
  const id=process.argv[2],m=manifest.maps[id];
  if(!m) throw Error('Unknown staged map');
  console.log(JSON.stringify(makeProbes(read(m.authority),read('godot/'+m.acceptedAuthority.slice(6)))));
}

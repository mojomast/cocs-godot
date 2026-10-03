// Source-only successor to frozen U districts-v3. Never writes U artifacts.
import {makeRecipe as previous} from '../districts-v3/recipe-v3.mjs';
import {stampTerrainFloor} from '../../../../../../game/terrain.mjs';
export const ID='parallax-observatory', REVISION='districts-v4';
export function makeRecipe() {
  const a=previous();
  // An actual cut-and-fill entry, not a probe relocation. The U court ended at
  // x46; x46..48 was empty and the east-instrument terrace starts with a cliff.
  // Replacement footprints stay west of the old x54 route and its nav nodes.
  const replace=(id,x0,x1,z0,z1,height)=>{
    stampTerrainFloor(a.terrain,[[x0,z0],[x1,z0],[x1,z1],[x0,z1]],height,id);
    // Stamping only fills existing triangles. Supply ONE complete canonical
    // quad, including the previously unsupported gap, after removing fragments.
    a.terrain.surfaces=a.terrain.surfaces.filter(s=>s.id!==id);
    a.terrain.surfaces.push({id,material:'saltstone',walkable:true,
      vertices:[[x0,height(x0,z0),z0],[x0,height(x0,z1),z1],
        [x1,height(x1,z1),z1],[x1,height(x1,z0),z0]],triangles:[[0,1,2],[0,2,3]]});
  };
  replace('court-east-landing-v4',44,52,-37.5,-30.5,()=>12);
  replace('court-east-grade-v4',47,52,-63,-37.5,(_x,z)=>12+(-37.5-z)*12/25.5);
  // The landing connects through the unchanged full-width portal, then ascends
  // at 0.4706 rise/run to the existing y24 upper terrace. Lightwell stays intact.
  a.routes.push({id:'court-east-connection-v4',width:3,points:[
    {x:44,y:12,z:-34},{x:49.5,y:12,z:-34},{x:49.5,y:12,z:-37.5},
    {x:49.5,y:24,z:-63},{x:54,y:24,z:-63}]});
  const points=a.routes.at(-1).points;
  for(let j=1;j<points.length;j++) {
    const p=points[j-1],q=points[j],n=Math.ceil(Math.hypot(q.x-p.x,q.z-p.z)/2);
    for(let i=0;i<=n;i++)a.navNodes.push({x:p.x+(q.x-p.x)*i/n,y:p.y+(q.y-p.y)*i/n,z:p.z+(q.z-p.z)*i/n});
  }
  a.verification.varietyRouteIds.push('court-east-connection-v4');
  a.art.baseCraft.cutouts.push({id:'court-east-connection-v4',min:[44,12,-63],max:[52,26,-30.5]});
  a.art.sourceCorrection={revision:REVISION,predecessor:'districts-v3',
    rule:'supported east landing and graded cliff cut; original portals/routes retained'};
  delete a.terrain.height;
  return a;
}
export const recipe=makeRecipe();

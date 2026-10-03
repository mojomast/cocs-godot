// Source successor; frozen revision-3 and U exports are read-only.
import {makeRecipe as previous} from './recipe-v3.mjs';
import {composeKitAuthority} from '../map_variety/kit_authority.mjs';
export const ID='helix-conservatory',REVISION='revision-4';
export function makeRecipe() {
  const a=previous();
  // Remove the five floating tangential arches and their unattached north
  // ridge. The inherited thin pavilion frame and south assembly are retained.
  a.art.kit=a.art.kit.filter(k=>!k.id.startsWith('greenhouse-rib-')&&k.id!=='greenhouse-ridge');
  // Recompose the Kit's physical triangles once, including new reachable posts.
  a.terrain.surfaces=a.terrain.surfaces.filter(s=>s.renderSource!=='kit');
  a.terrain.walls=a.terrain.walls.filter(s=>s.renderSource!=='kit');
  a.art.kit.push({id:'greenhouse-frame-v4',class:'greenhouse_frame',material:'helix.greenhouse-frame',
    sector:'canopy',at:[0,16,0],rot:0,params:{angles:[70,76,82,88,94],radius:87,
      inner:5.8,outer:6.6,depth:.6,spring:3,segments:28,profiled:true}});
  a.art.greenhouseAttachments={version:1,assembly:'greenhouse-frame-v4',groundY:16,
    intent:'five radial transverse arches, paired ground posts, inner/outer eaves and crown ridge',
    members:[70,76,82,88,94].map(angle=>({rib:`greenhouse-rib-${angle}`,angle,
      posts:[`greenhouse-post-${angle}--1`,`greenhouse-post-${angle}-1`],
      eaves:['greenhouse-inner-eave','greenhouse-outer-eave'],ridge:'greenhouse-ridge'}))};
  a.art.sourceCorrection={revision:REVISION,predecessor:'revision-3',rule:'ground-rooted radial greenhouse frame'};
  return composeKitAuthority(a);
}
export const recipe=makeRecipe();

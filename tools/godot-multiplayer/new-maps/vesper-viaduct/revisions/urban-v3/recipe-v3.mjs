// Source-only successor to frozen U urban-v2. All old outputs stay immutable.
import {makeRecipe as previous} from '../urban-v2/recipe-v2.mjs';
export const ID='vesper-viaduct', REVISION='urban-v3';
export function makeRecipe() {
  const a=previous();
  const replacements=a.art.kit.filter(k=>k.class==='roof_run'&&k.params.style==='parapet');
  const descriptors=[];
  for(const z of [-47,45,112]) {
    const depth=z===112?14:22;
    for(const center of [-68,68])for(let j=0;j<5;j++) {
      const x=center+(j-2)*8;
      const top=(z>65?24:z>25?12+(z+7-25)*.3:(z+7+65)*.3)+13+(j%3)*3;
      for(const zz of [z-depth/2,z+depth/2]) {
        const id=`canonical-row-parapet-${x}-${zz}`;
        const min=[x-4,top,zz-.225],max=[x+4,top+.7,zz+.225];
        const kit=replacements.find(k=>k.at[0]===x&&k.at[2]===z);
        descriptors.push({id,name:'row-roof-parapet',material:'brick',min,max,
          replacement:kit?{kind:'kit',id:kit.id}:{kind:'authority',id}});
        if(kit)continue; // New Kit owns the entire renovated parapet, once.
        const [x0,y0,z0]=min,[x1,y1,z1]=max;
        const v=[[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1],
          [x0,y1,z0],[x1,y1,z0],[x1,y1,z1],[x0,y1,z1]];
        for(const [i,f] of [[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]].entries())
          for(const [n,t] of [[f[0],f[1],f[2]],[f[0],f[2],f[3]]].entries())
            a.terrain.walls.push({id:`${id}-w${i}-${n}`,material:'brick',vertices:t.map(k=>v[k])});
        for(const [suffix,f] of [['top',[4,7,6,5]],['bottom',[0,1,2,3]]])
          a.terrain.surfaces.push({id:`${id}-${suffix}`,material:'brick',walkable:false,
            vertices:f.map(k=>v[k]),triangles:[[0,1,2],[0,2,3]]});
      }
    }
  }
  // The pure accepted-craft consumer validates every captured legacy bound
  // before suppressing it. Retained masonry is rendered from these colliders;
  // six renovated ends are rendered/collided by the existing Kit descriptor.
  a.art.baseCraft.canonicalSolids={version:1,role:'row-roof-parapet',descriptors};
  a.art.sourceCorrection={revision:REVISION,predecessor:'urban-v2',
    rule:'one canonical owner per parapet; no independent legacy thickness'};
  return a;
}
export const recipe=makeRecipe();

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {recipes,faces,maps,palette} from '../../../tools/godot-biomes/expansion/recipe.mjs';
import {compile,root,readChapter,sha} from '../../../tools/godot-biomes/expansion/compile.mjs';
import {createStructureRay,structurePlacements,readImportedTriangles,facadeTriangles} from '../../../port/edge-effects/structure-rays.mjs';
import {interludeDefinitions} from '../../../port/native-campaign/interlude-definitions.mjs';
import {bakeTerrainBvh,terrainRayHitFast} from '../../../game/terrain-bvh.mjs';
import {floorAt,obstructed} from '../../../port/native-campaign/core.generated.mjs';

const assets=recipes(),catalog=JSON.parse(compile().catalogText);
const xyz = p => [p.x,p.y,p.z];
const point = p => ({x:p[0],y:p[1],z:p[2]});
export function placedFaces(asset,placement,lod=0) {
  return faces(asset,lod).map(t=>t.map(p=>p.map((v,i)=>v*placement.scale[i]+placement.origin[i])));
}
function bvh(triangles) {
  return bakeTerrainBvh({surfaces:[],walls:triangles.map((vertices,i)=>({id:`biome4-${i}`,vertices,triangles:[[0,1,2]]}))});
}
function hit(tree,a,b) {
  const d={x:b.x-a.x,y:b.y-a.y,z:b.z-a.z},length=Math.hypot(d.x,d.y,d.z);
  if(length<1e-7)return null;
  for(const k of ['x','y','z'])d[k]/=length;
  return terrainRayHitFast(tree,a,d,length-.02);
}
// Exact segment/AABB slab test on inflated reviewed footprints. This is a
// conservative swept-route proof for every triangle, not sparse vertex samples.
function intersects(a,b,min,max) {
  let lo=0,hi=1;
  for(let i=0;i<3;i++) {
    const d=b[i]-a[i];
    if(Math.abs(d)<1e-10) {if(a[i]<min[i]||a[i]>max[i])return false;continue;}
    let u=(min[i]-a[i])/d,v=(max[i]-a[i])/d;if(u>v)[u,v]=[v,u];
    lo=Math.max(lo,u);hi=Math.min(hi,v);if(lo>hi)return false;
  }
  return true;
}

test('12 additive authored assemblies, bounded nondegenerate geometry, allowlisted opaque palette and reduced LOD',()=>{
  assert.equal(assets.length,12);
  for(const map of maps)assert.deepEqual(assets.filter(a=>a.chapter===map).map(a=>a.role),['hero','support','support']);
  for(const a of assets) {
    assert.ok(a.parts.length>=10,a.id);
    assert.equal(new Set(a.parts.map(p=>p.name)).size,a.parts.length);
    const tris=faces(a);assert.ok(tris.length<4500,a.id);
    assert.ok(new Set(a.parts.map(p=>p.material)).size<=4,a.id);
    for(const p of a.parts)assert.ok(p.material in palette);
    for(const t of tris) {
      for(const [x,y,z] of t)assert.ok(Math.abs(x)<=.5&&y>=0&&y<=1&&Math.abs(z)<=.5,`${a.id}: ${x},${y},${z}`);
      const u=t[1].map((v,i)=>v-t[0][i]),v=t[2].map((v,i)=>v-t[0][i]);
      assert.ok(Math.hypot(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])>1e-10,a.id);
    }
    assert.ok(faces(a,1).length<tris.length);
  }
});

test('generated recipe/catalog reproducible and original production authority/art bytes unchanged from assigned base',()=>{
  const output=compile();
  assert.equal(readFileSync(root+'tools/godot-biomes/expansion/meshes.json','utf8'),output.recipeText);
  assert.equal(readFileSync(root+'godot/biomes/expansion/catalog.json','utf8'),output.catalogText);
  const paths=['godot/campaign/generated/','godot/campaign/art/','port/edge-effects/structure-faces.json',
    'port/edge-effects/structure-rays.mjs','port/native-campaign/core.generated.mjs','tools/godot-campaign/compile.mjs'];
  const changed=execFileSync('git',['diff','e9d784a7','--',...paths],{cwd:root,encoding:'utf8'});
  assert.equal(changed,'','Scenery may not silently change authority/facade/old asset provenance');
  for(const id of maps)assert.equal(sha(readFileSync(root+`godot/campaign/generated/${id}.json`)),catalog.chapters[id].recipeSha256);
});

for(const id of maps) {
  test(`${id}: exact imported facade baseline, all authored route sweeps, spawn/objective clearance and prospective triangle visibility`,()=>{
    const data=readChapter(id),placements=catalog.chapters[id].placements;
    // Read the real committed GLB triangles; facade collision must still use the
    // baseline bytes. Compare with source's baked triangle oracle within float tolerance.
    for(const key of new Set(structurePlacements(data).map(p=>p.key))) {
      const imported=readImportedTriangles(key),baked=facadeTriangles(key);
      assert.equal(imported.length,baked.length,key);
      let error=0;for(let i=0;i<baked.length;i++)for(let j=0;j<3;j++)for(let k=0;k<3;k++)error=Math.max(error,Math.abs(imported[i][j][k]-baked[i][j][k]));
      assert.ok(error<1e-5,`${key}: ${error}`);
    }
    let sweeps=0,sourceClear=0,visible=0,occluded=0,edgeWindows=0;
    const routes=data.routes.flatMap(r=>r.points),targets=Object.values(data.campaign.anchors).map(p=>({...p,y:p.y+1.5}));
    for(const beat of interludeDefinitions(data))for(const key of ['a','b'])targets.push({...beat[key],y:beat[key].y+(beat.family==='align'&&key==='b'?2.5:1.2)});
    for(const p of data.arena.spawns)targets.push({x:p[0],y:floorAt(p[0],p[1],data.arena)+1.45,z:p[1]});
    const tree=bvh(placements.flatMap(p=>placedFaces(assets.find(a=>a.id===p.asset),p)));
    for(const p of placements) {
      const lo=p.origin.map((v,i)=>v+(i===1?0:-p.scale[i]/2)-(i===1?1.8:.6));
      const hi=p.origin.map((v,i)=>v+(i===1?p.scale[i]:p.scale[i]/2)+(i===1?0:.6));
      for(const route of data.routes)for(let i=1;i<route.points.length;i++) {
        assert.ok(!intersects(xyz(route.points[i-1]),xyz(route.points[i]),lo,hi),`${p.asset} intersects ${route.id}/${i}`);sweeps++;
      }
      for(const t of targets)assert.ok(!intersects(xyz(t),xyz(t),lo,hi),`${p.asset} marker/spawn footprint`);
    }
    const sourceRay=createStructureRay(data);
    // Carry forward the reviewed cabin side-air and pitched-roof shot windows
    // from edge-effects/edges.test.mjs at every selected Rootfall facade.
    if(data.campaign.index===0)for(const p of placements)for(const sign of [-1,1])for(const [x,y] of [[.49,.5],[.4,.9625],[.41025,.5]]) {
      const a=point([p.origin[0]+x*sign*p.scale[0],p.origin[1]+y*p.scale[1],p.origin[2]+p.scale[2]*2]);
      const b={...a,z:p.origin[2]-p.scale[2]*2};
      if(sourceRay(a,{x:0,y:0,z:-1},p.scale[2]*4)>=p.scale[2]*4-.03) {
        assert.equal(hit(tree,a,b),null,`${p.asset} closes reviewed facade edge window ${x}/${y}`);edgeWindows++;
      }
    }
    for(const p of routes) {
      // Source movement oracle at authored feet, independent of visual geometry.
      if(!obstructed(p.x,p.y,p.z,.42,data.arena))sourceClear++;
      const a={...p,y:p.y+1.45};
      for(const t of targets) {
        const delta={x:t.x-a.x,y:t.y-a.y,z:t.z-a.z},dist=Math.hypot(delta.x,delta.y,delta.z);
        if(dist<.1||dist>100)continue;
        for(const k of ['x','y','z'])delta[k]/=dist;
        if(sourceRay(a,delta,dist)<dist-.03){occluded++;continue;}
        assert.equal(hit(tree,a,t),null,`${id} new visual occlusion ${JSON.stringify(a)} -> ${JSON.stringify(t)}`);visible++;
      }
    }
    assert.ok(visible>50);assert.ok(sourceClear>routes.length*.95);
    // Negative control: the exact triangle visibility oracle must detect a plane
    // inserted across an otherwise clear approach.
    const blocker=bvh([[[-1,0,0],[1,0,0],[0,3,0]]]);
    assert.ok(hit(blocker,{x:0,y:1,z:-2},{x:0,y:1,z:2}));
    assert.ok(intersects([0,0,-2],[0,0,2],[-1,-1,-1],[1,1,1]),'route blocker negative control');
    console.log(JSON.stringify({id,sweeps,sourceClear,routePoints:routes.length,visibleApproachRays:visible,baselineOccluded:occluded,edgeWindows}));
  });
}

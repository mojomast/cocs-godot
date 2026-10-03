// Vesper Viaduct authority revision urban-v2 — source-only candidate.
//
// Builds on the accepted recipe without touching it. Adds differentiated facade
// eras with varied roof heights, a covered market arcade, two canal arch
// bridges with quay coping, terraced retaining banks, rooftop access and new
// walkable crosslinks. Collision is triangle walls; walkable pads carry real
// terrain support. No accepted master, generated JSON or runtime GLB is touched.
import {recipe as baseRecipe, height} from '../../recipe.mjs';
import {stampTerrainFloor} from '../../../../../../game/terrain.mjs';
import {composeKitAuthority} from '../../../map_variety/kit_authority.mjs';
export const ID = 'vesper-viaduct';
export const REVISION = 'urban-v2';

export function makeRecipe() {
  const a = baseRecipe();
  a.art.labels=a.art.labels.map(label=>({material:'letter',size:.7,...label}));
  a.art.baseCraft={author:'author_blender.py',sha256:'f540161e4ec506f7ce3098bd1533d6d321a2aa806cd7c0180db8f0b8278ac4c6'};
  // Candidate-local renovation lineage: replace only this closed base building.
  a.terrain.walls=a.terrain.walls.filter(w=>!w.id?.startsWith('central-row-16-45-'));
  a.terrain.surfaces=a.terrain.surfaces.filter(s=>s.id!=='central-row-16-45-cap');
  a.art.pieces=a.art.pieces.filter(p=>!(p.kind.startsWith('central-')&&p.x>=8&&p.x<=24&&p.z>33&&p.z<34));
  a.art.kit = [];
  a.art.portals = [];
  a.art.varietyDistricts = ['era-facade-row', 'covered-market-arcade', 'canal-arch-and-quay', 'retaining-terrace-banks', 'rooftop-access'];
  a.overhead = a.overhead ?? [];
  a.verification = {...a.verification, varietyRouteIds: []};

  const surf = (id, material, x0, x1, z0, z1, y, walkable = true) =>
    a.terrain.surfaces.push({id, material, walkable, vertices: [[x0, y, z0], [x0, y, z1], [x1, y, z1], [x1, y, z0]], triangles: [[0, 1, 2], [0, 2, 3]]});
  const retain = (id, material, p, q, y0, y1) => {
    a.terrain.walls.push({id: id + '-a', material, vertices: [[p[0], y0, p[1]], [q[0], y0, q[1]], [q[0], y1, q[1]]]});
    a.terrain.walls.push({id: id + '-b', material, vertices: [[p[0], y0, p[1]], [q[0], y1, q[1]], [p[0], y1, p[1]]]});
  };
  const pillar = (id, x, z, w, d, b, t, material) => {
    const p = [[x - w / 2, b, z - d / 2], [x + w / 2, b, z - d / 2], [x + w / 2, b, z + d / 2], [x - w / 2, b, z + d / 2]];
    for (let i = 0; i < 4; i++) {
      const u = p[i], v = p[(i + 1) % 4];
      a.terrain.walls.push({id: `${id}-w${i}-a`, material, vertices: [[u[0], b, u[2]], [v[0], b, v[2]], [v[0], t, v[2]]]});
      a.terrain.walls.push({id: `${id}-w${i}-b`, material, vertices: [[u[0], b, u[2]], [v[0], t, v[2]], [u[0], t, u[2]]]});
    }
  };
  const box = (id, x, z, w, d, b, t, material = 'brick') => {
    pillar(id, x, z, w, d, b, t, material);
    surf(`${id}-cap`, material, x - w / 2, x + w / 2, z - d / 2, z + d / 2, t);
    return {id, type: 'era-block', x, z, w, d, baseY: b, top: t};
  };
  const route = (id, points, width = 5) => {
    a.routes.push({id, width, points});
    for (let j = 1; j < points.length; j++) {
      const A = points[j - 1], B = points[j], n = Math.max(1, Math.ceil(Math.hypot(B[0] - A[0], B[1] - A[1]) / 2));
      for (let i = 0; i <= n; i++) a.navNodes.push({x: A[0] + (B[0] - A[0]) * i / n, z: A[1] + (B[1] - A[1]) * i / n});
    }
    a.verification.varietyRouteIds.push(id);
  };
  const kit = (id, klass, material, sector, at, params, rot = 0) => a.art.kit.push({id, class: klass, material, sector, at, rot, params});

  // ---- Retaining terrace banks (east x100..108, west x-108..-100) -----------
  // A real sloped retaining bank that ties into the base x=±100 crosslink at its
  // low end, so the new surface is traversable and connected, not an island.
  for (const side of [-1, 1]) {
    const x0 = side > 0 ? 104 : -112, x1 = x0 + 8, zA = -60, zB = -25, yA = 1.5, yB = 12;
    a.terrain.surfaces.push({id: `retain-ramp-${side}`, material: 'quay', walkable: true,
      vertices: [[x0, yA, zA], [x0, yB, zB], [x1, yB, zB], [x1, yA, zA]], triangles: [[0, 1, 2], [0, 2, 3]]});
    retain(`retain-side-${side}`, 'sandstone', [x0 + (side > 0 ? 0 : 8), zA], [x0 + (side > 0 ? 0 : 8), zB], 0, yB);
    retain(`retain-side-outer-${side}`, 'sandstone', [x1 - (side > 0 ? 0 : 8), zA], [x1 - (side > 0 ? 0 : 8), zB], 0, yB);
    kit(`retain-coping-${side}`, 'retaining_wall', 'vesper.coping', 'retaining', [side*112, 12, -33], {length: 12, height: .9, thickness: .7, trimMaterial: 'vesper.coping'},Math.PI/2);
    route(`retaining-bank-${side}`, [[side * 100, -65], [side * 108, -65], [side * 108, zA], [side * 108, zB], [side * 108, -20], [side * 100, -20]], 4);
  }

  // ---- Canal arch bridges at x=±33 over the canal cut -----------------------
  for (const x of [-33, 33]) {
    // Open both existing quay rails for the new bridge, preserving their sides.
    for(const z of [-104,-116]){
      const id=`bridge-entry-${x}-${z}`;
      stampTerrainFloor(a.terrain,[[x-5,z-1],[x+5,z-1],[x+5,z+1],[x-5,z+1]],()=>0,id);
      for(const s of a.terrain.surfaces)if(s.id===id)s.material='brick';
    }
    surf(`canal-arch-deck-${x}`, 'brick', x - 6, x + 6, -116, -104, 0);
    a.terrain.surfaces.at(-1).renderSource='kit';
    for (const z of [-104, -116]) retain(`canal-arch-abut-${x}-${z}`, 'brick', [x - 6, z], [x + 6, z], -3, 0);
    kit(`canal-arch-${x}`, 'arch_bridge', 'vesper.brick-era', 'canal', [x, -3, -110], {span: 10, width: 12, thickness: 1.1, pier: 3, trimMaterial: 'vesper.coping'}, Math.PI / 2);
    route(`canal-arch-approach-${x}`, [[x, -85], [x, -118]], 4);
  }
  for (const z of [-104, -116]) for(const [lo,hi] of [[-94,-39],[-27,27],[39,94]])kit(`quay-coping-${z}-${lo}`, 'retaining_wall', 'vesper.quay', 'canal', [(lo+hi)/2, 0, z], {length: hi-lo, height: .6, thickness: .5, trimMaterial: 'vesper.coping'});

  // ---- Covered market arcade along civic street (z=0) -----------------------
  for (let x = -25; x <= 25; x += 10) for (const z of [-4.5, 4.5]) pillar(`market-pier-${x}-${z}`, x, z, 1.4, 1.4, 12, 15.2, 'iron');
  a.overhead.push({id: 'market-canopy', x: 0, z: 0, w: 64, d: 10, minY: 15.2, maxY: 15.7, material: 'iron'});
  kit('market-stalls', 'stall_row', 'vesper.stall', 'market', [-16, 12, 6.5], {count: 6, spacing: 5, width: 3.4, depth: 1.8, trimMaterial: 'vesper.awning'});
  kit('market-stalls-east', 'stall_row', 'vesper.stall', 'market', [16, 12, -6.5], {count: 6, spacing: 5, width: 3.4, depth: 1.8, trimMaterial: 'vesper.awning'}, Math.PI);
  for (const x of [-24,-16,-8,8,16,24]) box(`market-counter-cover-${x}`, x, 6.6, 3, 1.2, 12, 12.9, 'brick');
  a.structures.push({id: 'covered-market-arcade', type: 'market', x: 0, z: 0, w: 64, d: 10, height: 3.2, roofY: 15.2, doors: ['east', 'west']});

  // ---- Era facade rows with varied roof heights -----------------------------
  const eras = [['victorian', 16, 'pitched'], ['plaster', 12, 'parapet'], ['warehouse', 13, 'pitched'], ['civic', 18, 'parapet'], ['modern', 11, 'parapet'], ['victorian', 15, 'pitched']];
  for (const [index, [era, top, roof]] of eras.entries()) {
    const x = [-84,-68,-52,52,68,84][index], z = index % 2 ? -47 : 45;
    const j = [0,2,4,0,2,4][index], existingTop=height(z+7)+13+(j%3)*3;
    const base = existingTop-top;
    const block = {id:`era-row-${index}`,type:'facade-renovation',x,z,w:8,d:22,baseY:height(z-11),top:existingTop};
    a.structures.push({...block, era});
    kit(`roof-run-${index}`, 'roof_run', roof === 'pitched' ? 'vesper.slate' : 'vesper.coping', 'roofs', [x, base + top, z],
      {length: 8, width: 22, rise: roof === 'pitched' ? 4 : 0, style: roof, trimMaterial: 'vesper.coping'});
    for (const dx of [-2, 2]) for (let level = 0; level < 3; level++) {
      a.art.pieces.push({kind: era + '-window', x: x + dx, y: base + 2.5 + level * 3.4, z: z - 11.08, w: era === 'warehouse' ? 2.4 : 1.5, h: era === 'victorian' ? 2.4 : 2, d: .1, material: 'glass'});
    }
    a.art.pieces.push({kind: era + '-cornice', x, y: base + top - .3, z: z - 11.28, w: 8.4, h: .5, d: .6, material: 'sandstone'});
    if (index % 3 === 0) kit(`roof-cowl-${index}`, 'framed_bay', 'vesper.brick-era', 'rooftop', [x, base + top, z - 2], {width: 2.4, height: 2.6, depth: 2, arch: false, trimMaterial: 'vesper.coping'});
  }
  route('era-street', [[-108, 70], [-36, 70], [36, 70], [108, 70]], 5);

  // ---- Walkable rooftop terrace with a gentle access ramp -------------------
  const terraceBase = 15, terraceTop = terraceBase + 7;
  // Renovate this one closed base building into the accessible terrace.
  // Its old tall shell/windows must not remain inside the new playable roof.
  box('roof-terrace-block', 18, 45, 22, 16, terraceBase, terraceTop, 'brick');
  // The box already provides the supported top. Select slate for that one
  // surface rather than layering a second, differently materialed coplanar cap.
  Object.assign(a.terrain.surfaces.at(-1), {id:'roof-terrace-deck',material:'slate',
    renderLineage:{replaces:'roof-terrace-block-cap',selection:'single supported slate deck'}});
  retain('roof-terrace-parapet-n', 'sandstone', [7, 37], [29, 37], terraceTop, terraceTop + 1);
  retain('roof-terrace-parapet-w', 'sandstone', [7, 37], [7, 53], terraceTop, terraceTop + 1);
  // Connect the roof to the upper district, away from the preserved x=32 civic
  // stairs. Replace the underlying grade so highest-floor semantics follow
  // these small treads, not a hidden higher ground plane.
  for (let i = 0; i < 14; i++) {
    const z0=53+i*12/14,z1=53+(i+1)*12/14,y=22+(i+1)*2/14,id=`roof-ramp-step-${i}`;
    stampTerrainFloor(a.terrain,[[16,z0],[20,z0],[20,z1],[16,z1]],()=>y,id);
    for(const s of a.terrain.surfaces)if(s.id===id)s.material='sandstone';
  }
  route('roof-access-ramp', [[18,70],[18,65],[18,53],[18,51]], 3);
  a.routes.at(-1).points=a.routes.at(-1).points.map(([x,z],i)=>({x,z,y:[24,24,22+1/7,22][i]}));
  route('roof-terrace-loop', [[10, 40], [26, 40], [26, 51], [10, 51], [10, 40]], 3);
  a.routes.at(-1).points=a.routes.at(-1).points.map(([x,z])=>({x,z,y:22}));
  a.structures.push({id: 'roof-terrace-access', type: 'roof-terrace', x: 18, z: 45, w: 22, d: 16, height: 7, roofY: terraceTop, doors: ['east']});

  // ---- Portals --------------------------------------------------------------
  a.art.portals = [
    {id: 'market-west-mouth', at: [-32, 12, 0], dir: [1, 0], width: 6, depth: 3},
    {id: 'market-east-mouth', at: [32, 12, 0], dir: [-1, 0], width: 6, depth: 3},
    {id: 'canal-arch-33-mouth', at: [33, 0, -104], dir: [0, -1], width: 8, depth: 4},
  ];
  return composeKitAuthority(a);
}
export const recipe = makeRecipe();

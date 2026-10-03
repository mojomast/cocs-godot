// Parallax Observatory authority revision districts-v3 — source-only candidate.
//
// Reads the accepted generated arena as the immutable base and adds a sunken
// instrument court with a traversable lightwell, differentiated wing massing,
// instrument towers, scientific-room clusters and two new crosslinks. Collision
// is triangle walls; every walkable pad has authored terrain support. No
// accepted master, generated JSON or runtime GLB is touched.
import {readFileSync} from 'node:fs';
import {terrainSupportAt, stampTerrainFloor} from '../../../../../../game/terrain.mjs';
import {composeKitAuthority} from '../../../map_variety/kit_authority.mjs';
export const ID = 'parallax-observatory';
export const REVISION = 'districts-v3';
const BASE = new URL('../../../../../../godot/multiplayer_worlds/generated/parallax-observatory.json', import.meta.url);

export function makeRecipe() {
  const data = JSON.parse(readFileSync(BASE, 'utf8'));
  const a = structuredClone(data.arena);
  a.navNodes = (a.navNodes ?? []).map(n => Array.isArray(n) ? {x: n[0], z: n[1]} : {...n});
  a.routes = structuredClone(data.routes ?? a.routes ?? []);
  a.art = {kit: [], portals: [], landmarks: data.art?.landmarks ?? [], cameras: data.art?.cameras ?? []};
  a.art.baseCraft={author:'blender_author.py',sha256:'9cec1edaab54477d9999eb7888c921d527f0ee3f1248f2adf9c2a6a7cf5897cc',cutouts:[
    {id:'lightwell-opening',min:[30,8,-38],max:[44,13.8,-30]},
    {id:'court-entry-opening',min:[22,12,-11],max:[26,13.8,-7]},
  ]};
  a.art.varietyDistricts = ['sunken-instrument-court', 'traversable-lightwell', 'differentiated-wing-massing', 'instrument-towers', 'scientific-room-clusters'];

  const surface = (id, material, vertices) => a.terrain.surfaces.push({id, material, walkable: true, vertices, triangles: [[0, 1, 2], [0, 2, 3]]});
  const retain = (id, material, p, q, y0, y1) => {
    a.terrain.walls.push({id: id + '-a', material, vertices: [[p[0], y0, p[1]], [q[0], y0, q[1]], [q[0], y1, q[1]]]});
    a.terrain.walls.push({id: id + '-b', material, vertices: [[p[0], y0, p[1]], [q[0], y1, q[1]], [p[0], y1, p[1]]]});
  };
  const quad = (id, material, x0, x1, z0, z1, y) => surface(id, material, [[x0, y, z0], [x0, y, z1], [x1, y, z1], [x1, y, z0]]);
  const route = (id, points, width = 4) => {
    a.routes.push({id, width, points});
    for (let j = 1; j < points.length; j++) {
      const [ax, az] = points[j - 1], [bx, bz] = points[j];
      const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, bz - az) / 2));
      for (let i = 0; i <= n; i++) a.navNodes.push({x: ax + (bx - ax) * i / n, z: az + (bz - az) * i / n});
    }
  };
  const kit = (id, klass, material, sector, at, params, rot = 0) => a.art.kit.push({id, class: klass, material, sector, at, rot, params:{profiled:true,bevelSegments:1,...params}});

  // ---- Sunken instrument court (x 22..46, z -46..-22) -----------------------
  quad('court-floor', 'paving', 22, 46, -46, -1, 12);
  retain('court-north-wall', 'saltstone', [22, -46], [46, -46], 12, 20.5);
  surface('court-terrace-ramp','saltstone',[[10,14.4,-46],[10,14.4,-1],[22,12,-1],[22,12,-46]]);
  retain('court-west-parapet', 'saltstone', [10, -1], [10, -46], 14.4, 15.4);

  // ---- Traversable lightwell (x 30..38, z -38..-30) -------------------------
  // Replace, rather than stack underneath, every higher floor in this footprint.
  const stamp = (id,x0,x1,z0,z1,height,material) => {
    stampTerrainFloor(a.terrain,[[x0,z0],[x1,z0],[x1,z1],[x0,z1]],height,id);
    for(const s of a.terrain.surfaces)if(s.id===id)s.material=material;
  };
  stamp('lightwell-floor',30,36,-38,-30,()=>8,'cistern');
  stamp('lightwell-access-ramp',36,44,-38,-30,x=>8+(x-36)*.5,'saltstone');
  retain('lightwell-wall-west', 'saltstone', [30, -30], [30, -38], 8, 12);
  retain('lightwell-wall-south', 'saltstone', [30, -30], [36, -30], 8, 12);
  retain('lightwell-wall-north', 'saltstone', [30, -38], [36, -38], 8, 12);
  for(const z of [-38,-30])a.terrain.walls.push({id:`lightwell-ramp-side-${z}`,material:'saltstone',vertices:[[36,8,z],[44,12,z],[36,12,z]]});
  kit('lightwell-oculus', 'lightwell', 'parallax.trim', 'court', [34, 17, -34],
    {radius: 5.2, ribs: 12, glazingMaterial: 'parallax.glazing', trimMaterial: 'parallax.instrument-alloy'});

  // ---- Instrument towers + dishes (x=48, z=-48/-20) -------------------------
  for (const [index, [x, z]] of [[0, [64, -48]], [1, [64, -20]]].map(entry => entry)) {
    const baseY=terrainSupportAt(x,z,a.terrain,a.terrain.maxSlope)?.y??12;
    a.blocks.push({id: `instrument-tower-${index}`, kind: 'structure', x, z, w: 7, d: 7, baseY, h: baseY+22, material: 'metal'});
    kit(`instrument-tower-${index}`, 'tower', 'parallax.instrument-alloy', 'instruments', [x, baseY, z],
      {radius: 4.2, height: 40, drums: 4, trimMaterial: 'parallax.trim'});
    kit(`instrument-dish-${index}`, 'instrument_dish', 'parallax.optics', 'instruments', [x, baseY+42, z],
      {radius: 6, trimMaterial: 'parallax.etch'}, index * 0.6);
  }

  // ---- Differentiated wing massing (varied caps on the six institutes) ------
  const wings = [[-84, 10, 12, 5, 23], [-66, -10, 10, 5, 25], [-18, -10, 9, 5, 22], [18, 10, 9, 5, 24], [84, -10, 12, 5, 25], [82, 10, 10, 5, 23]];
  for (const [index, [x, z, w, d, h]] of wings.entries()) {
    const cap = 0.8 + (index % 3) * 0.6;
    a.blocks.push({id: `wing-cap-${index}`, kind: 'structure', x, z, w, d: d + .6, baseY: h, h: h + cap, material: index % 2 ? 'mirror' : 'metal'});
    kit(`wing-crest-${index}`, 'stepped_terrace', index % 2 ? 'parallax.enamel' : 'parallax.stone', 'institutes', [x, h + cap, z],
      {tiers: index % 3 === 0 ? 2 : 1, run: 1.4, rise: .4, width: w - 1, depth: d, capMaterial: 'parallax.trim'});
  }

  // ---- Scientific-room clusters inside the existing halls -------------------
  a.blocks.push({id: 'archive-rack-bank', kind: 'structure', x: -36, z: 4.5, w: 11.2, d: 1, baseY: 12, h: 13.8, material: 'metal'});
  kit('archive-cluster', 'scientific_room', 'parallax.enamel', 'scientific', [-36, 12, 4.5], {racks: 4, spacing: 3.2, trimMaterial: 'parallax.etch'});
  kit('pump-cluster', 'scientific_room', 'parallax.instrument-alloy', 'scientific', [24, 0, 82], {racks: 3, spacing: 3, trimMaterial: 'parallax.trim'});
  kit('optics-cluster', 'scientific_room', 'parallax.optics', 'scientific', [69, 19, 0], {racks: 3, spacing: 2.8, trimMaterial: 'parallax.etch'});
  kit('polar-instrument', 'instrument_dish', 'parallax.etch', 'scientific', [0, 42, -84], {radius: 9, trimMaterial: 'parallax.trim'});
  kit('calibration-column', 'tower', 'parallax.stone', 'scientific', [-78, 12, 6.5], {radius: 2.2, height: 12, drums: 2, trimMaterial: 'parallax.trim'});
  kit('calibration-column-east', 'tower', 'parallax.stone', 'scientific', [78, 12, -6.5], {radius: 2.2, height: 12, drums: 2, trimMaterial: 'parallax.trim'});

  // ---- Accepted landmarks re-expressed as authored kit forms ----------------
  for (const landmark of a.art.landmarks) {
    kit(landmark.id, 'landmark', landmark.kind === 'dome' ? 'parallax.enamel' : 'parallax.optics', 'landmarks',
      [landmark.x, landmark.y, landmark.z], {kind: landmark.kind, radius: landmark.r, tilt: landmark.tilt ?? 0, acceptedCraft:true});
  }

  // ---- New walkable crosslinks ---------------------------------------------
  // A real entry cut through the old court rail, rather than a route through it.
  stamp('court-entry',22,26,-11,-7,()=>12,'paving');
  route('court-approach', [[24, -2], [24, -24], [44, -24], [44, -44], [24, -44], [24, -2]], 4);
  route('court-steps', [[24, -34], [20, -34], [12, -34]], 4);
  a.routes.at(-1).points=a.routes.at(-1).points.map(([x,z],i)=>({x,z,y:[12,12.4,14][i]}));
  route('lightwell-stair', [[44, -34], [40, -34], [32, -34]], 3);
  a.routes.at(-1).points=a.routes.at(-1).points.map(([x,z],i)=>({x,z,y:[12,10,8][i]}));
  a.verification = {preservedRoutes: (data.routes ?? []).map(r => r.id), varietyRouteIds: ['court-approach', 'court-steps', 'lightwell-stair']};

  // Portals: the two court entries and the lightwell stair mouth.
  a.art.portals = [
    {id: 'court-south-entry', at: [34, 12, -22], dir: [0, -1], width: 6, depth: 4},
    {id: 'court-east-entry', at: [46, 12, -34], dir: [-1, 0], width: 6, depth: 4},
    {id: 'lightwell-stair-mouth', at: [39, 9.5, -34], dir: [-1, 0], width: 3, depth: 3},
  ];
  return composeKitAuthority(a);
}
export const recipe = makeRecipe();

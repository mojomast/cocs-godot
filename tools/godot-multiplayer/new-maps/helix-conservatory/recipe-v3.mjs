// Helix Conservatory authority revision 3 — source-only candidate.
//
// Builds on the accepted revision-2 recipe without touching it. Adds a rock
// grotto arcade on the archive terrace, stepped botanical terrace masses,
// varied archive-bay articulation, root/greenhouse hero forms and two new
// walkable crosslinks. Collision stays triangle walls; every walkable top has
// matching terrain support. No source/authority or physics change.
import {makeRecipe as checkpoint, hash, polar} from './recipe-v2.mjs';
import {terrainSupportAt} from '../../../../game/terrain.mjs';
export {hash, polar};
export const ID = 'helix-conservatory';
const TAU = Math.PI * 2, D = Math.PI / 180;
const mix = (a, b, t) => a + (b - a) * t;

export function makeRecipe() {
  const m = checkpoint();
  m.provenance.artRevision = 3;
  m.provenance.status = 'source-candidate-map-variety-not-native-accepted';
  m.art.revision = 3;
  m.art.kit = [];
  m.art.portals = [];
  m.art.varietyDistricts = ['rock-grotto-arcade', 'stepped-botanical-banks', 'archive-bay-articulation', 'root-and-greenhouse-forms'];
  m.verification = {...m.verification, varietyRouteIds: []};

  // Immutable floor snapshot: new masses must not feed back into their own base.
  const ground = {surfaces: m.terrain.surfaces.filter(s => s.walkable), walls: []};
  const floor = (x, z) => terrainSupportAt(x, z, ground, .8)?.y ?? 24;
  const p = (r, a, y) => { const [x, z] = polar(r, a); return [x, y ?? floor(x, z), z]; };

  const mesh = (id, vertices, triangles, material, collision = 'surface', walkable = false) => {
    triangles = triangles.filter(t => {
      const [a, b, c] = t.map(i => vertices[i]);
      const u = b.map((v, i) => v - a[i]), v = c.map((x, i) => x - a[i]);
      return Math.hypot(u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]) > 1e-8;
    });
    if (!triangles.length) return;
    m.art.meshes.push({id, vertices, triangles, material, collision, walkable});
    if (collision === 'surface') m.terrain.surfaces.push({id, vertices, triangles, material, walkable});
    if (collision === 'wall') for (const t of triangles) m.terrain.walls.push({id, material, vertices: t.map(i => vertices[i])});
  };
  const quad = (id, v, mat, collision = 'surface') => mesh(id, v, [[0, 1, 2], [0, 2, 3]], mat, collision);
  const sector = (id, r0, r1, a, b, h, mat, base = null) => {
    const bottom = [p(r0, a), p(r0, b), p(r1, b), p(r1, a)];
    for (const v of bottom) v[1] = base ?? v[1] - .08;
    const v = [...bottom, ...bottom.map(q => [q[0], q[1] + h, q[2]])];
    mesh(id, v, [[0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5], [2, 3, 7], [2, 7, 6], [3, 0, 4], [3, 4, 7]], mat, 'wall');
    quad(id + '-top', [v[4], v[5], v[6], v[7]], mat);
  };
  const primary = m.routes.map(r => ({...r, points: r.points.map(q => [...q])}));
  const distance = (q, a, b) => {
    const dx = b[0] - a[0], dz = b[1] - a[1];
    const t = Math.max(0, Math.min(1, ((q[0] - a[0]) * dx + (q[1] - a[1]) * dz) / (dx * dx + dz * dz)));
    return Math.hypot(q[0] - a[0] - dx * t, q[1] - a[1] - dz * t);
  };
  const clearance = q => Math.min(...primary.flatMap(r => r.points.slice(1).map((b, i) => distance(q, r.points[i], b))));
  const reserveRoute = (id, points, width = 2.5) => {
    m.routes.push({id, width, points});
    for (let j = 1; j < points.length; j++) {
      const a = points[j - 1], b = points[j], n = Math.ceil(Math.hypot(a[0] - b[0], a[1] - b[1]) / 2);
      for (let i = 0; i <= n; i++) m.navNodes.push({x: mix(a[0], b[0], i / n), z: mix(a[1], b[1], i / n)});
    }
    m.verification.varietyRouteIds.push(id);
  };
  const curve = (r, a, b) => {
    const n = Math.ceil(Math.abs(b - a) / (2 * D));
    return Array.from({length: n + 1}, (_, i) => polar(r, mix(a, b, i / n)));
  };
  const kit = (id, klass, material, sectorName, at, params, rot = 0, tilt = 0) =>
    m.art.kit.push({id, class: klass, material, sector: sectorName, at, rot, tilt, params});

  // ---- Rock grotto arcade on the flat r=45..60 archive terrace ---------------
  // Outer shell is real collision; two gaps stay open as authored mouths. The
  // archive ring keeps its own floor, so the cave is a roofed arcade, not a
  // second playable deck.
  const G0 = 232 * D, G1 = 286 * D, mouthA = 251 * D, mouthB = 272 * D;
  const MOUTH = 4.6, pieces = 30;
  for (let i = 0; i < pieces; i++) {
    const a = mix(G0, G1, i / pieces), b = mix(G0, G1, (i + 1) / pieces), mid = (a + b) / 2;
    if (Math.min(Math.abs(mid - mouthA), Math.abs(mid - mouthB)) * 57 < MOUTH) continue;
    sector(`grotto-shell-${i}`, 57.4, 60.6, a, b, 5.2 + (i % 3) * .5, i % 4 ? 'stone' : 'brick', 8);
  }
  for (let i = 0; i < 10; i++) {
    const a = mix(G0 + 5 * D, G1 - 5 * D, i / 9), r = 46.4 + (i % 3) * .9;
    const [x, z] = polar(r, a);
    if (clearance([x, z]) < 4.4) continue;
    sector(`grotto-pillar-${i}`, r, r + 1.5, a - 1.3 * D, a + 1.3 * D, 3.4 + (i % 3) * .6, 'stone', 8);
  }
  for (const [index, a] of [[0, mouthA], [1, mouthB]]) {
    const [x, z] = polar(59, a);
    kit(`grotto-arch-${index}`, 'grotto_arch', 'helix.grotto-rock', 'grotto', [x, 8, z], {span: 4.8, rise: 3.4, depth: 3.6, thickness: .9, blocks: 9}, a);
    m.art.portals.push({id: `grotto-mouth-${index}`, at: [x, 8, z], dir: [Math.cos(a), Math.sin(a)], width: 4.0, depth: 5, yaw: a});
  }
  const pool = polar(50.5, (G0 + G1) / 2);
  m.art.meshes.push({id: 'grotto-pool', vertices: [[pool[0] - 3, 8.06, pool[1] - 3], [pool[0] + 3, 8.06, pool[1] - 3], [pool[0] + 3, 8.06, pool[1] + 3], [pool[0] - 3, 8.06, pool[1] + 3]], triangles: [[0, 1, 2], [0, 2, 3]], material: 'water', collision: 'none', walkable: false});

  // ---- Stepped botanical terrace masses (free 100..150 sector) --------------
  // Solid soil shelves with real walkable tops, held clear of the archive ring
  // (r=52) and the crosslink between them, so no second playable floor shares an
  // XZ cell with a lower route.
  const shelfAngles = [104, 112, 120, 128, 136, 144];
  for (let i = 0; i < shelfAngles.length; i++) {
    const a = shelfAngles[i] * D;
    const r = 55.4;
    const [x, z] = polar(r, a);
    if (clearance([x, z]) < 3.0) continue;
    const id = `botanical-shelf-${i}`;
    sector(id, r, r + 2.6, a - 1.5 * D, a + 1.5 * D, 1.8, 'soil', 8);
    kit(`${id}-rim`, 'stepped_terrace', 'helix.soil', 'botanical', [x + 1.3 * Math.cos(a), 8.9, z + 1.3 * Math.sin(a)],
      {tiers: 2, run: 2.2, rise: .45, width: 2.2, depth: 5.4, capMaterial: 'helix.trim'});
    // A second, taller row beyond the crosslink.
    const [bx, bz] = polar(61.5, a);
    if (clearance([bx, bz]) >= 3.0) sector(`botanical-upper-${i}`, 60.2, 62.8, a - 1.4 * D, a + 1.4 * D, 2.3, 'soil', null);
  }
  reserveRoute('botanical-terrace-cross', [...curve(58.9, 103 * D, 147 * D)], 2.5);

  // ---- Varied archive-bay articulation (156..220) ---------------------------
  const bays = [[156, 168], [168, 176], [176, 190], [190, 198], [198, 212], [212, 220]];
  for (const [index, [a, b]] of bays.entries()) {
    const mid = (a + b) / 2, span = (b - a) * D;
    const [x, z] = polar(61.4, mid * D);
    kit(`archive-bay-${index}`, 'facade_bays', 'helix.archive-stone', 'archive', [x, 15.2, z],
      {height: 4.2, depth: .8, arch: index % 2 === 0, bays: [span * .32, span * .42, span * .26], trimMaterial: 'helix.trim'}, mid * D);
    if (span > .34) sector(`archive-blind-${index}`, 60.6, 61.7, (a + 1) * D, (b - 1) * D, 6.2, 'brick', null);
  }

  // ---- Root and greenhouse hero forms (visual) -----------------------------
  for (let i = 0; i < 7; i++) {
    const a = mix(G0 + 6 * D, G1 - 6 * D, i / 6), [x, z] = polar(53 + (i % 2) * 3, a);
    kit(`grotto-root-${i}`, 'root_form', 'helix.bark', 'grotto', [x, floor(x, z), z],
      {height: 13 + (i % 3) * 2, radius: .34, branches: 3, lean: (i % 2 ? 1 : -1) * .18});
  }
  for (let i = 0; i < 14; i++) {
    const a = mix(G0 + 2 * D, G1 - 2 * D, i / 13), [x, z] = polar(48 + (i % 3) * 3, a);
    kit(`grotto-fern-${i}`, 'fern_card', 'helix.fern', 'grotto', [x, floor(x, z) + .9, z], {scale: 1.5 + (i % 3) * .3, fronds: 7});
  }
  for (const a of [70, 76, 82, 88, 94]) {
    const [x, z] = polar(87, a * D);
    kit(`greenhouse-rib-${a}`, 'curved_rib', 'helix.greenhouse-frame', 'canopy', [x, 24.8, z], {inner: 13.4, outer: 14.2, depth: 1.1, start: 0, stop: Math.PI, segments: 28}, a * D, Math.PI / 2);
  }
  kit('greenhouse-ridge', 'pipe', 'helix.greenhouse-frame', 'canopy', [0, 30.4, 87], {radius: .28, sides: 10, path: [[-11, 30.2, 84], [0, 30.6, 87], [11, 30.2, 84]]});
  kit('greenhouse-ridge-south', 'pipe', 'helix.greenhouse-frame', 'canopy', [0, 30.4, -87], {radius: .28, sides: 10, path: [[-11, 30.2, -84], [0, 30.6, -87], [11, 30.2, -84]]});
  for (const s of [-1, 1]) kit(`specimen-root-buttress-${s}`, 'root_form', 'helix.bark', 'lightwell', [s * 6, 0, 0], {height: 11, radius: .42, branches: 2, lean: -s * .2});

  // ---- New walkable crosslinks ---------------------------------------------
  reserveRoute('grotto-loop', [...curve(50, G0 + 3 * D, G1 - 3 * D), ...curve(52.4, G1 - 3 * D, G0 + 3 * D)], 2.5);
  reserveRoute('grotto-spur', (() => { const [mx, mz] = polar(52, mouthA); const [ox, oz] = polar(60, mouthA); return [[mx, mz], polar(56.5, mouthA), [ox, oz]]; })(), 2.5);

  return m;
}
export const recipe = makeRecipe();

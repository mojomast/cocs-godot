import {writeFileSync, mkdirSync} from 'node:fs';
import {art, buildArt} from './art.mjs';
import {fileURLToPath} from 'node:url';
import {nativeArenaGeometryHash} from '../../port/native-arenas/schema.mjs';
import {terrainWallTriangles, terrainTriangles, terrainSupportAt} from '../../game/terrain.mjs';

const out = new URL('../../godot/identity_maps/generated/', import.meta.url);
const p = (x, y, z) => [x, y, z];
function surface(id, x0, z0, x1, z1, y0 = 0, y1 = y0) {
  return {id, material: 'floor', walkable: true, vertices: [p(x0, y0, z0), p(x0, y1, z1), p(x1, y1, z1), p(x1, y0, z0)], triangles: [[0, 1, 2], [0, 2, 3]]};
}

function make(id, name, mode, w, d, palette) {
  const a = {id, name, bounds: {minX: -w / 2, maxX: w / 2, minZ: -d / 2, maxZ: d / 2}, spawns: [], pickups: [], navNodes: [], blocks: [], terrain: {maxSlope: .65, surfaces: [surface('court', -w / 2, -d / 2, w / 2, d / 2)], walls: []}, voidY: -10, ceilingY: 40, raised: false, nextGen: true};
  const data = {schemaVersion: 1, id, name, mode, arena: a, palette, routes: [], cameras: [], landmarks: []};
  data.box = (bid, x, z, bw, bd, h, material = 'shell', baseY = 0) => a.blocks.push({id: bid, x, z, w: bw, d: bd, h, baseY, material});
  data.route = (rid, pts) => data.routes.push({id: rid, points: pts.map(([x, z]) => ({x, y: 0, z}))});
  data.box('north-boundary', 0, -d / 2 - 1, w + 4, 2, 7, 'enamel');
  data.box('south-boundary', 0, d / 2 + 1, w + 4, 2, 7, 'enamel');
  data.box('west-boundary', -w / 2 - 1, 0, 2, d, 7, 'enamel');
  data.box('east-boundary', w / 2 + 1, 0, 2, d, 7, 'enamel');
  return data;
}

export function recipes() {
  const l = make('lacuna-court', 'Lacuna Court', 'deathmatch', 56, 48, ['ded4bd', 'b7b0a0', '202c59', 'ad7045']);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    l.arena.spawns.push([sx * 24, sz * 20]);
    l.box(`pocket-side-${sx}-${sz}`, sx * 20, sz * 19, 2, 4, 3.4);
    l.box(`pocket-front-${sx}-${sz}`, sx * 24, sz * 16, 4, 2, 3.4);
    for (const [x, z] of [[24, 23], [18, 23], [18, 14], [27, 20], [27, 14]]) l.arena.navNodes.push([sx * x, sz * z]);
  }
  for (const sz of [-1, 1]) l.box(`gallery-divider-${sz}`, 0, sz * 21, 4, 6, 4);
  for (const sx of [-1, 1]) l.box(`lane-divider-${sx}`, sx * 25, 0, 6, 4, 3.6);
  l.box('resonator-west', -5, -3, 5, 9, 4.5); l.box('resonator-east', 5, 3, 5, 9, 4.5);
  l.arena.pickups = [['health', -14, 0], ['armor', 14, 0], ['rocket', 0, -13], ['health', 0, 13]];
  l.route('outer-loop', [[-16, -12], [0, -12], [16, -12], [16, 12], [0, 12], [-16, 12], [-16, -12]]);
  l.route('court-crossing', [[-14, 0], [-10, 7], [0, 9], [10, 9], [14, 0], [10, -7], [0, -9], [-10, -9], [-14, 0]]);
  // Terraces are solid infill. Floor replacement prevents overlapping floor layers.
  // Broad 1:6 ascent on north/south edges, isolated from the protected spawn doors.
  for (const sign of [-1, 1]) {
    const x0 = sign < 0 ? -16 : 8, x1 = x0 + 8;
    l.arena.terrain.surfaces.push(surface(`terrace-ramp-${sign}`, x0, -22, x1, -13, 1.5, 0));
    l.arena.terrain.surfaces.push(surface(`terrace-${sign}`, x0, -24, x1, -22, 1.5));
    l.route(`terrace-ascent-${sign}`, [[x0 + 4, -12], [x0 + 4, -22], [x0 + 4, -23]]);
  }
  l.landmarks = [{kind: 'resonator', at: [0, 7, 0], scale: [1, 1, 1]}, {kind: 'sail', at: [-12, 14, -31], scale: [1, 1, 1]}];
  l.cameras = [{id: 'entrance', at: [-16, 1.7, 12], target: [0, 5, 0]}, {id: 'landmark', at: [17, 5, 17], target: [0, 6, 0]}, {id: 'combat', at: [0, 1.7, 12], target: [0, 2, -12]}, {id: 'objective', at: [-13, 2, -11], target: [0, 1, -13]}, {id: 'worst', at: [31, 30, 33], target: [0, 0, 0]}];

  const v = make('vermilion-fold', 'Vermilion Fold', 'domination', 64, 56, ['e3dcc8', 'beaa93', '244d48', 'b84a38']);
  v.arena.spawns = [[-27, -21], [27, -21], [-27, 21], [27, 21], [-27, 0], [27, 0]];
  v.arena.teamSpawns = {0: [[-27, -21], [-27, 21], [-27, 0]], 1: [[27, -21], [27, 21], [27, 0]]};
  for (const sx of [-1, 1]) {
    v.box(`start-shield-${sx}`, sx * 22, 0, 2, 9, 3.4, 'enamel');
    for (const sz of [-1, 1]) {
      v.box(`pavilion-retainer-${sx}-${sz}`, sx * 10, sz * 9, 12, 3, 3.2);
      v.box(`spawn-shield-${sx}-${sz}`, sx * 23, sz * 21, 2, 7, 3.4, 'enamel');
    }
  }
  v.arena.objectiveZones = [{x: 0, z: -17, y: 0, radius: 3.5}, {x: 0, z: 0, y: 0, radius: 3.5}, {x: 0, z: 17, y: 0, radius: 3.5}];
  v.arena.navNodes = v.arena.objectiveZones.map(({x, z}) => [x, z]);
  v.arena.pickups = [['health', -18, -17], ['health', 18, 17], ['armor', -18, 17], ['armor', 18, -17]];
  v.route('west-rotation', [[-18, -17], [-18, 0], [-18, 17]]);
  v.route('east-rotation', [[18, -17], [18, 0], [18, 17]]);
  v.route('objective-axis', [[0, -17], [0, 0], [0, 17]]);
  for (const sx of [-1, 1]) for (const z of [-17, 0, 17]) v.route(`approach-${sx}-${z}`, [[sx * 27, z < 0 ? -21 : z > 0 ? 21 : 0], [sx * 27, z < 0 ? -26 : z > 0 ? 26 : -7], [sx * 18, z < 0 ? -26 : z > 0 ? 26 : -7], [sx * 18, z], [0, z]]);
  v.landmarks = [{kind: 'fan', at: [0, 8, -17], scale: [1, 1, 1]}, {kind: 'crown', at: [0, 10, 0], scale: [1, 1, 1]}, {kind: 'pleat', at: [0, 8, 17], scale: [1, 1, 1]}];
  v.cameras = [{id: 'entrance', at: [-18, 1.7, -17], target: [0, 7, -4]}, {id: 'landmark', at: [13, 4, 13], target: [0, 10, 0]}, {id: 'combat', at: [-18, 1.7, 0], target: [0, 2, 0]}, {id: 'objective', at: [-10, 2, -24], target: [0, 5, -17]}, {id: 'worst', at: [37, 34, 38], target: [0, 0, 0]}];

  const n = make('nacre-engine', 'Nacre Engine', 'horde', 60, 52, ['d3cbbc', 'a6a49c', '142b4a', 'b88b43']);
  // Solo survival layout: start in the south service bay, then rotate through
  // two open supply wings and a northern boss yard. The old six-point symmetric
  // arena spawned the human amid enemies and offered only one distant weapon.
  // The outer circuit always has two exits; low cover interrupts ranged fire
  // without becoming an impassable wall for the source's large enemy archetypes.
  n.arena.spawns = [[-23, -19], [23, -19], [-23, 19], [23, 19], [-23, 0], [23, 0], [0, -21]];
  // Horde uses the source's TEAM spawn scorer. The survivor holds the south
  // bay; enemies can enter from both flanks and the northern yard. Deathmatch
  // still uses the FFA spawn array above and needs no mode-specific override.
  n.arena.teamSpawns = {0: [[-3, 20], [3, 20]], 1: [...n.arena.spawns]};
  n.box('memory-housing', 0, 0, 12, 12, 6, 'enamel');
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) n.box(`shell-pocket-${sx}-${sz}`, sx * 17, sz * 10, 5, 3, 3.2);
  for (const sx of [-1, 1]) {
    n.box(`service-bay-wing-${sx}`, sx * 15, 16, 4.5, 2, 2.3, 'shell');
    n.box(`yard-breakwater-${sx}`, sx * 15, -14, 3, 2, 2.2, 'shell');
  }
  n.box('bay-low-cover-west', -4, 12, 2.5, 2, 1.4, 'cut');
  n.box('bay-low-cover-east', 4, 12, 2.5, 2, 1.4, 'cut');
  n.box('west-workshop-baffle', -13, 1, 2, 5, 3.2, 'enamel');
  n.box('east-condenser-baffle', 13, -1, 2, 5, 3.2, 'enamel');
  // Amber service organs are exact boxes, not art: a 0.3 m decorative fin proud
  // of the housing face must answer rays exactly like the prototype did.
  for (const [x, z] of [[-6.15, 2.5], [6.15, -2.5]]) n.box(`amber-organ-${x}-${z}`, x, z, 0.3, 3.2, 3.4, 'accent');
  n.arena.pickups = [
    ['health', -2, 19], ['ammo', 6, 20], ['scatter', 3, 16],
    ['health', -23, 7], ['armor', -22, -3], ['plasma', -22, 11],
    ['armor', 22, -3], ['shock', 22, 8], ['health', 21, -12],
    ['rocket', 12, -20], ['megahealth', 0, -20], ['flak', -12, -20],
  ];
  // Only these weapons are wave-gated. Source pickup cooldown/collection and
  // between-wave full resupply remain unchanged. The Horde-only adapter releases
  // them when the authoritative wave starts; DM uses the same geometry normally.
  n.arena.hordeCaches = [
    {pickupId: 2, wave: 1, zone: 'South Service Bay'},
    {pickupId: 5, wave: 3, zone: 'West Workshop'},
    {pickupId: 7, wave: 5, zone: 'East Condenser'},
    {pickupId: 9, wave: 7, zone: 'North Yard'},
    {pickupId: 11, wave: 9, zone: 'North Yard'},
  ];
  n.route('retreat-loop', [[0, 20], [-9, 20], [-22, 19], [-23, 6], [-23, -8], [-22, -20], [0, -20], [22, -20], [23, -8], [23, 6], [22, 19], [9, 20], [0, 20]]);
  n.route('inner-retreat', [[0, 20], [-9, 15], [-10, 7], [-10, 0], [-10, -9], [-10, -20], [0, -20], [10, -20], [10, -9], [10, 0], [10, 7], [9, 15], [0, 20]]);
  n.route('west-workshop', [[0, 20], [-9, 20], [-21, 16], [-22, 11], [-23, 6], [-23, -8]]);
  n.route('east-condenser', [[0, 20], [9, 20], [21, 16], [22, 8], [23, 0], [23, -8]]);
  n.route('boss-yard', [[-23, -8], [-22, -20], [-12, -20], [0, -20], [12, -20], [22, -20], [23, -8]]);
  n.landmarks = [{kind: 'drum', at: [0, 8, 0], scale: [1, 1, 1]}, {kind: 'vault', at: [0, 0, 0], scale: [1, 1, 1]}];
  n.cameras = [{id: 'entrance', at: [0, 1.7, 20], target: [0, 4, 0]}, {id: 'landmark', at: [19, 4, 17], target: [0, 8, 0]}, {id: 'combat', at: [-22, 1.7, 8], target: [0, 3, -15]}, {id: 'objective', at: [0, 2, -21], target: [0, 8, 0]}, {id: 'worst', at: [32, 25, 34], target: [0, 0, 0]}];

  return [l, v, n].map(r => {
    const built = buildArt(r);
    delete r.box; delete r.route;
    r.grayboxHash = nativeArenaGeometryHash(r.arena);
    r.art = built.render;
    r.arena.terrain.walls = built.collision;
    r.geometryHash = nativeArenaGeometryHash(r.arena);
    r.spawnPoints = r.arena.spawns.map(([x, z]) => {
      const y = terrainSupportAt(x, z, r.arena.terrain, r.arena.terrain.maxSlope)?.y;
      if (!Number.isFinite(y)) throw new Error(`No spawn support at ${x},${z} on ${r.id}`);
      return {x: +x, y: +y.toFixed(6), z: +z};
    });
    r.colliderSources = colliderSources(r, built);
    r.provenance = {
      godot: '4.5.2.stable.official.6ce3de25a',
      compiler: 'tools/godot-identity-maps/compile.mjs',
      input: 'authored identity recipe + tools/godot-identity-maps/art.mjs',
      supportModel: 'highest walkable XZ support; render triangles exact, collision authored coarse',
    };
    r.artNotes = built.notes;
    return r;
  });
}

function colliderSources(r, built) {
  const sources = [];
  for (const b of r.arena.blocks) {
    sources.push({
      id: `block:${b.id}`, kind: 'box', path: `StaticBody3D:${b.id}/CollisionShape3D`,
      walkable: false, low: [b.x - b.w / 2, b.baseY ?? 0, b.z - b.d / 2],
      high: [b.x + b.w / 2, b.h, b.z + b.d / 2], vertexCount: 8,
    });
  }
  for (const s of r.arena.terrain.surfaces) {
    const ys = s.vertices.map(v => v[1]);
    sources.push({
      id: `floor:${s.id}`, kind: 'triangles', path: `StaticBody3D:${s.id}/CollisionShape3D`,
      walkable: true,
      low: [Math.min(...s.vertices.map(v => v[0])), Math.min(...ys), Math.min(...s.vertices.map(v => v[2]))],
      high: [Math.max(...s.vertices.map(v => v[0])), Math.max(...ys), Math.max(...s.vertices.map(v => v[2]))],
      vertexCount: s.vertices.length,
    });
  }
  for (const w of r.arena.terrain.walls) {
    // Two-point entries are movement-only fences: they own no Godot collider,
    // so they are not collider sources.
    if (!w.vertices) continue;
    const verts = w.vertices;
    const ys = verts.map(v => v[1]);
    sources.push({
      id: `wall:${w.id ?? 'movement-barrier'}`, kind: 'triangles', path: `StaticBody3D:${w.id ?? 'movement-barrier'}/CollisionShape3D`,
      walkable: false,
      low: [Math.min(...verts.map(v => v[0])), Math.min(...ys), Math.min(...verts.map(v => v[2]))],
      high: [Math.max(...verts.map(v => v[0])), Math.max(...ys), Math.max(...verts.map(v => v[2]))],
      vertexCount: verts.length,
    });
  }
  return sources;
}

/** Independent degeneracy gate: the strict parsers and the source BVH both run
 * these, so a bad authored triangle must fail here first. */
export function validateRecipe(r) {
  const walls = terrainWallTriangles(r.arena.terrain);
  const surfaces = terrainTriangles(r.arena.terrain);
  const tris = [...walls, ...surfaces].length;
  if (!Number.isFinite(tris)) throw new Error(`${r.id}: non-finite triangle count`);
  if (r.art.length === 0) throw new Error(`${r.id}: no art`);
  return {
    id: r.id, geometryHash: r.geometryHash, grayboxHash: r.grayboxHash,
    walls: r.arena.terrain.walls.length, wallTriangles: walls.length, wallSegments: wallSegments(r),
    surfaces: r.arena.terrain.surfaces.length, surfaceTriangles: surfaces.length,
    artSurfaces: r.art.length, artTriangles: r.art.reduce((s, x) => s + x.triangles.length, 0),
    blocks: r.arena.blocks.length, colliderSources: r.colliderSources.length,
  };
}

function wallSegments(r) {
  let count = 0;
  for (const w of r.arena.terrain.walls) {
    const verts = w.vertices ?? [w.a, w.b];
    const closed = verts.length > 2, limit = closed ? verts.length : verts.length - 1;
    for (let i = 0; i < limit; i++) {
      const a = verts[i], b = verts[(i + 1) % verts.length];
      if (Math.hypot(b[0] - a[0], b[2] - a[2]) > 1e-9) count++;
    }
  }
  return count;
}

export function compile() {
  mkdirSync(out, {recursive: true});
  for (const r of recipes()) {
    const stats = validateRecipe(r);
    writeFileSync(new URL(r.id + '.json', out), JSON.stringify(r) + '\n');
    console.log(`${r.id} ${r.geometryHash} walls=${stats.walls} segments=${stats.wallSegments} artTriangles=${stats.artTriangles}`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) compile();

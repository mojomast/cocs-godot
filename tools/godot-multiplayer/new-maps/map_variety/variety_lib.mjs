// Source-only helpers for the map-variety Blender/authority revision candidates.
//
// No engine, Blender, network or build is invoked. This module binds the three
// new map revisions to the delivered `map-variety-20261003` Moth pack, computes
// candidate geometry hashes, and runs bounded topology/corridor/collision probes
// that a later Blender + native stage can reproduce exactly.
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,resolve,posix} from 'node:path';
import {terrainSupportAt, terrainWallSegments} from '../../../../game/terrain.mjs';
import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';

export const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
export const PACK_ROOT = 'assets/moth/map-variety-20261003';
export const BASE_MANIFEST = `${PACK_ROOT}/candidate-v2/manifest.json`;
export const OVERLAY_MANIFEST = `${PACK_ROOT}/candidate-v3/manifest.json`;

export const sha256 = data => createHash('sha256').update(data).digest('hex');
export const sha256File = relative => sha256(readFileSync(resolve(REPO_ROOT, relative)));
export const readJson = relative => JSON.parse(readFileSync(resolve(REPO_ROOT, relative), 'utf8'));
export const canonicalGeometryHash = arena => sha256(canonical(arena));

const isSha = value => typeof value === 'string' && /^[0-9a-f]{64}$/.test(value);

/**
 * Merge the immutable base pack with its additive image-engine overlay.
 * Resolution is by stable id + channel key, never array position or file glob.
 */
export function loadPack({base = BASE_MANIFEST, overlay = OVERLAY_MANIFEST} = {}) {
  const baseDir = base.replace(/\/manifest\.json$/, '');
  const overlayDir = overlay.replace(/\/manifest\.json$/, '');
  const baseBytes = readFileSync(resolve(REPO_ROOT, base));
  const overlayBytes = readFileSync(resolve(REPO_ROOT, overlay));
  const baseManifest = JSON.parse(baseBytes);
  const overlayManifest = JSON.parse(overlayBytes);
  if (baseManifest.schema !== 'moth-map-material-pack/v1') throw new Error('Unexpected base pack schema');
  if (overlayManifest.schema !== 'moth-map-material-overlay/v1') throw new Error('Unexpected overlay schema');
  const declaredBase = posix.normalize(`${overlayDir}/${overlayManifest.basePack?.manifest ?? ''}`);
  if (declaredBase !== base) throw new Error('Overlay does not reference the selected base pack');
  const baseSha = sha256(baseBytes), overlaySha = sha256(overlayBytes);
  if (overlayManifest.basePack.sha256 !== baseSha) throw new Error('Overlay base-pack hash does not match base bytes');

  const materials = new Map();
  for (const material of baseManifest.materials) materials.set(material.id, {dir: baseDir, origin: 'base', ...material});
  for (const material of overlayManifest.materials) materials.set(material.id, {dir: overlayDir, origin: 'overlay', ...material});

  const textureDirs = new Map();
  for (const [key, entry] of Object.entries(baseManifest.textures)) textureDirs.set(key, {dir: baseDir, entry});
  for (const [key, entry] of Object.entries(overlayManifest.textures)) textureDirs.set(key, {dir: overlayDir, entry});

  /**
   * Resolve `materials[].channels[channel]` in `textures[]` and return the
   * repository-relative path, expected sha256 and actual on-disk hash.
   */
  const channel = (resource, name) => {
    const material = materials.get(resource);
    if (!material) throw new Error(`Unknown map-variety resource id: ${resource}`);
    const key = material.channels?.[name];
    if (!key) throw new Error(`Resource ${resource} has no '${name}' channel`);
    const found = textureDirs.get(key);
    if (!found) throw new Error(`Channel ${key} is not in the merged texture registry`);
    const relative = `${found.dir}/${found.entry.path}`;
    const actual = sha256File(relative);
    if (actual !== found.entry.sha256) throw new Error(`PNG hash mismatch: ${relative}`);
    return {key, relative, sha256: found.entry.sha256, colorSpace: found.entry.colorSpace, semantic: found.entry.semantic, normalConvention: found.entry.normalConvention, material};
  };
  return {base, overlay, baseSha, overlaySha, materials, textures: textureDirs, channel};
}

/** Every binding must name a real resource and resolve its channels on disk. */
export function validateBindings(mapId, bindings, pack) {
  if (bindings.schema !== 'map-variety-bindings/v1') throw new Error(`${mapId}: bindings schema mismatch`);
  if (bindings.mapId !== mapId) throw new Error(`${mapId}: bindings mapId mismatch`);
  const materials = bindings.materials;
  if (!materials || typeof materials !== 'object') throw new Error(`${mapId}: missing materials`);
  const names = Object.keys(materials);
  if (!names.length || names.length > 64) throw new Error(`${mapId}: unbounded material registry`);
  const resolved = {};
  for (const [name, binding] of Object.entries(materials)) {
    if (!/^[A-Za-z0-9_.-]+$/.test(name)) throw new Error(`${mapId}: bad material name ${name}`);
    if (binding.role === 'preserve') {
      if (binding.resource) throw new Error(`${mapId}/${name}: preserved material must not name a resource`);
      resolved[name] = {role: 'preserve'};
      continue;
    }
    if (binding.role !== 'surface') throw new Error(`${mapId}/${name}: role must be surface or preserve`);
    if (typeof binding.resource !== 'string' || !binding.resource) throw new Error(`${mapId}/${name}: missing resource id`);
    const albedo = pack.channel(binding.resource, 'albedo');
    const normal = pack.channel(binding.resource, 'normal');
    if (normal.normalConvention && !/OpenGL\s*\+Y/.test(normal.normalConvention)) throw new Error(`${mapId}/${name}: normal is not OpenGL +Y`);
    if (!Number.isFinite(binding.tilesPerMeter) || binding.tilesPerMeter <= 0 || binding.tilesPerMeter > 16) throw new Error(`${mapId}/${name}: invalid tilesPerMeter`);
    resolved[name] = {
      role: 'surface', resource: binding.resource,
      albedo: albedo.relative, albedoKey: albedo.key,
      normal: normal.relative, normalKey: normal.key,
      normalStrength: binding.normalStrength ?? 1,
      tilesPerMeter: binding.tilesPerMeter,
    };
  }
  return {mapId, names, resolved};
}

/** Build the authority wrapper exactly like the accepted map builders do. */
export function authorityFor(id, arena, {support = true} = {}) {
  const maxSlope = arena.terrain?.maxSlope ?? Infinity;
  const spawnPoints = support
    ? arena.spawns.map(([x, z]) => ({x, y: terrainSupportAt(x, z, arena.terrain, maxSlope)?.y, z}))
    : [];
  return {
    schemaVersion: 1, id, name: arena.name,
    geometryHash: canonicalGeometryHash(arena),
    recipeHash: sha256(JSON.stringify(arena) + '\n'),
    spawnPoints, arena,
  };
}

const distancePointSegment = (px, pz, a, b) => {
  const dx = b.x - a.x, dz = b.z - a.z;
  const length2 = dx * dx + dz * dz || 1;
  const t = Math.max(0, Math.min(1, ((px - a.x) * dx + (pz - a.z) * dz) / length2));
  return Math.hypot(px - (a.x + t * dx), pz - (a.z + t * dz));
};

/** Triangles only: an untriangulated vertical quad can fail standing collision. */
export function assertWallTriangles(arena, failures) {
  for (const [index, wall] of (arena.terrain?.walls ?? []).entries()) {
    const vertices = wall.vertices ?? (wall.a && wall.b ? [wall.a, wall.b] : null);
    if (!vertices || vertices.length !== 3) { failures.push(`wall[${index}] is not a triangle (${vertices?.length ?? 0} vertices)`); continue; }
    for (const point of vertices) for (const value of point) if (!Number.isFinite(value)) failures.push(`wall[${index}] has a non-finite vertex`);
    const [a, b, c] = vertices;
    const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
    const vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
    const area = Math.hypot(uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx);
    if (area <= 1e-9) failures.push(`wall[${index}] is degenerate`);
  }
}

/** Every blocking wall triangle must exist as rendered geometry and vice versa. */
export function assertCollisionVisualCongruence(arena, failures) {
  const key = t => t.map(v => v.map(n => Math.round(n * 1000) / 1000).join(',')).sort().join('|');
  const visible = new Set();
  for (const mesh of arena.art?.meshes ?? []) {
    if (mesh.collision !== 'wall') continue;
    for (const triangle of mesh.triangles) visible.add(key(triangle.map(i => mesh.vertices[i])));
  }
  const collision = new Set();
  for (const wall of arena.terrain?.walls ?? []) {
    const vertices = wall.vertices ?? (wall.a && wall.b ? [wall.a, wall.b] : []);
    if (vertices.length === 3) collision.add(key(vertices));
  }
  for (const k of collision) if (!visible.has(k)) { failures.push(`wall triangle has no rendered counterpart: ${k}`); break; }
  for (const k of visible) if (!collision.has(k)) { failures.push(`rendered wall triangle has no collision: ${k}`); break; }
}

export function supportFailures(arena, points, label, failures) {
  const maxSlope = arena.terrain?.maxSlope ?? Infinity;
  for (const [index, point] of points.entries()) {
    const x = Array.isArray(point) ? point[0] : point.x;
    const z = Array.isArray(point) ? point[1] : point.z;
    const support = terrainSupportAt(x, z, arena.terrain, maxSlope);
    if (!support) { failures.push(`${label}[${index}] has no walkable support at ${x},${z}`); continue; }
    const declared = Array.isArray(point) ? undefined : point.y;
    if (Number.isFinite(declared) && Math.abs(declared - support.y) > 0.35) failures.push(`${label}[${index}] y=${declared} disagrees with support ${support.y.toFixed(3)}`);
  }
}

/** Centerline clearance against the actual wall segments (player radius 0.42). */
export function routeClearanceFailures(arena, routes, minimum, failures) {
  const segments = terrainWallSegments(arena.terrain);
  for (const route of routes) {
    for (const point of route.points ?? []) {
      const [x, z] = Array.isArray(point) ? point : [point.x, point.z];
      let nearest = Infinity;
      for (const {a, b} of segments) nearest = Math.min(nearest, distancePointSegment(x, z, a, b));
      if (nearest < minimum) { failures.push(`route ${route.id} point ${x.toFixed(1)},${z.toFixed(1)} is ${nearest.toFixed(3)} m from a wall (< ${minimum})`); break; }
    }
  }
}

/** Two playable nodes stacked over one XZ cell would break highest-floor reading. */
export function stackedPlayableFailures(arena, failures) {
  const maxSlope = arena.terrain?.maxSlope ?? Infinity;
  const nodes = (arena.navNodes ?? []).filter(n => Number.isFinite(n.x) && Number.isFinite(n.z))
    .map(n => ({...n, y: terrainSupportAt(n.x, n.z, arena.terrain, maxSlope)?.y}));
  for (let i = 0; i < nodes.length; i++) for (let j = i + 1; j < nodes.length; j++) {
    const a = nodes[i], b = nodes[j];
    if (Math.hypot(a.x - b.x, a.z - b.z) > 0.75) continue;
    if (Number.isFinite(a.y) && Number.isFinite(b.y) && Math.abs(a.y - b.y) > 1.0) failures.push(`stacked playable nodes ${i}/${j} differ by ${Math.abs(a.y - b.y).toFixed(2)} m`);
  }
}

/** Connectivity over authored nav nodes using the source's ~3 m route chord scale. */
export function navConnectivity(arena, {chord = 5.0, rise = 1.6} = {}) {
  const nodes = (arena.navNodes ?? []).filter(n => Number.isFinite(n.x) && Number.isFinite(n.z))
    .map(n => ({...n, y: terrainSupportAt(n.x, n.z, arena.terrain)?.y ?? 0}));
  const seen = new Set([0]);
  const queue = [0];
  while (queue.length) {
    const i = queue.shift();
    for (let j = 0; j < nodes.length; j++) {
      if (seen.has(j)) continue;
      if (Math.hypot(nodes[i].x - nodes[j].x, nodes[i].z - nodes[j].z) > chord) continue;
      if (Math.abs(nodes[i].y - nodes[j].y) > rise) continue;
      seen.add(j); queue.push(j);
    }
  }
  return {nodes: nodes.length, connected: seen.size, reachable: seen};
}

/** A horizontal ray must pass through a real opening rather than an invisible box. */
export function portalFailures(arena, portals, failures) {
  // Local triangle set keeps this probe independent of the terrain module caches.
  const triangles = [];
  for (const wall of arena.terrain?.walls ?? []) {
    const v = wall.vertices ?? (wall.a && wall.b ? [wall.a, wall.b] : []);
    for (let i = 1; i < v.length - 1; i++) triangles.push([v[0], v[i], v[i + 1]]);
  }
  const hit = (origin, direction, max) => {
    let best = null;
    for (const [a, b, c] of triangles) {
      const edge1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
      const edge2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
      const h = [direction[1] * edge2[2] - direction[2] * edge2[1], direction[2] * edge2[0] - direction[0] * edge2[2], direction[0] * edge2[1] - direction[1] * edge2[0]];
      const det = edge1[0] * h[0] + edge1[1] * h[1] + edge1[2] * h[2];
      if (Math.abs(det) <= 1e-9) continue;
      const inv = 1 / det;
      const s = [origin[0] - a[0], origin[1] - a[1], origin[2] - a[2]];
      const u = inv * (s[0] * h[0] + s[1] * h[1] + s[2] * h[2]);
      if (u < -1e-9 || u > 1 + 1e-9) continue;
      const q = [s[1] * edge1[2] - s[2] * edge1[1], s[2] * edge1[0] - s[0] * edge1[2], s[0] * edge1[1] - s[1] * edge1[0]];
      const v = inv * (direction[0] * q[0] + direction[1] * q[1] + direction[2] * q[2]);
      if (v < -1e-9 || u + v > 1 + 1e-9) continue;
      const distance = inv * (edge2[0] * q[0] + edge2[1] * q[1] + edge2[2] * q[2]);
      if (distance >= 0 && distance <= max && (best === null || distance < best)) best = distance;
    }
    return best;
  };
  for (const portal of portals) {
    const [x, y, z] = portal.at;
    const dir = portal.dir ?? [Math.sin(portal.yaw ?? 0), 0, Math.cos(portal.yaw ?? 0)];
    const half = (portal.width ?? 2) / 2;
    for (const offset of [-half * 0.55, 0, half * 0.55]) {
      for (const height of [0.9, 1.7]) {
        const origin = [x + dir[2] * offset, y + height, z - dir[0] * offset];
        if (hit(origin, dir, portal.depth ?? 6) !== null) failures.push(`portal ${portal.id} is blocked (offset ${offset}, height ${height})`);
      }
    }
  }
}

export function materialNamesUsed(arena, bindings) {
  const used = new Set();
  for (const surface of arena.terrain?.surfaces ?? []) used.add(surface.material);
  for (const wall of arena.terrain?.walls ?? []) used.add(wall.material);
  for (const mesh of arena.art?.meshes ?? []) used.add(mesh.material);
  for (const block of arena.blocks ?? []) used.add(block.material);
  for (const piece of arena.art?.pieces ?? []) used.add(piece.material);
  for (const kit of arena.art?.kit ?? []) used.add(kit.material);
  const missing = [...used].filter(name => name && !(name in bindings.materials));
  return {used: [...used].filter(Boolean).sort(), missing};
}

/** Common harness: returns {failures, geometryHash, authority, connectivity}. */
export function auditArena(arena, {bindings, pack, routes = arena.routes ?? [], portals = arena.art?.portals ?? [], clearance = 0.5, label = arena.id, visualCongruence = true} = {}) {
  const failures = [];
  if (!bindings || !pack) throw new Error('auditArena requires bindings and pack');
  const {missing} = materialNamesUsed(arena, bindings);
  for (const name of missing) failures.push(`${label}: unbound material ${name}`);
  assertWallTriangles(arena, failures);
  if (visualCongruence) assertCollisionVisualCongruence(arena, failures);
  supportFailures(arena, arena.spawns ?? [], 'spawn', failures);
  supportFailures(arena, arena.objectiveZones ?? [], 'objective', failures);
  for (const [team, pool] of Object.entries(arena.teamSpawns ?? {})) supportFailures(arena, pool, `teamSpawn.${team}`, failures);
  for (const [team, flag] of Object.entries(arena.flagSpawns ?? {})) supportFailures(arena, [{x: flag.x, z: flag.z}], `flagSpawn.${team}`, failures);
  supportFailures(arena, arena.navNodes ?? [], 'navNode', failures);
  routeClearanceFailures(arena, routes, clearance, failures);
  routeReachabilityFailures(arena, routes, failures);
  stackedPlayableFailures(arena, failures);
  portalFailures(arena, portals, failures);
  const connectivity = navConnectivity(arena);
  return {failures, geometryHash: canonicalGeometryHash(arena), authority: authorityFor(label, arena), connectivity};
}

/** Nodes reachable from the first authored nav node under the source chord scale. */
export function reachableNodes(arena, {chord = 5.0, rise = 1.6} = {}) {
  return navConnectivity(arena, {chord, rise}).reachable;
}

/** Every point of the listed routes must map to a reachable authored nav node. */
export function routeReachabilityFailures(arena, routes, failures) {
  const {reachable, nodes} = navConnectivity(arena);
  const list = (arena.navNodes ?? []).filter(n => Number.isFinite(n.x) && Number.isFinite(n.z));
  for (const route of routes) {
    for (const point of route.points ?? []) {
      const [x, z] = Array.isArray(point) ? point : [point.x, point.z];
      let best = -1, bestDistance = Infinity;
      for (let i = 0; i < list.length; i++) {
        const distance = Math.hypot(list[i].x - x, list[i].z - z);
        if (distance < bestDistance) { bestDistance = distance; best = i; }
      }
      if (best >= 0 && !reachable.has(best)) { failures.push(`route ${route.id} point ${x.toFixed(1)},${z.toFixed(1)} is unreachable`); break; }
    }
  }
  void nodes;
}

export function writeCandidate({mapId, revision, authority, bindings, pack, report}) {
  return {
    schemaVersion: 1,
    kind: 'map-variety-candidate/v1',
    mapId, revision,
    moth: {base: pack.base, baseSha256: pack.baseSha, overlay: pack.overlay, overlaySha256: pack.overlaySha},
    authority: {path: `port/new-maps/${mapId}/variety/${revision}/authority.json`, geometryHash: authority.geometryHash, recipeHash: authority.recipeHash},
    materials: bindings.materials,
    kit: {directives: (authority.arena.art?.kit ?? []).length, classes: [...new Set((authority.arena.art?.kit ?? []).map(k => k.class))].sort()},
    probes: report,
    acceptance: 'pending Blender master/GLB generation and native import; no mode acceptance inherited',
  };
}

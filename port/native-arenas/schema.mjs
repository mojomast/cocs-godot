import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {terrainTriangles, terrainWallTriangles, terrainSupportAt} from '../../game/terrain.mjs';
import {nativeArenaEntry} from './catalog.mjs';

export const ARENA_MAX_BYTES = 8 * 1024 * 1024;
// Cross-agent/package contract: sort object keys recursively, preserve array
// order, and serialize finite numbers with Node JSON.stringify semantics.
export function canonicalArenaJSON(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalArenaJSON).join(',')}]`;
  if (value !== null && typeof value === 'object') return `{${Object.keys(value).sort()
    .map(key => `${JSON.stringify(key)}:${canonicalArenaJSON(value[key])}`).join(',')}}`;
  return JSON.stringify(value);
}
export function nativeArenaGeometryHash(arena) {
  return createHash('sha256').update(canonicalArenaJSON(arena)).digest('hex');
}
const fail = label => { throw new TypeError(`Invalid native arena: ${label}`); };
export const record = value => value !== null && typeof value === 'object' &&
  !Array.isArray(value) && [Object.prototype, null].includes(Object.getPrototypeOf(value));
export function keys(value, allowed, label) {
  if (!record(value) || Object.keys(value).some(key => !allowed.includes(key))) fail(label);
}
const number = (value, min, max, label) => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) fail(label);
};
const text = (value, label, max = 128) => {
  if (typeof value !== 'string' || !value.length || value.length > max || /[\u0000-\u001f\u007f]/.test(value)) fail(label);
};
const list = (value, min, max, label) => {
  if (!Array.isArray(value) || value.length < min || value.length > max) fail(label);
};
// Presentation-only metadata is bounded JSON, never interpreted as sim options.
// This also rejects prototype keys and non-JSON values in direct factory calls.
function jsonTree(value, depth = 0, budget = {left:1500000}) {
  if (--budget.left < 0 || depth > 16) fail('JSON complexity');
  if (value === null || typeof value === 'boolean') return;
  if (typeof value === 'number') return number(value, -1e9, 1e9, 'finite JSON number');
  if (typeof value === 'string') { if (value.length > 4096) fail('JSON string'); return; }
  if (Array.isArray(value)) { for (const item of value) jsonTree(item, depth + 1, budget); return; }
  if (!record(value)) fail('JSON object');
  for (const [key, item] of Object.entries(value)) {
    if (['__proto__', 'prototype', 'constructor'].includes(key) || key.length > 128) fail('JSON key');
    jsonTree(item, depth + 1, budget);
  }
}
function point(value, label) {
  list(value, 3, 3, label);
  value.forEach(n => number(n, -1024, 1024, label));
}
function mesh(surface, label, wall = false) {
  keys(surface, ['id', 'material', 'walkable', 'vertices', 'triangles'], label);
  text(surface.id, `${label}.id`); text(surface.material, `${label}.material`);
  if (!wall && typeof surface.walkable !== 'boolean') fail(`${label}.walkable`);
  if (wall && surface.walkable !== undefined && surface.walkable !== false) fail(`${label}.walkable`);
  list(surface.vertices, 3, 100000, `${label}.vertices`);
  surface.vertices.forEach(v => point(v, `${label}.vertex`));
  if (!wall || surface.triangles !== undefined) {
    list(surface.triangles, 1, 100000, `${label}.triangles`);
    for (const triangle of surface.triangles) {
      list(triangle, 3, 3, `${label}.triangle`);
      if (triangle.some(i => !Number.isInteger(i) || i < 0 || i >= surface.vertices.length)) fail(`${label}.index`);
    }
  }
}

/** Parse the generated envelope, not a source-map path or client map JSON.
 * Returns an independent JSON tree. Callers may retain metadata for correlation.
 */
export function parseNativeArena(data, expectedId) {
  if (typeof data === 'string' || Buffer.isBuffer(data)) {
    if (Buffer.byteLength(data) > ARENA_MAX_BYTES) fail('file size');
    data = JSON.parse(String(data));
  }
  jsonTree(data);
  keys(data, ['schemaVersion', 'id', 'name', 'geometryHash', 'arena', 'spawnPoints', 'routes', 'colliderSources', 'provenance'], 'envelope');
  nativeArenaEntry(data.id);
  if (expectedId !== undefined && data.id !== nativeArenaEntry(expectedId).id) fail('ID mismatch');
  if (data.schemaVersion !== 1) fail('schemaVersion');
  text(data.name, 'name');
  if (typeof data.geometryHash !== 'string' || !/^[a-f0-9]{64}$/.test(data.geometryHash)) fail('geometryHash');
  const a = data.arena;
  keys(a, ['id', 'name', 'description', 'tag', 'color', 'background', 'bounds', 'minX', 'maxX', 'minZ', 'maxZ',
    'spawns', 'pickups', 'navNodes', 'blocks', 'terrain', 'voidY', 'ceilingY', 'raised', 'nextGen'], 'arena fields');
  if (a.id !== data.id || a.name !== data.name) fail('arena identity');
  for (const key of ['description', 'tag', 'color', 'background']) if (a[key] !== undefined) text(a[key], key, 512);
  keys(a.bounds, ['minX', 'maxX', 'minZ', 'maxZ'], 'bounds');
  for (const key of ['minX', 'maxX', 'minZ', 'maxZ']) number(a.bounds[key], -256, 256, key);
  for (const key of ['minX', 'maxX', 'minZ', 'maxZ']) if (a[key] !== undefined && a[key] !== a.bounds[key]) fail('duplicate bounds mismatch');
  if (a.bounds.minX >= a.bounds.maxX || a.bounds.minZ >= a.bounds.maxZ ||
      a.bounds.maxX - a.bounds.minX > 160 || a.bounds.maxZ - a.bounds.minZ > 160) fail('bounds extent');
  const xz = (x, z, label) => {
    number(x, a.bounds.minX, a.bounds.maxX, label);
    number(z, a.bounds.minZ, a.bounds.maxZ, label);
  };
  for (const [field, minimum, maximum] of [['spawns', 2, 64], ['navNodes', 2, 4096]]) {
    list(a[field], minimum, maximum, field);
    for (const p of a[field]) { list(p, 2, 2, field); xz(p[0], p[1], field); }
  }
  list(a.pickups, 0, 256, 'pickups');
  const kinds = ['health', 'armor', 'ammo', 'rocket', 'rail', 'scatter', 'plasma', 'grenade', 'shock', 'flak', 'marksman', 'smg', 'overcharge', 'haste', 'overshield', 'cloak'];
  for (const p of a.pickups) {
    list(p, 3, 3, 'pickup');
    if (!kinds.includes(p[0])) fail('pickup kind');
    xz(p[1], p[2], 'pickup position');
  }
  list(a.blocks, 0, 2048, 'blocks');
  for (const b of a.blocks) {
    keys(b, ['id', 'kind', 'x', 'z', 'w', 'd', 'h', 'baseY', 'material', 'color'], 'block');
    for (const key of ['x', 'z', 'h']) number(b[key], -1024, 1024, `block.${key}`);
    for (const key of ['w', 'd']) number(b[key], .001, 512, `block.${key}`);
    if (b.baseY !== undefined) { number(b.baseY, -1024, b.h - .001, 'block.baseY'); }
    for (const key of ['id', 'kind', 'material', 'color']) if (b[key] !== undefined) text(b[key], `block.${key}`);
  }
  number(a.voidY, -1024, 1024, 'voidY');
  if (a.ceilingY !== undefined) number(a.ceilingY, a.voidY + 2, 1024, 'ceilingY');
  if (a.raised !== undefined && a.raised !== false) fail('raised must be false');
  // An existing source navigation mode, not a new protocol field: the locked
  // source `navigation()` selects its spatial edge builder when `nextGen` is
  // true. Aurora Basin opts in to keep cold construction within budget; the
  // key allowlist and canonical arena hash validation remain unchanged.
  if (a.nextGen !== undefined && typeof a.nextGen !== 'boolean') fail('nextGen must be boolean');
  keys(a.terrain, ['maxSlope', 'surfaces', 'walls'], 'terrain');
  number(a.terrain.maxSlope, .01, Math.PI / 2, 'maxSlope');
  list(a.terrain.surfaces, 1, 4096, 'surfaces');
  list(a.terrain.walls, 0, 50000, 'walls');
  a.terrain.surfaces.forEach(s => mesh(s, 'surface'));
  a.terrain.walls.forEach(s => {
    if (record(s) && Object.hasOwn(s, 'a')) {
      keys(s, ['a', 'b', 'material'], 'wall segment');
      point(s.a, 'wall.a'); point(s.b, 'wall.b'); text(s.material, 'wall.material');
    } else mesh(s, 'wall', true);
  });
  for (const collection of [a.terrain.surfaces, a.terrain.walls.filter(s => s.id !== undefined)]) {
    if (new Set(collection.map(s => s.id)).size !== collection.length) fail('duplicate surface/wall ID');
  }
  // Use source winding/degeneracy and highest-XZ support semantics verbatim.
  terrainTriangles(a.terrain); terrainWallTriangles(a.terrain);
  const support = (x, z) => terrainSupportAt(x, z, a.terrain, a.terrain.maxSlope)?.y;
  for (const [x, z] of [...a.spawns, ...a.navNodes, ...a.pickups.map(p => p.slice(1))]) {
    const y = support(x, z);
    if (!Number.isFinite(y) || y <= a.voidY) fail('spawn/nav/pickup lacks walkable support above void');
  }
  list(data.spawnPoints, a.spawns.length, a.spawns.length, 'spawnPoints');
  data.spawnPoints.forEach((p, i) => {
    keys(p, ['x', 'y', 'z'], 'spawnPoint');
    point([p.x, p.y, p.z], 'spawnPoint');
    if (p.x !== a.spawns[i][0] || p.z !== a.spawns[i][1] || Math.abs(p.y - support(p.x, p.z)) > .15) fail('spawnPoint/source support mismatch');
  });
  list(data.routes, 0, 256, 'routes');
  for (const route of data.routes) {
    keys(route, ['id', 'points'], 'route'); text(route.id, 'route.id');
    list(route.points, 2, 10000, 'route.points');
    for (const p of route.points) { keys(p, ['x', 'y', 'z'], 'route point'); point([p.x, p.y, p.z], 'route point'); xz(p.x, p.z, 'route point'); }
  }
  if (data.colliderSources !== undefined) {
    list(data.colliderSources, 0, 10000, 'colliderSources');
    for (const source of data.colliderSources) {
      keys(source, ['id', 'kind', 'path', 'walkable', 'low', 'high', 'vertexCount'], 'collider source');
      for (const key of ['id', 'kind', 'path']) text(source[key], `collider.${key}`, 512);
      if (!['convex', 'triangles', 'box', 'cylinder', 'sphere', 'capsule'].includes(source.kind) || typeof source.walkable !== 'boolean') fail('collider kind/walkable');
      point(source.low, 'collider.low'); point(source.high, 'collider.high');
      if (!Number.isInteger(source.vertexCount) || source.vertexCount < 3 || source.vertexCount > 500000) fail('collider.vertexCount');
    }
  }
  if (data.provenance !== undefined) {
    keys(data.provenance, ['godot', 'compiler', 'input', 'supportModel'], 'provenance');
    for (const key of ['godot', 'compiler', 'input', 'supportModel']) text(data.provenance[key], `provenance.${key}`, 512);
  }
  if (nativeArenaGeometryHash(a) !== data.geometryHash) fail('geometryHash does not match canonical arena');
  return structuredClone(data);
}

/** Only three static package-relative files can be opened; no path override. */
export function readNativeArena(mapId) {
  const entry = nativeArenaEntry(mapId);
  const data = readFileSync(new URL(`../../${entry.path}`, import.meta.url));
  return parseNativeArena(data, mapId);
}

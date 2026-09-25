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
const color = (value, label) => {
  if (typeof value !== 'string' || !/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value)) fail(label);
};
const hash = (value, label) => {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) fail(label);
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
// The identity compiler emits wall segments as either [x,y,z] arrays or
// {x,y,z} records; the source terrain readers accept both. Native envelopes
// keep their historical array-only form.
function pointLike(value, label) {
  const p = Array.isArray(value) ? value : record(value) ? [value.x, value.y, value.z] : null;
  if (p === null) fail(label);
  list(p, 3, 3, label);
  p.forEach(n => number(n, -1024, 1024, label));
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

const COLLIDER_KINDS = ['convex', 'triangles', 'box', 'cylinder', 'sphere', 'capsule'];
const PICKUP_KINDS = ['health', 'armor', 'ammo', 'megahealth', 'rocket', 'rail', 'scatter', 'plasma', 'grenade', 'shock', 'flak', 'marksman', 'smg', 'overcharge', 'haste', 'overshield', 'cloak'];
const IDENTITY_MODES = ['deathmatch', 'domination', 'horde'];
const TEAM_KEYS = ['0', '1', 'red', 'blue', 'west', 'east'];
const teamOf = key => ['0', 'red', 'west'].includes(key) ? 0 : 1;

/** Native envelopes always carry spawnPoints; identity envelopes keep the
 * source `arena.spawns` array authoritative and may add the same explicit
 * contract later, in which case it is checked with identical strictness. */
function validateSpawnPoints(envelope, arena, support, required) {
  if (envelope.spawnPoints === undefined && !required) return;
  list(envelope.spawnPoints, arena.spawns.length, arena.spawns.length, 'spawnPoints');
  envelope.spawnPoints.forEach((p, i) => {
    keys(p, ['x', 'y', 'z'], 'spawnPoint');
    point([p.x, p.y, p.z], 'spawnPoint');
    if (p.x !== arena.spawns[i][0] || p.z !== arena.spawns[i][1] || Math.abs(p.y - support(p.x, p.z)) > .15) fail('spawnPoint/source support mismatch');
  });
}
function validateColliderSources(envelope) {
  if (envelope.colliderSources === undefined) return;
  list(envelope.colliderSources, 0, 10000, 'colliderSources');
  for (const source of envelope.colliderSources) {
    keys(source, ['id', 'kind', 'path', 'walkable', 'low', 'high', 'vertexCount'], 'collider source');
    for (const key of ['id', 'kind', 'path']) text(source[key], `collider.${key}`, 512);
    if (!COLLIDER_KINDS.includes(source.kind) || typeof source.walkable !== 'boolean') fail('collider kind/walkable');
    point(source.low, 'collider.low'); point(source.high, 'collider.high');
    if (!Number.isInteger(source.vertexCount) || source.vertexCount < 3 || source.vertexCount > 500000) fail('collider.vertexCount');
  }
}
function validateProvenance(envelope) {
  if (envelope.provenance === undefined) return;
  keys(envelope.provenance, ['godot', 'compiler', 'input', 'supportModel'], 'provenance');
  for (const key of ['godot', 'compiler', 'input', 'supportModel']) text(envelope.provenance[key], `provenance.${key}`, 512);
}
/** Identity-map presentation/objective metadata. `objectiveZones` is exactly
 * the three authored fold points on vermilion-fold; `teamSpawns` is validated
 * as source-read team pools (`0/1`, `red/blue`, `west/east` spellings). */
function validateIdentityZones(zones, bounds, support, id, voidY) {
  // Vermilion Fold keeps its exact three authored fold points; other identity
  // maps may author a future alternative set, still bounded and validated.
  list(zones, id === 'vermilion-fold' ? 3 : 1, id === 'vermilion-fold' ? 3 : 16, 'objectiveZones');
  for (const zone of zones) {
    keys(zone, ['id', 'label', 'x', 'y', 'z', 'radius'], 'objectiveZone');
    for (const key of ['id', 'label']) if (zone[key] !== undefined) text(zone[key], `objectiveZone.${key}`);
    number(zone.x, bounds.minX, bounds.maxX, 'objectiveZone.x');
    number(zone.z, bounds.minZ, bounds.maxZ, 'objectiveZone.z');
    if (zone.y !== undefined) number(zone.y, -1024, 1024, 'objectiveZone.y');
    if (zone.radius !== undefined) number(zone.radius, .5, 32, 'objectiveZone.radius');
    const y = support(zone.x, zone.z);
    if (!Number.isFinite(y) || y <= voidY) fail('objectiveZone lacks walkable support above void');
  }
}
function validateIdentityTeamSpawns(teamSpawns, bounds, support, voidY) {
  keys(teamSpawns, TEAM_KEYS, 'teamSpawns');
  const entries = Object.entries(teamSpawns);
  if (entries.length !== 2) fail('teamSpawns must name two teams');
  const covered = new Set();
  for (const [key, pool] of entries) {
    list(pool, 2, 16, `teamSpawns.${key}`);
    covered.add(teamOf(key));
    for (const spawn of pool) {
      list(spawn, 2, 2, `teamSpawns.${key} point`);
      const [x, z] = spawn;
      number(x, bounds.minX, bounds.maxX, `teamSpawns.${key} x`);
      number(z, bounds.minZ, bounds.maxZ, `teamSpawns.${key} z`);
      const y = support(x, z);
      if (!Number.isFinite(y) || y <= voidY) fail('team spawn lacks walkable support above void');
    }
  }
  if (covered.size !== 2) fail('teamSpawns must cover both teams');
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
  for (const p of a.pickups) {
    list(p, 3, 3, 'pickup');
    if (!PICKUP_KINDS.includes(p[0])) fail('pickup kind');
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
  validateSpawnPoints(data, a, support, true);
  list(data.routes, 0, 256, 'routes');
  for (const route of data.routes) {
    keys(route, ['id', 'points'], 'route'); text(route.id, 'route.id');
    list(route.points, 2, 10000, 'route.points');
    for (const p of route.points) { keys(p, ['x', 'y', 'z'], 'route point'); point([p.x, p.y, p.z], 'route point'); xz(p.x, p.z, 'route point'); }
  }
  validateColliderSources(data);
  validateProvenance(data);
  if (nativeArenaGeometryHash(a) !== data.geometryHash) fail('geometryHash does not match canonical arena');
  return structuredClone(data);
}

/** Parse the identity-map envelope. Same canonical `arena` hash contract as
 * native arenas plus identity presentation metadata (mode, palette, art,
 * cameras, landmarks) and the optional team/objective fields. */
export function parseIdentityArena(data, expectedId) {
  if (typeof data === 'string' || Buffer.isBuffer(data)) {
    if (Buffer.byteLength(data) > ARENA_MAX_BYTES) fail('file size');
    data = JSON.parse(String(data));
  }
  jsonTree(data);
  keys(data, ['schemaVersion', 'id', 'name', 'mode', 'geometryHash', 'arena', 'palette', 'art',
    'routes', 'cameras', 'landmarks', 'grayboxHash', 'spawnPoints', 'colliderSources', 'provenance', 'artNotes'], 'envelope');
  const entry = nativeArenaEntry(data.id);
  if (entry.family !== 'identity') fail('not an identity map');
  if (expectedId !== undefined && data.id !== nativeArenaEntry(expectedId).id) fail('ID mismatch');
  if (data.schemaVersion !== 1) fail('schemaVersion');
  text(data.name, 'name');
  hash(data.geometryHash, 'geometryHash');
  if (data.mode !== undefined && !IDENTITY_MODES.includes(data.mode)) fail('mode');
  if (data.grayboxHash !== undefined) hash(data.grayboxHash, 'grayboxHash');
  list(data.palette, 4, 4, 'palette');
  data.palette.forEach(value => color(value, 'palette color'));
  list(data.art, 1, 4096, 'art');
  data.art.forEach(surface => {
    mesh(surface, 'art');
    // Art is presentation-only: it must never claim walkable support.
    if (surface.walkable !== false) fail('art.walkable must be false');
  });
  if (new Set(data.art.map(surface => surface.id)).size !== data.art.length) fail('duplicate art ID');
  if (data.cameras !== undefined) {
    list(data.cameras, 1, 64, 'cameras');
    for (const camera of data.cameras) {
      keys(camera, ['id', 'at', 'target'], 'camera');
      text(camera.id, 'camera.id');
      point(camera.at, 'camera.at'); point(camera.target, 'camera.target');
    }
  }
  if (data.landmarks !== undefined) {
    list(data.landmarks, 0, 64, 'landmarks');
    for (const landmark of data.landmarks) {
      keys(landmark, ['id', 'kind', 'label', 'at', 'scale'], 'landmark');
      text(landmark.kind, 'landmark.kind');
      for (const key of ['id', 'label']) if (landmark[key] !== undefined) text(landmark[key], `landmark.${key}`);
      point(landmark.at, 'landmark.at');
      point(landmark.scale, 'landmark.scale');
      landmark.scale.forEach(value => number(value, .001, 1024, 'landmark.scale'));
    }
  }
  // Per-piece collision notes from the geometry compiler (presentation
  // provenance, never simulation input); bounded text only.
  if (data.artNotes !== undefined) {
    list(data.artNotes, 0, 64, 'artNotes');
    for (const note of data.artNotes) {
      keys(note, ['id', 'collision', 'reason'], 'artNote');
      for (const key of ['id', 'collision', 'reason']) text(note[key], `artNote.${key}`, 512);
    }
  }
  const a = data.arena;
  keys(a, ['id', 'name', 'description', 'tag', 'color', 'background', 'bounds', 'minX', 'maxX', 'minZ', 'maxZ',
    'spawns', 'pickups', 'navNodes', 'blocks', 'terrain', 'voidY', 'ceilingY', 'raised', 'nextGen',
    'teamSpawns', 'objectiveZones', 'hordeCaches'], 'arena fields');
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
  for (const [field, minimum, maximum] of [['spawns', 2, 64], ['navNodes', 0, 4096]]) {
    list(a[field], minimum, maximum, field);
    for (const p of a[field]) { list(p, 2, 2, field); xz(p[0], p[1], field); }
  }
  list(a.pickups, 0, 256, 'pickups');
  for (const p of a.pickups) {
    list(p, 3, 3, 'pickup');
    if (!PICKUP_KINDS.includes(p[0])) fail('pickup kind');
    xz(p[1], p[2], 'pickup position');
  }
  // Nacre's local Horde route gates existing pickup IDs by source wave. Other
  // identity modes may read the same arena, but cannot silently redefine this
  // plan or accept arbitrary fields in the canonical geometry envelope.
  if (a.hordeCaches !== undefined) {
    if (a.id !== 'nacre-engine' || data.mode !== 'horde') fail('hordeCaches map/mode');
    list(a.hordeCaches, 1, 12, 'hordeCaches');
    const seen = new Set();
    let priorWave = 0;
    for (const cache of a.hordeCaches) {
      keys(cache, ['pickupId', 'wave', 'zone'], 'horde cache');
      if (!Number.isSafeInteger(cache.pickupId) || cache.pickupId < 0 || cache.pickupId >= a.pickups.length || seen.has(cache.pickupId)) fail('horde cache pickup ID');
      if (!Number.isSafeInteger(cache.wave) || cache.wave < 1 || cache.wave > 30 || cache.wave < priorWave) fail('horde cache wave');
      text(cache.zone, 'horde cache zone', 48);
      if (!/^[A-Za-z -]{1,48}$/.test(cache.zone)) fail('horde cache zone');
      if (!['scatter', 'plasma', 'shock', 'rocket', 'flak'].includes(a.pickups[cache.pickupId][0])) fail('horde cache pickup kind');
      seen.add(cache.pickupId);
      priorWave = cache.wave;
    }
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
  if (a.nextGen !== undefined && typeof a.nextGen !== 'boolean') fail('nextGen must be boolean');
  keys(a.terrain, ['maxSlope', 'surfaces', 'walls'], 'terrain');
  number(a.terrain.maxSlope, .01, Math.PI / 2, 'maxSlope');
  list(a.terrain.surfaces, 1, 4096, 'surfaces');
  list(a.terrain.walls, 0, 50000, 'walls');
  a.terrain.surfaces.forEach(s => mesh(s, 'surface'));
  a.terrain.walls.forEach(s => {
    if (record(s) && Object.hasOwn(s, 'a')) {
      keys(s, ['a', 'b', 'material'], 'wall segment');
      pointLike(s.a, 'wall.a'); pointLike(s.b, 'wall.b'); text(s.material, 'wall.material');
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
  validateSpawnPoints(data, a, support, false);
  list(data.routes, 0, 256, 'routes');
  for (const route of data.routes) {
    keys(route, ['id', 'points'], 'route'); text(route.id, 'route.id');
    list(route.points, 2, 10000, 'route.points');
    for (const p of route.points) { keys(p, ['x', 'y', 'z'], 'route point'); point([p.x, p.y, p.z], 'route point'); xz(p.x, p.z, 'route point'); }
  }
  if (a.objectiveZones !== undefined) validateIdentityZones(a.objectiveZones, a.bounds, support, a.id, a.voidY);
  if (a.teamSpawns !== undefined) validateIdentityTeamSpawns(a.teamSpawns, a.bounds, support, a.voidY);
  validateColliderSources(data);
  validateProvenance(data);
  if (nativeArenaGeometryHash(a) !== data.geometryHash) fail('geometryHash does not match canonical arena');
  return structuredClone(data);
}

/** Family-dispatching strict parser for a reviewed static arena envelope. */
export function parseArenaEnvelope(data, expectedId) {
  let id = expectedId;
  if (id === undefined && record(data)) id = data.id;
  if (typeof id === 'string' && nativeArenaEntry(id).family === 'identity') return parseIdentityArena(data, expectedId);
  return parseNativeArena(data, expectedId);
}

/** Only reviewed static package-relative files can be opened; no path override. */
export function readNativeArena(mapId) {
  const entry = nativeArenaEntry(mapId);
  const data = readFileSync(new URL(`../../${entry.path}`, import.meta.url));
  return entry.family === 'identity' ? parseIdentityArena(data, mapId) : parseNativeArena(data, mapId);
}

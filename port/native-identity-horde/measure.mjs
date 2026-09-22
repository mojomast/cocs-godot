// Nacre Engine corridor measurement against the capsule the source actually
// moves, not the enemy display scale.
//
// Source facts this module is built on (read-only audit of the locked source):
//   * game/data.mjs RULES = {radius:.42, height:1.8}. Every actor — the local
//     human and every NPC — moves and spawns through the same test
//     `obstructed(x, y, z, RULES.radius, arena)` (game/core.mjs moveActor,
//     Match.spawn, and the nav bake). There is no per-actor collision radius.
//   * `obstructed` is a real capsule test, not a point test: blockObstructed
//     expands every box by r and terrainObstructed requires the actor's full
//     RULES.height to overlap a wall segment before it counts as blocking.
//   * enemy-types.mjs `scale` (.72 husk … 1.32 brute) is written to
//     `actor.npcProfile.scale` and read only by the presentation layer
//     (game/view.mjs applies it to the browser model). No source movement,
//     spawn, ray, damage or navigation path reads it, so the display scale is
//     not an input to clearance and must not be used to compute one.
//   * the nav bake is stricter than the capsule: nodes are rejected when
//     `obstructed(..., .65, ...)` and every accepted edge passes `walkEdge`
//     with a .52 probe radius. A graph-following NPC therefore always has at
//     least 2×.52 = 1.04 m of free width, while its own capsule needs .84 m.
//
// Measurement vocabulary used below:
//   freeRadius(arena,x,z) = largest probe radius r such that the source capsule
//                           test `obstructed(x, floorAt(x,z), z, r, arena)` is
//                           false. freeWidth = 2 × freeRadius.
import {RULES} from '../../game/data.mjs';
import {Match, floorAt, obstructed} from '../../game/core.mjs';
import {pathToFileURL} from 'node:url';
import {writeFileSync} from 'node:fs';
import {createHordeMatch, identityArenaHash, readIdentityMap, validateConfig} from '../native-horde/authority.mjs';

export const IDENTITY_HORDE_MAP = 'nacre-engine';
export const PROBE_LIMIT = 3.0;
export const PROBE_STEP = 0.01;
export const SOURCE_CAPSULE = Object.freeze({
  radius: RULES.radius,
  height: RULES.height,
  neededWidth: RULES.radius * 2,
  source: 'game/data.mjs RULES via game/core.mjs obstructed(); identical for humans and NPCs',
});
// The nav bake's own stricter probe (game/core.mjs walkEdge radius, doubled).
export const NAV_PROBE_WIDTH = 0.52 * 2;
// A guard value only: the transport fails the run if an accepted nav edge is
// narrower than the source capsule. Derived from the capsule, never from scale.
export const CAPSULE_GUARD_WIDTH = SOURCE_CAPSULE.neededWidth;

export function nacreArena() {
  return readIdentityMap(IDENTITY_HORDE_MAP);
}

/** The exact arena and nav graph the authoritative Match plays. `nav`/`edges`
 * come from the same constructor the authority uses, not from a re-implementation. */
export function nacreMatch(fragLimit = 1) {
  const config = validateConfig({mapId: IDENTITY_HORDE_MAP, config: {mode: 'horde', fragLimit}});
  const match = createHordeMatch({mapId: IDENTITY_HORDE_MAP, config, random: () => 0.5});
  if (!(match instanceof Match)) throw Error('Identity hook did not construct a source Match');
  return match;
}

/** Largest free probe radius at one point: bounded bisection to ~1e-7 m, then a
 * confirmation that the boundary is where the measurement says it is. The
 * monotonicity the bisection relies on (a larger capsule can only touch more
 * geometry) is asserted by the confirmation rather than assumed. */
export function freeRadius(arena, x, z, limit = PROBE_LIMIT) {
  const y = floorAt(x, z, arena);
  if (y === null) return {y: null, radius: -1, blocked: true, reason: 'no floor'};
  const free = r => !obstructed(x, y, z, r, arena);
  if (!free(0)) return {y, radius: 0, blocked: true, reason: 'capsule centre blocked'};
  if (free(limit)) return {y, radius: limit, blocked: false, reason: 'above probe limit'};
  let low = 0, high = limit;
  for (let step = 0; step < 24; step++) {
    const middle = (low + high) / 2;
    if (free(middle)) low = middle; else high = middle;
  }
  if (!free(low)) throw Error('Measured clearance is not free at its own radius');
  if (low + PROBE_STEP < limit && free(low + PROBE_STEP)) throw Error('Measured clearance is not the maximum');
  return {y, radius: low, blocked: false, reason: null};
}

/** Free width (m) at a point. Values below `neededWidth` cannot be traversed by
 * the source capsule; values at or above `graphProbeWidth` are past the nav
 * bake's own stricter probe. */
export function freeWidth(arena, x, z) {
  const measured = freeRadius(arena, x, z);
  return {...measured, width: measured.radius < 0 ? 0 : measured.radius * 2};
}

/** Narrowest channel through a point: the smallest sum of the two opposite
 * source-capsule probe rays (0.02 m probe, refined to 1 cm) over four direction
 * pairs. For a point inside a straight corridor this equals the corridor width
 * even when the point is not on the centreline, which is what "how wide is the
 * corridor the NPC actually used" means. Rays stop at `max` per side, so an
 * unbounded open area reports 2×max. */
export const CHANNEL_PROBE = 0.02;
const CHANNEL_DIRECTIONS = [0, Math.PI / 8, Math.PI / 4, 3 * Math.PI / 8];
function rayReach(arena, x, y, z, dx, dz, max) {
  for (let distance = 0.1; distance <= max; distance += 0.1) {
    if (!obstructed(x + dx * distance, y, z + dz * distance, CHANNEL_PROBE, arena)) continue;
    let low = distance - 0.1, high = distance;
    for (let step = 0; step < 6; step++) {
      const middle = (low + high) / 2;
      if (obstructed(x + dx * middle, y, z + dz * middle, CHANNEL_PROBE, arena)) high = middle; else low = middle;
    }
    return high;
  }
  return max;
}
export function channelWidth(arena, x, z, max = PROBE_LIMIT) {
  const y = floorAt(x, z, arena);
  if (y === null) return {y: null, width: 0, capped: false, reason: 'no floor'};
  let width = Infinity, angle = 0;
  for (const direction of CHANNEL_DIRECTIONS) {
    const dx = Math.cos(direction), dz = Math.sin(direction);
    const sum = rayReach(arena, x, y, z, dx, dz, max) + rayReach(arena, x, y, z, -dx, -dz, max);
    if (sum < width) { width = sum; angle = direction; }
  }
  return {y, width, angle, capped: width >= 2 * max - 1e-9, reason: null};
}

export function sampleSegment(arena, from, to, step = 0.25) {
  const span = Math.hypot(to.x - from.x, to.z - from.z);
  const count = Math.max(1, Math.ceil(span / step));
  let worst = null;
  for (let index = 0; index <= count; index++) {
    const t = index / count;
    const x = from.x + (to.x - from.x) * t;
    const z = from.z + (to.z - from.z) * t;
    const measured = freeWidth(arena, x, z);
    const channel = channelWidth(arena, x, z);
    const sample = {...measured, x, z, t, freeWidth: measured.width, width: channel.width, capped: channel.capped};
    if (!worst || sample.width < worst.width) worst = sample;
  }
  return worst;
}

/** Every accepted nav edge, sampled at .25 m with the real capsule. This is the
 * narrowest corridor the source's own graph admits, independent of any run. */
export function navEdgeReport(match, arena, step = 0.25) {
  let worst = null;
  let edges = 0, degenerate = 0;
  for (let from = 0; from < match.nav.length; from++) {
    for (const to of match.edges[from] ?? []) {
      if (to <= from) continue;
      edges++;
      const measured = sampleSegment(arena, match.nav[from], match.nav[to], step);
      if (measured.width < CAPSULE_GUARD_WIDTH) degenerate++;
      if (!worst || measured.width < worst.width) worst = {...measured, from, to};
    }
  }
  return {nodes: match.nav.length, edges, edgesBelowCapsule: degenerate, narrowestEdge: worst};
}

function nearestNode(match, x, z) {
  let best = -1, distance = Infinity;
  match.nav.forEach((node, index) => {
    const d = Math.hypot(node.x - x, node.z - z);
    if (d < distance) { distance = d; best = index; }
  });
  return best;
}

function shortestPath(match, from, to) {
  const previous = new Array(match.nav.length).fill(-1);
  const seen = new Array(match.nav.length).fill(false);
  const queue = [from];
  seen[from] = true;
  for (let head = 0; head < queue.length; head++) {
    const node = queue[head];
    if (node === to) break;
    for (const next of match.edges[node] ?? []) {
      if (seen[next]) continue;
      seen[next] = true;
      previous[next] = node;
      queue.push(next);
    }
  }
  if (!seen[to]) return null;
  const path = [];
  for (let node = to; node !== -1; node = previous[node]) path.push(node);
  return path.reverse();
}

/** Approach widths: the real graph route from each authored spawn to the arena
 * centre (where a defending player holds), sampled with the real capsule. */
export function approachReport(match, arena, target = null) {
  const center = target ?? match.center;
  const goals = nearestNode(match, center.x, center.z);
  const approaches = [];
  for (const spawn of match.spawns) {
    const start = nearestNode(match, spawn.x, spawn.z);
    const path = start < 0 || goals < 0 ? null : shortestPath(match, start, goals);
    if (!path) { approaches.push({spawn: [spawn.x, spawn.z], reachable: false}); continue; }
    let worst = null, length = 0;
    for (let index = 1; index < path.length; index++) {
      const a = match.nav[path[index - 1]], b = match.nav[path[index]];
      length += Math.hypot(b.x - a.x, b.z - a.z);
      const measured = sampleSegment(arena, a, b);
      if (!worst || measured.width < worst.width) worst = measured;
    }
    approaches.push({spawn: [spawn.x, spawn.z], reachable: true, hops: path.length - 1,
      pathLength: length, minWidth: worst.width, minClearanceWidth: worst.freeWidth, at: {x: worst.x, z: worst.z}});
  }
  return {center: {x: center.x, z: center.z}, approaches};
}

/** Traversal measurement from a real run: the minimum capsule clearance any
 * living NPC held while moving (free radius: geometry contact reads as 0.42),
 * plus the narrowest channel width the NPCs actually moved through. Positions
 * are accepted state, never client guesses; the sampling rate is the snapshot
 * rate, so the channel figure is an upper bound on the narrowest corridor the
 * run could have used. */
export function traversalReport(arena, samples) {
  const perNpc = new Map();
  const perWave = new Map();
  let worst = null, tightestChannel = null, contacts = 0, measured = 0;
  for (const sample of samples) {
    for (const actor of sample.actors ?? []) {
      if (actor.isNpc !== true || actor.health <= 0) continue;
      const clearance = freeWidth(arena, actor.x, actor.z);
      const channel = channelWidth(arena, actor.x, actor.z);
      measured++;
      if (clearance.radius <= SOURCE_CAPSULE.radius + 1e-3) contacts++;
      const point = {clearance: clearance.radius, clearanceWidth: clearance.width,
        channelWidth: channel.width, capped: channel.capped, npc: actor.id, npcType: actor.npcType,
        wave: sample.wave, x: actor.x, z: actor.z};
      const key = actor.id;
      const current = perNpc.get(key);
      if (!current || point.channelWidth < current.channelWidth) perNpc.set(key, point);
      const wave = perWave.get(sample.wave);
      if (!wave || point.channelWidth < wave.channelWidth) perWave.set(sample.wave, point);
      if (!worst || point.clearanceWidth < worst.clearanceWidth) worst = {...point, freeWidth: point.clearanceWidth};
      if (!tightestChannel || point.channelWidth < tightestChannel.channelWidth) tightestChannel = point;
    }
  }
  return {npcCount: perNpc.size, samples: measured, contacts, minimumTraversed: worst, tightestChannel,
    perNpc: [...perNpc.values()].sort((a, b) => a.channelWidth - b.channelWidth),
    perWave: [...perWave.entries()].map(([wave, value]) => ({wave, ...value})).sort((a, b) => a.wave - b.wave)};
}

/** Coarse whole-footprint clearance scan: at each grid point the width of the
 * largest free disc centred there (nearest-obstacle distance × 2). This is a
 * conservative lower bound on the local corridor width, because an off-centre
 * point reports less than the corridor. It includes pockets the nav graph
 * cannot reach (for example space between two separate decorative feet), so it
 * is reported as a distribution, never as "the corridor". */
export function footprintScan(arena, step = 1.0) {
  const bounds = arena.bounds;
  const samples = [];
  let belowCapsule = 0, belowNavProbe = 0, free = 0, blocked = 0, touching = 0;
  for (let x = bounds.minX + step / 2; x <= bounds.maxX; x += step) {
    for (let z = bounds.minZ + step / 2; z <= bounds.maxZ; z += step) {
      const measured = freeWidth(arena, x, z);
      if (measured.y === null || measured.reason === 'capsule centre blocked') { blocked++; continue; }
      free++;
      // A grid sample that lands on a wall face has ~0 clearance by
      // construction; it is a geometry boundary, not a corridor.
      if (measured.radius <= PROBE_STEP) { touching++; continue; }
      if (measured.width < SOURCE_CAPSULE.neededWidth) belowCapsule++;
      if (measured.width < NAV_PROBE_WIDTH) belowNavProbe++;
      samples.push({x, z, width: measured.width});
    }
  }
  samples.sort((a, b) => a.width - b.width);
  return {grid: step, free, blocked, touching, belowCapsule, belowNavProbe,
    narrowest: samples.slice(0, 8), widest: samples.slice(-3).reverse()};
}

/** Verdict helper: does a measured width clear the real capsule, with the nav
 * bake's stricter probe as the second bar? */
export function verdictFor(width) {
  if (typeof width !== 'number' || !Number.isFinite(width)) return 'unknown';
  if (width < SOURCE_CAPSULE.neededWidth) return 'blocked-for-source-capsule';
  if (width <= NAV_PROBE_WIDTH + 1e-9) return 'passes-capsule-only';
  return 'passes-nav-probe';
}

export function measureNacre({fragLimit = 1} = {}) {
  const arena = nacreArena();
  const match = nacreMatch(fragLimit);
  const nav = navEdgeReport(match, arena);
  const approaches = approachReport(match, arena);
  const reachable = approaches.approaches.filter(entry => entry.reachable);
  const narrowestApproach = reachable.length ? reachable.reduce((a, b) => (a.minWidth <= b.minWidth ? a : b)) : null;
  return {
    mapId: IDENTITY_HORDE_MAP,
    geometryHash: identityArenaHash(arena),
    capsule: SOURCE_CAPSULE,
    navProbeWidth: NAV_PROBE_WIDTH,
    nav: {nodes: nav.nodes, edges: nav.edges, edgesBelowCapsule: nav.edgesBelowCapsule,
      narrowestEdgeWidth: nav.narrowestEdge?.width ?? null, at: nav.narrowestEdge ? {x: nav.narrowestEdge.x, z: nav.narrowestEdge.z} : null,
      verdict: verdictFor(nav.narrowestEdge?.width)},
    spawnClearance: match.spawns.map(spawn => ({spawn: [spawn.x, spawn.z], width: freeWidth(arena, spawn.x, spawn.z).width})),
    approaches,
    narrowestApproach: narrowestApproach ? {spawn: narrowestApproach.spawn, minWidth: narrowestApproach.minWidth, at: narrowestApproach.at} : null,
    footprintScan: footprintScan(arena),
    displayScaleNote: 'enemy npcProfile.scale is presentation-only; every measurement above uses RULES.radius',
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const report = measureNacre();
  const out = process.argv[2];
  if (out) writeFileSync(out, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify({mapId: report.mapId, capsule: report.capsule.neededWidth,
    nav: report.nav, narrowestApproach: report.narrowestApproach,
    footprint: {...report.footprintScan, narrowest: report.footprintScan.narrowest.slice(0, 3)}}, null, 2));
}

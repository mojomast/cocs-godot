// Stormglass Causeway — deterministic grade-plan analysis.
//
// SOURCE-ONLY. This module builds the *proposed* graded world in memory only.
// It never writes a runtime world JSON, a receipt, a probe file or an artifact,
// and it never invokes the engine, Blender or the network. It exists so the
// numbers quoted in `port/finish/map-variety/STORMGLASS_GRADE_PLAN_20261005.md`
// can be re-derived by anyone from committed source.
//
// What it deliberately reuses rather than re-implements:
//   * `game/terrain.mjs terrainSupportAt` — the real authority support query.
//   * `game/vehicles.mjs createVehicle/PUMA/stepVehicle` — the real vehicle step,
//     so grip, slope, suspension and grounded come from production constants.
//   * `game/core.mjs obstructed` — the real static-contact predicate.
//   * `game/race.mjs crossRaceGates` — the real gate rule, so the proposed
//     per-gate window is validated against the code that would consume it.

import {makeStormglass} from '../recipe.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';
import {obstructed} from '../../../../../game/core.mjs';
import {createVehicle, PUMA, respawnVehicle, stepVehicle} from '../../../../../game/vehicles.mjs';
import {crossRaceGates} from '../../../../../game/race.mjs';
import {LIMITS, KNOT_HEIGHTS, GRADE_VERSION, PROFILE_ID,
  knotHeight, roadHeight, sectorGrade, gradeLedger, gateWindow, insideGateWindow,
  relief, localRelief, breakAmplitude, suspensionLag} from './grade-profile.mjs';

/** The accepted Stormglass recipe, rebuilt in memory. Never written. */
export function acceptedArena() {
  return makeStormglass();
}

const clone = value => JSON.parse(JSON.stringify(value));

/** Closest point on the closed centerline, as {sector, t, distance, arc}. */
export function project(centerline, x, z) {
  const n = centerline.length;
  let best = {sector: 0, t: 0, distance: Infinity, arc: 0};
  let arc = 0;
  for (let i = 0; i < n; i++) {
    const a = centerline[i], b = centerline[(i + 1) % n];
    const dx = b.x - a.x, dz = b.z - a.z, span = dx * dx + dz * dz;
    const t = span > 1e-9 ? Math.max(0, Math.min(1, ((x - a.x) * dx + (z - a.z) * dz) / span)) : 0;
    const d = Math.hypot(x - a.x - dx * t, z - a.z - dz * t);
    if (d < best.distance) best = {sector: i, t, distance: d, arc: arc + Math.hypot(dx, dz) * t};
    arc += Math.hypot(dx, dz);
  }
  return best;
}

/** Local road height at any XZ, from the authored profile alone. */
export function profileHeightAt(arena, x, z, heights = KNOT_HEIGHTS) {
  const at = project(arena.race.centerline, x, z);
  return roadHeight(at.sector, at.t, heights);
}

/**
 * Cosmetic geometry that must NOT ride the profile: the bounded ocean is a
 * single flat quad authored at Y=-4 (`recipe.mjs:100`, collision `none`, so it
 * lives in `art.meshes` and never in `terrain.surfaces`) and is deliberately
 * independent of the road. Listed explicitly so a future revision that does
 * move cosmetic meshes cannot pick it up by accident.
 */
export const PROFILE_EXEMPT = Object.freeze(new Set(['ocean']));

/**
 * Rebase every road-anchored authority vertex onto the profile. This is the
 * single transformation a real recipe revision would need: add the local road
 * height to every authored Y. Vertices that are already relative to the road
 * (barriers 0..2.8, vault 7..16, gantries 22..24, labels 4, shoulders 0.015)
 * keep their exact accepted offsets.
 */
export function rebaseVertex(centerline, vertex, heights = KNOT_HEIGHTS) {
  const at = project(centerline, vertex[0], vertex[2]);
  return [vertex[0], vertex[1] + roadHeight(at.sector, at.t, heights), vertex[2]];
}

export function rebaseTerrain(terrain, centerline, heights = KNOT_HEIGHTS) {
  const lift = v => PROFILE_EXEMPT.has(v.id) ? v.vertices
    : v.vertices.map(p => rebaseVertex(centerline, p, heights));
  return {
    ...terrain,
    surfaces: terrain.surfaces.map(s => ({...s, vertices: lift(s)})),
    walls: terrain.walls.map(w => ({...w, vertices: lift(w)}))
  };
}

/** The proposed graded world, in memory. */
export function gradedArena(heights = KNOT_HEIGHTS) {
  const base = acceptedArena();
  const centerline = base.race.centerline;
  const arena = clone(base);
  arena.terrain = rebaseTerrain(base.terrain, centerline, heights);
  arena.metrics = {...base.metrics, roadRelief: Math.max(...heights) - Math.min(...heights)};
  arena.race = {...base.race, gradeProfile: PROFILE_ID, gradeVersion: GRADE_VERSION};
  return arena;
}

/** The proposed world with barriers deliberately left on the old datum. */
export function arenaWithoutBarrierRebase(heights = KNOT_HEIGHTS) {
  const base = acceptedArena();
  const centerline = base.race.centerline;
  const arena = clone(base);
  arena.terrain = {
    ...base.terrain,
    surfaces: base.terrain.surfaces.map(s => (PROFILE_EXEMPT.has(s.id) ? s
      : {...s, vertices: s.vertices.map(p => rebaseVertex(centerline, p, heights))})),
    walls: base.terrain.walls.filter(w => !w.id.startsWith('barrier-'))
  };
  return arena;
}

/** `stepVehicle`'s ground contract, fed by the real authority support query. */
export function authoritySampler(arena) {
  const maxSlope = arena.terrain?.maxSlope;
  return (x, z) => {
    const y = terrainSupportAt(x, z, arena.terrain, maxSlope)?.y;
    if (y === undefined || y === null) return null;
    if (!arena.terrain) return y;
    const e = 0.6;
    const yx = terrainSupportAt(x + e, z, arena.terrain, maxSlope)?.y;
    const yz = terrainSupportAt(x, z + e, arena.terrain, maxSlope)?.y;
    if (yx === undefined || yz === undefined || yx === null || yz === null) return y;
    return {y, normal: normalize({x: -(yx - y) / e, y: 1, z: -(yz - y) / e})};
  };
}

function normalize(v) {
  const length = Math.hypot(v.x, v.y, v.z) || 1;
  return {x: v.x / length, y: v.y / length, z: v.z / length};
}

/**
 * Support heights along a deterministic sample route: every centerline node,
 * 20 interior points per sector, and every authored grid slot. Returns the
 * authority support height next to the authored profile height.
 */
export function supportProfile(arena, heights = KNOT_HEIGHTS, perSector = 20) {
  const centerline = arena.race.centerline, maxSlope = arena.terrain.maxSlope;
  const rows = [];
  const sample = (x, z, label) => {
    const authored = profileHeightAt(arena, x, z, heights);
    const support = terrainSupportAt(x, z, arena.terrain, maxSlope);
    rows.push({
      label, x, z,
      authored,
      support: support ? support.y : null,
      delta: support ? support.y - authored : null,
      normalY: support ? support.normal[1] : null
    });
  };
  const n = centerline.length;
  for (let i = 0; i < n; i++) {
    sample(centerline[i].x, centerline[i].z, `node-${i}`);
    const j = (i + 1) % n;
    for (let k = 1; k <= perSector; k++) {
      const t = k / (perSector + 1);
      sample(centerline[i].x + (centerline[j].x - centerline[i].x) * t,
        centerline[i].z + (centerline[j].z - centerline[i].z) * t, `sector-${i}-${k}`);
    }
  }
  arena.race.grid.forEach((g, i) => sample(g.x, g.z, `grid-${i}`));
  return rows;
}

/** Aggregate of supportProfile: worst deviation and worst normal tilt. */
export function supportSummary(rows) {
  let maxAbsDelta = 0, worst = null, minNormalY = 1, worstNormal = null;
  for (const row of rows) {
    if (row.delta === null) continue;
    if (Math.abs(row.delta) > maxAbsDelta) { maxAbsDelta = Math.abs(row.delta); worst = row; }
    if (row.normalY < minNormalY) { minNormalY = row.normalY; worstNormal = row; }
  }
  return {samples: rows.length, maxAbsDelta, worst, minNormalY, worstNormal};
}

/**
 * Subdivision study. The accepted road strip is one quad per sector, and its
 * two long mitred edges have *different* lengths (sector 20: 72.3 m outer vs
 * 22.5 m inner), so a longitudinally graded quad is not planar. This measures
 * the support ridge and normal tilt that the two triangles of each sub-quad
 * actually produce, for a given number of sub-quads per sector.
 */
export function subdivisionStudy(heights = KNOT_HEIGHTS, subdivisions = [1, 2, 4, 8, 16, 32]) {
  const base = acceptedArena(), centerline = base.race.centerline;
  const {outer, inner} = base.race.boundary;
  const n = centerline.length;
  return subdivisions.map(k => {
    const surfaces = [];
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      const y0 = knotHeight(i, heights), y1 = knotHeight(j, heights);
      const lerp = (a, b, t) => [a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t];
      for (let s = 0; s < k; s++) {
        const ta = s / k, tb = (s + 1) / k;
        const oa = lerp(outer[i], outer[j], ta), ob = lerp(outer[i], outer[j], tb);
        const ia = lerp(inner[i], inner[j], ta), ib = lerp(inner[i], inner[j], tb);
        const ya = y0 + (y1 - y0) * ta, yb = y0 + (y1 - y0) * tb;
        surfaces.push({id: `road-${i}-${s}`, walkable: true, material: 'asphalt',
          vertices: [[oa[0], ya, oa[1]], [ia[0], ya, ia[1]], [ib[0], yb, ib[1]], [ob[0], yb, ob[1]]],
          triangles: [[0, 1, 2], [0, 2, 3]]});
      }
    }
    const terrain = {maxSlope: base.terrain.maxSlope, base: base.terrain.base,
      amplitude: base.terrain.amplitude, surfaces, walls: []};
    // Per-sector worst support error along the centerline, so the recipe can
    // subdivide where the mitred strip actually needs it.
    const perSector = [];
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      let worst = 0;
      for (let q = 1; q < 40; q++) {
        const t = q / 40;
        const x = centerline[i].x + (centerline[j].x - centerline[i].x) * t;
        const z = centerline[i].z + (centerline[j].z - centerline[i].z) * t;
        const support = terrainSupportAt(x, z, terrain, terrain.maxSlope);
        if (support) worst = Math.max(worst, Math.abs(support.y - roadHeight(i, t, heights)));
      }
      perSector.push(worst);
    }
    const rows = supportProfile({...base, terrain}, heights, 20);
    const summary = supportSummary(rows);
    return {
      subdivisions: k,
      surfaces: surfaces.length,
      triangles: surfaces.length * 2,
      maxAbsDelta: summary.maxAbsDelta,
      perSectorWorst: Math.max(...perSector),
      minNormalY: summary.minNormalY,
      worst: summary.worst && summary.worst.label,
      sectorsOverTwoCentimetres: perSector.map((v, i) => (v > 0.02 ? i : -1)).filter(v => v >= 0)
    };
  });
}

/**
 * Longitudinal grade sensitivity, measured with the real `stepVehicle`.
 *
 * Note the modelling fact this proves rather than assumes: `stepVehicle`
 * derives thrust from throttle alone and subtracts only quadratic drag, so a
 * grade does **not** reduce straight-line speed in the current source model.
 * Grade changes exactly three things: the grip multiplier
 * (`slopeGrip = clamp(normal.y, 0.4, 1)`), the cosmetic body pitch/roll, and
 * the vertical suspension follower.
 */
export function physicsSensitivity(arena, heights = KNOT_HEIGHTS) {
  const ground = authoritySampler(arena);
  const centerline = arena.race.centerline, n = centerline.length;
  const dt = LIMITS.physicsStep;
  const rows = [];
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    const start = centerline[i];
    const end = centerline[j];
    const heading = Math.atan2(end.x - start.x, end.z - start.z);
    const grade = sectorGrade(i, centerline, heights);
    const vehicle = createVehicle(PUMA);
    respawnVehicle(vehicle, {x: start.x, y: knotHeight(i, heights), z: start.z}, heading);
    vehicle.speed = PUMA.speed;
    vehicle.velocity = {x: Math.sin(heading) * PUMA.speed, z: Math.cos(heading) * PUMA.speed};
    let maxLag = 0, minGrounded = true, minNormalY = 1, steps = 0;
    const length = Math.hypot(end.x - start.x, end.z - start.z);
    while (steps * dt * PUMA.speed < length && steps < 4000) {
      const before = vehicle.position.y;
      stepVehicle(vehicle, {throttle: 1, steer: 0}, dt, next => next, ground);
      const support = ground(vehicle.position.x, vehicle.position.z);
      const road = typeof support === 'number' ? support : support.y;
      if (Number.isFinite(road)) maxLag = Math.max(maxLag, Math.abs(before - road));
      if (vehicle.grounded === false) minGrounded = false;
      const normal = support && typeof support === 'object' ? support.normal : null;
      if (normal) minNormalY = Math.min(minNormalY, normal.y);
      steps++;
    }
    rows.push({
      sector: i, grade, gradeDeg: Math.atan(grade) * 180 / Math.PI,
      speed: vehicle.speed, steps,
      maxVerticalLag: maxLag, stayedGrounded: minGrounded,
      minNormalY, grip: PUMA.grip * Math.max(0.4, Math.min(1, minNormalY)),
      pitch: vehicle.pitchBody
    });
  }
  const flat = rows.find(r => r.grade === 0);
  const steepest = rows.reduce((a, b) => (Math.abs(b.grade) > Math.abs(a.grade) ? b : a));
  return {
    rows, flat, steepest,
    topSpeedFlat: flat ? flat.speed : null,
    topSpeedSteepest: steepest.speed,
    speedDelta: flat && steepest ? steepest.speed - flat.speed : null,
    gripFlat: flat ? flat.grip : null,
    gripSteepest: steepest.grip,
    maxVerticalLag: rows.reduce((m, r) => Math.max(m, r.maxVerticalLag), 0),
    anyUngrounded: rows.some(r => !r.stayedGrounded)
  };
}

/**
 * Does the *existing* `crossRaceGates` rule accept a graded crossing?
 * This is the decisive compatibility measurement: with the current hardcoded
 * `-0.25 <= y <= 3` window, every gate above 3.0 m is unreachable.
 */
export function gateAdmission(centerline, heights = KNOT_HEIGHTS) {
  const gates = centerline.map((p, i) => ({...p, nx: 1, nz: 0, halfWidth: 13.9}));
  const rows = [];
  for (let i = 0; i < gates.length; i++) {
    const gate = gates[i];
    const y = knotHeight(i, heights);
    const state = {gates, racers: [], coins: [], boxes: [], hazards: [], boostPads: [],
      phase: 'racing', laps: 3, elapsed: 0, serial: 0, boxes: [], coins: []};
    const racer = {actorId: 0, nextGate: i, passed: 0, started: false, progress: 0,
      completedLaps: 0, checkpointAge: 0, anchor: {x: gate.x, z: gate.z, heading: 0}};
    state.racers.push(racer);
    const from = {x: gate.x - gate.nx * 0.5, y, z: gate.z - gate.nz * 0.5};
    const to = {x: gate.x + gate.nx * 0.5, y, z: gate.z + gate.nz * 0.5};
    crossRaceGates(state, racer, from, to, 0, 1);
    const window = gateWindow(i, heights);
    // Two independent measurements of the same crossing: the shipped
    // `crossRaceGates` rule (which hardcodes -0.25..3) and the proposed
    // per-gate predicate evaluated directly.
    const acceptedByCurrentRule = racer.passed > 0;
    const acceptedByAuthoredWindow = insideGateWindow(window, y);
    rows.push({gate: i, roadY: y, window, acceptedByCurrentRule, acceptedByAuthoredWindow});
  }
  return rows;
}

/**
 * Lateral containment. With the barriers rebased, a Puma-sized probe beyond
 * the road edge must still be blocked at the new road height. With the barriers
 * left on the old datum the same probe is free, which is the concrete reason a
 * partial change is not shippable.
 */
export function containment(arena, rebaseBarriers = true, heights = KNOT_HEIGHTS) {
  const subject = rebaseBarriers ? arena : arenaWithoutBarrierRebase(heights);
  const centerline = subject.race.centerline, boundary = subject.race.boundary;
  const radius = 2.08387;
  let freeProbes = 0, blocked = 0;
  const samples = [];
  for (let i = 0; i < centerline.length; i++) {
    const p = centerline[i];
    const o = boundary.outer[i], q = boundary.inner[i];
    const dx = q.x - o.x, dz = q.z - o.z, len = Math.hypot(dx, dz) || 1;
    // The barrier is the mitred edge, so a probe has to be measured from the
    // actual barrier distance at this gate, not from the nominal 14 m.
    const barrier = Math.hypot(o.x - p.x, o.z - p.z);
    const outward = {x: (o.x - q.x) / len, z: (o.z - q.z) / len};
    const y = profileHeightAt(subject, p.x, p.z, heights);
    // Probes stay inside the 2.08387 m Puma radius of the barrier: a chassis
    // centre within one radius of the wall must be reported as a contact.
    for (const beyond of [0.1, 0.8, 1.6]) {
      const reach = barrier + beyond;
      const x = p.x + outward.x * reach, z = p.z + outward.z * reach;
      const hit = obstructed(x, y, z, radius, subject);
      if (hit) blocked++; else freeProbes++;
      samples.push({sector: i, beyond, barrier, y, blocked: hit});
    }
  }
  const total = samples.length;
  return {rebaseBarriers, total, blocked, freeProbes, samples};
}

/**
 * Camera-rig audit. `game/race-camera.mjs` mixes relative heights (chase uses
 * focus.y + 5) with absolute world heights (trackside 3.4, cinematic 2.6,
 * flyover 12 + 1.4 sin). Only the relative rigs survive an elevated road.
 */
export function cameraRigs(centerline, heights = KNOT_HEIGHTS) {
  const crest = knotHeight(heights.indexOf(Math.max(...heights)), heights);
  const n = centerline.length;
  let maxNodeY = -Infinity;
  centerline.forEach((_, i) => { maxNodeY = Math.max(maxNodeY, knotHeight(i, heights)); });
  return {
    crest,
    chase: {formula: 'focus.y + 5', relative: true, safeAboveRoad: true},
    orbit: {formula: 'focus.y + 4.2', relative: true, safeAboveRoad: true},
    trackside: {formula: '3.4 (absolute)', relative: false,
      safeAboveRoad: crest <= 3.4, clearanceAtCrest: 3.4 - crest},
    cinematic: {formula: '2.6 (absolute)', relative: false,
      safeAboveRoad: crest <= 2.6, clearanceAtCrest: 2.6 - crest},
    flyover: {formula: '12 + 1.4*sin(t) (absolute)', relative: false,
      safeAboveRoad: crest <= 10.6, clearanceAtCrest: 10.6 - crest},
    maxNodeY, nodes: n
  };
}

/**
 * Vertical envelope: the worst thing the suspension and the four-corner sampler
 * have to absorb, all derived from the source constants rather than asserted.
 */
export function verticalEnvelope(centerline, heights = KNOT_HEIGHTS) {
  const ledger = gradeLedger(centerline, acceptedArena().race.boundary, heights);
  let maxBreak = 0, breakSector = -1;
  for (let i = 0; i < ledger.length; i++) {
    const prev = (i - 1 + ledger.length) % ledger.length;
    const d = Math.abs(ledger[i].centerGrade - ledger[prev].centerGrade);
    if (d > maxBreak) { maxBreak = d; breakSector = i; }
  }
  const steepest = ledger.reduce((a, b) =>
    Math.max(Math.abs(b.centerGrade), Math.abs(b.outerGrade), Math.abs(b.innerGrade)) >
    Math.max(Math.abs(a.centerGrade), Math.abs(a.outerGrade), Math.abs(a.innerGrade)) ? b : a);
  const lag = suspensionLag(PUMA.speed, steepest.centerGrade,
    {suspensionRate: PUMA.suspensionRate, dt: LIMITS.physicsStep});
  const amplitude = breakAmplitude(maxBreak, PUMA.dimensions.length);
  return {
    maxBreak, breakSector, breakAmplitude: amplitude,
    sustainedLag: lag,
    worstVerticalError: amplitude + lag,
    groundedTolerance: LIMITS.groundedTolerance,
    headroom: LIMITS.groundedTolerance - (amplitude + lag),
    maxGradeDeg: Math.atan(Math.max(Math.abs(steepest.centerGrade), Math.abs(steepest.outerGrade),
      Math.abs(steepest.innerGrade))) * 180 / Math.PI,
    pitchMaxDeg: PUMA.pitchMax * 180 / Math.PI,
    rollMaxDeg: PUMA.rollMax * 180 / Math.PI
  };
}

/** Everything the plan document quotes, in one deterministic object. */
export function gradePlan(heights = KNOT_HEIGHTS) {
  const base = acceptedArena();
  const centerline = base.race.centerline, boundary = base.race.boundary;
  const arena = gradedArena(heights);
  const ledger = gradeLedger(centerline, boundary, heights);
  const steepest = ledger.reduce((a, b) => {
    const worst = Math.max(Math.abs(b.centerGrade), Math.abs(b.outerGrade), Math.abs(b.innerGrade));
    return worst > a.worst ? {worst, sector: b.sector} : a;
  }, {worst: 0, sector: -1});
  const support = supportSummary(supportProfile(arena, heights));
  const physics = physicsSensitivity(arena, heights);
  const admission = gateAdmission(centerline, heights);
  const contained = containment(arena, true, heights);
  const uncontained = containment(arena, false, heights);
  let maxBreak = 0;
  for (let i = 0; i < ledger.length; i++) {
    const prev = (i - 1 + ledger.length) % ledger.length;
    maxBreak = Math.max(maxBreak, Math.abs(Math.abs(ledger[i].centerGrade) - Math.abs(ledger[prev].centerGrade)));
  }
  return {
    profile: {id: PROFILE_ID, version: GRADE_VERSION, knots: [...heights], limits: LIMITS},
    footprint: {
      centerline: centerline.length,
      roadWidth: base.metrics.roadWidth,
      barriers: base.terrain.walls.filter(w => w.id.startsWith('barrier-')).length,
      surfaces: base.terrain.surfaces.length,
      spawns: base.spawns.length,
      navNodes: base.navNodes.length,
      modes: [...base.candidateModes]
    },
    relief: {...relief(heights), local: localRelief(heights)},
    grades: {
      steepest: steepest.worst, steepestSector: steepest.sector,
      cap: LIMITS.maxGrade, headroom: LIMITS.maxGrade - steepest.worst,
      maxCentreline: ledger.reduce((m, r) => Math.max(m, Math.abs(r.centerGrade)), 0),
      maxOuterEdge: ledger.reduce((m, r) => Math.max(m, Math.abs(r.outerGrade)), 0),
      maxInnerEdge: ledger.reduce((m, r) => Math.max(m, Math.abs(r.innerGrade)), 0),
      maxBreak, ledger
    },
    envelope: verticalEnvelope(centerline, heights),
    support,
    subdivisions: subdivisionStudy(heights),
    physics,
    gates: {
      admittedByCurrentRule: admission.filter(r => r.acceptedByCurrentRule).length,
      admittedByAuthoredWindow: admission.filter(r => r.acceptedByAuthoredWindow).length,
      total: admission.length,
      unreachable: admission.filter(r => !r.acceptedByCurrentRule).map(r => r.gate),
      rows: admission
    },
    containment: {
      acceptedFlatBaseline: containment(base, true, new Array(base.race.centerline.length).fill(0)),
      rebased: contained,
      unrebased: uncontained
    },
    camera: cameraRigs(centerline, heights)
  };
}
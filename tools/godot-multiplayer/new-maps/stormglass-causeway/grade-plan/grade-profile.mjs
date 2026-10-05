// Stormglass Causeway — proposed longitudinal road profile, revision 3 ("grade-v1").
//
// SOURCE-ONLY PROPOSAL. Nothing here is wired into the accepted recipe, the
// runtime world JSON, the Blender master or any receipt. This module only
// *describes* the elevation profile a future grant would author, so that the
// grade arithmetic in STORMGLASS_GRADE_PLAN_20261005.md is reproducible and
// testable without touching runtime data.
//
// Design rules this profile deliberately obeys:
//   * XZ footprint is untouched. Every road quad, barrier, structure, label and
//     gate keeps its accepted plan position; only Y is added. That is what makes
//     the change reviewable as "relief", not as a new map.
//   * Longitudinal grade only. Camber/cross-slope is exactly 0, so the four
//     wheel samples in `game/vehicles.mjs stepVehicle` never see a lateral tilt
//     and `groundRoll` stays 0.
//   * The elevation is piecewise linear in the sector parameter `t`, so each
//     sub-quad corner set is authored rather than solved.
//   * Sectors 0-6 (start/finish straight, weather terminal and the arched
//     freight bore) and sector 20 (grid) stay at the 0.0 datum, which keeps the
//     bore vault, the surge-gate structures and the whole starting grid at their
//     accepted heights.

/** Versioned identity for the proposed profile. Bump when heights change. */
export const GRADE_VERSION = 1;
export const PROFILE_ID = 'stormglass-causeway/grade-v1';

/** Hard caps. The 0.08 grade cap is the blueprint's ~8% target; the rest are
 *  derived limits, justified in the plan document. */
export const LIMITS = Object.freeze({
  maxGrade: 0.08,          // per-edge |dy| / edge length, over ALL three edges
  maxCamberDeg: 0,         // longitudinal only in revision 1
  maxRelief: 8,            // metres, crest above the 0.0 datum
  maxLocalRelief: 3,       // metres between adjacent sector knots
  crestTransitionLength: 25, // metres; minimum run for any grade change
  minGridDatum: 0,         // the starting grid must not move off the datum
  gateWindowBelow: 0.25,   // metres below the local road Y (existing race.mjs rule)
  gateWindowAbove: 3,      // metres above the local road Y (existing race.mjs rule)
  suspensionRate: 12,      // vehicles.mjs PUMA.suspensionRate
  groundedTolerance: 0.4,  // vehicles.mjs: grounded = position.y - groundY <= 0.4
  physicsStep: 1 / 60      // race.mjs fixed slice
});

/**
 * Authored knot heights, one per centerline node, in metres above the 0.0
 * datum. Index i is the *start* of sector i; sector 20 closes back onto node 0.
 */
export const KNOT_HEIGHTS = Object.freeze([
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,   // 0-6  datum: start straight + freight bore
  1.8,                                     // 7   quay approach
  4.8,                                     // 8   steepest authored climb
  6.2,                                     // 9
  6.8,                                     // 10  crest
  6.8,                                     // 11  crest plateau
  6.4, 5.8, 5.0, 4.2, 3.4, 2.6, 1.8, 0.9, // 12-19 stepped-quay descent
  0.0                                      // 20  datum: starting grid
]);

/** Knot height of centerline node `i` (wraps). */
export function knotHeight(i, heights = KNOT_HEIGHTS) {
  const n = heights.length;
  return heights[((i % n) + n) % n];
}

/** Road surface height inside sector `i` at parameter `t` in [0,1]. */
export function roadHeight(i, t, heights = KNOT_HEIGHTS) {
  const clamped = Number.isFinite(t) ? Math.max(0, Math.min(1, t)) : 0;
  return knotHeight(i, heights) * (1 - clamped) + knotHeight(i + 1, heights) * clamped;
}

/** Signed grade (dy/ds) of sector `i`, using the accepted centerline length. */
export function sectorGrade(i, centerline, heights = KNOT_HEIGHTS) {
  const n = centerline.length, j = (i + 1) % n;
  const length = Math.hypot(centerline[j].x - centerline[i].x, centerline[j].z - centerline[i].z);
  return length > 1e-9 ? (knotHeight(j, heights) - knotHeight(i, heights)) / length : 0;
}

/**
 * Full per-sector grade ledger. Reports the centerline grade *and* the grade on
 * both mitred road edges, because the stormglass road strip is a trapezoid
 * (its two long edges have different lengths), so the steepest driven line is
 * an edge and not the centerline.
 */
export function gradeLedger(centerline, boundary, heights = KNOT_HEIGHTS) {
  const n = centerline.length;
  const rows = [];
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    const delta = knotHeight(j, heights) - knotHeight(i, heights);
    const center = Math.hypot(centerline[j].x - centerline[i].x, centerline[j].z - centerline[i].z);
    const outer = Math.hypot(boundary.outer[j].x - boundary.outer[i].x, boundary.outer[j].z - boundary.outer[i].z);
    const inner = Math.hypot(boundary.inner[j].x - boundary.inner[i].x, boundary.inner[j].z - boundary.inner[i].z);
    rows.push({
      sector: i, delta,
      centerLength: center, outerLength: outer, innerLength: inner,
      centerGrade: delta / center,
      outerGrade: delta / Math.max(outer, 1e-9),
      innerGrade: delta / Math.max(inner, 1e-9)
    });
  }
  return rows;
}

/** Relief summary over the knot table alone. */
export function relief(heights = KNOT_HEIGHTS) {
  const crest = Math.max(...heights), datum = Math.min(...heights);
  return {crest, datum, span: crest - datum, crestNode: heights.indexOf(crest)};
}

/**
 * Corner-crest break amplitude. `stepVehicle` averages four wheel samples at
 * `+/-wheelBase/2`, so at a grade break the sampled support sits below the road
 * by `0.5 * wheelBase * |dGrade|` — this is the vertical step the suspension
 * has to absorb, and it is why a grade break cannot be arbitrarily sharp.
 */
export function breakAmplitude(gradeBreak, wheelBase = 3.6) {
  return 0.5 * wheelBase * Math.abs(gradeBreak);
}

/**
 * Suspension-follower lag for a car held at `speed` on a constant `grade`.
 * `stepVehicle` moves `position.y` a fixed fraction `suspensionRate*dt` of the
 * way to the sampled support every step, so on a uniform ramp the residual is
 * `(1 - k) * v * grade / (suspensionRate * v_vertical)`, derived exactly below
 * by walking the same recursion the source walks.
 */
export function suspensionLag(speed, grade, {suspensionRate = 12, dt = 1 / 60} = {}) {
  const k = Math.min(1, suspensionRate * dt);
  let y = 0, support = 0;
  for (let i = 0; i < 20000; i++) {
    support += speed * grade * dt;
    y += (support - y) * k;
  }
  return Math.abs(support - y);
}

/** Local (adjacent-knot) relief check used by the preservation rules. */
export function localRelief(heights = KNOT_HEIGHTS) {
  const n = heights.length;
  let worst = {delta: 0, sector: -1};
  for (let i = 0; i < n; i++) {
    const delta = Math.abs(knotHeight(i + 1, heights) - knotHeight(i, heights));
    if (delta > worst.delta) worst = {delta, sector: i};
  }
  return worst;
}

/**
 * Per-gate authored height window. `race.mjs` currently hardcodes
 * `-0.25 <= y <= 3`; revision 1 keeps exactly that band, translated to the
 * local road Y, so an ungraded map is byte-identical in behaviour.
 */
export function gateWindow(i, heights = KNOT_HEIGHTS) {
  const y = knotHeight(i, heights);
  return {y, y0: y - LIMITS.gateWindowBelow, y1: y + LIMITS.gateWindowAbove};
}

/**
 * The exact predicate a graded `game/race.mjs` would evaluate at `race.mjs:218`
 * in place of the hardcoded `y < -.25 || y > 3`. It reads an authored window
 * when the gate carries one and otherwise falls back to today's numbers, so a
 * map with no authored gate height keeps bit-identical behaviour.
 */
export function insideGateWindow(gate, y) {
  const y0 = Number.isFinite(gate?.y0) ? gate.y0
    : Number.isFinite(gate?.y) ? gate.y - LIMITS.gateWindowBelow : -LIMITS.gateWindowBelow;
  const y1 = Number.isFinite(gate?.y1) ? gate.y1
    : Number.isFinite(gate?.y) ? gate.y + LIMITS.gateWindowAbove : LIMITS.gateWindowAbove;
  return Number.isFinite(y) && y >= y0 && y <= y1;
}
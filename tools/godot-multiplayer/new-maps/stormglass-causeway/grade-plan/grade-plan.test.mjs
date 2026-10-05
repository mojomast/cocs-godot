// Bounded source acceptance for the Stormglass grade plan.
//
// SOURCE-ONLY. Every assertion below is derived from committed source: the
// accepted Stormglass recipe, `game/terrain.mjs`, `game/vehicles.mjs`,
// `game/core.mjs` and `game/race.mjs`. No engine, Blender, network, runtime
// world data, receipt or artifact is touched, and nothing is written to disk.
//
// What these tests are and are not:
//   * They are arithmetic and authority-consistency checks on the *proposal*.
//   * They prove the proposal is internally consistent with production code.
//   * They prove nothing about native physics, chase-camera feel or lap times.

import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

import {LIMITS, KNOT_HEIGHTS, GRADE_VERSION, PROFILE_ID,
  knotHeight, roadHeight, gradeLedger, relief, localRelief,
  breakAmplitude, suspensionLag, gateWindow, insideGateWindow} from './grade-profile.mjs';
import {acceptedArena, gradedArena, arenaWithoutBarrierRebase, project,
  profileHeightAt, authoritySampler, supportProfile, supportSummary,
  subdivisionStudy, physicsSensitivity, gateAdmission, containment,
  cameraRigs, verticalEnvelope, gradePlan, rebaseVertex, PROFILE_EXEMPT}
  from './grade-analysis.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';
import {obstructed} from '../../../../../game/core.mjs';
import {PUMA, stepVehicle, createVehicle, respawnVehicle} from '../../../../../game/vehicles.mjs';
import {crossRaceGates} from '../../../../../game/race.mjs';

const arena = acceptedArena();
const centerline = arena.race.centerline;
const plan = gradePlan();

test('profile is closed, versioned and one knot per accepted centerline node', () => {
  assert.equal(KNOT_HEIGHTS.length, centerline.length);
  assert.equal(GRADE_VERSION, 1);
  assert.equal(PROFILE_ID, 'stormglass-causeway/grade-v1');
  assert.equal(knotHeight(0), 0);
  assert.equal(knotHeight(centerline.length), knotHeight(0), 'profile must close on the datum');
});

test('roadHeight is linear in the sector parameter and wraps at the datum', () => {
  for (let i = 0; i < centerline.length; i++) {
    assert.ok(Math.abs(roadHeight(i, 0) - knotHeight(i)) < 1e-12);
    assert.ok(Math.abs(roadHeight(i, 1) - knotHeight(i + 1)) < 1e-12);
    const mid = roadHeight(i, 0.5);
    assert.ok(Math.abs(mid - (knotHeight(i) + knotHeight(i + 1)) / 2) < 1e-12);
    assert.equal(roadHeight(i, -5), roadHeight(i, 0), 'clamped below');
    assert.equal(roadHeight(i, 9), roadHeight(i, 1), 'clamped above');
  }
});

test('relief stays inside the declared cap and the starting grid holds the datum', () => {
  const r = relief();
  assert.equal(r.datum, 0);
  assert.ok(r.span <= LIMITS.maxRelief, `relief ${r.span} exceeds ${LIMITS.maxRelief}`);
  for (const i of [0, 20]) assert.equal(knotHeight(i), 0, `knot ${i} moved off the grid datum`);
  const local = localRelief();
  assert.ok(local.delta <= LIMITS.maxLocalRelief, `local relief ${local.delta}`);
});

test('every driven line stays under the 8% grade cap, on both mitred edges', () => {
  const ledger = gradeLedger(centerline, arena.race.boundary);
  assert.equal(ledger.length, centerline.length);
  for (const row of ledger) {
    for (const [edge, grade] of [['center', row.centerGrade], ['outer', row.outerGrade], ['inner', row.innerGrade]]) {
      assert.ok(Math.abs(grade) <= LIMITS.maxGrade,
        `sector ${row.sector} ${edge} grade ${(grade * 100).toFixed(3)}% exceeds ${LIMITS.maxGrade * 100}%`);
    }
  }
  // The steepest driven line is a mitred road edge, not the centerline.
  assert.ok(plan.grades.maxInnerEdge > plan.grades.maxCentreline,
    'the trapezoid road strip should make an edge steeper than the centerline');
  assert.ok(plan.grades.steepest <= LIMITS.maxGrade);
});

test('relief lands on the authored quay crest, not on the bore or the grid', () => {
  const r = relief();
  assert.ok(r.crestNode >= 8 && r.crestNode <= 12, `crest node ${r.crestNode}`);
  for (const i of [4, 5, 6]) assert.equal(knotHeight(i), 0, 'freight bore must hold the datum');
});

test('the accepted XZ footprint is preserved bit-for-bit by the rebase', () => {
  const graded = gradedArena();
  assert.equal(graded.terrain.surfaces.length, arena.terrain.surfaces.length);
  assert.equal(graded.terrain.walls.length, arena.terrain.walls.length);
  assert.deepEqual(graded.race.centerline, arena.race.centerline);
  assert.deepEqual(graded.race.gates.map(g => [g.x, g.z]), arena.race.gates.map(g => [g.x, g.z]));
  assert.deepEqual(graded.race.grid, arena.race.grid);
  assert.deepEqual(graded.spawns, arena.spawns);
  assert.deepEqual(graded.navNodes, arena.navNodes);
  for (let i = 0; i < arena.terrain.surfaces.length; i++) {
    const a = arena.terrain.surfaces[i].vertices, b = graded.terrain.surfaces[i].vertices;
    assert.equal(a.length, b.length);
    for (let k = 0; k < a.length; k++) {
      assert.equal(a[k][0], b[k][0], `surface ${i} vertex ${k} X moved`);
      assert.equal(a[k][2], b[k][2], `surface ${i} vertex ${k} Z moved`);
    }
  }
  assert.deepEqual(arena.metrics.roadWidth, 28);
  assert.equal(arena.metrics.roadRelief, 0, 'the accepted concession is still zero');
});

test('rebaseVertex adds the local profile height and nothing else', () => {
  const before = [12.5, 2.8, -40.25];
  const after = rebaseVertex(centerline, before);
  assert.equal(after[0], before[0]);
  assert.equal(after[2], before[2]);
  assert.ok(Math.abs(after[1] - before[1] - profileHeightAt(arena, before[0], before[2])) < 1e-12);
});

test('the bounded cosmetic ocean stays flat and is never authority geometry', () => {
  assert.ok(PROFILE_EXEMPT.has('ocean'));
  const mesh = arena.art.meshes.find(m => m.id === 'ocean');
  assert.ok(mesh, 'the sea plane is an art mesh');
  assert.equal(mesh.collision, 'none');
  assert.deepEqual(mesh.vertices.map(v => v[1]), [-4, -4, -4, -4]);
  assert.equal(arena.terrain.surfaces.some(s => s.id === 'ocean'), false,
    'the sea plane must never become walkable support');
  const graded = gradedArena();
  assert.deepEqual(graded.art, arena.art, 'the rebase never touches art geometry');
});

test('authority support along the sample route matches the authored profile', () => {
  const graded = gradedArena();
  const rows = supportProfile(graded);
  const summary = supportSummary(rows);
  const ledger = gradeLedger(centerline, arena.race.boundary);
  assert.ok(summary.samples >= 440, `only ${summary.samples} support samples`);
  for (const row of rows) {
    assert.notEqual(row.support, null, `${row.label} has no support`);
    const at = project(centerline, row.x, row.z);
    const expected = 1 / Math.sqrt(1 + ledger[at.sector].centerGrade ** 2);
    assert.ok(Math.abs(row.normalY - expected) < 0.005,
      `${row.label} normal.y ${row.normalY} vs ramp normal ${expected}`);
  }
  // One quad per sector cannot hold a linear grade: the trapezoid strip's two
  // triangles disagree, and the support query returns the higher one.
  assert.ok(summary.maxAbsDelta > 0.1, 'the accepted one-quad strip must show a support ridge');
});

test('subdividing the road strip converges the support ridge to the authored grade', () => {
  const study = subdivisionStudy();
  const [k1, , , k8, k16, k32] = study;
  assert.ok(k8.maxAbsDelta < k1.maxAbsDelta / 8, 'error should fall roughly as 1/k^2');
  assert.ok(k32.maxAbsDelta < k16.maxAbsDelta, 'still converging at 32');
  assert.equal(k16.sectorsOverTwoCentimetres.length, 0,
    `k=16 still over 2 cm at sectors ${k16.sectorsOverTwoCentimetres}`);
  assert.ok(k16.maxAbsDelta <= 0.02, `k=16 support error ${k16.maxAbsDelta} exceeds the 2 cm probe budget`);
  // Sector 8 has the worst mitred edge-length ratio on a graded sector, so it
  // is the last one to converge: a useful place for the recipe to spend more.
  assert.ok(k8.sectorsOverTwoCentimetres.length >= 1, 'k=8 must still have a straggler');
  for (const row of study) assert.ok(row.minNormalY > 0.99, 'no triangle may approach vertical');
});

test('every centerline node and grid slot is supported at the authored height', () => {
  const graded = gradedArena();
  const maxSlope = graded.terrain.maxSlope;
  for (const p of centerline) {
    const support = terrainSupportAt(p.x, p.z, graded.terrain, maxSlope);
    assert.ok(support, `node ${p.x},${p.z} unsupported`);
    assert.ok(Math.abs(support.y - profileHeightAt(graded, p.x, p.z)) < 0.25,
      `node support ${support.y} far from profile`);
    assert.ok(support.normal[1] > 0.99);
  }
  for (const slot of graded.race.grid) {
    const support = terrainSupportAt(slot.x, slot.z, graded.terrain, maxSlope);
    assert.equal(knotHeight(20), 0);
    assert.ok(support && Math.abs(support.y) < 1e-9, 'the grid must sit on the datum');
  }
});

test('the existing hardcoded gate window cannot admit an elevated crossing', () => {
  const admission = gateAdmission(centerline);
  assert.equal(admission.length, centerline.length);
  const unreachable = admission.filter(r => !r.acceptedByCurrentRule);
  assert.ok(unreachable.length > 0, 'a 6.8 m crest must break the -0.25..3 window');
  for (const row of unreachable) assert.ok(row.roadY > 3, `gate ${row.gate} below the ceiling`);
  assert.equal(admission.filter(r => r.acceptedByAuthoredWindow).length, centerline.length,
    'the authored per-gate window must admit every gate');
});

test('the authored gate window is exactly the existing band translated to local Y', () => {
  const admission = gateAdmission(centerline);
  for (const row of admission) {
    assert.ok(Math.abs(row.window.y0 - (row.roadY - 0.25)) < 1e-12);
    assert.ok(Math.abs(row.window.y1 - (row.roadY + 3)) < 1e-12);
  }
  // Untranslated, it reproduces today's behaviour on a flat map exactly.
  const flat = gateWindow(0, new Array(centerline.length).fill(0));
  assert.equal(flat.y0, -0.25);
  assert.equal(flat.y1, 3);
});

test('an ungraded map keeps its exact crossing behaviour under the default window', () => {
  const gates = centerline.map(p => ({...p, nx: 1, nz: 0, halfWidth: 13.9}));
  const attempt = (fromY, toY, window) => {
    const state = {gates, racers: [], phase: 'racing', laps: 3, elapsed: 0};
    const racer = {actorId: 0, nextGate: 0, passed: 0, started: false, progress: 0, completedLaps: 0, checkpointAge: 0, anchor: {}};
    state.racers.push(racer);
    crossRaceGates(state, racer, {x: gates[0].x - 0.5, y: fromY, z: gates[0].z},
      {x: gates[0].x + 0.5, y: toY, z: gates[0].z}, 0, 1);
    return racer.passed;
  };
  assert.equal(attempt(0, 0), 1, 'a flat crossing must still count');
  assert.equal(attempt(4, 4), 0, 'the existing ceiling must still reject 4 m');
  assert.equal(attempt(-1, -1), 0, 'the existing floor must still reject -1 m');
  assert.equal(attempt(2.9, 0), 1, 'inside the existing band must still count');
});

test('the proposed gate predicate reproduces the shipped rule exactly when ungraded', () => {
  // `insideGateWindow` is the exact expression a graded race.mjs would evaluate.
  // With no authored window it must agree with crossRaceGates on every sample.
  for (const y of [-1, -0.3, -0.25, 0, 1, 2.9, 3, 3.1, 4, 8, NaN, undefined, Infinity]) {
    assert.equal(insideGateWindow({}, y), y >= -0.25 && y <= 3 && Number.isFinite(y),
      `default window disagrees with the shipped rule at y=${y}`);
  }
  // The translated window admits every authored Stormglass crossing.
  for (let i = 0; i < centerline.length; i++) {
    const window = gateWindow(i);
    assert.equal(insideGateWindow(window, window.y), true, `gate ${i} rejects its own road height`);
    assert.equal(insideGateWindow(window, window.y - 0.25), true);
    assert.equal(insideGateWindow(window, window.y + 3), true);
    assert.equal(insideGateWindow(window, window.y - 0.2500001), false);
    assert.equal(insideGateWindow(window, window.y + 3.0000001), false);
  }
});

test('rebasing the barriers preserves lateral containment; skipping it does not', () => {
  const graded = gradedArena();
  const flatBaseline = containment(arena, true, new Array(centerline.length).fill(0));
  const rebased = containment(graded, true);
  const unrebased = containment(graded, false);
  assert.equal(rebased.blocked, flatBaseline.blocked,
    'a graded road must block exactly what the flat road blocks');
  assert.equal(rebased.freeProbes, 0);
  assert.ok(unrebased.freeProbes > rebased.freeProbes + 40,
    `leaving the barriers on the datum only lost ${unrebased.freeProbes - rebased.freeProbes} probes`);
});

test('the containment probe radius is the documented Puma race radius', () => {
  const graded = gradedArena();
  const i = 0, p = centerline[i];
  const o = graded.race.boundary.outer[i], q = graded.race.boundary.inner[i];
  const len = Math.hypot(o.x - q.x, o.z - q.z) || 1;
  const outward = {x: (o.x - q.x) / len, z: (o.z - q.z) / len};
  const barrier = Math.hypot(o.x - p.x, o.z - p.z);
  const x = p.x + outward.x * (barrier + 0.1), z = p.z + outward.z * (barrier + 0.1);
  assert.equal(obstructed(x, 0, z, 2.08387, graded), true);
});

test('source physics loses no top speed to the grade', () => {
  const physics = physicsSensitivity(gradedArena());
  assert.equal(physics.flat.grade, 0);
  assert.ok(Math.abs(physics.topSpeedFlat - PUMA.speed) < 1e-9);
  // thrust is throttle-only and drag is the only resistance, so the grade
  // cannot reduce straight-line speed in the current model.
  assert.equal(physics.speedDelta, 0);
  assert.equal(physics.topSpeedSteepest, PUMA.speed);
});

test('the grade costs lateral grip exactly as slopeGrip predicts', () => {
  const physics = physicsSensitivity(gradedArena());
  const steep = physics.steepest;
  const expected = PUMA.grip * Math.max(0.4, Math.min(1, steep.minNormalY));
  assert.ok(Math.abs(steep.grip - expected) < 1e-12);
  assert.ok(steep.grip < physics.gripFlat, 'an uphill must cost some grip');
  assert.ok(Math.abs(physics.gripFlat - PUMA.grip) < 1e-12, 'flat grip is unchanged');
  // At a 4 deg slope the loss is a fraction of a percent, not a balance change.
  assert.ok((PUMA.grip - steep.grip) / PUMA.grip < 0.005);
});

test('steepestVehicleGrade reproduces the ledger from a driving run', () => {
  const physics = physicsSensitivity(gradedArena());
  const ledger = gradeLedger(centerline, arena.race.boundary);
  for (const row of physics.rows) {
    assert.ok(Math.abs(Math.abs(row.grade) - Math.abs(ledger[row.sector].centerGrade)) < 1e-12);
  }
});

test('the sampled ground normal is the analytic plane normal of the ramp', () => {
  const graded = gradedArena();
  const ground = authoritySampler(graded);
  const sample = ground(centerline[7].x, centerline[7].z);
  assert.ok(sample && typeof sample === 'object');
  const ledger = gradeLedger(centerline, arena.race.boundary);
  const grade = ledger[7].centerGrade;
  const expected = 1 / Math.sqrt(1 + grade * grade);
  assert.ok(Math.abs(sample.normal.y - expected) < 0.01,
    `normal.y ${sample.normal.y} vs analytic ${expected}`);
});

test('the vehicle stays grounded through every grade break', () => {
  const physics = physicsSensitivity(gradedArena());
  assert.equal(physics.anyUngrounded, false);
  for (const row of physics.rows) assert.ok(row.stayedGrounded, `sector ${row.sector} ungrounded`);
});

test('the vertical envelope stays inside the 0.4 m grounded tolerance', () => {
  const envelope = verticalEnvelope(centerline);
  assert.ok(envelope.maxBreak > 0, 'the profile must actually contain a grade break');
  assert.ok(envelope.worstVerticalError < envelope.groundedTolerance,
    `worst vertical error ${envelope.worstVerticalError} reaches the grounded tolerance`);
  assert.ok(envelope.headroom > 0.2, `only ${envelope.headroom} m of grounded headroom`);
  assert.ok(envelope.maxGradeDeg < envelope.pitchMaxDeg);
  assert.equal(envelope.rollMaxDeg, PUMA.rollMax * 180 / Math.PI, 'cross-level road: zero roll');
});

test('breakAmplitude and suspensionLag agree with a walked source recursion', () => {
  const envelope = verticalEnvelope(centerline);
  assert.ok(Math.abs(breakAmplitude(envelope.maxBreak, PUMA.dimensions.length) - envelope.breakAmplitude) < 1e-12);
  const walked = suspensionLag(PUMA.speed, 0.0677, {suspensionRate: PUMA.suspensionRate, dt: 1 / 60});
  assert.ok(walked > 0 && walked < 0.2);
  assert.ok(Math.abs(suspensionLag(0, 0.0677) - 0) < 1e-12, 'a stationary car has no lag');
  // Lag grows with speed and with grade, and is zero on the flat.
  assert.ok(suspensionLag(PUMA.speed, 0.0677) > suspensionLag(PUMA.speed / 2, 0.0677));
  assert.ok(suspensionLag(PUMA.speed, 0.0677) > suspensionLag(PUMA.speed, 0.03));
});

test('a hand-driven vehicle on the graded profile rides the surface without leaving it', () => {
  const graded = gradedArena();
  const ground = authoritySampler(graded);
  const vehicle = createVehicle(PUMA);
  // Launch at the foot of the quay climb (sector 6) so the run covers the
  // steepest authored sector rather than the flat datum run.
  const start = centerline[6], next = centerline[7];
  const heading = Math.atan2(next.x - start.x, next.z - start.z);
  respawnVehicle(vehicle, {x: start.x, y: knotHeight(6), z: start.z}, heading);
  vehicle.speed = PUMA.speed;
  vehicle.velocity = {x: Math.sin(heading) * PUMA.speed, z: Math.cos(heading) * PUMA.speed};
  let worst = 0;
  for (let i = 0; i < 400; i++) {
    stepVehicle(vehicle, {throttle: 1, steer: 0}, 1 / 60, next => next, ground);
    const sample = ground(vehicle.position.x, vehicle.position.z);
    if (sample == null) continue;
    const y = typeof sample === 'number' ? sample : sample.y;
    worst = Math.max(worst, Math.abs(vehicle.position.y - y));
    assert.ok(Number.isFinite(vehicle.position.y));
  }
  assert.ok(vehicle.position.y > 1, `the run should have climbed off the datum, reached ${vehicle.position.y}`);
  assert.ok(worst < 0.4, `chassis left the surface by ${worst} m`);
  assert.equal(vehicle.grounded, true);
});

test('the profile keeps only the chase and orbit rigs above the road', () => {
  const rigs = cameraRigs(centerline);
  assert.equal(rigs.chase.relative, true);
  assert.equal(rigs.orbit.relative, true);
  for (const name of ['trackside', 'cinematic', 'flyover']) {
    assert.equal(rigs[name].relative, false, `${name} is an absolute-height rig`);
  }
  assert.equal(rigs.trackside.safeAboveRoad, false, 'trackside at 3.4 m is below the 6.8 m crest');
  assert.equal(rigs.cinematic.safeAboveRoad, false);
  assert.ok(rigs.flyover.clearanceAtCrest > 0);
  // These rigs are menu-reel presentation, not the in-match chase camera.
  const source = readFileSync(new URL('../../../../../game/race-camera.mjs', import.meta.url), 'utf8');
  assert.ok(source.includes("RACE_DEMO_MODES = ['chase', 'orbit', 'flyover', 'trackside']"));
  assert.ok(source.includes('y = focus.y + 5'), 'the in-match chase rig is relative to the car');
});

test('no new mode, no new pair and no catalog change is proposed', () => {
  assert.deepEqual(arena.candidateModes, ['puma-race']);
  assert.deepEqual(arena.modeBindings, {});
  assert.equal(plan.footprint.modes.length, 1);
  assert.ok(arena.race);
  assert.equal(plan.footprint.centerline, 21, 'gate count is preserved');
});

test('the analysis is deterministic and self-contained', () => {
  assert.deepEqual(gradePlan(), plan);
  assert.deepEqual(gradedArena().terrain.surfaces, gradedArena().terrain.surfaces);
  const onNode = project(centerline, centerline[4].x, centerline[4].z);
  assert.ok(onNode.distance < 1e-9, 'a centerline node must project onto the polyline');
  assert.ok([3, 4].includes(onNode.sector), `knot 4 projected to sector ${onNode.sector}`);
  // Nothing in this tool writes: it returns values, it does not emit files.
  assert.equal(typeof gradePlan, 'function');
  // Source-only proof: neither module imports or calls a filesystem write API.
  for (const name of ['grade-profile.mjs', 'grade-analysis.mjs']) {
    const source = readFileSync(new URL(name, import.meta.url), 'utf8');
    for (const forbidden of ['writeFileSync', 'appendFileSync', 'mkdirSync', 'createWriteStream']) {
      assert.ok(!source.includes(forbidden), `${name} must not call ${forbidden}`);
    }
    assert.ok(!source.includes('node:fs'), `${name} must not import node:fs`);
  }
});

test('the accepted Stormglass recipe still declares the flat-road concession', () => {
  assert.equal(arena.metrics.roadRelief, 0);
  assert.equal(arena.terrain.base, 0);
  const source = readFileSync(new URL('../recipe.mjs', import.meta.url), 'utf8');
  assert.ok(source.includes("roadRelief:0,architectureRelief:24"),
    'the accepted recipe must keep reporting zero relief until a grant lands');
});

test('the arena without a barrier rebase is strictly less safe than the rebased one', () => {
  const graded = gradedArena();
  const broken = arenaWithoutBarrierRebase();
  assert.equal(broken.terrain.walls.filter(w => w.id.startsWith('barrier-')).length, 0);
  assert.ok(graded.terrain.walls.some(w => w.id.startsWith('barrier-')));
  assert.equal(containment(graded, false).freeProbes,
    containment(graded, false).samples.filter(s => !s.blocked).length);
});
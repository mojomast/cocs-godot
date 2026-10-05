#!/usr/bin/env node
// Prints the deterministic Stormglass grade-plan report to stdout.
//
// SOURCE-ONLY. Writes no file, touches no runtime data, artifact, receipt or
// network, and starts no engine. Everything printed here is re-derived from the
// accepted recipe plus `game/terrain.mjs`, `game/vehicles.mjs`,
// `game/core.mjs` and `game/race.mjs`.
//
//   node tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/report.mjs
//   node .../report.mjs --json
import {gradePlan} from './grade-analysis.mjs';
import {gradeLedger} from './grade-profile.mjs';
import {acceptedArena} from './grade-analysis.mjs';

const plan = gradePlan();
const arena = acceptedArena();
const pct = value => `${(value * 100).toFixed(3)}%`;
const m = value => `${value.toFixed(4)} m`;
const ledger = gradeLedger(arena.race.centerline, arena.race.boundary);

if (process.argv.includes('--json')) {
  console.log(JSON.stringify(plan, null, 2));
  process.exit(0);
}

console.log(`profile            ${plan.profile.id} v${plan.profile.version}`);
console.log(`knots (21)         ${plan.profile.knots.join(' ')}`);
console.log(`relief             crest ${m(plan.relief.crest)} above datum ${m(plan.relief.datum)} (span ${m(plan.relief.span)})`);
console.log(`largest knot step  ${m(plan.relief.local.delta)} at sector ${plan.relief.local.sector}`);
console.log(`grade cap          ${pct(plan.grades.cap)}; steepest driven line ${pct(plan.grades.steepest)} (sector ${plan.grades.steepestSector}); headroom ${pct(plan.grades.headroom)}`);
console.log(`centreline grade   max ${pct(plan.grades.maxCentreline)}`);
console.log(`outer edge grade   max ${pct(plan.grades.maxOuterEdge)}`);
console.log(`inner edge grade   max ${pct(plan.grades.maxInnerEdge)}`);
console.log(`largest break      ${pct(plan.grades.maxBreak)} at sector ${plan.envelope.breakSector}`);
console.log(`break amplitude    ${m(plan.envelope.breakAmplitude)} (0.5 * wheelBase * |dGrade|)`);
console.log(`sustained lag      ${m(plan.envelope.sustainedLag)} at top speed on the steepest ramp`);
console.log(`worst vertical     ${m(plan.envelope.worstVerticalError)} vs grounded tolerance ${m(plan.envelope.groundedTolerance)}; headroom ${m(plan.envelope.headroom)}`);
console.log(`support samples    ${plan.support.samples}; worst ridge ${m(plan.support.maxAbsDelta)} at ${plan.support.worst.label}`);
console.log('');
console.log('road strip subdivision (mitred trapezoid, one quad per sector today):');
for (const row of plan.subdivisions) {
  console.log(`  k=${String(row.subdivisions).padStart(2)}  surfaces ${String(row.surfaces).padStart(4)}  triangles ${String(row.triangles).padStart(4)}  ridge ${m(row.maxAbsDelta)}  over 2 cm: ${row.sectorsOverTwoCentimetres.length ? row.sectorsOverTwoCentimetres.join(',') : 'none'}`);
}
console.log('');
console.log('vehicle (real stepVehicle, real authority support sampler):');
console.log(`  flat top speed   ${plan.physics.topSpeedFlat} m/s`);
console.log(`  steep top speed  ${plan.physics.topSpeedSteepest} m/s (delta ${plan.physics.speedDelta})`);
console.log(`  grip flat/steep  ${plan.physics.gripFlat} -> ${plan.physics.gripSteepest.toFixed(5)}`);
console.log(`  any ungrounded   ${plan.physics.anyUngrounded}`);
console.log(`  max |y - support| ${m(plan.physics.maxVerticalLag)}`);
console.log('');
console.log(`gates admitted by the shipped rule  ${plan.gates.admittedByCurrentRule}/${plan.gates.total}`);
console.log(`gates admitted by the authored window ${plan.gates.admittedByAuthoredWindow}/${plan.gates.total}`);
console.log(`unreachable under the shipped rule  ${plan.gates.unreachable.join(', ') || 'none'}`);
console.log('');
console.log(`containment (Puma r=2.08387, 63 probes)`);
console.log(`  accepted flat baseline  blocked ${plan.containment.acceptedFlatBaseline.blocked}, free ${plan.containment.acceptedFlatBaseline.freeProbes}`);
console.log(`  graded, barriers rebased blocked ${plan.containment.rebased.blocked}, free ${plan.containment.rebased.freeProbes}`);
console.log(`  graded, barriers NOT rebased  blocked ${plan.containment.unrebased.blocked}, free ${plan.containment.unrebased.freeProbes}`);
console.log('');
console.log('per-sector grades (centre / outer edge / inner edge):');
for (const row of ledger) {
  console.log(`  sector ${String(row.sector).padStart(2)}  ${pct(row.centerGrade).padStart(8)} ${pct(row.outerGrade).padStart(8)} ${pct(row.innerGrade).padStart(8)}   dy ${row.delta >= 0 ? '+' : ''}${row.delta.toFixed(1)} m over ${row.centerLength.toFixed(1)} m`);
}
#!/usr/bin/env node
// Evidence check for the committed benchmark matrices. It re-reads every run in
// port/native-benchmark/evidence/matrix-*.json, validates each result, and prints
// the level comparisons it can defend.
//
//   node port/native-benchmark/verify_evidence.mjs
//   node port/native-benchmark/verify_evidence.mjs --require-slower
//
// --require-slower additionally asserts that Extreme is at least 1.25x slower
// than Low at the same resolution. Extreme raises the shared particle pool from
// 8,192 to 1,000,000 slots, so a saturated software rasterizer must show it. Low
// vs High is printed but not asserted: the arena's own rasterization dominates at
// these resolutions and bot activity differs per run. This is not a hardware gate.
import {readdirSync, readFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {compareResults, lineSummary, validateResult} from './validate.mjs';

const root = resolve(import.meta.dirname, '../..');
const evidence = join(root, 'port/native-benchmark/evidence');
const requireSlower = process.argv.includes('--require-slower');
const matrices = readdirSync(evidence).filter(name => name.startsWith('matrix-') && name.endsWith('.json')).sort();
if (matrices.length === 0) {
  console.error(`No matrix-*.json files in ${evidence}; run run_benchmark.mjs first.`);
  process.exit(1);
}
let problems = 0;
let comparisons = 0;
let expected = 0;
let slower = 0;
for (const name of matrices) {
  const matrix = JSON.parse(readFileSync(join(evidence, name), 'utf8'));
  console.log(`\n${name}  map=${matrix.map} bots=${matrix.bots} resolution=${matrix.resolution} label=${matrix.label || '-'}`);
  for (const run of matrix.runs) {
    const result = run.result ? run.result : JSON.parse(readFileSync(join(run.directory, 'result.json'), 'utf8'));
    const validation = validateResult(result);
    const ok = validation.ok && result.complete;
    if (!ok) problems += 1;
    console.log(`  ${ok ? 'PASS' : 'FAIL'} ${run.level.padEnd(8)} ${lineSummary(result)}`);
    for (const problem of validation.problems) console.log(`        ${problem}`);
    if (!result.honesty?.software_renderer) {
      console.log('        NOTE: not a software renderer; comparisons below describe this machine only');
    }
  }
  for (const comparison of matrix.comparisons ?? []) {
    const [label, value] = Object.entries(comparison)[0];
    comparisons += 1;
    if (value.slower) slower += 1;
    const asserted = value.baseline === 'Low' && value.candidate === 'Extreme';
    if (asserted) expected += 1;
    console.log(`  ${label}: ${value.baseline} -> ${value.candidate} median x${value.median_ratio.toFixed(2)}`
      + ` (p95 x${value.p95_ratio.toFixed(2)}, frames ${value.frames[0]}/${value.frames[1]},`
      + ` particles ${value.particles[0]}/${value.particles[1]})${value.slower ? ' SLOWER' : ' not slower'}${asserted ? ' [asserted]' : ''}`);
  }
}
console.log(`\n${matrices.length} matrices, ${comparisons} comparisons, ${slower} slower, ${problems} invalid runs`);
if (problems > 0) process.exit(1);
if (requireSlower && (expected === 0 || slower < expected)) {
  console.error(`At least one Low -> Extreme comparison was expected to be slower and was not (${slower} slower of ${expected} asserted).`);
  process.exit(1);
}

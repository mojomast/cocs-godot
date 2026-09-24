// Per-snapshot serialization cost for the port-owned native authority.
//
// Measures the exact pieces authority.mjs runs per snapshot tick against a real
// generated native arena and the unmodified source Match:
//   1. match.snapshot()            (state construction)
//   2. JSON.stringify(full frame)  (wire serialization)
//   3. JSON.parse(text)            (the observer copy `report` already performs)
//   4. structuredClone(input)      (inbound input copy, for reference)
//
// Run: node port/native-motion-smoothness/serialize-cost.mjs
import {createNativeMatch} from '../native-arenas/match.mjs';
import {seededRandom} from '../native-arenas/tests/fixtures.mjs';

const round = value => Math.round(value * 1000) / 1000;
const stats = values => {
  const sorted = [...values].sort((a, b) => a - b);
  const at = ratio => sorted[Math.min(sorted.length - 1, Math.floor(ratio * sorted.length))];
  return {meanMs: round(values.reduce((sum, value) => sum + value, 0) / values.length),
    p50Ms: round(at(0.5)), p95Ms: round(at(0.95)), p99Ms: round(at(0.99)), maxMs: round(sorted[sorted.length - 1])};
};

const report = {};
for (const botCount of [2, 7]) {
  const match = createNativeMatch({mapId: 'prism-foundry', config: {mode: 'deathmatch', botCount,
    difficulty: 'normal', timeLimit: 180, fragLimit: 15}, random: seededRandom(7)});
  const snapshotMs = [], stringifyMs = [], parseMs = [], stepMs = [];
  let bytes = 0, seq = 0;
  const ticks = 900;
  for (let tick = 0; tick < ticks; tick++) {
    // Ordinary driven input, computed outside the timed sections.
    const controls = {x: tick % 120 < 60 ? 0 : 1, z: tick % 120 < 60 ? 1 : 0,
      yaw: (tick % 360) * 0.01, pitch: 0, fire: false};
    let started = performance.now();
    match.step(1 / 60, {inputs: {0: controls}});
    stepMs.push(performance.now() - started);
    started = performance.now();
    const state = match.snapshot();
    snapshotMs.push(performance.now() - started);
    started = performance.now();
    const text = JSON.stringify({type: 'snapshot', seq: ++seq, acks: {0: tick}, inputEpoch: 1,
      nativeArenaInput: {receivedSeq: tick, appliedSeq: tick, cancelledThrough: 0, queueDepth: 0}, state});
    stringifyMs.push(performance.now() - started);
    bytes = Buffer.byteLength(text);
    started = performance.now();
    JSON.parse(text);
    parseMs.push(performance.now() - started);
  }
  const clones = [];
  for (let i = 0; i < 1000; i++) {
    const sample = {x: 1, z: 0, yaw: 0.1, pitch: 0, weapon: 0, fire: true, jump: false,
      power: false, interact: false, sprint: true, crouch: false, ads: false,
      reload: false, melee: false, grenade: false, mobility: false, altFire: false};
    const started = performance.now();
    structuredClone(sample);
    clones.push(performance.now() - started);
  }
  const perTickMs = snapshotMs.reduce((a, b) => a + b, 0) / snapshotMs.length +
    stringifyMs.reduce((a, b) => a + b, 0) / stringifyMs.length +
    parseMs.reduce((a, b) => a + b, 0) / parseMs.length;
  report[`bots${botCount}`] = {
    actors: match.actors.length, ticks: snapshotMs.length, frameBytes: bytes,
    step: stats(stepMs), snapshotState: stats(snapshotMs),
    stringify: stats(stringifyMs), observerParse: stats(parseMs),
    inputClone: stats(clones),
    snapshotStatePlusStringifyMs: round(perTickMs),
    costAt20HzMsPerSecond: round(perTickMs * 20),
    costAt60HzMsPerSecond: round(perTickMs * 60),
    costAt60HzPercentOfOneCore: round(perTickMs * 60 / 10),
  };
}
console.log(JSON.stringify(report, null, 2));

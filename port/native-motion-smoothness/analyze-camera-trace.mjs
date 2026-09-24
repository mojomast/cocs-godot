// Analyze a client --native-trace JSONL: how often does the on-screen camera
// actually move, and how large is each move?
//
// Run: node port/native-motion-smoothness/analyze-camera-trace.mjs <trace.jsonl>...
import {readFileSync} from 'node:fs';

const round = value => Math.round(value * 10000) / 10000;
const stats = values => {
  if (!values.length) return {count: 0};
  const sorted = [...values].sort((a, b) => a - b);
  const at = ratio => sorted[Math.min(sorted.length - 1, Math.floor(ratio * sorted.length))];
  return {count: values.length, mean: round(values.reduce((a, b) => a + b, 0) / values.length),
    p50: round(at(0.5)), p95: round(at(0.95)), p99: round(at(0.99)),
    min: round(sorted[0]), max: round(sorted[sorted.length - 1])};
};

for (const path of process.argv.slice(2)) {
  const records = readFileSync(path, 'utf8').split('\n').filter(Boolean)
    .map(line => JSON.parse(line)).filter(record => record.event === 'snapshot' && record.camera_position);
  const gaps = [], steps = [];
  let movedDistance = 0;
  for (let index = 1; index < records.length; index++) {
    const previous = records[index - 1], current = records[index];
    if (current.round !== previous.round) continue;
    gaps.push((current.monotonic_usec - previous.monotonic_usec) / 1000);
    const dx = current.camera_position[0] - previous.camera_position[0];
    const dy = current.camera_position[1] - previous.camera_position[1];
    const dz = current.camera_position[2] - previous.camera_position[2];
    const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
    if (distance > 1e-6) { steps.push(distance); movedDistance += distance; }
  }
  const windowMs = records.length > 1 ? (records[records.length - 1].monotonic_usec - records[0].monotonic_usec) / 1000 : 0;
  console.log(JSON.stringify({
    path, round: records[0]?.round ?? null,
    snapshotSamples: records.length,
    windowMs: round(windowMs),
    sampleRateHz: round(records.length / Math.max(0.001, windowMs / 1000)),
    cameraGapMs: stats(gaps),
    movingSteps: steps.length,
    cameraUpdateRateHz: round(steps.length / Math.max(0.001, windowMs / 1000)),
    stepDistance: stats(steps),
    pathLength: round(movedDistance),
  }, null, 0));
}

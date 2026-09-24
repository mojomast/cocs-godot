// Evaluate the optional local-camera catch-up filter against the measured
// authoritative pose timeline. Never shipped by itself: this is the "prove it
// or drop it" evidence for the client-side smoothing option.
//
// Input: JSONL of {t, pose} snapshot arrivals captured by measure-wire.mjs
// (--pose-out). The 20 Hz analogue is every third sample, which is exactly the
// tick phase the old every-3rd-tick authority emitted.
//
// Policies compared at a 60 fps render clock:
//   direct   camera := newest authoritative pose the frame can see (shipped)
//   catch-up camera chases the newest pose with a first-order filter
//            (tau ms), no extrapolation, no prediction
//
// Run: node port/native-motion-smoothness/evaluate-smoothing.mjs <pose.jsonl>
import {readFileSync} from 'node:fs';

const RENDER_DT = 1 / 60;
const round = value => Math.round(value * 1000) / 1000;
const stats = values => {
  if (!values.length) return {count: 0};
  const sorted = [...values].sort((a, b) => a - b);
  const at = ratio => sorted[Math.min(sorted.length - 1, Math.floor(ratio * sorted.length))];
  return {count: values.length, mean: round(values.reduce((a, b) => a + b, 0) / values.length),
    p50: round(at(0.5)), p95: round(at(0.95)), p99: round(at(0.99)), max: round(sorted[sorted.length - 1])};
};

function evaluate(samples, tau) {
  const start = samples[0].t;
  const duration = samples[samples.length - 1].t - start;
  const camera = {...samples[0].pose};
  let index = 0, target = {...samples[0].pose};
  const steps = [], lag = [];
  let overshoot = 0;
  for (let frame = 0; frame * RENDER_DT <= duration; frame++) {
    const now = start + frame * RENDER_DT;
    while (index + 1 < samples.length && samples[index + 1].t <= now) {
      index += 1;
      target = samples[index].pose;
    }
    const before = {...camera};
    if (tau > 0) {
      const alpha = 1 - Math.exp(-RENDER_DT / tau);
      camera.x += (target.x - camera.x) * alpha;
      camera.z += (target.z - camera.z) * alpha;
    } else {
      camera.x = target.x; camera.z = target.z;
    }
    steps.push(Math.hypot(camera.x - before.x, camera.z - before.z));
    lag.push(Math.hypot(camera.x - target.x, camera.z - target.z));
    for (const axis of ['x', 'z']) {
      const previousSide = Math.sign(before[axis] - target[axis]);
      const currentSide = Math.sign(camera[axis] - target[axis]);
      if (previousSide !== 0 && currentSide === -previousSide)
        overshoot = Math.max(overshoot, Math.abs(camera[axis] - target[axis]));
    }
  }
  const final = samples[samples.length - 1].pose;
  // Last frame on which any authoritative target change arrived (the final
  // snapshot). Settling is measured from there, so the actor's own deceleration
  // tail is not misread as filter lag.
  let lastTargetFrame = 0;
  {
    let cursorLast = 0, previous = {...samples[0].pose};
    for (let frame = 0; frame * RENDER_DT <= duration; frame++) {
      const now = start + frame * RENDER_DT;
      while (cursorLast + 1 < samples.length && samples[cursorLast + 1].t <= now) {
        cursorLast += 1;
        const next = samples[cursorLast].pose;
        if (Math.abs(next.x - previous.x) > 1e-9 || Math.abs(next.z - previous.z) > 1e-9) lastTargetFrame = frame;
        previous = next;
      }
    }
  }
  let settleFrame = null;
  const replay = {x: samples[0].pose.x, z: samples[0].pose.z};
  // Re-run the filter only to find the settle frame; deterministic and cheap.
  let cursor = 0, targetReplay = {...samples[0].pose};
  for (let frame = 0; frame * RENDER_DT <= duration; frame++) {
    const now = start + frame * RENDER_DT;
    while (cursor + 1 < samples.length && samples[cursor + 1].t <= now) { cursor += 1; targetReplay = {...samples[cursor].pose}; }
    if (tau > 0) {
      const alpha = 1 - Math.exp(-RENDER_DT / tau);
      replay.x += (targetReplay.x - replay.x) * alpha;
      replay.z += (targetReplay.z - replay.z) * alpha;
    } else { replay.x = targetReplay.x; replay.z = targetReplay.z; }
    if (frame >= lastTargetFrame && settleFrame === null &&
        Math.hypot(replay.x - final.x, replay.z - final.z) < 0.005) settleFrame = frame;
  }
  return {
    tauMs: Math.round(tau * 1000),
    frameStepM: stats(steps),
    zeroStepFrames: steps.filter(value => value < 1e-6).length,
    framesOver50mm: steps.filter(value => value > 0.05).length,
    addedLagToNewestPoseM: stats(lag),
    settleAfterFinalTargetFrames: settleFrame === null ? null : settleFrame - lastTargetFrame,
    settleAfterFinalTargetMs: settleFrame === null ? null : Math.round((settleFrame - lastTargetFrame) * RENDER_DT * 1000),
    overshootM: round(overshoot),
  };
}

for (const path of process.argv.slice(2)) {
  const samples = readFileSync(path, 'utf8').split('\n').filter(Boolean).map(line => JSON.parse(line))
    .map(sample => ({t: sample.t / 1000, pose: {x: sample.pose[0], z: sample.pose[2]}}));
  let travelled = 0, movingMs = 0;
  for (let index = 1; index < samples.length; index++) {
    const distance = Math.hypot(samples[index].pose.x - samples[index - 1].pose.x,
      samples[index].pose.z - samples[index - 1].pose.z);
    if (distance > 1e-6) movingMs += (samples[index].t - samples[index - 1].t) * 1000;
    travelled += distance;
  }
  const meanSpeed = travelled / Math.max(0.001, movingMs / 1000);
  const decimated = samples.filter((_, index) => index % 3 === 0);
  for (const [label, series] of [['60Hz', samples], ['20Hz-decimated', decimated]]) {
    const hz = series.length / (series[series.length - 1].t - series[0].t);
    console.log(JSON.stringify({path, cadence: label, hz: round(hz), samples: series.length,
      meanSpeedMps: round(meanSpeed), configs: {
        direct: evaluate(series, 0),
        catchUp20ms: evaluate(series, 0.02),
        catchUp50ms: evaluate(series, 0.05),
      }}, null, 2));
  }
}

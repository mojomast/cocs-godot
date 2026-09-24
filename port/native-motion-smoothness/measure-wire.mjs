// Wire-level snapshot cadence and authority CPU measurement.
//
// Answers: at what real interval does the port-owned native authority emit
// `snapshot` frames, and what does that cost the authority process?
//
// Run from the repository root:
//   node port/native-motion-smoothness/measure-wire.mjs --bots=2 --seconds=8
//
// The authority runs in a forked child (authority-child.mjs) and reports its
// own process.cpuUsage(); the parent only drives a real WebSocket client at
// 60 Hz. Output is one JSON object on stdout.
import {fork} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, join} from 'node:path';
import {WebSocket} from 'ws';

const here = dirname(fileURLToPath(import.meta.url));
const options = Object.fromEntries(process.argv.slice(2).map(arg => {
  const [key, value] = arg.replace(/^--/, '').split('=');
  return [key, value ?? 'true'];
}));
const bots = Number(options.bots ?? 2);
const seconds = Number(options.seconds ?? 8);
const mapId = options.map ?? 'prism-foundry';
const driveHz = Number(options.drive ?? 60);

const child = fork(join(here, 'authority-child.mjs'), [mapId, String(bots), String(Math.max(60, Math.ceil(seconds) + 10)), '1'], {stdio: 'ignore'});
const ready = await new Promise((resolve, reject) => {
  child.once('message', resolve);
  child.once('exit', code => reject(new Error(`Authority child exited early: ${code}`)));
});
const {endpoint} = ready;

const ws = new WebSocket(endpoint);
const frames = [];
const snapshotArrivals = [];
const sendTimes = [];
ws.on('message', bytes => {
  const now = performance.now();
  const frame = {...JSON.parse(String(bytes)), bytes: bytes.length, at: now};
  frames.push(frame);
  if (frame.type === 'snapshot') {
    const actor = frame.state?.actors?.find(candidate => candidate.id === 0) ?? {};
    snapshotArrivals.push({...frame, pose: [actor.x, actor.y, actor.z], x: actor.x, z: actor.z});
  }
});
await new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); });
ws.on('error', () => {});
const send = frame => ws.send(JSON.stringify(frame));
const waitFor = async (predicate, timeout = 10000) => {
  const deadline = performance.now() + timeout;
  for (;;) {
    const found = frames.find(predicate);
    if (found) return found;
    if (performance.now() > deadline) throw new Error(`frame timeout; recent: ${frames.slice(-6).map(f => f.type)}`);
    await new Promise(resolve => setTimeout(resolve, 5));
  }
};

// Complete the documented v3 lifecycle.
send({type: 'create', v: 3, delta: 0, nativeArenaInput: 1});
await waitFor(entry => entry.type === 'welcome');
await waitFor(entry => entry.type === 'lobby');
send({type: 'host', mapId, config: {mode: 'deathmatch', botCount: bots, timeLimit: 60, fragLimit: 50}});
await waitFor(entry => entry.type === 'lobby' && entry.config);
send({type: 'start'});
const startFrame = await waitFor(entry => entry.type === 'start');
const inputEpoch = startFrame.inputEpoch;
child.send('begin');
await new Promise(resolve => child.once('message', message => message.type === 'begun' && resolve()));
const startedAt = performance.now();
sendTimes.push({at: startedAt, type: 'start'});

let seq = 0;
let tick = 0;
const driver = setInterval(() => {
  if (ws.readyState !== WebSocket.OPEN) return;
  // Ordinary movement input: forward, stop, strafe, stop. The stop phases give
  // the smoothing evaluation a real deceleration/standstill to settle into.
  const phase = tick++ % 240;
  const forward = phase < 72, strafe = phase >= 120 && phase < 192;
  const input = {x: strafe ? 1 : 0, z: forward ? 1 : 0, yaw: 0, pitch: 0,
    weapon: 0, fire: false, jump: false, power: false, interact: false,
    sprint: false, crouch: false, ads: false, reload: false, melee: false,
    grenade: false, mobility: false, altFire: false};
  send({type: 'input', seq: ++seq, input, inputEpoch});
}, 1000 / driveHz);

await new Promise(resolve => setTimeout(resolve, seconds * 1000));
clearInterval(driver);
const stoppedAt = performance.now();
child.send('stop');
const cpu = await new Promise(resolve => child.once('message', resolve));

const snapshotTimes = snapshotArrivals.map(entry => entry.at);
const firstAt = snapshotTimes.length ? snapshotTimes[0] : stoppedAt;
const lastAt = snapshotTimes.length ? snapshotTimes[snapshotTimes.length - 1] : stoppedAt;
const windowSeconds = (lastAt - firstAt) / 1000;
const intervals = snapshotTimes.slice(1).map((at, index) => at - snapshotTimes[index]);
const mean = values => values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : 0;
const percentile = (values, ratio) => {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(ratio * sorted.length))];
};
const round = value => Math.round(value * 1000) / 1000;
const summary = {
  label: options.label ?? null, map: mapId, bots, seconds, driveHz,
  endpointPort: ready.port,
  wallSeconds: round((stoppedAt - startedAt) / 1000),
  windowSeconds: round(windowSeconds),
  snapshots: snapshotTimes.length,
  snapshotsPerSecond: round(snapshotTimes.length / Math.max(0.001, windowSeconds)),
  intervalMs: {
    mean: round(mean(intervals)), p50: round(percentile(intervals, 0.5)),
    p95: round(percentile(intervals, 0.95)), p99: round(percentile(intervals, 0.99)),
    min: round(Math.min(...intervals)), max: round(Math.max(...intervals)),
  },
  // A "step" is a snapshot arriving more than half a 60 Hz tick after the
  // previous one; distinct gaps estimate how often the local camera moves on a
  // render clock faster than the snapshot clock.
  distinctIntervals: intervals.filter(value => value > 8.34).length,
  frameBytes: {
    mean: Math.round(mean(snapshotArrivals.map(entry => entry.bytes))),
    max: Math.max(...snapshotArrivals.map(entry => entry.bytes)),
  },
  authorityCpu: {
    userMs: round(cpu.usage.user / 1000), systemMs: round(cpu.usage.system / 1000),
    windowSeconds: round(cpu.endedUptime - cpu.beginUptime),
    cpuMsPerSecond: round((cpu.usage.user + cpu.usage.system) / 1000 /
      Math.max(0.001, cpu.endedUptime - cpu.beginUptime)),
    counts: cpu.counts,
  },
  clientInputs: seq,
  snapshotsPerInput: round(snapshotTimes.length / Math.max(1, seq)),
};
console.log(JSON.stringify(summary, null, 2));
if (options['pose-out']) {
  writeFileSync(options['pose-out'], snapshotArrivals.map(entry =>
    JSON.stringify({t: Math.round(entry.at * 1000) / 1000, seq: entry.seq, pose: entry.pose})).join('\n') + '\n');
}
ws.close();
child.kill('SIGKILL');

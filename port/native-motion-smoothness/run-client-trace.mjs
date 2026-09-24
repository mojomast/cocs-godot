// End-to-end local-camera trace: a real native-arena authority plus the real
// Godot native-DM client, captured through the existing --native-trace channel.
//
// The trace records the authoritative camera position at every applied snapshot,
// so consecutive records expose exactly how often on-screen translation moves.
//
// Modes:
//   --mode=smoke      the route's own smoke stimulus (holds W, fires) and quits
//                     on success; the trace covers real translation.
//   --mode=autostart  a live round with neutral input; records the raw snapshot
//                     cadence for --run-seconds. Default.
//
// Rendering:
//   --rendering=headless  Godot --headless (default; no rasterizer)
//   --rendering=xvfb      private Xvfb + gl_compatibility (llvmpipe), matching
//                         the route's own graphical capture environment
//
// Run from the repository root:
//   node port/native-motion-smoothness/run-client-trace.mjs --bots=2 --out=<file>
import {fork, spawn} from 'node:child_process';
import {createWriteStream, mkdirSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..');
const options = Object.fromEntries(process.argv.slice(2).map(arg => {
  const [key, value] = arg.replace(/^--/, '').split('=');
  return [key, value ?? 'true'];
}));
const bots = Number(options.bots ?? 2);
const runSeconds = Number(options['run-seconds'] ?? 20);
const mode = options.mode ?? 'autostart';
const rendering = options.rendering ?? 'headless';
if (!['smoke', 'autostart'].includes(mode)) throw new Error('mode must be smoke or autostart');
if (!['headless', 'xvfb'].includes(rendering)) throw new Error('rendering must be headless or xvfb');
const binary = process.env.GODOT_BIN;
if (!binary) throw new Error('Set GODOT_BIN to the pinned Godot editor');
const outPath = resolve(options.out ?? join(root, 'port/native-motion-smoothness/evidence/client-trace.jsonl'));
mkdirSync(dirname(outPath), {recursive: true});

const authority = fork(join(here, 'authority-child.mjs'),
  ['prism-foundry', String(bots), String(Math.max(60, runSeconds + 20)), '2'], {stdio: 'ignore'});
const {endpoint} = await new Promise((resolve, reject) => {
  authority.once('message', resolve);
  authority.once('exit', code => reject(new Error(`authority exited early: ${code}`)));
});

const clientArgs = ['--path', 'godot', ...(rendering === 'headless'
  ? ['--headless', '--audio-driver', 'Dummy']
  : ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy']),
  'res://native_arenas/demo.tscn', '--',
  `--endpoint=${endpoint}`, '--native-trace', mode === 'smoke' ? '--smoke' : '--autostart'];
const command = rendering === 'xvfb'
  ? ['python3', join(root, 'tools/godot-dev/xvfb_run.py'), binary, ...clientArgs]
  : [binary, ...clientArgs];
const child = spawn(command[0], command.slice(1), {cwd: root, detached: true, stdio: ['ignore', 'pipe', 'pipe']});
const killClient = () => {
  try { process.kill(-child.pid, 'SIGKILL'); } catch {}
  try { child.kill('SIGKILL'); } catch {}
};
const out = createWriteStream(outPath, {flags: 'w'});
const records = [];
const stdoutChunks = [], stderrChunks = [];
const onChunk = (chunk, sink) => {
  const text = chunk.toString();
  sink.push(text);
  for (const line of text.split('\n')) {
    if (!line.startsWith('PORT_NATIVE_TRACE ')) continue;
    try {
      const record = JSON.parse(line.slice('PORT_NATIVE_TRACE '.length));
      records.push(record);
      out.write(JSON.stringify(record) + '\n');
    } catch {}
  }
};
child.stdout.on('data', chunk => onChunk(chunk, stdoutChunks));
child.stderr.on('data', chunk => onChunk(chunk, stderrChunks));
let timedOut = false;
const exitCode = await new Promise(resolve => {
  const timer = setTimeout(() => { timedOut = true; killClient(); }, runSeconds * 1000);
  child.once('error', () => { clearTimeout(timer); resolve(-1); });
  child.once('exit', code => { clearTimeout(timer); resolve(code ?? 0); });
});
const stdout = stdoutChunks.join(''), stderr = stderrChunks.join('');
const snapshots = records.filter(record => record.event === 'snapshot');
authority.send('stop');
const cpu = await new Promise(resolve => authority.once('message', resolve));
console.log(JSON.stringify({
  out: outPath, mode, rendering, exitCode, timedOut, bots,
  smokeOk: stdout.includes('NATIVE_DM_SMOKE_OK'),
  traceRecords: records.length, snapshotRecords: snapshots.length,
  firstCamera: snapshots[0]?.camera_position ?? null,
  lastCamera: snapshots[snapshots.length - 1]?.camera_position ?? null,
  authorityCpu: {userMs: Math.round(cpu.usage.user / 1000), systemMs: Math.round(cpu.usage.system / 1000),
    windowSeconds: Math.round((cpu.endedUptime - cpu.beginUptime) * 1000) / 1000,
    cpuMsPerSecond: Math.round((cpu.usage.user + cpu.usage.system) / 1000 /
      Math.max(0.001, cpu.endedUptime - cpu.beginUptime)),
    counts: cpu.counts},
  errors: stderr.split('\n').filter(line => line.includes('ERROR')).slice(0, 5),
}, null, 2));
out.end();
killClient();
process.exit(0);

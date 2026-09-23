// Rendered live blood check on the real native Deathmatch composition.
//
// Starts a real authority with the debug channel, runs the actual demo scene under
// a private Xvfb display, forces real source damage events on the local seat, and
// asserts the blood controller's own counters. Evidence: the counter report, the
// Godot logs and one rendered frame.
//
// This harness owns its own deadline because the gate that runs it
// (tools/godot-dev/verify.py -> gate_runner.run_gate) SIGKILLs the whole process
// group at 180 s: anything still alive then is destroyed without a trace. The budget
// below must stay strictly inside that window, and every exit path must flush the
// evidence first, so a broken run still reports why it broke.
//
// Usage: GODOT_BIN=<pinned Godot> node port/native-blood-fx/live.mjs
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';

const root = resolve(import.meta.dirname, '../..');
const binary = process.env.GODOT_BIN;
if (!binary) throw Error('Set GODOT_BIN to the pinned Godot 4.5.2 executable');
const lock = JSON.parse(readFileSync(resolve(root, 'port/contracts/source-lock.json')));
if (execFileSync(binary, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) {
  throw Error('Godot version differs from the lock');
}
// Outer gate budget (gate_runner.run_gate default) and the harness deadline that must
// beat it. The override exists so the bounded-failure path can be tested; it can never
// be raised to the gate's own budget.
const GATE_BUDGET_MS = 180000;
const DEFAULT_BUDGET_MS = 150000;
const budget = process.env.BLOOD_LIVE_BUDGET_MS === undefined ? DEFAULT_BUDGET_MS
  : Number(process.env.BLOOD_LIVE_BUDGET_MS);
if (!Number.isInteger(budget) || budget < 1000 || budget >= GATE_BUDGET_MS) {
  throw Error(`BLOOD_LIVE_BUDGET_MS must be an integer in 1000..${GATE_BUDGET_MS - 1};`
    + ` the gate kills the process group at ${GATE_BUDGET_MS}`);
}
// A composition that fails to compile spins on runtime errors instead of reaching the
// scene's own fail guards, so it is reported the moment the engine says so rather than
// after the whole budget.
const COMPILE_BREAK = /SCRIPT ERROR: (Parse Error|Compile Error)|Failed to load script/;
function huntArgs() {
  const flag = process.argv.find(value => value === '--hunt' || value.startsWith('--hunt='));
  if (!flag) return ['--hits=5'];
  const count = flag.includes('=') ? Number(flag.split('=')[1]) : 3;
  if (!Number.isInteger(count) || count < 1 || count > 40) throw Error('--hunt=<1..40>');
  return [`--hunt=${count}`];
}
const evidence = resolve(root, 'port/native-blood-fx/evidence', `live-${Date.now()}`);
mkdirSync(evidence, {recursive:true});
const png = resolve(evidence, 'live-native-dm.png');
let stdout = '', stderr = '', reported = false;
const tail = text => text.length > 1200 ? text.slice(-1200) : text;
function flush(summary) {
  writeFileSync(resolve(evidence, 'stdout.log'), stdout);
  writeFileSync(resolve(evidence, 'stderr.log'), stderr);
  writeFileSync(resolve(evidence, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
  reported = true;
  console.log(JSON.stringify(summary));
  return summary;
}

const authority = await createNativeArenaAuthority({port:0, host:'127.0.0.1', mapId:'prism-foundry',
  mode:'deathmatch', bots:2, roundSeconds:180, debug:true});
const display = spawn('Xvfb', ['-displayfd', '3', '-screen', '0', '1280x800x24',
  '-nolisten', 'tcp', '-nolisten', 'unix'], {stdio:['ignore', 'ignore', 'pipe', 'pipe']});
const displayNumber = await new Promise((resolveDisplay, reject) => {
  let text = '';
  const timer = setTimeout(() => reject(Error('Xvfb display readiness timeout')), 8000);
  display.stdio[3].on('data', chunk => {
    text += chunk;
    if (/^\d+\n$/.test(text)) { clearTimeout(timer); resolveDisplay(text.trim()); }
  });
  display.once('exit', () => { clearTimeout(timer); reject(Error('Xvfb exited early')); });
});
const env = {...process.env, DISPLAY:`:${displayNumber}`};
let child;
try {
  child = spawn(binary, ['--path', 'godot', '--resolution', '1280x800',
    '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
    '--script', 'res://tests/blood_fx/live_native.gd', '--',
    '--map=prism-foundry', '--mode=deathmatch', '--bots=2', '--round-seconds=180', '--autostart',
    '--endpoint=' + authority.endpoint, `--capture=${png}`,
    ...huntArgs()],
    {cwd:root, env, stdio:['ignore', 'pipe', 'pipe']});
  child.stdout.on('data', chunk => { stdout += chunk; });
  child.stderr.on('data', chunk => { stderr += chunk; });
  const code = await new Promise((resolveExit, reject) => {
    let settled = false, timer = null;
    const fail = (reason, message) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
      reject(Object.assign(Error(message), {reason}));
    };
    timer = setTimeout(() => fail('timeout', `live blood check exceeded its ${budget} ms budget`), budget);
    const watch = () => {
      if (COMPILE_BREAK.test(stdout + stderr)) {
        fail('compile-error', 'native arena composition failed to compile');
      }
    };
    child.stdout.on('data', watch);
    child.stderr.on('data', watch);
    child.once('error', error => {
      if (settled) return;
      settled = true; clearTimeout(timer); reject(error);
    });
    child.once('exit', value => {
      if (settled) return;
      settled = true; clearTimeout(timer); resolveExit(value ?? 1);
    });
  });
  const ok = stdout.split('\n').find(line => line.startsWith('BLOOD_LIVE_OK '));
  const failed = stdout.split('\n').find(line => line.startsWith('BLOOD_LIVE_FAILED '));
  const report = ok ? JSON.parse(ok.slice('BLOOD_LIVE_OK '.length))
    : failed ? JSON.parse(failed.slice('BLOOD_LIVE_FAILED '.length)) : null;
  const errors = /(SCRIPT ERROR|Parse Error|ERROR:)/.test(stdout + stderr);
  const passed = Boolean(ok) && code === 0 && !errors;
  const summary = {godot:lock.godot_version, exit_code:code, status:passed ? 'passed' : 'failed',
    failure_reason:passed ? null : (errors ? 'engine-error' : (code !== 0 ? 'nonzero-exit' : 'scene-reported-failure')), report, capture:png,
    errors, budget_ms:budget};
  flush(summary);
  if (!passed) throw Error(`live blood check failed (${JSON.stringify(summary)})`);
} catch (error) {
  if (!reported) {
    flush({godot:lock.godot_version, exit_code:child?.exitCode ?? null, status:'failed',
      failure_reason:error.reason ?? 'harness-error', report:null, capture:png,
      errors:/(SCRIPT ERROR|Parse Error)/.test(stdout + stderr), budget_ms:budget,
      message:error.message, stdout_tail:tail(stdout), stderr_tail:tail(stderr)});
  }
  throw error;
} finally {
  if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
  await authority.close();
  display.kill('SIGTERM');
}

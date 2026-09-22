// Rendered live blood check on the real native Deathmatch composition.
//
// Starts a real authority with the debug channel, runs the actual demo scene under
// a private Xvfb display, forces real source damage events on the local seat, and
// asserts the blood controller's own counters. Evidence: the counter report, the
// Godot logs and one rendered frame.
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
let stdout = '', stderr = '';
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
    const timer = setTimeout(() => { child.kill('SIGKILL'); reject(Error('blood check timed out')); }, 180000);
    child.once('error', reject);
    child.once('exit', value => { clearTimeout(timer); resolveExit(value ?? 1); });
  });
  writeFileSync(resolve(evidence, 'stdout.log'), stdout);
  writeFileSync(resolve(evidence, 'stderr.log'), stderr);
  const ok = stdout.split('\n').find(line => line.startsWith('BLOOD_LIVE_OK '));
  const failed = stdout.split('\n').find(line => line.startsWith('BLOOD_LIVE_FAILED '));
  const report = ok ? JSON.parse(ok.slice('BLOOD_LIVE_OK '.length))
    : failed ? JSON.parse(failed.slice('BLOOD_LIVE_FAILED '.length)) : null;
  const summary = {godot:lock.godot_version, exit_code:code, status:ok ? 'passed' : 'failed', report,
    capture:png, errors:/(SCRIPT ERROR|Parse Error)/.test(stdout + stderr)};
  writeFileSync(resolve(evidence, 'summary.json'), JSON.stringify(summary, null, 2) + '\n');
  console.log(JSON.stringify(summary));
  if (!ok) throw Error(`live blood check failed (${JSON.stringify(summary)})`);
} finally {
  if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
  await authority.close();
  display.kill('SIGTERM');
}

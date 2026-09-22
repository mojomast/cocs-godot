// Rendered evidence for the debug panel: a real local authority + the real
// native Deathmatch route under a private Xvfb display. The panel's capture flag
// enables god mode and a 2x damage multiplier through its own debug frames, so
// the image shows the live knobs, not a mock-up.
//
// Usage: GODOT_BIN=<pinned Godot> node port/native-debug/capture.mjs [--verify-only]
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';

const root = resolve(import.meta.dirname, '../..');
const binary = process.env.GODOT_BIN;
if (!binary) throw Error('Set GODOT_BIN to the pinned Godot 4.5.2 executable');
const lock = JSON.parse(readFileSync(resolve(root, 'port/contracts/source-lock.json')));
if (execFileSync(binary, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) {
  throw Error('Godot version differs from the lock');
}
const evidence = resolve(root, 'port/native-debug/evidence', `capture-${Date.now()}`);
mkdirSync(evidence, {recursive:true});
const SLEEP = ms => new Promise(resolve => setTimeout(resolve, ms));

async function capture(width, height) {
  const authority = await createNativeArenaAuthority({port:0, host:'127.0.0.1', mapId:'prism-foundry',
    mode:'deathmatch', bots:2, roundSeconds:180, debug:true});
  const display = spawn('Xvfb', ['-displayfd', '3', '-screen', '0', `${width}x${height}x24`,
    '-nolisten', 'tcp', '-nolisten', 'unix'], {stdio:['ignore', 'ignore', 'pipe', 'pipe']});
  const displayNumber = await new Promise((resolve, reject) => {
    let text = '';
    const timer = setTimeout(() => reject(Error('Xvfb display readiness timeout')), 8000);
    display.stdio[3].on('data', chunk => {
      text += chunk;
      if (/^\d+\n$/.test(text)) { clearTimeout(timer); resolve(text.trim()); }
    });
    display.once('exit', () => { clearTimeout(timer); reject(Error('Xvfb exited early')); });
  });
  const png = resolve(evidence, `debug-panel-${width}x${height}.png`);
  const runtime = mkdtempSync(resolve(tmpdir(), 'cocs-debug-capture-'));
  const env = {...process.env, DISPLAY:`:${displayNumber}`,
    XDG_DATA_HOME:resolve(runtime, 'data'), XDG_CONFIG_HOME:resolve(runtime, 'config'),
    XDG_CACHE_HOME:resolve(runtime, 'cache'), COCS_DEBUG:'1'};
  for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) mkdirSync(env[key], {recursive:true});
  const args = ['--path', 'godot', '--resolution', `${width}x${height}`,
    '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
    'res://native_arenas/demo.tscn', '--',
    '--map=prism-foundry', '--mode=deathmatch', '--bots=2', '--round-seconds=180', '--autostart',
    '--endpoint=' + authority.endpoint, '--debug-panel',
    `--debug-capture=${png}`, '--debug-capture-delay=3.0'];
  let stdout = '', stderr = '';
  let child;
  try {
    child = spawn(binary, args, {env, stdio:['ignore', 'pipe', 'pipe']});
    child.stdout.on('data', chunk => { stdout += chunk; });
    child.stderr.on('data', chunk => { stderr += chunk; });
    const code = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { child.kill('SIGKILL'); reject(Error('capture timed out')); }, 120000);
      child.once('error', reject);
      child.once('exit', value => { clearTimeout(timer); resolve(value ?? 1); });
    });
    const panelLine = stdout.split('\n').find(line => line.startsWith('DEBUG_PANEL_CAPTURE '));
    const bytes = existsSync(png) ? readFileSync(png).length : 0;
    writeFileSync(resolve(evidence, `capture-${width}x${height}.stdout.log`), stdout);
    writeFileSync(resolve(evidence, `capture-${width}x${height}.stderr.log`), stderr);
    return {width, height, code, png:`port/native-debug/evidence/${png.split('/evidence/')[1]}`,
      bytes, panel:panelLine ? JSON.parse(panelLine.slice('DEBUG_PANEL_CAPTURE '.length)) : null,
      rounds:(stdout.match(/DEBUG_PANEL_ROUND /g) ?? []).length,
      stimulus:(stdout.match(/DEBUG_PANEL_STIMULUS /g) ?? []).length,
      errors:/(SCRIPT ERROR|Parse Error|ERROR:)/.test(stdout + stderr)};
  } finally {
    if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    await authority.close();
    display.kill('SIGTERM');
    rmSync(runtime, {recursive:true, force:true, maxRetries:5, retryDelay:100});
  }
}

const results = [];
for (const [width, height] of [[960, 640], [1280, 800]]) {
  const result = await capture(width, height);
  results.push(result);
  console.log('capture', `${width}x${height}`, JSON.stringify(result));
  if (result.code !== 0 || result.bytes < 10000 || result.errors || !result.panel || result.panel.size[0] !== width) {
    throw Error(`capture ${width}x${height} failed (${JSON.stringify(result)})`);
  }
}
writeFileSync(resolve(evidence, 'summary.json'), JSON.stringify({godot:lock.godot_version, results,
  command:'COCS_DEBUG=1 GODOT_BIN=<pinned> node port/native-debug/capture.mjs'}, null, 2));
console.log('evidence:', resolve(evidence));

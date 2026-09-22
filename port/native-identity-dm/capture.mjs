// Identity Deathmatch capture runner (route/package lane).
//
// Starts a private Xvfb display, owns the same Node loopback authority the
// native-dm launcher uses, runs the real native Deathmatch scene with ordinary
// input, and records real framebuffer PNGs at each requested size.
//
//   node port/native-identity-dm/capture.mjs --map=lacuna-court
//
// Evidence lands under port/native-identity-dm/captures/<map>-<stamp>/.
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, writeFileSync, createWriteStream, existsSync, readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const GODOT = process.env.GODOT_BIN ?? '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const options = {};
for (const arg of process.argv.slice(2)) {
  const match = /^--([a-z-]+)=(.*)$/.exec(arg);
  if (match) options[match[1]] = match[2];
}
const mapId = options.map ?? 'lacuna-court';
const bots = Number(options.bots ?? 3);
const roundSeconds = Number(options['round-seconds'] ?? 180);
const sizes = options.sizes ?? '960x640,1280x800';
const menu = process.argv.includes('--menu');
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const captureRoot = resolve(options['capture-root'] ?? `${ROOT}/port/native-identity-dm/captures/${mapId}-${stamp}`);
mkdirSync(captureRoot, {recursive: true});
for (const name of ['data', 'config', 'cache']) mkdirSync(`${captureRoot}/home/${name}`, {recursive: true});

function freeDisplay() {
  for (let number = 90; number < 130; number++) {
    if (!existsSync(`/tmp/.X11-unix/X${number}`)) return number;
  }
  throw Error('No free private X display');
}
const display = freeDisplay();
const xvfb = spawn('Xvfb', [`:${display}`, '-screen', '0', '1920x1080x24', '-nolisten', 'tcp'],
  {stdio: ['ignore', 'pipe', 'pipe']});
const xvfbLog = [];
for (const stream of [xvfb.stdout, xvfb.stderr]) stream.on('data', data => xvfbLog.push(String(data)));
await new Promise(resolve => setTimeout(resolve, 800));

const lock = JSON.parse(readFileSync(`${ROOT}/port/contracts/source-lock.json`, 'utf8'));
if (execFileSync(GODOT, ['--version'], {encoding: 'utf8'}).trim() !== lock.godot_version) {
  throw Error('Godot version differs from the pinned source lock');
}

const authority = await createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId, mode: 'deathmatch', bots, roundSeconds});
const health = await (await fetch(`http://127.0.0.1:${authority.port}`)).json();
const logPath = `${captureRoot}/godot.log`;
const logStream = createWriteStream(logPath);
let log = '';
const args = ['--path', 'godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
  '--script', 'res://native_arenas/capture.gd', '--',
  `--map=${mapId}`, `--endpoint=${authority.endpoint}`, `--bots=${bots}`, `--round-seconds=${roundSeconds}`,
  ...(menu ? ['--capture-menu'] : ['--autostart']), `--capture-root=${captureRoot}`, `--sizes=${sizes}`];
const child = spawn(GODOT, args, {cwd: ROOT, env: {...process.env, DISPLAY: `:${display}`,
  HOME: `${captureRoot}/home`, XDG_DATA_HOME: `${captureRoot}/home/data`, XDG_CONFIG_HOME: `${captureRoot}/home/config`,
  XDG_CACHE_HOME: `${captureRoot}/home/cache`}, stdio: ['ignore', 'pipe', 'pipe']});
for (const stream of [child.stdout, child.stderr]) stream.on('data', data => {log += data; logStream.write(data);});
const timeout = setTimeout(() => child.kill('SIGKILL'), 300000);
const exitCode = await new Promise(resolve => child.on('exit', code => resolve(code)));
clearTimeout(timeout);
logStream.end();
await authority.close();
xvfb.kill('SIGTERM');
await new Promise(resolve => setTimeout(resolve, 300));
if (xvfb.exitCode === null) xvfb.kill('SIGKILL');

const captures = log.split(/\r?\n/).filter(line => line.startsWith('NATIVE_DM_CAPTURE '))
  .map(line => JSON.parse(line.slice('NATIVE_DM_CAPTURE '.length)));
const summary = {mapId, mode: menu ? 'deathmatch-setup' : 'deathmatch', bots, roundSeconds, sizes,
  geometryHash: health.geometryHash, authorityPort: authority.port, exitCode, captureRoot, captures,
  passed: exitCode === 0 && captures.length >= (menu ? 1 : 2) && !/SCRIPT ERROR|ERROR:/.test(log)};
writeFileSync(`${captureRoot}/summary.json`, `${JSON.stringify({...summary, logTail: log.slice(-4000)}, null, 2)}\n`);
writeFileSync(`${captureRoot}/xvfb.log`, xvfbLog.join(''));
console.log(JSON.stringify(summary));
if (!summary.passed) process.exitCode = 1;

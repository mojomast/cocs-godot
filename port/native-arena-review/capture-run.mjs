// Review-lane graphical session runner: real Node authority (the same factory
// the native-dm launcher uses) plus the delivered native DM scene under a
// private Xvfb display, capturing 960x640 and 1280x800 frames.
//
// Usage:
//   DISPLAY=:97 XAUTHORITY=/tmp/... node port/native-arena-review/capture-run.mjs \
//     --map=prism-foundry --bots=3 --round-seconds=180
//
// Writes images + logs under port/native-arena-review/captures/<stamp>/.
import {spawn} from 'node:child_process';
import {mkdirSync, writeFileSync, createWriteStream} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const GODOT = process.env.GODOT_BIN ?? '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const opts = {};
for (const arg of process.argv.slice(2)) {
  const m = /^--([a-z-]+)=(.*)$/.exec(arg);
  if (m) opts[m[1]] = m[2];
}
const mapId = opts.map ?? 'prism-foundry';
const bots = Number(opts.bots ?? 3);
const roundSeconds = Number(opts['round-seconds'] ?? 180);
const sizes = opts.sizes ?? '960x640,1280x800';
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const captureRoot = `${ROOT}/port/native-arena-review/captures/${mapId}-${stamp}`;
mkdirSync(captureRoot, {recursive: true});

const authority = await createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId, mode: 'deathmatch', bots, roundSeconds});
const endpoint = authority.endpoint;
const health = await (await fetch(`http://127.0.0.1:${authority.port}`)).json();
console.log(JSON.stringify({stage: 'authority', endpoint, health: {localOnly: health.localOnly, mapId: health.mapId,
  geometryHash: health.geometryHash, navNodes: health.navNodes, v: health.v}}));

const args = ['--path', 'godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
  '--script', 'res://tests/native_arena_review/capture_review.gd', '--',
  `--map=${mapId}`, `--endpoint=${endpoint}`, `--bots=${bots}`, `--round-seconds=${roundSeconds}`,
  '--autostart', `--capture-root=${captureRoot}`, `--sizes=${sizes}`];
const logPath = `${captureRoot}/godot.log`;
const log = createWriteStream(logPath);
const child = spawn(GODOT, args, {env: {...process.env}, stdio: ['ignore', 'pipe', 'pipe']});
child.stdout.pipe(log);
child.stderr.pipe(log);
const timeout = setTimeout(() => { console.error('capture timeout; terminating'); child.kill('SIGKILL'); }, 240000);
const code = await new Promise(resolve => child.on('exit', resolve));
clearTimeout(timeout);
log.end();
await authority.close();
const summary = {mapId, bots, roundSeconds, sizes, endpoint, captureRoot, exitCode: code, geometryHash: health.geometryHash};
writeFileSync(`${captureRoot}/summary.json`, `${JSON.stringify(summary, null, 2)}\n`);
console.log(JSON.stringify({stage: 'done', ...summary}));
if (code !== 0) process.exitCode = 1;

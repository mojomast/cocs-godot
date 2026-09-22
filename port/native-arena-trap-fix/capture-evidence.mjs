// Post-fix evidence capture (trap-fix lane).
//
// Starts the real native DM authority, runs the pinned Godot under a private
// Xvfb at the requested sizes, saves the PNGs plus the capture log, and
// asserts the delivered PNG dimensions and geometry hashes. Software rendering
// (llvmpipe) is recorded in the log line and echoed in the summary.
import {spawn} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {createAuthority} from '../native-arenas/authority.mjs';
import {readNativeArena} from '../native-arenas/schema.mjs';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const godot = '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const outDir = `${ROOT}/port/native-arena-trap-fix/evidence`;
const captureRoot = `${outDir}/raw`;
fs.mkdirSync(captureRoot, {recursive: true});
const plan = JSON.parse(process.argv[2] ?? '[]');

function pngSize(file) {
  const buffer = fs.readFileSync(file);
  if (buffer.readUInt32BE(0) !== 0x89504e47) throw new Error(`${file} is not a PNG`);
  return {width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20)};
}

const summary = [];
for (const {mapId, sizes} of plan) {
  const data = readNativeArena(mapId);
  let seed = 71027;
  const random = () => ((seed = Math.imul(seed, 1664525) + 1013904223 >>> 0) / 4294967296);
  const resets = [];
  const authority = createAuthority({mapId, botCount: 5, timeLimit: 300, difficulty: 'easy', random,
    observe: event => { if (event.direction === 'control-reset') resets.push({reason: event.reason, epoch: event.inputEpoch}); }});
  await new Promise(resolve => authority.server.listen(0, '127.0.0.1', resolve));
  const endpoint = `ws://127.0.0.1:${authority.server.address().port}/native-arenas`;
  const args = ['-a', '-s', '-screen 0 1920x1080x24', godot, '--path', 'godot', '--audio-driver', 'Dummy',
    '--rendering-method', 'gl_compatibility', '--script', 'res://tests/native_arenas/geometry/capture.gd', '--',
    `--map=${mapId}`, `--endpoint=${endpoint}`, '--bots=5', '--round-seconds=300', '--autostart',
    `--capture-root=${captureRoot}`, `--capture-sizes=${sizes.join(',')}`];
  const logPath = `${captureRoot}/${mapId}.log`;
  const log = fs.createWriteStream(logPath);
  const child = spawn('xvfb-run', args, {stdio: ['ignore', 'pipe', 'pipe'], env: {...process.env, LP_NUM_THREADS: '8'}});
  child.stdout.pipe(log); child.stderr.pipe(log);
  const code = await new Promise(resolve => child.on('exit', resolve));
  log.end(); await authority.close();
  fs.writeFileSync(`${captureRoot}/${mapId}-controls.json`, `${JSON.stringify({resets}, null, 2)}\n`);
  const captures = fs.readFileSync(logPath, 'utf8').split('\n').filter(l => l.includes('NATIVE_DM_GRAPHICAL_CAPTURE'))
    .map(l => JSON.parse(l.slice(l.indexOf('{'))));
  const images = captures.map(c => {
    const file = c.path;
    const size = pngSize(file);
    const ok = size.width === c.size[0] && size.height === c.size[1] && c.geometryHash === data.geometryHash && c.first_person === true;
    return {file, declared: c.size, actual: [size.width, size.height], geometryHash: c.geometryHash,
      eye: c.authoritative_eye, msaa: c.msaa, rendering_method: c.rendering_method, video_adapter: c.video_adapter, actors: c.actors, ok};
  });
  summary.push({mapId, exit: code, expectedHash: data.geometryHash, images});
  console.log(JSON.stringify({mapId, exit: code, hash: data.geometryHash.slice(0, 12), images: images.map(i => ({file: path.basename(i.file), actual: i.actual, hash: i.geometryHash.slice(0, 12), ok: i.ok}))}));
  if (code !== 0 || images.some(i => !i.ok) || images.length !== sizes.length) process.exitCode = 1;
}
fs.writeFileSync(`${outDir}/capture-summary.json`, `${JSON.stringify(summary, null, 2)}\n`);

// Identity-family Horde acceptance runner (Nacre Engine).
//
// Owns a private Xvfb display, the loopback-only Horde authority, the real
// product composition (res://native_arenas/identity_horde_demo.tscn through the
// test-only observer res://tests/horde/identity_live.tscn), and a bounded
// evidence directory. Nothing shared is touched: no package build, no launcher,
// no public room, no other lane's files.
//
//   GODOT_BIN=<pinned 4.5.2> node port/native-identity-horde/run.mjs --scenario=waves --waves=3
//
// Scenarios: startup (wave 1 with enemies), motion (held-W camera/source trace),
// waves (multi-wave combat and a
// legal wave-target victory), defeat (natural deaths to a real defeat and a
// clean restart), peak (clears as far as the bound allows and measures frame
// cadence at the highest simultaneous NPC count reached).
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync} from 'node:fs';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
import {createAuthority} from '../native-horde/authority.mjs';
import {IDENTITY_HORDE_MAP, traversalReport, nacreArena, measureNacre} from './measure.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const option = (key, fallback) => args.find(value => value.startsWith(key + '='))?.slice(key.length + 1) ?? fallback;
const scenario = option('--scenario', 'startup');
const selectedMap = option('--map', IDENTITY_HORDE_MAP);
const cinderwake = selectedMap === 'cinderwake-drydock';
if (selectedMap !== IDENTITY_HORDE_MAP && !cinderwake) throw Error('Unsupported Horde observer map');
// startup keeps the product default of ten waves so the default-ten contract is
// exercised on the identity composition too; it finishes at wave one.
const waves = Number(option('--waves', {startup: 10, motion: 10, waves: 3, stages: 6, defeat: 1, peak: 10}[scenario] ?? 1));
const resolution = option('--resolution', '1280x800');
const rendering = option('--rendering', '');
const RENDERING_METHODS = ['', 'gl_compatibility', 'mobile', 'forward_plus'];
const SCENARIOS = Object.freeze({startup: 95, motion: 65, waves: cinderwake ? 380 : 205,
  ...(cinderwake ? {stages: 380} : {}), defeat: 205, peak: 195});
// Full snapshots are retained for source/scene correlation; on the expanded
// seven-spawn Horde map a natural three-wave run can exceed 96 MiB of raw JSON
// while still well inside its 205-second deadline. Keep a finite bound.
// The staged route deliberately permits a longer ordinary-input attempt.
// Full source snapshots and event receipts for that bounded 355s run need a
// larger finite cap than the short Nacre fixture; compressed artifacts stay
// much smaller on disk, and this never changes simulation pacing.
const EVIDENCE_CAP = (cinderwake && ['waves','stages'].includes(scenario) ? 512 : 192) * 1024 * 1024;
if (!Object.hasOwn(SCENARIOS, scenario)) throw Error('Invalid scenario');
if (!Number.isInteger(waves) || waves < 1 || waves > 30) throw Error('waves must be 1..30');
if (!/^[0-9]{3,4}x[0-9]{3,4}$/.test(resolution)) throw Error('resolution must be WxH');
if (!RENDERING_METHODS.includes(rendering)) throw Error('unsupported rendering method');

const binary = process.env.GODOT_BIN;
const lock = JSON.parse(readFileSync(resolve(ROOT, 'port/contracts/source-lock.json'), 'utf8'));
if (!binary) throw Error('Pinned GODOT_BIN required');
if (execFileSync(binary, ['--version'], {encoding: 'utf8'}).trim() !== lock.godot_version) throw Error('GODOT_BIN differs from the source lock');

const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const out = resolve(ROOT, `port/native-identity-horde/evidence/${stamp}-${selectedMap}-${scenario}`);
mkdirSync(out, {recursive: true});
const temp = mkdtempSync('/tmp/opencode/identity-horde-runtime-');
const env = {...process.env};
for (const key of ['HOME', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']) {
  env[key] = resolve(temp, key);
  mkdirSync(env[key], {mode: 0o700});
}
const children = [];
let game, child, timer, stdout = '', stderr = '', wire = [], bytes = 0;
let reason = 'setup', exit = 1, stopping = false;
const startedAt = performance.now();

function tracked(command, argv, options) {
  const process_ = spawn(command, argv, options);
  children.push(process_);
  process_.done = new Promise((resolvePromise, reject) => {
    process_.once('error', reject);
    process_.once('exit', (code, signal) => resolvePromise({code, signal}));
  });
  return process_;
}
async function stop(process_) {
  if (process_.exitCode === null && process_.signalCode === null) {
    process_.kill('SIGTERM');
    const guard = setTimeout(() => process_.kill('SIGKILL'), 2500);
    await process_.done;
    clearTimeout(guard);
  }
}
const interrupted = () => { stopping = true; reason = 'interrupted'; if (child) void stop(child); };
process.on('SIGTERM', interrupted);
process.on('SIGINT', interrupted);

try {
  // Private display: -displayfd removes display-number guessing, and both
  // listener kinds are disabled so no other local client can attach.
  const display = tracked('Xvfb', ['-displayfd', '3', '-screen', '0', '1920x1080x24', '-nolisten', 'tcp', '-nolisten', 'unix'],
    {env, stdio: ['ignore', 'ignore', 'pipe', 'pipe']});
  const number = await Promise.race([
    new Promise(resolvePromise => {
      let text = '';
      display.stdio[3].on('data', chunk => {
        text += chunk;
        if (/^\d+\n$/.test(text)) resolvePromise(text.trim());
      });
    }),
    display.done.then(() => { throw Error('Xvfb exited before serving a display'); }),
    new Promise((_, reject) => { const t = setTimeout(() => reject(Error('display timeout')), 5000); t.unref(); }),
  ]);
  env.DISPLAY = ':' + number;

  game = createAuthority({observe(record) {
    const line = JSON.stringify(record);
    bytes += line.length;
    if (bytes > EVIDENCE_CAP) { reason = 'evidence cap'; void stop(child); return; }
    wire.push(line);
  }});
  game.server.on('error', () => { stopping = true; reason = 'authority server error'; if (child) void stop(child); });
  await new Promise((resolvePromise, reject) => {
    game.server.once('error', reject);
    game.server.listen(0, '127.0.0.1', resolvePromise);
  });
  const port = game.server.address().port;
  const endpoint = `ws://127.0.0.1:${port}`;
  const health = await (await fetch(endpoint.replace('ws:', 'http:'), {signal: AbortSignal.timeout(5000)})).json();
  if (health.service !== 'cocs-local-horde' || health.localOnly !== true || health.port !== port) throw Error('readiness failed');
  if (stopping) throw Error('Launch cancelled');

  const argv = ['--audio-driver', 'Dummy', ...(rendering ? ['--rendering-method', rendering] : []),
    '--resolution', resolution, '--path', 'godot',
    cinderwake ? 'res://tests/horde/cinderwake_live.tscn' : 'res://tests/horde/identity_live.tscn', '--',
    `--map=${selectedMap}`, `--endpoint=${endpoint}`, `--waves=${waves}`,
    '--horde-evidence', '--native-trace', `--scenario=${scenario}`, `--screenshot=${out}/gameplay.png`];
  const files = [
    'game/core.mjs', 'game/singleplayer.mjs', 'game/enemy-types.mjs', 'game/data.mjs',
    'game/config.mjs', 'game/input.mjs', 'game/protocol.mjs', 'game/bots.mjs', 'game/terrain.mjs', 'game/maps.mjs',
    'godot/native_arenas/identity_horde_demo.gd', 'godot/native_arenas/identity_horde_demo.tscn',
    'godot/identity_maps/map.gd', 'godot/identity_maps/style.gd',
    'godot/identity_maps/generated/nacre-engine.json', 'tools/godot-identity-maps/compile.mjs',
    'godot/native_arenas/identity_environment.gd', 'godot/native_arenas/catalog.gd',
    'godot/tests/horde/identity_live.gd', 'godot/tests/horde/identity_live.tscn',
    ...(cinderwake ? ['godot/tests/horde/cinderwake_live.gd', 'godot/tests/horde/cinderwake_live.tscn',
      'godot/horde_maps/catalog.gd', 'godot/horde_maps/cinderwake.gd', 'godot/horde_maps/demo.gd',
      'godot/horde_maps/generated/cinderwake-drydock.json', 'game/horde-stages.mjs'] : []),
    'godot/horde/demo.gd', 'godot/horde/client.gd', 'godot/horde/controls.gd', 'godot/horde/model.gd',
    'godot/horde/scoreboard.gd', 'godot/world/session.gd', 'godot/world/local_motion.gd', 'godot/world/presentation.gd',
    'godot/world/pickups.gd', 'godot/world/combat_feedback.gd', 'godot/first_person/rig.gd', 'godot/first_person/session_binding.gd',
    'godot/net/client.gd', 'godot/ui/game_hud.gd', 'godot/ui/scoreboard.gd',
    'port/native-horde/authority.mjs', 'port/native-horde/input-buffer.mjs',
    'port/native-identity-horde/run.mjs', 'port/native-identity-horde/validate.mjs',
    'port/native-identity-horde/measure.mjs',
  ];
  writeFileSync(resolve(out, 'launch.json'), JSON.stringify({
    base: execFileSync('git', ['rev-parse', 'HEAD'], {cwd: ROOT, encoding: 'utf8'}).trim(),
    source: lock.source_commit, binary,
    engineSHA256: createHash('sha256').update(readFileSync(binary)).digest('hex'),
    hashes: Object.fromEntries(files.map(path => [path, createHash('sha256').update(readFileSync(resolve(ROOT, path))).digest('hex')])),
    argv, scenario, map: selectedMap, waves, resolution, rendering: rendering || 'engine-default',
    clockPolicy: 'monotonic elapsed, fixed 1/60, source five-step backlog cap',
    localOnly: true, display: 'private Xvfb, -nolisten tcp -nolisten unix',
    scope: cinderwake ? 'source-staged Horde on Cinderwake Drydock' : 'identity-family Horde on Nacre Engine',
  }, null, 2));

  child = tracked(binary, argv, {cwd: ROOT, env, stdio: ['ignore', 'pipe', 'pipe']});
  child.stdout.on('data', chunk => { stdout += chunk; if (stdout.length > 48 * 1024 * 1024) void stop(child); });
  child.stderr.on('data', chunk => { stderr += chunk; if (stderr.length > 8 * 1024 * 1024) void stop(child); });
  reason = 'running';
  timer = setTimeout(() => { reason = `${SCENARIOS[scenario]} second deadline`; void stop(child); }, SCENARIOS[scenario] * 1000);
  const result = await child.done;
  clearTimeout(timer);
  exit = result.code === 0 && !/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use|RIDs? of type.*leaked/.test(stdout + stderr) && !stopping ? 0 : 1;
  reason = exit === 0 ? 'identity horde scenario completed' : reason === 'running' ? 'identity horde scenario failed' : reason;
} catch (error) {
  reason = error.stack;
} finally {
  clearTimeout(timer);
  for (const process_ of [...children].reverse()) await stop(process_);
  if (game) await game.close();
  // Corridor measurement from the accepted records plus the static analysis.
  let traversal = null, corridors = null;
  try {
    if (!cinderwake) {
      const arena = nacreArena();
      const samples = wire.map(line => JSON.parse(line))
        .filter(record => record.direction === 'out' && record.frame?.type === 'snapshot')
        .map(record => ({wave: record.frame.state?.singleplayer?.wave ?? 0, actors: record.frame.state?.actors ?? []}));
      traversal = traversalReport(arena, samples);
      corridors = measureNacre();
      writeFileSync(resolve(out, 'corridors.json'), `${JSON.stringify({static: corridors, traversed: traversal}, null, 2)}\n`);
    }
  } catch (error) {
    writeFileSync(resolve(out, 'corridors-error.txt'), String(error.stack ?? error));
  }
  for (const [name, text] of Object.entries({'wire.jsonl': wire.join('\n'), 'native.stdout.log': stdout, 'native.stderr.log': stderr})) {
    writeFileSync(resolve(out, `${name}.gz`), gzipSync(text));
  }
  rmSync(temp, {recursive: true, force: true});
  const cleanup = children.map(process_ => {
    let absent = false;
    try { process.kill(process_.pid, 0); } catch (error) { absent = error.code === 'ESRCH'; }
    return {pid: process_.pid, reaped: process_.exitCode !== null || process_.signalCode !== null, absent};
  });
  if (cleanup.some(entry => !entry.absent || !entry.reaped) || game?.server.listening || game?.wss.clients.size || existsSync(temp)) exit = 1;
  const summary = {exit, reason, scenario, map: selectedMap, waves, resolution, rendering: rendering || 'engine-default',
    wallSeconds: (performance.now() - startedAt) / 1000, records: wire.length, cleanup,
    serverClosed: !game?.server.listening, sockets: game?.wss.clients.size ?? 0, temporaryTreeRemoved: !existsSync(temp),
    traversedMinimum: traversal?.minimumTraversed ?? null,
    traversedChannel: traversal?.tightestChannel ?? null};
  writeFileSync(resolve(out, 'summary.json'), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify({exit, reason, evidence: out, records: wire.length, cleanup}));
  if (!existsSync(resolve(ROOT, 'port/native-identity-horde/attempt-history.json'))) {
    writeFileSync(resolve(ROOT, 'port/native-identity-horde/attempt-history.json'), '[]\n');
  }
  const history = JSON.parse(readFileSync(resolve(ROOT, 'port/native-identity-horde/attempt-history.json'), 'utf8'));
  history.push({stamp, scenario, waves, resolution, exit, reason, records: wire.length,
    wallSeconds: summary.wallSeconds, traversedMinimumWidth: traversal?.minimumTraversed?.width ?? null});
  writeFileSync(resolve(ROOT, 'port/native-identity-horde/attempt-history.json'), `${JSON.stringify(history, null, 2)}\n`);
  process.exitCode = exit;
}

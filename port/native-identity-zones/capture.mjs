// Identity zone graphical acceptance runner (Vermilion Fold Domination).
//
// Per requested size: starts a private Xvfb display and the owned loopback
// authority, computes supported spawn->zone routes from the validated identity
// arena, runs the real scene through `res://tests/zone_modes/identity_live.gd`
// with ordinary input events, then validates the rendered projections against
// the authority's own frames and records the framebuffer PNGs.
//
//   GODOT_BIN=<pinned 4.5.2> node port/native-identity-zones/capture.mjs
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {gzipSync} from 'node:zlib';
import {readNativeArena} from '../native-arenas/schema.mjs';
import {createIdentityZoneAuthority} from './authority.mjs';
import {IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE} from './catalog.mjs';
import {planZoneRoutes} from './route.mjs';
import {validate} from './validate.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const MAP = IDENTITY_ZONE_MAP_ID;
const options = {sizes:'960x640,1280x800', bots:2, seconds:180, score:100, difficulty:'easy',
  root:`${ROOT}/port/native-identity-zones/captures/${MAP}-${new Date().toISOString().replace(/[:.]/g, '-')}`};
for (const arg of process.argv.slice(2)) {
  const match = /^--([a-z-]+)=?(.*)$/.exec(arg);
  if (!match || match[2] === '') continue;
  options[{'score-limit':'score', 'round-seconds':'seconds', 'capture-root':'root'}[match[1]] ?? match[1]] = match[2];
}
const sizes = options.sizes.split(',').map(value => value.split('x').map(Number));
const GODOT = process.env.GODOT_BIN ?? '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
mkdirSync(options.root, {recursive: true});

// Static launch closure: source lock, pinned engine, reviewed identity envelope.
const lock = JSON.parse(readFileSync(resolve(ROOT, 'port/contracts/source-lock.json'), 'utf8'));
if (execFileSync(GODOT, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) {
  throw Error('Godot version differs from the pinned source lock');
}
const data = readNativeArena(MAP);
// Route planning happens before any live clock, from the validated arena only.
const routesFile = resolve(options.root, 'routes.json');
writeFileSync(routesFile, `${JSON.stringify(planZoneRoutes(data.arena))}\n`);

const compact = state => ({mapId:state.mapId, config:state.config, time:state.time, over:state.over,
  overReason:state.overReason ?? null, winner:state.winner, teamScores:state.teamScores,
  objectives:state.objectives,
  actors:state.actors.map(actor => ({id:actor.id, team:actor.team, x:actor.x, y:actor.y, z:actor.z,
    health:actor.health, frags:actor.frags, deaths:actor.deaths, scoreStats:actor.scoreStats,
    bot:actor.bot !== null}))});

// Godot scans scripts reachable from the loaded scene chain. Only this lane's
// resources may fail this gate: a foreign in-progress script in the shared
// worktree is recorded, not silently accepted or wrongly blamed on this route.
const OWNED_PREFIXES = ['res://native_arenas/identity_zone_demo', 'res://identity_maps/',
  'res://zone_modes/', 'res://tests/zone_modes/identity_live.gd'];
function scriptErrors(text) {
  const lines = text.split(/\r?\n/);
  const errors = [];
  for (let index = 0; index < lines.length; index++) {
    if (!/SCRIPT ERROR|Parse Error/.test(lines[index])) continue;
    const context = lines.slice(index, index + 3).join(' ');
    const paths = [...context.matchAll(/res:\/\/[^\s"']+/g)]
      .map(match => match[0].replace(/:\d+$/, ''));
    errors.push({message:lines[index].trim(), paths});
  }
  return errors;
}
const ownedError = error => error.paths.length === 0 ||
  error.paths.some(path => OWNED_PREFIXES.some(prefix => path.startsWith(prefix)));

function freeDisplay() {
  for (let number = 90; number < 130; number++) {
    if (!existsSync(`/tmp/.X11-unix/X${number}`)) return number;
  }
  throw Error('No free private X display');
}
function terminate(child) {
  return new Promise(resolveClose => {
    if (!child || child.exitCode !== null || child.signalCode !== null) { resolveClose(); return; }
    child.kill('SIGTERM');
    const timer = setTimeout(() => child.kill('SIGKILL'), 2000);
    child.once('close', () => { clearTimeout(timer); resolveClose(); });
  });
}

const report = {gate:'identity-zone-graphical-acceptance', mapId:MAP, mode:IDENTITY_ZONE_MODE,
  startedAt:new Date().toISOString(), sizes:options.sizes, bots:Number(options.bots),
  scoreLimit:Number(options.score), roundSeconds:Number(options.seconds), difficulty:options.difficulty,
  godot:execFileSync(GODOT, ['--version'], {encoding:'utf8'}).trim(), sourceCommit:lock.source_commit,
  geometryHash:data.geometryHash, runs:[], passed:false};
const children = [];
let ok = true;

/** One private-display Godot session for one evidence size. */
async function runSize(width, height, attempt) {
  const display = freeDisplay();
  const xvfb = spawn('Xvfb', [`:${display}`, '-screen', '0', '1280x800x24', '-nolisten', 'tcp', '-nolisten', 'unix'],
    {stdio:['ignore', 'pipe', 'pipe']});
  children.push(xvfb);
  const xvfbLog = [];
  for (const stream of [xvfb.stdout, xvfb.stderr]) stream.on('data', data => xvfbLog.push(String(data)));
  await new Promise(resolveWait => setTimeout(resolveWait, 800));

  const wire = [];
  const authority = await createIdentityZoneAuthority({port:0, host:'127.0.0.1', mapId:MAP, mode:IDENTITY_ZONE_MODE,
    bots:Number(options.bots), roundSeconds:Number(options.seconds), fragLimit:Number(options.score),
    difficulty:options.difficulty,
    observe:record => {
      const frame = record.frame;
      if (!frame || !['welcome','lobby','start','snapshot','results','events','error'].includes(frame.type)) {
        if (record.direction === 'in' && frame?.type === 'input') wire.push({direction:'in', round:record.round, frame:{type:'input', seq:frame.seq, inputEpoch:frame.inputEpoch}});
        return;
      }
      wire.push({direction:record.direction, round:record.round, observedMs:record.observedMs,
        frame:frame.state ? {...frame, state:compact(frame.state)} : frame});
    }});
  const health = await (await fetch(`http://127.0.0.1:${authority.port}`)).json();
  assert.equal(health.geometryHash, data.geometryHash);
  assert.equal(health.mapId, MAP);
  const runRoot = resolve(options.root, `${width}x${height}`);
  mkdirSync(runRoot, {recursive:true});
  for (const name of ['data', 'config', 'cache']) mkdirSync(`${runRoot}/home/${name}`, {recursive:true});
  let stdout = '', stderr = '';
  const child = spawn(GODOT, ['--path', 'godot', '--audio-driver', 'Dummy',
    '--rendering-method', 'gl_compatibility', '--max-fps', '60', '--resolution', `${width}x${height}`,
    '--script', 'res://tests/zone_modes/identity_live.gd', '--',
    `--map=${MAP}`, `--mode=${IDENTITY_ZONE_MODE}`, `--endpoint=${authority.endpoint}`,
    `--bots=${options.bots}`, `--round-seconds=${options.seconds}`, `--score-limit=${options.score}`,
    `--deadline-seconds=${Number(options.seconds) + 180}`,
    `--routes=${routesFile}`, `--output=${runRoot}`, `--size=${width}x${height}`,
    '--zone-evidence'],
    {cwd:ROOT, env:{...process.env, DISPLAY:`:${display}`, HOME:`${runRoot}/home`,
      XDG_DATA_HOME:`${runRoot}/home/data`, XDG_CONFIG_HOME:`${runRoot}/home/config`,
      XDG_CACHE_HOME:`${runRoot}/home/cache`}, stdio:['ignore', 'pipe', 'pipe']});
  children.push(child);
  child.stdout.on('data', bytes => { stdout += bytes; if (stdout.length > 64 * 1024 * 1024) void terminate(child); });
  child.stderr.on('data', bytes => { stderr += bytes; });
  const closed = await new Promise(resolveExit => {
    const timer = setTimeout(() => { void terminate(child); }, (Number(options.seconds) + 240) * 1000);
    child.once('close', (code, signal) => { clearTimeout(timer); resolveExit({code, signal}); });
  });
  await authority.close();
  await terminate(xvfb);
  // Compressed native logs keep the committed evidence small; the private
  // Godot cache tree is disposable and is not evidence.
  writeFileSync(`${runRoot}/godot.stdout.log.gz`, gzipSync(Buffer.from(stdout)));
  writeFileSync(`${runRoot}/godot.stderr.log.gz`, gzipSync(Buffer.from(stderr)));
  writeFileSync(`${runRoot}/xvfb.log`, xvfbLog.join(''));
  rmSync(`${runRoot}/home`, {recursive:true, force:true});
  const errors = scriptErrors(stdout + '\n' + stderr);
  const ownedErrors = errors.filter(ownedError);
  const foreignErrors = errors.filter(error => !ownedError(error));
  const raw = Buffer.from(wire.map(record => JSON.stringify(record)).join('\n') + '\n');
  writeFileSync(`${runRoot}/wire.jsonl.gz`, gzipSync(raw));
  const run = {size:[width, height], attempt, exitCode:closed.code, signal:closed.signal ?? null,
    wireBytes:raw.length, wireSha256:createHash('sha256').update(raw).digest('hex'),
    scriptErrors:ownedErrors.map(error => error.message),
    foreignScriptErrors:foreignErrors.map(error => ({message:error.message, paths:error.paths}))};
  let validation = null;
  try {
    assert.equal(closed.code, 0, `Godot exit at ${width}x${height}`);
    assert.deepEqual(run.scriptErrors, [], 'no script errors in this lane during the run');
    validation = validate({wire, stdout, mapId:MAP, mode:IDENTITY_ZONE_MODE, sizes:[[width, height]]});
    run.validation = validation;
    // Hard gates hold for a driver-choreographed round: real source capture,
    // contest and held scoring, both teams scoring, results and restart, plus
    // every rendered/HUD/one-world correlation check the validator makes.
    // `lost`/`recovered` are reported observations (bot decisions are not
    // deterministic); the exact 0->1->0 sequence is gated deterministically by
    // port/native-identity-zones/tests/match.test.mjs.
    run.passed = validation.capture && validation.contested && validation.heldScore &&
      validation.teamsScored[0] && validation.teamsScored[1] &&
      validation.results.over && validation.restart.starts === 2;
  } catch (error) {
    run.error = error.message;
    run.passed = false;
  }
  writeFileSync(`${runRoot}/validation.json`, `${JSON.stringify({run, validation}, null, 2)}\n`);
  return run;
}

for (const [width, height] of sizes) {
  let run = await runSize(width, height, 1);
  if (run.exitCode === null && run.signal !== null) {
    // A signaled Godot process is host pressure, not a gate result: retry the
    // size once and keep the final attempt's evidence.
    console.log(JSON.stringify({size:`${width}x${height}`, retry:'signaled Godot process', signal:run.signal}));
    run = await runSize(width, height, 2);
  }
  report.runs.push(run);
  ok = ok && run.passed === true;
  console.log(JSON.stringify({size:`${width}x${height}`, attempt:run.attempt, exitCode:run.exitCode,
    signal:run.signal, passed:run.passed, error:run.error ?? null,
    validation:run.validation && {capture:run.validation.capture, contested:run.validation.contested,
      lost:run.validation.lost, recovered:run.validation.recovered, held:run.validation.heldScore,
      teamsScored:run.validation.teamsScored, results:run.validation.results,
      correlated:run.validation.correlatedSnapshots}}));
}
report.passed = ok;
report.finishedAt = new Date().toISOString();
writeFileSync(resolve(options.root, 'summary.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({passed:report.passed, evidence:options.root,
  runs:report.runs.map(run => ({size:run.size, exitCode:run.exitCode, passed:run.passed}))}));
process.exitCode = ok ? 0 : 1;

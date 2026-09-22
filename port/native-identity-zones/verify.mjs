// Full identity-zone (Vermilion Fold Domination) gate.
//
//   GODOT_BIN=<pinned 4.5.2> node port/native-identity-zones/verify.mjs [--skip-capture]
//
// Runs this lane's source/authority tests, the existing zone and HUD/protocol
// Godot gates, the arena suites, the spawn-to-zone travel measurement and the
// graphical acceptance at both evidence sizes. Every step's log is kept under
// evidence/, and the consolidated report records the exit codes.
import {spawn} from 'node:child_process';
import {mkdirSync, writeFileSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const GODOT = process.env.GODOT_BIN ?? '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const output = resolve(ROOT, 'port/native-identity-zones/evidence');
mkdirSync(output, {recursive:true});
const report = {gate:'identity-zone-vermilion-fold-domination', startedAt:new Date().toISOString(), steps:[], passed:false};
const skipCapture = process.argv.includes('--skip-capture');

function run(name, command, args, options = {}) {
  return new Promise(resolvePromise => {
    const started = Date.now();
    const child = spawn(command, args, {cwd:ROOT, env:{...process.env, GODOT_BIN:GODOT, TMPDIR:'/tmp/opencode'}, ...options});
    let text = '';
    for (const stream of [child.stdout, child.stderr]) stream.on('data', data => { text += data; });
    const timeout = setTimeout(() => child.kill('SIGKILL'), options.timeoutMs ?? 900000);
    child.on('exit', code => {
      clearTimeout(timeout);
      const step = {name, command:[command, ...args].join(' '), exitCode:code,
        wallSeconds:(Date.now() - started) / 1000, log:`${output}/${name}.log`};
      writeFileSync(step.log, text);
      report.steps.push(step);
      console.log(JSON.stringify({step:name, exitCode:code, wallSeconds:step.wallSeconds}));
      resolvePromise(code === 0);
    });
  });
}
const headless = (name, script) => run(name, GODOT, ['--headless', '--path', 'godot', '--script', script]);

let ok = true;
ok = await run('identity-zone-node-tests', process.execPath, ['--test',
  'port/native-identity-zones/tests/match.test.mjs',
  'port/native-identity-zones/tests/route.test.mjs',
  'port/native-identity-zones/tests/authority.test.mjs']) && ok;
// The delivered arena suites must stay green with this route's additions.
ok = await run('native-arena-node-tests', process.execPath, ['--test',
  'port/native-arenas/tests/actual-maps.mjs', 'port/native-arenas/tests/identity-maps.mjs',
  'port/native-arenas/tests/schema.test.mjs', 'port/native-arenas/tests/source-match.test.mjs',
  'port/native-arenas/tests/input-events.test.mjs']) && ok;
// Existing zone and HUD/protocol gates this lane's presentation touches.
for (const [name, script] of [
  ['zone-modes-unit', 'res://tests/zone_modes/unit.gd'],
  ['input-queue', 'res://tests/protocol/input_queue.gd'],
  ['round-boundaries', 'res://tests/protocol/round_boundaries.gd'],
  ['local-lifecycle', 'res://tests/protocol/local_lifecycle.gd'],
  ['game-hud-session', 'res://tests/protocol/game_hud_session.gd'],
  ['scoreboard-session', 'res://tests/protocol/scoreboard_session.gd'],
  ['team-scores', 'res://tests/protocol/team_scores.gd'],
]) ok = await headless(name, script) && ok;
ok = await run('travel-times', process.execPath, ['port/native-identity-zones/travel.mjs']) && ok;
if (!skipCapture) {
  ok = await run('graphical-capture', process.execPath, ['port/native-identity-zones/capture.mjs',
    '--bots=2', '--round-seconds=180', '--score-limit=900'],
    {timeoutMs:900000}) && ok;
}
report.passed = ok;
report.finishedAt = new Date().toISOString();
report.godot = GODOT;
writeFileSync(`${output}/verify-report.json`, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({passed:report.passed,
  steps:report.steps.map(({name, exitCode}) => ({name, exitCode}))}));
if (!ok) process.exitCode = 1;

// Route/package Deathmatch gate for the three identity maps (Lacuna Court,
// Vermilion Fold, Nacre Engine).
//
// Runs the owned Node gates, a real launcher smoke per map at HEAD, and the
// graphical Xvfb captures, then writes report.json. The detached-package gate
// (build.py + run.mjs + PCK resource probe) is documented in README.md and
// recorded separately because it needs committed adapter/data bytes.
//
//   GODOT_BIN=<pinned 4.5.2> node port/native-identity-dm/verify.mjs
import {spawn} from 'node:child_process';
import {readdirSync, mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const MAPS = ['lacuna-court', 'vermilion-fold', 'nacre-engine'];
const report = {gate: 'identity-deathmatch-route-package', startedAt: new Date().toISOString(), steps: [], passed: false};
const output = resolve(ROOT, 'port/native-identity-dm/evidence');
mkdirSync(output, {recursive: true});

function run(name, command, args, options = {}) {
  return new Promise(resolvePromise => {
    const started = Date.now();
    const child = spawn(command, args, {cwd: ROOT, env: {...process.env, TMPDIR: '/tmp/opencode'}, ...options});
    let text = '';
    for (const stream of [child.stdout, child.stderr]) stream.on('data', data => {text += data;});
    const timeout = setTimeout(() => child.kill('SIGKILL'), options.timeoutMs ?? 900000);
    child.on('exit', code => {
      clearTimeout(timeout);
      const step = {name, command: [command, ...args].join(' '), exitCode: code,
        wallSeconds: (Date.now() - started) / 1000, log: `${output}/${name}.log`};
      writeFileSync(step.log, text);
      report.steps.push(step);
      console.log(JSON.stringify({step: name, exitCode: code, wallSeconds: step.wallSeconds}));
      resolvePromise(code === 0);
    });
  });
}

const arenaTests = readdirSync(resolve(ROOT, 'port/native-arenas/tests')).filter(name => name.endsWith('.mjs'))
  .map(name => `port/native-arenas/tests/${name}`);
const toolTests = [
  ...readdirSync(resolve(ROOT, 'tools/godot-dev')).filter(name => name.endsWith('.test.mjs')).map(name => `tools/godot-dev/${name}`),
  ...readdirSync(resolve(ROOT, 'tools/godot-package')).filter(name => name.endsWith('.test.mjs')).map(name => `tools/godot-package/${name}`),
];
let ok = true;
ok = await run('native-arena-node-tests', process.execPath, ['--test', ...arenaTests]) && ok;
ok = await run('launcher-package-node-tests', process.execPath, ['--test', ...toolTests, '--test-concurrency=1']) && ok;
for (const map of MAPS) {
  ok = await run(`launcher-smoke-${map}`, process.execPath,
    ['tools/godot-dev/launch.mjs', '--experience=native-dm', `--map=${map}`, '--smoke'],
    {env: {...process.env, GODOT_BIN: process.env.GODOT_BIN ?? ''}, timeoutMs: 240000}) && ok;
}
for (const map of MAPS) {
  ok = await run(`capture-${map}`, process.execPath,
    ['port/native-identity-dm/capture.mjs', `--map=${map}`],
    {env: {...process.env, GODOT_BIN: process.env.GODOT_BIN ?? ''}, timeoutMs: 600000}) && ok;
}
report.passed = ok;
report.finishedAt = new Date().toISOString();
writeFileSync(`${output}/verify-report.json`, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({passed: report.passed, steps: report.steps.map(({name, exitCode}) => ({name, exitCode}))}));
if (!ok) process.exitCode = 1;

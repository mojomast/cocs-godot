#!/usr/bin/env node
// Linux/CI runner for the in-match benchmark. It owns the loopback native
// Deathmatch authority, runs the pinned Godot client under a private Xvfb display
// (via tools/godot-dev/xvfb_run.py), and keeps the raw result JSON, the rendered
// captures and the full console log as evidence.
//
// The owner measures the packaged Windows build instead: see README.md.
//
// Usage:
//   node port/native-benchmark/run_benchmark.mjs --level=all --resolution=1280x800
//   node port/native-benchmark/run_benchmark.mjs --level=extreme --resolution=960x640
//   node port/native-benchmark/run_benchmark.mjs --level=low --bots=6 --map=aurora-basin
import {spawn} from 'node:child_process';
import {existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';
import {compareResults, lineSummary, parseConsole, validateResult, auditAutostart} from './validate.mjs';

const root = resolve(import.meta.dirname, '../..');
const LEVELS = {low: 'low', high: 'high', extreme: 'extreme', current: 'current'};

function usage() {
  console.log(`Native Deathmatch benchmark runner

  node port/native-benchmark/run_benchmark.mjs [options]

  --map=ID            native Deathmatch map (default prism-foundry)
  --bots=N            1..7 bots (default 4)
  --resolution=WxH    window size (default 1280x800)
  --level=low|high|extreme|current|all   effects level to measure (default all)
  --round-seconds=N   authoritative round length (default 180)
  --seconds=N         safety timeout for one run (default 150)
  --gate=autostart|unarmed|none   run-sheet regression gate instead of a matrix
  --out=DIR           evidence directory (default port/native-benchmark/evidence)
  --label=TEXT        extra label recorded with the evidence
  --keep-temp         keep the private XDG runtime directory for inspection

Set GODOT_BIN to the pinned Godot 4.5.2 executable.`);
}

function parse(argv) {
  const options = {map: 'prism-foundry', bots: 4, resolution: '1280x800', level: 'all',
    roundSeconds: 180, seconds: 150, gate: 'none', out: 'port/native-benchmark/evidence', label: '', keepTemp: false};
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') { usage(); process.exit(0); }
    if (arg === '--keep-temp') { options.keepTemp = true; continue; }
    const match = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (!match) throw new Error(`Unknown option: ${arg}`);
    const [, key, value] = match;
    if (key === 'map') options.map = value;
    else if (key === 'bots') options.bots = Number(value);
    else if (key === 'resolution') options.resolution = value;
    else if (key === 'level') options.level = value;
    else if (key === 'round-seconds') options.roundSeconds = Number(value);
    else if (key === 'seconds') options.seconds = Number(value);
    else if (key === 'gate') options.gate = value;
    else if (key === 'out') options.out = value;
    else if (key === 'label') options.label = value;
    else throw new Error(`Unknown option: ${key}`);
  }
  if (!LEVELS[options.level] && options.level !== 'all') throw new Error(`--level must be low, high, extreme, current or all`);
  if (!/^\d{3,4}x\d{3,4}$/.test(options.resolution)) throw new Error('--resolution must look like 1280x800');
  if (!Number.isInteger(options.bots) || options.bots < 1 || options.bots > 7) throw new Error('--bots must be 1..7');
  if (!Number.isInteger(options.roundSeconds) || options.roundSeconds < 60 || options.roundSeconds > 900) throw new Error('--round-seconds must be 60..900');
  if (!['none', 'autostart', 'unarmed', 'all'].includes(options.gate)) throw new Error('--gate must be autostart, unarmed, all or none');
  return options;
}

async function runOnce({options, binary, level, stamp, outDir, directoryLabel = null, armByArgument = true, killSeconds = null}) {
  const runDir = join(outDir, `${stamp}-${options.resolution}-${directoryLabel ?? level}`);
  mkdirSync(runDir, {recursive: true});
  const runtime = mkdtempSync(join(process.env.TMPDIR || tmpdir(), 'cocs-benchmark-'));
  const env = {...process.env, COCS_BENCHMARK: '1', COCS_BENCHMARK_OUT: runDir,
    XDG_DATA_HOME: join(runtime, 'data'), XDG_CONFIG_HOME: join(runtime, 'config'), XDG_CACHE_HOME: join(runtime, 'cache')};
  for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) mkdirSync(env[key], {recursive: true});
  if (level !== 'current') env.COCS_BENCHMARK_LEVEL = level;
  else delete env.COCS_BENCHMARK_LEVEL;
  // The un-armed negative gate removes the environment trigger entirely; the
  // armed autostart gate keeps only the environment, never the --benchmark
  // argument, so it exercises exactly the owner's documented launcher path.
  if (options.gate === 'unarmed') {
    delete env.COCS_BENCHMARK;
    delete env.COCS_BENCHMARK_LEVEL;
  }
  const [width, height] = options.resolution.split('x');
  const godotArgs = [binary, '--path', 'godot', '--audio-driver', 'Dummy', '--resolution', options.resolution,
    'res://native_arenas/demo.tscn', '--',
    `--map=${options.map}`, '--mode=deathmatch', `--bots=${options.bots}`,
    `--round-seconds=${options.roundSeconds}`, `--endpoint=${endpoint}`];
  if (armByArgument) godotArgs.push('--benchmark');
  const command = ['python3', 'tools/godot-dev/xvfb_run.py', ...godotArgs];
  const child = spawn(command[0], command.slice(1), {cwd: root, env, detached: true, stdio: ['ignore', 'pipe', 'pipe']});
  let output = '';
  child.stdout.on('data', chunk => { output += chunk; process.stdout.write(chunk); });
  child.stderr.on('data', chunk => { output += chunk; process.stdout.write(chunk); });
  const timer = setTimeout(() => {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); }
  }, (killSeconds ?? options.seconds) * 1000);
  const code = await new Promise(resolveCode => child.once('exit', resolveCode));
  clearTimeout(timer);
  if (!options.keepTemp) rmSync(runtime, {recursive: true, force: true});
  writeFileSync(join(runDir, 'run.log'), output);
  const {result, line} = parseConsole(output);
  const meta = {
    label: options.label, level, resolution: options.resolution, map: options.map, bots: options.bots,
    godot: binary, command: command.join(' '), exit_code: code, endpoint_scheme: 'ws://127.0.0.1:PORT/native-arenas',
    window_pixels: Number(width) * Number(height), directory: runDir,
    result_file: result ? join(runDir, 'result.json') : null, line: line || null,
  };
  if (result) {
    const validation = validateResult(result);
    meta.validation = validation;
    meta.result = result;
    writeFileSync(join(runDir, 'result.json'), JSON.stringify(result, null, 2) + '\n');
    writeFileSync(join(runDir, 'BENCHMARK_RESULT.txt'), line + '\n');
    meta.summary = lineSummary(result);
    console.log(`\n[${level}] ${meta.summary}`);
    if (result.honesty?.software_renderer) {
      console.log(`[${level}] WARNING: software rasterizer (${result.environment.adapter}) - these numbers are NOT hardware figures.`);
    }
    if (!validation.ok) console.log(`[${level}] VALIDATION PROBLEMS: ${validation.problems.join('; ')}`);
  } else {
    meta.validation = {ok: false, problems: ['no BENCHMARK_RESULT line was printed']};
    console.log(`\n[${level}] no BENCHMARK_RESULT line; see ${join(runDir, 'run.log')}`);
  }
  meta.output = output;
  return meta;
}

/** Run one gate, or both (`--gate=all`). Returns the process exit code. */
async function runGate(options, binary, stamp, outDir) {
  const gates = options.gate === 'all' ? ['autostart', 'unarmed'] : [options.gate];
  let code = 0;
  for (const gate of gates) code = Math.max(code, await runOneGate({...options, gate}, binary, stamp, outDir));
  return code;
}

/**
 * The run-sheet regression gate. One rendered run with the launcher arming the
 * benchmark the documented way (environment only, no --benchmark argument):
 *   --gate=autostart  the run must print BENCHMARK_AUTOSTART, start measuring,
 *                     return one complete BENCHMARK_RESULT and exit cleanly.
 *   --gate=unarmed    no arming at all: the game must stay at the setup screen
 *                     and print no benchmark startup marker at all.
 * Prints BENCHMARK_GATE_OK or BENCHMARK_GATE_FAIL and returns the process code.
 */
async function runOneGate(options, binary, stamp, outDir) {
  const level = options.level === 'all' ? 'high' : options.level;
  const armed = options.gate === 'autostart';
  // Both gates arm through the environment only: the autostart gate sets the
  // run-sheet trigger, the unarmed gate clears it. The --benchmark user arg is
  // never passed, because the packaged launchers cannot pass it either.
  const run = await runOnce({options, binary, level, directoryLabel: `${level}-gate-${options.gate}`, stamp, outDir,
    armByArgument: false, killSeconds: armed ? options.seconds : Math.min(options.seconds, 10)});
  const audit = auditAutostart(run.output, {expectAutostart: armed});
  const problems = [...audit.problems];
  if (armed) {
    const result = run.result;
    if (!result) problems.push('the armed gate printed no BENCHMARK_RESULT');
    else {
      if (result.complete !== true) problems.push('the armed gate did not complete the scripted sequence');
      if (result.launch?.automatic !== true) problems.push('the armed gate was not an automatic benchmark run');
      if (result.launch?.trigger !== 'environment') problems.push(`the armed gate trigger is ${result.launch?.trigger}, not environment`);
      if (result.scene?.autostart !== true) problems.push('the armed gate result does not record the session autostart');
      if (result.scene?.bots !== options.bots || result.scene?.map !== options.map) problems.push('the armed gate measured a different composition');
      const validation = validateResult(result);
      if (!validation.ok) problems.push(...validation.problems);
    }
  }
  const payload = {schema: 1, gate: options.gate, map: options.map, bots: options.bots,
    level, directory: run.directory, autostarts: audit.autostarts, problems,
    result_file: run.result_file, exit_code: run.exit_code};
  if (problems.length === 0) {
    console.log(`BENCHMARK_GATE_OK ${JSON.stringify(payload)}`);
    return 0;
  }
  console.log(`BENCHMARK_GATE_FAIL ${JSON.stringify(payload)}`);
  return 1;
}

const options = parse(process.argv.slice(2));
const binary = process.env.GODOT_BIN;
if (!binary) throw new Error('Set GODOT_BIN to the pinned Godot 4.5.2 executable');
if (!existsSync(binary)) throw new Error(`GODOT_BIN does not exist: ${binary}`);
const outDir = resolve(root, options.out);
mkdirSync(outDir, {recursive: true});
const stamp = new Date().toISOString().replace(/[:.]/g, '-').replace('Z', 'Z');
const levels = options.level === 'all' ? ['low', 'high', 'extreme'] : [options.level];
let authority = null;
let endpoint = '';
try {
  authority = await createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId: options.map,
    mode: 'deathmatch', bots: options.bots, roundSeconds: options.roundSeconds});
  endpoint = authority.endpoint;
  console.log(`Owned loopback authority ready at ${endpoint} (map ${options.map}, ${options.bots} bots)`);
  if (options.gate !== 'none') {
    process.exitCode = await runGate(options, binary, stamp, outDir);
  } else {
    const runs = [];
    for (const level of levels) runs.push(await runOnce({options, binary, level, stamp, outDir}));
    const matrix = {schema: 1, stamp, label: options.label, resolution: options.resolution, map: options.map,
      bots: options.bots, round_seconds: options.roundSeconds, runs};
    const comparisons = [];
    if (runs.length > 1) {
      const byLevel = Object.fromEntries(runs.map(run => [run.level, run.result]));
      if (byLevel.low && byLevel.extreme) comparisons.push({low_vs_extreme: compareResults(byLevel.low, byLevel.extreme)});
      if (byLevel.high && byLevel.extreme) comparisons.push({high_vs_extreme: compareResults(byLevel.high, byLevel.extreme)});
      if (byLevel.low && byLevel.high) comparisons.push({low_vs_high: compareResults(byLevel.low, byLevel.high)});
    }
    matrix.comparisons = comparisons;
    const matrixPath = join(outDir, `matrix-${options.resolution}-${stamp}.json`);
    writeFileSync(matrixPath, JSON.stringify(matrix, null, 2) + '\n');
    console.log('\n=== comparison ===');
    for (const comparison of comparisons) {
      const [name, value] = Object.entries(comparison)[0];
      console.log(`${name}: ${value.baseline} -> ${value.candidate} median x${value.median_ratio.toFixed(2)} (p95 x${value.p95_ratio.toFixed(2)}, ${value.frames[0]}/${value.frames[1]} frames, particles ${value.particles[0]}/${value.particles[1]})`
        + `${value.slower ? ' SLOWER' : ' not slower'}`);
    }
    console.log(`\nEvidence written to ${outDir}`);
    console.log(`Matrix: ${matrixPath}`);
    const failed = runs.filter(run => !run.validation?.ok || !run.result?.complete);
    console.log(failed.length === 0
      ? 'All benchmark runs completed and validated.'
      : `${failed.length} of ${runs.length} runs did not complete or validate.`);
    process.exitCode = failed.length === 0 ? 0 : 1;
  }
} finally {
  if (authority) { for (const socket of authority.wss?.clients ?? []) socket.terminate(); await authority.close(); }
}

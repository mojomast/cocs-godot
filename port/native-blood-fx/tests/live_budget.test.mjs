// Focused tests for the live blood harness's bounded-failure contract.
//
// Regression context: widening the lobby client's create_room signature stopped the
// derived native-arena client from compiling, so the demo scene never loaded and the
// Godot child spun on runtime errors until the gate SIGKILLed the process group at
// 180 s. The harness had written nothing yet, so the gate reported "timeout" with an
// empty log and an empty evidence directory: a one-line compile break became a
// three-minute silent kill. These tests pin the contract that must hold instead —
// the harness always reports inside its own budget, strictly inside the gate's, and
// always leaves stdout/stderr/summary evidence behind.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync}
  from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

// This file lives one directory deeper than the harness it exercises.
const root = resolve(import.meta.dirname, '../../..');
const lock = JSON.parse(readFileSync(resolve(root, 'port/contracts/source-lock.json')));
const LIVE = resolve(root, 'port/native-blood-fx/live.mjs');
const EVIDENCE = resolve(root, 'port/native-blood-fx/evidence');
const GATE_BUDGET_MS = 180000;

// A stand-in Godot that answers the lock version probe and then behaves as scripted.
function fakeGodot(body) {
  const dir = mkdtempSync(join(tmpdir(), 'blood-fake-godot-'));
  const path = join(dir, 'godot');
  writeFileSync(path, `#!/bin/sh\nif [ "$1" = "--version" ]; then `
    + `printf '%s\\n' '${lock.godot_version}'; exit 0; fi\n${body}\n`);
  chmodSync(path, 0o755);
  return path;
}

function evidenceBefore() {
  mkdirSync(EVIDENCE, {recursive:true});
  return new Set(readdirSync(EVIDENCE));
}

function runLive(env) {
  const started = Date.now();
  const before = evidenceBefore();
  let status = 0, output = '';
  try {
    output = execFileSync(process.execPath, [LIVE], {cwd:root, encoding:'utf8',
      stdio:['ignore', 'pipe', 'pipe'], timeout:GATE_BUDGET_MS,
      env:{...process.env, TMPDIR:tmpdir(), ...env}});
  } catch (error) {
    status = error.status ?? 1;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  }
  return {status, output, before, elapsed:Date.now() - started};
}

function newestEvidence(before) {
  const fresh = readdirSync(EVIDENCE).filter(name => !before.has(name))
    .map(name => ({name, mtime:statSync(join(EVIDENCE, name)).mtimeMs}))
    .sort((left, right) => right.mtime - left.mtime);
  assert.ok(fresh.length, 'the harness created an evidence directory');
  return join(EVIDENCE, fresh[0].name);
}

test('a success marker cannot hide a nonzero engine exit', () => {
  const run = runLive({GODOT_BIN:fakeGodot("printf '%s\\n' 'BLOOD_LIVE_OK {}'; exit 9")});
  assert.notEqual(run.status, 0, 'engine exit must override the marker');
  const summary = JSON.parse(readFileSync(join(newestEvidence(run.before), 'summary.json'), 'utf8'));
  assert.equal(summary.status, 'failed');
  assert.equal(summary.exit_code, 9);
});

test('a success marker cannot hide an engine runtime error', () => {
  const run = runLive({GODOT_BIN:fakeGodot("printf '%s\\n' 'BLOOD_LIVE_OK {}'; printf '%s\\n' 'ERROR: fixture runtime failure' >&2; exit 0")});
  assert.notEqual(run.status, 0, 'runtime error must override the marker');
  const summary = JSON.parse(readFileSync(join(newestEvidence(run.before), 'summary.json'), 'utf8'));
  assert.equal(summary.status, 'failed');
  assert.equal(summary.errors, true);
});

test('a budget that cannot beat the gate is refused before any process starts', () => {
  const run = runLive({GODOT_BIN:fakeGodot('sleep 60'), BLOOD_LIVE_BUDGET_MS:String(GATE_BUDGET_MS)});
  assert.notEqual(run.status, 0, 'a non-beating budget is a hard error');
  assert.match(run.output, /BLOOD_LIVE_BUDGET_MS/, 'the refusal names the offending knob');
  assert.deepEqual(readdirSync(EVIDENCE), [...run.before].sort(),
    'a refused run leaves no half-written evidence behind');
});

test('a hung scene is bounded by the harness and leaves flushed evidence', () => {
  const run = runLive({GODOT_BIN:fakeGodot('sleep 60'), BLOOD_LIVE_BUDGET_MS:'4000'});
  assert.notEqual(run.status, 0, 'a hung scene fails the harness');
  assert.ok(run.elapsed < 30000, `the harness reported inside its own budget (${run.elapsed} ms)`);
  const evidence = newestEvidence(run.before);
  const summary = JSON.parse(readFileSync(join(evidence, 'summary.json'), 'utf8'));
  assert.equal(summary.status, 'failed');
  assert.equal(summary.failure_reason, 'timeout');
  assert.equal(summary.budget_ms, 4000);
  assert.ok(summary.budget_ms < GATE_BUDGET_MS, 'the harness deadline stays inside the gate');
  assert.match(readFileSync(join(evidence, 'stdout.log'), 'utf8'), /^$/);
  assert.ok(readFileSync(join(evidence, 'stderr.log'), 'utf8') !== undefined, 'stderr.log is flushed');
});

test('a composition compile break is reported immediately instead of being spun on', () => {
  const body = [
    'echo "SCRIPT ERROR: Parse Error: The function signature does not match the parent." >&2',
    'echo "ERROR: Failed to load script \\"res://native_arenas/demo.gd\\" with error \\"Compilation failed\\"." >&2',
    'sleep 60',
  ].join('\n');
  const run = runLive({GODOT_BIN:fakeGodot(body), BLOOD_LIVE_BUDGET_MS:'20000'});
  assert.notEqual(run.status, 0, 'a compile break fails the harness');
  assert.ok(run.elapsed < 15000, `the break was reported well inside the budget (${run.elapsed} ms)`);
  const evidence = newestEvidence(run.before);
  const summary = JSON.parse(readFileSync(join(evidence, 'summary.json'), 'utf8'));
  assert.equal(summary.status, 'failed');
  assert.equal(summary.failure_reason, 'compile-error');
  assert.equal(summary.errors, true, 'the engine error is surfaced, not swallowed');
  assert.match(summary.stderr_tail, /Parse Error/, 'the engine message reaches the evidence');
});

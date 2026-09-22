// Contracts for the benchmark result parser and comparison. Pure functions only:
// no display, no authority, no Godot. The rendered runs live in evidence/.
import test from 'node:test';
import assert from 'node:assert/strict';
import {compareResults, lineSummary, parseConsole, validateResult} from './validate.mjs';

function result(overrides = {}) {
  const base = {
    schema: 1, tool: 'cocs-native-benchmark', version: '1.0.0',
    generated: '2026-09-22T12:00:00Z', command: 'godot res://native_arenas/demo.tscn -- --benchmark',
    complete: true, verdict: 'usable', verdict_reasons: [],
    measured_seconds: 28.0, controls_seconds: 28.0, startup_seconds: 3.0,
    environment: {adapter: 'llvmpipe (LLVM 20.1.8, 256 bits)', renderer_method: 'gl_compatibility',
      renderer_driver: 'opengl3', display_server: 'X11', os: 'Linux', headless: false},
    window: {size: [1280, 800], viewport_size: [1280, 800], mode: 'windowed', scaling_3d: 1.0},
    launch: {trigger: 'environment', automatic: true, env: {COCS_BENCHMARK: '1', COCS_BENCHMARK_LEVEL: 'high'},
      windows_run: 'set COCS_BENCHMARK=1 && Play.cmd --experience=native-dm --map=prism-foundry --bots=4'},
    scene: {map: 'prism-foundry', mode: 'deathmatch', bots: 4, actor_count: 5, authority: 'owned-loopback'},
    quality: {level: 1, name: 'High', levels: ['Low', 'High', 'Extreme'], stable: true, levels_seen: ['High']},
    phases: [{name: 'warmup', samples: 16, median_ms: 159.0, p95_ms: 703.0, max_ms: 703.0, frames: 17, measured: false},
      {name: 'combat', samples: 60, median_ms: 184.0, p95_ms: 219.0, max_ms: 391.0, frames: 60, measured: true},
      {name: 'burst', samples: 32, median_ms: 175.6, p95_ms: 212.6, max_ms: 343.9, frames: 32, measured: true},
      {name: 'sustained', samples: 50, median_ms: 194.5, p95_ms: 214.2, max_ms: 431.3, frames: 50, measured: true}],
    aggregate: {samples: 142, median_ms: 190.4, p95_ms: 217.5, max_ms: 431.3, mean_ms: 194.8, fps_from_median: 5.25},
    engine: {draw_calls_mean: 1228.9, draw_calls_max: 1555, primitives_mean: 230880.5, primitives_max: 279249},
    particles: {allocated_slots: 131072, draw_slots: 81920, budget: 131072, backend: 'GPUParticles3D', quality: 'High'},
    combat: {shots: 96, explosions: 25, launches: 9, hits: 0, hurts: 4, local_deaths: 1, local_weapon: 0, local_weapon_name: 'Pulse Rifle'},
    recommendation: {level: 0, name: 'Low', basis: 'p95 wall-clock frame time measured by the in-match benchmark', p95_ms: 217.5},
    artifacts: {directory: '/tmp/evidence', json: '/tmp/evidence/benchmark.json', captures: [], write_error: '', json_written: true},
    honesty: {renderer_class: 'software', software_renderer: true,
      notes: ['SOFTWARE RENDERER (llvmpipe): these are CPU rasterizer numbers, not hardware GPU figures.',
        'Frame times are wall-clock intervals between real RenderingServer frame_post_draws, with display buffering included. They are not GPU timestamps.']},
  };
  for (const [key, value] of Object.entries(overrides)) base[key] = value;
  return base;
}

test('a complete, controlled run validates', () => {
  const validation = validateResult(result());
  assert.equal(validation.ok, true, validation.problems.join('; '));
});

test('missing or dishonest fields are rejected', () => {
  const missing = result();
  delete missing.aggregate;
  assert.equal(validateResult(missing).ok, false);
  assert.match(validateResult(missing).problems.join(' '), /aggregate/);
  const headless = result({environment: {...result().environment, headless: true}});
  assert.match(validateResult(headless).problems.join(' '), /headless/);
  const emptyRun = result({aggregate: {...result().aggregate, samples: 0}});
  assert.match(validateResult(emptyRun).problems.join(' '), /no frame samples/);
  const noPhases = result({phases: []});
  assert.match(validateResult(noPhases).problems.join(' '), /phases/);
  assert.equal(validateResult(null).ok, false);
});

test('a software result must carry the hardware caveat', () => {
  const honest = result();
  const weakened = result({honesty: {...honest.honesty, notes: ['Frame times are wall-clock intervals between real RenderingServer frame_post_draws.']}});
  assert.match(validateResult(weakened).problems.join(' '), /not hardware/);
  const misleading = result({honesty: {...honest.honesty, renderer_class: 'hardware', software_renderer: false,
    notes: ['Frame times are wall-clock intervals between real RenderingServer frame_post_draws.']}});
  assert.equal(validateResult(misleading).ok, true, 'hardware results need no software caveat');
});

test('an unknown renderer class is neither software nor hardware', () => {
  const unknown = result({honesty: {renderer_class: 'unknown', software_renderer: false,
    notes: ['Frame times are wall-clock intervals between real RenderingServer frame_post_draws.']}});
  assert.equal(validateResult(unknown).ok, true);
});

test('console output is parsed from the last BENCHMARK_RESULT line', () => {
  const text = ['Godot Engine v4.5.2', 'BENCHMARK_START plan=33.0s',
    `BENCHMARK_RESULT ${JSON.stringify(result())}`, 'BENCHMARK_ARTIFACTS {"written":true}', ''].join('\n');
  const parsed = parseConsole(text);
  assert.equal(parsed.result.quality.name, 'High');
  const noisy = parseConsole(`noise\nBENCHMARK_RESULT not-json\n`);
  assert.equal(noisy.result, null);
  assert.ok(noisy.error);
  assert.equal(parseConsole('nothing here').result, null);
});

test('lineSummary names resolution, quality and renderer class', () => {
  const summary = lineSummary(result());
  assert.match(summary, /prism-foundry 1280x800 High/);
  assert.match(summary, /median 190\.4 ms/);
  assert.match(summary, /p95 217\.5 ms/);
  assert.match(summary, /software/);
});

test('comparison refuses mismatched compositions', () => {
  const low = result({quality: {name: 'Low'}, aggregate: {...result().aggregate, median_ms: 100.0, p95_ms: 120.0}});
  const extreme = result({quality: {name: 'Extreme'}, aggregate: {...result().aggregate, median_ms: 400.0, p95_ms: 520.0}});
  const compared = compareResults(low, extreme);
  assert.equal(compared.slower, true);
  assert.ok(Math.abs(compared.median_ratio - 4.0) < 1e-9);
  assert.ok(compared.p95_ratio > 4.0);
  assert.throws(() => compareResults(low, result({scene: {...result().scene, bots: 6}})), /bots/);
  assert.throws(() => compareResults(low, result({window: {size: [960, 640]}})), /window.size/);
});

test('a level change that does not slow the frame down is reported as not slower', () => {
  const low = result({quality: {name: 'Low'}, aggregate: {...result().aggregate, median_ms: 100.0}});
  const high = result({quality: {name: 'High'}, aggregate: {...result().aggregate, median_ms: 101.0}});
  assert.equal(compareResults(low, high).slower, false);
  assert.equal(compareResults(low, high, 1.005).slower, true);
});

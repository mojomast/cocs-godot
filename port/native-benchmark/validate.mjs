// Pure parsers and validators for the in-match benchmark result. No I/O and no
// hardware dependency, so the same checks run in tests and in the runner.
export const RESULT_SCHEMA = 1;
export const LEVELS = ['Low', 'High', 'Extreme'];

export const REQUIRED_KEYS = ['schema', 'tool', 'version', 'generated', 'complete', 'verdict',
  'verdict_reasons', 'measured_seconds', 'controls_seconds', 'environment', 'window', 'launch', 'scene',
  'quality', 'phases', 'aggregate', 'engine', 'particles', 'combat', 'recommendation', 'artifacts', 'honesty'];
const AGGREGATE_KEYS = ['samples', 'median_ms', 'p95_ms', 'max_ms', 'mean_ms'];

/** Validate one parsed BENCHMARK_RESULT object. Returns {ok, problems}. */
export function validateResult(result) {
  const problems = [];
  const fail = message => problems.push(message);
  if (result === null || typeof result !== 'object' || Array.isArray(result)) return {ok: false, problems: ['result is not an object']};
  for (const key of REQUIRED_KEYS) if (!(key in result)) fail(`missing key ${key}`);
  if (result.schema !== RESULT_SCHEMA) fail(`schema ${result.schema} is not ${RESULT_SCHEMA}`);
  if (result.tool !== 'cocs-native-benchmark') fail(`tool is ${result.tool}`);
  if (typeof result.complete !== 'boolean') fail('complete is not a boolean');
  if (!['usable', 'partial', 'unusable'].includes(result.verdict)) fail(`verdict ${result.verdict} is not a known classification`);
  if (!Array.isArray(result.verdict_reasons)) fail('verdict_reasons is not a list');
  if (!Array.isArray(result.phases) || result.phases.length < 3) fail('phases are missing the scripted sequence');
  for (const phase of result.phases ?? []) {
    if (typeof phase.name !== 'string' || typeof phase.samples !== 'number') fail('a phase entry is malformed');
  }
  for (const key of AGGREGATE_KEYS) if (typeof result.aggregate?.[key] !== 'number') fail(`aggregate.${key} is not a number`);
  if (result.complete === true && (result.aggregate?.samples ?? 0) <= 0) fail('a complete run reports no frame samples');
  if (!Number.isFinite(result.measured_seconds) || result.measured_seconds <= 0) fail('measured_seconds is not positive');
  if ((result.controls_seconds ?? 0) < 0 || result.controls_seconds > result.measured_seconds + 1) fail('controls_seconds is outside the measured window');
  const environment = result.environment ?? {};
  if (!environment.adapter) fail('environment.adapter is missing');
  if (!environment.renderer_method) fail('environment.renderer_method is missing');
  if (typeof environment.headless !== 'boolean') fail('environment.headless is missing');
  if (environment.headless === true) fail('a headless run must never be reported as a benchmark');
  if (typeof result.launch?.trigger !== 'string') fail('launch.trigger is missing');
  if (!Array.isArray(result.window?.size) || result.window.size.length !== 2) fail('window.size is not a resolution pair');
  if (!result.window?.viewport_size) fail('window.viewport_size is missing');
  if (typeof result.scene?.map !== 'string' || typeof result.scene?.actor_count !== 'number') fail('scene composition is incomplete');
  if (typeof result.quality?.name !== 'string' || !LEVELS.includes(result.quality.name)) fail('quality.name is not a known level');
  if (typeof result.particles?.allocated_slots !== 'number') fail('particles.allocated_slots is not a number');
  if (typeof result.combat?.shots !== 'number') fail('combat.shots is not a number');
  if (typeof result.recommendation?.basis !== 'string') fail('recommendation.basis is missing');
  if (result.honesty?.renderer_class === undefined) fail('honesty.renderer_class is missing');
  const notes = result.honesty?.notes;
  if (!Array.isArray(notes) || notes.length === 0) fail('honesty.notes are missing');
  else if (!notes.some(note => String(note).includes('frame_post_draw'))) fail('honesty.notes do not state what a frame time measures');
  if (result.honesty?.software_renderer === true && !notes.some(note => String(note).includes('not hardware'))) {
    fail('a software-rendered result does not warn that its numbers are not hardware figures');
  }
  return {ok: problems.length === 0, problems};
}

/** Find the BENCHMARK_RESULT payload in raw console output. */
export function parseConsole(output) {
  const lines = String(output).split(/\r?\n/).filter(line => line.startsWith('BENCHMARK_RESULT '));
  if (lines.length === 0) return {result: null, line: ''};
  const line = lines[lines.length - 1];
  try {
    return {result: JSON.parse(line.slice('BENCHMARK_RESULT '.length)), line};
  } catch (error) {
    return {result: null, line, error: error.message};
  }
}

/** One human line for a result, used by the runner and by the lead's notes. */
export function lineSummary(result) {
  const [width, height] = result.window?.size ?? [0, 0];
  const mode = result.honesty?.software_renderer ? 'software' : result.honesty?.renderer_class ?? 'unknown';
  return `${result.scene?.map ?? '?'} ${width}x${height} ${result.quality?.name ?? '?'} `
    + `median ${Number(result.aggregate?.median_ms ?? 0).toFixed(1)} ms · p95 ${Number(result.aggregate?.p95_ms ?? 0).toFixed(1)} ms · `
    + `${result.aggregate?.samples ?? 0} frames · draw calls ${Number(result.engine?.draw_calls_mean ?? 0).toFixed(0)} · ${result.environment?.adapter ?? '?'} (${mode})`;
}

/** Baseline-vs-candidate slowdown for two runs of the same composition. */
export function compareResults(baseline, candidate, threshold = 1.25) {
  for (const key of ['map', 'actor_count', 'bots']) {
    if (baseline.scene?.[key] !== candidate.scene?.[key]) throw new Error(`runs differ on scene.${key}`);
  }
  if (JSON.stringify(baseline.window?.size) !== JSON.stringify(candidate.window?.size)) throw new Error('runs differ on window.size');
  const ratio = key => {
    const a = Number(baseline.aggregate?.[key] ?? 0);
    const b = Number(candidate.aggregate?.[key] ?? 0);
    return a > 0 ? b / a : 0;
  };
  const median = ratio('median_ms');
  return {
    baseline: baseline.quality?.name, candidate: candidate.quality?.name,
    median_ratio: median, p95_ratio: ratio('p95_ms'),
    frames: [baseline.aggregate?.samples ?? 0, candidate.aggregate?.samples ?? 0],
    particles: [baseline.particles?.allocated_slots ?? 0, candidate.particles?.allocated_slots ?? 0],
    slower: median > threshold, threshold,
  };
}

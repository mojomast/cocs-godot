// TEST-ONLY native Horde upgrade loopback harness: UI -> actual authority -> snapshot.
//
// This is the missing positive proof for the Horde upgrade feature. The adapter
// tests only ever exercised REJECTION over a real socket, and the positive path
// used a pure source fixture with no transport. Here the ACTUAL product scene
// (res://horde/demo.tscn, run by godot/tests/horde/upgrade_live.gd) talks to the
// ACTUAL authority (`port/native-horde/authority.mjs`, a real source Match over
// a real local socket) and the operator selects with a real InputEventKey.
//
// TEST-ONLY ACCELERATED-OFFER FIXTURE (NOT natural three-wave gameplay):
// this process wraps `Match.prototype.step` for the duration of the run only
// (restored in `finally`, no source or adapter file is edited, no hook exists in
// any shippable module). After the wrapped original step, once the Horde state
// is live, the fixture sets `modeState.wave = 3` and calls the source's own
// `offerHordeUpgrade` — exactly the function the source calls on a natural
// wave-clear boundary. Only offer *timing* and the wave number are fixture
// values; identities, the choice list, validation, selection, application and
// every snapshot stay source/adapter-owned.
//
//   GODOT_BIN=/path/to/Godot node godot/tests/horde/upgrade_loopback.mjs
//
// A private Xvfb is started when no DISPLAY is present (the port needs a real
// window: the headless default viewport is 64x64). Exit code 0 only when every
// check passes; a JSON result line is always printed.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtempSync, mkdirSync, rmSync, existsSync, writeFileSync, copyFileSync} from 'node:fs';
import {createInterface} from 'node:readline';
import {resolve} from 'node:path';
import {Match} from '../../../game/core.mjs';
import {offerHordeUpgrade} from '../../../game/singleplayer.mjs';
import {createAuthority} from '../../../port/native-horde/authority.mjs';

const LABEL = 'TEST-ONLY accelerated-offer fixture (not natural 3-wave gameplay)';
const HARNESS = 'godot/tests/horde/upgrade_loopback.mjs';
const MAP = 'meridian-exchange';
const WAVES = 10;
const TIMEOUT_MS = 30000;
const ARTIFACT_DIR = process.env.HORDE_LOOPBACK_ARTIFACTS ?? '';
const binary = process.env.GODOT_BIN;
if (!binary) throw Error('GODOT_BIN must point at the pinned 4.5.2 engine');

const checks = [];
const check = (name, ok, detail = '') => { checks.push({name, ok: ok === true, detail}); return ok === true; };
const FAIL_RE = /SCRIPT ERROR|Parse Error|ERROR:/;

// ---------------------------------------------------------------------------
// Fixture: instrumented step in THIS process only.
// ---------------------------------------------------------------------------
const fixture = {activations: 0, raised: false, error: null, choices: null, wave: null, match: null, config: null};
const originalStep = Match.prototype.step;
function installFixture() {
  Match.prototype.step = function (...args) {
    const result = originalStep.apply(this, args);
    if (fixture.raised || fixture.error) return result;
    try {
      const state = this?.modeState;
      if (state && state.kind === 'horde' && state.phase === 'wave' && !state.pendingUpgrade) {
        fixture.activations += 1;
        fixture.match = this;
        state.wave = 3;                                   // fixture: wave number only
        const choices = offerHordeUpgrade(this, state);   // the source raiser, unchanged
        assert.ok(Array.isArray(choices) && choices.length === 3, 'source offered three rows');
        fixture.choices = [...choices];
        fixture.wave = state.wave;
        fixture.config = stableConfig(this.config);
        fixture.raised = true;
      }
    } catch (error) {
      fixture.error = error;
    }
    return result;
  };
}
const stableConfig = config => JSON.stringify({mode: config?.mode, botCount: config?.botCount,
  difficulty: config?.difficulty, fragLimit: config?.fragLimit, timeLimit: config?.timeLimit});

// ---------------------------------------------------------------------------
// Private display + product scene child.
// ---------------------------------------------------------------------------
async function startDisplay(env) {
  if (process.env.DISPLAY) return {display: process.env.DISPLAY, xvfb: null, private: false};
  const xvfb = spawn('Xvfb', ['-displayfd', '3', '-screen', '0', '640x400x24', '-nolisten', 'tcp', '-nolisten', 'unix'], {
    env, stdio: ['ignore', 'ignore', 'pipe', 'pipe']});
  xvfb.stderr.resume();
  const number = await Promise.race([
    new Promise((resolveNumber, reject) => {
      let text = '';
      const timer = setTimeout(() => reject(Error('Xvfb display timeout')), 5000);
      xvfb.stdio[3].on('data', chunk => {
        text += chunk;
        if (/^\d+\n$/.test(text)) { clearTimeout(timer); resolveNumber(text.trim()); }
      });
    }),
    new Promise((_, reject) => xvfb.once('error', reject)),
    new Promise((_, reject) => xvfb.once('exit', code => reject(Error(`Xvfb exited ${code}`)))),
  ]);
  env.DISPLAY = ':' + number;
  return {display: env.DISPLAY, xvfb, private: true};
}
const stop = child => new Promise(resolveExit => {
  if (!child || child.exitCode !== null || child.signalCode !== null) return resolveExit();
  child.once('exit', resolveExit);
  child.kill('SIGTERM');
  setTimeout(() => child.kill('SIGKILL'), 4000).unref();
});

// ---------------------------------------------------------------------------
// One run.
// ---------------------------------------------------------------------------
const temp = mkdtempSync('/tmp/horde-upgrade-loopback-');
const env = {...process.env};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']) {
  env[key] = resolve(temp, key);
  mkdirSync(env[key], {recursive: true});
}
const shotPrefix = resolve(temp, 'horde-upgrade');
const records = [];
const godot = [];
const fatal = [];
let child = null, display = null, xvfb = null, exit = null, timedOut = false, godotEvidence = null, godotShots = [];
let authorityStatus = {listening: false, clients: -1, closed: false};
let spawnError = null;
const copiedShots = [];

const authority = createAuthority({observe: record => records.push(record)});
installFixture();
try {
  await new Promise((resolveListen, reject) => {
    authority.server.once('error', reject);
    authority.server.listen(0, '127.0.0.1', resolveListen);
  });
  const port = authority.server.address().port;
  try {
    display = await startDisplay(env);
  } catch (error) {
    display = {display: null, xvfb: null, private: false, note: `headless fallback: ${error.message}`};
  }
  const argv = [
    ...(display.display ? [] : ['--headless']),
    ...(display.display ? ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '640x400'] : []),
    '--max-fps', '60', '--path', 'godot', '--script', 'res://tests/horde/upgrade_live.gd', '--',
    `--map=${MAP}`, `--waves=${WAVES}`, `--endpoint=ws://127.0.0.1:${port}`, `--shot=${shotPrefix}`,
  ];
  child = spawn(binary, argv, {env, stdio: ['ignore', 'pipe', 'pipe']});
  xvfb = display.xvfb;
  let settled = false;
  const finished = new Promise(resolveExit => {
    child.once('error', error => { spawnError = error; if (!settled) { settled = true; resolveExit(); } });
    child.once('exit', (code, signal) => { exit = {code, signal}; if (!settled) { settled = true; resolveExit(); } });
  });
  for (const stream of [child.stdout, child.stderr]) {
    createInterface({input: stream}).on('line', line => {
      godot.push(line);
      if (FAIL_RE.test(line)) {
        fatal.push(line);
        if (!timedOut) child.kill('SIGTERM');
      }
      if (line.startsWith('HORDE_UPGRADE_LIVE ')) {
        try { godotEvidence = JSON.parse(line.slice('HORDE_UPGRADE_LIVE '.length)); }
        catch (error) { fatal.push(`unparsable evidence line: ${error.message}`); }
      }
      if (line.startsWith('HORDE_UPGRADE_LIVE_SHOT ')) {
        try { godotShots.push(JSON.parse(line.slice('HORDE_UPGRADE_LIVE_SHOT '.length))); } catch {}
      }
    });
  }
  const deadline = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, TIMEOUT_MS);
  await finished;
  clearTimeout(deadline);
} finally {
  Match.prototype.step = originalStep;                       // fixture restored unconditionally
  await authority.close().catch(() => {});
  authorityStatus = {listening: authority.server.listening, clients: authority.wss.clients.size, closed: true};
  await stop(xvfb);
  await new Promise(flush => setTimeout(flush, 250));        // drain trailing child output
  if (ARTIFACT_DIR) {
    try {
      mkdirSync(ARTIFACT_DIR, {recursive: true});
      writeFileSync(resolve(ARTIFACT_DIR, 'horde-upgrade-live.log'), godot.join('\n'));
      const shotDir = resolve(ARTIFACT_DIR, 'horde-upgrade-shots');
      mkdirSync(shotDir, {recursive: true});
      for (const entry of godotShots) {
        if (entry.ok && existsSync(entry.path)) {
          const target = resolve(shotDir, entry.path.split('/').pop());
          copyFileSync(entry.path, target);
          copiedShots.push(target);
        }
      }
    } catch (error) {
      copiedShots.push(`artifact copy failed: ${error.message}`);
    }
  }
  rmSync(temp, {recursive: true, force: true});
  try { child?.kill('SIGKILL'); } catch {}
}

// ---------------------------------------------------------------------------
// Authoritative observer records.
// ---------------------------------------------------------------------------
const frame = record => record.frame ?? {};
const isOut = (record, type) => record.direction === 'out' && frame(record).type === type;
const lobbies = records.filter(record => isOut(record, 'lobby'));
const started = records.find(record => isOut(record, 'start'));
const snapshots = records.map((record, index) => ({index, state: isOut(record, 'snapshot') ? frame(record).state : null}))
  .filter(entry => entry.state?.singleplayer?.kind === 'horde');
const offerSnapshot = snapshots.find(entry => Array.isArray(entry.state.singleplayer.upgrades)
  && entry.state.singleplayer.upgrades.length === 3 && entry.state.singleplayer.upgradeCount === 0);
const appliedSnapshot = snapshots.find(entry => entry.state.singleplayer.upgradeCount === 1);
const applied = records.filter(r => r.direction === 'upgrade-applied');
const intent = records.find(r => r.direction === 'in' && frame(r).type === 'horde-upgrade');
const answer = records.find(r => r.direction === 'out' && frame(r).type === 'horde-upgrade-applied');
const rejected = records.filter(r => r.direction === 'upgrade-reject');
const controlResets = records.filter(r => r.direction === 'control-reset');
const transportErrors = records.filter(r => r.direction === 'transport-error');
const appliedAt = records.findIndex(r => r.direction === 'upgrade-applied');
const steps = records.map((r, index) => ({index, seq: r.inputSeq, received: r.receivedSeq})).filter(entry => entry.seq !== undefined && Number.isInteger(entry.seq));
const stepsAfter = steps.filter(entry => entry.index > appliedAt);
const monotonic = steps.every((entry, i) => i === 0 || entry.seq > steps[i - 1].seq);
const appliedChoice = applied[0]?.choice;
const offerIds = offerSnapshot ? offerSnapshot.state.singleplayer.upgrades.map(row => row.id) : null;
// Environment diagnostics: where the authority's 250 ms input TTL fired.
const nearestStep = (from, step) => {
  for (let index = from; index >= 0 && index < records.length; index += step) {
    const entry = records[index];
    if (entry.direction === 'step' && Number.isInteger(entry.inputSeq)) return {index, entry};
  }
  return null;
};
const resetContext = controlResets.map(entry => {
  const index = records.indexOf(entry);
  const before = nearestStep(index, -1);
  const after = nearestStep(index, 1);
  return {index, reason: entry.reason, seqBefore: before?.entry.inputSeq ?? null, seqAfter: after?.entry.inputSeq ?? null,
    gapBeforeMs: before ? Math.round(entry.observedMs - before.entry.observedMs) : null,
    gapAfterMs: after ? Math.round(after.entry.observedMs - entry.observedMs) : null,
    beforeOffer: offerSnapshot ? index < offerSnapshot.index : null};
});

// ---------------------------------------------------------------------------
// Checks.
// ---------------------------------------------------------------------------
check('fixture is labelled test-only', HARNESS.includes('upgrade_loopback') && LABEL.includes('TEST-ONLY'), LABEL);
check('fixture activated once', fixture.activations === 1 && fixture.raised === true, JSON.stringify({activations: fixture.activations, error: String(fixture.error)}));
check('fixture raised the source offer at wave 3', fixture.wave === 3 && Array.isArray(fixture.choices) && fixture.choices.length === 3, JSON.stringify(fixture.choices));
check('authority published the live round', Boolean(started) && lobbies.length > 0, JSON.stringify(lobbies.at(-1) ? frame(lobbies.at(-1)).config : null));
const lobbyConfig = lobbies.at(-1) ? frame(lobbies.at(-1)).config : null;
check('run settings stayed the reviewed solo Horde preset', lobbyConfig?.mode === 'horde' && lobbyConfig?.botCount === 0
  && lobbyConfig?.difficulty === 'easy' && lobbyConfig?.fragLimit === WAVES && frame(lobbies.at(-1)).mapId === MAP, JSON.stringify(lobbyConfig));
check('offer snapshot carries the source offer rows', Boolean(offerSnapshot) && offerSnapshot.state.singleplayer.upgradeWave === 3
  && offerSnapshot.state.singleplayer.upgradeCount === 0 && offerSnapshot.state.singleplayer.upgradeSelected === null,
  JSON.stringify(offerIds));
check('offer snapshot rows equal the fixture-raised source choices', JSON.stringify(offerIds) === JSON.stringify(fixture.choices), `${JSON.stringify(offerIds)} vs ${JSON.stringify(fixture.choices)}`);
check('exactly one authoritative upgrade-applied record', applied.length === 1, JSON.stringify(applied.map(r => ({choice: r.choice, wave: r.wave, count: r.count}))));
check('authoritative record has the live wave and count 1', applied[0]?.wave === 3 && applied[0]?.count === 1, JSON.stringify(applied[0] ?? null));
check('applied choice is one of the offered rows', Boolean(appliedChoice) && fixture.choices.includes(appliedChoice), String(appliedChoice));
check('applied snapshot closes the offer and carries the pick', Boolean(appliedSnapshot)
  && appliedSnapshot.state.singleplayer.upgradeSelected === appliedChoice
  && appliedSnapshot.state.singleplayer.upgrades.length === 0
  && appliedSnapshot.state.singleplayer.upgradeWave === null,
  JSON.stringify(appliedSnapshot ? appliedSnapshot.state.singleplayer : null));
check('no upgrade was refused or replayed', rejected.length === 0, JSON.stringify(rejected.map(r => r.reason)));
// The selection flight (live intent -> authoritative answer) must cross no
// input epoch boundary. Environment stalls that happen while the operator is
// still choosing are reported in `resetContext`; the native observer re-samples
// the epoch and re-checks the offer on the press frame by design.
check('live intent and its answer share one input epoch', Boolean(intent) && Boolean(answer)
  && frame(intent).inputEpoch === frame(answer).inputEpoch
  && frame(intent).choice === appliedChoice && frame(answer).choice === appliedChoice,
  JSON.stringify({intent: intent ? frame(intent) : null, answer: answer ? frame(answer) : null}));
check('no control reset after the intent was sent', controlResets.every(record => records.indexOf(record) < records.indexOf(intent)),
  JSON.stringify({total: controlResets.length, reasons: controlResets.map(r => r.reason), intentRecord: intent ? records.indexOf(intent) : null}));
check('no transport error ended the round', transportErrors.length === 0, JSON.stringify(transportErrors.map(r => r.reason)));
check('ordinary input sequence is monotonic and survived the selection', monotonic && stepsAfter.length >= 5
  && stepsAfter.at(-1).received >= stepsAfter[0].received,
  JSON.stringify({steps: steps.length, after: stepsAfter.length, last: stepsAfter.at(-1) ?? null}));
check('source match holds exactly the applied upgrade', Boolean(fixture.match)
  && JSON.stringify(fixture.match.modeState.upgrades) === JSON.stringify([appliedChoice])
  && fixture.match.modeState.pendingUpgrade === null && fixture.match.modeState.wave === 3,
  JSON.stringify({upgrades: fixture.match?.modeState?.upgrades, wave: fixture.match?.modeState?.wave}));
check('source run settings unchanged by the loop', Boolean(fixture.match) && stableConfig(fixture.match.config) === fixture.config, `${fixture.config} vs ${fixture.match ? stableConfig(fixture.match.config) : null}`);
check('native observer reported the same loopback', godotEvidence?.ok === true && godotEvidence?.failures === 0
  && godotEvidence?.chosen === appliedChoice && JSON.stringify(godotEvidence?.offer_ids) === JSON.stringify(fixture.choices)
  && godotEvidence?.offer_wave === 3,
  JSON.stringify(godotEvidence ? {ok: godotEvidence.ok, failures: godotEvidence.failures, chosen: godotEvidence.chosen, delivery: godotEvidence.delivery, status: godotEvidence.status_after_confirm, notes: godotEvidence.notes} : null));
check('native observer delivery path is a real engine input path', ['parse_input_event', 'viewport_push_input'].includes(godotEvidence?.delivery), String(godotEvidence?.delivery));
check('godot child exited cleanly with no ERROR/SCRIPT ERROR', exit?.code === 0 && fatal.length === 0 && !timedOut && !spawnError,
  JSON.stringify({exit, timedOut, spawnError: spawnError?.message ?? null, fatal: fatal.slice(0, 3)}));
check('authority closed with no live sockets', authorityStatus.closed === true && authorityStatus.listening === false && authorityStatus.clients === 0, JSON.stringify(authorityStatus));

const failures = checks.filter(entry => !entry.ok);
const result = {
  label: LABEL,
  harness: HARNESS,
  ok: failures.length === 0,
  checks: checks.length,
  failures: failures.length,
  failed: failures.map(entry => entry.name),
  fixture: {wave: fixture.wave, activated: fixture.activations, choices: fixture.choices},
  authority: {offerRows: offerIds, applied: applied.map(r => ({choice: r.choice, wave: r.wave, count: r.count})), rejects: rejected.length, controlResets: controlResets.length,
    intent: intent ? frame(intent) : null, answer: answer ? frame(answer) : null},
  native: godotEvidence ? {delivery: godotEvidence.delivery, checks: godotEvidence.checks, failures: godotEvidence.failures, chosen: godotEvidence.chosen, status: godotEvidence.status_after_confirm} : null,
  records: records.length,
  steps: {total: steps.length, afterApply: stepsAfter.length, monotonic},
  display: display?.display ?? null,
  shots: godotShots,
  copiedShots,
  godotExit: exit,
  resetContext,
};
console.log(`${result.ok ? 'HORDE_UPGRADE_LOOPBACK_OK' : 'HORDE_UPGRADE_LOOPBACK_FAIL'} ${JSON.stringify(result)}`);
for (const entry of failures) console.error(`FAILED CHECK: ${entry.name} :: ${entry.detail}`);
if (!result.ok) process.exitCode = 1;

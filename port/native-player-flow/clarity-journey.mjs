// Live native player-flow clarity journey for the Career reader.
//
// One owned authority and one real Godot session host a legal short source match
// (the session's own lobby path pins `timeLimit: 60`) and drive the shipped
// CAREER / ARSENAL panel through the states a player meets. The observer holds the
// client's own wire (only `client.set_process(false)`) so the pending and no-reply
// timeout states are observable, then releases it so the real source settles:
//   * pending  -> "awaiting source confirmation", no optimistic item;
//   * unknown  -> the 8 s no-reply timeout ("outcome unknown"), still no item;
//   * confirmed-> the source-marked GEAR reply names the item;
//   * results  -> the accepted round and same-round award XP in the pinned header.
// Each state is captured at 760x520 @150% and its text and bounds are asserted,
// not just the viewport root or Back. The projection never prints a credential.
//
// Pending/unknown are genuine wire states, not fabricated frames: the shipped
// client simply is not polled for a few seconds (the authority keeps running).
//
// Run from an integrated checkout:
//   GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
//     node port/native-player-flow/clarity-journey.mjs
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, writeFileSync, existsSync, rmSync, readFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import {recordedDerivative} from '../../tools/godot-dev/recorded_derivative.mjs';
import {MatchHistory} from '../../server/history.mjs';

const binary = process.env.GODOT_BIN;
assert.ok(binary, 'Set GODOT_BIN to the pinned editor');
const out = resolve(process.env.CAREER_CLARITY_OUT || 'port/native-player-flow/evidence/clarity');
assert.ok(!existsSync(out), `Preserve existing evidence: ${out}`);
mkdirSync(out, {recursive: true});
const temp = mkdtempSync('/tmp/opencode/native-player-flow-');
const children = [];
const wire = [];
const checks = [];
const samples = [];
const pass = (name, value = true) => { assert.ok(value, name); checks.push({name}); };
const sleep = ms => new Promise(r => setTimeout(r, ms));

function spawnOwned(name, cmd, args, options) {
  const p = spawn(cmd, args, options);
  p.name = name; p.text = ''; p.err = ''; p.samples = [];
  p.done = new Promise((res, rej) => { p.once('error', rej); p.once('close', res); });
  children.push(p);
  let buffer = '';
  p.stdout?.on('data', chunk => {
    p.text += chunk; buffer += chunk;
    let i;
    while ((i = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, i); buffer = buffer.slice(i + 1);
      if (line.startsWith('CAREER_CLARITY_SAMPLE ')) {
        const sample = JSON.parse(line.slice('CAREER_CLARITY_SAMPLE '.length));
        p.samples.push(sample); samples.push(sample);
      }
    }
  });
  p.stderr?.on('data', chunk => p.err += chunk);
  return p;
}

const latest = p => p.samples.at(-1);
async function until(predicate, ms, label) {
  const deadline = Date.now() + ms;
  for (;;) {
    const value = predicate();
    if (value) return value;
    if (Date.now() > deadline) throw new Error(`timeout: ${label}`);
    await sleep(100);
  }
}
const within = (rect, vw, vh) => rect.length === 4 && rect[0] >= -1 && rect[1] >= -1 && rect[0] + rect[2] <= vw + 1 && rect[1] + rect[3] <= vh + 1;
const compactLogical = s => s.back?.length === 4 && Math.abs(s.viewport[0] - 760 / 1.5) <= 1.5 && Math.abs(s.viewport[1] - 520 / 1.5) <= 1.5;

const env = {...process.env, HOME: temp, LIBGL_ALWAYS_SOFTWARE: '1',
  COCS_CAREER_ROOT: resolve(temp, 'career'),
  COCS_CAREER_CREDENTIALS_PATH: '', COCS_CAREER_SCOPE: '', COCS_CAREER_ENDPOINT: ''};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']) {
  env[key] = resolve(temp, key); mkdirSync(env[key], {recursive: true, mode: 0o700});
}
const careerRoot = resolve(temp, 'career');
const historyPath = join(careerRoot, 'history.json');
const progressionPath = join(careerRoot, 'progression.json');

const sourceLock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
const derivative = recordedDerivative();
assert.equal(execFileSync(binary, ['--version'], {encoding: 'utf8'}).trim(), sourceLock.godot_version, 'pinned engine version');
const summary = {port_commit: execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  source_commit: sourceLock.source_commit,
  source_derivative_commit: derivative?.commit ?? null,
  scope: 'One native client hosting a scripted source match on an owned authority; not human acceptance',
  checks: [], status: 'RUNNING'};
let game, observer, xvfb, expired = false;
const timer = setTimeout(() => { expired = true; for (const p of children) { try { p.kill('SIGTERM'); } catch {} } }, 300000);

try {
  xvfb = spawnOwned('xvfb', 'Xvfb', ['-displayfd', '3', '-screen', '0', '1600x900x24', '-nolisten', 'tcp', '-nolisten', 'unix'], {stdio: ['ignore', 'ignore', 'pipe', 'pipe']});
  const display = await new Promise((res, rej) => {
    let text = ''; const t = setTimeout(() => rej(Error('Xvfb startup')), 5000);
    xvfb.stdio[3].on('data', b => { text += b; if (text.includes('\n')) { clearTimeout(t); res(text.trim()); } });
  });
  env.DISPLAY = ':' + display;
  summary.display = env.DISPLAY;

  game = createGameServer({historyPath, progressionPath});
  game.wss.on('connection', socket => {
    socket.on('message', raw => { try { wire.push({dir: 'recv', frame: JSON.parse(String(raw))}); } catch {} });
    const send = socket.send;
    socket.send = function (data, ...rest) {
      try { wire.push({dir: 'send', frame: JSON.parse(String(data))}); } catch {}
      return send.call(this, data, ...rest);
    };
  });
  await new Promise((res, rej) => { game.server.once('error', rej); game.server.listen(0, '127.0.0.1', res); });
  const endpoint = `ws://127.0.0.1:${game.server.address().port}`;
  summary.port = game.server.address().port;
  summary.endpoint = endpoint;

  const inbox = resolve(temp, 'observer-inbox.json');
  observer = spawnOwned('observer', binary, ['--path', 'godot', '--audio-driver', 'Dummy', '--max-fps', '60',
    '--resolution', '1280x800', '--script', 'res://tests/player_flow/clarity_observer.gd', '--',
    '--lobby-menu', `--endpoint=${endpoint}`, '--map=meridian-exchange', '--mode=deathmatch',
    `--career-endpoint=${endpoint}`, '--career-map=meridian-exchange', '--career-mode=deathmatch',
    `--career-inbox=${inbox}`, `--career-out=${out}`], {env, stdio: ['ignore', 'pipe', 'pipe']});
  observer.inbox = inbox;

  const pending = await until(() => samples.find(s => s.pending_captured), 120000, 'pending capture');
  pass('the pending selection is held before the source can answer', pending.pending === true);
  pass('pending copy says awaiting source confirmation', String(pending.action_status).includes('awaiting'));
  pass('a pending selection is never named as saved', !String(pending.summary).includes(pending.equip.name));
  pass('pending is captured at the exact 760x520 @150% size', compactLogical(pending));
  await until(() => existsSync(resolve(out, 'clarity-pending-compact.png')), 10000, 'pending png');
  pass('pending readability captured', existsSync(resolve(out, 'clarity-pending-compact.png')));

  const unknown = await until(() => samples.find(s => s.unknown_captured), 30000, 'unknown capture');
  pass('the no-reply reader state is the honest timeout', unknown.timed_out === true);
  pass('the timeout copy stays unknown, not a refusal', String(unknown.action_status).includes('unknown'));
  pass('a timed-out selection is never named as saved', !String(unknown.summary).includes(unknown.equip.name));
  pass('unknown is captured at the exact 760x520 @150% size', compactLogical(unknown));
  await until(() => existsSync(resolve(out, 'clarity-unknown-compact.png')), 10000, 'unknown png');
  pass('unknown readability captured', existsSync(resolve(out, 'clarity-unknown-compact.png')));

  writeFileSync(inbox, JSON.stringify({id: 1, op: 'resume_wire'}));

  const confirmed = await until(() => samples.find(s => s.confirmed), 30000, 'confirmed state');
  pass('only the source reply settles the selection', confirmed.pending === false);
  pass('the confirmed saved summary names the item', String(confirmed.summary).includes(confirmed.equip.name));
  pass('confirmed is captured at the exact 760x520 @150% size', compactLogical(confirmed));
  await until(() => existsSync(resolve(out, 'clarity-confirmed-compact.png')), 10000, 'confirmed png');
  pass('confirmed readability captured', existsSync(resolve(out, 'clarity-confirmed-compact.png')));

  const results = await until(() => samples.find(s => s.results_captured), 180000, 'results capture');
  pass('the real session received an accepted source result', results.result.mode === 'deathmatch' && Boolean(results.result.map));
  pass('the pinned header shows the accepted round and award', String(results.state_text).includes('ROUND COMPLETE') && String(results.state_text).includes('XP'));
  pass('the RESULTS rows render the accepted result', results.rows.join('\n').includes('Round complete'));
  pass('the same-round source award was attributed', typeof results.attributed.gained === 'number');
  pass('results is captured at the exact 760x520 @150% size', compactLogical(results));
  await until(() => existsSync(resolve(out, 'clarity-results-compact.png')), 10000, 'results png');
  pass('results readability captured', existsSync(resolve(out, 'clarity-results-compact.png')));

  for (const [name, sample] of [['pending', pending], ['unknown', unknown], ['confirmed', confirmed], ['results', results]]) {
    const [vw, vh] = sample.viewport;
    pass(`${name}: Back stays inside the compact viewport`, within(sample.back, vw, vh));
    pass(`${name}: the reader rows stay within the compact width`, sample.rows_bounds.length === 4 && sample.rows_bounds[0] + sample.rows_bounds[2] <= vw + 1);
  }

  const awardIndex = wire.findIndex(f => f.dir === 'send' && f.frame.type === 'progression' && 'gained' in f.frame);
  const resultsIndex = wire.findIndex(f => f.dir === 'send' && f.frame.type === 'results');
  pass('the authority sent an award frame', awardIndex >= 0);
  pass('the authority sent a results frame', resultsIndex >= 0);
  pass('award precedes results on the real wire', awardIndex >= 0 && resultsIndex >= 0 && awardIndex < resultsIndex);

  const dumped = JSON.stringify(samples);
  pass('no ownership token serialized', !dumped.includes('ownerToken') && !dumped.includes('progressToken'));
  pass('no native script/parse/render errors', !/SCRIPT ERROR|Parse Error|ERROR:/.test(observer.text + observer.err));

  const persisted = await until(() => { try { return new MatchHistory(historyPath).all().length >= 1; } catch { return false; } }, 10000, 'persisted history');
  pass('the owned server persisted history.json', persisted === true && existsSync(historyPath));
  summary.history_entries = new MatchHistory(historyPath).all().length;
  summary.status = 'PASS';
} catch (error) {
  summary.status = 'FAIL'; summary.error = error?.stack || String(error); process.exitCode = 1;
} finally {
  clearTimeout(timer);
  for (const p of [...children].reverse()) {
    try { p.kill('SIGTERM'); } catch {}
    const kill = setTimeout(() => { try { p.kill('SIGKILL'); } catch {} }, 2500);
    try { await p.done; } catch {} finally { clearTimeout(kill); }
  }
  if (game) { for (const socket of game.wss.clients) socket.terminate(); await game.close(); }
  summary.checks = checks;
  summary.cleanup = children.map(p => ({name: p.name, exit_code: p.exitCode, signal: p.signalCode}));
  if (observer) writeFileSync(resolve(out, 'observer-last-sample.json'), JSON.stringify(latest(observer) ?? null, null, 2) + '\n');
  summary.wire = {frames: wire.length, award_index: wire.findIndex(f => f.dir === 'send' && f.frame.type === 'progression' && 'gained' in f.frame), results_index: wire.findIndex(f => f.dir === 'send' && f.frame.type === 'results'), sha256: createHash('sha256').update(JSON.stringify(wire)).digest('hex')};
  writeFileSync(resolve(out, 'summary.json'), JSON.stringify({...summary, expired}, null, 2) + '\n');
  rmSync(temp, {recursive: true, force: true});
  console.log(JSON.stringify({status: summary.status, checks: checks.length, error: summary.error}, null, 2));
}

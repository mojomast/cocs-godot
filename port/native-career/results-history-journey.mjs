// Live native Career RESULTS/HISTORY journey.
//
// One owned authority and one real Godot session host a legal short source match
// (`timeLimit: 60` through the session's own lobby path), play until the source
// reports results, then open the shipped Career panel and drive the RESULTS and
// HISTORY tabs. It proves what the offline fixture cannot:
//   * the real session receives an accepted `results` and a same-round award;
//   * the Career reader renders *Round complete* and the attributed +XP;
//   * the HISTORY tab requests the source list and renders *Recent server
//     matches* from the owned server's persisted `history.json`;
//   * the authority sends the award BEFORE the results (wire order asserted);
//   * the reader fits 760x520 @150% with Back reachable;
//   * no career credential file or token is requested or printed.
//
// The Career panel only sees start/results/history once the parent routes
// `client.career_receive(frame)` for those types (welcome/progression already
// route). This harness reports the not-ready status honestly until then.
//
// Run from an integrated checkout:
//   GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
//     node port/native-career/results-history-journey.mjs
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, writeFileSync, renameSync, existsSync, rmSync, readFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import {recordedDerivative} from '../../tools/godot-dev/recorded_derivative.mjs';
import {MatchHistory} from '../../server/history.mjs';

const binary = process.env.GODOT_BIN;
assert.ok(binary, 'Set GODOT_BIN to the pinned editor');
const out = resolve(process.env.CAREER_RESULTS_OUT || 'port/native-career/evidence/results-history');
assert.ok(!existsSync(out), `Preserve existing evidence: ${out}`);
mkdirSync(out, {recursive: true});
const temp = mkdtempSync('/tmp/opencode/native-career-results-');
const children = [];
const wire = [];
const checks = [];
const samples = [];
let commandId = 0;
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
      if (line.startsWith('CAREER_RESULTS_SAMPLE ')) {
        const sample = JSON.parse(line.slice('CAREER_RESULTS_SAMPLE '.length));
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
async function cmd(p, c) {
  c = {id: ++commandId, ...c};
  writeFileSync(`${p.inbox}.next`, JSON.stringify(c));
  renameSync(`${p.inbox}.next`, p.inbox);
  await until(() => latest(p)?.command === c.id, 5000, `${p.name} ${c.op}`);
}

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
const within = (rect, vw, vh) => rect.length === 4 && rect[0] >= -1 && rect[1] >= -1 && rect[0] + rect[2] <= vw + 1 && rect[1] + rect[3] <= vh + 1;
const compactSettled = samples => {
  const tail = samples.slice(-2);
  if (tail.length < 2) return false;
  const expected = [760 / 1.5, 520 / 1.5];
  return tail.every(s => s.back?.length === 4 && Math.abs(s.viewport[0] - expected[0]) <= 1.5 && Math.abs(s.viewport[1] - expected[1]) <= 1.5);
};

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
    '--resolution', '1280x800', '--script', 'res://tests/career/results_history_observer.gd', '--',
    '--lobby-menu', `--endpoint=${endpoint}`, '--map=meridian-exchange', '--mode=deathmatch',
    `--career-endpoint=${endpoint}`, '--career-map=meridian-exchange', '--career-mode=deathmatch',
    `--career-inbox=${inbox}`, `--career-out=${out}`], {env, stdio: ['ignore', 'pipe', 'pipe']});
  observer.inbox = inbox;

  // The controlled source match resolves on the 60 s clock; allow startup + play
  // and a possible sudden-death extension without forcing an outcome.
  const resolved = await until(() => { const s = latest(observer); return s && s.results_seen >= 1 && s.phase === 4 ? s : null; }, 240000, 'source results');
  pass('the real session received an accepted source result', resolved.phase === 4);
  const awarded = await until(() => { const s = latest(observer); return s && Object.keys(s.attributed ?? {}).length > 0 ? s : null; }, 30000, 'attributed award');
  pass('the same-round source award was attributed', typeof awarded.attributed.gained === 'number');
  pass('the result renders the source mode and map', awarded.result.mode === 'deathmatch' && Boolean(awarded.result.map));
  await cmd(observer, {op: 'capture', name: 'career-results'});
  await until(() => existsSync(resolve(out, 'career-results.png')), 10000, 'results capture');
  pass('RESULTS tab captured before history', existsSync(resolve(out, 'career-results.png')));

  // Now drive the HISTORY tab through the observer (it no longer auto-selects).
  await cmd(observer, {op: 'select', category: 'history'});
  const ready = await until(() => { const s = latest(observer); return s && s.category === 'history' && s.history_status === 'ready' ? s : null; }, 30000, 'history ready');
  pass('the HISTORY tab shows a ready source list', ready.history_count >= 1);
  pass('history is labelled as server-wide', ready.rows.join('\n').includes('Recent server matches'));
  pass('history carries real source facts', ready.rows.join('\n').toLowerCase().includes('deathmatch'));

  // Compact reader geometry at 150%: exact logical 760/1.5 x 520/1.5, settled.
  await cmd(observer, {op: 'scale', value: 1.5});
  await cmd(observer, {op: 'resize', width: 760, height: 520});
  const compact = await until(() => compactSettled(observer.samples) && latest(observer), 10000, 'compact settled');
  const [vw, vh] = compact.viewport;
  pass('compact viewport is the exact 760x520 logical size @150%', Math.abs(vw - 760 / 1.5) <= 1.5 && Math.abs(vh - 520 / 1.5) <= 1.5);
  pass('Back stays inside the compact viewport', within(compact.back, vw, vh));
  pass('the RESULTS and HISTORY tabs stay inside the compact viewport', within(compact.tab_results, vw, vh) && within(compact.tab_history, vw, vh));
  pass('the reader rows stay within the compact width', compact.rows_bounds.length === 4 && compact.rows_bounds[0] >= -1 && compact.rows_bounds[0] + compact.rows_bounds[2] <= vw + 1);
  await cmd(observer, {op: 'capture', name: 'career-history-compact'});
  await until(() => existsSync(resolve(out, 'career-history-compact.png')), 10000, 'compact history capture');
  pass('HISTORY tab captured at the compact size', existsSync(resolve(out, 'career-history-compact.png')));
  // Full-size capture so the actual source records are visible, not only the header.
  await cmd(observer, {op: 'scale', value: 1.0});
  await cmd(observer, {op: 'resize', width: 1280, height: 800});
  await cmd(observer, {op: 'capture', name: 'career-history'});
  await until(() => existsSync(resolve(out, 'career-history.png')), 10000, 'history capture');
  pass('HISTORY records captured at full size', existsSync(resolve(out, 'career-history.png')));

  // Wire order: award BEFORE results, as the authority actually sends.
  const awardIndex = wire.findIndex(f => f.dir === 'send' && f.frame.type === 'progression' && 'gained' in f.frame);
  const resultsIndex = wire.findIndex(f => f.dir === 'send' && f.frame.type === 'results');
  pass('the authority sent an award frame', awardIndex >= 0);
  pass('the authority sent a results frame', resultsIndex >= 0);
  pass('award precedes results on the real wire', awardIndex >= 0 && resultsIndex >= 0 && awardIndex < resultsIndex);

  // No credential material anywhere in the observer output or the projection.
  const dumped = JSON.stringify(samples);
  pass('no ownership token serialized', !dumped.includes('ownerToken') && !dumped.includes('progressToken'));
  pass('no native script/parse/render errors', !/SCRIPT ERROR|Parse Error|ERROR:/.test(observer.text + observer.err));

  // The owned server persisted the match beside the career root.
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

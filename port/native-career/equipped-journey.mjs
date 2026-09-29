// Live native Career saved-loadout journey.
//
// One owned authority and one real Godot session host a legal short source match
// (`timeLimit: 60` through the session's own lobby path). The observer opens the
// shipped Career panel, equips a level-one starter attachment through the
// displayed MODS tab, and proves on the real wire that:
//   * the source replied to the GEAR write and the reader is confirmed (never
//     optimistic before the reply);
//   * the saved LOADOUT summary names the confirmed attachment;
//   * the current match actor keeps its resolved, round-start loadout;
//   * after the authoritative restart the new actor carries the saved attachment.
// Plus the compact 760x520 @150% geometry and a no-credential sweep.
//
// The Career panel sees welcome/progression through the parent's routing; the
// shipped gameplay/lobby/authority are read-only. No unlock is granted and no
// human visual acceptance is claimed.
//
// Run from an integrated checkout:
//   GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
//     node port/native-career/equipped-journey.mjs
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, writeFileSync, renameSync, existsSync, rmSync, readFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';

const binary = process.env.GODOT_BIN;
assert.ok(binary, 'Set GODOT_BIN to the pinned editor');
const out = resolve(process.env.CAREER_EQUIPPED_OUT || 'port/native-career/evidence/equipped');
assert.ok(!existsSync(out), `Preserve existing evidence: ${out}`);
mkdirSync(out, {recursive: true});
const temp = mkdtempSync('/tmp/opencode/native-career-equipped-');
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
      if (line.startsWith('CAREER_NEWLOADOUT_SAMPLE ')) {
        const sample = JSON.parse(line.slice('CAREER_NEWLOADOUT_SAMPLE '.length));
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
const progressionPath = join(careerRoot, 'progression.json');

const sourceLock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
const derivative = process.env.COCS_SOURCE_DERIVATIVE ? JSON.parse(readFileSync(process.env.COCS_SOURCE_DERIVATIVE)) : null;
assert.equal(execFileSync(binary, ['--version'], {encoding: 'utf8'}).trim(), sourceLock.godot_version, 'pinned engine version');
const summary = {port_commit: execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  source_commit: sourceLock.source_commit,
  source_derivative_commit: derivative?.derivative_commit ?? null,
  scope: 'One native client equipping a saved attachment on an owned authority; not human acceptance',
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

  game = createGameServer({progressionPath});
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
    '--resolution', '1280x800', '--script', 'res://tests/career/newloadout_observer.gd', '--',
    '--lobby-menu', `--endpoint=${endpoint}`, '--map=meridian-exchange', '--mode=deathmatch',
    `--career-endpoint=${endpoint}`, '--career-map=meridian-exchange', '--career-mode=deathmatch',
    `--career-inbox=${inbox}`, `--career-out=${out}`], {env, stdio: ['ignore', 'pipe', 'pipe']});
  observer.inbox = inbox;

  // 1. The round starts, the panel opens on the LOADOUT tab and the equipping
  //    write is confirmed by the source (never before the progression reply).
  const confirmed = await until(() => { const s = latest(observer); return s && s.confirmed === true ? s : null; }, 90000, 'source-confirmed equip');
  pass('the panel opened on a source profile', confirmed.opened === true);
  pass('a saved attachment was confirmed by the source reply', confirmed.confirmed === true && confirmed.pending === false);
  const slot = confirmed.equip.slot;
  pass('the catalog names the confirmed attachment', Boolean(confirmed.saved?.fields?.attachments?.[slot]) && confirmed.saved.fields.attachments[slot].id === confirmed.equip.id);
  pass('the saved summary is labelled for the next match', String(confirmed.summary).includes('next match'));
  pass('the saved summary names the confirmed attachment', String(confirmed.summary).includes(confirmed.saved.fields.attachments[slot].name));
  // The current match actor keeps its resolved round-start attachments.
  pass('the current match actor was not rewritten by the saved write', Array.isArray(confirmed.actor_ids_before) && !confirmed.actor_ids_before.includes(confirmed.equip.id));

  // 2. Let the round resolve and restart; the next actor carries the saved mod.
  const rematch = await until(() => { const s = latest(observer); return s && s.restarted === true && Array.isArray(s.actor_ids_after) && s.actor_ids_after.length >= 0 && s.round_starts >= 2 ? s : null; }, 180000, 'next-match restart');
  pass('the authoritative next round started', rematch.round_starts >= 2);
  pass('the next match actor carries the saved attachment', Array.isArray(rematch.actor_ids_after) && rematch.actor_ids_after.includes(rematch.equip.id));

  // 3. Captures: the LOADOUT tab at full and compact sizes.
  await cmd(observer, {op: 'select', category: 'loadout'});
  await cmd(observer, {op: 'capture', name: 'career-loadout'});
  await until(() => existsSync(resolve(out, 'career-loadout.png')), 10000, 'loadout capture');
  pass('the LOADOUT tab was captured', existsSync(resolve(out, 'career-loadout.png')));

  await cmd(observer, {op: 'scale', value: 1.5});
  await cmd(observer, {op: 'resize', width: 760, height: 520});
  const compact = await until(() => compactSettled(observer.samples) && latest(observer), 10000, 'compact settled');
  const [vw, vh] = compact.viewport;
  pass('compact viewport is the exact 760x520 logical size @150%', Math.abs(vw - 760 / 1.5) <= 1.5 && Math.abs(vh - 520 / 1.5) <= 1.5);
  pass('Back stays inside the compact viewport', within(compact.back, vw, vh));
  pass('the LOADOUT tab stays inside the compact viewport', within(compact.tab_loadout, vw, vh));
  // The compact first screen must show real saved content, not only chrome:
  // the confirmed summary and the named equipped slot detail both start inside.
  const equippedName = compact.saved?.fields?.attachments?.[slot]?.name;
  const namedRow = (compact.row_rects ?? []).find(row => typeof row.text === 'string' && equippedName && row.text.includes(equippedName));
  pass('the saved loadout summary is visible in the compact first screen', within(compact.summary_rect, vw, vh));
  pass('the named equipped slot detail is visible in the compact first screen', Boolean(namedRow) && namedRow.rect[1] >= -1 && namedRow.rect[1] <= vh + 1);
  await cmd(observer, {op: 'capture', name: 'career-loadout-compact'});
  await until(() => existsSync(resolve(out, 'career-loadout-compact.png')), 10000, 'compact capture');
  pass('the LOADOUT tab was captured at the compact size', existsSync(resolve(out, 'career-loadout-compact.png')));

  // 4. Wire: the GEAR request carried a complete equipment map and the source
  //    replied with a progression frame carrying both maps.
  const requestIndex = wire.findIndex(f => f.dir === 'recv' && f.frame.type === 'gear');
  const replyIndex = wire.findIndex(f => f.dir === 'send' && f.frame.type === 'progression' && f.frame.attachments);
  pass('the client sent a GEAR write', requestIndex >= 0);
  pass('the source replied with an equipment progression frame', replyIndex >= 0);
  pass('the GEAR write carried a complete equipment map', requestIndex >= 0 && wire[requestIndex].frame.gear && wire[requestIndex].frame.attachments);
  const finished = samples.at(-1);
  pass('no ownership token serialized', !JSON.stringify(samples).includes('ownerToken') && !JSON.stringify(samples).includes('progressToken'));
  pass('no native script/parse/render errors', !/SCRIPT ERROR|Parse Error|ERROR:/.test(observer.text + observer.err));
  summary.equip = finished?.equip ?? null;
  summary.summary = finished?.summary ?? '';
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
  summary.wire = {frames: wire.length, gear_request_index: wire.findIndex(f => f.dir === 'recv' && f.frame.type === 'gear'), progression_index: wire.findIndex(f => f.dir === 'send' && f.frame.type === 'progression' && f.frame.attachments), sha256: createHash('sha256').update(JSON.stringify(wire)).digest('hex')};
  writeFileSync(resolve(out, 'summary.json'), JSON.stringify({...summary, expired}, null, 2) + '\n');
  rmSync(temp, {recursive: true, force: true});
  console.log(JSON.stringify({status: summary.status, checks: checks.length, error: summary.error}, null, 2));
}

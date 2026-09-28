// Live native social journey: one real authority, two real rooms, and two native
// Godot clients driven through the actual lobby/chat UI. Proves what the offline
// fixture cannot:
//   * the guest browses the live room list, selects the host's row through the UI,
//     and the advertised (non-default) map/mode is populated so the join passes
//     strict validate_map;
//   * the guest opens live chat, types, and a source `chat` frame is queued and
//     echoed back into the UI log;
//   * a third protocol client seated in a different room never receives the line;
//   * while chat is open, typed W and a click produce no actor move or fire;
//   * the chat closes on a fresh click and the guest can leave while the external
//     host room keeps running;
//   * the chat toggle/panel fit 960x640 and 1280x800 at 150% interface scale.
//
// Run (private Xvfb is started by this harness):
//   GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 \
//     node port/native-social/social_journey.mjs
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, writeFileSync, renameSync, existsSync, rmSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import WebSocket from 'ws';

const binary = process.env.GODOT_BIN;
assert.ok(binary, 'Set GODOT_BIN to the pinned editor');
const hostMap = 'verdant-reliquary';
const hostMode = 'teamdeathmatch';
const guestDefaultMap = 'meridian-exchange';
const out = resolve(process.env.SOCIAL_JOURNEY_OUT || 'port/native-social/evidence/meridian-verdant');
assert.ok(!existsSync(out), `Preserve existing evidence: ${out}`);
mkdirSync(out, {recursive: true});
const temp = mkdtempSync('/tmp/opencode/native-social-');
const children = [];
const wire = [];
const checks = [];
let recipientSeq = 0;
let commandId = 0;
let timeline = Date.now();

const pass = (name, value = true) => { assert.ok(value, name); checks.push({name, wall: Date.now() - timeline}); };
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function until(predicate, ms, label) {
  const deadline = Date.now() + ms;
  for (;;) {
    const value = predicate();
    if (value) return value;
    if (Date.now() > deadline) throw new Error(`timeout: ${label}`);
    await sleep(50);
  }
}
function spawnOwned(name, cmd, args, options) {
  const p = spawn(cmd, args, options);
  p.name = name; p.text = ''; p.err = ''; p.samples = [];
  p.done = new Promise((res, rej) => { p.once('error', rej); p.once('close', res); });
  children.push(p);
  if (p.stdout) {
    let buffer = '';
    p.stdout.on('data', chunk => {
      p.text += chunk; buffer += chunk;
      let i;
      while ((i = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, i); buffer = buffer.slice(i + 1);
        if (line.startsWith('SOCIAL_SAMPLE ')) p.samples.push(JSON.parse(line.slice(14)));
      }
      if (p.text.length > 32 * 1024 * 1024) p.kill('SIGTERM');
    });
  }
  p.stderr?.on('data', chunk => p.err += chunk);
  return p;
}
const latest = p => p.samples.at(-1);
function nativeClient(name, map, mode, width, height, position, endpoint) {
  const inbox = resolve(temp, `${name}.json`);
  const p = spawnOwned(name, binary, ['--path', 'godot', '--audio-driver', 'Dummy', '--max-fps', '60', '--resolution', `${width}x${height}`, '--position', position, '--script', 'res://tests/protocol/lobby_social_observer.gd', '--', '--lobby-menu', `--endpoint=${endpoint}`, `--map=${map}`, `--mode=${mode}`, `--lobby-inbox=${inbox}`, `--lobby-out=${out}`], {env, stdio: ['ignore', 'pipe', 'pipe']});
  Object.assign(p, {inbox, width, height});
  return p;
}
async function cmd(p, c) {
  c = {id: ++commandId, ...c};
  writeFileSync(`${p.inbox}.next`, JSON.stringify(c));
  renameSync(`${p.inbox}.next`, p.inbox);
  await until(() => latest(p)?.command === c.id, 4000, `${p.name} command ${c.op}`);
}
async function click(p, name) {
  let ui = latest(p).ui[name];
  assert.ok(ui && ui.visible, `click target visible: ${name}`);
  // Focus the control first so a scroll-following container brings it into view.
  await cmd(p, {op: 'focus_named', name});
  await sleep(150);
  ui = latest(p).ui[name];
  const [x, y, w, h] = ui.rect;
  await cmd(p, {op: 'focus'});
  await cmd(p, {op: 'mouse', x: x + w / 2, y: y + h / 2, pressed: true});
  await cmd(p, {op: 'mouse', x: x + w / 2, y: y + h / 2, pressed: false});
}
async function typeText(p, text) { await cmd(p, {op: 'text', text}); }
async function waitFor(p, pred, ms, label) { return until(() => { const sample=latest(p); return sample && pred(sample); }, ms, `${p.name} ${label}`); }

const env = {...process.env, HOME: temp, LIBGL_ALWAYS_SOFTWARE: '1', COCS_CAREER_ROOT:resolve(temp,'career'),
  COCS_CAREER_CREDENTIALS_PATH:'', COCS_CAREER_SCOPE:'', COCS_CAREER_ENDPOINT:''};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']) { env[key] = resolve(temp, key); mkdirSync(env[key], {recursive: true, mode: 0o700}); }

const sourceLock=JSON.parse(readFileSync('port/contracts/source-lock.json'));
const derivative=process.env.COCS_SOURCE_DERIVATIVE?JSON.parse(readFileSync(process.env.COCS_SOURCE_DERIVATIVE)):null;
assert.equal(execFileSync(binary,['--version'],{encoding:'utf8'}).trim(),sourceLock.godot_version);
const summary = {port_commit:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
  source_commit:sourceLock.source_commit,source_derivative_commit:derivative?.derivative_commit??null,
  scope:'Two native clients with scripted UI actions on an owned source authority; not human acceptance',
  hostMap, hostMode, checks: [], status: 'RUNNING'};
let game, host, guest, third, xvfb, expired = false;
const timer = setTimeout(() => { expired = true; for (const p of children) { try { p.kill('SIGTERM'); } catch {} } }, 180000);

try {
  // Private Xvfb picked from its own displayfd, never a shared display.
  xvfb = spawnOwned('xvfb', 'Xvfb', ['-displayfd', '3', '-screen', '0', '2300x900x24', '-nolisten', 'tcp', '-nolisten', 'unix'], {stdio: ['ignore', 'ignore', 'pipe', 'pipe']});
  const display = await new Promise((res, rej) => {
    let text = ''; const t = setTimeout(() => rej(Error('Xvfb startup')), 5000);
    xvfb.stdio[3].on('data', b => { text += b; if (text.includes('\n')) { clearTimeout(t); res(text.trim()); } });
  });
  env.DISPLAY = ':' + display;
  summary.display = env.DISPLAY;

  // Real authority; wrap every socket to record the exact frames delivered.
  game = createGameServer({historyPath: null, progressionPath: null});
  game.wss.on('connection', socket => {
    const recipient = recipientSeq++;
    socket.__recipient = recipient;
    socket.on('message', raw => { try { wire.push({recipient, dir: 'recv', frame: JSON.parse(String(raw))}); } catch {} });
    const send = socket.send;
    socket.send = function (data, ...rest) {
      try { wire.push({recipient, dir: 'send', frame: JSON.parse(String(data))}); } catch {}
      return send.call(this, data, ...rest);
    };
  });
  await new Promise((res, rej) => { game.server.once('error', rej); game.server.listen(0, '127.0.0.1', res); });
  summary.port = game.server.address().port;
  const endpoint = `ws://127.0.0.1:${summary.port}`;

  // Host creates a room on the non-default map through the real UI.
  host = nativeClient('host', hostMap, hostMode, 960, 640, '0,0', endpoint);
  await waitFor(host, s => s.phase === -3, 30000, 'menu');
  await cmd(host, {op: 'focus'});
  await click(host, 'connect_button');
  await waitFor(host, s => s.phase === 12, 15000, 'host lobby');
  summary.hostRoom = latest(host).room;
  pass('host created a room on the advertised non-default map', latest(host).selected_map === hostMap);

  // A third protocol client seats in a different room.
  third = new WebSocket(endpoint);
  const thirdFrames = [];
  third.on('message', raw => thirdFrames.push(JSON.parse(String(raw))));
  await new Promise((res, rej) => { third.once('open', res); third.once('error', rej); });
  third.send(JSON.stringify({type: 'create', name: 'Other room', playerName: 'Other', character: 'chatgpt', harness: 'openclaw', v: 3, delta: 0}));
  const thirdWelcome = await until(() => thirdFrames.find(f => f.type === 'welcome'), 5000, 'third welcome');
  pass('third client is in a different room', thirdWelcome.roomId !== summary.hostRoom);

  // Guest starts on the default map, browses, selects the host row via the UI.
  guest = nativeClient('guest', guestDefaultMap, 'deathmatch', 1280, 800, '980,0', endpoint);
  await waitFor(guest, s => s.phase === -3, 30000, 'menu');
  await cmd(guest, {op: 'focus'});
  const endpointField = latest(guest).ui.endpoint;
  assert.ok(endpointField.visible, 'endpoint field visible');
  await click(guest, 'endpoint');
  await cmd(guest, {op: 'key', key: 'A', pressed: true, ctrl: true});
  await cmd(guest, {op: 'key', key: 'A', pressed: false, ctrl: true});
  await typeText(guest, endpoint);
  await until(() => latest(guest).ui.endpoint.text === endpoint, 5000, 'guest endpoint text');
  await click(guest, 'browse');
  await waitFor(guest, s => s.rooms.some(r => r.code === summary.hostRoom), 15000, 'browse lists host room');
  pass('guest listed the host room from the entered endpoint', latest(guest).bound.includes(endpoint));
  const rowIndex = latest(guest).rooms.findIndex(r => r.code === summary.hostRoom);
  await click(guest, `room_${rowIndex}`);
  await until(() => latest(guest).ui.room.text === summary.hostRoom, 5000, 'row selection fills the code');
  pass('selecting the Verdant room populated its advertised map', latest(guest).selected_map === hostMap);
  pass('selecting the Verdant room populated its advertised mode', latest(guest).selected_mode === hostMode);
  await cmd(guest, {op:'capture',name:'room-browser'});

  // Compact 150% layout while seated in the lobby.
  await cmd(guest, {op: 'scale', value: 1.5});
  for (const [w, h] of [[960, 640], [1280, 800]]) {
    await cmd(guest, {op: 'resize', width: w, height: h});
    await sleep(250);
    const s = latest(guest);
    const [vx, vy, vw, vh] = s.viewport;
    for (const name of ['chat_toggle', 'chat_panel']) {
      const [x, y, cw, ch] = s.ui[name].rect;
      pass(`${name} fits ${w}x${h} @150%`, x >= -1 && y >= -1 && x + cw <= vw + 1 && y + ch <= vh + 1);
    }
  }
  await cmd(guest, {op: 'scale', value: 1.0});
  await cmd(guest, {op: 'resize', width: 1280, height: 800});

  await click(guest, 'connect_button');
  await waitFor(guest, s => s.phase === 11 || s.phase === 3, 15000, 'guest joined');
  pass('guest joined the Verdant room (no map substitution teardown)', latest(guest).phase === 11 && latest(guest).map === hostMap);

  await click(host, 'start_button');
  await waitFor(host, s => s.phase === 3 && s.pose, 15000, 'host live');
  await waitFor(guest, s => s.phase === 3 && s.pose, 15000, 'guest live');
  pass('both native clients are in the live round', latest(host).revision === latest(guest).revision);

  // Chat: open, verify typing suspends movement/fire, send, wait for the echo.
  const before = latest(guest);
  await click(guest, 'chat_toggle');
  await waitFor(guest, s => s.capturing, 5000, 'chat open');
  await click(guest, 'chat_input');
  await typeText(guest, 'W');
  await cmd(guest, {op: 'mouse', x: 640, y: 400, pressed: true});
  await cmd(guest, {op: 'mouse', x: 640, y: 400, pressed: false});
  await sleep(900);
  const during = latest(guest);
  pass('chat holds the pointer (no capture while typing)', during.captured === false && during.eligible === false);
  pass('typing W while chat is open did not move the actor', during.local.x === before.local.x && during.local.z === before.local.z);
  pass('clicking while chat is open did not fire', during.local.shots === before.local.shots);
  pass('the typed character landed in the chat draft', during.ui.chat_input.text.includes('W'));

  await cmd(guest, {op: 'key', key: 'Enter', pressed: true});
  await cmd(guest, {op: 'key', key: 'Enter', pressed: false});
  await until(() => wire.some(f => f.dir === 'recv' && f.frame.type === 'chat' && f.frame.text === 'W'), 5000, 'source chat frame received');
  pass('the guest queued a source chat frame', wire.some(f => f.dir === 'recv' && f.frame.type === 'chat' && f.frame.text === 'W'));
  await waitFor(guest, s => s.chat_log.some(line => line.includes('W')), 5000, 'chat echo rendered in the UI');
  pass('the source echo rendered in the native chat log', latest(guest).chat_log.some(line => line.includes('W') && line.includes('you')));
  await cmd(guest, {op:'capture',name:'live-room-chat'});

  // Room scope at the authority: only members of the host room receive chat.
  const chatRecipients = new Set(wire.filter(f => f.dir === 'send' && f.frame.type === 'chat').map(f => f.recipient));
  const roomByRecipient = new Map(wire.filter(f => f.dir === 'send' && f.frame.type === 'welcome').map(f => [f.recipient, f.frame.roomId]));
  const thirdRecipient = wire.find(f => f.dir === 'recv' && f.frame.type === 'create' && f.frame.name === 'Other room')?.recipient;
  pass('chat was delivered only inside the host room', [...chatRecipients].every(r => roomByRecipient.get(r) === summary.hostRoom));
  pass('the third client in the other room received no chat', thirdRecipient !== undefined && !chatRecipients.has(thirdRecipient));

  // Close on a fresh click, then leave; the external host room keeps running.
  await click(guest, 'chat_close');
  await waitFor(guest, s => !s.capturing, 5000, 'chat closed by click');
  pass('a fresh click closed the chat panel', !latest(guest).capturing);
  const hostRevision = latest(host).revision;
  await click(guest, 'leave_button');
  await waitFor(guest, s => s.phase === -3, 10000, 'guest left');
  pass('guest left to a clean disconnected state', latest(guest).room === '' && latest(guest).actor === -1);
  await sleep(1500);
  pass('the external host left the room running', latest(host).phase === 3 && latest(host).revision === hostRevision);

  pass('no native script errors', [host, guest].every(p => !/SCRIPT ERROR|Parse Error|ERROR:/.test(p.text + p.err)));
  summary.status = 'PASS';
} catch (error) {
  summary.status = 'FAIL'; summary.error = error?.stack || String(error); process.exitCode = 1;
} finally {
  clearTimeout(timer);
  for (const p of [...children].reverse()) {
    try { p.kill('SIGTERM'); } catch {}
    const kill=setTimeout(()=>{try{p.kill('SIGKILL');}catch{}},2500);
    try { await p.done; } catch {} finally { clearTimeout(kill); }
  }
  if (third) { try { third.terminate(); } catch {} }
  if (game) { for (const socket of game.wss.clients) socket.terminate(); await game.close(); }
  summary.checks = checks;
  summary.cleanup = children.map(p=>({name:p.name,pid:p.pid,exit_code:p.exitCode,signal:p.signalCode}));
  summary.wire = {frames: wire.length, sha256: createHash('sha256').update(JSON.stringify(wire)).digest('hex')};
  writeFileSync(resolve(out, 'summary.json'), JSON.stringify({...summary, expired}, null, 2) + '\n');
  rmSync(temp, {recursive: true, force: true});
  console.log(JSON.stringify({status: summary.status, checks: checks.length, hostRoom: summary.hostRoom, error: summary.error}, null, 2));
}

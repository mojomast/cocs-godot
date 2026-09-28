// Native social authority contract: the exact `list`/`rooms` and `chat` wire
// verbs the Godot room browser and chat panel consume. It drives the real
// `server/game-server.mjs` over real WebSockets, so it proves the source facts
// the native UI is built on:
//   * `{type:'list'}` answers `{type:'rooms', rooms:[summary,...]}` where each
//     summary exposes roomId/name/mapId/config.mode/players/started;
//   * `{type:'chat', text}` is sanitized (control-strip + trim + 200) and
//     broadcast only inside the sender's room (no cross-room leakage), and a
//     spectator seated in the room shares that scope;
//   * the source 300 ms per-peer chat floor drops a burst;
//   * `chat` without a seat, and an unknown verb, answer a correlated `error`.
//
// Run: node --test port/native-social/social_authority.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {createGameServer} from '../../server/game-server.mjs';
import WebSocket from 'ws';

const CHAR = 'chatgpt';
const HARNESS = 'openclaw';

function connect(port) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  const frames = [];
  const waiters = [];
  ws.on('message', raw => {
    const frame = JSON.parse(String(raw));
    frames.push(frame);
    for (const waiter of [...waiters]) if (waiter.predicate(frame)) waiters.splice(waiters.indexOf(waiter), 1)[0].resolve(frame);
  });
  const api = {
    ws,
    frames,
    send: frame => ws.send(JSON.stringify(frame)),
    open: () => new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); }),
    wait: (predicate, label, ms = 3000) => new Promise((resolve, reject) => {
      const found = frames.find(predicate);
      if (found) return resolve(found);
      const entry = {predicate, resolve: frame => { clearTimeout(timer); resolve(frame); }};
      const timer = setTimeout(() => { waiters.splice(waiters.indexOf(entry), 1); reject(new Error(`timeout: ${label}`)); }, ms);
      waiters.push(entry);
    }),
    close: () => new Promise(resolve => { if (ws.readyState === WebSocket.CLOSED) return resolve(); ws.once('close', resolve); ws.close(); }),
  };
  return api;
}

async function withServer(t) {
  const game = createGameServer({historyPath: null, progressionPath: null});
  await new Promise((resolve, reject) => { game.server.once('error', reject); game.server.listen(0, '127.0.0.1', resolve); });
  const port = game.server.address().port;
  const clients = [];
  t.after(async () => {
    for (const client of clients) { try { client.ws.terminate(); } catch {} }
    await game.close();
  });
  return {
    game,
    port,
    connect: () => { const client = connect(port); clients.push(client); return client; },
  };
}

async function seat(port, {name, roomName, roomId = '', spectate = false}) {
  const client = connect(port);
  await client.open();
  if (roomId) client.send({type: 'join', roomId, name, character: CHAR, harness: HARNESS, v: 3, delta: 0, spectate});
  else client.send({type: 'create', name: roomName, playerName: name, character: CHAR, harness: HARNESS, v: 3, delta: 0});
  const welcome = await client.wait(f => f.type === 'welcome', `welcome ${name}`);
  return {client, roomId: welcome.roomId, peerId: welcome.peerId, spectate: welcome.spectate === true};
}

test('list answers rooms with the exact summary fields the browser renders', async t => {
  const s = await withServer(t);
  const a = await seat(s.port, {name: 'Host A', roomName: 'Alpha room'});
  const b = await seat(s.port, {name: 'Host B', roomName: 'Bravo room'});
  assert.notEqual(a.roomId, b.roomId, 'two distinct room codes');

  const browser = s.connect();
  await browser.open();
  browser.send({type: 'list'});
  const reply = await browser.wait(f => f.type === 'rooms', 'rooms reply');
  assert.ok(Array.isArray(reply.rooms), 'rooms is an array');

  const byCode = Object.fromEntries(reply.rooms.map(room => [room.roomId, room]));
  for (const code of [a.roomId, b.roomId, 'local']) assert.ok(byCode[code], `summary present for ${code}`);
  const alpha = byCode[a.roomId];
  assert.equal(alpha.name, 'Alpha room', 'create name is the advertised room name');
  for (const field of ['roomId', 'name', 'players', 'started', 'mapId', 'config']) assert.ok(field in alpha, `summary carries ${field}`);
  assert.equal(typeof alpha.players, 'number', 'players is a count, not a list');
  assert.equal(alpha.started, false, 'a fresh room is not started');
  assert.equal(alpha.mapId, 'exchange', 'the default map id is advertised unchanged');
  // An unconfigured room advertises `config: null`: the browser must treat the
  // mode as unknown rather than infer it.
  assert.equal(alpha.config, null, 'unconfigured room config is null, never a guessed mode');

  await browser.close();
});

test('chat is room-scoped, sanitized, and shared with a seated spectator', async t => {
  const s = await withServer(t);
  const a = await seat(s.port, {name: 'Host A', roomName: 'Alpha room'});
  const b = await seat(s.port, {name: 'Host B', roomName: 'Bravo room'});
  const spectator = await seat(s.port, {name: 'Watcher', roomId: a.roomId, spectate: true});
  assert.equal(spectator.spectate, true, 'source seated an explicit spectator');
  const outsider = await seat(s.port, {name: 'Outsider', roomId: b.roomId});

  const raw = '  hi\u0007 <b>all</b>\n'.padEnd(260, 'x');
  a.client.send({type: 'chat', text: raw});
  const line = await a.client.wait(f => f.type === 'chat', 'author self echo');
  assert.equal(line.peerId, 1, 'the sender peer id is echoed');
  assert.equal(line.name, 'Host A', 'the seated name is echoed');
  assert.equal(line.text.length, 200, 'the source 200-char ceiling is applied');
  assert.ok(!line.text.includes('\u0007'), 'control characters are stripped');
  assert.ok(!line.text.includes('\n'), 'embedded newlines are stripped');
  assert.ok(line.text.startsWith('hi'), 'leading whitespace is trimmed and content preserved');

  const spectatorLine = await spectator.client.wait(f => f.type === 'chat', 'spectator receives room chat');
  assert.equal(spectatorLine.text, line.text, 'a seated spectator shares the room chat scope');

  const outsiderChats = outsider.client.frames.filter(f => f.type === 'chat');
  assert.equal(outsiderChats.length, 0, 'a peer in another room never receives the line');

  // The spectator can speak back into the same room; the host hears it.
  const before = a.client.frames.filter(f => f.type === 'chat').length;
  spectator.client.send({type: 'chat', text: 'spectator speaking'});
  await a.client.wait(f => f.type === 'chat' && f.text === 'spectator speaking', 'host hears spectator');
  assert.equal(a.client.frames.filter(f => f.type === 'chat').length, before + 1, 'exactly one spectator line arrives');

  await Promise.all([a.client.close(), b.client.close(), spectator.client.close(), outsider.client.close()]);
});

test('the source ceiling counts UTF-16 units and trims JS whitespace', async t => {
  const s = await withServer(t);
  const a = await seat(s.port, {name: 'Host A', roomName: 'Alpha room'});
  a.client.send({type: 'chat', text: `${'😀'.repeat(150)}\u00a0`});
  const emoji = await a.client.wait(f => f.type === 'chat', 'emoji chat reply');
  assert.equal([...emoji.text].length, 100, 'cuts at 100 supplementary codepoints, not 200, because each emoji is two UTF-16 units');
  assert.equal(emoji.text.length, 200, 'the echoed text is exactly 200 UTF-16 units');
  assert.ok(!emoji.text.includes('\u00a0'), 'the trailing JS whitespace was trimmed');

  await new Promise(resolve => setTimeout(resolve, 400));
  a.client.send({type: 'chat', text: '\ufeff\u00a0hello\u3000'});
  const trimmed = await a.client.wait(f => f.type === 'chat' && f.text === 'hello', 'JS trim reply');
  assert.equal(trimmed.text, 'hello', 'JS trim removes FEFF/NBSP/ideographic whitespace');
  await a.client.close();
});

test('the 300 ms source floor drops a same-peer chat burst', async t => {
  const s = await withServer(t);
  const a = await seat(s.port, {name: 'Host A', roomName: 'Alpha room'});
  a.client.send({type: 'chat', text: 'first'});
  a.client.send({type: 'chat', text: 'second'});
  a.client.send({type: 'chat', text: 'third'});
  await a.client.wait(f => f.type === 'chat' && f.text === 'first', 'first line');
  await new Promise(resolve => setTimeout(resolve, 400));
  const texts = a.client.frames.filter(f => f.type === 'chat').map(f => f.text);
  assert.deepEqual(texts, ['first'], 'only the first line inside the floor is broadcast; the rest are dropped');
  await a.client.close();
});

test('chat without a seat and an unknown verb answer a correlated error', async t => {
  const s = await withServer(t);
  const browser = s.connect();
  await browser.open();
  browser.send({type: 'chat', text: 'hello?'});
  const refusal = await browser.wait(f => f.type === 'error', 'not-in-a-room error');
  assert.equal(refusal.message, 'not in a room', 'the exact client social-refusal message');
  assert.ok(!('code' in refusal), 'it is a plain message frame, so the client keeps the connection');

  browser.send({type: 'definitely-not-a-verb'});
  const unknown = await browser.wait(f => f.type === 'error' && /unknown message type/.test(f.message ?? ''), 'unknown verb error');
  assert.ok(unknown, 'unknown verbs stay a correlated error');
  await browser.close();
});

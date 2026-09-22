// Boundary proof: the multi-human room path (locked server/**) gains NOTHING.
// A real two-human room over a real socket answers a debug frame with its
// existing unknown-message error, and the running match is untouched.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync, readdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createGameServer} from '../../server/game-server.mjs';

const root = resolve(import.meta.dirname, '../..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
function connect(url) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    const frames = [];
    ws.onmessage = event => frames.push(JSON.parse(event.data));
    ws.onopen = () => resolve({ws, frames, send: msg => ws.send(JSON.stringify(msg))});
    ws.onerror = () => reject(new Error('connection failed'));
  });
}
async function until(client, type, timeout = 15000) {
  const started = Date.now();
  while (Date.now() - started < timeout) {
    const frame = client.frames.find(item => item.type === type);
    if (frame) return frame;
    await sleep(20);
  }
  throw new Error(`timeout waiting for ${type}; saw ${client.frames.slice(-6).map(f => f.type)}`);
}

test('a real two-human room rejects a debug frame and its match is untouched', {timeout:60000}, async () => {
  const {server, close, registry} = createGameServer({tickDt:1 / 6, historyPath:null, progressionPath:null});
  await new Promise(resolve => server.listen(0, resolve));
  const url = `ws://127.0.0.1:${server.address().port}`;
  const a = await connect(url), b = await connect(url);
  try {
    a.send({type:'join', name:'Alice', character:'chatgpt', harness:'openclaw'});
    b.send({type:'join', name:'Bob', character:'claude', harness:'hermes'});
    await until(a, 'welcome'); await until(b, 'welcome');
    await until(a, 'lobby');
    a.send({type:'host', mapId:'crosswire', config:{mode:'instagib', botCount:2, fragLimit:5, timeLimit:60, difficulty:'easy'}});
    a.send({type:'start'});
    await until(a, 'start'); await until(b, 'snapshot');
    const room = registry.rooms.get('local');
    assert.ok(room?.match, 'the multi-human room owns a live match');
    assert.equal(room.match.actors.length, 4, 'two humans plus two bots');
    const before = {...room.match.config};
    const damageBefore = room.match.mutators.damageMultiplier;
    const healthBefore = room.match.actors[0].health;

    for (const client of [a, b]) {
      const mark = client.frames.length;
      client.send({type:'debug', v:1, godMode:true, damage:2, botCount:8, unlockAllWeapons:true});
      const error = await new Promise((resolve, reject) => {
        const started = Date.now();
        const poll = () => {
          const reply = client.frames.slice(mark).find(frame => frame.type === 'error');
          if (reply) return resolve(reply);
          if (Date.now() - started > 10000) return reject(new Error('no refusal'));
          setTimeout(poll, 20);
        };
        poll();
      });
      assert.equal(error.message, 'unknown message type: debug');
    }
    await sleep(300);
    assert.deepEqual(room.match.config, before, 'the authoritative config is byte-identical');
    assert.equal(room.match.mutators.damageMultiplier, damageBefore);
    assert.equal(room.match.actors.length, 4, 'no seat was added or removed');
    assert.equal(room.match.actors[0].health <= room.match.actors[0].maxHealth, true, 'health is still source-owned');
    assert.ok(room.match.actors[0].health > 0 || healthBefore === 0 || room.match.actors[0].deaths > 0, 'the human is still mortal');
    assert.equal(Object.hasOwn(room.match, 'damage'), false, 'no debug guard was installed on the locked source match');
    // The clients are still connected and the room is still live.
    assert.equal(a.ws.readyState, WebSocket.OPEN);
    assert.equal(b.ws.readyState, WebSocket.OPEN);
    assert.equal(room.match.over, false);
  } finally {
    a.ws.close(); b.ws.close(); close();
  }
});

test('the shipped closure contains the debug module only in the local adapters', () => {
  const closure = JSON.parse(execFileSync(process.execPath,
    ['--no-warnings', '--experimental-vm-modules', 'tools/godot-package/discover.mjs', root],
    {cwd:root, encoding:'utf8', stdio:['ignore', 'pipe', 'pipe']}));
  assert.equal(Object.hasOwn(closure.routes, 'ordinary'), true);
  assert.ok(!closure.routes.ordinary.includes('port/native-debug/debug.mjs'));
  assert.ok(closure.routes.horde.includes('port/native-debug/debug.mjs'));
  assert.ok(closure.routes.nativeArena.includes('port/native-debug/debug.mjs'));
  assert.ok(Object.hasOwn(closure.adapterModules, 'port/native-debug/debug.mjs'));
  // The locked multi-human server source does not mention the debug surface at
  // all: there is no frame branch, no import and no state.
  for (const entry of readdirSync(resolve(root, 'server')).filter(name => name.endsWith('.mjs'))) {
    const text = readFileSync(resolve(root, 'server', entry), 'utf8');
    assert.ok(!/debug/i.test(text), `server/${entry} never mentions the debug surface`);
  }
});

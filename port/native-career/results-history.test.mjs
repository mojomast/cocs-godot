// Controlled source fixture for the native Career RESULTS/HISTORY lane.
//
// It uses the real authoritative Room, MatchHistory and ProgressionStore (no
// local balance authority, no fabricated identity). The fixture steps the match
// at a fixed dt so the ending is deterministic rather than wall-clock bound; the
// host config is a legal short round (deathmatch, timeLimit 60, fragLimit 5).
// It asserts the exact wire order the native reader relies on:
//   history.record -> award `progression` (award BEFORE results) -> `results`
// and then proves a reconnect replays the result with no second award, the
// history store persists across a process restart, and the read-only `history`
// endpoint returns the persisted recent server matches.
//
// Run (parent serial slot): node --test port/native-career/results-history.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import WebSocket from 'ws';
import {Room} from '../../server/room.mjs';
import {MatchHistory} from '../../server/history.mjs';
import {ProgressionStore} from '../../server/progression.mjs';
import {createGameServer} from '../../server/game-server.mjs';

function rng() { let n = 11; return () => ((n = (Math.imul(n, 1664525) + 1013904223) >>> 0) / 4294967296); }
const tmpDir = () => fs.mkdtempSync(path.join(os.tmpdir(), 'career-results-'));

// A legal controlled round: two owned humans, no bots, the 5-frag floor and the
// minimum 60 s clock. The fixture places both actors and fires once, then steps
// until the authoritative match resolves (time or frag).
test('source award precedes results, stays distinct from equipment, and history persists', async () => {
  const dir = tmpDir();
  const historyFile = path.join(dir, 'history.json');
  const progressFile = path.join(dir, 'progression.json');
  try {
    const history = new MatchHistory(historyFile);
    const progression = new ProgressionStore(progressFile);
    const room = new Room('CAREER', rng(), {history, progression});
    room.join(1, 'Host', 'chatgpt', 'openclaw', '', false, 'player-0001');
    room.join(2, 'Guest', 'claude', 'claudecode', '', false, 'player-0002');
    room.host(1, {mode: 'deathmatch', botCount: 0, fragLimit: 5, timeLimit: 60, respawn: 1}, 'crosswire');
    room.start(1);
    room.drain();
    // GEAR reply shape first: it must never look like an award.
    room.setGear(1, {}, {optic: 'red-dot'});
    const gearReply = room.drain().find(item => item.msg.type === 'progression');
    assert.ok(gearReply, 'GEAR write replied');
    assert.ok(gearReply.msg.gear && gearReply.msg.attachments, 'GEAR reply carries explicit equipment maps');
    assert.equal('gained' in gearReply.msg, false, 'no award field on an equipment reply');
    assert.equal('levelUp' in gearReply.msg, false, 'no level-up on an equipment reply');
    // Play the round and inspect the actual ending wire.
    const [a, b] = room.match.actors;
    Object.assign(a, {x: -10, y: 0, z: 3.3, weapon: 1, ammo: [Infinity, 1, 0, 0, 0], protection: 0, shotWait: 0, yaw: 0, pitch: 0});
    Object.assign(b, {x: -10, y: 0, z: -3.3, protection: 0, health: 40});
    room.input(1, {yaw: 0, fire: true});
    for (let i = 0; i < 3700 && !room.roundOver; i++) room.tick(1 / 60);
    assert.equal(room.roundOver, true, 'round resolved');
    const frames = room.drain();
    const awardIndex = frames.findIndex(item => item.msg.type === 'progression' && 'gained' in item.msg);
    const resultsIndex = frames.findIndex(item => item.msg.type === 'results');
    assert.ok(awardIndex >= 0, 'an award frame was sent');
    assert.ok(resultsIndex >= 0, 'a results frame was sent');
    assert.ok(awardIndex < resultsIndex, 'source award precedes the accepted result');
    const award = frames[awardIndex].msg;
    assert.equal(typeof award.profile?.id, 'string', 'award carries the source profile id');
    assert.equal(typeof award.gained, 'number', 'award carries gained XP');
    assert.equal(typeof award.levelUp, 'boolean', 'award carries a level-up flag');
    assert.ok(Array.isArray(award.unlocked) && Array.isArray(award.achievements), 'award carries reward lists');
    assert.equal('gear' in award, false, 'award is not an equipment reply');
    assert.equal('attachments' in award, false, 'award is not an equipment reply');
    // The summary history record exists and is server-wide.
    assert.equal(history.all().length, 1, 'one source match recorded');
    const entry = history.all()[0];
    assert.equal(entry.roomId, 'CAREER');
    assert.equal(entry.mapId, 'crosswire');
    assert.equal(entry.mode, 'deathmatch');
    assert.ok(entry.players.some(player => player.name === 'Host'));
    assert.equal('ownerToken' in entry.players[0], false, 'history player rows carry no career identity');
    await history.whenPersisted();
    await progression.whenPersisted();
    assert.ok(!history.lastPersistError, 'history persisted cleanly');
    // A restart recovers both stores from the same owned files.
    const reloadedHistory = new MatchHistory(historyFile);
    assert.equal(reloadedHistory.all().length, 1, 'persisted history reloads');
    assert.equal(reloadedHistory.all()[0].mode, 'deathmatch');
    const reloadedProgression = new ProgressionStore(progressFile);
    assert.ok(reloadedProgression.get('player-0001').xp >= 0, 'persisted career reloads');
    // Reconnect the same owned seat: the result replays, no second award.
    const peer = room.peers.get(1);
    room.drain();
    room.join(3, 'Host', 'chatgpt', 'openclaw', peer.token, false, 'player-0001', peer.playerToken);
    const reconnect = room.drain();
    const welcome = reconnect.find(item => item.msg.type === 'welcome');
    assert.equal(welcome?.msg.reconnected, true, 'owned reconnect is admitted');
    assert.ok(reconnect.some(item => item.msg.type === 'results'), 'result replays to the reconnecting seat');
    assert.ok(!reconnect.some(item => item.msg.type === 'progression' && 'gained' in item.msg), 'reconnect sends no new award');
    assert.equal(history.all().length, 1, 'reconnect records no second match');
  } finally {
    fs.rmSync(dir, {recursive: true, force: true});
  }
});

test('read-only history endpoint returns the persisted recent server matches', async () => {
  const dir = tmpDir();
  const historyFile = path.join(dir, 'history.json');
  const progressFile = path.join(dir, 'progression.json');
  try {
    const history = new MatchHistory(historyFile);
    history.record({roomId: 'CAREER', mapId: 'crosswire', config: {mode: 'deathmatch', fragLimit: 5, timeLimit: 60}, time: 60, actors: [{name: 'Host', character: 'chatgpt', harness: 'openclaw', frags: 3, deaths: 1}]});
    await history.whenPersisted();
    const game = createGameServer({port: 0, historyPath: historyFile, progressionPath: progressFile});
    await new Promise(resolve => game.server.listen(0, '127.0.0.1', resolve));
    const ws = new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);
    const queue = [];
    ws.on('message', data => queue.push(JSON.parse(String(data))));
    try {
      await new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); });
      ws.send(JSON.stringify({type: 'history'}));
      const reply = await new Promise((resolve, reject) => {
        const deadline = setTimeout(() => reject(new Error('missing history reply')), 5000);
        const poll = setInterval(() => {
          const found = queue.find(frame => frame.type === 'history');
          if (found) { clearTimeout(deadline); clearInterval(poll); resolve(found); }
        }, 20);
      });
      assert.equal(reply.matches.length, 1, 'the persisted server match is returned');
      assert.equal(reply.matches[0].mode, 'deathmatch');
      assert.ok(reply.matches[0].players.some(player => player.name === 'Host'));
    } finally {
      ws.close();
      await game.close();
    }
  } finally {
    fs.rmSync(dir, {recursive: true, force: true});
  }
});

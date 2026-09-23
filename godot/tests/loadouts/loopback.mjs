// Loopback authority proof for native operator/harness selection.
// Starts the actual Node game server on 127.0.0.1, then runs two native Godot
// clients with two different operator/harness pairs, each driving the real lobby
// UI with key/mouse events. Success requires both clients to read the other
// player's identity back out of the authoritative snapshot state.
//
// Two-party completion barrier: a client that has read its own identity back
// must stay connected, so the peer can still read that actor out of the
// authoritative snapshot, until BOTH proofs are in and validated. Only then
// does the harness write each client's release file, and every client must
// acknowledge it and exit 0 on its own. A client that stops before the barrier,
// ignores its release, or dies on the way out fails the run, so teardown is a
// verified two-party handshake instead of a race.
//
//   GODOT_BIN=/path/to/Godot python3 tools/godot-dev/xvfb_run.py node godot/tests/loadouts/loopback.mjs
import {createGameServer} from '../../../server/game-server.mjs';
import {spawn} from 'node:child_process';
import {mkdirSync, rmSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createInterface} from 'node:readline';
import assert from 'node:assert/strict';

const binary = process.env.GODOT_BIN;
assert.ok(binary, 'Set GODOT_BIN to the pinned editor');
assert.ok(process.env.DISPLAY, 'Run through tools/godot-dev/xvfb_run.py: real UI clicks require a display');
const hostPair = {operator: 'grok', harness: 'cline'};
const guestPair = {operator: 'deepseek', harness: 'hermes'};
const runtime = resolve('.port-runtime/loadouts');
const proofTimeoutMs = Number(process.env.LOADOUT_LOOPBACK_TIMEOUT_MS ?? '') || 60000;
const releaseWaitMs = Number(process.env.LOADOUT_LOOPBACK_RELEASE_WAIT_MS ?? '') || 15000;
const releaseGraceMs = 500;
const game = createGameServer({historyPath: null, progressionPath: null});
const children = [];

const results = {};
const exits = new Map();
const violations = [];
let stopping = false;
let barrierComplete = false;
let timer;
let resolveDone, rejectDone;
const done = new Promise((resolve, reject) => { resolveDone = resolve; rejectDone = reject; });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

function waitExit(child, ms) {
  return new Promise(resolveExit => {
    if (exits.has(child)) return resolveExit();
    const escalation = setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, ms);
    child.once('exit', () => { clearTimeout(escalation); resolveExit(); });
  });
}

// Both proofs are in and validated, so both clients may stop now. Their exits
// are client-owned events the harness verifies instead of assumed: each client
// must acknowledge its release file and exit 0 without being killed.
async function releaseBarrier() {
  for (const child of children) if (exits.has(child)) violations.push(`${child.__role} stopped before the barrier released it`);
  stopping = true;
  for (const child of children) writeFileSync(child.__release, `release ${child.__role}\n`);
  const deadline = Date.now() + releaseWaitMs;
  let unacknowledgedExitSince = 0;
  while (Date.now() < deadline && children.some(child => !child.__released || !exits.has(child))) {
    // An exited client can no longer acknowledge; give its buffered output a
    // moment to land, then stop waiting so a broken client fails promptly.
    if (children.some(child => !child.__released && exits.has(child))) {
      unacknowledgedExitSince ||= Date.now();
      if (Date.now() - unacknowledgedExitSince > releaseGraceMs) break;
    }
    await sleep(10);
  }
  for (const child of children) {
    const exit = exits.get(child);
    if (!child.__released) violations.push(`${child.__role} never acknowledged its release`);
    if (!exit) violations.push(`${child.__role} never exited after its release`);
    else if (exit.signal !== null) violations.push(`${child.__role} had to be killed with ${exit.signal} after its release`);
    else if (exit.code !== 0) violations.push(`${child.__role} exited ${exit.code} after its release`);
    rmSync(child.__release, {force: true});
  }
  assert.deepEqual(violations, [], 'both clients hold for the two-party barrier and then exit 0');
  console.log(`PORT_LOADOUT_BARRIER released ${children.map(child => `${child.__role}=${exits.get(child)?.code}`).join(' ')}`);
}

function launch(role, pair, other, extra = []) {
  const index = children.length;
  const env = {...process.env};
  for (const [key, suffix] of [['XDG_DATA_HOME', 'data'], ['XDG_CONFIG_HOME', 'config'], ['XDG_CACHE_HOME', 'cache']]) {
    env[key] = resolve(runtime, `live-${role}-${index}`, suffix);
    mkdirSync(env[key], {recursive: true});
  }
  const release = resolve(runtime, `release-${process.pid}-${role}-${index}.flag`);
  rmSync(release, {force: true});
  const child = spawn(binary, ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '1280x800', '--path', 'godot', '--script', 'res://tests/loadouts/live.gd', '--',
    '--lobby-menu', `--role=${role}`, `--endpoint=ws://127.0.0.1:${game.server.address().port}`,
    `--operator=${pair.operator}`, `--harness=${pair.harness}`,
    `--peer-operator=${other.operator}`, `--peer-harness=${other.harness}`,
    `--release-file=${release}`, ...extra], {env, stdio: ['ignore', 'pipe', 'pipe']});
  child.__role = role;
  child.__release = release;
  child.__released = false;
  children.push(child);
  child.once('error', rejectDone);
  child.once('exit', (code, signal) => {
    exits.set(child, {code, signal});
    if (!stopping) rejectDone(new Error(`${role} exited early: ${code ?? signal}`));
  });
  for (const stream of [child.stdout, child.stderr]) createInterface({input: stream}).on('line', line => {
    if (line.includes('ERROR:') || line.includes('SCRIPT ERROR')) { rejectDone(new Error(`${role}: ${line}`)); return; }
    if (line.startsWith('PORT_LOADOUT_')) console.log(`[${role}] ${line}`);
    if (line.startsWith('PORT_LOADOUT_LIVE_RELEASED')) child.__released = true;
    if (line.startsWith('PORT_LOADOUT_LIVE_OK ')) {
      try { results[role] = JSON.parse(line.slice('PORT_LOADOUT_LIVE_OK '.length)); }
      catch (error) { rejectDone(error); return; }
      // Barrier satisfied: both proofs are in, so the proof clock stops here.
      // Exits stay fatal until releaseBarrier() has validated both payloads.
      if (results.host && results.guest && !barrierComplete) { barrierComplete = true; clearTimeout(timer); resolveDone(); }
    }
    if (line.startsWith('PORT_LOADOUT_ROOM ') && role === 'host' && !children.some(child => child.__guest)) {
      const room = line.slice('PORT_LOADOUT_ROOM '.length).trim();
      const guest = launch('guest', guestPair, hostPair, [`--join-room=${room}`]);
      guest.__guest = true;
    }
  });
  return child;
}

const interrupt = () => rejectDone(new Error('Interrupted'));
process.once('SIGINT', interrupt);
process.once('SIGTERM', interrupt);
try {
  await new Promise((resolveListen, reject) => { game.server.once('error', reject); game.server.listen(0, '127.0.0.1', resolveListen); });
  assert.ok((await fetch(`http://127.0.0.1:${game.server.address().port}`, {signal: AbortSignal.timeout(5000)})).ok, 'loopback authority responds');
  timer = setTimeout(() => rejectDone(new Error('Native loadout clients timed out')), proofTimeoutMs);
  launch('host', hostPair, guestPair);
  await done;
  const host = results.host, guest = results.guest;
  assert.notEqual(host.actor_id, guest.actor_id, 'both humans hold different actors');
  assert.equal(host.seated, 2, 'host sees two seated humans');
  assert.equal(host.requested.character, hostPair.operator);
  assert.equal(host.requested.harness, hostPair.harness);
  assert.equal(guest.requested.character, guestPair.operator);
  assert.equal(guest.requested.harness, guestPair.harness);
  assert.notEqual(hostPair.operator + '/' + hostPair.harness, guestPair.operator + '/' + guestPair.harness, 'pairs differ');
  assert.equal(host.snapshot_self, `${hostPair.operator}/${hostPair.harness}`, 'host snapshot shows the host pair');
  assert.equal(host.snapshot_peer, `${guestPair.operator}/${guestPair.harness}`, 'host snapshot shows the guest pair');
  assert.equal(guest.snapshot_self, `${guestPair.operator}/${guestPair.harness}`, 'guest snapshot shows the guest pair');
  assert.equal(guest.snapshot_peer, `${hostPair.operator}/${hostPair.harness}`, 'guest snapshot shows the host pair');
  assert.equal(host.peer_actor_id, guest.actor_id, 'host identifies the guest actor');
  assert.equal(guest.peer_actor_id, host.actor_id, 'guest identifies the host actor');
  await releaseBarrier();
  console.log('PORT_LOADOUT_LOOPBACK_OK ' + JSON.stringify({clock: 'loopback only, normal server rate', host, guest}));
} finally {
  stopping = true;
  clearTimeout(timer);
  await Promise.all(children.map(async child => {
    if (!exits.has(child)) {
      try { child.kill('SIGTERM'); } catch {}
      await waitExit(child, 10000);
    }
    rmSync(child.__release, {force: true});
  }));
  await game.close();
  process.removeListener('SIGINT', interrupt);
  process.removeListener('SIGTERM', interrupt);
}

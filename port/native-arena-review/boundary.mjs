// Review-lane boundary tests for the native DM authority and launcher contract.
//
// Every case records the OBSERVED behaviour (status, error text, frames) rather
// than asserting a hoped-for outcome, so a rejection is a real rejection and
// never a timeout-driven pass. Writes results to
// port/native-arena-review/logs/boundary-<stamp>.json.
import {WebSocket} from 'ws';
import {mkdirSync, writeFileSync, mkdtempSync, cpSync, rmSync, existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve, join} from 'node:path';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {createNativeArenaAuthority, readNativeArena} from '../native-arenas/authority.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const logDir = `${ROOT}/port/native-arena-review/logs`;
mkdirSync(logDir, {recursive: true});
const results = [];
const unexpectedErrors = new Map();
const noteUnexpected = error => {
  const message = String(error?.message ?? error);
  unexpectedErrors.set(message, (unexpectedErrors.get(message) ?? 0) + 1);
};
process.on('uncaughtException', noteUnexpected);
process.on('unhandledRejection', noteUnexpected);
const record = (test, outcome, detail) => {
  results.push({test, outcome, detail});
  console.log(JSON.stringify({test, outcome, detail}));
};
const attempt = async (test, fn) => {
  try { record(test, 'observed', await fn()); } catch (error) { record(test, 'threw', {name: error.constructor.name, message: error.message}); }
};

// ---------- 1. API-level validation rejections (no sockets) ----------
for (const [label, options] of [
  ['invalid-map-id', {mapId: 'not-a-map'}],
  ['bots-0', {mapId: 'prism-foundry', bots: 0}],
  ['bots-8', {mapId: 'prism-foundry', bots: 8}],
  ['round-seconds-30', {mapId: 'prism-foundry', roundSeconds: 30}],
  ['round-seconds-901', {mapId: 'prism-foundry', roundSeconds: 901}],
  ['frag-limit-1', {mapId: 'prism-foundry', fragLimit: 1}],
  ['bad-difficulty', {mapId: 'prism-foundry', difficulty: 'godlike'}],
  ['bad-mode', {mapId: 'prism-foundry', mode: 'koth'}],
  ['conflicting-bots', {mapId: 'prism-foundry', bots: 2, botCount: 3}],
  ['unknown-option', {mapId: 'prism-foundry', url: 'http://evil'}],
]) {
  await attempt(`authority-reject:${label}`, async () => {
    const started = Date.now();
    try {
      const authority = await createNativeArenaAuthority({port: 0, host: '127.0.0.1', mode: 'deathmatch', ...options});
      const port = authority.port;
      await authority.close();
      return {rejected: false, boundPort: port, ms: Date.now() - started};
    } catch (error) {
      return {rejected: true, error: `${error.constructor.name}: ${error.message}`, ms: Date.now() - started};
    }
  });
}

// ---------- 2. HTTP surface ----------
{
  const authority = await createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId: 'prism-foundry', mode: 'deathmatch', bots: 2, roundSeconds: 60});
  try {
    const root = await fetch(`http://127.0.0.1:${authority.port}/`);
    record('http-root', 'observed', {status: root.status, body: await root.json()});
    const wrong = await fetch(`http://127.0.0.1:${authority.port}/wrong-path`);
    record('http-wrong-path', 'observed', {status: wrong.status, body: (await wrong.text()).slice(0, 120)});
    const post = await fetch(`http://127.0.0.1:${authority.port}/`, {method: 'POST', body: '{}'});
    record('http-post-root', 'observed', {status: post.status, body: (await post.text()).slice(0, 120)});
  } finally { await authority.close(); }
}

// ---------- 3. WebSocket upgrade rules ----------
function rawUpgrade(port, path, headers = {}) {
  return new Promise(resolve => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}${path}`, {headers});
    ws.on('error', () => {});
    const timer = setTimeout(() => { ws.terminate(); resolve({connected: false, reason: 'timeout'}); }, 4000);
    ws.on('open', () => { clearTimeout(timer); resolve({connected: true, ws}); });
    ws.on('error', error => { clearTimeout(timer); resolve({connected: false, reason: `${error.name}: ${error.message}`.slice(0, 160)}); });
  });
}
{
  const fresh = async (options = {}) => createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId: 'prism-foundry', mode: 'deathmatch', bots: 2, roundSeconds: 60, ...options});
  // Each upgrade case gets its own authority so the one-seat rule cannot
  // masquerade as a path/origin rejection.
  let authority = await fresh();
  const first = new WebSocket(`ws://127.0.0.1:${authority.port}/`);
  first.on('error', () => {});
  await new Promise(resolve => first.on('open', resolve));
  record('ws-root-path', 'observed', {connected: true});
  await authority.close();
  authority = await fresh();
  const second = new WebSocket(`ws://127.0.0.1:${authority.port}/native-arenas`);
  second.on('error', () => {});
  await new Promise(resolve => second.on('open', resolve));
  record('ws-native-path', 'observed', {connected: true});
  // second concurrent connection while the first is open
  record('ws-second-connection', 'observed', await rawUpgrade(authority.port, '/native-arenas'));
  await authority.close();
  authority = await fresh();
  record('ws-wrong-path', 'observed', await rawUpgrade(authority.port, '/other'));
  await authority.close();
  authority = await fresh();
  record('ws-browser-origin', 'observed', await rawUpgrade(authority.port, '/native-arenas', {origin: 'http://example.com'}));
  await authority.close();
}

// ---------- 4. Protocol lifecycle, restart during results, mid-round disconnect ----------
function client(port, observations) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}/native-arenas`);
  const frames = [];
  ws.on('error', () => {});
  ws.on('message', bytes => {
    const frame = JSON.parse(String(bytes));
    frames.push(frame);
    observations.push(frame);
    if (frame.type === 'error') ws.terminate();
  });
  return {ws, frames, send: frame => ws.send(JSON.stringify(frame)), open: () => new Promise(r => ws.on('open', r))};
}
{
  const observations = [];
  const authority = await createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId: 'cinder-array', mode: 'deathmatch', bots: 7, roundSeconds: 60, fragLimit: 5});
  try {
    const c = client(authority.port, observations);
    await c.open();
    c.send({type: 'create', v: 3, delta: 0, nativeArenaInput: 1, playerName: 'Reviewer'});
    await new Promise(r => setTimeout(r, 250));
    record('protocol-welcome', 'observed', {types: c.frames.slice(0, 2).map(f => f.type), welcome: c.frames[0], lobby: c.frames[1]});
    // wrong map id in host
    c.send({type: 'host', mapId: 'aurora-basin', config: {mode: 'deathmatch'}});
    await new Promise(r => setTimeout(r, 250));
    record('protocol-wrong-map-host', 'observed', c.frames.slice(-1)[0]);
    // valid host + start (wait for the seat to detach, retry once)
    observations.length = 0;
    await new Promise(r => setTimeout(r, 300));
    let c2 = client(authority.port, observations);
    let opened = false;
    for (let attemptNo = 0; attemptNo < 3 && !opened; attemptNo++) {
      try { await Promise.race([c2.open(), new Promise((_, reject) => setTimeout(() => reject(new Error('open timeout')), 3000))]); opened = true; }
      catch { c2 = client(authority.port, observations); await new Promise(r => setTimeout(r, 400)); }
    }
    record('protocol-second-seat', 'observed', {opened});
    const waitFor = async (type, ms) => {
      const deadline = Date.now() + ms;
      while (Date.now() < deadline) {
        const frame = c2.frames.find(f => f.type === type);
        if (frame) return frame;
        await new Promise(r => setTimeout(r, 50));
      }
      return null;
    };
    c2.send({type: 'create', v: 3, delta: 0, nativeArenaInput: 1});
    const welcome = await waitFor('welcome', 3000);
    c2.send({type: 'host', mapId: 'cinder-array', config: {mode: 'deathmatch', botCount: 7, timeLimit: 60, fragLimit: 5, difficulty: 'easy'}});
    const configured = await waitFor('lobby', 3000);
    record('protocol-host-lobby', 'observed', {welcome: welcome?.type ?? null, config: configured?.config ?? null});
    c2.send({type: 'start'});
    const startFrame = await waitFor('start', 5000);
    const firstSnap = await waitFor('snapshot', 5000);
    record('protocol-start', 'observed', startFrame
      ? {inputEpoch: startFrame.inputEpoch, roundRevision: startFrame.roundRevision, geometryHash: startFrame.geometryHash,
        firstSnapshotTime: firstSnap?.state?.time, actors: firstSnap?.state?.actors?.length}
      : {note: 'no start frame', frames: c2.frames.map(f => f.type).slice(0, 8)});
    if (startFrame) {
      // drive the round with ordinary inputs until results
      let seq = 0;
      const resultsFrame = await (async () => {
        const deadline = Date.now() + 80000;
        while (Date.now() < deadline) {
          seq++;
          c2.send({type: 'input', seq, inputEpoch: startFrame.inputEpoch, input: {x: 0.4, z: 0.2, yaw: seq * 0.05, pitch: 0, fire: seq % 3 === 0}});
          const frame = c2.frames.find(f => f.type === 'results');
          if (frame) return frame;
          await new Promise(r => setTimeout(r, 50));
        }
        return null;
      })();
      record('protocol-results', 'observed', resultsFrame
        ? {over: resultsFrame.state.over, overReason: resultsFrame.state.overReason, time: resultsFrame.state.time,
          leaders: resultsFrame.state.leaders, frags: resultsFrame.state.actors.map(a => a.frags),
          deaths: resultsFrame.state.actors.map(a => a.deaths), inputEpoch: resultsFrame.inputEpoch,
          killEvents: c2.frames.filter(f => f.type === 'events').flatMap(f => f.items).filter(e => e.type === 'death').length}
        : {over: false, note: 'no results within 80s'});
      // restart during results
      const beforeRestart = c2.frames.length;
      c2.send({type: 'start'});
      await new Promise(r => setTimeout(r, 700));
      const newFrames = c2.frames.slice(beforeRestart);
      const restartStart = newFrames.find(f => f.type === 'start');
      const restartSnap = newFrames.find(f => f.type === 'snapshot');
      record('protocol-restart-during-results', 'observed', restartStart ? {
        roundRevision: restartStart.roundRevision, inputEpochBefore: resultsFrame?.inputEpoch, inputEpochAfter: restartStart.inputEpoch,
        snapshotTime: restartSnap?.state?.time, frags: restartSnap?.state?.actors?.map(a => a.frags),
        deaths: restartSnap?.state?.actors?.map(a => a.deaths), over: restartSnap?.state?.over,
        firstEventIds: newFrames.filter(f => f.type === 'events').flatMap(f => f.items).map(e => e.id).slice(0, 4),
      } : {note: 'no restart start frame', observed: newFrames.map(f => f.type)});
      // invalid frames after restart
      c2.send({type: 'input', input: {x: 1}});
      await new Promise(r => setTimeout(r, 200));
      record('protocol-invalid-input', 'observed', c2.frames.slice(-1)[0]);
    }
    // disconnect mid-round
    const statusBefore = await (await fetch(`http://127.0.0.1:${authority.port}/`)).json();
    c2.ws.terminate();
    await new Promise(r => setTimeout(r, 700));
    const statusAfter = await (await fetch(`http://127.0.0.1:${authority.port}/`)).json();
    record('protocol-disconnect-mid-round', 'observed', {before: statusBefore.mapId, after: statusAfter.mapId,
      authorityAlive: statusAfter.localOnly === true && authority.server.listening === true});
    // reconnect after disconnect
    const reconnect = await rawUpgrade(authority.port, '/native-arenas');
    record('protocol-reconnect-after-disconnect', 'observed', {connected: reconnect.connected, reason: reconnect.reason ?? null});
    if (reconnect.connected) {
      // The probe socket holds the single seat; release it before the real client.
      reconnect.ws.terminate();
      await new Promise(r => setTimeout(r, 400));
      const c3 = client(authority.port, []);
      try {
        await Promise.race([c3.open(), new Promise((_, reject) => setTimeout(() => reject(new Error('open timeout')), 3000))]);
        c3.send({type: 'create', v: 3, delta: 0, nativeArenaInput: 1});
        await new Promise(r => setTimeout(r, 300));
        record('protocol-reconnect-create', 'observed', c3.frames.slice(0, 2).map(f => f.type));
      } catch (error) {
        record('protocol-reconnect-create', 'observed', {error: String(error.message)});
      } finally { c3.ws.terminate(); }
    }
  } finally { await authority.close(); }
}

// ---------- 5. Missing geometry asset must fail before binding ----------
await attempt('missing-geometry-file', async () => {
  const runtime = mkdtempSync(join(tmpdir(), 'native-review-missing-'));
  try {
    cpSync(`${ROOT}/port`, `${runtime}/port`, {recursive: true, filter: p => !p.includes('/tests/') && !p.includes('node_modules')});
    cpSync(`${ROOT}/game`, `${runtime}/game`, {recursive: true, filter: p => !p.endsWith('.test.mjs')});
    // The documented package closure relies on the bundled `ws` dependency.
    cpSync(`${ROOT}/package.json`, `${runtime}/package.json`);
    const {symlinkSync} = await import('node:fs');
    symlinkSync(`${ROOT}/node_modules`, `${runtime}/node_modules`, 'dir');
    const generated = `${runtime}/godot/native_arenas/generated`;
    mkdirSync(generated, {recursive: true});
    for (const id of ['prism-foundry', 'aurora-basin']) cpSync(`${ROOT}/godot/native_arenas/generated/${id}.json`, `${generated}/${id}.json`);
    const authorityModule = await import(`${runtime}/port/native-arenas/authority.mjs`);
    const observed = {};
    for (const id of ['prism-foundry', 'cinder-array']) {
      try {
        const authority = await authorityModule.createNativeArenaAuthority({port: 0, host: '127.0.0.1', mapId: id, mode: 'deathmatch', bots: 2, roundSeconds: 60});
        observed[id] = {rejected: false, boundPort: authority.port};
        await authority.close();
      } catch (error) { observed[id] = {rejected: true, error: `${error.constructor.name}: ${error.message}`}; }
    }
    observed.generatedFiles = existsSync(`${generated}/cinder-array.json`);
    return observed;
  } finally { rmSync(runtime, {recursive: true, force: true, maxRetries: 3}); }
});

// ---------- 6. Launcher CLI rejections (real launcher path) ----------
const launcher = (args) => {
  try {
    const out = execFileSync(process.execPath, ['tools/godot-dev/launch.mjs', ...args], {cwd: ROOT, encoding: 'utf8', timeout: 30000, env: {...process.env, GODOT_BIN: process.env.GODOT_BIN ?? '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'}});
    return {exitCode: 0, stdout: out.slice(-300)};
  } catch (error) {
    return {exitCode: error.status, stdout: String(error.stdout ?? '').slice(-300), stderr: String(error.stderr ?? '').slice(-500)};
  }
};
for (const [label, args] of [
  ['launcher-invalid-map', ['--experience=native-dm', '--map=tidal-citadel']],
  ['launcher-bots-0', ['--experience=native-dm', '--map=prism-foundry', '--bots=0']],
  ['launcher-bots-8', ['--experience=native-dm', '--map=prism-foundry', '--bots=8']],
  ['launcher-round-seconds-30', ['--experience=native-dm', '--map=prism-foundry', '--round-seconds=30']],
  ['launcher-round-seconds-901', ['--experience=native-dm', '--map=prism-foundry', '--round-seconds=901']],
  ['launcher-bad-mode', ['--experience=native-dm', '--map=prism-foundry', '--mode=koth']],
  ['launcher-endpoint-rejected', ['--experience=native-dm', '--map=prism-foundry', '--endpoint=ws://127.0.0.1:1/native-arenas']],
  ['launcher-unknown-flag', ['--experience=native-dm', '--map=prism-foundry', '--play']],
  ['launcher-missing-map-value', ['--experience=native-dm', '--map']],
]) {
  const observed = launcher(args);
  record(`cli:${label}`, observed.exitCode === 0 ? 'unexpected-success' : 'observed',
    {exitCode: observed.exitCode, output: (observed.stderr || observed.stdout || '').trim().split('\n').slice(-3).join(' | ')});
}

writeFileSync(`${logDir}/boundary-${new Date().toISOString().replace(/[:.]/g, '-')}.json`, `${JSON.stringify(results, null, 2)}\n`);
console.log(JSON.stringify({tests: results.length, unexpectedOutcomes: results.filter(r => r.outcome !== 'observed').length,
  asyncErrors: Object.fromEntries(unexpectedErrors), detail: results.filter(r => r.outcome !== 'observed')}));

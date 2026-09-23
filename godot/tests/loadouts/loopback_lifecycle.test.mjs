// Lifecycle regression for the loadout loopback harness barrier.
//
// The canonical gate (godot/tests/loadouts/loopback.mjs) runs two real native
// clients against the real authority; that run is the only identity/UI
// evidence. This file pins the *lifecycle* contract that keeps that gate
// deterministic, using stub clients instead of the engine so it can run in
// seconds: the first client to prove its own view must stay connected, so the
// peer can still read it out of the authoritative snapshot, until BOTH proofs
// were validated. Only then does the harness release both clients, and both
// must exit 0 - no kills, no hangs, no leftover release files.
//
// A client that stops right after its own proof (the reproduced regression) and
// a client that never reports must still fail the run closed and be reaped.
// Identity payloads in the stubs are copied back from the CLI pairs the harness
// passes in, so the stubs can never claim a proof of their own; the forged-self
// case below additionally proves the harness identity assertions still reject a
// wrong pair.
//
// Cleanup is unconditional: every scenario reclaims its fixtures from a finally
// path, so a failed assertion, a bound that fired, or a harness that had to be
// force-killed can no longer strand a fixture client or a temp dir. A pid is
// only ever signalled while /proc/<pid>/cmdline still names the stub script
// inside this scenario's own dir, so a recycled pid is never killed from here.
//
//   node --test godot/tests/loadouts/loopback_lifecycle.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {chmodSync, existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '../../..');
const HARNESS = join(HERE, 'loopback.mjs');
const LIVE_GD = join(HERE, 'live.gd');
const STUB_NAME = 'stub-godot.mjs';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

// Lifecycle double for the pinned editor. It speaks only the PORT_LOADOUT_*
// client protocol the harness consumes and is never used as identity evidence.
const STUB_SOURCE = [
  '#!' + process.execPath,
  "import {existsSync, statSync, writeFileSync} from 'node:fs';",
  "import {join} from 'node:path';",
  '',
  'const args = process.argv.slice(2);',
  "const after = args.indexOf('--');",
  'const flags = new Map((after < 0 ? args : args.slice(after + 1)).map(entry => {',
  "  const at = entry.indexOf('=');",
  "  return at < 0 ? [entry.replace(/^--/, ''), ''] : [entry.slice(2, at), entry.slice(at + 1)];",
  '}));',
  "const role = flags.get('role') ?? 'host';",
  "const release = flags.get('release-file') ?? '';",
  'const dir = process.env.STUB_DIR;',
  "const mode = process.env.STUB_MODE ?? 'hold';",
  "const delayMs = Number(process.env.STUB_DELAY_MS ?? '') || 0;",
  "const delayRole = process.env.STUB_DELAY_ROLE ?? 'guest';",
  "const exitRole = process.env.STUB_EXIT_ROLE ?? 'guest';",
  "const holdMs = Number(process.env.STUB_HOLD_MS ?? '') || 20000;",
  'const forgeSelf = process.env.STUB_FORGE_SELF === role;',
  'const local = (name, text) => writeFileSync(join(dir, name), text);',
  "const pair = (operator, harness) => operator + '/' + harness;",
  '',
  "local('pid-' + role, String(process.pid));",
  "process.on('SIGTERM', () => { local('killed-' + role, 'terminated'); process.exit(9); });",
  '',
  'function payload() {',
  '  const self = pair(flags.get(\'operator\'), flags.get(\'harness\'));',
  '  const peer = pair(flags.get(\'peer-operator\'), flags.get(\'peer-harness\'));',
  '  return {',
  '    role, stub: true,',
  "    actor_id: role === 'host' ? 0 : 1,",
  "    peer_actor_id: role === 'host' ? 1 : 0,",
  '    seated: 2,',
  "    requested: {character: flags.get('operator'), harness: flags.get('harness')},",
  "    snapshot_self: forgeSelf ? pair('stub', 'forged') : self,",
  '    snapshot_peer: peer,',
  '  };',
  '}',
  '',
  "if (mode === 'silent') {",
  '  // Bounded like every other mode: a harness that is force-killed mid-run',
  '  // must not be able to leave this client running for ever.',
  '  setTimeout(() => process.exit(3), holdMs);',
  '  setInterval(() => {}, 1000);',
  '} else {',
  "  const heartbeat = setInterval(() => local('alive-' + role, String(Date.now())), 50);",
  "  local('alive-' + role, String(Date.now()));",
  '  const report = () => {',
  "    if (role === 'guest') {",
  "      const path = join(dir, 'alive-host');",
  '      const fresh = existsSync(path) && Date.now() - statSync(path).mtimeMs < 750;',
  "      if (!fresh) { console.log('STUB_FAIL peer-not-alive'); process.exit(4); }",
  '    }',
  "    console.log('PORT_LOADOUT_LIVE_OK ' + JSON.stringify(payload()));",
  "    if (mode === 'exit-after-ok' && role === exitRole) process.exit(0);",
  '    const deadline = Date.now() + holdMs;',
  '    const poll = setInterval(() => {',
  "      if (release !== '' && existsSync(release)) {",
  "        console.log('PORT_LOADOUT_LIVE_RELEASED ' + role);",
  "        local('released-' + role, 'released');",
  '        clearInterval(poll); clearInterval(heartbeat); process.exit(0);',
  '      }',
  '      if (Date.now() > deadline) {',
  "        local('released-' + role, 'timeout');",
  '        clearInterval(poll); clearInterval(heartbeat); process.exit(3);',
  '      }',
  '    }, 25);',
  '  };',
  "  if (role === 'host') console.log('PORT_LOADOUT_ROOM STUB1');",
  '  if (delayMs > 0 && role === delayRole) setTimeout(report, delayMs); else report();',
  '}',
].join('\n');

function scenarioDir() {
  const dir = mkdtempSync(join(tmpdir(), 'loadout-lifecycle-'));
  const stub = join(dir, STUB_NAME);
  writeFileSync(stub, STUB_SOURCE);
  chmodSync(stub, 0o755);
  return {dir, stub};
}

function runHarness({dir, stub, env = {}, boundMs}) {
  const child = spawn(process.execPath, [HARNESS], {
    cwd: dir,
    env: {...process.env, DISPLAY: ':0', GODOT_BIN: stub, STUB_DIR: dir, ...env},
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', chunk => { output += chunk; });
  child.stderr.on('data', chunk => { output += chunk; });
  let timedOut = false;
  const bound = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, boundMs);
  return once(child, 'exit').then(([code, signal]) => {
    clearTimeout(bound);
    return {code, signal, timedOut, output};
  });
}

function pidOf(dir, role) {
  const path = join(dir, 'pid-' + role);
  return existsSync(path) ? Number(readFileSync(path, 'utf8')) : 0;
}

// A pid is this fixture's client only while /proc/<pid>/cmdline still names the
// stub script inside the scenario dir. A recycled pid fails that check, so no
// unrelated process is ever probed or signalled on the strength of a bare pid.
function stubOwnsPid(dir, pid) {
  if (!pid) return false;
  try { return readFileSync(`/proc/${pid}/cmdline`, 'utf8').includes(join(dir, STUB_NAME)); }
  catch { return false; }
}

async function waitForPid(dir, role, ms) {
  const deadline = Date.now() + ms;
  for (;;) {
    const pid = pidOf(dir, role);
    if (pid) return pid;
    if (Date.now() > deadline) return 0;
    await sleep(25);
  }
}

async function pidGone(dir, role, attempts = 60) {
  const pid = pidOf(dir, role);
  if (!pid) return true;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    if (!stubOwnsPid(dir, pid)) return true;
    await sleep(50);
  }
  return false;
}

// Reap the clients a scenario intentionally leaves behind (a harness that was
// force-killed cannot finish its own teardown): bounded SIGTERM, then SIGKILL,
// and only for pids whose cmdline still proves this fixture owns them. Returns
// the survivors it could not stop, so the caller can fail the test.
async function reapStubs(dir) {
  const survivors = [];
  for (const role of ['host', 'guest']) {
    const pid = await waitForPid(dir, role, 1500);
    if (!pid || !stubOwnsPid(dir, pid)) continue;
    try { process.kill(pid, 'SIGTERM'); } catch {}
    if (await pidGone(dir, role, 20)) continue;
    try { process.kill(pid, 'SIGKILL'); } catch {}
    if (!(await pidGone(dir, role, 20))) survivors.push(`${role} (pid ${pid})`);
  }
  return survivors;
}

// Every scenario ends here, however its test body exited: reap any survivor,
// then drop the temp dir. The survivors are handed back to the caller so an
// unreclaimable client is a test failure instead of a silent leak.
async function cleanup(dir) {
  const survivors = await reapStubs(dir);
  rmSync(dir, {recursive: true, force: true});
  return survivors;
}

function releasedFlag(dir, role) {
  const path = join(dir, 'released-' + role);
  return existsSync(path) ? readFileSync(path, 'utf8') : '';
}

function tidiness(dir) {
  const runtime = join(dir, '.port-runtime', 'loadouts');
  const leftovers = existsSync(runtime) ? readdirSync(runtime).filter(name => name.startsWith('release-')) : [];
  assert.deepEqual(leftovers, [], 'no release files survive a run');
}

// Shared shape for the two ordering cases: one client proves first and holds,
// the delayed peer proves second, and both exit 0 on the harness's release.
async function barrierScenario(delayRole) {
  const {dir, stub} = scenarioDir();
  let survivors = [];
  let output = '';
  try {
    const run = await runHarness({
      dir, stub, boundMs: 40000,
      env: {STUB_MODE: 'hold', STUB_DELAY_MS: '700', STUB_DELAY_ROLE: delayRole,
        LOADOUT_LOOPBACK_TIMEOUT_MS: '30000', LOADOUT_LOOPBACK_RELEASE_WAIT_MS: '15000'},
    });
    assert.equal(run.timedOut, false, 'harness finished inside the bound');
    assert.equal(run.code, 0, run.output);
    assert.match(run.output, /PORT_LOADOUT_LOOPBACK_OK/);
    assert.match(run.output, /PORT_LOADOUT_BARRIER released host=0 guest=0/);
    assert.equal(releasedFlag(dir, 'host'), 'released');
    assert.equal(releasedFlag(dir, 'guest'), 'released');
    assert.equal(existsSync(join(dir, 'killed-host')), false, 'host was never killed');
    assert.equal(existsSync(join(dir, 'killed-guest')), false, 'guest was never killed');
    assert.equal(await pidGone(dir, 'host'), true);
    assert.equal(await pidGone(dir, 'guest'), true);
    tidiness(dir);
    output = run.output;
  } finally {
    survivors = await cleanup(dir);
  }
  assert.deepEqual(survivors, [], 'no fixture-owned client survived the barrier scenario');
  assert.equal(existsSync(dir), false, 'the scenario dir was removed');
  return output;
}

test('host proves first: it holds until the delayed guest finishes, then both are released cleanly', async () => {
  const output = await barrierScenario('guest');
  // The delayed guest reported after the host's proof, with the host's
  // heartbeat still fresh (the stub fails otherwise) and never force-killed.
  assert.ok(output.indexOf('[host] PORT_LOADOUT_LIVE_OK') < output.indexOf('[guest] PORT_LOADOUT_LIVE_OK'),
    'guest proof follows the host proof');
});

test('guest proves first: the host is not evacuated while it finishes its own proof', async () => {
  const output = await barrierScenario('host');
  assert.ok(output.indexOf('[guest] PORT_LOADOUT_LIVE_OK') < output.indexOf('[host] PORT_LOADOUT_LIVE_OK'),
    'host proof follows the guest proof');
});

test('the native client implements the hold/release handshake instead of quitting after its proof', () => {
  const source = readFileSync(LIVE_GD, 'utf8');
  assert.match(source, /--release-file=/, 'client accepts the harness release file');
  assert.match(source, /release_file\.is_empty\(\)/, 'client polls the release file');
  assert.match(source, /PORT_LOADOUT_LIVE_HELD/, 'client reports that it is holding');
  assert.match(source, /PORT_LOADOUT_LIVE_RELEASED/, 'client reports its released exit');
  assert.equal(/if finished: return true/.test(source), false,
    'the success path must not quit the client while the peer is still proving');
  // Hold budget: a client may spend PROOF_DEADLINE_SECONDS proving its own view,
  // so the peer's proof can legally land that far after this one. The hold must
  // cover that whole window plus a release hop, or a slow-but-legal peer gets
  // misreported as this client giving up early. Both bounds are compiled in.
  const bound = name => {
    const match = new RegExp('const ' + name + ' := ([0-9]+(?:\\.[0-9]+)?)').exec(source);
    assert.ok(match, name + ' is a compiled constant');
    return Number(match[1]);
  };
  const proofDeadline = bound('PROOF_DEADLINE_SECONDS');
  const releaseHop = bound('RELEASE_HOP_SECONDS');
  const hold = bound('HOLD_SECONDS');
  assert.ok(proofDeadline > 0 && releaseHop > 0 && hold > 0, 'the hold bounds are positive constants');
  assert.ok(hold >= proofDeadline + releaseHop,
    `the hold (${hold}s) covers the proof deadline (${proofDeadline}s) plus the release hop (${releaseHop}s)`);
  assert.match(source, /if elapsed > PROOF_DEADLINE_SECONDS:/, 'the proof deadline is the single bound enforced while proving');
  assert.match(source, /if elapsed > hold_deadline:/, 'the hold stays bounded and fails closed');
});

test('a client that stops right after its own proof fails the run closed', async () => {
  const {dir, stub} = scenarioDir();
  let survivors = [];
  let stalled = 0;
  try {
    const run = await runHarness({
      dir, stub, boundMs: 20000,
      env: {STUB_MODE: 'exit-after-ok', STUB_EXIT_ROLE: 'guest',
        LOADOUT_LOOPBACK_TIMEOUT_MS: '15000', LOADOUT_LOOPBACK_RELEASE_WAIT_MS: '5000'},
    });
    assert.equal(run.timedOut, false, 'harness failed fast instead of hanging');
    assert.notEqual(run.code, 0, 'early client exit must never pass');
    assert.doesNotMatch(run.output, /PORT_LOADOUT_LOOPBACK_OK/);
    assert.equal(await pidGone(dir, 'guest'), true);
    stalled = pidOf(dir, 'host');
  } finally {
    survivors = await cleanup(dir);
  }
  assert.deepEqual(survivors, [], 'no fixture-owned client survived the early-exit scenario');
  assert.equal(stubOwnsPid(dir, stalled), false, 'the surviving client was reaped');
  assert.equal(existsSync(dir), false, 'the scenario dir was removed');
});

test('a client that never reports fails the run closed and is reaped', async () => {
  const {dir, stub} = scenarioDir();
  let survivors = [];
  let stalled = 0;
  try {
    const run = await runHarness({
      dir, stub, boundMs: 20000,
      env: {STUB_MODE: 'silent', LOADOUT_LOOPBACK_TIMEOUT_MS: '2500', LOADOUT_LOOPBACK_RELEASE_WAIT_MS: '5000'},
    });
    assert.equal(run.timedOut, false, 'harness timeout fired instead of hanging');
    assert.notEqual(run.code, 0);
    assert.doesNotMatch(run.output, /PORT_LOADOUT_LOOPBACK_OK/);
    assert.equal(existsSync(join(dir, 'killed-host')), true, 'stalled client was terminated by the harness');
    stalled = pidOf(dir, 'host');
  } finally {
    survivors = await cleanup(dir);
  }
  assert.deepEqual(survivors, [], 'no fixture-owned client survived the stalled scenario');
  assert.equal(stubOwnsPid(dir, stalled), false, 'the stalled client is gone');
  assert.equal(existsSync(dir), false, 'the scenario dir was removed');
});

test('a wrong identity payload still fails the run (the barrier never replaces the identity proof)', async () => {
  const {dir, stub} = scenarioDir();
  let survivors = [];
  let forged = 0;
  try {
    const run = await runHarness({
      dir, stub, boundMs: 20000,
      env: {STUB_MODE: 'hold', STUB_FORGE_SELF: 'guest',
        LOADOUT_LOOPBACK_TIMEOUT_MS: '15000', LOADOUT_LOOPBACK_RELEASE_WAIT_MS: '5000'},
    });
    assert.equal(run.timedOut, false);
    assert.notEqual(run.code, 0, 'forged identity must fail');
    assert.doesNotMatch(run.output, /PORT_LOADOUT_LOOPBACK_OK/);
    forged = pidOf(dir, 'guest');
  } finally {
    survivors = await cleanup(dir);
  }
  assert.deepEqual(survivors, [], 'no fixture-owned client survived the forged-identity scenario');
  assert.equal(stubOwnsPid(dir, forged), false, 'the forged client is gone');
  assert.equal(existsSync(dir), false, 'the scenario dir was removed');
});

test('a harness force-killed by the test bound still leaves no orphan client or temp dir', async () => {
  const {dir, stub} = scenarioDir();
  let survivors = [];
  let orphan = 0;
  try {
    // The silent client never reports, so the harness is still inside its own
    // (long) proof window when the test bound fires and force-kills it: exactly
    // the abort path that used to strand the client and its scenario dir.
    const run = await runHarness({
      dir, stub, boundMs: 4000,
      env: {STUB_MODE: 'silent', LOADOUT_LOOPBACK_TIMEOUT_MS: '30000', LOADOUT_LOOPBACK_RELEASE_WAIT_MS: '5000'},
    });
    assert.equal(run.timedOut, true, 'the test bound force-killed the harness');
    orphan = await waitForPid(dir, 'host', 2000);
    assert.notEqual(orphan, 0, 'the silent client started and recorded its pid');
    assert.equal(stubOwnsPid(dir, orphan), true, 'the client outlived its harness (a fixture is there to leak)');
  } finally {
    survivors = await cleanup(dir);
  }
  assert.deepEqual(survivors, [], 'the forced-timeout fixture was reaped, not left running');
  assert.equal(stubOwnsPid(dir, orphan), false, 'no fixture-owned client survives the test');
  assert.equal(existsSync(dir), false, 'the scenario dir was removed');
});

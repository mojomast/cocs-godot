import {spawn} from 'node:child_process';
import {readFileSync, mkdtempSync, mkdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {options, HELP} from './options.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const executable = process.platform === 'win32' ? 'cocs.exe' : 'cocs.x86_64';

// One direct route run: validate nothing (options() already ran), construct the
// authority when the plan owns one, spawn the scene and clean up. All marker
// strings (PACKAGE_SERVER_READY, PACKAGE_NATIVE_ONLY, PACKAGE_EXTERNAL_AUTHORITY,
// PACKAGE_NATIVE_STARTED, PACKAGE_STOPPED) and the cleanup semantics are exactly
// the pre-menu behavior; verifiers grep them byte-for-byte.
async function runRoute(plan, env) {
  // Arm the debug channel in-process (authority factory) and for the child,
  // BEFORE any authority module is imported or constructed. options() already
  // guarantees lobby can never carry --debug-panel.
  const debug = plan.userArgs.includes('--debug-panel');
  if (debug) { process.env.COCS_DEBUG = '1'; }
  // These paths are relative to this artifact, never to the caller's cwd/repo.
  // Native-only scenes and external lobby never import local authority adapters.
  const factory = plan.nativeOnly || plan.endpoint ? null : plan.nativeArena
    ? (await import('./runtime/port/native-arenas/authority.mjs')).createNativeArenaAuthority
    : plan.identityZone
    ? (await import('./runtime/port/native-identity-zones/authority.mjs')).createIdentityZoneAuthority
    : plan.experience === 'horde'
    ? (await import('./runtime/port/native-horde/authority.mjs')).createAuthority
    : (await import('./runtime/server/game-server.mjs')).createGameServer;
  const runtime = mkdtempSync(join(tmpdir(), 'cocs-native-'));
  const childEnv = {...env};
  if (debug) childEnv.COCS_DEBUG = '1';
  for (const name of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
    childEnv[name] = join(runtime, name); mkdirSync(childEnv[name]);
  }
  let game;
  let child, childDone, stopping = false, signalCode = 0, serverFailure, killTimer, smokeTimer;
  const stop = () => {
    stopping = true;
    if (child && child.exitCode === null && child.signalCode === null) {
      child.kill('SIGTERM');
      killTimer ??= setTimeout(() => child.kill('SIGKILL'), 3000);
      killTimer.unref();
    }
  };
  const interrupt = () => { signalCode = 130; stop(); };
  const terminate = () => { signalCode = 143; stop(); };
  const serverError = error => { serverFailure = error; stop(); };
  process.on('SIGINT', interrupt); process.on('SIGTERM', terminate);
  try {
    game = await factory?.(plan.nativeArena ? {port:0, host:'127.0.0.1', mapId:plan.map, mode:plan.mode, bots:plan.bots, roundSeconds:plan.roundSeconds} : plan.identityZone ? {port:0, host:'127.0.0.1', mode:plan.mode, bots:plan.bots, roundSeconds:plan.roundSeconds, fragLimit:plan.scoreLimit} : plan.experience === 'horde' ? {} : {historyPath:null, progressionPath:null});
    game?.server?.on('error', serverError);
    let endpoint = plan.endpoint;
    if (game) {
      if (!(plan.nativeArena || plan.identityZone) || (!game.endpoint && !game.server?.listening)) await new Promise((resolve, reject) => {
        game.server.once('error', reject);
        game.server.listen(0, '127.0.0.1', () => { game.server.removeListener('error', reject); resolve(); });
      });
      const ownedEndpoint = (plan.nativeArena || plan.identityZone) && game.endpoint ? game.endpoint : `ws://127.0.0.1:${game.server.address().port}`;
      const owned = new URL(ownedEndpoint);
      // Accept only the authority's exact routes, including before URL normalization.
      const allowedPath = plan.nativeArena ? [owned.origin, `${owned.origin}/`, `${owned.origin}/native-arenas`].includes(ownedEndpoint)
        : plan.identityZone ? [owned.origin, `${owned.origin}/`, `${owned.origin}/native-zones`].includes(ownedEndpoint)
        : owned.pathname === '/';
      if (owned.protocol !== 'ws:' || owned.hostname !== '127.0.0.1' || !owned.port || owned.username || owned.password || !allowedPath || owned.search || owned.hash) throw Error('Owned authority must use a private loopback endpoint');
      const port = Number(owned.port);
      const health = await fetch(`http://127.0.0.1:${port}/`, {signal:AbortSignal.timeout(5000)});
      const status = await health.json();
      const identity = plan.nativeArena ? status?.localOnly === true
        : plan.identityZone ? status?.localOnly === true && status?.mode === 'domination'
        : plan.experience === 'horde'
        ? status?.service === 'cocs-local-horde' && status.transport === 1 && status.localOnly === true
        : status?.service === 'token-arena-game-server';
      if (!health.ok || status?.port !== port || !identity) throw Error('Owned server health check failed');
      if (stopping) return signalCode || 1;
      console.log('PACKAGE_SERVER_READY ' + JSON.stringify({pid:process.pid, host:'127.0.0.1', port, experience:plan.experience, map:plan.map, mode:plan.mode, health:status}));
      const ownedPath = plan.nativeArena && owned.pathname === '/native-arenas' ? '/native-arenas'
        : plan.identityZone && owned.pathname === '/native-zones' ? '/native-zones' : '';
      endpoint = `ws://127.0.0.1:${port}${ownedPath}`;
    } else if (plan.nativeOnly) {
      console.log('PACKAGE_NATIVE_ONLY ' + JSON.stringify({authority:false, experience:plan.experience}));
    } else {
      console.log('PACKAGE_EXTERNAL_AUTHORITY ' + JSON.stringify({owned:false, experience:plan.experience}));
    }
    if (stopping) return signalCode || 1;
    const engineArgs = plan.userArgs.some(arg => ['--session-smoke','--smoke'].includes(arg)) ? ['--headless','--audio-driver','Dummy'] : [];
    const endpointArgs = plan.nativeOnly ? [] : [`--endpoint=${endpoint}`];
    child = spawn(join(root, executable), [...engineArgs, '--main-pack',join(root, 'cocs.pck'), plan.scene, '--', ...endpointArgs, ...plan.userArgs], {cwd:root, env:childEnv, stdio:'inherit'});
    childDone = new Promise((resolve, reject) => { child.once('error', reject); child.once('exit', (code, signal) => resolve({code, signal})); });
    if (plan.nativeArena && plan.userArgs.includes('--smoke')) smokeTimer = setTimeout(() => serverError(Error('Native DM smoke exceeded 20 seconds')), 20000);
    console.log('PACKAGE_NATIVE_STARTED ' + JSON.stringify({pid:child.pid, scene:plan.scene}));
    const result = await childDone;
    if (serverFailure) throw serverFailure;
    return signalCode || result.code || (result.signal ? 1 : 0);
  } finally {
    stop();
    if (childDone) await childDone.catch(() => {});
    clearTimeout(killTimer);
    clearTimeout(smokeTimer);
    // The native process is gone: terminate any residual WS close handshake.
    if (game) {
      for (const socket of game.wss?.clients ?? []) socket.terminate();
      game.server?.closeAllConnections();
      await game.close();
      game.server?.removeListener('error', serverError);
    }
    process.removeListener('SIGINT', interrupt); process.removeListener('SIGTERM', terminate);
    rmSync(runtime, {recursive:true, force:true, maxRetries:5, retryDelay:100});
    console.log('PACKAGE_STOPPED');
  }
}

// Spawn the main-menu child and tee its stdout/stderr line-by-line to ours.
// Resolves with the raw JSON text following a `MENU_ROUTE ` line, or null when
// the menu quits (MENU_QUIT) or exits without picking a route.
function spawnMenu(menuPlan, env) {
  return new Promise((resolve, reject) => {
    // Same executable/main-pack pattern as routes; headless only under --smoke.
    const engineArgs = menuPlan.userArgs.includes('--smoke') ? ['--headless','--audio-driver','Dummy'] : [];
    const child = spawn(join(root, executable),
      [...engineArgs, '--main-pack', join(root, 'cocs.pck'), menuPlan.scene, '--', ...menuPlan.userArgs],
      {cwd:root, env, stdio:['inherit','pipe','pipe']});
    let payload = null;
    const onLine = line => {
      const clean = line.endsWith('\r') ? line.slice(0, -1) : line;
      if (clean.startsWith('MENU_ROUTE ')) payload = clean.slice('MENU_ROUTE '.length);
    };
    const tee = (stream, write) => {
      let buffer = '';
      stream.setEncoding('utf8');
      stream.on('data', chunk => {
        buffer += chunk;
        let index;
        while ((index = buffer.indexOf('\n')) !== -1) {
          const line = buffer.slice(0, index); buffer = buffer.slice(index + 1);
          write(line); onLine(line);
        }
      });
      stream.on('end', () => { if (buffer !== '') { write(buffer); onLine(buffer); buffer = ''; } });
    };
    tee(child.stdout, line => console.log(line));
    tee(child.stderr, line => console.error(line));
    child.once('error', reject);
    child.once('exit', () => resolve(payload));
  });
}

// Supervisor half of the loop: boot the menu, parse `MENU_ROUTE ` payloads and
// re-validate them with the SAME options() validator used by direct entry.
// Returns the picked argv (caller re-parses it into a plan), or null for
// MENU_QUIT / a menu exit without a route. Throws after 3 consecutive
// rejections so a wedged menu can never spin the supervisor forever.
async function menuPick(menuPlan, catalog, env) {
  let rejections = 0;
  for (;;) {
    const payload = await spawnMenu(menuPlan, env);
    if (payload === null) return null;
    try {
      const parsed = JSON.parse(payload);
      if (!parsed || !Array.isArray(parsed.args)) throw Error('MENU_ROUTE payload must be {"args":[...]}');
      options(parsed.args, catalog);
      return parsed.args.map(String);
    } catch (error) {
      console.log('MENU_ROUTE_REJECTED ' + JSON.stringify({error:error.message}));
      if (++rejections >= 3) throw Error(`menu route rejected three consecutive times: ${error.message}`);
    }
  }
}

async function main() {
  if (process.argv.length === 3 && process.argv[2] === '--help') { console.log(HELP); return 0; }
  const version = process.versions.node.split('.').map(Number);
  if (version[0] < 22 || (version[0] === 22 && version[1] < 13)) throw Error('Node >=22.13.0 required');
  const catalog = JSON.parse(readFileSync(join(root, 'catalog.json')));
  const plan = options(process.argv.slice(2), catalog);
  const env = {...process.env};
  // Loop only for a default boot (argv empty → menu) or an explicit
  // --experience=menu without --smoke. Every direct route invocation runs
  // exactly once and exits, keeping all verifier/marker contracts untouched.
  if (!(plan.experience === 'menu' && !plan.userArgs.includes('--smoke'))) return await runRoute(plan, env);
  let fastFailures = 0;
  for (;;) {
    const args = await menuPick(plan, catalog, env);
    if (args === null) return 0;
    const routePlan = options(args, catalog); // revalidate with the same options()
    const started = Date.now();
    const code = await runRoute(routePlan, env);
    // Ctrl+C/Ctrl+TERM during a route ends the supervisor; it is an explicit
    // stop, not a crash loop.
    if (code === 130 || code === 143) return code;
    // No crash loop: three non-zero route exits in a row, each under 2s.
    if (code !== 0 && Date.now() - started < 2000) {
      if (++fastFailures >= 3) return 1;
    } else fastFailures = 0;
    // Route exited → boot the menu again.
  }
}
try { process.exitCode = await main(); }
catch (error) { console.error(`Package launch failed: ${error.message}`); process.exitCode = 1; }

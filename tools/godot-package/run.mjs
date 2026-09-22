import {spawn} from 'node:child_process';
import {readFileSync, mkdtempSync, mkdirSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {options, HELP} from './options.mjs';

const root = dirname(fileURLToPath(import.meta.url));
async function main() {
  if (process.argv.length === 3 && process.argv[2] === '--help') { console.log(HELP); return 0; }
  const version = process.versions.node.split('.').map(Number);
  if (version[0] < 22 || (version[0] === 22 && version[1] < 13)) throw Error('Node >=22.13.0 required');
  const plan = options(process.argv.slice(2), JSON.parse(readFileSync(join(root, 'catalog.json'))));
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
  const env = {...process.env};
  for (const name of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
    env[name] = join(runtime, name); mkdirSync(env[name]);
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
    const executable = process.platform === 'win32' ? 'cocs.exe' : 'cocs.x86_64';
    const engineArgs = plan.userArgs.some(arg => ['--session-smoke','--smoke'].includes(arg)) ? ['--headless','--audio-driver','Dummy'] : [];
    const endpointArgs = plan.nativeOnly ? [] : [`--endpoint=${endpoint}`];
    child = spawn(join(root, executable), [...engineArgs, '--main-pack',join(root, 'cocs.pck'), plan.scene, '--', ...endpointArgs, ...plan.userArgs], {cwd:root, env, stdio:'inherit'});
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
try { process.exitCode = await main(); }
catch (error) { console.error(`Package launch failed: ${error.message}`); process.exitCode = 1; }

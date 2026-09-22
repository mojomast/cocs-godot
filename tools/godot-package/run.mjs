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
  const {createGameServer} = await import('./runtime/server/game-server.mjs');
  const runtime = mkdtempSync(join(tmpdir(), 'cocs-native-'));
  const env = {...process.env};
  for (const name of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
    env[name] = join(runtime, name); mkdirSync(env[name]);
  }
  const game = plan.endpoint ? null : createGameServer({historyPath:null, progressionPath:null});
  let child, childDone, stopping = false, signalCode = 0, serverFailure, killTimer;
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
  game?.server.on('error', serverError);
  try {
    let endpoint = plan.endpoint;
    if (game) {
      await new Promise((resolve, reject) => {
        game.server.once('error', reject);
        game.server.listen(0, '127.0.0.1', () => { game.server.removeListener('error', reject); resolve(); });
      });
      const port = game.server.address().port;
      const health = await fetch(`http://127.0.0.1:${port}/`, {signal:AbortSignal.timeout(5000)});
      const status = await health.json();
      if (!health.ok || status.port !== port || status.service !== 'token-arena-game-server') throw Error('Owned server health check failed');
      if (stopping) return signalCode || 1;
      console.log('PACKAGE_SERVER_READY ' + JSON.stringify({pid:process.pid, host:'127.0.0.1', port, experience:plan.experience, map:plan.map, mode:plan.mode, health:status}));
      endpoint = `ws://127.0.0.1:${port}`;
    } else {
      console.log('PACKAGE_EXTERNAL_AUTHORITY ' + JSON.stringify({owned:false, experience:plan.experience}));
    }
    if (stopping) return signalCode || 1;
    child = spawn(join(root, 'cocs.x86_64'), ['--main-pack',join(root, 'cocs.pck'), plan.scene, '--', `--endpoint=${endpoint}`, ...plan.userArgs], {cwd:root, env, stdio:'inherit'});
    childDone = new Promise((resolve, reject) => { child.once('error', reject); child.once('exit', (code, signal) => resolve({code, signal})); });
    console.log('PACKAGE_NATIVE_STARTED ' + JSON.stringify({pid:child.pid, scene:plan.scene}));
    const result = await childDone;
    if (serverFailure) throw serverFailure;
    return signalCode || result.code || (result.signal ? 1 : 0);
  } finally {
    stop();
    if (childDone) await childDone.catch(() => {});
    clearTimeout(killTimer);
    // The native process is gone: terminate any residual WS close handshake.
    if (game) {
      for (const socket of game.wss.clients) socket.terminate();
      game.server.closeAllConnections();
      await game.close();
      game.server.removeListener('error', serverError);
    }
    process.removeListener('SIGINT', interrupt); process.removeListener('SIGTERM', terminate);
    rmSync(runtime, {recursive:true, force:true});
    console.log('PACKAGE_STOPPED');
  }
}
try { process.exitCode = await main(); }
catch (error) { console.error(`Package launch failed: ${error.message}`); process.exitCode = 1; }

// Requires the orchestrator's explicit engine grant. Sequential normal-rate
// production sessions; deterministic source challenge date, no seeded rewards.
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createGameServer as sourceServer} from '../../../server/game-server.mjs';
import {installChallenges} from './challenge-authority.mjs';

if (process.env.CHALLENGE_ENGINE_GRANT !== '1') throw Error('Explicit engine slot grant required');
const binary = process.env.GODOT_BIN;
assert.ok(binary, 'Pinned GODOT_BIN required');
const lock = JSON.parse(readFileSync(new URL('../../contracts/source-lock.json', import.meta.url)));
assert.equal(execFileSync(binary, ['--version'], {encoding:'utf8'}).trim(), lock.godot_version);
const out = resolve(process.env.MODE_EVIDENCE ?? `/tmp/opencode/challenges-native-${Date.now()}`);
mkdirSync(out, {recursive:true});
const temp = mkdtempSync('/tmp/opencode/challenges-native-');
const children = [];
let game;
const env = {...process.env, LP_NUM_THREADS:'1'};
for (const name of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) {
  env[name] = join(temp, name); mkdirSync(env[name]);
}
env.COCS_CAREER_CREDENTIALS_PATH = join(temp, 'credentials.json');
env.COCS_CAREER_SCOPE = 'challenge-native-proof';
writeFileSync(env.COCS_CAREER_CREDENTIALS_PATH, JSON.stringify({version:1, scopes:{}}), {mode:0o600});
function child(command, args, options) {
  const p = spawn(command, args, options);
  p.done = new Promise((res, rej) => {p.once('error', rej); p.once('close', (code, signal) => res({code, signal}));});
  children.push(p); return p;
}
async function stop(p) {
  if (p.exitCode !== null || p.signalCode !== null) return;
  p.kill('SIGTERM'); const timer = setTimeout(() => p.kill('SIGKILL'), 3000);
  await p.done; clearTimeout(timer);
}
const interrupted = () => {for (const p of children) p.kill('SIGTERM');};
process.on('SIGTERM', interrupted); process.on('SIGINT', interrupted);
try {
  const display = child('Xvfb', ['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'], {stdio:['ignore','ignore','pipe','pipe']});
  const number = await new Promise((res, rej) => {
    let buffer = '';
    const timer = setTimeout(() => rej(Error('Xvfb timeout')), 5000);
    display.stdio[3].on('data', bytes => {buffer += bytes; if (/^\d+\n$/.test(buffer)) {clearTimeout(timer); res(buffer.trim());}});
  });
  env.DISPLAY = ':' + number;
  let previous;
  for (let session = 0; session < 2; session++) {
    const evidence = join(out, `session-${session}`); mkdirSync(evidence);
    game = installChallenges(sourceServer({historyPath:join(temp,'history.json'), progressionPath:join(temp,'career.json')}),
      {now: () => Date.UTC(2026,9,2)});
    if (previous) {
      const restored = [...game.progression.players.values()][0];
      assert.equal(restored.xp, previous.xp); assert.equal(restored.matches, 3);
      assert.deepEqual(restored.portChallenges, previous.challenges);
    }
    await new Promise(res => game.server.listen(0,'127.0.0.1',res));
    const endpoint = `ws://127.0.0.1:${game.server.address().port}`;
    let stdout = '', stderr = '';
    const native = child(binary, ['--audio-driver','Dummy','--path','godot','--resolution','1280x720',
      'res://tests/mode_expansion/challenges_live.tscn','--',`--endpoint=${endpoint}`,
      '--map=meridian-exchange','--mode=juggernaut','--bots=0','--time-limit=60'],
      {env:{...env, COCS_CAREER_ENDPOINT:endpoint, CHALLENGE_EVIDENCE:evidence, CHALLENGE_RELOAD:String(session)}, stdio:['ignore','pipe','pipe']});
    native.stdout.on('data', bytes => {stdout += bytes;});
    native.stderr.on('data', bytes => {stderr += bytes;});
    const timer = setTimeout(() => void stop(native), session ? 90000 : 200000);
    let result;
    try {result = await native.done;} finally {
      clearTimeout(timer); writeFileSync(join(evidence,'stdout.log'),stdout); writeFileSync(join(evidence,'stderr.log'),stderr);
    }
    assert.equal(result.code,0); assert.match(stdout,/CHALLENGE_JOURNEY_OK/);
    assert.doesNotMatch(stdout+stderr,/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use/);
    assert.match(stdout,session ? /CHALLENGE_RELOADED/ : /CHALLENGE_RECONNECT_OK/);
    for (const socket of game.wss.clients) socket.terminate();
    await game.close();
    assert.equal(await game.progression.whenPersisted(),true);
    assert.equal(await game.history.whenPersisted(),true);
    const disk = JSON.parse(readFileSync(join(temp,'career.json')));
    assert.equal(disk.players.length,1);
    const profile = disk.players[0];
    assert.equal(profile.matches,session ? 4 : 3);
    previous = {xp:profile.xp,matches:profile.matches,challenges:profile.portChallenges,gear:profile.gear,unlocks:profile.unlocks};
    writeFileSync(join(evidence,'persisted-proof.json'),JSON.stringify(previous,null,2));
    game = null;
  }
  writeFileSync(join(out,'acceptance.json'),JSON.stringify({normalRate:true,sessions:2,sourceMatches:4,sourceDate:'2026-10-02',result:previous},null,2));
} catch (error) {
  writeFileSync(join(out,'failure.log'),String(error.stack)); throw error;
} finally {
  for (const p of [...children].reverse()) await stop(p);
  if (game) {for (const socket of game.wss.clients) socket.terminate(); await game.close();}
  rmSync(temp,{recursive:true,force:true});
  writeFileSync(join(out,'cleanup.json'),JSON.stringify(children.map(p=>({pid:p.pid,code:p.exitCode,signal:p.signalCode})),null,2));
  process.off('SIGTERM',interrupted); process.off('SIGINT',interrupted);
}

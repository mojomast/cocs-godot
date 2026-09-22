// Owned loopback authority, unmodified normal-rate simulation, bounded children.
// GODOT_BIN must be the already-installed pinned toolchain; no installs/services.
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, writeFileSync, readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {createGameServer} from '../../server/game-server.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const output = resolve(root, 'port/native-mode-expansion');
const binary = process.env.GODOT_BIN;
const lock = JSON.parse(readFileSync(resolve(root, 'port/contracts/source-lock.json')));
if (!binary || execFileSync(binary, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Pinned GODOT_BIN required');
const game = createGameServer({historyPath:null, progressionPath:null});
const children = new Set();
await new Promise((ok, fail) => {game.server.once('error', fail); game.server.listen(0, '127.0.0.1', ok);});
const endpoint = `ws://127.0.0.1:${game.server.address().port}`;
const env = {...process.env};
for (const kind of ['DATA','CONFIG','CACHE']) {
  env[`XDG_${kind}_HOME`] = resolve(root, '.port-runtime/modes', kind.toLowerCase());
  mkdirSync(env[`XDG_${kind}_HOME`], {recursive:true});
}
async function run(map, mode, smoke = false) {
  const name = `${map}-${mode}${smoke ? '-session' : ''}`;
  const args = ['--headless','--audio-driver','Dummy','--path',resolve(root,'godot'),
    ...(smoke ? ['res://world/session.tscn'] : ['--script','res://tests/protocol/native_modes_live.gd']),
    '--',`--endpoint=${endpoint}`,`--map=${map}`,`--mode=${mode}`,'--mute',...(smoke ? ['--session-smoke'] : [])];
  const child = spawn(binary, args, {cwd:root, env, stdio:['ignore','pipe','pipe']});
  children.add(child);
  let text = '';
  const collect = data => {text += data; if (text.length > 100000) child.kill('SIGTERM');};
  child.stdout.on('data', collect); child.stderr.on('data', collect);
  const timer = setTimeout(() => child.kill('SIGKILL'), smoke ? 30000 : 85000);
  const code = await new Promise((ok, fail) => {child.once('error', fail); child.once('exit', ok);});
  clearTimeout(timer); children.delete(child);
  writeFileSync(resolve(output, `${name}.log`), text);
  const marker = smoke ? 'PORT_SESSION_SMOKE_OK' : 'PORT_NATIVE_MODE_LIVE_OK';
  if (code !== 0 || /SCRIPT ERROR|ERROR:/.test(text) || !text.includes(marker)) throw Error(`${name} failed; see owned log`);
  console.log(text.split('\n').find(line => line.startsWith(marker)));
  return smoke ? null : JSON.parse(text.split('\n').find(line => line.startsWith(marker)).slice(marker.length));
}
try {
  for (const mode of process.argv.includes('--session-only') ? [] : ['teamdeathmatch', 'rockets']) {
    const results = await Promise.all(['meridian-exchange','verdant-reliquary','ember-crucible'].map(map => run(map, mode)));
    if (mode === 'teamdeathmatch' && !results.some(result => result.team_score_changes > 0)) throw Error('No real team-score change observed across the three rounds');
  }
  for (const map of ['meridian-exchange','verdant-reliquary','ember-crucible']) await run(map, 'teamdeathmatch', true);
} finally {
  for (const child of children) child.kill('SIGKILL');
  for (const ws of game.wss.clients) ws.terminate();
  await game.close();
}

// Owned normal-rate authority + private Xvfb; source and dependency trees read-only.
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {cpSync, mkdirSync, mkdtempSync, symlinkSync, writeFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const binary = process.env.GODOT_BIN;
const deps = process.env.GUEST_NODE_MODULES;
assert.ok(binary && deps, 'Set GODOT_BIN and GUEST_NODE_MODULES');
assert.equal(execFileSync(binary, ['--version'], {encoding:'utf8'}).trim(), '4.5.2.stable.official.6ce3de25a');
const temp = mkdtempSync('/tmp/opencode/cocs-hud-capture-');
const out = resolve(process.argv.find(a => a.startsWith('--output='))?.slice(9) ?? resolve(root, 'port/native-game-hud/evidence'));
mkdirSync(out, {recursive:true});
const env = {PATH:process.env.PATH, HOME:temp, LANG:'C.UTF-8', LIBGL_ALWAYS_SOFTWARE:'1'};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) {
  env[key] = resolve(temp, key);
  mkdirSync(env[key]);
}
for (const dir of ['game', 'server']) cpSync(resolve(root, dir), resolve(temp, dir), {recursive:true});
symlinkSync(resolve(deps), resolve(temp, 'node_modules'), 'dir');
const {createGameServer} = await import(pathToFileURL(resolve(temp, 'server/game-server.mjs')));
const game = createGameServer({historyPath:null, progressionPath:null});
const children = [];
function launch(command, args, options = {}) {
  const child = spawn(command, args, {cwd:root, env, stdio:['ignore','pipe','pipe'], ...options});
  children.push(child);
  child.text = '';
  child.stdout.on('data', data => child.text += data);
  child.stderr.on('data', data => child.text += data);
  child.done = new Promise((res, rej) => {
    child.once('error', rej);
    child.once('close', code => res(code));
  });
  return child;
}
const deadline = setTimeout(() => {
  for (const child of children) if (child.exitCode === null) child.kill('SIGKILL');
  game.close();
}, 60000);
try {
  await new Promise(res => game.server.listen(0, '127.0.0.1', res));
  const endpoint = `ws://127.0.0.1:${game.server.address().port}`;
  const display = launch('Xvfb', ['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'], {stdio:['ignore','pipe','pipe','pipe']});
  const number = await new Promise((res, rej) => {
    let text = '';
    display.stdio[3].on('data', data => { text += data; if (/^\d+\n$/.test(text)) res(text.trim()); });
    display.once('exit', () => rej(Error('Xvfb exited')));
  });
  env.DISPLAY = `:${number}`;
  const evidence = [];
  for (const [name, resolution, script, args] of [
    ['live-960x640', '960x640', 'game_hud_live_capture', [`--endpoint=${endpoint}`]],
    ['live-1280x800', '1280x800', 'game_hud_live_capture', [`--endpoint=${endpoint}`]],
    ['synthetic-respawn-960x640', '960x640', 'game_hud_visual', []],
    ['synthetic-results-1280x800', '1280x800', 'game_hud_visual', ['--hud-results']],
  ]) {
    const child = launch(binary, ['--path','godot','--audio-driver','Dummy','--max-fps','60','--resolution',resolution,'--script',`res://tests/protocol/${script}.gd`,'--',...args,`--hud-capture=${resolve(out, name + '.png')}`]);
    const code = await child.done;
    writeFileSync(resolve(out, name + '.log'), child.text);
    assert.equal(code, 0, child.text);
    assert.match(child.text, /PORT_GAME_HUD_(LIVE_CAPTURE|VISUAL)_OK/);
    assert.doesNotMatch(child.text, /SCRIPT ERROR|ERROR:/);
    evidence.push({name, resolution, synthetic:script === 'game_hud_visual', exit:code});
  }
  writeFileSync(resolve(out, 'results.json'), JSON.stringify({godot:'4.5.2', normalRate:true, tickDt:1/60, tickMs:1000/60, renderer:'Mesa llvmpipe', audio:'Dummy', evidence}, null, 2) + '\n');
  console.log('PORT_GAME_HUD_CAPTURE_OK', JSON.stringify(evidence));
} finally {
  clearTimeout(deadline);
  for (const child of children) if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM');
  await game.close();
  await Promise.allSettled(children.map(child => child.done));
  rmSync(temp, {recursive:true, force:true});
}

// Focused, normal-rate native selection acceptance. No authority state mutation.
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {cpSync, mkdirSync, mkdtempSync, symlinkSync, writeFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
const root = fileURLToPath(new URL('../../', import.meta.url));
const binary = process.env.GODOT_BIN, deps = process.env.GUEST_NODE_MODULES;
const menuOnly = process.argv.includes('--menu-only');
const menuMode = process.argv.find(arg=>arg.startsWith('--menu-mode='))?.slice('--menu-mode='.length) ?? 'instagib';
assert.ok(['deathmatch','teamdeathmatch','instagib','rockets'].includes(menuMode));
assert.ok(binary && deps, 'Set GODOT_BIN and GUEST_NODE_MODULES');
const temp = mkdtempSync('/tmp/opencode/cocs-selection-');
const out = resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9) ?? resolve(root, 'port/native-match-selection/runs', new Date().toISOString().replaceAll(':','-')));
mkdirSync(out, {recursive:true});
const env = {PATH:process.env.PATH, HOME:temp, LANG:'C.UTF-8', LIBGL_ALWAYS_SOFTWARE:'1'};
for (const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
  env[key] = resolve(temp, key); mkdirSync(env[key]);
}
for (const dir of ['game','server']) cpSync(resolve(root, dir), resolve(temp, dir), {recursive:true});
symlinkSync(resolve(deps), resolve(temp, 'node_modules'), 'dir');
assert.equal(execFileSync(binary, ['--version'], {encoding:'utf8'}).trim(), '4.5.2.stable.official.6ce3de25a');
const {createGameServer} = await import(pathToFileURL(resolve(temp, 'server/game-server.mjs')));
const game = createGameServer({historyPath:null, progressionPath:null});
const children = [];
const observed = [];
let display;
function launch(command, args, extra = {}) {
  const child = spawn(command, args, {cwd:root, env, stdio:['ignore','pipe','pipe'], ...extra});
  children.push(child);
  child.text = ''; child.errors = '';
  child.stdout.on('data', d => child.text += d);
  child.stderr.on('data', d => child.errors += d);
  child.done = new Promise((res, rej) => {child.once('error', rej); child.once('close', code => res(code));});
  return child;
}
const deadline = setTimeout(() => {for (const c of children) c.kill('SIGKILL'); game.close();}, 58000);
try {
  await new Promise(res => game.server.listen(0, '127.0.0.1', res));
  const endpoint = `ws://127.0.0.1:${game.server.address().port}`;
  game.wss.on('connection', socket => {
    socket.on('message', data => {
      const f = JSON.parse(data.toString());
      if (f.type === 'host') observed.push({requestedMap:f.mapId, requestedMode:f.config.mode});
    });
    const original = socket.send;
    socket.send = function(data, ...args) {
      const f = JSON.parse(data.toString());
      if (f.type === 'snapshot' && observed.length) {
        const row = observed.at(-1);
        row.authorityMap = f.state.mapId; row.authorityMode = f.state.config.mode;
        row.actors = f.state.actors.length; row.snapshots = (row.snapshots ?? 0) + 1;
      }
      return original.call(this, data, ...args);
    };
  });
  for (const map of menuOnly ? [] : ['meridian-exchange','verdant-reliquary','ember-crucible']) {
    for (const mode of ['deathmatch','instagib']) {
      const native = launch(binary, ['--headless','--path','godot','res://world/session.tscn','--',`--endpoint=${endpoint}`,`--map=${map}`,`--mode=${mode}`,'--session-smoke']);
      const code = await native.done;
      writeFileSync(resolve(out, `${map}-${mode}.log`), native.text + native.errors);
      assert.equal(code, 0, native.errors);
      assert.match(native.text, /PORT_SESSION_SMOKE_OK/);
      assert.doesNotMatch(native.errors, /SCRIPT ERROR|ERROR:/);
      assert.equal(observed.at(-1).authorityMap, map);
      assert.equal(observed.at(-1).authorityMode, mode);
    }
  }
  display = launch('Xvfb', ['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'], {stdio:['ignore','pipe','pipe','pipe']});
  const number = await new Promise((res, rej) => {
    let text = '';
    display.stdio[3].on('data', d => {text += d; if (/^\d+\n$/.test(text)) res(text.trim());});
    display.once('exit', () => rej(Error('Xvfb exited')));
  });
  env.DISPLAY = `:${number}`;
  const native = launch(binary, ['--path','godot','--audio-driver','Dummy','--max-fps','60','--script','res://tests/protocol/match_selection_menu.gd','--',`--endpoint=${endpoint}`,'--setup',`--menu-mode=${menuMode}`,`--selection-evidence=${resolve(out,'menu.png')}`]);
  const code = await native.done;
  writeFileSync(resolve(out, 'menu.log'), native.text + native.errors);
  assert.equal(code, 0, native.errors);
  assert.match(native.text, /PORT_MATCH_MENU_OK/);
  assert.doesNotMatch(native.errors, /SCRIPT ERROR|ERROR:/);
  assert.equal(observed.at(-1).authorityMap, 'verdant-reliquary');
  assert.equal(observed.at(-1).authorityMode, menuMode);
  writeFileSync(resolve(out, 'results.json'), JSON.stringify({normalRate:true, tickDt:1/60, tickMs:1000/60, observed}, null, 2) + '\n');
  console.log('PORT_MATCH_SELECTION_LIVE_OK', JSON.stringify(observed));
} finally {
  clearTimeout(deadline);
  for (const child of children) if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM');
  await game.close();
  await Promise.allSettled(children.map(child => child.done));
  rmSync(temp, {recursive:true, force:true});
}

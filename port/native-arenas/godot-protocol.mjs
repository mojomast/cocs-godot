// Headless real WebSocket integration. Defaults to explicitly SYNTHETIC data;
// --actual loads the static generated asset without fixture substitution.
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createNativeArenaAuthority} from './authority.mjs';
import {syntheticArena, seededRandom} from './tests/fixtures.mjs';

const actual = process.argv.includes('--actual');
const mapId = process.argv.find(arg => arg.startsWith('--map='))?.slice(6) || 'prism-foundry';
const godot = process.env.GODOT_BIN;
if (!godot) throw new Error('Set GODOT_BIN to pinned Godot 4.5.2 executable');
for (const ordinary of [false, true]) {
  const authority = await createNativeArenaAuthority({port:0, host:'127.0.0.1', mapId,
    ...(actual ? {} : {arenaData:syntheticArena(mapId)}), random:seededRandom(42)});
  try {
    console.log(JSON.stringify({gate:'godot-live-protocol', data:actual ? 'generated' : 'SYNTHETIC', mapId, ordinary}));
    const child = spawn(godot, ['--headless', '--path', fileURLToPath(new URL('../../godot', import.meta.url)),
      '--script', 'res://tests/native_arenas/protocol/live_client.gd', '--',
      `--endpoint=${authority.endpoint}`, `--map=${mapId}`, ...(ordinary ? ['--ordinary'] : [])],
    {stdio:['ignore', 'pipe', 'pipe'], env:process.env});
    let output = '';
    child.stdout.on('data', bytes => { output += bytes; process.stdout.write(bytes); });
    child.stderr.on('data', bytes => process.stderr.write(bytes));
    const code = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { child.kill('SIGKILL'); reject(new Error('Godot protocol child timeout')); }, 30000);
      child.once('error', error => { clearTimeout(timer); reject(error); });
      child.once('close', code => { clearTimeout(timer); resolve(code); });
    });
    if (code !== 0 || !output.includes('NATIVE_ARENA_LIVE_PROTOCOL {') || !output.includes('"ok":true')) {
      throw new Error(`Godot live protocol failed: ${code}`);
    }
  } finally { await authority.close(); }
}

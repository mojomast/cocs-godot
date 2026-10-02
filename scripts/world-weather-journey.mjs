import {spawn} from 'node:child_process';
import {mkdirSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createAuthority} from '../port/native-campaign/authority.mjs';
import {createGameServer} from '../port/multiplayer-worlds/derived/game-server.mjs';
import {createGameServer as createSourceServer} from '../server/game-server.mjs';
import {WebSocket} from 'ws';
import {campaignInputDiagnostic} from './campaign-input-diagnostic.mjs';

const [kind, map, directory] = process.argv.slice(2);
if (!['campaign', 'mp', 'spectator', 'source'].includes(kind) || !map || !directory) throw Error('campaign|mp|spectator|source map absolute-output-dir');
const output = resolve(directory); mkdirSync(output, {recursive: true});
const observations = [];
const inputDiagnostic = campaignInputDiagnostic();
const authority = kind === 'campaign' ? createAuthority({mapId: map, difficulty: 'easy', observe: row => {
  // Record transport provenance and public state, never alter authority state.
  inputDiagnostic.observe(row);
  if (row.direction === 'in' && row.frame.type !== 'input' || row.direction === 'out' && ['start', 'results'].includes(row.frame.type)) observations.push(row);
}}) : (kind === 'source' ? createSourceServer : createGameServer)({random: () => .37});
await new Promise(resolve => authority.server.listen(0, '127.0.0.1', resolve));
const endpoint = `ws://127.0.0.1:${authority.server.address().port}${kind === 'campaign' ? '/native-campaign' : ''}`;
let host, room;
if (kind === 'spectator') {
  host = new WebSocket(endpoint);
  await new Promise((resolve, reject) => {
    let configured = false, started = 0;
    host.on('error', reject);
    host.on('open', () => host.send(JSON.stringify({type:'create',v:3,name:'Weather spectator host',delta:0})));
    host.on('message', bytes => {
      const frame = JSON.parse(bytes);
      if (frame.type === 'error') return reject(Error(frame.message));
      if (frame.type === 'welcome') {
        room = frame.roomId;
        host.send(JSON.stringify({type:'host',mapId:map,config:{mode:'deathmatch',botCount:0,timeLimit:300,fragLimit:100}}));
      }
      if (frame.type === 'lobby' && frame.config && !configured) { configured = true; host.send(JSON.stringify({type:'start'})); }
      if (frame.type === 'start') {
        observations.push({direction:'host-received',frame});
        if (++started === 1) host.send(JSON.stringify({type:'start'}));
        else resolve();
      }
    });
  });
}
const binary = process.env.GODOT_BIN || '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const args = ['-a', binary, '--path', 'godot', '--audio-driver', 'Dummy', '--script', 'res://tests/world_weather/journey.gd', '--', `--endpoint=${endpoint}`, `--map=${map}`, `--mode=${kind === 'campaign' ? 'campaign' : kind === 'source' ? 'ctf' : 'deathmatch'}`, '--bots=0', '--mute', `--weather-journey=${kind}`, `--weather-output=${output}`];
if (room) args.push(`--join-room=${room}`);
const child = spawn('xvfb-run', args, {detached:true, env: {...process.env, LP_NUM_THREADS: '1', COCS_SETTINGS_PATH: output + '/settings.json'}, stdio: 'inherit'});
// The owned Xvfb wrapper and native child share this private process group.
// Reap both on deadline instead of leaving an engine behind after killing only
// the wrapper. This harness runs on Linux; Windows acceptance uses its own runner.
const timeout = setTimeout(() => {
  try { process.kill(-child.pid, 'SIGKILL'); }
  catch (error) { if (error.code !== 'ESRCH') throw error; }
}, 115000);
try {
  process.exitCode = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', code => resolve(code ?? 1)); });
} finally {
  clearTimeout(timeout);
  writeFileSync(output + '/authority-boundaries.json', JSON.stringify({endpoint, kind, map, observations}, null, 2));
  if(kind==='campaign')writeFileSync(output+'/campaign-input-diagnostic.json',JSON.stringify(inputDiagnostic.result(),null,2));
  for (const socket of authority.wss?.clients ?? []) socket.terminate();
  authority.server.closeAllConnections();
  await authority.close();
}

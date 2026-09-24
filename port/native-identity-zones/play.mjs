// Standalone owned convenience entry until the lead wires the common launcher.
//
//   GODOT_BIN=<pinned 4.5.2> node port/native-identity-zones/play.mjs [--bots=0..24]
//     [--round-seconds=60..900] [--score-limit=1..900]
//
// Starts the owned loopback Domination authority and the identity zone scene on
// the caller's display. Close the window (or Ctrl+C) to stop both.
import {spawn, execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, readFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {createIdentityZoneAuthority} from './authority.mjs';
import {IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE} from './catalog.mjs';

const values = {bots:'2', 'round-seconds':'180', 'score-limit':'900'};
const seen = new Set();
for (const arg of process.argv.slice(2)) {
  const match = /^--(bots|round-seconds|score-limit)=(.+)$/.exec(arg);
  if (!match || seen.has(match[1])) throw Error('Use --bots=0..24 --round-seconds=60..900 --score-limit=1..900, once each');
  seen.add(match[1]); values[match[1]] = match[2];
}
for (const [key, min, max] of [['bots', 0, 24], ['round-seconds', 60, 900], ['score-limit', 1, 900]]) {
  if (!/^\d+$/.test(values[key]) || +values[key] < min || +values[key] > max) throw Error(`Invalid ${key}`);
}
const lock = JSON.parse(readFileSync('port/contracts/source-lock.json', 'utf8'));
const binary = process.env.GODOT_BIN;
if (!binary || execFileSync(binary, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) {
  throw Error('Pinned GODOT_BIN required');
}
const temp = mkdtempSync('/tmp/opencode/identity-zone-play-');
const env = {...process.env};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) {
  env[key] = resolve(temp, key); mkdirSync(env[key]);
}
const authority = await createIdentityZoneAuthority({port:0, host:'127.0.0.1', mapId:IDENTITY_ZONE_MAP_ID,
  mode:IDENTITY_ZONE_MODE, bots:Number(values.bots), roundSeconds:Number(values['round-seconds']),
  fragLimit:Number(values['score-limit'])});
let child, done;
const stop = () => child?.kill('SIGTERM');
process.on('SIGINT', stop); process.on('SIGTERM', stop);
try {
  console.log(`Vermilion Fold Domination: ${authority.endpoint}; close the window to stop the owned authority.`);
  child = spawn(binary, ['--path', 'godot', 'res://native_arenas/identity_zone_demo.tscn', '--',
    `--endpoint=${authority.endpoint}`, `--map=${IDENTITY_ZONE_MAP_ID}`, `--mode=${IDENTITY_ZONE_MODE}`,
    `--bots=${values.bots}`, `--round-seconds=${values['round-seconds']}`,
    `--score-limit=${values['score-limit']}`, '--autostart'], {env, stdio:'inherit'});
  done = new Promise((resolveExit, reject) => { child.once('error', reject); child.once('close', code => resolveExit(code ?? 1)); });
  process.exitCode = await done;
} finally {
  if (child && child.exitCode === null && child.signalCode === null) {
    stop();
    const timer = setTimeout(() => child.kill('SIGKILL'), 2000);
    await done; clearTimeout(timer);
  }
  for (const socket of authority.wss.clients) socket.terminate();
  await authority.close();
  rmSync(temp, {recursive:true, force:true});
  process.off('SIGINT', stop); process.off('SIGTERM', stop);
}

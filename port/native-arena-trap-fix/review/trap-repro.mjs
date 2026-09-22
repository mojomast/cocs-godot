// Review-lane trap reproduction: find any live actor that spends a long window
// inside blocking volume (obstructed at r=0.06) and record its bot state.
import {appendFileSync, mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {obstructed, floorAt} from '../../../game/core.mjs';
import {createNativeMatch} from '../../native-arenas/match.mjs';
import {seededRandom} from '../../native-arena-review/lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const mapId = process.argv.find(a => a.startsWith('--map='))?.split('=')[1] ?? 'prism-foundry';
const seed = Number(process.argv.find(a => a.startsWith('--seed='))?.split('=')[1] ?? 20260922);
const seconds = Number(process.argv.find(a => a.startsWith('--seconds='))?.split('=')[1] ?? 180);
mkdirSync(`${ROOT}/port/native-arena-trap-fix/logs`, {recursive: true});
const out = `${ROOT}/port/native-arena-trap-fix/logs/trap-${mapId}-${seed}.jsonl`;
const match = createNativeMatch({mapId, config: {mode: 'deathmatch', botCount: 7, timeLimit: seconds, fragLimit: 50}, random: seededRandom(seed)});
const arena = match.arena;
const windows = new Map();
const traps = [];
for (let tick = 0; tick < seconds * 60 && !match.over; tick++) {
  match.step(1 / 60, {inputs: {0: {}}});
  if (tick % 30) continue;
  for (const a of match.actors) {
    if (a.health <= 0) { windows.delete(a.id); continue; }
    const inside = obstructed(a.x, a.y, a.z, 0.06, arena);
    const w = windows.get(a.id);
    if (!inside) {
      if (w && w.last - w.first > 2 && (tick - w.last) < 120) {
        traps.push({actor: a.id, first: +(w.first / 60).toFixed(1), last: +(w.last / 60).toFixed(1),
          duration: +((w.last - w.first) / 60).toFixed(2), center: w.center, maxRadius: +w.maxRadius.toFixed(2),
          maxHeight: +(w.maxHeight - w.minFloor).toFixed(2), minFloor: +w.minFloor.toFixed(2), samples: w.samples,
          botState: w.botState, routeLen: w.routeLen, stuck: w.stuck});
      }
      windows.delete(a.id);
      continue;
    }
    const sample = {t: +(tick / 60).toFixed(2), actor: a.id, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3),
      grounded: a.grounded === true, botState: a.bot?.state ?? null, routeLen: a.bot?.route?.length ?? null, stuck: a.bot?.stuck ?? null,
      wallContact: obstructed(a.x, a.y, a.z, 0.42, arena)};
    appendFileSync(out, `${JSON.stringify(sample)}\n`);
    if (!w) {
      const floor = floorAt(a.x, a.z, arena) ?? a.y;
      windows.set(a.id, {first: tick, last: tick, center: [a.x, a.z], minFloor: floor, maxHeight: a.y, maxRadius: 0, samples: 1,
        botState: sample.botState, routeLen: sample.routeLen, stuck: sample.stuck});
    } else {
      w.last = tick; w.samples++;
      w.maxRadius = Math.max(w.maxRadius, Math.hypot(a.x - w.center[0], a.z - w.center[1]));
      w.maxHeight = Math.max(w.maxHeight, a.y);
      w.minFloor = Math.min(w.minFloor, floorAt(a.x, a.z, arena) ?? w.minFloor);
      w.botState = sample.botState; w.routeLen = sample.routeLen; w.stuck = sample.stuck;
    }
  }
}
console.log(JSON.stringify({mapId, seed, simSeconds: match.time, over: match.over, reason: match.overReason,
  frags: match.actors.map(a => a.frags), traps: traps.sort((a, b) => b.duration - a.duration).slice(0, 12)}, null, 1));

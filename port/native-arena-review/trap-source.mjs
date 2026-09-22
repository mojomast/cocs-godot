// Review-lane comparison: does the same live-actor obstruction trap occur on
// the locked source nine-map arenas (no native asset involved)?
// Usage: node port/native-arena-review/trap-source.mjs --map=meridian-exchange --seconds=120
import {appendFileSync, mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {Match, obstructed, floorAt} from '../../game/core.mjs';
import {seededRandom} from './lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = Object.fromEntries(process.argv.slice(2).filter(a => a.startsWith('--')).map(a => a.split('=')));
const mapId = args.map ?? 'meridian-exchange';
const seed = Number(args.seed ?? 20260922);
const seconds = Number(args.seconds ?? 120);
mkdirSync(`${ROOT}/port/native-arena-review/logs`, {recursive: true});
const out = `${ROOT}/port/native-arena-review/logs/trap-source-${mapId}-${seed}.jsonl`;
const match = new Match('chatgpt', 'openclaw', seededRandom(seed), mapId, {mode: 'deathmatch', botCount: 7, timeLimit: seconds, fragLimit: 50});
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
      if (w && w.last - w.first > 2 * 60) traps.push({actor: a.id, first: +(w.first / 60).toFixed(1), last: +(w.last / 60).toFixed(1),
        duration: +((w.last - w.first) / 60).toFixed(2), center: w.center.map(v => +v.toFixed(2)), maxRadius: +w.maxRadius.toFixed(2), botState: w.botState, stuck: w.stuck});
      windows.delete(a.id);
      continue;
    }
    appendFileSync(out, `${JSON.stringify({t: +(tick / 60).toFixed(2), actor: a.id, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3),
      grounded: a.grounded === true, botState: a.bot?.state ?? null, stuck: a.bot?.stuck ?? null, floor: floorAt(a.x, a.z, arena)})}\n`);
    if (!w) windows.set(a.id, {first: tick, last: tick, center: [a.x, a.z], maxRadius: 0, botState: a.bot?.state ?? null, stuck: a.bot?.stuck ?? null});
    else { w.last = tick; w.maxRadius = Math.max(w.maxRadius, Math.hypot(a.x - w.center[0], a.z - w.center[1])); w.botState = a.bot?.state ?? null; w.stuck = a.bot?.stuck ?? null; }
  }
}
console.log(JSON.stringify({mapId, seed, seconds, over: match.over, reason: match.overReason, frags: match.actors.map(a => a.frags),
  trapWindows: traps.sort((a, b) => b.duration - a.duration).slice(0, 8), log: out}, null, 1));

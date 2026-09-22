// Post-fix trap audit (trap-fix lane).
//
// Drives real source rounds through createNativeMatch (1 local human seat + a
// configurable number of source bots, default 7) and flags live actors that
// cannot move. Sampling is 4x per second. Three detectors:
//   - lock:     a continuous immobile window (maxRadius < 0.25 m) longer than
//               1.5 s in which the actor's own centre is refused by source
//               movement at the full 0.42 m contact radius at every sample.
//               That is the delivered defect class: the actor is inside a
//               movement band, so no axis step can leave it (a live prism bot
//               stayed there for 71 s).
//   - inside06: the review's narrower detector - the actor centre sits inside a
//               movement band at r = 0.06 for > 1.5 s (regardless of radius).
//   - hold:     immobile > 1.5 s while not self-blocked; a bot holding an angle
//               or pressed against a wall is not a geometry trap, so this is
//               reported for context only.
// A lock window longer than 1.5 s is the acceptance failure for the fix.
import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {floorAt, obstructed} from '../../game/core.mjs';
import {createNativeMatch} from '../native-arenas/match.mjs';
import {EventCursor} from '../native-arenas/event-cursor.mjs';
import {seededRandom} from '../native-arena-review/lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = Object.fromEntries(process.argv.slice(2).filter(a => a.startsWith('--'))
  .map(a => a.replace(/^--/, '').split('=')).map(([key, ...rest]) => [key, rest.join('=')]));
const mapId = args.map ?? 'prism-foundry';
const seed = Number(args.seed ?? 20260922);
const seconds = Number(args.seconds ?? 180);
const bots = Number(args.bots ?? 7);
const outDir = args.out ? resolve(args.out) : `${ROOT}/port/native-arena-trap-fix/logs`;
mkdirSync(outDir, {recursive: true});

const config = {mode: 'deathmatch', botCount: bots, timeLimit: seconds, fragLimit: 50};
const match = createNativeMatch({mapId, config, random: seededRandom(seed)});
const arena = match.arena;
const cursor = new EventCursor();
cursor.take(match);
const totals = {kills: 0, deaths: 0, respawns: 0, falls: 0, pickups: 0, humanKills: 0, humanDeaths: 0};
const SAMPLE = 0.25, LIMIT = 1.5, TOLERANCE = 0.25;
const windows = new Map();
const closed = {lock: [], slide: [], inside: [], hold: []};

function closeWindow(id, tick) {
  const w = windows.get(id);
  if (!w) return;
  windows.delete(id);
  const duration = (tick - w.start) / 60;
  if (duration <= LIMIT || w.maxRadius >= TOLERANCE) return;
  const record = {actor: id, first: +(w.start / 60).toFixed(2), last: +(tick / 60).toFixed(2), duration: +duration.toFixed(2),
    center: w.center.map(v => +v.toFixed(2)), maxRadius: +w.maxRadius.toFixed(3), trappedAll: w.trappedAll, inside06: w.inside06, groundedBlocked: w.groundedBlocked,
    botStates: [...w.states], maxStuck: +w.stuck.toFixed(2)};
  if (w.trappedAll && w.groundedBlocked) closed.lock.push(record);
  else if (w.trappedAll) closed.slide.push(record);
  else if (w.inside06) closed.inside.push(record);
  else closed.hold.push(record);
}

let tick = 0;
for (; tick < Math.ceil(seconds * 60) && !match.over; tick++) {
  match.step(1 / 60, {inputs: {0: {}}});
  for (const event of cursor.take(match)) {
    if (event.type === 'death') {
      totals.deaths++;
      if (event.actor === 0) totals.humanDeaths++;
      if (event.killer !== null && event.killer !== undefined && event.killer !== event.actor) {
        totals.kills++;
        if (event.killer === 0) totals.humanKills++;
      }
    } else if (event.type === 'spawn') totals.respawns++;
    else if (event.type === 'fall') totals.falls++;
    else if (event.type === 'pickup') totals.pickups++;
  }
  if (tick % Math.round(SAMPLE * 60)) continue;
  for (const actor of match.actors) {
    if (actor.health <= 0 || actor.dead) { closeWindow(actor.id, tick); continue; }
    const selfBlocked = obstructed(actor.x, actor.y, actor.z, 0.42, arena);
    const centerInside = obstructed(actor.x, actor.y, actor.z, 0.06, arena);
    // A landed trap: the actor is refused by movement at its own position while
    // standing on a surface. An actor falling past a wall face is horizontally
    // immobile too but keeps falling (vertical motion is never blocked), so it
    // is recorded separately instead of counting as a landed lock.
    const standing = actor.grounded === true || actor.y - (floorAt(actor.x, actor.z, arena) ?? -Infinity) < 0.35;
    let w = windows.get(actor.id);
    if (!w) {
      w = {start: tick, center: [actor.x, actor.z], maxRadius: 0, trappedAll: true, inside06: true, groundedBlocked: false, states: new Set(), stuck: 0};
      windows.set(actor.id, w);
    }
    w.maxRadius = Math.max(w.maxRadius, Math.hypot(actor.x - w.center[0], actor.z - w.center[1]));
    w.trappedAll = w.trappedAll && selfBlocked;
    w.inside06 = w.inside06 && centerInside;
    w.groundedBlocked = w.groundedBlocked || (standing && selfBlocked);
    w.states.add(actor.bot?.state ?? '-');
    w.stuck = Math.max(w.stuck, actor.bot?.stuck ?? 0);
    if (w.maxRadius >= TOLERANCE) closeWindow(actor.id, tick);
  }
}
for (const id of [...windows.keys()]) closeWindow(id, tick);
const results = {over: match.over, reason: match.overReason, time: +match.time.toFixed(2),
  actors: match.actors.map(a => ({id: a.id, frags: a.frags, deaths: a.deaths}))};
const restart = (() => {
  const fresh = createNativeMatch({mapId, config, random: seededRandom(seed + 1)});
  const freshCursor = new EventCursor();
  freshCursor.take(fresh);
  let ticks = 0;
  const restartEvents = {kills: 0, deaths: 0, respawns: 0, pickups: 0};
  for (; ticks < 30 * 60 && !fresh.over; ticks++) {
    fresh.step(1 / 60, {inputs: {0: {}}});
    for (const event of freshCursor.take(fresh)) {
      if (event.type === 'death') {
        restartEvents.deaths++;
        if (event.killer !== null && event.killer !== undefined && event.killer !== event.actor) restartEvents.kills++;
      } else if (event.type === 'spawn') restartEvents.respawns++;
      else if (event.type === 'pickup') restartEvents.pickups++;
    }
  }
  return {time: +fresh.time.toFixed(2), over: fresh.over, frags: fresh.actors.map(a => a.frags), simulatedTicks: ticks, events: restartEvents};
})();
const report = {mapId, seed, seconds, bots, results, kills: totals.kills, deaths: totals.deaths, respawns: totals.respawns,
  falls: totals.falls, pickups: totals.pickups, humanKills: totals.humanKills, humanDeaths: totals.humanDeaths,
  restart,
  detectors: {limitSeconds: LIMIT, tolerance: TOLERANCE,
    lock: closed.lock.sort((a, b) => b.duration - a.duration).slice(0, 12),
    inside06: closed.inside.sort((a, b) => b.duration - a.duration).slice(0, 12),
    fallSlide: closed.slide.sort((a, b) => b.duration - a.duration).slice(0, 8), hold: closed.hold.length}};
const outPath = `${outDir}/trap-audit-${mapId}-${seed}.json`;
writeFileSync(outPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({mapId, seed, out: outPath, over: results.over, simTime: results.time, kills: totals.kills,
  deaths: totals.deaths, respawns: totals.respawns, falls: totals.falls, pickups: totals.pickups,
  humanKills: totals.humanKills, humanDeaths: totals.humanDeaths, restartTime: restart.time, restartFrags: restart.frags,
  restartEvents: restart.events,
  lockWindows: closed.lock.length, longestLock: closed.lock[0]?.duration ?? 0, fallSlides: closed.slide.length,
  longestFallSlide: closed.slide[0]?.duration ?? 0, inside06Windows: closed.inside.length,
  holds: closed.hold.length}));
if (closed.lock.some(w => w.duration > LIMIT)) { console.error('TRAP_AUDIT_FAIL', JSON.stringify(closed.lock.slice(0, 4))); process.exitCode = 1; }

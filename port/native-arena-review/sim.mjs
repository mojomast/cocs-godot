// Independent source-Match simulation review for the three native DM arenas.
//
// Review lane only: this file reads delivered modules and writes logs into
// port/native-arena-review/logs/. It never writes production paths.
//
// Usage:
//   node port/native-arena-review/sim.mjs --map=prism-foundry --bots=7 \
//     --round-seconds=180 --frag-limit=50 --seed=1234
//
// Evidence produced (my own, not the delivered gate logs):
//   - JSONL log: one summary line per simulated second plus every event of
//     interest (spawn/death/frag/fall/illegal-position).
//   - JSON report: legality counters, spawn-attribution, movement stats,
//     kill/death/respawn counts, results, restart check.
import {mkdirSync, writeFileSync, appendFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {Match, floorAt, obstructed, rayWorld} from '../../game/core.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {readNativeArena} from '../native-arenas/schema.mjs';
import {createNativeMatch} from '../native-arenas/match.mjs';
import {EventCursor} from '../native-arenas/event-cursor.mjs';
import {seededRandom} from './lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

function args(argv) {
  const out = {};
  for (const arg of argv) {
    const m = /^--([a-z-]+)=(.*)$/.exec(arg);
    if (m) out[m[1]] = m[2];
  }
  return out;
}
const opts = args(process.argv.slice(2));
const mapId = opts.map ?? 'prism-foundry';
const bots = Number(opts.bots ?? 7);
const roundSeconds = Number(opts['round-seconds'] ?? 180);
const fragLimit = Number(opts['frag-limit'] ?? 50);
const seed = Number(opts.seed ?? 20260922);
const wallCapSeconds = Number(opts['wall-cap'] ?? 900);
const logDir = `${ROOT}/port/native-arena-review/logs`;

mkdirSync(logDir, {recursive: true});
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const jsonlPath = `${logDir}/sim-${mapId}-${stamp}.jsonl`;
const reportPath = `${logDir}/sim-${mapId}-${stamp}.json`;
const log = line => appendFileSync(jsonlPath, `${JSON.stringify(line)}\n`);

const data = readNativeArena(mapId);
const random = seededRandom(seed);
const config = {mode: 'deathmatch', botCount: bots, difficulty: 'normal',
  timeLimit: roundSeconds, fragLimit};

const constructStart = Date.now();
const match = createNativeMatch({mapId, config, random});
const constructMs = Date.now() - constructStart;
const arena = match.arena;
const bounds = arena.bounds;

const issues = [];
const issue = (kind, detail) => { issues.push({kind, t: Number(match.time.toFixed(3)), ...detail}); log({kind, ...detail}); };

const cursor = new EventCursor();
const events = [];
const initialEvents = cursor.take(match);
events.push(...initialEvents);

const spawnFeet = data.spawnPoints.map(p => ({x: p.x, y: p.y, z: p.z}));
const spawnAttribution = new Map(spawnFeet.map((p, i) => [i, 0]));
const spawnSamples = [];
const deathPayloads = [];
const damageByType = new Map();

// Independent legality gate applied to the live actor state every tick.
//
// Severity split, so ordinary wall-hugging never masquerades as a geometry
// defect: `solid-overlap` (obstructed even at r=0.06) means the actor centre is
// inside a blocking volume; `wall-contact` (obstructed only at full source
// radius) is normal sliding contact and is counted separately.
const legalityCounters = {solidOverlap: 0, wallContact: 0, noFloorAirborne: 0, noFloorGrounded: 0, voidGrounded: 0, voidAirborne: 0};
function legality(a, phase) {
  if (!Number.isFinite(a.x) || !Number.isFinite(a.y) || !Number.isFinite(a.z) ||
      !Number.isFinite(a.vx) || !Number.isFinite(a.vz)) {
    issue('non-finite-position', {phase, actor: a.id, x: a.x, y: a.y, z: a.z});
    return;
  }
  if (a.x < bounds.minX - 1 || a.x > bounds.maxX + 1 || a.z < bounds.minZ - 1 || a.z > bounds.maxZ + 1) {
    issue('out-of-bounds', {phase, actor: a.id, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3)});
  }
  const floor = floorAt(a.x, a.z, arena);
  const grounded = a.grounded === true;
  if (floor === null) {
    if (grounded) { legalityCounters.noFloorGrounded++; issue('grounded-without-support', {phase, actor: a.id, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3)}); }
    else legalityCounters.noFloorAirborne++;
  } else if (a.y < floor - 0.75) {
    issue('sunk-below-support', {phase, actor: a.id, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3), floor: +floor.toFixed(3)});
  }
  if (a.y <= arena.voidY + 0.4) {
    if (grounded) { legalityCounters.voidGrounded++; issue('grounded-in-void', {phase, actor: a.id, y: +a.y.toFixed(3), voidY: arena.voidY}); }
    else legalityCounters.voidAirborne++;
  }
  if (a.y > arena.ceilingY) issue('above-ceiling', {phase, actor: a.id, y: +a.y.toFixed(3)});
  if (obstructed(a.x, a.y, a.z, 0.06, arena)) {
    legalityCounters.solidOverlap++;
    issue('solid-overlap', {phase, actor: a.id, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3), grounded});
  } else if (obstructed(a.x, a.y, a.z, 0.42, arena)) {
    legalityCounters.wallContact++;
  }
}

// Review-owned human policy: ordinary player controls only, deterministic.
// The human charges the nearest enemy, strafes, fires, and deliberately
// exposes itself so the round includes real human deaths and respawns.
function humanControls() {
  const a = match.actors[0];
  if (!a || a.health <= 0) return {};
  const enemies = match.actors.filter(b => b.id !== a.id && b.health > 0);
  if (!enemies.length) return {x: 0, z: 0};
  let target = null, best = Infinity;
  for (const b of enemies) {
    const d = Math.hypot(b.x - a.x, b.z - a.z);
    const visible = match.visible({x: a.x, y: a.y + a.eyeHeight, z: a.z}, {x: b.x, y: b.y + b.eyeHeight * 0.85, z: b.z});
    const score = d - (visible ? 8 : 0);
    if (score < best) { best = score; target = b; }
  }
  const dx = target.x - a.x, dz = target.z - a.z;
  const dy = target.y + target.eyeHeight * 0.8 - (a.y + a.eyeHeight);
  const dist = Math.hypot(dx, dz);
  const yaw = Math.atan2(-dx, -dz) - (a.punchYaw || 0);
  const pitch = Math.atan2(dy, Math.max(dist, 0.001)) - (a.punchPitch || 0);
  // Approach while distant, strafe once in range; periodic hops.
  const forward = dist > 9 ? 1 : 0.25;
  const strafe = Math.sin(match.time * 1.7) > 0 ? 1 : -1;
  const raw = {x: forward, z: strafe * (dist < 14 ? 0.85 : 0.15), yaw, pitch,
    fire: true, jump: Math.sin(match.time * 0.9) > 0.97, sprint: dist > 9,
    reload: a.ammo[a.weapon] === 0, seq: Math.floor(match.time * 60) + 1};
  return parseInputEnvelope(raw);
}

const totals = {
  ticks: 0, kills: 0, deaths: 0, respawns: 0, falls: 0, shots: 0, pickups: 0,
  humanDamageDealt: 0, humanDamageTaken: 0, humanDeaths: 0, humanKills: 0,
  illegalTicks: 0, blockedVolumeTicks: 0,
};
const botMove = new Map(match.actors.filter(a => a.id !== 0).map(a => [a.id, {origin: {x: a.x, z: a.z}, max: 0}]));
const humanMove = {origin: {x: match.actors[0].x, z: match.actors[0].z}, max: 0};
const stuckWindows = new Map();
const perSecond = [];

const dt = 1 / 60;
const wallDeadline = Date.now() + wallCapSeconds * 1000;
const maxTicks = Math.ceil((roundSeconds + 5) * 60);
let lastSecond = -1;

function validateSpawn(a, why) {
  const floor = floorAt(a.x, a.z, arena);
  let nearest = -1, nearestDist = Infinity;
  spawnFeet.forEach((p, i) => {
    const d = Math.hypot(p.x - a.x, p.z - a.z);
    if (d < nearestDist) { nearestDist = d; nearest = i; }
  });
  if (nearest >= 0 && nearestDist < 0.05) spawnAttribution.set(nearest, spawnAttribution.get(nearest) + 1);
  spawnSamples.push({actor: a.id, why, x: +a.x.toFixed(3), y: +a.y.toFixed(3), z: +a.z.toFixed(3),
    nearestAuthored: nearest, nearestAuthoredDist: +nearestDist.toFixed(3),
    floor: floor === null ? null : +floor.toFixed(3),
    obstructed: obstructed(a.x, a.y, a.z, 0.42, arena)});
  if (floor === null || obstructed(a.x, a.y, a.z, 0.42, arena)) {
    issue('illegal-spawn', {actor: a.id, why, x: a.x, y: a.y, z: a.z, floor});
  }
}

for (const e of initialEvents) if (e.type === 'spawn') validateSpawn(match.actors.find(a => a.id === e.actor), 'initial');

while (!match.over && totals.ticks < maxTicks) {
  const t0 = Date.now();
  match.step(dt, {inputs: {0: humanControls()}});
  totals.ticks++;
  const tickMs = Date.now() - t0;
  const tick = totals.ticks;
  const newEvents = cursor.take(match);
  for (const e of newEvents) {
    events.push(e);
    switch (e.type) {
      case 'spawn': {
        totals.respawns++;
        const a = match.actors.find(x => x.id === e.actor);
        if (tick > 1) validateSpawn(a, 'respawn');
        break;
      }
      case 'death': {
        totals.deaths++;
        if (e.actor === 0) totals.humanDeaths++;
        if (e.killer === 0 && e.killer !== e.actor) totals.humanKills++;
        deathPayloads.push({...e});
        break;
      }
      case 'kill': case 'frag': totals.kills++; break;
      case 'damage': {
        if (e.amount > 0) {
          const key = e.source === 0 ? 'human-dealt' : e.actor === 0 ? 'human-taken' : 'bot-bot';
          damageByType.set(key, (damageByType.get(key) || 0) + e.amount);
          if (e.source === 0) totals.humanDamageDealt += e.amount;
          if (e.actor === 0) totals.humanDamageTaken += e.amount;
        }
        break;
      }
      case 'fall': totals.falls++; break;
      case 'pickup': totals.pickups++; break;
      default: break;
    }
  }
  for (const a of match.actors) {
    if (a.health > 0) legality(a, 'live');
    if (a.id !== 0 && a.health > 0) {
      const m = botMove.get(a.id);
      m.max = Math.max(m.max, Math.hypot(a.x - m.origin.x, a.z - m.origin.z));
    }
  }
  const human = match.actors[0];
  if (human.health > 0) humanMove.max = Math.max(humanMove.max, Math.hypot(human.x - humanMove.origin.x, human.z - humanMove.origin.z));
  totals.shots = match.stats.shots;
  totals.kills = Math.max(totals.kills, match.stats.kills);
  totals.pickups = Math.max(totals.pickups, match.stats.pickups);
  totals.falls = Math.max(totals.falls, match.stats.falls);
  if (tick % 300 === 0) { // every 5 simulated seconds: stuck detector
    for (const a of match.actors) {
      if (a.health <= 0) { stuckWindows.delete(a.id); continue; }
      const w = stuckWindows.get(a.id) ?? {x: a.x, z: a.z, at: tick};
      if (Math.hypot(a.x - w.x, a.z - w.z) > 1.25) stuckWindows.set(a.id, {x: a.x, z: a.z, at: tick});
      else if (tick - w.at >= 600) { issue('stuck-actor', {actor: a.id, x: +a.x.toFixed(2), y: +a.y.toFixed(2), z: +a.z.toFixed(2), grounded: a.grounded === true}); stuckWindows.set(a.id, {x: a.x, z: a.z, at: tick}); }
    }
  }
  if (tick % 60 === 0) {
    const second = tick / 60;
    if (second !== lastSecond) {
      lastSecond = second;
      perSecond.push({t: second, alive: match.actors.filter(a => a.health > 0).length,
        frags: match.actors.map(a => a.frags), deaths: match.actors.map(a => a.deaths),
        shots: match.stats.shots, pickups: match.stats.pickups, falls: match.stats.falls,
        respawns: match.stats.respawns, tickMs, queue: newEvents.length});
    }
  }
  if (Date.now() > wallDeadline) { issue('wall-clock-cap', {ticks: totals.ticks}); break; }
  if (tickMs > 250) issue('slow-tick', {tickMs});
}

const snapshot = match.snapshot();
const finals = [...cursor.take(match)];
for (const e of finals) events.push(e);

// Restart check: a fresh match on the same map with the same seed must start
// from zeroed source score/time and must remain legal for a short live window.
const restartStart = Date.now();
const restarted = createNativeMatch({mapId, config, random: seededRandom(seed)});
const restartConstructMs = Date.now() - restartStart;
const restartInitial = new EventCursor().take(restarted);
let restartIllegal = 0;
let restartTick = 0;
for (; restartTick < 30 * 60 && !restarted.over; restartTick++) {
  restarted.step(dt, {inputs: {0: {}}});
  for (const a of restarted.actors) {
    const floor = floorAt(a.x, a.z, restarted.arena);
    if (a.health > 0 && (floor === null && a.grounded === true || obstructed(a.x, a.y, a.z, 0.06, restarted.arena))) restartIllegal++;
  }
}

const report = {
  review: 'native-arena-review/sim.mjs',
  mapId, geometryHash: data.geometryHash, arenaHashRecomputed: null,
  config, seed, constructMs,
  nav: {nodes: match.nav.length, edges: match.edges.reduce((n, e) => n + e.length, 0)},
  initialEventIds: initialEvents.map(e => e.id),
  initialSpawnCount: initialEvents.filter(e => e.type === 'spawn').length,
  round: {
    simulatedSeconds: +match.time.toFixed(3),
    wallSeconds: +((totals.ticks * dt)).toFixed(3),
    over: match.over, overReason: match.overReason ?? null,
    leaders: snapshot.leaders, winner: snapshot.winner ?? null,
    frags: match.actors.map(a => ({id: a.id, name: a.name, bot: a.bot === true, frags: a.frags, deaths: a.deaths, shots: a.shots, pickups: a.pickups ?? 0})),
    stats: {...match.stats, ...totals},
  },
  legality: {
    issueCount: issues.length,
    byKind: issues.reduce((acc, i) => { acc[i.kind] = (acc[i.kind] || 0) + 1; return acc; }, {}),
    counters: legalityCounters,
    uniquePositions: [...new Map(issues.filter(i => i.x !== undefined).map(i => [`${i.actor}:${i.x}:${i.y}:${i.z}`, i])).values()].slice(0, 40),
  },
  spawns: {authored: spawnFeet, attribution: Object.fromEntries([...spawnAttribution].map(([i, n]) => [i, n])),
    samples: spawnSamples.length, illegalDeduped: [...new Map(spawnSamples.filter(s => s.floor === null || s.obstructed).map(s => [`${s.actor}:${s.x}:${s.z}`, s])).values()]},
  movement: {humanMaxDisplacement: +humanMove.max.toFixed(2),
    bots: Object.fromEntries([...botMove].map(([id, m]) => [id, +m.max.toFixed(2)]))},
  damageByType: Object.fromEntries(damageByType),
  deaths: deathPayloads.slice(0, 40),
  perSecond,
  restart: {constructorMs: restartConstructMs, time: restarted.time, frags: restarted.actors.map(a => a.frags),
    deaths: restarted.actors.map(a => a.deaths), firstEvents: restartInitial.map(e => ({id: e.id, type: e.type, actor: e.actor})),
    simulatedTicks: restartTick, illegalActorTicks: restartIllegal},
  claimsChecked: {
    humanKills: totals.humanKills, humanDeaths: totals.humanDeaths, humanDamageDealt: +totals.humanDamageDealt.toFixed(1),
    humanDamageTaken: +totals.humanDamageTaken.toFixed(1), botShots: match.actors.filter(a => a.id !== 0).reduce((n, a) => n + a.shots, 0),
    botMaxDisplacement: Math.max(...[...botMove.values()].map(m => m.max)),
  },
};
writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({log: jsonlPath, report: reportPath, mapId, over: match.over, reason: match.overReason,
  time: match.time, leaders: snapshot.leaders, issues: report.legality.byKind,
  frags: report.round.frags.map(a => a.frags), deaths: report.deaths.length, kills: match.stats.kills,
  human: report.claimsChecked, restart: report.restart}));

// Grounded spawn-to-zone travel measurement for Vermilion Fold Domination.
//
// Every number comes from a real source Match built through the route's own
// factory (two local seats, zero bots) stepping at 1/60 with ordinary movement
// inputs along a supported source ground route. For each authored team spawn
// point and each of the three authored zones the actor is walked to the spawn,
// brought to a standstill, and timed from the first movement tick until its
// horizontal position enters the zone radius. Both gaits are measured: walk and
// sprint. No teleport, no state write, no clock override.
//
//   node port/native-identity-zones/travel.mjs [--json=<path>]
import {writeFileSync, mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {readNativeArena} from '../native-arenas/schema.mjs';
import {IDENTITY_ZONE_MAP_ID} from './catalog.mjs';
import {createIdentityZoneMatch, identityTeamPool} from './match.mjs';
import {controlsToward, hold, routeBetween, seededRandom} from './fixtures.mjs';

const MAP = IDENTITY_ZONE_MAP_ID;
const GAITS = Object.freeze([{id:'walk', sprint:false}, {id:'sprint', sprint:true}]);
const REST_TICKS = 30;
const ARRIVE = 0.5;

const options = {json:`port/native-identity-zones/evidence/travel-${MAP}.json`};
for (const arg of process.argv.slice(2)) {
  const match = /^--([a-z-]+)=(.*)$/.exec(arg);
  if (match) options[match[1]] = match[2];
}

const data = readNativeArena(MAP);
const arena = data.arena;
const zones = arena.objectiveZones.map((zone, index) => ({id:['alpha','bravo','charlie'][index], x:zone.x, z:zone.z, radius:zone.radius, y:zone.y}));
const pools = {0:identityTeamPool(arena, 0), 1:identityTeamPool(arena, 1)};
const straight = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

function newMatch() {
  // One identical loadout for both seats: travel time must measure the map and
  // the spawns, never a seat-speed difference between the two characters.
  return createIdentityZoneMatch({config:{mode:'domination', botCount:0, timeLimit:900, fragLimit:900},
    humanCount:2, random:seededRandom(97),
    loadouts:{0:{character:'chatgpt', harness:'openclaw'}, 1:{character:'chatgpt', harness:'openclaw'}}});
}

/** Walk `actorId` to `point`; returns the route distance actually walked. */
function walkTo(match, actorId, point, sprint) {
  const actor = match.actors[actorId];
  if (Math.hypot(actor.x - point[0], actor.z - point[1]) <= ARRIVE) return 0;
  const route = routeBetween(arena, [actor.x, actor.z], point);
  let distance = Math.hypot(actor.x - route[0][0], actor.z - route[0][1]);
  for (let index = 0; index < route.length && !match.over; ) {
    const waypoint = route[index];
    if (Math.hypot(actor.x - waypoint[0], actor.z - waypoint[1]) <= 0.6) { index++; continue; }
    const controls = controlsToward(actor, waypoint);
    controls.sprint = sprint === true && !(index === route.length - 1 && waypoint === point);
    match.step(1 / 60, {inputs:{[actorId]:controls}});
  }
  for (let tick = 0; tick < 240 && Math.hypot(actor.x - point[0], actor.z - point[1]) > 0.35 && !match.over; tick++) {
    match.step(1 / 60, {inputs:{[actorId]:controlsToward(actor, point)}});
  }
  for (let index = 1; index < route.length; index++) distance += straight(route[index - 1], route[index]);
  return distance;
}

/** Time the actor from a standstill at `from` until it enters `zone`. */
function timedRun(match, actorId, from, zone, sprint) {
  const actor = match.actors[actorId];
  if (Math.hypot(actor.x - from[0], actor.z - from[1]) > ARRIVE) throw new Error('Timed run did not start at the spawn');
  if (Object.keys(actor.powerups ?? {}).length) throw new Error('Timed run started with a live powerup');
  hold(match, actorId, {x:0, z:0}, REST_TICKS);
  if (Math.hypot(actor.vx, actor.vz) > 0.15) throw new Error('Timed run did not reach a standstill');
  const route = routeBetween(arena, from, [zone.x, zone.z]);
  const started = match.time;
  let distance = 0;
  for (let index = 0; index < route.length && !match.over; ) {
    const inside = Math.hypot(actor.x - zone.x, actor.z - zone.z) <= zone.radius;
    if (inside) break;
    const waypoint = route[index];
    if (Math.hypot(actor.x - waypoint[0], actor.z - waypoint[1]) <= 0.6) { index++; continue; }
    const previous = {x:actor.x, z:actor.z};
    const controls = controlsToward(actor, waypoint);
    controls.sprint = sprint;
    match.step(1 / 60, {inputs:{[actorId]:controls}});
    distance += Math.hypot(actor.x - previous.x, actor.z - previous.z);
  }
  const inside = Math.hypot(actor.x - zone.x, actor.z - zone.z) <= zone.radius;
  return {seconds:match.time - started, ticks:Math.round((match.time - started) * 60), distance,
    entered:inside, x:actor.x, z:actor.z,
    straight:straight(from, [zone.x, zone.z]),
    routeLength:straight(from, route[0]) + route.slice(1).reduce((sum, point, index) => sum + straight(route[index], point), 0)};
}

const results = [];
let freshMatches = 0;
for (const team of [0, 1]) {
  for (const [spawnIndex, spawn] of pools[team].entries()) {
    let match = newMatch(); freshMatches++;
    for (const gait of GAITS) {
      for (const zone of zones) {
        walkTo(match, team, spawn, gait.sprint);
        if (Math.hypot(match.actors[team].x - spawn[0], match.actors[team].z - spawn[1]) > ARRIVE) {
          match = newMatch(); freshMatches++;
          walkTo(match, team, spawn, gait.sprint);
        }
        if (Object.keys(match.actors[team].powerups ?? {}).length) {
          match = newMatch(); freshMatches++;
          walkTo(match, team, spawn, gait.sprint);
        }
        const run = timedRun(match, team, spawn, zone, gait.sprint);
        results.push({team, spawn:spawnIndex, spawnPoint:spawn, zone:zone.id, gait:gait.id, ...run});
      }
    }
  }
}

const summary = [];
for (const zone of zones) {
  for (const gait of GAITS) {
    const west = results.filter(item => item.zone === zone.id && item.gait === gait.id && item.team === 0);
    const east = results.filter(item => item.zone === zone.id && item.gait === gait.id && item.team === 1);
    const times = rows => ({min:Math.min(...rows.map(item => item.seconds)), max:Math.max(...rows.map(item => item.seconds)),
      mean:rows.reduce((sum, item) => sum + item.seconds, 0) / rows.length});
    const wests = times(west), easts = times(east);
    summary.push({zone:zone.id, gait:gait.id, zoneCenter:[zone.x, zone.z], radius:zone.radius,
      westSpawns:west.map(item => ({spawn:item.spawnPoint, seconds:Number(item.seconds.toFixed(3)), ticks:item.ticks,
        routeLength:Number(item.routeLength.toFixed(2))})),
      eastSpawns:east.map(item => ({spawn:item.spawnPoint, seconds:Number(item.seconds.toFixed(3)), ticks:item.ticks,
        routeLength:Number(item.routeLength.toFixed(2))})),
      westMin:Number(wests.min.toFixed(3)), eastMin:Number(easts.min.toFixed(3)),
      fastestDelta:Number(Math.abs(wests.min - easts.min).toFixed(3)),
      asymmetryPercent:Number((100 * Math.abs(wests.min - easts.min) / Math.max(wests.min, easts.min)).toFixed(2))});
  }
}
const report = {gate:'identity-zone-travel', mapId:MAP, mode:'domination',
  method:'real source Match through createIdentityZoneMatch; two local seats; zero bots; '
    + 'supported ground route (port/native-projectile-combat/route.mjs); standstill start; '
    + 'timed until the actor enters the source radius; 1/60 source ticks',
  geometryHash:data.geometryHash, sourceTicks:60, restTicks:REST_TICKS, freshMatches,
  zones, teamSpawns:pools, runs:results.map(item => ({...item, seconds:Number(item.seconds.toFixed(3)),
    distance:Number(item.distance.toFixed(2)), routeLength:Number(item.routeLength.toFixed(2)),
    straight:Number(item.straight.toFixed(2))})),
  summary};
const output = resolve(options.json);
mkdirSync(resolve(output, '..'), {recursive:true});
writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({gate:report.gate, mapId:MAP, freshMatches, runs:results.length,
  evidence:options.json, summary}));

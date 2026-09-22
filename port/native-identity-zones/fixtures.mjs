// Small deterministic helpers for this route's own acceptance:
//   * a seeded RNG (source constructor draws bot harnesses from it)
//   * world-space waypoint steering over a source ground route
//   * a bounded route follower that steps a real Match with real controls
import {groundRouteGeometry, planRoute} from '../native-projectile-combat/route.mjs';

export function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state |= 0; state = state + 0x6D2B79F5 | 0;
    let t = Math.imul(state ^ state >>> 15, 1 | state);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

/** One tick of ordinary controls steering `actor` toward a world waypoint. */
export function controlsToward(actor, waypoint) {
  const dx = waypoint[0] - actor.x, dz = waypoint[1] - actor.z;
  const distance = Math.hypot(dx, dz);
  if (!(distance > 1e-9)) return {x:0, z:0};
  return {x:dx / distance, z:dz / distance, sprint:distance > 5};
}

/** Plan a supported ground route between two XZ points on a validated arena. */
export function routeBetween(arena, from, to) {
  const geometry = groundRouteGeometry(arena);
  if (!geometry.clear([to[0], to[1]])) throw new Error('Route goal is not clear ground');
  return planRoute({...arena, pickups: []}, {x:from[0], z:from[1]}, to, geometry);
}

/** Follow `waypoints` for `actorId` inside a real Match. Other seats idle. */
export function followRoute(match, actorId, waypoints, {maxTicks = 7200, dt = 1 / 60, reach = 0.6} = {}) {
  const actor = match.actors[actorId];
  let index = 0, ticks = 0;
  while (index < waypoints.length && ticks < maxTicks && !match.over) {
    const waypoint = waypoints[index];
    if (Math.hypot(actor.x - waypoint[0], actor.z - waypoint[1]) <= reach) { index++; continue; }
    const controls = controlsToward(actor, waypoint);
    match.step(dt, {inputs:{[actorId]:controls}});
    ticks++;
  }
  return {arrived:index >= waypoints.length, ticks, time:match.time, index};
}

/** Run `ticks` of a single held control set for one seat. */
export function hold(match, actorId, controls, ticks, dt = 1 / 60) {
  for (let tick = 0; tick < ticks && !match.over; tick++) match.step(dt, {inputs:{[actorId]:controls}});
  return match.time;
}

/** Step a match until `predicate` is true. Returns ticks used, or -1 on timeout. */
export function stepUntil(match, predicate, {maxTicks = 7200, dt = 1 / 60, inputs = () => ({})} = {}) {
  for (let tick = 0; tick < maxTicks; tick++) {
    if (predicate(match)) return tick;
    if (match.over) return predicate(match) ? tick : -1;
    match.step(dt, {inputs:inputs(match, tick)});
  }
  return predicate(match) ? maxTicks : -1;
}

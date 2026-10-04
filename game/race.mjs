import {createVehicle, PUMA, respawnVehicle, takeVehicleSeat, stepVehicle} from './vehicles.mjs';
import {clamp} from './math.mjs';
const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const angle = n => Math.atan2(Math.sin(n), Math.cos(n));
export const ITEMS = ['turbo', 'shield', 'oil', 'pulse', 'mine', 'triple', 'bolt', 'star'];

// Cars collide as equal-radius circles. The Puma is 2.1 x 3.6; a 1.7 radius
// wraps the chassis so a pack can rub without feeling like bumper cars.
export const CAR_RADIUS = 1.7;
export const MIN_CAR_SEPARATION = CAR_RADIUS * 2;

// Distance/rank pace help, indexed by normalized rank t (0 = leader, 1 = last).
// The leader runs stock pace (no artificial penalty); the trailer gets a small
// transparent boost so one bad corner is recoverable. The band is deliberately
// small and clamped so skill, items, walls, slipstream and contacts dominate.
export const PACE_LEADER = 1.0;
export const PACE_TRAILER = 1.07;
export function paceMultiplier(t) {
  const rank = clamp(Number.isFinite(t) ? t : 0, 0, 1);
  return clamp(PACE_LEADER + (PACE_TRAILER - PACE_LEADER) * rank, PACE_LEADER, PACE_TRAILER);
}

// Slipstream. A racer tucked behind another inside a narrow cone builds draft
// charge for DRAFT_BUILD seconds, then gets a short speed boost drawn from
// match.random within [DRAFT_BOOST_MIN, DRAFT_BOOST_MAX]. After a boost the cone
// must cool down before it can build again. Works for humans and bots and feeds
// the existing speedScale composition (like item turbo).
export const DRAFT_GAP_MIN = 3;
export const DRAFT_GAP_MAX = 8;
export const DRAFT_LATERAL = 2.4;
export const DRAFT_HEADING_DOT = 0.9;
export const DRAFT_SPEED_FRACTION = 0.7;
export const DRAFT_BUILD = 1;
export const DRAFT_DURATION = 1.2;
export const DRAFT_COOLDOWN = 4;
export const DRAFT_BOOST_MIN = 1.12;
export const DRAFT_BOOST_MAX = 1.18;
const DRAFT_TOP_SPEED = PUMA.speed;

// Contact is asymmetric on purpose: the rammer (the car closing fastest along
// the normal) is capped at the leader's own normal speed with a small penalty,
// so dumping into the car ahead can never transfer speed to it. Equal-speed
// side-by-side scrapes barely change either car.
export const CONTACT_RAM_PENALTY = 0.97;

// Bot corner speed: sample the authored centerline at increasing look-aheads
// and solve targetSpeed = sqrt(maxLatAccel / curvature), so a bot actually
// brakes into a tight corner instead of crawling through it on part throttle.
const AI_MAX_LAT_ACCEL = 20;
const AI_LOOKAHEADS = [8, 14, 20];
const AI_MIN_TARGET_SPEED = 6;
const AI_MISTAKE_CHANCE = 0.01;
const AI_MISTAKE_TIME = 0.4;

// Mystery boxes bend toward the back of the field: the leader mostly draws
// defensive/denial items, the trailer mostly draws catch-up items. Linear blend
// between rank 0 and rank 1, in ITEMS order; deterministic via match.random.
const LEADER_WEIGHTS = {turbo: .06, shield: .30, oil: .22, pulse: .08, mine: .22, triple: .05, bolt: .04, star: .03};
const TRAILER_WEIGHTS = {turbo: .20, shield: .08, oil: .07, pulse: .16, mine: .07, triple: .14, bolt: .15, star: .13};
export function itemWeights(t) {
  const rank = clamp(Number.isFinite(t) ? t : 0, 0, 1);
  const weights = {};
  for (const item of ITEMS) weights[item] = LEADER_WEIGHTS[item] + (TRAILER_WEIGHTS[item] - LEADER_WEIGHTS[item]) * rank;
  return weights;
}
export function rollItem(random, t) {
  const weights = itemWeights(t);
  let roll = clamp(typeof random === 'function' ? random() : 0, 0, 1 - 1e-9);
  for (const item of ITEMS) { roll -= weights[item]; if (roll < 0) return item; }
  return ITEMS[ITEMS.length - 1];
}

// Opponents still racing that are physically ahead on the circuit, nearest
// first. A racer with a finish time is already done and cannot be targeted.
function opponentsAhead(state, racer) {
  return state.racers
    .filter(r => r.actorId !== racer.actorId && r.finishTime === null && r.progress > racer.progress)
    .sort((a, b) => a.progress - b.progress || a.actorId - b.actorId);
}

// A slow only lands when the target has neither star immunity nor a shield.
// The victim sheds two coins (never below zero). Returns whether it landed.
function applySlow(racer, duration) {
  if (!racer || racer.effects.star > 0 || racer.effects.shield > 0) return false;
  racer.effects.slow = Math.max(racer.effects.slow, duration);
  racer.coins = Math.max(0, racer.coins - 2);
  return true;
}

// Normalized rank for every racer in one standings pass: leader 0, last 1.
function rankFractions(state) {
  const order = [...state.racers].sort((a, b) => b.progress - a.progress || a.actorId - b.actorId);
  const ranks = new Map();
  order.forEach((racer, index) => ranks.set(racer.actorId, order.length > 1 ? index / (order.length - 1) : 0));
  return ranks;
}

function gridSeparation(slots) {
  let min = Infinity;
  for (let i = 0; i < slots.length; i++) for (let j = i + 1; j < slots.length; j++)
    min = Math.min(min, distance(slots[i], slots[j]));
  return min;
}

// Push authored grid slots apart only if the map packs them too tight. A slot
// only moves if match.vehicleCollision accepts it, so a nudge can never spawn a
// car inside world geometry. Returns whether any slot actually moved.
function separateGrid(match, slots) {
  const probe = {config: PUMA};
  let nudged = false;
  for (let pass = 0; pass < 6; pass++) {
    let moved = false;
    for (let i = 0; i < slots.length; i++) for (let j = i + 1; j < slots.length; j++) {
      const dx = slots[j].x - slots[i].x, dz = slots[j].z - slots[i].z, d = Math.hypot(dx, dz);
      if (d >= MIN_CAR_SEPARATION) continue;
      const nx = d > 1e-6 ? dx / d : 1, nz = d > 1e-6 ? dz / d : 0;
      const half = (MIN_CAR_SEPARATION - d) / 2 + 1e-3;
      const movedI = acceptSlot(match, probe, slots[i].x - nx * half, slots[i].z - nz * half);
      const movedJ = acceptSlot(match, probe, slots[j].x + nx * half, slots[j].z + nz * half);
      if (movedI) { slots[i].x = movedI.x; slots[i].z = movedI.z; moved = nudged = true; }
      if (movedJ) { slots[j].x = movedJ.x; slots[j].z = movedJ.z; moved = nudged = true; }
    }
    if (!moved) break;
  }
  return nudged;
}

function acceptSlot(match, probe, x, z) {
  if (!Number.isFinite(x) || !Number.isFinite(z) || typeof match.vehicleCollision !== 'function') return null;
  const resolved = match.vehicleCollision({x, y: 0, z}, probe);
  if (resolved && Number.isFinite(resolved.x) && Number.isFinite(resolved.z)) return resolved;
  return null;
}

export function initializeRace(match) {
  const track = match.arena.race;
  const racerCount = Math.min(8, match.actors.length);
  if (!track?.gates?.length || racerCount < 1 || track.grid.length < racerCount) throw new Error('Race requires a circuit and enough grid slots');
  match.pickups = [];
  match.rockets = [];
  match.race = {
    kind: 'race', phase: 'countdown', countdown: 3, laps: match.config.fragLimit, elapsed: 0,
    winnerId: null, gates: track.gates.map(g => ({...g})), centerline: track.centerline,
    boxes: track.itemBoxes.map(b => ({...b, wait: 0})), hazards: [], serial: 0, racers: [],
    coins: (track.coins || []).map(c => ({...c, wait: 0})), boostPads: [...(track.boostPads || [])],
    gridMinSeparation: Infinity, gridNudged: false, contacts: 0, finalLap: false
  };
  // Authored grid slots are used as-is. If a future map ever packs them closer
  // than one car diameter we nudge them apart in-game (never editing the map)
  // and only keep a moved slot when the world accepts it. Never NaN.
  const slots = track.grid.slice(0, racerCount).map(g => ({x: g.x, z: g.z, heading: g.heading}));
  match.race.gridMinSeparation = gridSeparation(slots);
  if (match.race.gridMinSeparation <= MIN_CAR_SEPARATION) {
    match.race.gridNudged = separateGrid(match, slots);
    match.race.gridMinSeparation = gridSeparation(slots);
  }
  // Each racer owns a chassis; overlaps are resolved in stepRace, not ghosted.
  match.vehicles = Array.from({length: racerCount}, (_,id) => {
    const grid = slots[id], vehicle = createVehicle(PUMA);
    vehicle.id = id; vehicle.kind = 'puma';
    vehicle.spawn = {x: grid.x, y: 0, z: grid.z};
    respawnVehicle(vehicle, vehicle.spawn, grid.heading);
    return vehicle;
  });
  match.actors.forEach((actor, index) => {
    if (index >= racerCount) return;
    const vehicle = match.vehicles[index], grid = slots[index];
    takeVehicleSeat(vehicle, actor.id, 'driver');
    actor.yaw = grid.heading - Math.PI;
    actor.active = actor.cooldown = actor.temporaryShield = actor.armor = 0;
    actor.powerups = {}; actor.ammo = actor.ammo.map(() => 0);
    actor.speedMultiplier = 1;
    match.syncVehicleActor(actor, vehicle);
    // Seeded in actor order from match.random so a fixed seed is reproducible.
    match.race.racers.push({actorId: actor.id, vehicleId: vehicle.id, lap: 1, completedLaps: 0,
      nextGate: 0, passed: 0, started: false, progress: -1, finishTime: null, item: null,
      coins: 0, boostPadWait: 0,
      effects: {turbo: 0, shield: 0, slow: 0, star: 0, draft: 0}, resetWait: 0, stuck: 0, checkpointAge: 0,
      anchor: {...grid}, useHeld: false, resetHeld: false,
      draftCharge: 0, draftCooldown: 0, draftBoost: DRAFT_BOOST_MIN,
      botGate: 0, mistake: 0, mistakeLift: false, mistakeSteer: 0, prevError: 0,
      skill: 0.92 + match.random() * 0.14, lane: match.random() * 6 - 3, phase: match.random() * Math.PI * 2});
  });
  return match.race;
}

export function raceStandings(state) {
  if (!state) return [];
  return [...state.racers].sort((a,b) => {
    if (a.finishTime !== null || b.finishTime !== null) return (a.finishTime ?? Infinity) - (b.finishTime ?? Infinity) || a.actorId - b.actorId;
    return b.progress - a.progress || a.actorId - b.actorId;
  }).map((r,index) => ({actorId: r.actorId, vehicleId: r.vehicleId, position: index + 1,
    lap: r.lap, completedLaps: r.completedLaps, nextGate: r.nextGate, progress: r.progress,
    finishTime: r.finishTime, item: r.item, coins: r.coins, effects: {...r.effects}}));
}

export function raceSnapshot(state) {
  if (!state) return null;
  return {phase: state.phase, countdown: state.countdown, laps: state.laps, elapsed: state.elapsed,
    finalLap: state.finalLap === true, winnerId: state.winnerId, standings: raceStandings(state),
    boxes: state.boxes.map(({id,x,z,wait}) => ({id,x,z,ready: wait <= 0})),
    coins: state.coins.map(({id,x,z,wait}) => ({id,x,z,ready: wait <= 0})),
    hazards: state.hazards.map(({id,x,z,ttl,type}) => ({id,x,z,ttl,type})), gates: state.gates.map(g => ({...g}))};
}

// Only the expected gate can advance progress. Intersections use the swept center,
// the forward normal, and the finite ground-level opening, never proximity.
export function crossRaceGates(state, racer, from, to, startTime, dt) {
  let lastT = -1;
  for (let count = 0; count < state.gates.length; count++) {
    const gate = state.gates[racer.nextGate];
    const before = (from.x-gate.x)*gate.nx + (from.z-gate.z)*gate.nz;
    const after = (to.x-gate.x)*gate.nx + (to.z-gate.z)*gate.nz;
    if (before > 0 || after <= 0 || after <= before) break;
    const t = -before/(after-before);
    const x = from.x+(to.x-from.x)*t-gate.x, z = from.z+(to.z-from.z)*t-gate.z;
    const y = from.y+(to.y-from.y)*t;
    if (t <= lastT || !Number.isFinite(y) || y < -.25 || y > 3 || Math.abs(x*gate.nz-z*gate.nx) > gate.halfWidth) break;
    lastT = t;
    if (racer.nextGate === 0) {
      if (racer.started) racer.completedLaps++;
      racer.started = true;
      racer.lap = Math.min(state.laps, racer.completedLaps+1);
    }
    racer.passed++;
    racer.anchor = {x: gate.x+gate.nx*.5, z: gate.z+gate.nz*.5, heading: Math.atan2(gate.nx,gate.nz)};
    racer.nextGate = (racer.nextGate+1)%state.gates.length;
    racer.checkpointAge = 0;
    if (racer.completedLaps >= state.laps) {
      racer.finishTime = startTime+t*dt;
      break;
    }
  }
  const prev = state.gates[(racer.nextGate+state.gates.length-1)%state.gates.length], next = state.gates[racer.nextGate];
  const dx = next.x-prev.x, dz = next.z-prev.z, span = dx*dx+dz*dz;
  const fraction = span > 1e-9 ? clamp(((to.x-prev.x)*dx+(to.z-prev.z)*dz)/span,0,.999999) : 0;
  racer.progress = racer.started ? racer.passed-1+fraction : -distance(to,state.gates[0])/1000;
}

export function resetRaceRacer(match, racer) {
  const vehicle = match.vehicleById(racer.vehicleId), a = racer.anchor;
  respawnVehicle(vehicle, {x:a.x,y:0,z:a.z}, a.heading);
  takeVehicleSeat(vehicle,racer.actorId,'driver');
  racer.resetWait = 2; racer.stuck = 0; racer.checkpointAge = 0;
  racer.effects.turbo = 0; racer.effects.draft = 0;
  racer.draftCharge = 0; racer.draftCooldown = 0;
  const actor = match.actors.find(a => a.id === racer.actorId);
  actor.yaw = a.heading-Math.PI;
  match.syncVehicleActor(actor,vehicle);
  // Teleports are not swept, and cannot grant a gate or undo banked checkpoints.
  crossRaceGates(match.race,racer,vehicle.position,vehicle.position,match.race.elapsed,0);
}

export function botControls(match, state, racer, vehicle, dt=0) {
  const points = state.centerline, n = points.length;
  if (n < 2) return {throttle: 1, steer: 0, sprint: false, fire: Boolean(racer.item)&&!racer.useHeld};
  const next = racer.nextGate, prev = (next+n-1)%n;
  const a = points[prev], b = points[next], dx = b.x-a.x, dz = b.z-a.z, length = Math.hypot(dx,dz)||1e-6;
  const along = clamp(((vehicle.position.x-a.x)*dx+(vehicle.position.z-a.z)*dz)/length,0,length);
  // Walk the authored centerline from the car's projection. `advance` is an arc
  // distance ahead and returns both the point and the segment heading.
  const aheadAt = advance => {
    let index = prev, pos = along;
    for (let i=0;i<n;i++) {
      const p = points[index], q = points[(index+1)%n], len = distance(p,q)||1e-6;
      if (pos+advance <= len) { const t=(pos+advance)/len; return {x:p.x+(q.x-p.x)*t,z:p.z+(q.z-p.z)*t,h:Math.atan2(q.x-p.x,q.z-p.z)}; }
      advance -= len-pos; pos=0; index=(index+1)%n;
    }
    return {x:b.x,z:b.z,h:Math.atan2(dx,dz)};
  };
  const speed = Math.abs(Number(vehicle.speed)||0), top = DRAFT_TOP_SPEED;
  const baseHeading = Math.atan2(dx,dz);
  // Tightest heading change across the sample distances sets the corner speed.
  let curvature = 0;
  for (const look of AI_LOOKAHEADS) {
    const sample = aheadAt(look);
    curvature = Math.max(curvature, Math.abs(angle(sample.h-baseHeading))/look);
  }
  const targetSpeed = clamp(Math.sqrt(AI_MAX_LAT_ACCEL/Math.max(curvature,1e-4)), AI_MIN_TARGET_SPEED, top);
  // Rare deterministic mistake when a new gate is armed: a short throttle lift
  // or a small steering wobble, seeded from match.random.
  if (racer.botGate !== racer.nextGate) {
    racer.botGate = racer.nextGate;
    if (match.random() < AI_MISTAKE_CHANCE) { racer.mistake = AI_MISTAKE_TIME; racer.mistakeLift = match.random() < 0.5; racer.mistakeSteer = match.random()*0.5-0.25; }
  }
  racer.mistake = Math.max(0, (racer.mistake||0) - dt);
  const steering = aheadAt(Math.max(5, speed*0.65));
  // Shift the lookahead target sideways along the racing line so seeded racers
  // do not all chase the exact same geometric point, and swing the lane by gate
  // so the pack does not settle onto one fixed groove.
  const lane = (Number.isFinite(racer.lane) ? racer.lane : 0) + 2.5*Math.sin((racer.nextGate||0)*0.7 + (racer.phase||0));
  const target = lane ? {x:steering.x+Math.cos(steering.h)*lane, z:steering.z-Math.sin(steering.h)*lane} : steering;
  const error = angle(Math.atan2(target.x-vehicle.position.x,target.z-vehicle.position.z)-vehicle.heading);
  const derivative = dt > 0 ? (error-(racer.prevError||0))/dt : 0;
  racer.prevError = error;
  const braking = targetSpeed < top-1e-6 && speed > targetSpeed+0.5;
  let throttle = braking ? 0 : 1, steer = clamp(error*1.8+derivative*0.06,-1,1);
  if (racer.mistake > 0) {
    if (racer.mistakeLift) throttle = 0;
    else steer = clamp(steer+(racer.mistakeSteer||0),-1,1);
  }
  return {throttle, steer, brake: braking,
    sprint: Math.abs(error)<.08&&distance(vehicle.position,b)>18, fire: Boolean(racer.item)&&!racer.useHeld};
}

// Nearest car directly ahead inside the draft cone, or null. Uses the follower's
// own forward/right frame, so a car only drafts what is genuinely in front.
function draftLeader(match, state, racer) {
  const vehicle = match.vehicleById(racer.vehicleId);
  if (!vehicle || !Number.isFinite(vehicle.position?.x) || Math.abs(Number(vehicle.speed)||0) < DRAFT_TOP_SPEED*DRAFT_SPEED_FRACTION) return null;
  const heading = Number(vehicle.heading)||0, fx = Math.sin(heading), fz = Math.cos(heading);
  let best = null, bestGap = Infinity;
  for (const other of state.racers) {
    if (other === racer || other.actorId === racer.actorId) continue;
    const ov = match.vehicleById(other.vehicleId);
    if (!ov || !Number.isFinite(ov.position?.x) || Math.abs(Number(ov.speed)||0) < DRAFT_TOP_SPEED*DRAFT_SPEED_FRACTION) continue;
    const oh = Number(ov.heading)||0;
    if (fx*Math.sin(oh)+fz*Math.cos(oh) <= DRAFT_HEADING_DOT) continue;
    const dx = ov.position.x-vehicle.position.x, dz = ov.position.z-vehicle.position.z;
    const gap = dx*fx+dz*fz;
    if (gap < DRAFT_GAP_MIN || gap > DRAFT_GAP_MAX || gap >= bestGap) continue;
    if (Math.abs(dx*Math.cos(heading)-dz*Math.sin(heading)) > DRAFT_LATERAL) continue;
    best = other; bestGap = gap;
  }
  return best;
}

// Advance draft charge/cooldown one physics step and grant the boost when the
// cone has been held long enough. Granting draws its strength from match.random
// so a fixed seed stays reproducible.
export function stepSlipstream(match, state, dt) {
  for (const racer of state.racers) {
    if (racer.draftCooldown > 0) racer.draftCooldown = Math.max(0, racer.draftCooldown-dt);
    if (racer.resetWait > 0 || racer.draftCooldown > 0 || !draftLeader(match, state, racer)) { racer.draftCharge = 0; continue; }
    racer.draftCharge = (racer.draftCharge||0)+dt;
    if (racer.draftCharge < DRAFT_BUILD) continue;
    racer.draftCharge = 0;
    racer.draftCooldown = DRAFT_COOLDOWN;
    racer.draftBoost = DRAFT_BOOST_MIN + match.random()*(DRAFT_BOOST_MAX-DRAFT_BOOST_MIN);
    racer.effects.draft = DRAFT_DURATION;
    match.emit?.('race-draft', {actor: racer.actorId, boost: racer.draftBoost, pos: {...match.vehicleById(racer.vehicleId).position}});
  }
}

function useItem(match, racer) {
  const state=match.race, vehicle=match.vehicleById(racer.vehicleId), item=racer.item;
  if (!item) return;
  match.emit?.('race-item', {actor: racer.actorId, item, pos: vehicle?.position ? {...vehicle.position} : null});
  racer.item=null;
  if (item==='turbo') racer.effects.turbo=2;
  if (item==='shield') {racer.effects.shield=5; racer.effects.slow=0;}
  if (item==='oil') state.hazards.push({id:++state.serial,owner:racer.actorId,type:'oil',
    x:vehicle.position.x-Math.sin(vehicle.heading)*4,z:vehicle.position.z-Math.cos(vehicle.heading)*4,ttl:8,slow:2,radius:3});
  if (item==='pulse') { const target=opponentsAhead(state,racer)[0]; if (target) applySlow(target,2); }
  if (item==='mine') state.hazards.push({id:++state.serial,owner:racer.actorId,type:'mine',
    x:vehicle.position.x,z:vehicle.position.z,ttl:12,slow:2.5,radius:3.5});
  if (item==='triple') for (const target of opponentsAhead(state,racer).slice(0,3)) applySlow(target,1.5);
  if (item==='bolt') for (const target of opponentsAhead(state,racer)) applySlow(target,2);
  if (item==='star') racer.effects.star=3.5;
}

export function stepRace(match, dt, inputs={}) {
  const state=match.race;
  if (!state || match.over || !Number.isFinite(dt) || dt<=0) return;
  // Fixed-size physics slices also make large host ticks safe for vehicle physics.
  let remaining=dt;
  const given=inputs.inputs||{0:inputs};
  while (remaining>1e-9 && !match.over) {
    let step=Math.min(remaining,1/60);
    if (state.phase==='countdown') {
      step=Math.min(step,state.countdown);
      state.countdown=Math.max(0,state.countdown-step); match.time+=step; remaining-=step;
      for (const r of state.racers) {r.useHeld=Boolean(given[r.actorId]?.fire||given[r.actorId]?.power); r.resetHeld=Boolean(given[r.actorId]?.interact);}
      if (state.countdown<1e-9) {state.countdown=0;state.phase='racing';}
      continue;
    }
    step=Math.min(step,Math.max(0,match.config.timeLimit-state.elapsed));
    const start=state.elapsed;
    state.elapsed+=step; match.time+=step; remaining-=step;
    for (const box of state.boxes) box.wait=Math.max(0,box.wait-step);
    for (const coin of state.coins) coin.wait=Math.max(0,coin.wait-step);
    for (const hazard of state.hazards) hazard.ttl-=step;
    state.hazards=state.hazards.filter(h=>h.ttl>0);
    for (const r of state.racers) for (const effect of Object.keys(r.effects)) r.effects[effect]=Math.max(0,r.effects[effect]-step);
    stepSlipstream(match, state, step);
    const ranks=rankFractions(state);
    for (const r of state.racers) {
      const actor=match.actors.find(a=>a.id===r.actorId), vehicle=match.vehicleById(r.vehicleId);
      const external=given[actor.id], controls=external||(actor.bot?botControls(match,state,r,vehicle,step):{});
      if (Number.isFinite(controls.yaw)) actor.yaw=controls.yaw;
      const use=Boolean(controls.fire||controls.power), reset=Boolean(controls.interact);
      if (reset&&!r.resetHeld) resetRaceRacer(match,r);
      if (use&&!r.useHeld&&r.resetWait<=0) useItem(match,r);
      r.useHeld=use; r.resetHeld=reset;
      if (r.boostPadWait>0) r.boostPadWait=Math.max(0,r.boostPadWait-step);
      if (r.resetWait>0) {r.resetWait=Math.max(0,r.resetWait-step); continue;}
      const from={...vehicle.position};
      const automatic=actor.bot&&!external;
      const rank=ranks.get(r.actorId)??0;
      const throttle=automatic?controls.throttle:clamp(-(controls.x||0)*Math.sin(actor.yaw)-(controls.z||0)*Math.cos(actor.yaw),-1,1);
      const steer=automatic?controls.steer:clamp(-(controls.x||0)*Math.cos(actor.yaw)+(controls.z||0)*Math.sin(actor.yaw),-1,1);
      const itemScale=(r.effects.slow>0?.5:r.effects.turbo>0?1.6:1)*(r.effects.star>0?1.35:1);
      const draftScale=r.effects.draft>0?(Number.isFinite(r.draftBoost)?r.draftBoost:DRAFT_BOOST_MIN):1;
      const coinScale=1+.012*clamp(r.coins,0,10);
      const skill=automatic&&Number.isFinite(r.skill)?r.skill:1;
      const speedScale=clamp(itemScale*coinScale*paceMultiplier(rank)*skill*draftScale,.1,2);
      stepVehicle(vehicle,{throttle,steer,brake:controls.brake===true||controls.jump===true||controls.crouch===true,
        boost:controls.sprint===true,speedScale,boostScale:speedScale,fire:false},step,
        next=>match.vehicleCollision(next,vehicle),()=>0);
      if (automatic) actor.yaw=vehicle.heading-Math.PI;
      match.syncVehicleActor(actor,vehicle);
      const prevLaps=r.completedLaps;
      crossRaceGates(state,r,from,vehicle.position,start,step);
      if (r.completedLaps>prevLaps) {
        if (r.completedLaps>=state.laps) match.emit?.('race-finish', {actor: r.actorId, lap: r.completedLaps, time: r.finishTime, pos: {...vehicle.position}});
        else match.emit?.('race-lap', {actor: r.actorId, lap: r.completedLaps, pos: {...vehicle.position}});
      }
      for (const box of state.boxes) if (!r.item&&box.wait<=0&&distance(vehicle.position,box)<3) {
        r.item=rollItem(match.random,rank); box.wait=8;
        match.emit?.('race-box', {actor: r.actorId, item: r.item, pos: {x: box.x, y: 2.2, z: box.z}});
      }
      for (const coin of state.coins) if (coin.wait<=0&&distance(vehicle.position,coin)<2.2) {
        r.coins=Math.min(10,r.coins+1); coin.wait=10;
        match.emit?.('race-coin', {actor: r.actorId, coins: r.coins, pos: {x: coin.x, y: 1.2, z: coin.z}});
      }
      if (r.boostPadWait<=0&&r.effects.star<=0) for (const pad of state.boostPads) if (distance(vehicle.position,pad)<2.6) {
        r.effects.turbo=Math.max(r.effects.turbo,1.2); r.boostPadWait=1.2;
        match.emit?.('race-boost', {actor: r.actorId, pos: {x: pad.x, y: 0, z: pad.z}});
        break;
      }
      for (const h of state.hazards) if (h.owner!==r.actorId&&distance(vehicle.position,h)<(h.radius??3)) {
        if (applySlow(r,h.slow??2)) match.emit?.('race-hazard-hit', {actor: r.actorId, hazard: h.type, pos: {x: h.x, y: 0, z: h.z}});
      }
      r.stuck=Math.abs(throttle)>.1&&distance(from,vehicle.position)<.015?r.stuck+step:0;
      r.checkpointAge+=step;
      if (r.finishTime===null&&(r.stuck>3||r.checkpointAge>20||!Number.isFinite(vehicle.position.x)||!Number.isFinite(vehicle.position.z))) resetRaceRacer(match,r);
    }
    // Contacts settle after every racer moved and banked gates, so a push can
    // never re-run a crossing or duplicate progress.
    state.contacts += resolveCarCollisions(match,state,2);
    // Resolve after every racer moved, using sub-tick crossing times, not actor order.
    const order=raceStandings(state);
    // The final-lap flag latches once the current leader is on their last lap.
    if (!state.finalLap && state.laps > 0) {
      const leader=state.racers.find(r=>r.actorId===order[0]?.actorId);
      if (leader && leader.lap >= state.laps) state.finalLap=true;
    }
    if (order[0]?.finishTime!==null || state.elapsed>=match.config.timeLimit) {
      state.phase='finished'; state.winnerId=order[0]?.actorId??null;
      match.endMatch(order[0]?.finishTime!==null?'race-finish':'time');
    }
  }
}

// Place a car candidate only when the world accepts it. Returns the resolved
// position, or null when blocked (never a NaN or a wall clip).
function tryPlace(match, vehicle, x, z) {
  if (!Number.isFinite(x) || !Number.isFinite(z) || typeof match.vehicleCollision !== 'function') return null;
  const y = Number.isFinite(vehicle.position?.y) ? vehicle.position.y : 0;
  const resolved = match.vehicleCollision({x, y, z}, vehicle);
  if (resolved && Number.isFinite(resolved.x) && Number.isFinite(resolved.z)) return resolved;
  return null;
}

function applyPlace(vehicle, resolved) {
  vehicle.position.x = resolved.x;
  vehicle.position.z = resolved.z;
  if (Number.isFinite(resolved.y)) vehicle.position.y = resolved.y;
}

// Nudge one velocity component onto `target` along the contact normal.
function setNormalSpeed(velocity, nx, nz, target) {
  const current = velocity.x * nx + velocity.z * nz;
  const delta = target - current;
  if (!Number.isFinite(delta)) return;
  velocity.x += nx * delta;
  velocity.z += nz * delta;
  if (!Number.isFinite(velocity.x)) velocity.x = 0;
  if (!Number.isFinite(velocity.z)) velocity.z = 0;
}

// Resolve one overlapping pair. Positions are pushed apart symmetrically; if a
// side is pinned by world geometry the other takes the full (still guarded)
// correction. Normal velocity is made equal so the pair cannot immediately
// re-overlap or tunnel through one another.
function resolveCarPair(match, racerA, racerB) {
  const va = match.vehicleById(racerA.vehicleId), vb = match.vehicleById(racerB.vehicleId);
  if (!va || !vb) return false;
  const pa = va.position, pb = vb.position;
  if (!Number.isFinite(pa?.x) || !Number.isFinite(pa?.z) || !Number.isFinite(pb?.x) || !Number.isFinite(pb?.z)) return false;
  let dx = pb.x - pa.x, dz = pb.z - pa.z, d = Math.hypot(dx, dz);
  if (d >= MIN_CAR_SEPARATION) return false;
  let nx, nz;
  if (d > 1e-6) { nx = dx / d; nz = dz / d; }
  else if ((racerA.actorId ?? 0) >= (racerB.actorId ?? 0)) { nx = 1; nz = 0; }
  else { nx = -1; nz = 0; }
  const penetration = MIN_CAR_SEPARATION - d, half = penetration / 2;
  let ga = tryPlace(match, va, pa.x - nx * half, pa.z - nz * half);
  let gb = tryPlace(match, vb, pb.x + nx * half, pb.z + nz * half);
  if (ga && !gb) {
    const full = tryPlace(match, va, pa.x - nx * penetration, pa.z - nz * penetration);
    if (full) ga = full;
  } else if (!ga && gb) {
    const full = tryPlace(match, vb, pb.x + nx * penetration, pb.z + nz * penetration);
    if (full) gb = full;
  }
  if (!ga && !gb) return false;
  // Contact never transfers speed to the car ahead. The rammer is the car
  // closing fastest along the normal (measured toward the other car); it is
  // capped at the leader's own normal speed with a small penalty, while the
  // leader keeps its speed. Equal-speed side-by-side scrapes barely change
  // either car, so separation is maintained without an artificial speed-up.
  if (va.velocity && vb.velocity) {
    const closing = (va.velocity.x - vb.velocity.x) * nx + (va.velocity.z - vb.velocity.z) * nz;
    if (closing > 0) {
      const vaN = va.velocity.x * nx + va.velocity.z * nz;
      const vbN = vb.velocity.x * nx + vb.velocity.z * nz;
      // approachA = vaN (A toward B), approachB = -vbN (B toward A).
      if (vaN + vbN >= 0) setNormalSpeed(va.velocity, nx, nz, vbN * CONTACT_RAM_PENALTY);
      else setNormalSpeed(vb.velocity, nx, nz, vaN * CONTACT_RAM_PENALTY);
    }
  }
  if (ga) applyPlace(va, ga);
  if (gb) applyPlace(vb, gb);
  const actorA = match.actors?.find(a => a.id === racerA.actorId);
  const actorB = match.actors?.find(a => a.id === racerB.actorId);
  if (ga && actorA) match.syncVehicleActor(actorA, va);
  if (gb && actorB) match.syncVehicleActor(actorB, vb);
  return true;
}

export function resolveCarCollisions(match, state, passes = 2) {
  if (!state?.racers?.length) return 0;
  let resolved = 0;
  for (let pass = 0; pass < passes; pass++) {
    let moved = false;
    for (let i = 0; i < state.racers.length; i++) {
      const a = state.racers[i];
      if (a.resetWait > 0) continue;
      for (let j = i + 1; j < state.racers.length; j++) {
        const b = state.racers[j];
        if (b.resetWait > 0) continue;
        if (resolveCarPair(match, a, b)) { moved = true; resolved++; }
      }
    }
    if (!moved) break;
  }
  return resolved;
}

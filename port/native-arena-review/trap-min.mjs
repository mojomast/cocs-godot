// Review-lane minimal reproduction: an actor that lands within the source
// wall-contact radius of a ramp side band cannot move again.
//
// Source movement (game/core.mjs moveActor) applies an axis step only when the
// destination is NOT obstructed at RULES.radius (0.42). Acceleration starts at
// sub-centimetre steps, so once the actor is inside that band no single step can
// leave it and every axis move is refused: position frozen, jumps continue.
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {floorAt, obstructed} from '../../game/core.mjs';
import {createNativeMatch} from '../native-arenas/match.mjs';
import {seededRandom} from './lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const mapId = process.argv.find(a => a.startsWith('--map='))?.split('=')[1] ?? 'prism-foundry';
const match = createNativeMatch({mapId, config: {mode: 'deathmatch', botCount: 1, timeLimit: 60, fragLimit: 50}, random: seededRandom(1234)});
const arena = match.arena;
const a = match.actors[0];
const trials = [];
function trial(label, x, z, controls, steps = 120, y = null) {
  const fy = y ?? floorAt(x, z, arena);
  Object.assign(a, {x, y: fy, z, vx: 0, vy: 0, vz: 0, grounded: true, health: a.maxHealth, dead: 0, protection: 0,
    yaw: 0, pitch: 0, punchYaw: 0, punchPitch: 0, sliding: false, sprinting: false});
  const start = {x: a.x, y: a.y, z: a.z};
  let maxDist = 0;
  for (let i = 0; i < steps; i++) {
    match.step(1 / 60, {inputs: {0: controls}});
    maxDist = Math.max(maxDist, Math.hypot(a.x - start.x, a.z - start.z));
  }
  trials.push({label, start: [+start.x.toFixed(2), +start.y.toFixed(2), +start.z.toFixed(2)], end: [+a.x.toFixed(2), +a.y.toFixed(2), +a.z.toFixed(2)],
    maxHorizontalDisplacement: +maxDist.toFixed(3), escaped: maxDist > 0.75,
    obstructedAtStart: {r006: obstructed(start.x, start.y, start.z, 0.06, arena), r02: obstructed(start.x, start.y, start.z, 0.2, arena),
      r03: obstructed(start.x, start.y, start.z, 0.3, arena), r042: obstructed(start.x, start.y, start.z, 0.42, arena), r05: obstructed(start.x, start.y, start.z, 0.5, arena)}});
}
// The captured bot landing spot: on the ramp top, 0.06 m inside its side edge.
for (const [label, x, z] of [['trap-landing-spot-8.96', -8.96, -8.4], ['free-spot-8.2', -8.2, -8.4], ['free-spot-8.5', -8.5, -8.4], ['free-spot-8.6', -8.6, -8.4]]) {
  const y = floorAt(x, z, arena);
  // world-axis input: +x moves away from the ramp side face
  trial(`${label}-move+x`, x, z, {x: 1, z: 0}, 120, y);
}
// Same spot, every cardinal direction (world axes).
for (const [label, cx, cz] of [['+x', 1, 0], ['-x', -1, 0], ['+z', 0, 1], ['-z', 0, -1]]) {
  trial(`trap-landing-spot-move-${label}`, -8.96, -8.4, {x: cx, z: cz}, 120);
}
// Jumping while inside the band does not help (matches the captured 71 s window).
trial('trap-landing-spot-jump-repeat', -8.96, -8.4, {x: 1, z: 0, jump: true}, 240);
console.log(JSON.stringify({mapId, rampEdge: {x: -8.96, floor: floorAt(-8.96, -8.4, arena)}, trials}, null, 1));

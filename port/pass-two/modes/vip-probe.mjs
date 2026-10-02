// Bounded accelerated-source diagnostic; inputs target ONLY the human actor.
// No runtime map, actor, objective or rule mutation is used to obtain an outcome.
import {Match, moveActor, floorAt} from '../../../game/core.mjs';
import {writeFileSync} from 'node:fs';
const match = new Match('chatgpt', 'openclaw', () => .5, 'sunscar-convoy',
  {mode: 'vip-escort', botCount: 0, humanCount: 2, timeLimit: 180});
const samples = [];
let collisionWitness;
for (let tick = 0; tick < 10810 && !match.over; tick++) {
  const actor = match.actors[0], vip = match.actors.find(a => a.isVip);
  const dx = vip ? vip.x - actor.x : 0, dz = vip ? vip.z - actor.z : 0;
  const distance = Math.hypot(dx, dz);
  match.step(1 / 60, {inputs: {0: {x: distance > 2 ? dx / distance : 0,
    z: distance > 2 ? dz / distance : 0, yaw: Math.atan2(-dx, -dz)}}});
  if (tick % 600 === 0) samples.push({time: match.time,
    actor: {x: actor.x, y: actor.y, z: actor.z},
    vip: vip && {x: vip.x, y: vip.y, z: vip.z}, progress: match.objectiveState.progress});
  if (!collisionWitness && vip && match.time > 90) {
    // Isolate a single ordinary locomotion step on a COPY. Its recovered x
    // identifies the collision; this copy is never installed in the Match.
    const copy = structuredClone(vip);
    const before = {x: copy.x, y: copy.y, z: copy.z};
    moveActor(copy, {}, 1 / 60, match.arena, match.config);
    const extract = match.objectiveState.extract;
    const length = Math.hypot(extract.x - copy.x, extract.z - copy.z);
    const next = {x: copy.x + (extract.x - copy.x) / length * 4 / 60,
      z: copy.z + (extract.z - copy.z) / length * 4 / 60};
    collisionWitness = {before, afterLocomotion: {x: copy.x, y: copy.y, z: copy.z},
      nextDirectObjectiveStep: {...next, floor: floorAt(next.x, next.z, match.arena)},
      bulkhead: match.arena.blocks.find(b => b.kind === 'bulkhead' && b.x === -30 && b.z === -22)};
  }
}
const report = {kind: 'accelerated-source-ordinary-human-input-failed-extraction',
  samples, collisionWitness, time: match.time, winner: match.winner,
  objective: match.objectiveState, extracted: match.events.some(e => e.type === 'vip-extracted')};
const output = process.argv[2];
if (!output) throw Error('Explicit evidence output path required');
writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({output, extracted: report.extracted, collisionWitness}));

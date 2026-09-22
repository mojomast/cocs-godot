// Review-lane decisive movement test: can a real source actor walk across the
// points my static probe flagged as "movement blocked, rays clear"?
//
// Uses Match.step with ordinary controls on a live match (no state injection
// beyond the initial teleport used to start each trial at the probe point).
import {readFileSync, readdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {floorAt} from '../../game/core.mjs';
import {createNativeMatch} from '../native-arenas/match.mjs';
import {seededRandom} from './lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const logDir = `${ROOT}/port/native-arena-review/logs`;
const source = readdirSync(logDir).filter(f => f.startsWith('geometry-analysis-')).sort().pop();
const analysis = JSON.parse(readFileSync(`${logDir}/${source}`, 'utf8'));
const followup = JSON.parse(readFileSync(`${logDir}/${readdirSync(logDir).filter(f => f.startsWith('probe-followup-')).sort().pop()}`, 'utf8'));

const out = {};
for (const [mapId, report] of Object.entries(analysis)) {
  const match = createNativeMatch({mapId, config: {mode: 'deathmatch', botCount: 1, timeLimit: 60, fragLimit: 50}, random: seededRandom(7)});
  const arena = match.arena;
  const actor = match.actors[0];
  const trials = [];
  const samples = (followup[mapId]?.wallOrSolidBlocks ?? report.wallProbes.samples).slice(0, 8).map(s => s.sample ?? s);
  for (const sample of samples) {
    const y = floorAt(sample.x, sample.z, arena);
    if (y === null) continue;
    const dir = {x: sample.to[0] - sample.x, z: sample.to[2] - sample.z};
    const len = Math.hypot(dir.x, dir.z);
    // Aim input along the world direction: Motion.movement(yaw, forward) maps
    // forward to the camera forward vector; solve the yaw for this direction.
    const yaw = Math.atan2(-dir.x, -dir.z);
    const start = {x: sample.x, z: sample.z};
    Object.assign(actor, {x: sample.x, y, z: sample.z, vx: 0, vy: 0, vz: 0, grounded: true, health: actor.maxHealth,
      yaw, pitch: 0, punchYaw: 0, punchPitch: 0, protection: 0, dead: 0, sliding: false, sprinting: false});
    let maxAdvance = 0, blockedSteps = 0, airborne = 0;
    for (let i = 0; i < 90; i++) {
      match.step(1 / 60, {inputs: {0: {x: 1, z: 0, yaw, pitch: 0}}});
      const advance = ((actor.x - start.x) * dir.x + (actor.z - start.z) * dir.z) / len;
      maxAdvance = Math.max(maxAdvance, advance);
      if (advance < 0.05 && i > 30) blockedSteps++;
      if (!actor.grounded) airborne++;
    }
    trials.push({from: [sample.x, sample.y, sample.z], intended: [+(sample.x + dir.x).toFixed(2), +(sample.z + dir.z).toFixed(2)],
      distance: +len.toFixed(2), maxAdvance: +maxAdvance.toFixed(2), finalAdvance: +(((actor.x - start.x) * dir.x + (actor.z - start.z) * dir.z) / len).toFixed(2),
      blockedSteps, airborneSteps: airborne, passed: maxAdvance > len * 0.9});
  }
  out[mapId] = {trials, passed: trials.filter(t => t.passed).length, total: trials.length};
}
const outPath = `${logDir}/probe-move-${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
writeFileSync(outPath, `${JSON.stringify(out, null, 2)}\n`);
console.log(JSON.stringify({source, outPath, summary: Object.fromEntries(Object.entries(out).map(([k, v]) => [k, `${v.passed}/${v.total} passed`]))}));

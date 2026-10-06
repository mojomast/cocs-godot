#!/usr/bin/env node
// F10 promotion-prep scenario runner. NOT a human playtest and not an engine
// run: the player is scripted and the only output is the exact HUD-relevant
// snapshot fields, so the control rule and the opt-in policy can be compared
// side by side on the same seed. No rendering, no audio, no acceptance claim.
//
//   node port/native-campaign/f10-scenario.mjs --policy=experiment
//   node port/native-campaign/f10-scenario.mjs --policy=control
//
// Stops printing once the opted-in transfer has completed and every retreating
// guard has left, or after --seconds.
import {createCampaignMatch} from './match.mjs';
import {loadCampaignMap} from './maps.mjs';
import {OBJECTIVE_COMPLETION} from './missions.mjs';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const hit = args.find(argument => argument.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
};
const policyName = flag('policy', 'experiment');
const policy = policyName === 'control' ? OBJECTIVE_COMPLETION.requireAllGuards
  : policyName === 'experiment' ? OBJECTIVE_COMPLETION.restoreAndWithdraw
  : (() => { throw new Error(`Unknown --policy=${policyName} (use control or experiment)`); })();
const difficulty = flag('difficulty', 'normal');
const seed = Number(flag('seed', 8157));
const seconds = Number(flag('seconds', 30));
if (!['easy', 'normal', 'hard'].includes(difficulty)) throw new Error(`Unknown --difficulty=${difficulty}`);
if (!Number.isFinite(seed) || !Number.isFinite(seconds) || seconds <= 0) throw new Error('Invalid --seed/--seconds');

const DT = 1 / 60;
const MAP = 'siltwake-crossing';
const STEP = 1;                       // "Restart the west pump": restore, 5 s
const rng = (value) => { let n = value >>> 0; return () => ((n = Math.imul(n, 1664525) + 1013904223 >>> 0) / 4294967296); };
const data = loadCampaignMap(MAP);
const mark = data.campaign.anchors[`encounter-${STEP + 1}`];
const match = createCampaignMatch({mapId: MAP, difficulty, random: rng(seed), checkpoint: STEP, objectiveCompletion: policy});
const put = (point) => Object.assign(match.actors[0], {x: point.x, y: point.y, z: point.z, vx: 0, vy: 0, vz: 0, grounded: true, lastValid: {x: point.x, y: point.y, z: point.z}});
const fixed = (value) => typeof value === 'number' ? value.toFixed(2) : String(value);
function line() {
  const campaign = match.snapshot().campaign;
  const guards = match.actors.filter(a => a.isNpc && a.health > 0)
    .map(a => `${a.npcModel}@${fixed(a.x)},${fixed(a.z)}`).join(' ');
  return [`t=${fixed(match.time)}`, `step=${campaign.stepIndex}`, `hold=${fixed(campaign.holdProgress)}`,
    `enemies=${campaign.enemiesRemaining}`, `withdrawing=${campaign.withdrawing ?? 0}`, `kills=${campaign.kills}`,
    `phase=${campaign.phase}`, `detail="${campaign.detail}"`, `echo="${campaign.transmission.text}"`,
    `guards=[${guards}]`].join(' ');
}

put({x: mark.x + 34, y: mark.y, z: mark.z}); match.step(DT, {inputs: {0: {}}});
if (!match.modeState.deployed) { put(mark); match.step(DT, {inputs: {0: {}}}); }
put(mark);
console.log(`F10 scenario policy=${policyName} difficulty=${difficulty} seed=${seed} map=${MAP} step=${STEP}`);
let nextPrint = 0;
const steps = Math.ceil(seconds / DT);
for (let n = 0; n < steps && match.snapshot().campaign.phase !== 'dead'; n++) {
  // Hold Interact so the transfer latches; the player stays on the marker.
  match.step(DT, {inputs: {0: {interact: n % 2 === 0}}});
  if (match.time >= nextPrint) { console.log(line()); nextPrint += 0.5; }
  if (match.modeState.stepIndex !== STEP && !match.modeState.withdrawn.length && match.time > 1) break;
}
console.log('FINAL ' + line());

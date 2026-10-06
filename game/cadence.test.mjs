// F07 fire-cadence characterization (measurement only).
//
// The source decrements/clamps `shotWait` and replaces it with the authored
// interval on an accepted shot, so the *effective* cadence is tick-quantized
// with a one-tick overshoot instead of the authored seconds. This test records
// that policy for every primary weapon at 60 Hz so presentation tables and
// designer values cannot silently disagree with the simulation. It does not
// change balance: no overshoot-preserving or residue-tolerant policy is
// promoted here (that requires a reviewed descriptor update).
import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from './core.mjs';
import {WEAPONS} from './data.mjs';

const STEP = 1 / 60;
const FIRE_EVENTS = new Set(['shot', 'launch']);

function firingMatch(index) {
  const match = new Match('chatgpt', 'openclaw', () => 0.5, 'exchange', {botCount: 0, humanCount: 1});
  const player = match.actors[0];
  player.weapon = index;
  player.ammo = WEAPONS.map((weapon, i) => i === index ? Infinity : 0);
  return match;
}

// One volley per accepted-fire step: pellet weapons emit several shot records
// in the step that produced them, which is one trigger pull, not extra cadence.
function fireSteps(index, steps) {
  const match = firingMatch(index);
  const recorded = [];
  let cursor = match.events.length;
  for (let step = 0; step < steps; step++) {
    match.step(STEP, {inputs: {0: {fire: true}}});
    let fired = false;
    for (const event of match.events.slice(cursor)) {
      if (FIRE_EVENTS.has(event.type) && event.actor === 0 && event.weapon === index) fired = true;
    }
    if (fired) recorded.push(step);
    cursor = match.events.length;
  }
  return recorded;
}

test('authored fire intervals quantize to whole 60 Hz ticks with bounded overshoot', () => {
  const table = [];
  for (const [index, weapon] of WEAPONS.entries()) {
    const steps = fireSteps(index, 300);
    assert.ok(steps.length >= 3, `${weapon.name} fires repeatedly under a held trigger`);
    const gaps = steps.slice(1).map((step, i) => step - steps[i]);
    assert.equal(new Set(gaps).size, 1, `${weapon.name} cadence is constant while held`);
    const gap = gaps[0];
    const effective = gap * STEP;
    assert.ok(effective >= weapon.interval - 1e-9, `${weapon.name} never fires faster than authored`);
    assert.ok(effective - weapon.interval <= 2 * STEP + 1e-9, `${weapon.name} overshoot stays within two ticks`);
    assert.equal(gap, Math.round(effective / STEP), `${weapon.name} gap is a whole number of ticks`);
    table.push({weapon: weapon.name, index, authored: weapon.interval, gapTicks: gap,
      effective: Number(effective.toFixed(6))});
  }
  assert.equal(table.length, WEAPONS.length, 'every primary weapon is characterized');
  // The audit's measured counterexamples: .1 s and .058 s authored intervals
  // become 7 and 4 ticks under the current reset policy.
  const pulse = table.find(row => row.weapon === 'Pulse Rifle');
  const smg = table.find(row => row.weapon === 'Submachine Gun');
  assert.equal(pulse.gapTicks, 7, 'Pulse Rifle .1 s authors 116.667 ms effective');
  assert.equal(smg.gapTicks, 4, 'SMG .058 s authors 66.667 ms effective');
  assert.equal(Number((pulse.effective * 1000).toFixed(3)), 116.667);
  assert.equal(Number((smg.effective * 1000).toFixed(3)), 66.667);
  console.log('CADENCE_CHARACTERIZATION', JSON.stringify(table));
});

test('trigger taps fire one shot per press and pauses never replay a burst', () => {
  const match = firingMatch(0);
  const recorded = [];
  let cursor = match.events.length;
  const step = fire => {
    match.step(STEP, {inputs: {0: {fire}}});
    for (const event of match.events.slice(cursor)) {
      if (FIRE_EVENTS.has(event.type) && event.actor === 0) recorded.push(match.time);
    }
    cursor = match.events.length;
  };
  // Spawn protection legitimately blocks the first trigger pull; fire a tap
  // only once the round has started, then test the tap/pause/tap rhythm.
  for (let i = 0; i < 60; i++) step(false);
  step(true);
  step(false);
  for (let i = 0; i < 120; i++) step(false);
  step(true);
  step(false);
  assert.equal(recorded.length, 2, 'each trigger tap fires exactly one shot');
  assert.ok(recorded[1] - recorded[0] > 1.9, 'the pause is long enough to expire the cooldown');
  // A burst weapon must not dump a catch-up burst after the pause either.
  for (let i = 0; i < 30; i++) step(false);
  assert.equal(recorded.length, 2, 'no catch-up burst after a pause');
});

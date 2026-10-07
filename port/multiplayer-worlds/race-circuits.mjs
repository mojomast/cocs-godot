#!/usr/bin/env node
// Shared source of truth for authored race circuits.
//
// A race circuit's checkpoint count is authored data, never a constant in a
// check. The hand-written recipe carries race.gates verbatim into the generated
// Godot arena, and game/race.mjs initializeRace copies them into the live room,
// so any consumer of a live race must compare against the authored sequence.
// Sources of truth:
//   port/native-multiplayer-worlds/worlds/sirocco-circuit.json      14 gates
//   port/native-multiplayer-worlds/worlds/stormglass-causeway.json  21 gates
// Each circuit derives one gate per authored centerline corner (see
// tools/godot-multiplayer/new-maps/stormglass-causeway/recipe.mjs), and a
// circuit is only valid when the gate sequence matches the driving loop.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';

export function authoredRace(map) {
  const recipe = JSON.parse(readFileSync(new URL(`../native-multiplayer-worlds/worlds/${map}.json`, import.meta.url), 'utf8'));
  if (recipe.id !== map || !Array.isArray(recipe.race?.gates) || !recipe.race.gates.length || !Array.isArray(recipe.race?.centerline))
    throw Error(`No authored race circuit for ${map}`);
  return recipe.race;
}

// Verifies a live race carries the authored circuit intact. Comparing the whole
// sequence rather than a bare count is strictly stronger: a count alone accepts
// a truncated or reordered circuit, this rejects both.
export function assertAuthoredCircuit(race, map, label) {
  const circuit = authoredRace(map);
  assert.equal(circuit.gates.length, circuit.centerline.length, `${label ?? map}: authored gates match the driving loop`);
  assert.deepEqual(race.gates, circuit.gates, `${label ?? map}: race carries the authored gate sequence`);
  return circuit;
}
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const demo = read('godot/assault/demo.gd');
const state = read('godot/assault/state.gd');

test('source contract still supplies sequential six-second Assault with both drain rates', () => {
  const source = read('game/assault.mjs');
  assert.match(source, /captureSeconds=6/);
  assert.match(source, /active\.progress-rate\*\.6/);
  assert.match(source, /active\.progress-rate\)/);
  assert.match(source, /state\.active\+=1/);
  const config = read('game/config.mjs').split('\n').find(line => line.includes("id:'assault'"));
  assert.match(config, /fragLimit:3,minFragLimit:1,maxFragLimit:9/);
  assert.doesNotMatch(config, /vehicles:false/);
  assert.match(read('game/core.mjs'), /vehiclesEnabled=modeRule\(this\.config\.mode\)\.vehicles!==false/);
  const maps = read('game/destination-objective-maps.mjs');
  assert.match(maps, /ctx\.addVehicle\(vehicle\(`tidal-/);
  assert.match(maps, /ctx\.addVehicle\(vehicle\(`sunscar-/);
});

test('native composition consumes authority and preserves vehicle support', () => {
  assert.match(demo, /extends "res:\/\/world\/session.gd"/);
  assert.match(demo, /MAPS := \["tidal-citadel", "sunscar-convoy"\]/);
  for (const field of ['"mode":"assault"', '"botCount":selected_bot_count', '"timeLimit":round_seconds', '"fragLimit":sector_count']) assert.ok(demo.includes(field));
  assert.match(demo, /fleet\.apply_state\(frame\.state, client\.actor_id\)/);
  assert.match(demo, /VehicleLease\.vehicle_for/);
  assert.doesNotMatch(demo, /VehicleLease\.permitted|"vehicles"\s*:\s*false/);
  assert.match(demo, /vehicle_controls\.command/);
  assert.match(demo, /chase\.follow/);
  assert.match(demo, /snapshot_watch\.age > 10/);
});

test('projection requires wire fields without requiring contested or advancing local capture', () => {
  for (const field of ['"x"', '"y"', '"z"', '"radius"', '"owner"', '"captureTeam"', '"progress"', '"captureSeconds"']) assert.ok(state.includes(field));
  assert.doesNotMatch(state, /get\("contested"\)|has\("contested"\)|func _process|progress\s*[+\-]=|winner\s*=(?!=)/);
  for (const boundary of ['on_started', 'on_error', 'on_transport_dropped', 'on_reconnect_outcome']) assert.match(demo, new RegExp(`func ${boundary}[^]*?clear_assault\\(\\)`));
  assert.match(demo, /client\.results\.connect\(on_results\)/);
  assert.match(demo, /func _request_restart\(\)[^]*?super\._request_restart/);
});

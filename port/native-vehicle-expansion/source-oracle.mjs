// Deterministic source-only fixture. This directly steps Match; it is NOT a
// network/client acceptance test. Actor placement is deliberately arranged.
import assert from 'node:assert/strict';
import {Match} from '../../game/core.mjs';
import {VEHICLE_TYPES, vehicleMuzzleCount, vehicleSeatFor} from '../../game/vehicles.mjs';

const kinds = ['puma', 'hornet', 'titan', 'scout', 'transport'];
assert.deepEqual(VEHICLE_TYPES.map(v => v.id), kinds);
const match = new Match('chatgpt', 'openclaw', () => 0.5, 'sunscar-convoy',
  {mode:'combined-arms', botCount:0, humanCount:2, skipNav:true});
assert.equal(match.config.mode, 'combined-arms');
assert.equal(match.config.fragLimit, 200);
assert.equal(match.objectiveState.kind, 'domination');
assert.deepEqual([...new Set(match.vehicles.map(v => v.kind))].sort(), [...kinds].sort());
for (const vehicle of match.vehicles) {
  const def = VEHICLE_TYPES.find(v => v.id === vehicle.kind);
  assert.equal(vehicle.maxHealth, def.health);
  assert.equal(vehicleMuzzleCount(vehicle), def.muzzles.length);
  assert.equal(vehicleSeatFor(vehicle)?.role, 'driver');
}

const samples = [];
for (const kind of kinds) {
  const m = new Match('chatgpt', 'openclaw', () => 0.5, 'sunscar-convoy',
    {mode:'combined-arms', botCount:0, humanCount:2, skipNav:true});
  const v = m.vehicles.find(x => x.kind === kind);
  assert(v);
  const [driver, gunner] = m.actors;
  // Controlled fixture placement near the selected vehicle: no claim that a
  // naturally spawned client can reach this seat in the same amount of time.
  for (const a of [driver, gunner]) Object.assign(a, {x:v.position.x, y:v.position.y, z:v.position.z});
  assert(m.enterVehicle(driver));
  assert.equal(driver.vehicleId, v.id);
  assert.equal(driver.vehicleSeat, 'driver');
  assert.equal(v.driver, driver.id); // actor 0 is a valid occupant.
  assert(m.enterVehicle(gunner));
  const expected = kind === 'scout' ? 'passenger' : 'gunner';
  assert.equal(gunner.vehicleSeat, expected);
  const before = {x:v.position.x, z:v.position.z, y:v.position.y};
  const steering = {x:-Math.sin(driver.yaw), z:-Math.cos(driver.yaw),
    yaw:driver.yaw, pitch:0, sprint:true, fire:kind === 'scout'};
  for (let i=0; i<90; i++) m.step(1/60, {inputs:{0:steering, 1:{yaw:gunner.yaw, pitch:0, fire:true}}});
  const moved = Math.hypot(v.position.x-before.x, v.position.z-before.z);
  assert(moved > 0.01, `${kind} controlled driver fixture did not move`);
  const events = m.events.filter(e => e.type === 'vehicle-shot');
  if (kind !== 'scout') assert(events.some(e => e.actor === gunner.id && e.vehicle === v.id), `${kind} gunner did not fire`);
  samples.push({kind, id:v.id, driver:driver.id, secondRole:expected,
    moved, shotEvents:events.length, altitude:v.position.y});
  m.releaseVehicle(gunner, v);
  assert.equal(gunner.vehicleId, null);
  m.damageVehicle(v, v.maxHealth+100, null);
  assert.equal(v.health, 0);
  assert.equal(driver.vehicleId, null);
  for (let i=0; i<Math.ceil((v.config.respawn+0.1)*60); i++) m.step(1/60, {inputs:{}});
  assert.equal(v.health, v.maxHealth);
}
console.log('VEHICLE_SOURCE_ORACLE '+JSON.stringify({classification:'arranged direct Match fixture, not Room wire', samples}));

// Unit contract for the port-only debug reconciliation module. The socket-level
// proof that a REAL authority applies these frames lives in
// port/native-arenas/tests/debug.test.mjs and port/native-horde/debug.test.mjs.
import test from 'node:test';
import assert from 'node:assert/strict';
import {DIFFICULTIES, mutatorEffects, normalizeConfig} from '../../game/config.mjs';
import {applyDebugFrame, applyLiveOverrides, createDebugState, debugEcho,
  installHumanGuard, parseDebugFrame, reconcileHuman, restoreSpawnAmmo, DEBUG_DIFFICULTIES,
  DEBUG_FIELDS, HUMAN_SEAT} from './debug.mjs';

const actor = (id, over = {}) => ({id, health:100, maxHealth:100, armor:25, spawnArmor:25, dead:0,
  temporaryShield:0, juggernautShield:0, ammo:[Infinity, 0, 0, 0, 0, 0, 0, 0, 0, 0], weapon:0, ...over});

function fakeMatch(overrides = {}) {
  const match = {
    config:normalizeConfig({mode:'deathmatch', botCount:1, ...overrides}),
    mutators:null, difficulty:null,
    actors:[actor(HUMAN_SEAT), actor(1)],
    calls:[],
    damage(target, amount) { match.calls.push({id:target.id, amount}); return amount; },
    startingLoadout() { return {weapon:0, ammo:[Infinity, 0, 0, 0, 0, 0, 0, 0, 0, 0]}; },
    weaponForIndex() { return {ammo:30, cap:120}; },
  };
  match.mutators = mutatorEffects(match.config);
  match.difficulty = DIFFICULTIES.find(entry => entry.id === match.config.difficulty);
  return match;
}

test('debug frame validation refuses unknown, malformed, unbounded and prototype keys', () => {
  const valid = {type:'debug', v:1, godMode:true, damage:2, difficulty:'hard', respawn:4.5,
    unlockAllWeapons:true, playerIncomingScale:.5, testDamage:40, botCount:4, startingWeapon:9,
    oneShot:false, speed:1.25, gravity:.4};
  assert.deepEqual(Object.keys(parseDebugFrame(valid).set).sort(), Object.keys(valid)
    .filter(key => !['type', 'v'].includes(key)).sort());
  assert.equal(parseDebugFrame({type:'debug', v:1}).clear, false);
  assert.equal(parseDebugFrame({type:'debug', v:1, clear:true}).clear, true);
  for (const frame of [null, [], 'debug', 3, {type:'debug'}, {type:'debug', v:2}, {type:'other', v:1},
    {type:'debug', v:1, mapId:'prism-foundry'}, {type:'debug', v:1, path:'/etc/passwd'},
    {type:'debug', v:1, url:'ws://evil'}, {type:'debug', v:1, __proto__:{godMode:true}},
    {type:'debug', v:1, constructor:'x'}, {type:'debug', v:1, damage:.75}, {type:'debug', v:1, damage:3},
    {type:'debug', v:1, damage:'2'}, {type:'debug', v:1, damage:Infinity}, {type:'debug', v:1, damage:NaN},
    {type:'debug', v:1, speed:1.1}, {type:'debug', v:1, gravity:0},
    {type:'debug', v:1, difficulty:'impossible'}, {type:'debug', v:1, difficulty:1},
    {type:'debug', v:1, respawn:.5}, {type:'debug', v:1, respawn:6}, {type:'debug', v:1, respawn:'2'},
    {type:'debug', v:1, godMode:1}, {type:'debug', v:1, godMode:'yes'}, {type:'debug', v:1, oneShot:0},
    {type:'debug', v:1, botCount:8.5}, {type:'debug', v:1, botCount:-1}, {type:'debug', v:1, botCount:9},
    {type:'debug', v:1, startingWeapon:10}, {type:'debug', v:1, startingWeapon:'9'},
    {type:'debug', v:1, playerIncomingScale:.1}, {type:'debug', v:1, playerIncomingScale:5},
    {type:'debug', v:1, testDamage:-1}, {type:'debug', v:1, testDamage:1e9},
    {type:'debug', v:1, clear:'yes'}]) {
    assert.throws(() => parseDebugFrame(frame), TypeError, JSON.stringify(frame));
  }
  // Every refused key is outside the published field list.
  for (const key of ['map', 'mapId', 'path', 'url', 'actor', 'target', 'seed', 'teleport', 'spawn']) {
    assert.ok(!DEBUG_FIELDS.includes(key));
  }
  assert.deepEqual(DEBUG_DIFFICULTIES, ['easy', 'normal', 'hard', 'nightmare']);
});

test('debug state partitions live, queued and port-only knobs; clear resets all', () => {
  const state = createDebugState({enabled:true});
  const touched = applyDebugFrame(state, parseDebugFrame({type:'debug', v:1, godMode:true,
    playerIncomingScale:.5, unlockAllWeapons:true, damage:2, botCount:5, startingWeapon:3,
    testDamage:40, difficulty:'nightmare'}));
  assert.deepEqual(touched.sort(), ['botCount', 'damage', 'difficulty', 'godMode',
    'playerIncomingScale', 'startingWeapon', 'testDamage', 'unlockAllWeapons']);
  assert.deepEqual(state.queued, {botCount:5, startingWeapon:3});
  assert.deepEqual(state.live, {godMode:true, playerIncomingScale:.5, unlockAllWeapons:true});
  assert.deepEqual(state.config, {damage:2, difficulty:'nightmare', unlimitedAmmo:true});
  assert.equal(state.autoUnlimited, true);
  // testDamage is an action, never stored.
  assert.equal(Object.hasOwn(state.config, 'testDamage'), false);
  applyDebugFrame(state, parseDebugFrame({type:'debug', v:1, clear:true}));
  assert.deepEqual(state.live, {godMode:false, playerIncomingScale:1, unlockAllWeapons:false});
  assert.deepEqual(state.config, {}); assert.deepEqual(state.queued, {});
  assert.equal(state.autoUnlimited, false);
  // Unlock-all releases only the unlimited ammo flag it set itself.
  const owned = createDebugState({enabled:true});
  applyDebugFrame(owned, parseDebugFrame({type:'debug', v:1, unlockAllWeapons:true}));
  applyDebugFrame(owned, parseDebugFrame({type:'debug', v:1, unlockAllWeapons:false}));
  assert.deepEqual(owned.config, {});
  const separate = createDebugState({enabled:true});
  applyDebugFrame(separate, parseDebugFrame({type:'debug', v:1, unlimitedAmmo:true}));
  applyDebugFrame(separate, parseDebugFrame({type:'debug', v:1, unlockAllWeapons:true}));
  applyDebugFrame(separate, parseDebugFrame({type:'debug', v:1, unlockAllWeapons:false}));
  assert.deepEqual(separate.config, {unlimitedAmmo:true});
});

test('live config overrides rebuild from the reviewed base and restore on clear', () => {
  const base = {mode:'deathmatch', botCount:1, damage:1, speed:1, gravity:1, difficulty:'easy'};
  const match = fakeMatch({});
  assert.equal(applyLiveOverrides(match, {damage:2, speed:1.25, gravity:.4, difficulty:'nightmare'}, base), true);
  assert.equal(match.config.damage, 2);
  assert.equal(match.mutators.damageMultiplier, 2);
  assert.equal(match.mutators.speedMultiplier, 1.25);
  assert.equal(match.mutators.gravityMultiplier, .4);
  assert.equal(match.difficulty.id, 'nightmare');
  assert.ok(match.config.mutators.includes('doubleDamage'));
  // Clearing uses the base, not the mutated config: no frozen debug values.
  applyLiveOverrides(match, {}, base);
  assert.equal(match.config.damage, 1); assert.equal(match.mutators.damageMultiplier, 1);
  assert.equal(match.config.speed, 1); assert.equal(match.difficulty.id, 'easy');
});

test('human guard scales and caps only the human seat; bots pass through untouched', () => {
  const live = {godMode:false, playerIncomingScale:1, unlockAllWeapons:false};
  const match = fakeMatch({});
  assert.equal(installHumanGuard(match, live, HUMAN_SEAT), true);
  assert.equal(installHumanGuard(match, live, HUMAN_SEAT), false, 'guard installs once');
  match.damage(match.actors[1], 50, undefined);
  match.damage(match.actors[0], 50, undefined);
  assert.deepEqual(match.calls, [{id:1, amount:50}, {id:0, amount:50}]);
  live.playerIncomingScale = .5;
  match.calls = [];
  match.damage(match.actors[0], 40, undefined);
  match.damage(match.actors[1], 40, undefined);
  assert.deepEqual(match.calls, [{id:0, amount:20}, {id:1, amount:40}]);
  live.playerIncomingScale = 1; live.godMode = true;
  match.calls = [];
  match.actors[0].health = 10; match.actors[0].armor = 0;
  match.damage(match.actors[0], 10000, undefined);
  match.damage(match.actors[1], 10000, undefined);
  assert.deepEqual(match.calls, [{id:0, amount:9}, {id:1, amount:10000}], 'lethal damage stops one point short');
});

test('post-step reconcile restores the human seat, clears death and grants the ammo belt', () => {
  const match = fakeMatch({});
  assert.equal(reconcileHuman(match, createDebugState()), null, 'disabled state is inert');
  const state = createDebugState({enabled:true});
  state.live.godMode = true;
  match.actors[0].health = 0; match.actors[0].dead = 2;
  match.actors[1].health = 0;
  const report = reconcileHuman(match, state);
  assert.equal(report.restoredDeath, true);
  assert.equal(match.actors[0].health, match.actors[0].maxHealth);
  assert.equal(match.actors[0].dead, 0);
  assert.equal(state.restores, 1);
  assert.equal(match.actors[1].health, 0, 'bots are never reconciled');
  state.live.unlockAllWeapons = true;
  match.actors[0].ammo = [3, 0, 1, 0, 0, 0, 0, 0, 0, 0];
  assert.equal(reconcileHuman(match, state).grantedAmmo, true);
  assert.ok(match.actors[0].ammo.every(value => value === Infinity));
  assert.deepEqual(match.actors[1].ammo, [Infinity, 0, 0, 0, 0, 0, 0, 0, 0, 0], 'bot belt untouched');
  // Reversibility: revoke restores the source spawn belt, held weapon loaded.
  match.actors[0].weapon = 3;
  match.actors[0].ammo = Array.from({length:10}, () => Infinity);
  restoreSpawnAmmo(match, match.actors[0]);
  assert.deepEqual(match.actors[0].ammo, [Infinity, 0, 0, 30, 0, 0, 0, 0, 0, 0]);
});

test('debug echo publishes live, queued and route restart bounds', () => {
  const state = createDebugState({enabled:true});
  applyDebugFrame(state, parseDebugFrame({type:'debug', v:1, godMode:true, botCount:4}));
  const echo = debugEcho(state, {botCount:[1, 7], startingWeapon:[0, 9]});
  assert.equal(echo.enabled, true); assert.equal(echo.version, 1);
  assert.equal(echo.live.godMode, true);
  assert.deepEqual(echo.queued, {botCount:4});
  assert.deepEqual(echo.restart, {botCount:[1, 7], startingWeapon:[0, 9]});
  assert.equal(debugEcho(createDebugState()).restart !== undefined, true);
  assert.deepEqual(debugEcho(createDebugState()).restart, {});
});

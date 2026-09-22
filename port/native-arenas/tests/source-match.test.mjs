import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match, floorAt} from '../../../game/core.mjs';
import {MAPS, getMap} from '../../../game/maps.mjs';
import {createNativeMatch} from '../match.mjs';
import {EventCursor} from '../event-cursor.mjs';
import {syntheticArena, seededRandom, aimedControls} from './fixtures.mjs';

test('source constructor seam is assignment before nav/spawns/actors, not options.arena', () => {
  const source = readFileSync(new URL('../../../game/core.mjs', import.meta.url), 'utf8');
  const constructor = source.slice(source.indexOf("constructor(character="), source.indexOf('initializeRace(){'));
  assert.ok(constructor.includes('this.arena=getMap(mapId)'));
  assert.ok(!constructor.includes('options.arena'));
  assert.ok(constructor.indexOf('this.arena=getMap(mapId)') < constructor.indexOf('matchNavigation(this.arena'));
  assert.ok(constructor.indexOf('matchNavigation(this.arena') < constructor.indexOf('this.actors=['));
});
test('SYNTHETIC: constructor initializes native nav/spawns/pickups/actors; source registry is untouched', () => {
  const registry = MAPS.slice(), fallback = getMap('prism-foundry');
  const data = syntheticArena();
  const match = createNativeMatch({arenaData:data, random:seededRandom()});
  assert.ok(match instanceof Match); assert.equal(match.humanCount, 1);
  assert.equal(match.actors.length, 4); assert.equal(match.actors[0].bot, null);
  assert.ok(match.actors.slice(1).every(a => a.bot));
  assert.equal(match.arena.id, 'prism-foundry'); assert.notEqual(match.arena, fallback);
  assert.equal(match.snapshot().mapId, 'prism-foundry');
  assert.equal(match.snapshot().singleplayer, null);
  assert.ok(match.nav.length > 0); assert.ok(match.edges.some(edges => edges.length > 0));
  assert.ok(match.nav.every(p => p.y === 4));
  assert.ok(match.spawns.every(p => p.y === 4));
  assert.ok(match.pickups.every(p => p.y === 4));
  for (const a of match.actors) {
    assert.equal(a.y, floorAt(a.x, a.z, match.arena));
    assert.ok(match.spawns.some(p => p.x === a.x && p.z === a.z));
  }
  assert.deepEqual(MAPS, registry); assert.equal(getMap('prism-foundry'), fallback);
  assert.equal(data.arena.terrain.surfaces[0].vertices[0][1], 4);
  assert.throws(() => match.arena = fallback, /reassignment/);
  assert.equal(match.step, Match.prototype.step); assert.equal(match.snapshot, Match.prototype.snapshot);
  assert.equal(match.damage, Match.prototype.damage); assert.equal(match.spawn, Match.prototype.spawn);
});
test('SYNTHETIC: ordinary player input causes source damage, kills, frags, bot navigation and results', () => {
  const match = createNativeMatch({arenaData:syntheticArena(), random:seededRandom(42),
    config:{difficulty:'easy', fragLimit:5, timeLimit:60}});
  const cursor = new EventCursor(), events = cursor.take(match);
  const initial = match.actors.map(a => ({x:a.x, z:a.z}));
  let moved = false, routed = false, ads = false;
  for (let tick = 0; tick < 61 * 60 && !match.over; tick++) {
    match.step(1 / 60, {inputs:{0:aimedControls(match)}});
    events.push(...cursor.take(match));
    ads ||= match.snapshot().actors[0].ads === true;
    moved ||= match.actors.slice(1).some(a => Math.hypot(a.x - initial[a.id].x, a.z - initial[a.id].z) > 2);
    routed ||= match.actors.slice(1).some(a => a.bot.route.length > 0);
  }
  assert.ok(ads); assert.ok(moved); assert.ok(routed);
  assert.ok(events.some(e => e.type === 'damage' && e.source === 0 && e.amount > 0));
  assert.ok(match.actors[0].frags > 0, 'player scored a legitimate source frag');
  assert.ok(match.actors.slice(1).some(a => a.shots > 0), 'source bots fired weapons');
  assert.ok(match.stats.kills > 0); assert.ok(match.over); assert.ok(match.snapshot().leaders.length);
  assert.ok(events.some(e => e.type === 'death' && e.killer === 0));
  assert.equal(new Set(events.map(e => e.id)).size, events.length);
  assert.ok(events.every(e => Number.isSafeInteger(e.id) && e.id > 0));
});
test('SYNTHETIC: source bot attacks kill idle player and source respawn restores control', () => {
  const match = createNativeMatch({arenaData:syntheticArena(), random:seededRandom(7),
    config:{difficulty:'nightmare', fragLimit:50, timeLimit:60}});
  const cursor = new EventCursor(); cursor.take(match);
  let death = false, respawn = false, botDamage = false;
  for (let tick = 0; tick < 60 * 60 && !match.over && !respawn; tick++) {
    match.step(1 / 60, {inputs:{0:{}}});
    for (const event of cursor.take(match)) {
      botDamage ||= event.type === 'damage' && event.actor === 0 && event.source > 0 && event.amount > 0;
      respawn ||= death && event.type === 'spawn' && event.actor === 0;
    }
    death ||= match.actors[0].health <= 0;
  }
  assert.ok(botDamage); assert.ok(death); assert.ok(respawn);
  assert.ok(match.actors[0].deaths > 0); assert.ok(match.actors[0].health > 0);
  match.step(1 / 60, {inputs:{0:{ads:true}}});
  assert.equal(match.snapshot().actors[0].ads, true);
  match.step(1 / 60, {inputs:{0:{ads:false}}});
  assert.equal(match.snapshot().actors[0].ads, false);
});

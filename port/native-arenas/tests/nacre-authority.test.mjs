// This must load the shipped Horde-authored recipe, not the synthetic DM fixture.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {floorAt, obstructed} from '../../../game/core.mjs';
import {parseIdentityArena, nativeArenaGeometryHash} from '../schema.mjs';
import {createNativeArenaAuthority} from '../authority.mjs';
import {connect} from './socket-helper.mjs';

const recipe = JSON.parse(readFileSync(new URL('../../../godot/identity_maps/generated/nacre-engine.json', import.meta.url), 'utf8'));

test('committed Nacre recipe preserves canonical geometry and strictly validates Horde metadata for DM', () => {
  const data = parseIdentityArena(recipe, 'nacre-engine');
  assert.deepEqual(data, recipe);
  assert.equal(nativeArenaGeometryHash(data.arena), recipe.geometryHash);
  assert.equal(data.arena.teamSpawns[0].length, 1);
  assert.ok(data.arena.pickups.some(p => p[0] === 'megahealth'));
  const reject = (edit, reason) => {
    const changed = structuredClone(recipe);
    edit(changed);
    changed.geometryHash = nativeArenaGeometryHash(changed.arena);
    assert.throws(() => parseIdentityArena(changed, 'nacre-engine'), reason);
  };
  reject(d => { d.arena.singleplayer = {}; }, /arena fields/);
  reject(d => { d.arena.hordeCaches[0].unknown = true; }, /horde cache/);
  reject(d => { d.arena.hordeCaches[1].pickupId = d.arena.hordeCaches[0].pickupId; }, /horde cache id/);
  reject(d => { d.arena.hordeCaches[0].wave = 31; }, /horde cache wave/);
  reject(d => { d.arena.hordeCaches[0].zone = '../cache'; }, /horde cache zone/);
  reject(d => { d.arena.hordeCaches[0].pickupId = 0; }, /horde cache weapon/);
  reject(d => { d.arena.teamSpawns[0] = []; }, /teamSpawns/);
  reject(d => { d.arena.teamSpawns[0][0] = [100, 100]; }, /teamSpawns/);
  reject(d => { d.mode = 'deathmatch'; }, /arena fields/);
  reject(d => { d.arena.pickups[0][0] = 'unknown'; }, /pickup kind/);
});

test('committed Nacre DM authority: readiness, real room host/start and source snapshot', {timeout:60000}, async t => {
  const authority = await createNativeArenaAuthority({host:'127.0.0.1', port:0,
    mapId:'nacre-engine', mode:'deathmatch', bots:1, roundSeconds:60, fragLimit:5, debug:false});
  t.after(() => authority.close());
  const ready = await (await fetch(`http://127.0.0.1:${authority.port}/`)).json();
  assert.equal(ready.mapId, recipe.id);
  assert.equal(ready.geometryHash, recipe.geometryHash);
  const client = await connect(authority.endpoint);
  t.after(() => client.ws.terminate());
  client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
  const welcome = await client.wait(f => f.type === 'welcome');
  assert.equal(welcome.geometryHash, recipe.geometryHash);
  await client.wait(f => f.type === 'lobby');
  client.send({type:'host', mapId:recipe.id, config:{mode:'deathmatch', botCount:1, timeLimit:60, fragLimit:5}});
  const lobby = await client.wait(f => f.type === 'lobby' && f.config);
  assert.equal(lobby.mapId, recipe.id);
  assert.equal(lobby.config.mode, 'deathmatch');
  client.send({type:'start'});
  const initial = await client.wait(f => f.type === 'snapshot', {timeout:50000});
  assert.equal(initial.state.mapId, recipe.id);
  assert.equal(initial.state.actors.length, 2);
  assert.equal(initial.state.singleplayer, null);
  assert.equal(initial.state.over, false);
  for (const actor of initial.state.actors) {
    assert.ok(Number.isFinite(actor.y));
    assert.ok(Number.isFinite(floorAt(actor.x, actor.z, recipe.arena)));
    assert.equal(obstructed(actor.x, actor.y, actor.z, undefined, recipe.arena), false);
  }
  // Horde cache gating must not leak into the source Deathmatch pickups.
  assert.equal(initial.state.pickups.length, recipe.arena.pickups.length);
  assert.ok(initial.state.pickups.some(p => p.kind === 'megahealth'));
  for (const cache of recipe.arena.hordeCaches) {
    assert.equal(initial.state.pickups[cache.pickupId].wait, 0);
  }
  assert.equal(client.frames.some(f => f.type === 'error'), false);
});

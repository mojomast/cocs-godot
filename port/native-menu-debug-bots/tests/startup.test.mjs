import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {normalizeConfig} from '../../../game/config.mjs';
import {MAX_ACTORS, floorAt, obstructed} from '../../../game/core.mjs';
import {createNativeMatch, validateNativeConfig} from '../../native-arenas/match.mjs';
import {createIdentityZoneMatch, validateIdentityZoneConfig} from '../../native-identity-zones/match.mjs';
import {applyLiveOverrides} from '../../native-debug/debug.mjs';
import {parseLocalDebugFrame} from '../debug-frame.mjs';

test('local bot debug extension retains the shared plain-envelope gate', () => {
  const impostor = Object.assign(new Date(), {type:'debug', v:1, botCount:24});
  assert.throws(() => parseLocalDebugFrame(impostor, [1, 24]), /object envelope/);
  assert.throws(() => parseLocalDebugFrame(Object.assign([], {type:'debug', v:1, botCount:24}), [1, 24]), /object envelope/);
  assert.equal(parseLocalDebugFrame({type:'debug', v:1, botCount:24}, [1, 24]).set.botCount, 24);
});

test('24 genuine source bot seats start on both reviewed local routes, supported and separated', () => {
  assert.equal(MAX_ACTORS, 32);
  assert.equal(normalizeConfig({mode:'deathmatch', botCount:24}).botCount, 8);
  assert.equal(normalizeConfig({mode:'domination', botCount:24}).botCount, 8);
  for (const [label, validate, create] of [
    ['deathmatch', validateNativeConfig, createNativeMatch],
    ['domination', validateIdentityZoneConfig, createIdentityZoneMatch],
  ]) {
    assert.equal(validate({botCount:24}).botCount, 24, label);
    assert.throws(() => validate({botCount:25}), /botCount/);
    const match = create({config:{botCount:24}});
    assert.equal(match.config.botCount, 24);
    assert.equal(match.humanCount, 1);
    assert.equal(match.actors.length, 25);
    assert.equal(match.actors[0].bot, null);
    assert.ok(match.actors.slice(1).every(actor => actor.bot !== null));
    for (const [index, actor] of match.actors.entries()) {
      assert.equal(actor.id, index);
      assert.equal(actor.y, floorAt(actor.x, actor.z, match.arena));
      assert.equal(obstructed(actor.x, actor.y, actor.z, undefined, match.arena), false);
      for (const other of match.actors.slice(0, index)) {
        assert.ok(Math.hypot(actor.x-other.x, actor.z-other.z) >= 1.24,
          `${label}: seats ${index} and ${other.id} overlap`);
      }
    }
    const snapshot = match.snapshot();
    assert.equal(snapshot.actors.length, 25);
    assert.ok(Buffer.byteLength(JSON.stringify({type:'snapshot', state:snapshot})) < 1048576);
    const base = {...match.config};
    assert.equal(applyLiveOverrides(match, {difficulty:'hard'}, base), true);
    assert.equal(match.actors.length, 25);
    assert.equal(match.snapshot().config.botCount, 24);
    assert.equal(match.config.difficulty, 'hard');
  }
});

test('live debug config reassignment preserves small rosters on both routes', () => {
  for (const create of [createNativeMatch, createIdentityZoneMatch]) {
    const match = create({config:{botCount:3}});
    assert.equal(applyLiveOverrides(match, {difficulty:'nightmare'}, {...match.config}), true);
    assert.equal(match.config.botCount, 3);
    assert.equal(match.actors.length, 4);
    assert.equal(match.config.difficulty, 'nightmare');
  }
});

test('native interactive setup exposes the same 24-seat limit as its authority', () => {
  const dm = readFileSync(new URL('../../../godot/native_arenas/demo.gd', import.meta.url), 'utf8');
  const hud = readFileSync(new URL('../../../godot/native_arenas/hud.gd', import.meta.url), 'utf8');
  assert.match(hud, /bots\.max_value = 24/);
  assert.match(dm, /native_hud\.configure\(self\)/);
  const zones = readFileSync(new URL('../../../godot/native_arenas/identity_zone_demo.gd', import.meta.url), 'utf8');
  assert.match(zones, /const BOT_RANGE := Vector2i\(0, 24\)/);
  assert.match(zones, /auto_start = options.autostart/);
  assert.match(zones, /if auto_start: launch_match\(MAP_ID, "Operator", bot_count, round_seconds, score_limit\)/);
});

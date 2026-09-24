import test from 'node:test';
import assert from 'node:assert/strict';
import {parseDebugFrame} from '../../native-debug/debug.mjs';
import {parseLocalDebugFrame} from '../debug-frame.mjs';
import {createNativeArenaAuthority} from '../../native-arenas/authority.mjs';
import {createIdentityZoneAuthority} from '../../native-identity-zones/authority.mjs';
import {connect} from '../../native-identity-zones/tests/socket.mjs';

test('local debug parser extends only bot count and rejects malformed counts', () => {
  assert.throws(() => parseDebugFrame({type:'debug', v:1, botCount:24}), /botCount/);
  for (const range of [[1,24], [0,24]]) {
    assert.deepEqual(parseLocalDebugFrame({type:'debug', v:1, botCount:24, difficulty:'hard'}, range).set,
      {difficulty:'hard', botCount:24});
    for (const botCount of [25, -1, 2.5, '24', null]) {
      assert.throws(() => parseLocalDebugFrame({type:'debug', v:1, botCount}, range), /botCount/);
    }
    assert.throws(() => parseLocalDebugFrame({type:'debug', v:2, botCount:24}, range), /protocol/);
    assert.throws(() => parseLocalDebugFrame({type:'debug', v:1, botCount:24, bogus:true}, range), /unsupported field/);
  }
});

test('local authority debug queues 24, starts 25 actual seats, retains live override and rejects 25',
  {timeout:30000}, async () => {
    for (const [factory, mapId, mode, min] of [
      [createNativeArenaAuthority, 'prism-foundry', 'deathmatch', 1],
      [createIdentityZoneAuthority, 'vermilion-fold', 'domination', 0],
    ]) {
      const authority = await factory({port:0, host:'127.0.0.1', debug:true});
      try {
        const client = await connect(authority.endpoint);
        try {
          client.send({type:'create', v:3, delta:0, nativeArenaInput:1});
          await client.wait(f => f.type === 'welcome');
          const lobby = await client.wait(f => f.type === 'lobby');
          assert.deepEqual(lobby.debug.restart.botCount, [min,24]);
          client.send({type:'host', mapId, config:{mode, botCount:min, timeLimit:60,
            fragLimit:mode === 'deathmatch' ? 15 : 100, difficulty:'normal'}});
          await client.wait(f => f.type === 'lobby' && f.config);
          client.send({type:'debug', v:1, botCount:25});
          await client.wait(f => f.type === 'debug-reject' && /botCount/.test(f.reason));
          client.send({type:'debug', v:1, botCount:24});
          await client.wait(f => f.type === 'debug-state' && f.debug.queued.botCount === 24);
          client.send({type:'start'});
          const snapshot = await client.wait(f => f.type === 'snapshot' && f.state.actors.length === 25);
          assert.equal(snapshot.state.config.botCount, 24);
          assert.ok(snapshot.state.actors.slice(1).every(actor => actor.bot));
          client.send({type:'debug', v:1, difficulty:'hard'});
          await client.wait(f => f.type === 'debug-state' && f.debug.live.difficulty === 'hard');
          const updated = await client.wait(f => f.type === 'snapshot' &&
            f.state.config.difficulty === 'hard' && f.state.config.botCount === 24);
          assert.equal(updated.state.actors.length, 25);
        } finally { client.ws.terminate(); }
      } finally { await authority.close(); }
    }
  });

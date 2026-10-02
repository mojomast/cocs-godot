import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, rmSync, readFileSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {ProgressionStore} from '../../../server/progression.mjs';
import {RoomRegistry} from '../../../server/rooms.mjs';
import {MatchHistory} from '../../../server/history.mjs';
import {awardMatch} from '../../../game/progression.mjs';
import {applyMatchAll, normalizeChallengeState, currentDaySeed, currentWeekSeed} from '../../../game/challenges.mjs';
import {installChallenges} from './challenge-authority.mjs';

const now = () => Date.UTC(2026, 9, 2);
function authority(file = null) {
  const progression = new ProgressionStore(file);
  const history = new MatchHistory();
  const registry = new RoomRegistry({progression, history, random: () => .5});
  return installChallenges({progression, registry, history}, {now});
}

test('source rounds -> challenge bonus -> unlock -> atomic reload -> new rounds, with no duplicate settlement', async () => {
  const dir = mkdtempSync('/tmp/opencode/challenges-');
  try {
    const file = join(dir, 'career.json');
    let game = authority(file);
    const identity = game.progression.identify('challenge-player-0001');
    const id = identity.profile.id, token = identity.token;
    let expected = identity.profile;
    let state = normalizeChallengeState({}, currentDaySeed(now()), currentWeekSeed(now()));
    let bonuses = 0, unlocks = 0;
    for (let session = 0; session < 2; session++) {
      const room = game.registry.create('Challenge journey');
      room.join(1, 'Player', 'chatgpt', 'openclaw', '', false, id, token);
      room.host(1, {mode: 'juggernaut', botCount: 0, timeLimit: 60, fragLimit: 30}, 'meridian-exchange');
      for (let round = 0; round < 6; round++) {
        if (session === 0 && round === 2) {
          const equipped = game.progression.setGearOwned(id, token, {primary:'scope'}, {}, null);
          assert.equal(equipped.gear.primary, 'scope', 'earned unlock uses unchanged source equipment authority');
          expected = {...expected, gear:equipped.gear, attachments:equipped.attachments, finish:equipped.finish};
          assert.equal(game.progression.setGearOwned(id, 'invalid-token', {}, {}, null), null);
        }
        room.start(1); room.drain();
        // Accelerated wall clock, ordinary untouched 1/60 source steps. No
        // actor positioning, reward seeding, stat mutation or forced result.
        for (let tick = 0; tick < 3700 && !room.roundOver; tick++) room.tick(1 / 60);
        assert.equal(room.roundOver, true);
        const messages = room.drain().map(entry => entry.msg);
        const awards = messages.filter(frame => frame.type === 'progression');
        assert.equal(awards.length, 1);
        const award = awards[0];
        const result = {win: true, actor: room.lastResult.actors[0], mode: 'juggernaut'};
        const challenge = applyMatchAll(state, {...result, team: false, bestStreak: 0});
        state = challenge.state;
        const source = awardMatch(expected, {...result, bonusXp: challenge.gained, challengesCompleted: challenge.completed.length});
        expected = source.profile;
        assert.equal(award.gained, source.gained);
        assert.equal(award.profile.xp, expected.xp);
        assert.equal(award.profile.matches, expected.matches);
        assert.deepEqual(award.profile.gear, expected.gear);
        assert.equal(award.challengeAward.gained, challenge.gained);
        bonuses += challenge.gained; unlocks += award.unlocked.length;
        assert.equal(game.progression.awardOwned(id, token, result), null, 'same source round cannot settle twice');
        assert.equal(game.progression.awardOwned(id, token, {...result, actor: {...result.actor}}), null, 'copied client result is not source provenance');
        room.tick(1 / 60);
        assert.equal(game.progression.get(id).matches, expected.matches);
        const resume = room.peers.get(1).token;
        room.disconnect(1);
        room.join(2, 'Player', 'chatgpt', 'openclaw', resume);
        const replay = room.drain().map(entry => entry.msg);
        assert.ok(replay.some(frame => frame.type === 'welcome' && frame.reconnected));
        assert.ok(replay.some(frame => frame.type === 'results'));
        assert.equal(replay.filter(frame => frame.type === 'progression').length, 0);
        room.disconnect(2);
        room.join(1, 'Player', 'chatgpt', 'openclaw', resume);
        room.drain();
        assert.equal(await game.progression.whenPersisted(), true);
        const disk = JSON.parse(readFileSync(file));
        assert.equal(disk.players[0].xp, expected.xp);
        assert.deepEqual(disk.players[0].portChallenges, state);
      }
      assert.equal(game.history.all().length, 6);
      const previous = game.progression.getOwned(id, token);
      game = authority(file);
      assert.deepEqual(game.progression.getOwned(id, token), previous, 'new authority retains earned rows and XP');
    }
    assert.ok(bonuses > 0, 'actual source rotation pays a bonus');
    assert.ok(unlocks > 0, 'source XP unlocks gear');
    assert.equal(expected.matches, 12);
    console.log(JSON.stringify({matches: expected.matches, xp: expected.xp, bonuses, unlocks}));
  } finally { rmSync(dir, {recursive: true, force: true}); }
});

test('source persistence failure retries the same combined award; UTC rotation never re-awards the old match', async () => {
  const dir = mkdtempSync('/tmp/opencode/challenges-retry-');
  const blocker = join(dir, 'blocked');
  writeFileSync(blocker, 'blocked');
  try {
    const game = authority(join(blocker, 'career.json'));
    const room = game.registry.create('Retry');
    room.join(1, 'Player', 'chatgpt', 'openclaw');
    room.host(1, {mode: 'juggernaut', botCount: 0, timeLimit: 60, fragLimit: 30}, 'meridian-exchange');
    room.start(1); room.drain();
    for (let tick = 0; tick < 3700 && !room.roundOver; tick++) room.tick(1 / 60);
    const award = room.drain().map(entry => entry.msg).find(frame => frame.type === 'progression');
    assert.ok(award);
    assert.equal(await game.progression.whenPersisted(), false);
    const peer = room.peers.get(1);
    const result = {win: true, actor: room.lastResult.actors[0], mode: 'juggernaut'};
    assert.equal(game.progression.awardOwned(peer.playerId, peer.playerToken, result), null);
    rmSync(blocker); game.progression._retryAt = 0;
    assert.equal(await game.progression.flush(), true);
    const fresh = authority(game.progression.file);
    assert.deepEqual(fresh.progression.get(peer.playerId), game.progression.get(peer.playerId));
    const next = {progression: new ProgressionStore(game.progression.file), registry: new RoomRegistry()};
    installChallenges(next, {now: () => now() + 7 * 86400000});
    const rotated = next.progression.get(peer.playerId);
    assert.equal(rotated.xp, award.profile.xp);
    assert.ok(rotated.challenges.daily.every(row => row.progress === 0 && !row.done));
    assert.ok(rotated.challenges.weekly.every(row => row.progress === 0 && !row.done));
  } finally { rmSync(dir, {recursive: true, force: true}); }
});

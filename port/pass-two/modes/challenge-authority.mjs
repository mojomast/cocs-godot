// Port-owned composition of the web application's applyMatchAll -> awardMatch
// contract. The unmodified Room remains the sole caller of settlement. No wire
// verb accepts a result or a reward from a client.
import {readFileSync} from 'node:fs';
import {createGameServer as sourceServer} from '../../../server/game-server.mjs';
import {applyMatchAll, normalizeChallengeState, currentDaySeed, currentWeekSeed, challengeStatus, weeklyStatus} from '../../../game/challenges.mjs';
import {teamMode} from '../../../game/config.mjs';

export function installChallenges(game, {now = Date.now} = {}) {
  const store = game.progression;
  const active = value => normalizeChallengeState(value, currentDaySeed(now()), currentWeekSeed(now()));
  // The source loader deliberately normalizes ordinary profiles. Restore only
  // our namespaced state from that same atomic file; credentials stay source-owned.
  if (store.file) {
    try {
      const raw = JSON.parse(readFileSync(store.file, 'utf8'));
      for (const entry of raw.players ?? []) {
        const profile = store.players.get(entry.id);
        if (profile && entry.portChallenges) profile.portChallenges = active(entry.portChallenges);
      }
    } catch { /* The source loader already handles absent/unreadable stores. */ }
  }
  const clone = store.clone.bind(store);
  store.clone = profile => {
    const copy = clone(profile);
    if (!copy) return copy;
    const state = active(profile.portChallenges);
    delete copy.portChallenges;
    copy.challenges = {version: 1, daySeed: state.daySeed, weekSeed: state.weekSeed,
      daily: challengeStatus(state), weekly: weeklyStatus(state)};
    return copy;
  };
  const awardOwned = store.awardOwned.bind(store);
  const settled = new WeakMap();
  store.awardOwned = (id, token, result) => {
    if (!store.getOwned(id, token)) return null;
    // Exact object provenance from Room's final source snapshot. This also
    // excludes spectators, client-authored objects and unrelated profile writes.
    const room = [...game.registry.rooms.values()].find(room => room.roundOver && room.match?.over &&
      room.lastResult?.actors?.includes(result?.actor) && [...room.peers.values()].some(peer =>
        !peer.spectate && peer.playerId === id && peer.playerToken === token && peer.actorId === result.actor.id));
    if (!room) return null;
    const recipients = settled.get(room.match) ?? new Set();
    if (recipients.has(id)) return null;
    const bestStreak = (room.match.events ?? []).reduce((best, event) =>
      event.type === 'killstreak' && event.actor === result.actor.id ? Math.max(best, Number(event.streak) || 0) : best, 0);
    const challenge = applyMatchAll(active(store.players.get(id).portChallenges),
      {...result, team: teamMode(room.match.config), bestStreak});
    // Hold only the synchronous flush trigger: XP and challenge counters enter
    // the SAME source atomic payload before persistence can observe either.
    const flush = store.flush;
    store.flush = () => {};
    let award;
    try {
      award = awardOwned(id, token, {...result, bonusXp: challenge.gained, challengesCompleted: challenge.completed.length});
      if (!award) return null;
      store.players.get(id).portChallenges = challenge.state;
      recipients.add(id);
      settled.set(room.match, recipients);
      // Weak identity follows the source Match lifetime. A restart creates a
      // new Match; reconnect keeps the old one. No aged-out active receipt.
      award.profile = store.get(id);
      award.challengeAward = {version: 1, gained: challenge.gained,
        completed: challenge.completed.map(({id, label, reward}) => ({id, label, reward}))};
      return award;
    } finally {
      store.flush = flush;
      if (award) store.flush();
    }
  };
  return game;
}

export function createGameServer(options = {}) {
  return installChallenges(sourceServer(options));
}

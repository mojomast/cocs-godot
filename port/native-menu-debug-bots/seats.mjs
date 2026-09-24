// Route-local seat extension. The source config normalizer caps ordinary modes
// at 8 bots; MAX_ACTORS is a separate, source-owned ceiling of 32 actors. Only
// these two single-human local routes opt into the larger (24-bot) roster.
import {MAX_ACTORS, floorAt, obstructed} from '../../game/core.mjs';

export const LOCAL_BOT_MAX = 24;
export function routeBotConfig(normalized, requested) {
  if (!Number.isInteger(requested) || requested < 0 || requested > LOCAL_BOT_MAX ||
      requested + 1 > MAX_ACTORS) throw new TypeError('Unsupported local bot count');
  // Catch a changed source normalizer instead of silently overriding new rules.
  if (normalized.botCount !== Math.min(requested, 8)) throw new Error('Source bot normalization contract drift');
  return {...normalized, botCount:requested};
}

// Source spawn selection predates actor-array assignment in the constructor;
// at 25 seats that puts everyone on the same marker. Spread only crowded local
// rosters onto bounded, walkable locations near their authored spawn anchors.
// The source spawn path still initializes every actor and all respawn state.
export function spreadLocalSpawn(match, actor, anchors) {
  if (match.config.botCount <= 8) return;
  const occupants = match.actors ?? match._initialSeats ?? [];
  const occupied = occupants.filter(other => other !== actor && other.health > 0);
  if (occupied.every(other => Math.hypot(actor.x-other.x, actor.z-other.z) >= 1.25) &&
      (!anchors?.length || anchors.some(([x,z]) => Math.hypot(actor.x-x, actor.z-z) <= 7.5))) {
    if (!match.actors) (match._initialSeats ??= []).push(actor);
    return;
  }
  const origin = anchors?.length ? anchors : [[actor.x, actor.z]];
  let chosen = null;
  // Fixed upper bound, deterministic candidate order; collision-free against
  // the already spawned live roster. Ring extends at most 7.5 map units.
  for (let ring = 1; ring <= 6 && !chosen; ring++) {
    for (let anchor = 0; anchor < origin.length && !chosen; anchor++) {
      const [bx, bz] = origin[(anchor + actor.id) % origin.length];
      for (let spoke = 0; spoke < 24; spoke++) {
        const angle = (spoke + actor.id * 7) * Math.PI / 12;
        const x = bx + Math.cos(angle) * ring * 1.25;
        const z = bz + Math.sin(angle) * ring * 1.25;
        const y = floorAt(x, z, match.arena);
        if (y === null || obstructed(x, y, z, undefined, match.arena)) continue;
        if (occupied.some(other => Math.hypot(x-other.x, z-other.z) < 1.25)) continue;
        chosen = {x, y, z}; break;
      }
    }
  }
  if (!chosen) throw new Error('No collision-free local bot spawn within bounded search');
  Object.assign(actor, chosen, {lastValid:{...chosen}});
  const event = match.events.at(-1);
  if (event?.type === 'spawn' && event.actor === actor.id) event.pos = {x:chosen.x, y:chosen.y+1, z:chosen.z};
  if (!match.actors) (match._initialSeats ??= []).push(actor);
}

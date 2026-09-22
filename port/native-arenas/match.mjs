import {Match, floorAt, obstructed} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
import {CHARACTERS, HARNESSES} from '../../game/data.mjs';
import {nativeArenaEntry} from './catalog.mjs';
import {keys, parseArenaEnvelope, readNativeArena} from './schema.mjs';

export const DEFAULT_NATIVE_CONFIG = Object.freeze({mode:'deathmatch', botCount:3,
  difficulty:'normal', timeLimit:180, fragLimit:15});
export function validateNativeConfig(value = {}) {
  keys(value, ['mode', 'botCount', 'difficulty', 'timeLimit', 'fragLimit'], 'Deathmatch config');
  const config = {...DEFAULT_NATIVE_CONFIG, ...value};
  if (config.mode !== 'deathmatch') throw new TypeError('Native arenas support deathmatch only');
  for (const [key, min, max] of [['botCount', 1, 7], ['timeLimit', 60, 900], ['fragLimit', 5, 50]]) {
    if (!Number.isInteger(config[key]) || config[key] < min || config[key] > max) throw new TypeError(`${key} must be ${min}..${max}`);
  }
  if (!['easy', 'normal', 'hard', 'nightmare'].includes(config.difficulty)) throw new TypeError('Unsupported difficulty');
  return normalizeConfig(config);
}

/** A trusted in-process arenaData override exists for synthetic fixtures only.
 * WebSocket frames never reach it. No source registry or completed Match is
 * transplanted. The local accessor intercepts the source constructor's first
 * `this.arena = getMap(mapId)` BEFORE floor/nav/spawn/actor initialization.
 */
export function createNativeMatch({mapId = 'prism-foundry', config = {}, random = Math.random,
  character = 'chatgpt', harness = 'openclaw', arenaData} = {}) {
  nativeArenaEntry(mapId);
  const options = validateNativeConfig(config);
  if (typeof random !== 'function') throw new TypeError('RNG must be a function');
  if (!CHARACTERS.some(c => c.id === character) || !HARNESSES.some(h => h.id === harness)) throw new TypeError('Unsupported loadout');
  // Both reviewed families run the unmodified source Deathmatch rules against
  // their own spawns/pickups/nav/blocks. Identity maps are constructed through
  // the same scoped accessor; their non-DM recipe mode is metadata, not a gate.
  const data = arenaData === undefined ? readNativeArena(mapId) : parseArenaEnvelope(arenaData, mapId);
  const arena = data.arena;
  let assigned = false;
  class NativeMatch extends Match {
    get arena() { return arena; }
    set arena(_sourceFallback) {
      if (assigned) throw new Error('Native arena reassignment refused');
      assigned = true;
    }
  }
  const match = new NativeMatch(character, harness, random, mapId, {...options, humanCount:1});
  if (!assigned || match.arena !== arena || match.snapshot().mapId !== mapId) throw new Error('Native constructor contract drift');
  for (const actor of match.actors) {
    if (!Number.isFinite(actor.y) || floorAt(actor.x, actor.z, arena) === null || obstructed(actor.x, actor.y, actor.z, undefined, arena)) {
      throw new Error('Native constructor produced an unsupported/blocked spawn');
    }
  }
  return match;
}

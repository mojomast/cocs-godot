import {Match, floorAt, obstructed} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
import {CHARACTERS, HARNESSES} from '../../game/data.mjs';
import {nativeArenaEntry} from './catalog.mjs';
import {keys, parseArenaEnvelope, readNativeArena} from './schema.mjs';
import {LOCAL_BOT_MAX, routeBotConfig, spreadLocalSpawn} from '../native-menu-debug-bots/seats.mjs';

export const DEFAULT_NATIVE_CONFIG = Object.freeze({mode:'deathmatch', botCount:3,
  difficulty:'normal', timeLimit:180, fragLimit:15});
export function validateNativeConfig(value = {}) {
  keys(value, ['mode', 'botCount', 'difficulty', 'timeLimit', 'fragLimit'], 'Deathmatch config');
  const config = {...DEFAULT_NATIVE_CONFIG, ...value};
  if (config.mode !== 'deathmatch') throw new TypeError('Native arenas support deathmatch only');
  for (const [key, min, max] of [['botCount', 1, LOCAL_BOT_MAX], ['timeLimit', 60, 900], ['fragLimit', 5, 50]]) {
    if (!Number.isInteger(config[key]) || config[key] < min || config[key] > max) throw new TypeError(`${key} must be ${min}..${max}`);
  }
  if (!['easy', 'normal', 'hard', 'nightmare'].includes(config.difficulty)) throw new TypeError('Unsupported difficulty');
  return routeBotConfig(normalizeConfig(config), config.botCount);
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
    get config() { return this._localConfig; }
    set config(value) {
      if (this._localConfig && !this.actors) throw new Error('Native config reassignment during construction');
      this._localConfig = routeBotConfig(value, this._localConfig?.botCount ?? options.botCount);
    }
    get arena() { return arena; }
    set arena(_sourceFallback) {
      if (assigned) throw new Error('Native arena reassignment refused');
      assigned = true;
    }
  }
  const MatchType = options.botCount > 8 ? class CrowdedNativeMatch extends NativeMatch {
    spawn(actor) { super.spawn(actor); spreadLocalSpawn(this, actor, this.spawns.map(p => [p.x, p.z])); }
  } : NativeMatch;
  const match = new MatchType(character, harness, random, mapId, {...options, humanCount:1});
  if (!assigned || match.arena !== arena || match.snapshot().mapId !== mapId) throw new Error('Native constructor contract drift');
  if (match.actors.length !== 1 + options.botCount) throw new Error('Native bot seat count drift');
  for (const actor of match.actors) {
    if (!Number.isFinite(actor.y) || floorAt(actor.x, actor.z, arena) === null || obstructed(actor.x, actor.y, actor.z, undefined, arena)) {
      throw new Error('Native constructor produced an unsupported/blocked spawn');
    }
  }
  return match;
}

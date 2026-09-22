// Source-backed Domination factory for the identity map Vermilion Fold.
//
// The scoped constructor accessor is the same reviewed pattern the delivered
// Deathmatch factory uses: the source `Match` constructor's own
// `this.arena = getMap(mapId)` assignment is intercepted BEFORE the floor
// query, navigation graph, spawn pools, objective template and actor seats
// initialize, and returns the strict-parsed identity arena instead. No source
// registry is written, no completed Match is transplanted and no client value
// reaches the filesystem: `mapId` is checked against the static allowlist and
// the envelope comes from the reviewed static catalog entry.
//
// Acceptance pins the identity contract that the route actually consumes:
//   * exactly the three authored `arena.objectiveZones`, in authored order,
//     reported under the source's alpha/bravo/charlie ids. The constructor may
//     move a zone onto a source navigation node (its documented snap) or onto
//     clear ground (`clearZone`), so every zone must sit on either the authored
//     point or an existing source nav node, at the authored radius, on
//     walkable support above void.
//   * both validated `arena.teamSpawns` pools, preserved exactly by the source
//     `teamPoints` normalization, with every published point supported and
//     unobstructed.
import {Match, floorAt, obstructed} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
import {CHARACTERS, HARNESSES} from '../../game/data.mjs';
import {keys, parseArenaEnvelope, readNativeArena} from '../native-arenas/schema.mjs';
import {IDENTITY_ZONE_IDS, IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE, identityZoneEntry} from './catalog.mjs';

export const DEFAULT_IDENTITY_ZONE_CONFIG = Object.freeze({mode: IDENTITY_ZONE_MODE, botCount: 2,
  difficulty: 'normal', timeLimit: 300, fragLimit: 100});
const TEAM_KEYS = Object.freeze({0: ['0', 'red', 'west'], 1: ['1', 'blue', 'east']});
const floorClose = (a, b) => Number.isFinite(a) && Number.isFinite(b) && Math.abs(a - b) < 0.15;

/** Validate the route's launch config. Ordinary source rules, nothing injected. */
export function validateIdentityZoneConfig(value = {}) {
  keys(value, ['mode', 'botCount', 'difficulty', 'timeLimit', 'fragLimit'], 'Domination config');
  const config = {...DEFAULT_IDENTITY_ZONE_CONFIG, ...value};
  if (config.mode !== IDENTITY_ZONE_MODE) throw new TypeError('Identity zone route supports domination only');
  for (const [key, min, max] of [['botCount', 0, 7], ['timeLimit', 60, 900], ['fragLimit', 1, 900]]) {
    if (!Number.isInteger(config[key]) || config[key] < min || config[key] > max) {
      throw new TypeError(`${key} must be ${min}..${max}`);
    }
  }
  if (!['easy', 'normal', 'hard', 'nightmare'].includes(config.difficulty)) throw new TypeError('Unsupported difficulty');
  const normalized = normalizeConfig(config);
  if (normalized.mode !== IDENTITY_ZONE_MODE) throw new TypeError('Source config did not resolve domination');
  return normalized;
}

/** The team pool the strict identity envelope authored for `team`, in order. */
export function identityTeamPool(arena, team) {
  const teams = arena?.teamSpawns;
  if (teams === null || typeof teams !== 'object' || Array.isArray(teams)) return null;
  for (const key of TEAM_KEYS[team]) {
    const pool = teams[key];
    if (Array.isArray(pool)) return pool.map(p => Array.isArray(p) ? [p[0], p[1]] : [p?.x, p?.z]);
  }
  return null;
}

/** True when `(x,z)` is the authored point or one of the source's nav nodes. */
function zoneSitedOnIdentity(match, zone, authored) {
  if (zone.x === authored.x && zone.z === authored.z) return 'authored';
  return match.nav.some(node => node.x === zone.x && node.z === zone.z) ? 'navigation-node' : null;
}

/** Construct one real source Domination Match on the validated identity arena.
 *
 * `humanCount` stays 1 on the authority path (single local human, every other
 * seat a genuine source bot). In-process acceptance may construct two local
 * seats to prove the deterministic contest/loss/recover rules without bots.
 * `arenaData` is a trusted in-process synthetic test seam only: WebSocket
 * frames never reach it.
 */
export function createIdentityZoneMatch({mapId = IDENTITY_ZONE_MAP_ID, config = {}, random = Math.random,
  character = 'chatgpt', harness = 'openclaw', arenaData, humanCount = 1, loadouts} = {}) {
  const entry = identityZoneEntry(mapId);
  const options = validateIdentityZoneConfig(config);
  if (typeof random !== 'function') throw new TypeError('RNG must be a function');
  if (!CHARACTERS.some(c => c.id === character) || !HARNESSES.some(h => h.id === harness)) throw new TypeError('Unsupported loadout');
  if (!Number.isInteger(humanCount) || humanCount < 1 || humanCount > 8) throw new TypeError('humanCount must be 1..8');
  // In-process acceptance may pin both local seats to one identical loadout so
  // a seat-speed difference can never masquerade as map asymmetry. The launch
  // authority never passes this option; it stays out of the wire contract.
  if (loadouts !== undefined) {
    if (loadouts === null || typeof loadouts !== 'object' || Array.isArray(loadouts)) throw new TypeError('loadouts must be an object keyed by seat');
    for (const [key, value] of Object.entries(loadouts)) {
      const seat = Number(key);
      if (!Number.isInteger(seat) || seat < 0 || seat >= humanCount) throw new TypeError('loadouts seat is out of range');
      if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new TypeError('loadout entry must be an object');
      for (const field of Object.keys(value)) if (!['character', 'harness'].includes(field)) throw new TypeError(`Unsupported loadout field: ${field}`);
      if (value.character !== undefined && !CHARACTERS.some(c => c.id === value.character)) throw new TypeError('Unsupported loadout character');
      if (value.harness !== undefined && !HARNESSES.some(h => h.id === value.harness)) throw new TypeError('Unsupported loadout harness');
    }
  }
  const data = arenaData === undefined ? readNativeArena(entry.id) : parseArenaEnvelope(arenaData, entry.id);
  const arena = data.arena;
  let assigned = false;
  class IdentityZoneMatch extends Match {
    get arena() { return arena; }
    set arena(_sourceFallback) {
      if (assigned) throw new Error('Identity zone arena reassignment refused');
      assigned = true;
    }
  }
  const match = new IdentityZoneMatch(character, harness, random, entry.id,
    {...options, humanCount, ...(loadouts === undefined ? {} : {loadouts})});
  if (!assigned || match.arena !== arena || match.snapshot().mapId !== entry.id) throw new Error('Identity zone constructor contract drift');
  if (match.config.mode !== IDENTITY_ZONE_MODE) throw new Error('Identity zone match did not resolve domination');
  const state = match.objectiveState;
  const authored = Array.isArray(arena.objectiveZones) ? arena.objectiveZones : [];
  if (state?.kind !== 'domination' || !Array.isArray(state.zones) || state.zones.length !== 3) {
    throw new Error('Identity zone domination template is incomplete');
  }
  if (authored.length !== 3) throw new Error('Identity zone arena does not author exactly three fold points');
  const sited = [];
  state.zones.forEach((zone, index) => {
    const source = authored[index];
    if (zone.id !== IDENTITY_ZONE_IDS[index]) throw new Error('Identity zone source id order drift');
    const site = zoneSitedOnIdentity(match, zone, source);
    if (site === null) throw new Error('Identity zone is neither the authored point nor a source navigation node');
    if (zone.radius !== (Number.isFinite(source.radius) ? source.radius : 3.5)) throw new Error('Identity zone radius drift');
    const support = floorAt(zone.x, zone.z, arena);
    if (!Number.isFinite(zone.y) || support === null || !floorClose(zone.y, support) || zone.y <= arena.voidY) {
      throw new Error('Identity zone lacks walkable support above void');
    }
    sited.push({id: zone.id, site, authored: [source.x, source.z], source: [zone.x, zone.z]});
  });
  const pools = {};
  for (const team of [0, 1]) {
    const authored_pool = identityTeamPool(arena, team);
    if (!Array.isArray(authored_pool) || authored_pool.length < 2) throw new Error('Identity team spawn pool is missing');
    for (const [x, z] of authored_pool) {
      if (!Number.isFinite(x) || !Number.isFinite(z)) throw new Error('Identity team spawn is malformed');
      const y = floorAt(x, z, arena);
      if (y === null || y <= arena.voidY || obstructed(x, y, z, undefined, arena)) throw new Error('Identity team spawn is unsupported or blocked');
    }
    const normalized = match.teamSpawns[team];
    if (!Array.isArray(normalized) || normalized.length !== authored_pool.length ||
        normalized.some((point, index) => point[0] !== authored_pool[index][0] || point[1] !== authored_pool[index][1])) {
      throw new Error('Identity team spawn pool drift');
    }
    pools[team] = normalized.map(point => [point[0], point[1]]);
  }
  for (const actor of match.actors) {
    const pool = pools[actor.team];
    if (actor.team !== (actor.id % 2)) throw new Error('Identity seat/team assignment drift');
    if (!pool.some(([x, z]) => actor.x === x && actor.z === z)) throw new Error('Identity actor spawned outside its authored team pool');
    if (!Number.isFinite(actor.y) || obstructed(actor.x, actor.y, actor.z, undefined, arena)) {
      throw new Error('Identity zone constructor produced a blocked spawn');
    }
  }
  // Non-enumerable so snapshots, spreads and source reads never see it; the
  // authority and acceptance harness read the pinned provenance explicitly.
  Object.defineProperty(match, 'identityProvenance', {enumerable: false, writable: false, value: Object.freeze({
    mapId: entry.id, mode: IDENTITY_ZONE_MODE, geometryHash: data.geometryHash,
    zones: Object.freeze(sited.map(item => Object.freeze({...item}))),
    teamSpawns: Object.freeze({0: Object.freeze(pools[0]), 1: Object.freeze(pools[1])})})});
  return match;
}

// Port-owned debug reconciliation for the two LOCAL authorities only
// (port/native-arenas/authority.mjs, port/native-horde/authority.mjs).
//
// Boundary, stated plainly:
//   * LIVE knobs are applied to the running source Match the moment the frame
//     arrives, because the locked source reads them live every tick
//     (`match.config`, `match.mutators`, `match.difficulty`).
//   * RESTART knobs (`botCount`, `startingWeapon`) are QUEUED and consumed when
//     the next reviewed round is constructed. The panel must say so.
//   * PORT-ONLY knobs (`godMode`, `playerIncomingScale`, `unlockAllWeapons`,
//     `testDamage`) do not exist in the source. They are explicit port-side
//     reconciliation on the single human seat and are labelled debug-only in
//     the panel and in the echo. They never touch bot seats.
//   * This module is imported by the local authorities only. The multi-human
//     room path (server/**) never imports it and answers `debug` with its
//     existing unknown-message error, unchanged.
//
// Validation is strict and additive: unknown keys are refused, every number
// must be finite and inside its documented bound, every flag is a real boolean,
// and there is no map id, path, URL or free-form field of any kind.
import {DIFFICULTIES, mutatorEffects, normalizeConfig} from '../../game/config.mjs';

export const DEBUG_PROTOCOL = 1;
export const DEBUG_DIFFICULTIES = Object.freeze(DIFFICULTIES.map(entry => entry.id));
// Continuous presets are the exact values `game/config.mjs normalizeConfig`
// accepts, so a debug frame can never invent a multiplier the source would
// silently clamp.
const LIVE_NUMERIC = Object.freeze({
  damage:Object.freeze([.5, 1, 1.5, 2]),
  speed:Object.freeze([.75, 1, 1.25, 1.5]),
  gravity:Object.freeze([.4, .7, 1]),
});
const LIVE_BOOLEAN = Object.freeze(['oneShot', 'instagib', 'noRecoil', 'bigHead', 'berserk',
  'bounty', 'lifeSteal', 'suddenDeath', 'fastPowers', 'mirrorLoadout', 'randomLoadout',
  'unlimitedAmmo']);
const PORT_BOOLEAN = Object.freeze(['godMode', 'unlockAllWeapons']);
// Construction-time source knobs. The authority queues them for the next round.
export const RESTART_KNOBS = Object.freeze({
  botCount:Object.freeze([0, 8]),
  startingWeapon:Object.freeze([0, 9]),
});
export const DEBUG_FIELDS = Object.freeze(['type', 'v', 'clear', 'difficulty', 'respawn',
  'playerIncomingScale', 'testDamage', ...Object.keys(LIVE_NUMERIC), ...LIVE_BOOLEAN,
  ...PORT_BOOLEAN, ...Object.keys(RESTART_KNOBS)]);
export const HUMAN_SEAT = 0;

const fail = message => { throw new TypeError(`Debug frame: ${message}`); };
const plain = value => value !== null && typeof value === 'object' && !Array.isArray(value) &&
  [Object.prototype, null].includes(Object.getPrototypeOf(value));
const finite = (value, min, max, label) => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
    fail(`${label} must be a finite number in ${min}..${max}`);
  }
  return value;
};

/** Validate one C→S debug frame. Throws (never coerces) on anything malformed. */
export function parseDebugFrame(frame) {
  if (!plain(frame)) fail('object envelope required');
  for (const key of Object.keys(frame)) if (!DEBUG_FIELDS.includes(key)) fail(`unsupported field ${key}`);
  if (frame.type !== 'debug') fail('type must be debug');
  if (frame.v !== DEBUG_PROTOCOL) fail(`protocol ${DEBUG_PROTOCOL} required`);
  if (frame.clear !== undefined && typeof frame.clear !== 'boolean') fail('clear must be boolean');
  const set = {};
  for (const [key, allowed] of Object.entries(LIVE_NUMERIC)) {
    if (frame[key] === undefined) continue;
    if (!allowed.includes(frame[key])) fail(`${key} must be one of ${allowed.join('/')}`);
    set[key] = frame[key];
  }
  if (frame.difficulty !== undefined) {
    if (!DEBUG_DIFFICULTIES.includes(frame.difficulty)) fail(`difficulty must be one of ${DEBUG_DIFFICULTIES.join('/')}`);
    set.difficulty = frame.difficulty;
  }
  if (frame.respawn !== undefined) set.respawn = finite(frame.respawn, 1, 5, 'respawn');
  if (frame.playerIncomingScale !== undefined) {
    set.playerIncomingScale = finite(frame.playerIncomingScale, .25, 4, 'playerIncomingScale');
  }
  if (frame.testDamage !== undefined) set.testDamage = finite(frame.testDamage, 0, 100000, 'testDamage');
  for (const key of [...LIVE_BOOLEAN, ...PORT_BOOLEAN]) {
    if (frame[key] === undefined) continue;
    if (typeof frame[key] !== 'boolean') fail(`${key} must be a boolean`);
    set[key] = frame[key];
  }
  for (const [key, [min, max]] of Object.entries(RESTART_KNOBS)) {
    if (frame[key] === undefined) continue;
    if (!Number.isInteger(frame[key]) || frame[key] < min || frame[key] > max) fail(`${key} must be an integer in ${min}..${max}`);
    set[key] = frame[key];
  }
  return {clear:frame.clear === true, set};
}

export function createDebugState({enabled = false} = {}) {
  return {
    enabled:enabled === true,
    // Port-only reconciliation state, read live by the damage guard and the
    // post-step reconcile. `godMode` clears on every round boundary.
    live:{godMode:false, playerIncomingScale:1, unlockAllWeapons:false},
    // Source config overrides that the locked source reads live.
    config:{},
    // Construction-time overrides consumed by the next `start`.
    queued:{},
    // Restart knobs the running round was actually constructed with, so the
    // echo never confuses "pending" with "already applied".
    constructed:{},
    // True while the unlock-all knob owns `config.unlimitedAmmo`, so switching
    // it off releases only the flag it set.
    autoUnlimited:false,
    restores:0, applied:0, rejected:0, lastReject:null,
  };
}

/** Fold one validated frame into the state. Returns the list of touched keys. */
export function applyDebugFrame(state, {clear, set}) {
  if (clear) {
    state.live = {godMode:false, playerIncomingScale:1, unlockAllWeapons:false};
    state.config = {};
    state.queued = {};
    state.autoUnlimited = false;
    state.applied++;
    return ['clear'];
  }  const touched = [];
  for (const [key, value] of Object.entries(set)) {
    touched.push(key);
    if (key === 'godMode' || key === 'playerIncomingScale') state.live[key] = value;
    else if (key === 'unlockAllWeapons') {
      // Unlock-all is the source `unlimitedAmmo` flag PLUS a per-slot grant on
      // the human seat; switching it off releases only the flag it set.
      state.live.unlockAllWeapons = value;
      if (value && state.config.unlimitedAmmo !== true) {
        state.config.unlimitedAmmo = true;
        state.autoUnlimited = true;
      } else if (!value && state.autoUnlimited) {
        delete state.config.unlimitedAmmo;
        state.autoUnlimited = false;
      }
    } else if (key === 'testDamage') continue; // one-shot action, applied by the authority
    else if (Object.hasOwn(RESTART_KNOBS, key)) state.queued[key] = value;
    else {
      if (key === 'unlimitedAmmo') state.autoUnlimited = false;
      state.config[key] = value;
    }
  }
  state.applied++;
  return touched;
}

/** Rebuild the live match config from the reviewed base plus live overrides.
 *  `base` is the authority's own reviewed config, never the mutated one, so
 *  clearing an override restores the source value instead of freezing it. */
export function applyLiveOverrides(match, overrides, base) {
  if (!match || !base) return false;
  const {mutators:_drop, ...current} = base;
  const next = normalizeConfig({...current, ...overrides});
  match.config = next;
  match.mutators = mutatorEffects(next);
  const difficulty = DIFFICULTIES.find(entry => entry.id === next.difficulty);
  if (difficulty) match.difficulty = difficulty;
  return true;
}

/** Install the single interception point this lane uses for port-only
 *  reconciliation. The guard reads `live` by reference on every call, so
 *  toggling god mode or the incoming scale is reversible without reinstalling.
 *  It only ever inspects the human seat; bot damage passes through untouched. */
const GUARD = Symbol('cocs-debug-human-guard');
export function installHumanGuard(match, live, humanId = HUMAN_SEAT) {
  if (!match || typeof match.damage !== 'function' || match[GUARD]) return false;
  const base = match.damage;
  match[GUARD] = function debugHumanGuard(target, amount, source, ability) {
    let next = amount;
    if (target && target.id === humanId && Number.isFinite(amount)) {
      const scale = Number.isFinite(live.playerIncomingScale) ? live.playerIncomingScale : 1;
      if (scale !== 1) next *= scale;
      if (live.godMode === true) {
        // A lethal hit is capped one point short of the human's full shield
        // pool, so the source's own death branch never runs. The post-step
        // reconcile then refills health. Bots are never inspected.
        const pool = Math.max(0, target.health || 0) + Math.max(0, target.armor || 0) +
          Math.max(0, target.temporaryShield || 0) + Math.max(0, target.juggernautShield || 0);
        next = Math.min(next, Math.max(0, pool - 1));
      }
    }
    return base.call(match, target, next, source, ability);
  };
  match.damage = match[GUARD];
  return true;
}

function grantAllAmmo(match, actor) {
  if (!actor || !Array.isArray(actor.ammo)) return false;
  for (let index = 0; index < actor.ammo.length; index++) actor.ammo[index] = Infinity;
  return true;
}

/** Restore the human seat's ammo belt to what the source would hand a fresh
 *  spawn under the current config. Used when unlock-all is switched off so the
 *  grant is reversible; the held weapon keeps one magazine so the player is
 *  never left holding an empty gun. */
export function restoreSpawnAmmo(match, actor) {
  if (!match || !actor) return false;
  const belt = match.startingLoadout().ammo;
  actor.ammo = [...belt];
  const weapon = match.weaponForIndex(actor, actor.weapon);
  const held = Number.isFinite(actor.ammo[actor.weapon]) ? actor.ammo[actor.weapon] : 0;
  if (weapon && held <= 0) actor.ammo[actor.weapon] = Math.max(1, weapon.ammo || 1);
  return true;
}

/** Post-step reconciliation on the human seat only. Returns a small report for
 *  the authority's observer/echo so tests can see exactly what was restored. */
export function reconcileHuman(match, state, humanId = HUMAN_SEAT) {
  if (!state.enabled || !match || !Array.isArray(match.actors)) return null;
  const actor = match.actors[humanId];
  if (!actor) return null;
  const report = {};
  if (state.live.godMode === true) {
    const before = actor.health;
    if (before <= 0) {
      actor.dead = 0;
      actor.health = actor.maxHealth;
      state.restores++;
      report.restoredDeath = true;
    } else if (before < actor.maxHealth) actor.health = actor.maxHealth;
    if (before < actor.maxHealth) report.healthLost = +(actor.maxHealth - before).toFixed(3);
    report.health = actor.health;
  }
  if (state.live.unlockAllWeapons === true) report.grantedAmmo = grantAllAmmo(match, actor);
  return report;
}

/** Public echo attached to `lobby` and `debug-state`. `restart` names the
 *  construction-time knobs this route accepts and their reviewed bounds, so a
 *  client can colour the panel honestly without guessing. */
export function debugEcho(state, restart = {}) {
  return {
    enabled:state.enabled, version:DEBUG_PROTOCOL,
    live:{...state.live, ...state.config},
    queued:{...state.queued},
    constructed:{...state.constructed},
    restart:{...(state.enabled ? restart : {})},
    restores:state.restores, applied:state.applied, rejected:state.rejected, lastReject:state.lastReject,
  };
}

// Static allowlist for the identity-map Domination route (Vermilion Fold).
//
// One reviewed map/mode pair only: `vermilion-fold` + `domination`. The path is
// the identity family's own reviewed entry, so no second asset table can drift
// from `port/native-arenas/catalog.mjs`. Nothing here reads a caller path or a
// client-supplied map id; launch options are checked against this table.
import {nativeArenaEntry} from '../native-arenas/catalog.mjs';

export const IDENTITY_ZONE_MAP_ID = 'vermilion-fold';
export const IDENTITY_ZONE_MODE = 'domination';
export const IDENTITY_ZONE_IDS = Object.freeze(['alpha', 'bravo', 'charlie']);
// Exactly the reviewed pairs this route may construct. The three authored fold
// points are the only identity objective set with a delivered strict envelope.
export const IDENTITY_ZONE_MODES = Object.freeze({
  [IDENTITY_ZONE_MAP_ID]: Object.freeze([IDENTITY_ZONE_MODE]),
});
export function identityZoneAllowed(mapId, mode) {
  return typeof mapId === 'string' && Object.prototype.hasOwnProperty.call(IDENTITY_ZONE_MODES, mapId) &&
    IDENTITY_ZONE_MODES[mapId].includes(mode);
}
/** Reviewed static entry for an allowlisted identity zone map. Throws otherwise. */
export function identityZoneEntry(mapId) {
  if (!Object.prototype.hasOwnProperty.call(IDENTITY_ZONE_MODES, mapId)) {
    throw new TypeError('Unsupported identity zone map');
  }
  const entry = nativeArenaEntry(mapId);
  if (entry.family !== 'identity') throw new TypeError('Identity zone map is not an identity envelope');
  return Object.freeze({id: entry.id, name: entry.name, family: 'identity',
    mode: IDENTITY_ZONE_MODE, path: entry.path});
}
export const IDENTITY_ZONE_MAP_IDS = Object.freeze(Object.keys(IDENTITY_ZONE_MODES));

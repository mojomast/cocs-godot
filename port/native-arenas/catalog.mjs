// Port-owned static asset closure. Never pass a client path to the filesystem.
// Two reviewed families share the same source-Match factory:
//   native   — the three original Prism Foundry / Aurora Basin / Cinder Array arenas
//   identity — the three identity maps (Lacuna Court / Vermilion Fold / Nacre Engine)
// The identity JSON envelope is a superset of the native one (mode/palette/art plus
// optional objectiveZones/teamSpawns); `schema.mjs` validates each family strictly.
const nativeEntry = (id, name) => Object.freeze({id, name, family:'native',
  path:`godot/native_arenas/generated/${id}.json`});
const identityEntry = (id, name) => Object.freeze({id, name, family:'identity',
  path:`godot/identity_maps/generated/${id}.json`});

export const NATIVE_ARENA_CATALOG = Object.freeze([
  nativeEntry('prism-foundry', 'Prism Foundry'),
  nativeEntry('aurora-basin', 'Aurora Basin'),
  nativeEntry('cinder-array', 'Cinder Array'),
]);
export const IDENTITY_ARENA_CATALOG = Object.freeze([
  identityEntry('lacuna-court', 'Lacuna Court'),
  identityEntry('vermilion-fold', 'Vermilion Fold'),
  identityEntry('nacre-engine', 'Nacre Engine'),
]);
export const ARENA_CATALOG = Object.freeze([...NATIVE_ARENA_CATALOG, ...IDENTITY_ARENA_CATALOG]);
// The original three keep their historical list/identity for existing consumers.
export const NATIVE_ARENA_IDS = Object.freeze(NATIVE_ARENA_CATALOG.map(entry => entry.id));
export const IDENTITY_ARENA_IDS = Object.freeze(IDENTITY_ARENA_CATALOG.map(entry => entry.id));
// Every family that the owned Deathmatch route/factory may construct.
export const DEATHMATCH_ARENA_IDS = Object.freeze(ARENA_CATALOG.map(entry => entry.id));
export function nativeArenaEntry(id) {
  const entry = ARENA_CATALOG.find(entry => entry.id === id);
  if (!entry) throw new TypeError('Unsupported native arena ID');
  return entry;
}

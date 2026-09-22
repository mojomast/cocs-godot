// Port-owned static asset closure. Never pass a client path to the filesystem.
export const NATIVE_ARENA_CATALOG = Object.freeze([
  Object.freeze({id:'prism-foundry', name:'Prism Foundry', path:'godot/native_arenas/generated/prism-foundry.json'}),
  Object.freeze({id:'aurora-basin', name:'Aurora Basin', path:'godot/native_arenas/generated/aurora-basin.json'}),
  Object.freeze({id:'cinder-array', name:'Cinder Array', path:'godot/native_arenas/generated/cinder-array.json'}),
]);
export const NATIVE_ARENA_IDS = Object.freeze(NATIVE_ARENA_CATALOG.map(entry => entry.id));
export function nativeArenaEntry(id) {
  const entry = NATIVE_ARENA_CATALOG.find(entry => entry.id === id);
  if (!entry) throw new TypeError('Unsupported native arena ID');
  return entry;
}

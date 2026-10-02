// Only the production catalog grants a map/mode pair. Candidate IDs here are
// review scope, not registration or native acceptance.
import assert from 'node:assert/strict';
export const BASE_WORLDS = Object.freeze({
  'switchyard-ward':['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault'],
  'rainmarket-exchange':['deathmatch','teamdeathmatch','instagib','rockets','armsrace','domination','koth','uplink','holdout','assault','payload'],
  'breakwater-exchange':['deathmatch','teamdeathmatch','domination','assault','payload','combined-arms'],
  'thermal-divide':['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault'],
  'sirocco-circuit':['puma-race'], 'copper-bowl':['puma-soccer'], 'tern-archipelago':['cocs','cocs-coop'],
});
export const REVIEWED_CANDIDATES = Object.freeze(['helix-conservatory','gravemill-foundry','parallax-observatory','vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
export function worldArt(id) {
  assert.ok(Object.hasOwn(BASE_WORLDS,id)||REVIEWED_CANDIDATES.includes(id),`Unreviewed world: ${id}`);
  // Accepted rev3 Foundry retains its production worlds/ export path. Runtime
  // map.gd already loads these bytes; candidate naming must not invent a path.
  if (id==='gravemill-foundry') return 'res://multiplayer_worlds/art/worlds/gravemill-foundry.glb';
  if (['vesper-viaduct','abyssal-pressureworks','stormglass-causeway'].includes(id)) return `res://multiplayer_worlds/art/worlds/${id}.glb`;
  return REVIEWED_CANDIDATES.includes(id) ? `res://multiplayer_worlds/art/${id}/${id}.glb`
    : `res://multiplayer_worlds/art/${['switchyard-ward','rainmarket-exchange'].includes(id)?'':'worlds/'}${id}.glb`;
}
export function worldClosure(worlds) {
  for (const [id,modes] of Object.entries(BASE_WORLDS))
    assert.deepEqual(worlds[id]?.modes,modes,`Original accepted map/modes changed: ${id}`);
  const modes = new Set([...Object.values(BASE_WORLDS).flat(),'arsenal','juggernaut','team-elimination','vip-escort']);
  for (const [id,entry] of Object.entries(worlds)) {
    assert.ok(Object.hasOwn(BASE_WORLDS,id)||REVIEWED_CANDIDATES.includes(id),`Unreviewed world: ${id}`);
    assert.ok(Array.isArray(entry.modes)&&entry.modes.length&&new Set(entry.modes).size===entry.modes.length,`Invalid accepted modes: ${id}`);
    assert.ok(entry.modes.every(mode=>modes.has(mode)),`Unreviewed mode: ${id}`);
  }
  return Object.keys(worlds).map(id=>`godot/multiplayer_worlds/generated/${id}.json`);
}

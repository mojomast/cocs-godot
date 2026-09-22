import {nativeArenaGeometryHash} from '../schema.mjs';

// SYNTHETIC flat platform, not generated native geometry or visual acceptance.
// All combat on it still runs the unmodified source Match and source bot AI.
export function syntheticArena(id = 'prism-foundry') {
  const name = `SYNTHETIC ${id}`;
  const spawns = [[-8, -8], [8, 8], [-8, 8], [8, -8]];
  const arena = {id, name, bounds:{minX:-12, maxX:12, minZ:-12, maxZ:12},
    spawns, pickups:[['health', 0, 6], ['rail', 0, -6], ['armor', 6, 0]],
    navNodes:[[-6, -6], [0, -6], [6, -6], [-6, 0], [0, 0], [6, 0], [-6, 6], [0, 6], [6, 6]],
    blocks:[], terrain:{maxSlope:Math.PI / 4, surfaces:[{id:'synthetic-floor', material:'stone',
      walkable:true, vertices:[[-12, 4, -12], [-12, 4, 12], [12, 4, 12], [12, 4, -12]],
      triangles:[[0, 1, 2], [0, 2, 3]]}], walls:[]}, voidY:-20, nextGen:false};
  return {schemaVersion:1, id, name, geometryHash:nativeArenaGeometryHash(arena),
    arena, spawnPoints:spawns.map(([x, z]) => ({x, y:4, z})), routes:[], colliderSources:[]};
}
export function seededRandom(seed = 12345) {
  return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
}
// Test driver uses only ordinary player controls. Never writes actor state.
export function aimedControls(state) {
  const player = state.actors[0];
  if (player.health <= 0) return {};
  const target = state.actors.filter(a => a.id !== player.id && a.health > 0)
    .sort((a, b) => Math.hypot(a.x - player.x, a.z - player.z) - Math.hypot(b.x - player.x, b.z - player.z))[0];
  if (!target) return {};
  const dx = target.x - player.x, dz = target.z - player.z;
  const dy = target.y + .95 - player.y - player.eyeHeight;
  return {yaw:Math.atan2(-dx, -dz) - (player.punchYaw || 0),
    pitch:Math.atan2(dy, Math.hypot(dx, dz)) - (player.punchPitch || 0),
    fire:true, ads:true, reload:player.ammo[player.weapon] === 0};
}

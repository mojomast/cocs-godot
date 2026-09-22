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
// SYNTHETIC identity-map envelope: flat platform plus the identity-only
// presentation/objective metadata. Verification parses this with the real
// per-family schema; generated files stay the only source of shipped geometry.
export function syntheticIdentityArena(id = 'lacuna-court') {
  const name = `SYNTHETIC ${id}`;
  const spawns = [[-10, -10], [10, 10], [-10, 10], [10, -10]];
  const arena = {id, name, bounds:{minX:-16, maxX:16, minZ:-16, maxZ:16},
    spawns, pickups:[['health', 0, 8], ['rail', 0, -8], ['armor', 8, 0]],
    navNodes:[[-6, -6], [6, -6], [-6, 6], [6, 6]],
    blocks:[{id:'core', kind:'structure', x:0, z:0, w:4, d:4, h:2, baseY:0, material:'enamel'}],
    terrain:{maxSlope:Math.PI / 4, surfaces:[{id:'court', material:'floor',
      walkable:true, vertices:[[-16, 0, -16], [-16, 0, 16], [16, 0, 16], [16, 0, -16]],
      triangles:[[0, 1, 2], [0, 2, 3]]}], walls:[]}, voidY:-20, ceilingY:24, raised:false, nextGen:true};
  if (id === 'vermilion-fold') {
    arena.teamSpawns = {0:[[-14, 0], [-14, 12]], 1:[[14, 0], [14, -12]]};
    arena.objectiveZones = [{x:0, z:-10, y:0, radius:3.5}, {x:0, z:0, y:0, radius:3.5}, {x:0, z:10, y:0, radius:3.5}];
  }
  return {schemaVersion:1, id, name, mode:'deathmatch', geometryHash:nativeArenaGeometryHash(arena),
    arena, palette:['a4a8ac', 'b7b0a0', '202c59', 'ad7045'],
    art:[{id:'trim', material:'accent', walkable:false,
      vertices:[[-2, 2, -2], [-2, 2, 2], [2, 2, 2]], triangles:[[0, 1, 2]]}],
    routes:[{id:'loop', points:[{x:-8, y:0, z:-8}, {x:8, y:0, z:8}]}],
    cameras:[{id:'view', at:[0, 8, 8], target:[0, 0, 0]}],
    landmarks:[{kind:'beacon', at:[0, 4, 0], scale:[1, 1, 1]}],
    grayboxHash:'0'.repeat(64),
    spawnPoints:spawns.map(([x, z]) => ({x, y:0, z})),
    colliderSources:[],
    provenance:{godot:'4.5.2', compiler:'synthetic fixture', input:'authored identity recipe', supportModel:'flat platform'},
    artNotes:[{id:'trim', collision:'none-overhead', reason:'synthetic presentation note'}]};
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

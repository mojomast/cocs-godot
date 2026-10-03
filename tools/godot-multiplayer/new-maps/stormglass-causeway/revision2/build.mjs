// Stormglass revision-2 candidate builder. Source-only: writes only revision2/
// files. Never touches the accepted runtime JSON, GLB, master or profile.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {recipe, ID, LAYOUT_REVISION} from './recipe.mjs';
import {canonical} from '../../../../../port/multiplayer-worlds/catalog.mjs';
import {terrainSupportAt} from '../../../../../game/terrain.mjs';
const hash = s => createHash('sha256').update(s).digest('hex');
export function build() {
  const arena = recipe();
  const body = JSON.stringify(arena) + '\n';
  const geometryHash = hash(canonical(arena));
  const data = {schemaVersion: 1, id: ID, name: arena.name, layoutRevision: LAYOUT_REVISION,
    recipeHash: hash(body), geometryHash,
    spawnPoints: arena.spawns.map(([x, z]) => ({x, y: terrainSupportAt(x, z, arena.terrain, arena.terrain.maxSlope)?.y ?? null, z})),
    arena};
  const probes = {geometryHash, layoutRevision: LAYOUT_REVISION, roadWidth: arena.metrics.roadWidth,
    points: arena.navNodes.map(p => ({...p, y: terrainSupportAt(p.x, p.z, arena.terrain, arena.terrain.maxSlope)?.y ?? null}))};
  return {arena, body, data, probes};
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const {arena, data, probes, body} = build();
  for (const [name, value] of [['arena.json', body], ['candidate.json', JSON.stringify(data) + '\n'], ['probes.json', JSON.stringify(probes) + '\n']]) {
    const path = new URL(name, import.meta.url);
    if (process.argv.includes('--check')) { if (fs.readFileSync(path, 'utf8') !== value) throw Error('Stale revision2 ' + name); }
    else fs.writeFileSync(path, value);
  }
  console.log(JSON.stringify({id: ID, layoutRevision: LAYOUT_REVISION, geometryHash: data.geometryHash,
    roadWidth: arena.metrics.roadWidth, roadRelief: arena.metrics.roadRelief,
    surfaces: arena.terrain.surfaces.length, walls: arena.terrain.walls.length,
    scenic: Object.values(arena.art.revision2.scenery).reduce((n, list) => n + (Array.isArray(list) ? list.length : 1), 0)}, null, 0));
}

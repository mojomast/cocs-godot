// Abyssal V corrective successor. Writes only revision2-corrective-v/.
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
  const probes = {geometryHash, layoutRevision: LAYOUT_REVISION,
    points: arena.navNodes.map(p => ({...p, y: terrainSupportAt(p.x, p.z, arena.terrain, arena.terrain.maxSlope)?.y ?? null}))};
  return {arena, body, data, probes};
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const {arena, body, data, probes} = build();
  const outputs = [['arena.json', body], ['candidate.json', JSON.stringify(data) + '\n'], ['probes.json', JSON.stringify(probes) + '\n']];
  for (const [name, value] of outputs) {
    const path = new URL(name, import.meta.url);
    if (process.argv.includes('--check')) { if (fs.readFileSync(path, 'utf8') !== value) throw Error('Stale revision2-corrective-v ' + name); }
    else fs.writeFileSync(path, value);
  }
  console.log(JSON.stringify({id: ID, layoutRevision: LAYOUT_REVISION, geometryHash: data.geometryHash,
    surfaces: arena.terrain.surfaces.length, walls: arena.terrain.walls.length,
    blocks: arena.blocks.length, nav: arena.navNodes.length, routes: arena.routes.length,
    replacedRoofs: arena.art.revision2.replacedRoofHosts.length}, null, 0));
}

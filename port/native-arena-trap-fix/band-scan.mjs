// Post-fix static band scan (trap-fix lane).
//
// Source moveActor applies an axis step only when the destination is outside
// the 0.42 m contact band of every movement wall. An actor standing *inside* a
// band can therefore never take any step (its velocity is zeroed every tick):
// that position is a permanent trap. This scan walks the walkable support of a
// generated native arena and reports every sampled supported position whose
// centre is refused at the full contact radius, clustered for inspection.
//
// Expected post-fix result: zero clusters that are reachable standing spots.
import {readNativeArena} from '../native-arenas/schema.mjs';
import {floorAt, obstructed} from '../../game/core.mjs';

const mapId = process.argv[2] ?? 'prism-foundry';
const step = Number(process.argv[3] ?? 0.25);
const data = readNativeArena(mapId);
const arena = data.arena;
const bounds = arena.bounds;
const hits = [];
let supported = 0;
for (let x = bounds.minX; x <= bounds.maxX; x += step) {
  for (let z = bounds.minZ; z <= bounds.maxZ; z += step) {
    const y = floorAt(x, z, arena);
    if (y === null) continue;
    supported++;
    if (obstructed(x, y, z, 0.42, arena)) hits.push({x: +x.toFixed(2), y: +y.toFixed(2), z: +z.toFixed(2)});
  }
}
// cluster on a 1 m grid
const seen = new Set(), groups = [];
const key = p => `${Math.floor(p.x)},${Math.floor(p.z)}`;
const index = new Map();
for (const p of hits) { const k = key(p); if (!index.has(k)) index.set(k, []); index.get(k).push(p); }
for (const p of hits) {
  const k0 = key(p);
  if (seen.has(k0)) continue;
  const queue = [p]; seen.add(k0); const members = [];
  while (queue.length) {
    const c = queue.pop(); members.push(c);
    for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) {
      const k = `${Math.floor(c.x) + dx},${Math.floor(c.z) + dz}`;
      if (!index.has(k) || seen.has(k)) continue;
      seen.add(k); queue.push(...index.get(k));
    }
  }
  const xs = members.map(m => m.x), ys = members.map(m => m.y), zs = members.map(m => m.z);
  groups.push({cells: members.length, x: [Math.min(...xs), Math.max(...xs)], y: [Math.min(...ys), Math.max(...ys)],
    z: [Math.min(...zs), Math.max(...zs)], sample: members[0]});
}
groups.sort((a, b) => b.cells - a.cells);
const report = {mapId, geometryHash: data.geometryHash, gridStep: step, supportedSamples: supported, blockedSamples: hits.length,
  clusters: groups.length, top: groups.slice(0, 12)};
console.log(JSON.stringify(report, null, 1));
const outPath = `port/native-arena-trap-fix/logs/band-scan-${mapId}.json`;
const {writeFileSync} = await import('node:fs');
writeFileSync(outPath, `${JSON.stringify(report, null, 2)}\n`);

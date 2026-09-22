// Review-lane trap-site diagnostic: characterise a reported bot trap.
// Usage: node port/native-arena-review/trap-site.mjs --map=prism-foundry --x=-8.96 --z=-8.4
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {floorAt, obstructed, walkEdge, nearest, navigation} from '../../game/core.mjs';
import {readNativeArena} from '../native-arenas/schema.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const args = Object.fromEntries(process.argv.slice(2).filter(a => a.startsWith('--')).map(a => a.split('=')));
const mapId = args.map ?? 'prism-foundry';
const cx = Number(args.x ?? -8.96), cz = Number(args.z ?? -8.4);
const data = readNativeArena(mapId);
const arena = data.arena;
const nav = navigation(arena);

console.log(JSON.stringify({map: mapId, geometryHash: data.geometryHash, site: [cx, cz]}));
// vertical profile
const profile = [];
for (let y = -1; y <= 4.5; y += 0.5) profile.push({y: +y.toFixed(1), obstructed006: obstructed(cx, y, cz, 0.06, arena), obstructed042: obstructed(cx, y, cz, 0.42, arena)});
console.log('vertical', JSON.stringify(profile));
// support field
const field = [];
for (let dz = -2; dz <= 2; dz += 0.5) {
  const row = [];
  for (let dx = -2; dx <= 2; dx += 0.5) { const y = floorAt(cx + dx, cz + dz, arena); row.push(y === null ? null : +y.toFixed(2)); }
  field.push({z: +(cz + dz).toFixed(1), supports: row});
}
console.log('support field x from', cx - 2, 'to', cx + 2, JSON.stringify(field));
// nav nodes nearby
const near = nav.nodes.map((n, i) => ({i, d: Math.hypot(n.x - cx, n.z - cz), n})).filter(e => e.d < 4).sort((a, b) => a.d - b.d).slice(0, 6);
console.log('navNodes', JSON.stringify(near.map(e => ({d: +e.d.toFixed(2), x: e.n.x, y: e.n.y, z: e.n.z, edges: nav.edges[e.i].length}))));
// trap floor and colliders
const trapFloor = floorAt(cx, cz, arena);
console.log('trapFloor', trapFloor, 'obstructed at trapFloor', trapFloor === null ? null : obstructed(cx, trapFloor, cz, 0.42, arena));
const owners = [];
for (const source of data.colliderSources) {
  const vs = source.vertices;
  const xs = vs.map(v => v[0]), ys = vs.map(v => v[1]), zs = vs.map(v => v[2]);
  if (cx >= Math.min(...xs) - 0.05 && cx <= Math.max(...xs) + 0.05 && cz >= Math.min(...zs) - 0.05 && cz <= Math.max(...zs) + 0.05) {
    owners.push({id: source.id, path: source.path ?? null, kind: source.kind, walkable: source.walkable,
      y: [Math.min(...ys).toFixed(2), Math.max(...ys).toFixed(2)], x: [Math.min(...xs).toFixed(2), Math.max(...xs).toFixed(2)], z: [Math.min(...zs).toFixed(2), Math.max(...zs).toFixed(2)]});
  }
}
console.log('colliderSources containing XZ', JSON.stringify(owners, null, 1));
// can an actor walk off the deck above into the hole?
const deckNode = near.find(e => e.n.y > 3) ?? near[0];
if (deckNode) {
  const from = {x: deckNode.n.x, y: floorAt(deckNode.n.x, deckNode.n.z, arena) ?? deckNode.n.y, z: deckNode.n.z};
  console.log('walkEdge from deck node to trap XZ', walkEdge(from, {x: cx, y: from.y, z: cz}, arena));
}
// where does the support disappear along the line from the deck to the trap?
for (const n of near.slice(0, 3)) {
  const line = [];
  for (let t = 0; t <= 1.0001; t += 0.1) {
    const x = n.n.x + (cx - n.n.x) * t, z = n.n.z + (cz - n.n.z) * t;
    line.push({x: +x.toFixed(2), z: +z.toFixed(2), floor: floorAt(x, z, arena)});
  }
  console.log('line from node', [n.n.x, n.n.y, n.n.z], JSON.stringify(line.map(l => l.floor)));
}

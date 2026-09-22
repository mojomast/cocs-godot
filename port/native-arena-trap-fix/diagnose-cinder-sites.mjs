// Cinder trap-site attribution: which source colliders produce the blocking
// movement bands at the audited lock centres.
import fs from 'node:fs';
import {readNativeArena} from '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/port/native-arenas/schema.mjs';
import {floorAt, obstructed} from '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/game/core.mjs';

const mapId = process.argv[2] ?? 'cinder-array';
const sites = JSON.parse(process.argv[3]);
const data = readNativeArena(mapId);
const a = data.arena;
const sources = JSON.parse(fs.readFileSync(`/tmp/opencode/tf2/wall-sources-${mapId}.json`, 'utf8'));
const dump = JSON.parse(fs.readFileSync('/tmp/opencode/native-dm-colliders.json', 'utf8'));
const colliders = new Map(dump.find(m => m.id === mapId).colliders.map(c => [c.id, c]));
const segD = (x, z, p, q) => { const dx = q[0] - p[0], dz = q[2] - p[2], l2 = dx * dx + dz * dz; const t = l2 ? Math.max(0, Math.min(1, ((x - p[0]) * dx + (z - p[2]) * dz) / l2)) : 0; return Math.hypot(x - (p[0] + dx * t), z - (p[2] + dz * t)); };

for (const site of sites) {
  const [x, z] = site;
  const y = floorAt(x, z, a);
  console.log(`\n=== site (${x}, ${z}) floor=${y} obstructed42=${obstructed(x, y ?? 0, z, 0.42, a)}`);
  const near = [];
  a.terrain.walls.forEach((w, i) => {
    const d = segD(x, z, w.a, w.b);
    const ylo = Math.min(w.a[1], w.b[1]), yhi = Math.max(w.a[1], w.b[1]);
    if (d < 0.5 && y !== null && y < yhi - 1e-6 && y + 1.8 > ylo + 1e-6) near.push({i, d: +d.toFixed(3), ylo: +ylo.toFixed(2), yhi: +yhi.toFixed(2), a: w.a.map(v => +v.toFixed(2)), b: w.b.map(v => +v.toFixed(2)), source: sources[i]});
  });
  near.sort((p, q) => p.d - q.d);
  for (const n of near.slice(0, 6)) {
    const c = colliders.get(n.source);
    console.log(`  wall#${n.i} d=${n.d} y=[${n.ylo},${n.yhi}] a=${n.a} b=${n.b}`);
    console.log(`      source=${n.source} kind=${c?.kind} walkable=${c?.walkable} path=${c?.path}`);
    if (c) {
      const xs = c.vertices.map(v => v[0]), ys = c.vertices.map(v => v[1]), zs = c.vertices.map(v => v[2]);
      console.log(`      hull x=[${Math.min(...xs).toFixed(2)},${Math.max(...xs).toFixed(2)}] y=[${Math.min(...ys).toFixed(2)},${Math.max(...ys).toFixed(2)}] z=[${Math.min(...zs).toFixed(2)},${Math.max(...zs).toFixed(2)}] nverts=${c.vertices.length}`);
    }
  }
  // support probes around the site
  const probes = [];
  for (const [dx, dz] of [[0, 0], [0.3, 0], [-0.3, 0], [0, 0.3], [0, -0.3], [0.5, 0.5], [-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5]]) {
    const s = floorAt(x + dx, z + dz, a);
    probes.push(`${dx},${dz}:${s === null ? 'null' : s.toFixed(2)}`);
  }
  console.log('  support probes:', probes.join('  '));
}

// Compute the candidate rule metrics for specific cinder movement bands.
import {readNativeArena} from '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/port/native-arenas/schema.mjs';
import {terrainSupportAt} from '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/game/terrain.mjs';
import {floorAt} from '/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/game/core.mjs';

const mapId = process.argv[2] ?? 'cinder-array';
const indices = JSON.parse(process.argv[3]);
const data = readNativeArena(mapId);
const arena = data.arena;
const support = (x, z) => terrainSupportAt(x, z, arena.terrain, Math.PI / 4)?.y ?? null;
const f = (v) => v === null ? 'null' : v.toFixed(2);

for (const i of indices) {
  const w = arena.terrain.walls[i];
  const a = w.a, b = w.b;
  const dx = b[0] - a[0], dz = b[2] - a[2], length = Math.hypot(dx, dz);
  const ux = dx / length, uz = dz / length;
  const nx = -uz, nz = ux;
  const top = Math.max(a[1], b[1]), bottom = Math.min(a[1], b[1]);
  const mid = [(a[0] + b[0]) / 2, (a[2] + b[2]) / 2];
  const left = support(mid[0] - uz * 0.6, mid[1] + ux * 0.6);
  const right = support(mid[0] + uz * 0.6, mid[1] - ux * 0.6);
  const sideMin = (sx, sz) => {
    let low = null;
    for (const [px, pz] of [[a[0] + sx * 0.15, a[2] + sz * 0.15], [a[0] + sx * 0.3, a[2] + sz * 0.3], [a[0] + sx * 0.42, a[2] + sz * 0.42],
      [b[0] + sx * 0.15, b[2] + sz * 0.15], [b[0] + sx * 0.3, b[2] + sz * 0.3], [b[0] + sx * 0.42, b[2] + sz * 0.42],
      [mid[0] + sx * 0.3, mid[1] + sz * 0.3], [a[0] - ux * 0.45 + sx * 0.3, a[2] - uz * 0.45 + sz * 0.3], [b[0] + ux * 0.45 + sx * 0.3, b[2] + uz * 0.45 + sz * 0.3]]) {
      const s = support(px, pz); if (s !== null) low = low === null ? s : Math.min(low, s);
    }
    return low;
  };
  let atMid = -Infinity;
  for (const ox of [0, 0.15, -0.15]) for (const oz of [0, 0.15, -0.15]) atMid = Math.max(atMid, support(mid[0] + ox, mid[1] + oz) ?? -Infinity);
  const endProbe = (p) => Math.max(support(p[0] + nx * 0.2, p[2] + nz * 0.2) ?? -Infinity, support(p[0] - nx * 0.2, p[2] - nz * 0.2) ?? -Infinity);
  const insideEnds = Math.max(endProbe([a[0], 0, a[2]]), endProbe([b[0], 0, b[2]]));
  const insideMid = Math.max(support(mid[0] + nx * 0.2, mid[1] + nz * 0.2) ?? -Infinity, support(mid[0] - nx * 0.2, mid[1] - nz * 0.2) ?? -Infinity);
  const lo = Math.min(left ?? Infinity, right ?? Infinity);
  console.log(`wall#${i} len=${length.toFixed(2)} y=[${bottom.toFixed(2)},${top.toFixed(2)}] left=${f(left)} right=${f(right)}`);
  console.log(`   sideMin(L)=${f(sideMin(-uz, ux))} sideMin(R)=${f(sideMin(uz, -ux))} atMid=${f(Number.isFinite(atMid) ? atMid : null)}`);
  console.log(`   insideMid=${f(Number.isFinite(insideMid) ? insideMid : null)} insideEnds=${f(Number.isFinite(insideEnds) ? insideEnds : null)} lo=${f(Number.isFinite(lo) ? lo : null)}`);
  console.log(`   tests: burial=${(sideMin(-uz, ux) !== null && sideMin(-uz, ux) < top - 1e-6 && top - sideMin(-uz, ux) <= 0.3) || (sideMin(uz, -ux) !== null && sideMin(uz, -ux) < top - 1e-6 && top - sideMin(uz, -ux) <= 0.3)} cappedShort=${atMid >= top - 0.3 && top - bottom <= 2.2} interiorRule=${insideEnds >= top - 0.35 && insideMid >= lo + 0.35 && insideMid <= top - 0.05} overhang=${bottom > lo + 1e-6 && bottom < lo + 1.8 - 1e-6 && top > lo + 1.85 + 1e-6}`);
  // actual floor at the site of the earlier trap next to this band
  const probe = process.argv[4] ? JSON.parse(process.argv[4]) : null;
  if (probe) console.log('   floor at probe', probe, '=', f(floorAt(probe[0], probe[1], arena)));
}

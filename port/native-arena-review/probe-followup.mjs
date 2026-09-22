// Review-lane follow-up: classify the movement-vs-ray disagreement samples
// produced by analyze-geometry.mjs, and inspect the enclosed support pinholes.
//
// For each flagged pair the walkEdge path is re-walked at 0.2 m resolution and
// classified as one of:
//   step>0.30            - a legal step/ledge limit, not a barrier
//   no-support           - the path crosses unsupported ground
//   band-blocks          - the authored wall band itself blocks at the midpoint
//   unexplained          - nothing above explains the block
import {readFileSync, readdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {floorAt, obstructed, walkEdge, rayWorld, navigation} from '../../game/core.mjs';
import {readNativeArena} from '../native-arenas/schema.mjs';
import {NATIVE_ARENA_IDS} from '../native-arenas/catalog.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const logDir = `${ROOT}/port/native-arena-review/logs`;
const latest = readdirSync(logDir).filter(f => f.startsWith('geometry-analysis-')).sort().pop();
const report = JSON.parse(readFileSync(`${logDir}/${latest}`, 'utf8'));
const out = {};
for (const mapId of NATIVE_ARENA_IDS) {
  const arena = readNativeArena(mapId).arena;
  navigation(arena);
  const classified = [];
  for (const sample of report[mapId].wallProbes.samples) {
    const from = {x: sample.x, y: sample.y, z: sample.z};
    const to = {x: sample.to[0], y: sample.to[1], z: sample.to[2]};
    const dist = Math.hypot(to.x - from.x, to.z - from.z);
    const mid = {x: (from.x + to.x) / 2, z: (from.z + to.z) / 2};
    const midFloor = floorAt(mid.x, mid.z, arena);
    const midBlocked = midFloor !== null ? obstructed(mid.x, midFloor, mid.z, 0.42, arena) : null;
    const midSolid = midFloor !== null ? obstructed(mid.x, midFloor, mid.z, 0.06, arena) : null;
    const rays = [0.3, 0.9, 1.5].map(h => {
      const d = {x: (to.x - from.x) / dist, y: (to.y - from.y) / dist, z: (to.z - from.z) / dist};
      return +rayWorld({x: from.x, y: from.y + h, z: from.z}, d, dist, arena).toFixed(2);
    });
    const fromFloor = floorAt(from.x, from.z, arena);
    const toFloor = floorAt(to.x, to.z, arena);
    // Replicate walkEdge's own loop to name the exact blocker.
    let reason = null, at = null, prev = fromFloor, maxStep = 0;
    if (fromFloor !== null && toFloor !== null) {
      const n = Math.max(1, Math.ceil(dist / 0.2));
      for (let i = 0; i <= n; i++) {
        const x = from.x + (to.x - from.x) * i / n, z = from.z + (to.z - from.z) * i / n;
        const y = floorAt(x, z, arena);
        if (y === null) { reason = 'no-support'; at = [+x.toFixed(2), +z.toFixed(2)]; break; }
        if (Math.abs(y - prev) > 0.3) { maxStep = Math.abs(y - prev); reason = 'step'; at = [+x.toFixed(2), +y.toFixed(2), +z.toFixed(2), +Math.abs(y - prev).toFixed(3)]; break; }
        if (obstructed(x, y, z, 0.52, arena)) { reason = 'obstructed-0.52'; at = [+x.toFixed(2), +y.toFixed(2), +z.toFixed(2)]; break; }
        prev = y;
      }
    }
    const passable = reason === null && fromFloor !== null && toFloor !== null;
    const blockedKind = reason === 'obstructed-0.52'
      ? (obstructed(at[0], at[1], at[2], 0.06, arena) ? 'solid-overlap' : 'band-plausible') : reason;
    classified.push({sample, walkEdge: passable, reason, at, blockedKind,
      maxStep: +maxStep.toFixed(3), midBlocked, midSolid, rays, dist: +dist.toFixed(2)});
  }
  out[mapId] = {count: classified.length, reasons: classified.reduce((a, c) => { a[c.reason ?? 'passable'] = (a[c.reason ?? 'passable'] || 0) + 1; return a; }, {}),
    blockedKinds: classified.filter(c => !c.walkEdge).reduce((a, c) => { a[c.blockedKind] = (a[c.blockedKind] || 0) + 1; return a; }, {}),
    wallOrSolidBlocks: classified.filter(c => c.blockedKind === 'band-plausible' || c.blockedKind === 'solid-overlap').slice(0, 15),
    unexplainable: classified.filter(c => c.reason === null && c.walkEdge === false).slice(0, 15),
    holes: report[mapId].support.enclosedHoleGroups.map(h => {
      const arena2 = report[mapId];
      const probe = {x: h.center[0], z: h.center[1]};
      const support = floorAt(probe.x, probe.z, arena);
      const ring = [];
      for (const [dx, dz] of [[0.5, 0], [-0.5, 0], [0, 0.5], [0, -0.5]]) {
        const y = floorAt(probe.x + dx, probe.z + dz, arena);
        ring.push(y === null ? null : +y.toFixed(3));
      }
      return {...h, centerFloor: support, neighbourFloors: ring};
    })};
}
const outPath = `${logDir}/probe-followup-${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
writeFileSync(outPath, `${JSON.stringify(out, null, 2)}\n`);
console.log(JSON.stringify({source: latest, outPath, summary: Object.fromEntries(Object.entries(out).map(([k, v]) => [k, {kinds: v.kinds, holes: v.holes.map(h => ({area: h.approxArea, center: h.center, centerFloor: h.centerFloor, neighbours: h.neighbourFloors}))}]))}, null, 1));

// Independent structural review of the three delivered native arena assets.
//
// Review-lane only. Reads godot/native_arenas/generated/*.json and evaluates it
// with the delivered source physics consumers (floorAt/obstructed/walkEdge/
// rayWorld/navigation). Writes logs into port/native-arena-review/logs/.
//
// Checks (none of them reuse the geometry generator's own assertions):
//   A. envelope geometryHash re-derived with an independent canonicalizer.
//   B. walkable-support grid: floor gaps / enclosed holes inside the play area.
//   C. spawn + pickup legality, support agreement and nav reachability.
//   D. authored DM routes: support agreement and walkEdge continuity.
//   E. nav graph connectivity and bot-usable node filtering.
//   F. wall movement bands vs exported collider geometry: invisible barriers.
//   G. targeted probes across wall bands: movement vs ray disagreement.
import {mkdirSync, writeFileSync, appendFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, resolve} from 'node:path';
import {floorAt, obstructed, walkEdge, rayWorld, navigation} from '../../game/core.mjs';
import {readNativeArena} from '../native-arenas/schema.mjs';
import {NATIVE_ARENA_IDS} from '../native-arenas/catalog.mjs';
import {sha256, quantile} from './lib/self-check.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const logDir = `${ROOT}/port/native-arena-review/logs`;
mkdirSync(logDir, {recursive: true});
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const out = {...(process.argv.includes('--quiet') ? {} : {})};

const REPORT = {};

function trianglesOf(terrain) {
  const tris = [];
  const addSurface = (surface, walkableDefault) => {
    const verts = surface.vertices;
    const walkable = surface.walkable ?? walkableDefault;
    for (const [i, j, k] of surface.triangles ?? []) {
      tris.push({surfaceId: surface.id, walkable, vertices: [verts[i], verts[j], verts[k]]});
    }
  };
  for (const surface of terrain.surfaces) addSurface(surface, surface.walkable !== false);
  for (const wall of terrain.walls) if (Array.isArray(wall.vertices) && Array.isArray(wall.triangles)) addSurface(wall, false);
  return tris;
}

for (const mapId of NATIVE_ARENA_IDS) {
  const t0 = Date.now();
  const data = readNativeArena(mapId);
  const arena = data.arena;
  // navigation() also bakes the arena floor query, so every later floorAt call
  // runs against the same baked structure the source Match uses.
  const nav = navigation(arena);
  const bounds = arena.bounds;
  const report = {mapId, geometryHash: data.geometryHash,
    hashVerified: sha256(arena) === data.geometryHash,
    nextGen: arena.nextGen === true,
    counts: {surfaces: arena.terrain.surfaces.length, wallSegments: arena.terrain.walls.filter(w => w.a).length,
      wallMeshes: arena.terrain.walls.filter(w => w.triangles).length,
      navNodes: arena.navNodes.length, spawns: arena.spawns.length, pickups: arena.pickups.length, routes: data.routes.length,
      colliderSources: data.colliderSources.length}};
  const issues = [];
  const issue = (kind, detail) => issues.push({kind, ...detail});

  // ---- A. hash is already recomputed above (independent canonicalizer).

  // ---- B. support grid and enclosed holes.
  const step = 0.5;
  const gx0 = Math.ceil(bounds.minX / step) * step, gx1 = Math.floor(bounds.maxX / step) * step;
  const gz0 = Math.ceil(bounds.minZ / step) * step, gz1 = Math.floor(bounds.maxZ / step) * step;
  const cols = Math.round((gx1 - gx0) / step) + 1, rows = Math.round((gz1 - gz0) / step) + 1;
  const support = new Float64Array(cols * rows).fill(Number.NaN);
  let supported = 0, unsupported = 0;
  for (let ix = 0; ix < cols; ix++) for (let iz = 0; iz < rows; iz++) {
    const y = floorAt(gx0 + ix * step, gz0 + iz * step, arena);
    const idx = ix * rows + iz;
    if (y === null) unsupported++; else { support[idx] = y; supported++; }
  }
  const at = (ix, iz) => (ix < 0 || iz < 0 || ix >= cols || iz >= rows) ? null : support[ix * rows + iz];
  const holeCells = [];
  for (let ix = 1; ix < cols - 1; ix++) for (let iz = 1; iz < rows - 1; iz++) {
    if (!Number.isNaN(at(ix, iz))) continue;
    // enclosed: 8-neighbourhood supported and a 3.0 m ring mostly supported
    let ring8 = 0;
    for (let dx = -1; dx <= 1; dx++) for (let dz = -1; dz <= 1; dz++) if (!Number.isNaN(at(ix + dx, iz + dz))) ring8++;
    if (ring8 < 8) continue;
    let ring = 0, ringCount = 0;
    for (let a = 0; a < 16; a++) {
      const ang = a / 16 * Math.PI * 2;
      const jx = Math.round(ix + Math.cos(ang) * (3 / step)), jz = Math.round(iz + Math.sin(ang) * (3 / step));
      const v = at(jx, jz); ringCount++; if (v !== null) ring++;
    }
    if (ring >= ringCount - 1) holeCells.push({ix, iz, x: +(gx0 + ix * step).toFixed(2), z: +(gz0 + iz * step).toFixed(2)});
  }
  // group holes into components
  const holeSet = new Set(holeCells.map(h => `${h.ix}|${h.iz}`));
  const holeGroups = [];
  const seen = new Set();
  for (const cell of holeCells) {
    const key = `${cell.ix}|${cell.iz}`;
    if (seen.has(key)) continue;
    const q = [cell], group = [];
    seen.add(key);
    while (q.length) {
      const c = q.pop(); group.push(c);
      for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) {
        const k = `${c.ix + dx}|${c.iz + dz}`;
        if (holeSet.has(k) && !seen.has(k)) { seen.add(k); q.push({ix: c.ix + dx, iz: c.iz + dz, x: gx0 + (c.ix + dx) * step, z: gz0 + (c.iz + dz) * step}); }
      }
    }
    const cx = group.reduce((s, c) => s + c.x, 0) / group.length, cz = group.reduce((s, c) => s + c.z, 0) / group.length;
    holeGroups.push({cells: group.length, approxArea: +(group.length * step * step).toFixed(2), center: [+cx.toFixed(2), +cz.toFixed(2)]});
  }
  holeGroups.sort((a, b) => b.cells - a.cells);
  report.support = {gridStep: step, cols, rows, supportedCells: supported, unsupportedCells: unsupported,
    enclosedHoleGroups: holeGroups.slice(0, 12), enclosedHoleTotal: holeGroups.length,
    largestEnclosedHoleArea: holeGroups[0]?.approxArea ?? 0};
  if (holeGroups.some(g => g.approxArea > 2)) issue('enclosed-floor-hole', {groups: holeGroups.filter(g => g.approxArea > 2).slice(0, 6)});

  // ---- C. spawn + pickup legality and reachability.
  const comp = new Int32Array(nav.nodes.length).fill(-1);
  const comps = [];
  for (let s = 0; s < nav.nodes.length; s++) {
    if (comp[s] >= 0) continue;
    const id = comps.length, list = [], q = [s];
    comp[s] = id;
    for (let head = 0; head < q.length; head++) {
      const n = q[head]; list.push(n);
      for (const j of nav.edges[n]) if (comp[j] < 0) { comp[j] = id; q.push(j); }
    }
    comps.push(list);
  }
  const nearestNode = p => {
    let best = -1, bd = Infinity;
    nav.nodes.forEach((n, i) => { const d = Math.hypot(n.x - p.x, n.z - p.z); if (d < bd) { bd = d; best = i; } });
    return {index: best, dist: bd};
  };
  const spawnReports = arena.spawns.map(([x, z], i) => {
    const y = floorAt(x, z, arena);
    const node = nearestNode({x, z});
    return {index: i, x, z, floor: y === null ? null : +y.toFixed(3), authoredY: data.spawnPoints[i]?.y,
      heightAgreement: y === null ? null : +(y - (data.spawnPoints[i]?.y ?? 0)).toFixed(3),
      obstructed42: obstructed(x, y ?? 0, z, 0.42, arena), nearestNavNode: node.dist === Infinity ? null : +node.dist.toFixed(2),
      nodeComponent: node.index >= 0 ? comp[node.index] : null,
      reachableFromSpawn0: node.index >= 0 && comp[node.index] === comp[nearestNode({x: arena.spawns[0][0], z: arena.spawns[0][1]}).index]};
  });
  const pickupReports = arena.pickups.map(([kind, x, z], i) => {
    const y = floorAt(x, z, arena);
    const node = nearestNode({x, z});
    return {index: i, kind, x, z, floor: y === null ? null : +y.toFixed(3), obstructed42: y === null ? null : obstructed(x, y, z, 0.42, arena),
      nearestNavNode: node.dist === Infinity ? null : +node.dist.toFixed(2),
      nodeComponent: node.index >= 0 ? comp[node.index] : null,
      reachableFromSpawn0: node.index >= 0 && comp[node.index] === comp[nearestNode({x: arena.spawns[0][0], z: arena.spawns[0][1]}).index]};
  });
  report.spawns = spawnReports;
  report.pickups = pickupReports;
  report.nav = {nodes: nav.nodes.length, edges: nav.edges.reduce((n, e) => n + e.length, 0),
    components: comps.map(c => c.length).sort((a, b) => b - a).slice(0, 6), componentCount: comps.length,
    botUsableNodes: nav.nodes.filter(n => { const y = floorAt(n.x, n.z, arena); return y !== null && !obstructed(n.x, y, n.z, 0.378, arena); }).length,
    authoredNavNodesUnsupported: arena.navNodes.filter(([x, z]) => floorAt(x, z, arena) === null).length};
  for (const s of spawnReports) {
    if (s.floor === null) issue('spawn-without-support', s);
    else if (Math.abs(s.heightAgreement) > 0.15) issue('spawn-height-mismatch', s);
    if (s.obstructed42) issue('spawn-obstructed', s);
    if (s.reachableFromSpawn0 === false) issue('spawn-unreachable', s);
  }
  for (const p of pickupReports) {
    if (p.floor === null) issue('pickup-without-support', p);
    else if (p.obstructed42) issue('pickup-obstructed', p);
    if (p.reachableFromSpawn0 === false) issue('pickup-unreachable', p);
  }

  // ---- D. authored routes.
  const routeReports = [];
  for (const route of data.routes) {
    let badSupport = 0, badHeight = 0, badEdge = 0, blocked = 0, worstHeight = 0, worstEdge = null, worstSupport = null;
    for (let i = 0; i < route.points.length; i++) {
      const p = route.points[i];
      const y = floorAt(p.x, p.z, arena);
      if (y === null) { badSupport++; worstSupport = worstSupport ?? p; continue; }
      const dh = Math.abs(y - p.y);
      if (dh > worstHeight) worstHeight = dh;
      if (dh > 0.3) { badHeight++; }
      if (obstructed(p.x, y, p.z, 0.42, arena)) blocked++;
      if (i > 0) {
        const prev = route.points[i - 1];
        const py = floorAt(prev.x, prev.z, arena);
        if (py !== null && !walkEdge({x: prev.x, y: py, z: prev.z}, {x: p.x, y, z: p.z}, arena)) { badEdge++; worstEdge = worstEdge ?? {from: prev, to: p}; }
      }
    }
    routeReports.push({id: route.id, points: route.points.length, badSupport, badHeight, badEdge, blockedPoints: blocked,
      worstHeightDelta: +worstHeight.toFixed(3), worstSupport, worstEdge});
    if (badSupport || badHeight || badEdge || blocked) issue('route-defect', {route: route.id, badSupport, badHeight, badEdge, blocked});
  }
  report.routes = routeReports;

  // ---- F. wall movement bands vs exported collider geometry.
  const colliderTris = trianglesOf(arena.terrain);
  const cellSize = 1.6;
  const grid = new Map();
  const keyOf = (x, z) => `${Math.floor(x / cellSize)}|${Math.floor(z / cellSize)}`;
  colliderTris.forEach((t, ti) => {
    const xs = t.vertices.map(v => v[0]), zs = t.vertices.map(v => v[2]);
    const ymin = Math.min(...t.vertices.map(v => v[1])), ymax = Math.max(...t.vertices.map(v => v[1]));
    for (let cx = Math.floor(Math.min(...xs) / cellSize); cx <= Math.floor(Math.max(...xs) / cellSize); cx++)
      for (let cz = Math.floor(Math.min(...zs) / cellSize); cz <= Math.floor(Math.max(...zs) / cellSize); cz++) {
        const key = `${cx}|${cz}`;
        if (!grid.has(key)) grid.set(key, []);
        grid.get(key).push({ti, ymin, ymax});
      }
  });
  const nearTris = (x, z, radius) => {
    const found = new Set();
    for (let cx = Math.floor((x - radius) / cellSize); cx <= Math.floor((x + radius) / cellSize); cx++)
      for (let cz = Math.floor((z - radius) / cellSize); cz <= Math.floor((z + radius) / cellSize); cz++) {
        const bucket = grid.get(`${cx}|${cz}`);
        if (bucket) for (const e of bucket) found.add(e.ti);
      }
    return [...found];
  };
  const pointTriDist = (px, pz, t) => {
    // 2D point/triangle distance in XZ (exact enough: distance to the 3 edges)
    let best = Infinity;
    for (let i = 0; i < 3; i++) {
      const a = t.vertices[i], b = t.vertices[(i + 1) % 3];
      const ax = a[0], az = a[2], bx = b[0], bz = b[2];
      const vx = bx - ax, vz = bz - az, wx = px - ax, wz = pz - az;
      const L = vx * vx + vz * vz;
      const tt = L > 0 ? Math.max(0, Math.min(1, (wx * vx + wz * vz) / L)) : 0;
      best = Math.min(best, Math.hypot(px - (ax + vx * tt), pz - (az + vz * tt)));
    }
    return best;
  };
  const asPoint = (p, label) => {
    if (Array.isArray(p)) return {x: p[0], y: p[1], z: p[2]};
    if (p && Number.isFinite(p.x) && Number.isFinite(p.y) && Number.isFinite(p.z)) return {x: p.x, y: p.y, z: p.z};
    throw new TypeError(`Unsupported ${label} point: ${JSON.stringify(p)}`);
  };
  const wallSegments = [];
  for (const wall of arena.terrain.walls) {
    if (wall.a) wallSegments.push({a: asPoint(wall.a, 'wall.a'), b: asPoint(wall.b, 'wall.b'), material: wall.material, mesh: false});
    else if (Array.isArray(wall.vertices) && wall.triangles) {
      for (const [i, j, k] of wall.triangles) {
        const v = [wall.vertices[i], wall.vertices[j], wall.vertices[k]];
        for (let e = 0; e < 3; e++) {
          const p = v[e], q = v[(e + 1) % 3];
          const ylo = Math.min(p[1], q[1]), yhi = Math.max(p[1], q[1]);
          if (Math.abs(yhi - ylo) > 0.05) wallSegments.push({a: {x: p[0], y: p[1], z: p[2]}, b: {x: q[0], y: q[1], z: q[2]}, mesh: true, ylo, yhi});
        }
      }
    }
  }
  let sampled = 0, farSamples = [], farSamplesTotal = 0;
  for (const seg of wallSegments) {
    const len = Math.hypot(seg.b.x - seg.a.x, seg.b.z - seg.a.z);
    if (len < 0.05) continue;
    const ylo = Math.min(seg.a.y, seg.b.y), yhi = Math.max(seg.a.y, seg.b.y);
    // walking-scale bands only (a barrier that sits below/above the capsule is
    // not a walking invisible wall)
    if (ylo < arena.voidY || ylo > arena.ceilingY - 1.0) continue;
    if (yhi - ylo > 3.0) continue;
    const n = Math.max(1, Math.ceil(len / 0.4));
    for (let i = 0; i <= n; i++) {
      const x = seg.a.x + (seg.b.x - seg.a.x) * i / n, z = seg.a.z + (seg.b.z - seg.a.z) * i / n;
      sampled++;
      const cands = nearTris(x, z, 0.9);
      let min = Infinity;
      for (const ti of cands) {
        const t = colliderTris[ti];
        if (t.vertices.every(v => v[1] < ylo - 0.3) || t.vertices.every(v => v[1] > yhi + 0.3)) continue;
        min = Math.min(min, pointTriDist(x, z, t));
        if (min <= 0.6) break;
      }
      if (min > 0.9) { farSamplesTotal++; if (farSamples.length < 40) farSamples.push({x: +x.toFixed(2), y: +((ylo + yhi) / 2).toFixed(2), z: +z.toFixed(2), nearestColliderDistance: min === Infinity ? '>0.9' : +min.toFixed(2)}); }
    }
  }
  report.wallBands = {sampled, withoutNearbyColliderGeometry: farSamplesTotal,
    sampleShare: +(farSamplesTotal / Math.max(sampled, 1)).toFixed(4), samples: farSamples};
  if (farSamplesTotal > sampled * 0.02) issue('invisible-wall-candidates', {total: farSamplesTotal, sampled, samples: farSamples.slice(0, 10)});

  // ---- G. targeted movement vs ray probes across wall bands.
  let probed = 0, movementBlockedRayClear = [], walkableRayBlocked = [], clearedFloorBlocker = [];
  const probeDirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];
  const seenProbe = new Set();
  for (const seg of wallSegments) {
    const mid = {x: (seg.a.x + seg.b.x) / 2, z: (seg.a.z + seg.b.z) / 2};
    const ylo = Math.min(seg.a.y, seg.b.y), yhi = Math.max(seg.a.y, seg.b.y);
    if (yhi - ylo > 3.0) continue;
    const len = Math.hypot(seg.b.x - seg.a.x, seg.b.z - seg.a.z);
    if (len < 0.4) continue;
    const nx = -(seg.b.z - seg.a.z) / len, nz = (seg.b.x - seg.a.x) / len;
    for (const side of [1, -1]) {
      const px = mid.x + nx * side * 0.62, pz = mid.z + nz * side * 0.62;
      const py = floorAt(px, pz, arena);
      if (py === null) continue;
      const qx = mid.x + nx * side * 1.45, qz = mid.z + nz * side * 1.45;
      const qy = floorAt(qx, qz, arena);
      if (qy === null) continue;
      const key = `${Math.round(px * 2)}|${Math.round(pz * 2)}`;
      if (seenProbe.has(key)) continue;
      seenProbe.add(key);
      probed++;
      const passable = walkEdge({x: px, y: py, z: pz}, {x: qx, y: qy, z: qz}, arena);
      const dist = Math.hypot(qx - px, qz - pz);
      const rayClear = [0.3, 0.9, 1.5].every(h => rayWorld({x: px, y: py + h, z: pz}, {x: (qx - px) / dist, y: (qy - py) / dist, z: (qz - pz) / dist}, dist, arena) >= dist - 0.05);
      const blockedAtChest = rayWorld({x: px, y: py + 0.9, z: pz}, {x: (qx - px) / dist, y: (qy - py) / dist, z: (qz - pz) / dist}, dist, arena) < dist - 0.25;
      if (!passable && rayClear) { if (movementBlockedRayClear.length < 40) movementBlockedRayClear.push({x: +px.toFixed(2), y: +py.toFixed(2), z: +pz.toFixed(2), to: [+qx.toFixed(2), +qy.toFixed(2), +qz.toFixed(2)], bandY: [+ylo.toFixed(2), +yhi.toFixed(2)]}); }
      if (passable && blockedAtChest) { if (walkableRayBlocked.length < 40) walkableRayBlocked.push({x: +px.toFixed(2), y: +py.toFixed(2), z: +pz.toFixed(2), to: [+qx.toFixed(2), +qy.toFixed(2), +qz.toFixed(2)], bandY: [+ylo.toFixed(2), +yhi.toFixed(2)]}); }
    }
  }
  report.wallProbes = {probed, movementBlockedRayClear: movementBlockedRayClear.length, samples: movementBlockedRayClear,
    walkableRayBlocked: walkableRayBlocked.length, walkableSamples: walkableRayBlocked};
  if (movementBlockedRayClear.length) issue('movement-barrier-without-boundary', {count: movementBlockedRayClear.length, samples: movementBlockedRayClear.slice(0, 6)});
  if (walkableRayBlocked.length) issue('passable-rendered-cover', {count: walkableRayBlocked.length, samples: walkableRayBlocked.slice(0, 6)});

  report.durationMs = Date.now() - t0;
  report.issueCount = issues.length;
  report.issues = issues.slice(0, 60);
  REPORT[mapId] = report;
  console.log(JSON.stringify({mapId, hashVerified: report.hashVerified, nextGen: report.nextGen,
    holes: report.support.enclosedHoleTotal, largestHole: report.support.largestEnclosedHoleArea,
    navComponents: report.nav.componentCount, botUsable: report.nav.botUsableNodes + '/' + report.nav.nodes,
    spawnIssues: report.spawns.filter(s => s.floor === null || s.obstructed42 || s.reachableFromSpawn0 === false).length,
    pickupIssues: report.pickups.filter(p => p.floor === null || p.obstructed42 || p.reachableFromSpawn0 === false).length,
    routeIssues: report.routes.filter(r => r.badSupport || r.badHeight || r.badEdge || r.blockedPoints).length,
    wallBands: report.wallBands, wallProbes: {probed, blocked: report.wallProbes.movementBlockedRayClear, passable: report.wallProbes.walkableRayBlocked},
    issueKinds: issues.reduce((a, i) => { a[i.kind] = (a[i.kind] || 0) + 1; return a; }, {}), ms: report.durationMs}));
}

const outPath = `${logDir}/geometry-analysis-${stamp}.json`;
writeFileSync(outPath, `${JSON.stringify(REPORT, null, 2)}\n`);
console.log(JSON.stringify({report: outPath}));

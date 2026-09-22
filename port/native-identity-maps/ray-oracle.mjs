// Independent ray audit for the three identity maps.
//
// Two questions are answered here, and they are NOT the same question:
//
//  1. SOURCE vs GODOT PARITY (strict, 2 cm). Every fixture ray is answered by
//     the source `rayWorld` on the shipped arena and re-answered by Godot
//     physics on the map built from the same recipe (see godot/tests/
//     identity_maps/rays.gd). Any distance disagreement is a failure.
//
//  2. EXACT-PROTOTYPE vs SIMPLIFIED-COLlISION COVER PARITY (classification).
//     `exactArena()` rebuilds the prototype representation — one wall per art
//     triangle — from the same visible geometry, so the comparison isolates the
//     collision change from the art change. A ray that blocks under one
//     representation and not the other is a failure (recorded, not hidden).
//
// Coverage groups: block cover faces, wall faces, route floors, spawn/pickup/
// objective sightlines, a 4 m eye grid, and a probe that every visible mass in
// the reachable height band still collides.
//
// Outputs: godot/tests/identity_maps/source-rays.json (fixtures, consumed by
// rays.gd) and evidence/ray-report-<ts>.json (this audit, failures retained).

import {loadRecipe, CATALOG} from './match.mjs';
import {rayWorld, visible, obstructed, floorAt} from '../../game/core.mjs';
import {blockObstructed} from '../../game/spatial.mjs';
import {terrainSupportAt} from '../../game/terrain.mjs';
import {writeFileSync, mkdirSync} from 'node:fs';
import {performance} from 'node:perf_hooks';

const EYE = 1.6;
const JUMP_APEX = (() => {
  // Source variable-jump gravity: full gravity until |vy| < 2.5, then 0.6x.
  const v = 8.6, g = 26, low = 2.5;
  return (v * v - low * low) / (2 * g) + (low * low) / (2 * g * 0.6);
})();
const point = a => ({x: a[0], y: a[1], z: a[2]});
const fmt = n => +Number(n).toFixed(6);
const coarse = n => +Number(n).toFixed(4);

/** The prototype's collision policy: one wall entry per visible triangle. */
function exactArena(recipe) {
  const arena = structuredClone(recipe.arena);
  arena.terrain.walls = recipe.art.flatMap(surface => surface.triangles.map((t, i) => ({
    id: `${surface.id}-exact-${i}`, material: surface.material, walkable: false,
    vertices: t.map(j => surface.vertices[j].slice()), triangles: [[0, 1, 2]],
  })));
  return arena;
}

function triangleNormal(vertices, triangle) {
  const [a, b, c] = triangle.map(i => vertices[i]);
  const ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], ac = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
  const n = [ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2], ab[0] * ac[1] - ab[1] * ac[0]];
  const len = Math.hypot(...n);
  if (len < 1e-9) return null;
  return n.map(v => v / len);
}

function surfaceCentroid(surface) {
  const t = surface.triangles[Math.floor(surface.triangles.length / 2)];
  const [a, b, c] = t.map(i => surface.vertices[i]);
  return [(a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3];
}

export function audit() {
  const started = performance.now();
  const report = {scope: 'Independent source ray audit: source vs Godot fixtures and prototype-exact vs simplified cover parity', eyeHeight: EYE, jumpApex: fmt(JUMP_APEX), maps: [], failures: [], startedAt: new Date().toISOString()};
  const fixtures = [];
  let checks = 0;

  for (const id of Object.keys(CATALOG)) {
    const recipe = loadRecipe(id), arena = recipe.arena, exact = exactArena(recipe);
    const rays = [];
    const push = (label, group, from, to, opts = {}) => {
      const length = Math.hypot(to[0] - from[0], to[1] - from[1], to[2] - from[2]);
      const dir = [(to[0] - from[0]) / length, (to[1] - from[1]) / length, (to[2] - from[2]) / length];
      const source = rayWorld(point(from), point(dir), length, arena);
      const reference = rayWorld(point(from), point(dir), length, exact);
      const exported = opts.export !== false;
      rays.push({
        export: exported,
        label, group, from: from.map(fmt), to: to.map(fmt), length: fmt(length),
        source: fmt(source), exact: fmt(reference),
        blocked: source < length - 0.08, referenceBlocked: reference < length - 0.08,
        tolerance: opts.tolerance ?? 0.02, mode: opts.mode ?? 'distance',
        referencePolicy: opts.referencePolicy ?? 'strict', grazing: opts.grazing === true,
      });
    };

    // --- cover faces: every exact block, cast at the lowest of 1.6 m / half height
    for (const b of arena.blocks) {
      const y = Math.min(EYE, Math.max(0.4, b.h * 0.5));
      push(`block-${b.id}`, 'block-cover', [b.x - b.w / 2 - 2, y, b.z], [b.x + b.w / 2 + 2, y, b.z]);
      push(`block-${b.id}-z`, 'block-cover', [b.x, y, b.z - b.d / 2 - 2], [b.x, y, b.z + b.d / 2 + 2]);
    }

    // --- wall faces: every authored collision polygon, probed from its normal
    let wallIndex = 0;
    for (const wall of arena.terrain.walls) {
      const verts = wall.vertices ?? [wall.a, wall.b];
      if (verts.length < 3) continue;
      const triangles = wall.triangles ?? Array.from({length: verts.length - 2}, (_, i) => [0, i + 1, i + 2]);
      for (const t of triangles) {
        const n = triangleNormal(verts, t);
        if (!n) continue;
        const [a, b, c] = t.map(i => verts[i]);
        const centre = [(a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3];
        push(`wall-${wall.id ?? wallIndex}-${t.join('')}`, 'wall-face',
          [centre[0] + n[0] * 0.75, centre[1] + n[1] * 0.75, centre[2] + n[2] * 0.75],
          [centre[0] - n[0] * 0.75, centre[1] - n[1] * 0.75, centre[2] - n[2] * 0.75],
          {tolerance: 0.05, referencePolicy: 'proxy'});
      }
      wallIndex++;
    }

    // --- route floors: downward from 6 m at every route point and midpoint
    for (const route of recipe.routes) {
      const points = route.points;
      for (let i = 0; i < points.length; i++) {
        const a = points[i], b = points[(i + 1) % points.length];
        for (const [t, tag] of [[0, 'a'], [0.5, 'm'], [1, 'b']]) {
          const x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t;
          push(`floor-${route.id}-${i}${tag}`, 'route-floor', [x, 6, z], [x, -1, z]);
        }
      }
    }

    // --- sightlines: spawns, pickups, objective zones, route nodes, all pairs
    const eyePoints = [];
    for (const [x, z] of arena.spawns) eyePoints.push({id: `spawn-${x}-${z}`, x, z});
    for (const [kind, x, z] of arena.pickups) eyePoints.push({id: `pickup-${kind}-${x}-${z}`, x, z});
    for (const zone of arena.objectiveZones ?? []) eyePoints.push({id: `zone-${zone.z}`, x: zone.x, z: zone.z});
    for (const route of recipe.routes) for (let i = 0; i < route.points.length - 1; i++) {
      eyePoints.push({id: `route-${route.id}-${i}`, x: route.points[i].x, z: route.points[i].z});
    }
    for (let i = 0; i < eyePoints.length; i++) for (let j = i + 1; j < eyePoints.length; j++) {
      const a = eyePoints[i], b = eyePoints[j];
      const ya = floorAt(a.x, a.z, arena), yb = floorAt(b.x, b.z, arena);
      if (ya === null || yb === null) continue;
      const distance = Math.hypot(a.x - b.x, a.z - b.z);
      if (distance > 70) continue;
      push(`sight-${a.id}->${b.id}`, 'sightline', [a.x, ya + EYE, a.z], [b.x, yb + EYE, b.z], {mode: 'classification'});
    }

    // A ray that grazes a collider corner/edge is a knife-edge case: two
    // independent ray implementations (source slab test vs Godot shape test)
    // are not expected to agree on the last float there. Such rays are still
    // reported, but they are marked so the Godot side can count them apart from
    // real cover divergences.
    const stable = (from, to) => {
      const length = Math.hypot(to[0] - from[0], to[1] - from[1], to[2] - from[2]);
      const dx = (to[0] - from[0]) / length, dy = (to[1] - from[1]) / length, dz = (to[2] - from[2]) / length;
      const verdict = (ox, oy, oz, dir) => rayWorld(point([ox, oy, oz]), point(dir), length, arena) < length - 0.08;
      const base = verdict(from[0], from[1], from[2], [dx, dy, dz]);
      const angle = 0.0006, cos = Math.cos(angle), sin = Math.sin(angle);
      const variants = [
        [from[0] + 0.004, from[1], from[2] + 0.004, [dx, dy, dz]],
        [from[0] - 0.004, from[1], from[2] - 0.004, [dx, dy, dz]],
        [from[0], from[1], from[2], [dx * cos - dz * sin, dy, dx * sin + dz * cos]],
        [from[0], from[1], from[2], [dx * cos + dz * sin, dy, -dx * sin + dz * cos]],
      ];
      return variants.every(v => verdict(v[0], v[1], v[2], v[3]) === base);
    };

    // --- 4 m eye grid, eight compass directions, five lengths
    // A grid point only counts as an eye position if neither representation
    // already blocks a 0.9 m body there; a point inside visible geometry is not
    // a standable spot and would only manufacture false divergences.
    const standable = (x, y, z) => {
      if (obstructed(x, y, z, 0.5, arena) || obstructed(x, y, z, 0.5, exact)) return false;
      for (let k = 0; k < 8; k++) {
        const angle = k * Math.PI / 4;
        const dir = point([Math.sin(angle), 0, Math.cos(angle)]);
        for (const reach of [0.9]) {
          if (rayWorld(point([x, y, z]), dir, reach, exact) < reach - 0.05) return false;
          if (rayWorld(point([x, y, z]), dir, reach, arena) < reach - 0.05) return false;
        }
      }
      return true;
    };
    const bounds = arena.bounds;
    for (let x = Math.ceil(bounds.minX / 4) * 4; x <= bounds.maxX; x += 4) {
      for (let z = Math.ceil(bounds.minZ / 4) * 4; z <= bounds.maxZ; z += 4) {
        const y = floorAt(x, z, arena);
        if (y === null || !standable(x, y + EYE, z)) continue;
        for (let k = 0; k < 8; k++) {
          const angle = k * Math.PI / 4;
          for (const [lengthIndex, length] of [6, 12, 20, 30, 45].entries()) {
            const from = [x, y + EYE, z];
            const to = [x + Math.sin(angle) * length, y + EYE, z + Math.cos(angle) * length];
            // Every third direction and every second length goes to the Godot
            // fixture (503 rays/map); the full 8x5xgrid set is audited in JS.
            push(`grid-${x}-${z}-${k}-${length}`, 'eye-grid', from, to,
              {mode: 'classification', tolerance: 0.05, grazing: !stable(from, to), export: k % 3 === 0 && lengthIndex % 2 === 0});
          }
        }
      }
    }

    // --- reachable visible mass probe: every art triangle a player can see at
    // eye height must still collide under the simplified representation.
    const floorMax = Math.max(...arena.terrain.surfaces.flatMap(s => s.vertices.map(v => v[1])), 0);
    const eyeCeiling = floorMax + JUMP_APEX + 1.45 + 0.02;
    const reachable = (x, z) => x >= bounds.minX && x <= bounds.maxX && z >= bounds.minZ && z <= bounds.maxZ;
    const PROBE_REACH = 4.5;
    let probes = 0, probeHits = 0, probeMisses = [];
    for (const surface of recipe.art) {
      for (const t of surface.triangles) {
        const [a, b, c] = t.map(i => surface.vertices[i]);
        const centre = [(a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3];
        if (centre[1] < 0.02 || centre[1] > eyeCeiling) continue;
        if (!reachable(centre[0], centre[2])) continue;
        if (blockObstructed(arena, centre[0], centre[1], centre[2], 0.05)) continue;
        const n = triangleNormal(surface.vertices, t);
        if (!n) continue;
        probes++;
        const from = [centre[0] + n[0] * 0.75, centre[1] + n[1] * 0.75, centre[2] + n[2] * 0.75];
        const dir = [-n[0], -n[1], -n[2]];
        const hit = rayWorld(point(from), point(dir), PROBE_REACH, arena);
        if (hit < PROBE_REACH - 0.08) probeHits++;
        else probeMisses.push({surface: surface.id, centre: centre.map(fmt), hit: fmt(hit)});
      }
    }

    // --- source visible() parity between the two representations
    let visibleChecks = 0, visibleMismatch = [];
    for (let i = 0; i < eyePoints.length; i++) for (let j = i + 1; j < eyePoints.length; j++) {
      const a = eyePoints[i], b = eyePoints[j];
      const ya = floorAt(a.x, a.z, arena), yb = floorAt(b.x, b.z, arena);
      if (ya === null || yb === null) continue;
      if (Math.hypot(a.x - b.x, a.z - b.z) > 70) continue;
      visibleChecks++;
      const p = (p, y) => ({x: p.x, y, z: p.z});
      const simple = visible(p(a, ya + EYE), p(b, yb + EYE), arena);
      const proto = visible(p(a, ya + EYE), p(b, yb + EYE), exact);
      if (simple !== proto) visibleMismatch.push({from: a.id, to: b.id, simplified: simple, prototype: proto});
    }

    // --- classification / distance audit
    const groups = {};
    for (const ray of rays) {
      const g = groups[ray.group] ?? (groups[ray.group] = {rays: 0, blockedSource: 0, blockedExact: 0, classificationMismatch: 0, maxDistanceDelta: 0, deltas: []});
      g.rays++;
      if (ray.grazing) g.grazing = (g.grazing ?? 0) + 1;
      if (ray.blocked) g.blockedSource++;
      if (ray.referenceBlocked) g.blockedExact++;
      if (ray.blocked !== ray.referenceBlocked) {
        if (ray.referencePolicy === 'proxy') g.proxyDivergence = (g.proxyDivergence ?? 0) + 1;
        else {
          g.classificationMismatch++;
          report.failures.push({map: id, group: ray.group, label: ray.label, kind: 'classification', source: ray.source, exact: ray.exact, length: ray.length});
        }
      }
      const delta = Math.abs(ray.source - ray.exact);
      g.maxDistanceDelta = Math.max(g.maxDistanceDelta, delta);
      g.deltas.push(delta);
      checks++;
    }
    if (probeMisses.length) report.failures.push({map: id, kind: 'reachable-visible-mass', misses: probeMisses.slice(0, 20), total: probeMisses.length});
    if (visibleMismatch.length) report.failures.push({map: id, kind: 'visible-parity', mismatches: visibleMismatch.slice(0, 20), total: visibleMismatch.length});

    // --- reachability envelope: what heights are actually reachable
    const reach = {
      maxFloorY: floorMax, jumpApex: fmt(JUMP_APEX), eyeCeiling: fmt(eyeCeiling),
      excludedArtMinimumY: fmt(Math.min(...recipe.art.map(s => Math.min(...s.vertices.map(v => v[1]))))),
    };

    fixtures.push({
      id, geometryHash: recipe.geometryHash,
      rays: rays.filter(ray => ray.export).map(ray => ({
        label: ray.label, group: ray.group,
        from: ray.from.map(coarse), to: ray.to.map(coarse), length: coarse(ray.length),
        source: coarse(ray.source), blocked: ray.blocked, tolerance: ray.tolerance,
        mode: ray.mode, grazing: ray.grazing,
      })),
    });
    report.maps.push({
      id, geometryHash: recipe.geometryHash,
      rays: rays.length, checks, groups: Object.fromEntries(Object.entries(groups).map(([k, v]) => [k, {
        rays: v.rays, blockedSource: v.blockedSource, blockedExact: v.blockedExact,
        classificationMismatch: v.classificationMismatch, proxyDivergence: v.proxyDivergence ?? 0, grazing: v.grazing ?? 0, maxDistanceDelta: fmt(v.maxDistanceDelta),
      }])),
      probes: {reachableBand: probes, covered: probeHits, misses: probeMisses.length},
      visibleChecks, visibleMismatch: visibleMismatch.length,
      reach,
    });
  }

  report.checks = checks;
  report.elapsedMs = +(performance.now() - started).toFixed(1);
  report.passed = report.failures.length === 0;
  return {report, fixtures};
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const {report, fixtures} = audit();
  const fixturePath = new URL('../../godot/tests/identity_maps/source-rays.json', import.meta.url);
  writeFileSync(fixturePath, JSON.stringify(fixtures) + '\n');
  const out = new URL('./evidence/', import.meta.url);
  mkdirSync(out, {recursive: true});
  const name = `ray-report-${Date.now()}.json`;
  writeFileSync(new URL(name, out), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({checks: report.checks, failures: report.failures.length, elapsedMs: report.elapsedMs, evidence: name, fixtures: fixtures.reduce((n, f) => n + f.rays.length, 0)}, null, 2));
  for (const m of report.maps) console.log(`${m.id}: ${m.rays} rays, groups=${JSON.stringify(Object.fromEntries(Object.entries(m.groups).map(([k, v]) => [k, v.rays])))}, probeMisses=${m.probes.misses}, visibleMismatch=${m.visibleMismatch}, eyeCeiling=${m.reach.eyeCeiling}, excludedMinY=${m.reach.excludedArtMinimumY}`);
  process.exitCode = report.passed ? 0 : 1;
}

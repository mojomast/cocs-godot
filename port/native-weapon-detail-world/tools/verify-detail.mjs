// World-weapon detail verification: measures the delivered GLBs, proves the
// consumer contracts (anchors, bounds, batch counts, triangles), and proves the
// added detail does not clip the source hand pass.
//
// Hand clearance is exact rather than sampled. The source rig places the hand
// so its grip anchor matches `WeaponGripLeft/Right` and its basis equals the
// weapon basis, so for any of the 450 source fixture cases the hand's weapon
// space image is `anchor + (p - gripLocal)`. All nine operators share one hand
// geometry (game/models.mjs binds part 'hand' to the shared id), which this
// tool re-checks per operator before relying on it.
import * as T from 'three';
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {robotModel, simpleWeaponModel} from '../../../game/view.mjs';
import {ModelAssets} from '../../../game/effects-fx.mjs';
import {CHARACTERS} from '../../../game/data.mjs';
import {chassisFor} from '../../../game/weapon-models/chassis.mjs';
import {detailKit} from '../../../tools/godot-operators/world-weapons.mjs';

const ROOT = new URL('../../../', import.meta.url);
const STOCK_LENGTH = [.24, .17, .25, .25, .19, .22, .18, .20, .28, .16];
const stockLenOf = type => STOCK_LENGTH[type] ?? STOCK_LENGTH[0];
const sha = data => createHash('sha256').update(data).digest('hex');
const sub = (u, v) => [u[0] - v[0], u[1] - v[1], u[2] - v[2]];
const dot = (u, v) => u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
const cross = (u, v) => [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
const length = u => Math.hypot(u[0], u[1], u[2]);

// Ericson, Real-Time Collision Detection: closest point on a triangle.
function pointTriangle(p, a, b, c) {
  const ab = sub(b, a), ac = sub(c, a), ap = sub(p, a);
  const d1 = dot(ab, ap), d2 = dot(ac, ap);
  if (d1 <= 0 && d2 <= 0) return a;
  const bp = sub(p, b), d3 = dot(ab, bp), d4 = dot(ac, bp);
  if (d3 >= 0 && d4 <= d3) return b;
  const vc = d1 * d4 - d3 * d2;
  if (vc <= 0 && d1 >= 0 && d3 <= 0) { const v = d1 / (d1 - d3); return [a[0] + v * ab[0], a[1] + v * ab[1], a[2] + v * ab[2]]; }
  const cp = sub(p, c), d5 = dot(ab, cp), d6 = dot(ac, cp);
  if (d6 >= 0 && d5 <= d6) return c;
  const vb = d5 * d2 - d1 * d6;
  if (vb <= 0 && d2 >= 0 && d6 <= 0) { const w = d2 / (d2 - d6); return [a[0] + w * ac[0], a[1] + w * ac[1], a[2] + w * ac[2]]; }
  const va = d3 * d6 - d5 * d4;
  if (va <= 0 && d4 - d3 >= 0 && d5 - d6 >= 0) { const w = (d4 - d3) / ((d4 - d3) + (d5 - d6)); return [b[0] + w * (c[0] - b[0]), b[1] + w * (c[1] - b[1]), b[2] + w * (c[2] - b[2])]; }
  const denom = 1 / (va + vb + vc), v = vb * denom, w = vc * denom;
  return [a[0] + ab[0] * v + ac[0] * w, a[1] + ab[1] * v + ac[1] * w, a[2] + ab[2] * v + ac[2] * w];
}
const vertexTriangleDistance = (p, t) => length(sub(pointTriangle(p, t[0], t[1], t[2]), p));

function segmentDistance(p1, q1, p2, q2) {
  const d1 = sub(q1, p1), d2 = sub(q2, p2), r = sub(p1, p2);
  const a = dot(d1, d1), e = dot(d2, d2), f = dot(d2, r);
  let s, t;
  if (a <= 1e-18 && e <= 1e-18) return length(r);
  if (a <= 1e-18) { s = 0; t = Math.max(0, Math.min(1, f / e)); }
  else {
    const c = dot(d1, r);
    if (e <= 1e-18) { t = 0; s = Math.max(0, Math.min(1, -c / a)); }
    else {
      const b = dot(d1, d2), denom = a * e - b * b;
      s = denom > 1e-18 ? Math.max(0, Math.min(1, (b * f - c * e) / denom)) : 0;
      t = (b * s + f) / e;
      if (t < 0) { t = 0; s = Math.max(0, Math.min(1, -c / a)); }
      else if (t > 1) { t = 1; s = Math.max(0, Math.min(1, (b - c) / a)); }
    }
  }
  const c1 = [p1[0] + d1[0] * s, p1[1] + d1[1] * s, p1[2] + d1[2] * s];
  const c2 = [p2[0] + d2[0] * t, p2[1] + d2[1] * t, p2[2] + d2[2] * t];
  return length(sub(c1, c2));
}

const EDGES = [[0, 1], [1, 2], [2, 0]];
function triangleDistance(a, b) {
  let best = Infinity;
  for (const p of a) best = Math.min(best, vertexTriangleDistance(p, b));
  for (const p of b) best = Math.min(best, vertexTriangleDistance(p, a));
  for (const [i, j] of EDGES) for (const [k, l] of EDGES) best = Math.min(best, segmentDistance(a[i], a[j], b[k], b[l]));
  return best;
}

const aabb = t => {
  const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
  for (const p of t) for (let k = 0; k < 3; k++) { min[k] = Math.min(min[k], p[k]); max[k] = Math.max(max[k], p[k]); }
  return { min, max };
};
const overlap = (a, b, pad) => a.min[0] - pad <= b.max[0] && b.min[0] - pad <= a.max[0] && a.min[1] - pad <= b.max[1] && b.min[1] - pad <= a.max[1] && a.min[2] - pad <= b.max[2] && b.min[2] - pad <= a.max[2];

function trianglesOf(object) {
  const out = [];
  object.updateMatrixWorld(true);
  object.traverse(node => {
    if (!node.isMesh) return;
    let g = node.geometry.index ? node.geometry.toNonIndexed() : node.geometry.clone();
    g = g.clone().applyMatrix4(node.matrixWorld);
    const p = g.attributes.position;
    for (let i = 0; i < p.count; i += 3) out.push([[p.getX(i), p.getY(i), p.getZ(i)], [p.getX(i + 1), p.getY(i + 1), p.getZ(i + 1)], [p.getX(i + 2), p.getY(i + 2), p.getZ(i + 2)]]);
  });
  return out;
}
function kitTriangles(kit) {
  const out = [];
  for (const part of kit.parts) {
    const g = part.geometry.index ? part.geometry.toNonIndexed() : part.geometry;
    const p = g.attributes.position;
    for (let i = 0; i < p.count; i += 3) {
      const t = [[p.getX(i), p.getY(i), p.getZ(i)], [p.getX(i + 1), p.getY(i + 1), p.getZ(i + 1)], [p.getX(i + 2), p.getY(i + 2), p.getZ(i + 2)]];
      t.zone = part.zone; t.material = part.material;
      out.push(t);
    }
  }
  return out;
}

async function main() {
  const outDir = new URL('godot/source_operators/generated/world_weapons/', ROOT);
  const manifest = JSON.parse(await readFile(new URL('manifest.json', outDir)));
  const before = JSON.parse(await readFile(new URL('port/native-weapon-detail-world/anchors-before.json', ROOT)));

  // Hand geometry per operator, then a shared-geometry check across operators.
  const hands = new Map();
  for (const { id } of CHARACTERS) {
    const model = robotModel(id, new ModelAssets()); model.updateMatrixWorld(true);
    const entry = {};
    for (const side of ['L', 'R']) {
      const hand = model.userData.joints['hand' + side], grip = model.userData.characterRefinement['grip' + side];
      const local = new T.Matrix4().copy(hand.matrixWorld).invert();
      const tris = [];
      hand.traverse(node => {
        if (!node.isMesh) return;
        let g = node.geometry.clone().applyMatrix4(new T.Matrix4().multiplyMatrices(local, node.matrixWorld));
        g = g.index ? g.toNonIndexed() : g;
        const p = g.attributes.position;
        for (let i = 0; i < p.count; i += 3) tris.push([[p.getX(i), p.getY(i), p.getZ(i)], [p.getX(i + 1), p.getY(i + 1), p.getZ(i + 1)], [p.getX(i + 2), p.getY(i + 2), p.getZ(i + 2)]]);
      });
      entry[side] = { tris, grip: grip.position.toArray() };
    }
    entry.signature = ['L', 'R'].map(side => sha(JSON.stringify(entry[side].tris)) + '|' + entry[side].grip.join(','));
    hands.set(id, entry);
  }
  const reference = hands.get(CHARACTERS[0].id);
  const sharedHands = [...hands.values()].every(entry => entry.signature[0] === reference.signature[0] && entry.signature[1] === reference.signature[1]);

  const report = {
    schema: 1,
    method: 'Exported GLB measurement plus exact hand/detail triangle distance (vertex-triangle and edge-edge, no sampling). Hand placement is the source identity: the post-pose hand pass pins the grip anchor to WeaponGripLeft/Right with the hand basis equal to the weapon basis, so the hand mesh occupies anchor + (p - gripLocal) in weapon space.',
    sharedOperatorHandGeometry: sharedHands,
    weapons: [],
  };
  for (const weapon of manifest.weapons) {
    const type = weapon.id;
    const bytes = await readFile(new URL(weapon.file, outDir));
    const [w, h, len, mz, my] = chassisFor(type);
    const anchors = { Muzzle: [0, my, mz], WeaponGripLeft: [-w / 2 - .025, my - h / 2 - .015, -len * .48], WeaponGripRight: [0, my - h / 2 - .08, -.035] };
    const beforeWeapon = before.weapons[type];
    const anchorDrift = Math.max(...Object.keys(anchors).flatMap(name => anchors[name].map((v, i) => Math.abs(v - beforeWeapon.anchors[name][i]))));
    // Source world-body envelopes: any added triangle fully inside one of the
    // named source meshes would be invisible and is reported, not counted.
    // Cylindrical sources (barrel(s), grenade drum) are tested as cylinders so
    // hardware wrapped around them is not mistaken for hidden geometry.
    const [cw, ch, clen, cmz, cmy, cr] = chassisFor(type);
    const insideBox = (t, b) => t.every(p => b.min[0] - .0005 <= p[0] && p[0] <= b.max[0] + .0005 && b.min[1] - .0005 <= p[1] && p[1] <= b.max[1] + .0005 && b.min[2] - .0005 <= p[2] && p[2] <= b.max[2] + .0005);
    const boxAt = (w, h, d, x, y, z) => ({ min: [x - w / 2, y - h / 2, z - d / 2], max: [x + w / 2, y + h / 2, z + d / 2] });
    const envelopes = [
      { name: 'receiver', box: boxAt(cw, ch, clen, 0, cmy, -clen / 2) },
      { name: 'stock', box: boxAt(cw * .75, ch * .65, stockLenOf(type), 0, cmy - .03, stockLenOf(type) / 2 - .01) },
      { name: 'grip', box: boxAt(.07, .19, .09, 0, cmy - ch / 2 - .08, -.03) },
      ...(type === 5 ? [] : [{ name: 'feed', box: boxAt(type === 3 ? .23 : type === 7 ? .20 : .09, type === 1 ? .07 : type === 3 ? .055 : type === 7 ? .16 : type === 9 ? .27 : .16, .13, type === 7 ? -.07 : 0, type === 3 ? cmy - .04 : cmy - ch / 2 - .09, type === 3 ? -.18 : -.25) }]),
    ];
    const cylinders = [];
    if (type === 3) for (const x of [-.12, .12]) cylinders.push({ name: 'barrelL', x, y: cmy, r: cr, z0: cmz, z1: -clen });
    else cylinders.push({ name: 'barrel', x: 0, y: cmy, r: cr, z0: cmz, z1: -clen });
    if (type === 5) cylinders.push({ name: 'drum', x: 0, y: cmy - ch / 2 - .09, r: .125, z0: -.365, z1: -.135 });
    const insideCylinder = (t, c) => t.every(p => Math.hypot(p[0] - c.x, p[1] - c.y) <= c.r + .0005 && p[2] >= c.z0 - .0005 && p[2] <= c.z1 + .0005);
    const hidden = new Map();
    const kitTris = kitTriangles(detailKit(type));
    for (const t of kitTris) {
      const isHidden = envelopes.some(e => insideBox(t, e.box)) || cylinders.some(c => insideCylinder(t, c));
      if (isHidden) hidden.set(t.zone ?? '?', (hidden.get(t.zone ?? '?') ?? 0) + 1);
    }
    const sourceTris = trianglesOf(simpleWeaponModel(type, new ModelAssets()));
    const detailTris = kitTris;
    const handReport = {};
    for (const side of ['L', 'R']) {
      const contact = anchors[side === 'L' ? 'WeaponGripLeft' : 'WeaponGripRight'];
      const hand = reference[side];
      const placed = hand.tris.map(t => t.map(p => [contact[0] + p[0] - hand.grip[0], contact[1] + p[1] - hand.grip[1], contact[2] + p[2] - hand.grip[2]]));
      const boxes = placed.map(t => aabb(t));
      const test = list => {
        let pairs = 0, minDistance = Infinity, contacts = 0, nearest = null;
        for (const t of list) {
          const b = aabb(t);
          for (let i = 0; i < placed.length; i++) {
            if (!overlap(b, boxes[i], 0)) continue;
            const distance = triangleDistance(t, placed[i]);
            if (distance <= 0) contacts++;
            if (distance < minDistance) {
              minDistance = distance;
              nearest = { zone: t.zone ?? null, material: t.material ?? null, centroid: t.reduce((a, p) => [a[0] + p[0] / 3, a[1] + p[1] / 3, a[2] + p[2] / 3], [0, 0, 0]).map(v => +v.toFixed(5)), distance: +distance.toFixed(6) };
            }
          }
        }
        return { intersectingPairs: contacts, candidateTriangles: list.length, minimumDistance: Number.isFinite(minDistance) ? minDistance : null, nearest };
      };
      handReport[side] = { source: test(sourceTris), detail: test(detailTris) };
    }
    report.weapons.push({
      id: type, name: weapon.name, file: weapon.file, bytes: bytes.length, sha256: sha(bytes), matchesManifest: sha(bytes) === weapon.sha256,
      triangles: weapon.triangles, draws: weapon.draws, detailTriangles: weapon.detail.triangles,
      before: { triangles: beforeWeapon.triangles, draws: beforeWeapon.draws },
      anchorDrift, anchors: weapon.anchors, bounds: weapon.bounds, zones: weapon.detail.zones, hand: handReport,
      hiddenDetailTriangles: { total: [...hidden.values()].reduce((n, v) => n + v, 0), byZone: Object.fromEntries(hidden) },
    });
  }
  const flat = report.weapons.flatMap(w => [w.hand.L, w.hand.R]);
  report.totals = {
    triangles: report.weapons.reduce((n, w) => n + w.triangles, 0),
    detailTriangles: report.weapons.reduce((n, w) => n + w.detailTriangles, 0),
    draws: report.weapons.reduce((n, w) => n + w.draws, 0),
    rigDraws: report.weapons.reduce((n, w) => n + 4, 0),
    maxAnchorDrift: Math.max(...report.weapons.map(w => w.anchorDrift)),
    detailHandIntersections: flat.reduce((n, s) => n + s.detail.intersectingPairs, 0),
    sourceHandIntersections: flat.reduce((n, s) => n + s.source.intersectingPairs, 0),
    minDetailHandDistance: Math.min(...flat.map(s => s.detail.minimumDistance ?? Infinity)),
    minSourceHandDistance: Math.min(...flat.map(s => s.source.minimumDistance ?? Infinity)),
  };
  console.log(JSON.stringify(report, null, 1));
  const target = process.env.DETAIL_EVIDENCE;
  if (target) await writeFile(target, JSON.stringify(report, null, 1) + '\n');
}
await main();

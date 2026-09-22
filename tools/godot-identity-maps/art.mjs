// Deterministic authored art + simplified source-compatible collision for the
// three identity maps.
//
// Two products, deliberately separated:
//   render[]    every visible triangle, exact. Never derived from collision.
//   collision[] coarse wall entries the source accepts (`arena.terrain.walls`).
//               Each is either
//                 * a polygon wall {id, material, walkable:false, vertices} —
//                   the source fans it into ray triangles AND reads its closed
//                   XZ outline as movement segments, or
//                 * a two-point movement barrier {material, a, b} — one XZ
//                   segment with an explicit Y span and no ray triangles.
//
// Why this exists: the prototype passed one wall per art triangle through the
// source wall-segment mover, which is a linear scan per obstruction query
// (2.9-14.8 s cold Match construction). Every collision entry below is authored
// from the same parameters as its visible mass, so provenance stays explicit:
// nothing here is invisible support, and nothing decorative is silently demoted
// from cover without a recorded reason (see `notes`).
//
// Source collision semantics (game/core.mjs terrainObstructed): a wall segment
// blocks an actor when the actor body [y, y+1.8] overlaps the segment's
// [minY, maxY]. A polygon wall whose vertices alternate between a low and a
// high Y therefore yields two ray faces plus two full-height movement
// segments from one entry — that is the workhorse primitive here.

function geom(id, material) {
  return { id, material, walkable: false, vertices: [], triangles: [] };
}

function face(g, a, b, c, d) {
  const i = g.vertices.length;
  g.vertices.push(a, b, c, d);
  g.triangles.push([i, i + 1, i + 2], [i, i + 2, i + 3]);
}

function prism(g, points, depth) {
  const front = points.map(p => [p[0], p[1], p[2] - depth / 2]);
  const back = points.map(p => [p[0], p[1], p[2] + depth / 2]);
  face(g, ...front);
  face(g, ...back.slice().reverse());
  for (let i = 0; i < points.length; i++) {
    face(g, front[i], back[i], back[(i + 1) % points.length], front[(i + 1) % points.length]);
  }
}

// Local frame of an authored form: local X/Z rotate by yaw around Y, local Y is
// world up. Matches the prototype compiler's transform exactly.
function transform(g, at, yaw = 0) {
  const c = Math.cos(yaw), s = Math.sin(yaw);
  g.vertices = g.vertices.map(([x, y, z]) => [at[0] + x * c + z * s, at[1] + y, at[2] - x * s + z * c]);
  return g;
}

function localToWorld(at, yaw, p) {
  const c = Math.cos(yaw), s = Math.sin(yaw);
  return [at[0] + p[0] * c + p[2] * s, at[1] + p[1], at[2] - p[0] * s + p[2] * c];
}

/** Axis-aligned (or yaw-rotated) box form; 12 triangles, outward winding. */
function boxForm(id, material, { at, size, yaw = 0 }) {
  const g = geom(id, material);
  const [w, h, d] = size;
  const x0 = -w / 2, x1 = w / 2, y0 = -h / 2, y1 = h / 2, z0 = -d / 2, z1 = d / 2;
  const P = [[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]];
  face(g, P[0], P[3], P[2], P[1]);
  face(g, P[4], P[5], P[6], P[7]);
  face(g, P[0], P[1], P[5], P[4]);
  face(g, P[3], P[7], P[6], P[2]);
  face(g, P[0], P[4], P[7], P[3]);
  face(g, P[1], P[2], P[6], P[5]);
  return transform(g, at, yaw);
}

/**
 * Elliptical band arch around the local origin: `width` is the radial
 * thickness, `depth` the extrusion along local Z. `taper` widens the inner
 * radius toward the middle of the sweep, which is what makes the arc read as
 * cut stone with a stepped base instead of a paper strip.
 */
function bandArch(id, material, at, rx, ry, width, depth, start = 0, end = Math.PI, yaw = 0, stepsPerRadian = 14, opts = {}) {
  const g = geom(id, material);
  const steps = Math.max(4, Math.ceil((end - start) * stepsPerRadian));
  const innerX = Math.max(0.05, rx - width), innerY = Math.max(0.05, ry - width);
  const taper = opts.taper ?? 0;
  for (let i = 0; i < steps; i++) {
    const a = start + (end - start) * i / steps, b = start + (end - start) * (i + 1) / steps;
    const bulge = taper * (0.5 - 0.5 * Math.cos(Math.PI * (i + 0.5) / steps));
    prism(g, [
      [rx * Math.cos(a), ry * Math.sin(a), 0],
      [(innerX + bulge) * Math.cos(a), (innerY + bulge) * Math.sin(a), 0],
      [(innerX + bulge) * Math.cos(b), (innerY + bulge) * Math.sin(b), 0],
      [rx * Math.cos(b), ry * Math.sin(b), 0],
    ], depth);
  }
  return transform(g, at, yaw);
}

/**
 * Smooth folded ribbon sheet. `waves` crests across the width, `rise` lifts the
 * far edge, `thickness` folds a rim back so the silhouette reads as an opaque
 * ribbon. Replaces the prototype's 8-strip sawtooth (the jagged silhouette
 * called out for Vermilion).
 */
function foldedSheet(id, material, { at, width, length, amplitude = 1.6, waves = 2, rise = 0, yaw = 0, thickness = 0.16, cols = 12, rows = 5 }) {
  const g = geom(id, material);
  const point = (u, v) => [
    (u - 0.5) * width,
    amplitude * (0.5 - 0.5 * Math.cos(Math.PI * 2 * waves * u)) + rise * v,
    (v - 0.5) * length,
  ];
  const top = [], bottom = [];
  for (let r = 0; r <= rows; r++) {
    const rowT = [], rowB = [];
    for (let c = 0; c <= cols; c++) {
      const p = point(c / cols, r / rows);
      rowT.push(p);
      rowB.push([p[0], p[1] - thickness, p[2]]);
    }
    top.push(rowT); bottom.push(rowB);
  }
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) face(g, top[r][c], top[r][c + 1], top[r + 1][c + 1], top[r + 1][c]);
  }
  for (let c = 0; c < cols; c++) {
    face(g, bottom[0][c], bottom[0][c + 1], top[0][c + 1], top[0][c]);
    face(g, top[rows][c], top[rows][c + 1], bottom[rows][c + 1], bottom[rows][c]);
  }
  for (let r = 0; r < rows; r++) {
    face(g, top[r][0], top[r + 1][0], bottom[r + 1][0], bottom[r][0]);
    face(g, bottom[r][cols], bottom[r + 1][cols], top[r + 1][cols], top[r][cols]);
  }
  return transform(g, at, yaw);
}

/**
 * Hand-fan blade row: blades radiate from a hub, shorten toward the sweep
 * edges, and lift outward, so the outer boundary is an arc rather than a
 * straight cut.
 */
function bladeFan(id, material, { at, blades = 9, hub = 1.0, length = 9, width = 5.2, sweep = Math.PI * 0.72, lift = 1.1, yaw = 0, amplitude = 0.9, thickness = 0.14, droop = 0.5 }) {
  const g = geom(id, material);
  for (let i = 0; i < blades; i++) {
    const t = blades === 1 ? 0.5 : i / (blades - 1);
    const angle = -sweep / 2 + sweep * t;
    const bladeLength = length * (0.74 + 0.26 * Math.cos((t - 0.5) * Math.PI * 0.9));
    const centre = hub + bladeLength / 2 - 0.4;
    const blade = foldedSheet(`${id}-${i}`, material, {
      at: [Math.sin(angle) * centre, droop * (0.5 - Math.abs(t - 0.5)), Math.cos(angle) * centre],
      width, length: bladeLength, amplitude, waves: 1, rise: lift, yaw: angle, thickness, cols: 6, rows: 3,
    });
    const base = g.vertices.length;
    for (const v of blade.vertices) g.vertices.push(v);
    for (const tri of blade.triangles) g.triangles.push([tri[0] + base, tri[1] + base, tri[2] + base]);
  }
  return transform(g, at, yaw);
}

/** Elliptical ring of plates; alternating plates read as segmented shell. */
function plateRing(id, material, { at, rx, ry, width = 1.3, depth = 1.4, yaw = 0, segments = 12, step = 0, alternate = 0.18 }) {
  const g = geom(id, material);
  const count = Math.max(6, segments);
  for (let i = 0; i < count; i++) {
    const a = (i / count) * Math.PI * 2 + step;
    const b = ((i + 1) / count) * Math.PI * 2 + step;
    const w = width + (i % 2 ? alternate : 0);
    prism(g, [
      [rx * Math.cos(a), ry * Math.sin(a), 0],
      [(rx - w) * Math.cos(a), (ry - w) * Math.sin(a), 0],
      [(rx - w) * Math.cos(b), (ry - w) * Math.sin(b), 0],
      [rx * Math.cos(b), ry * Math.sin(b), 0],
    ], i % 2 ? depth * 1.3 : depth);
  }
  return transform(g, at, yaw);
}

// ---------------------------------------------------------------------------
// collision primitives
// ---------------------------------------------------------------------------

/** Planar quad wall; order is [low-a, high-a, high-b, low-b] so the source fan
 * stays in the quad's plane (a non-planar fan creases away from the face). */
function faceQuad(id, material, corners) {
  return {id, material, walkable: false, vertices: corners};
}

/** Two-point movement barrier: one XZ segment with an explicit Y span. */
function fence(material, x0, z0, x1, z1, y0, y1) {
  return {material, a: {x: x0, y: y0, z: z0}, b: {x: x1, y: y1, z: z1}};
}

/**
 * Compact ground foot volume: stacked planar face quads (so the source fan
 * never creases away from the face), two end trapezoids, an optional top cap,
 * and three movement fences. A leaning slab alone would leave the z-ends open
 * and a bare face quad adds no movement barrier at all, so the fences close
 * the footprint: an actor standing inside a visible rib foot is exactly the
 * invisible-geometry leak this lane must not ship.
 */
function footVolume(id, material, {z0, z1, y0, y1, outer, inner, slices = 2, cap = true}) {
  const entries = [];
  const ys = Array.from({length: slices + 1}, (_, i) => y0 + (y1 - y0) * i / slices);
  for (let i = 0; i < slices; i++) {
    const ya = ys[i], yb = ys[i + 1];
    const oa = outer(ya), ob = outer(yb), ia = inner(ya), ib = inner(yb);
    entries.push(faceQuad(`${id}-outer-${i}`, material, [[oa, ya, z0], [ob, yb, z0], [ob, yb, z1], [oa, ya, z1]]));
    entries.push(faceQuad(`${id}-inner-${i}`, material, [[ia, ya, z0], [ib, yb, z0], [ib, yb, z1], [ia, ya, z1]]));
    entries.push(faceQuad(`${id}-end-a-${i}`, material, [[oa, ya, z0], [ia, ya, z0], [ib, yb, z0], [ob, yb, z0]]));
    entries.push(faceQuad(`${id}-end-b-${i}`, material, [[oa, ya, z1], [ia, ya, z1], [ib, yb, z1], [ob, yb, z1]]));
  }
  if (cap) entries.push(faceQuad(`${id}-cap`, material, [[outer(y1), y1, z0], [inner(y1), y1, z0], [inner(y1), y1, z1], [outer(y1), y1, z1]]));
  entries.push(fence(material, outer(y0), z0, outer(y1), z1, y0, y1));
  entries.push(fence(material, inner(y0), z0, inner(y1), z1, y0, y1));
  entries.push(fence(material, (outer(y0) + inner(y0)) / 2, z0, (outer(y1) + inner(y1)) / 2, z1, y0, y1));
  return entries;
}

// ---------------------------------------------------------------------------
// per-map art
// ---------------------------------------------------------------------------

// Semantic identity names mapped onto the six shared per-map material keys the
// Godot builder owns (style.gd). One material per key per map; art never names
// its own shader, so no surface can create a per-surface material instance.
//   shell  = the map's pale structural stone / pearl / ivory
//   cut    = its secondary or joint material
//   enamel = its deep recess (indigo / jade / ultramarine)
//   accent = its inlay or service metal (copper / vermilion / amber)
//   trim   = dark hardware used by construction detail
const PALETTE = {
  chalk: 'shell', cut: 'cut', indigo: 'enamel', copper: 'accent',
  vermilion: 'accent', ivory: 'shell', jade: 'enamel', hardware: 'trim',
  pearl: 'shell', ultramarine: 'enamel', amber: 'accent', joint: 'cut',
};

function lacunaArt() {
  const render = [], collision = [], notes = [];

  // Landmark: two separated thick stone arcs with indigo receivers and copper
  // radial inlays. Both arcs stand on a 5 x 9 x 4.5 m exact resonator block.
  for (const side of [-1, 1]) {
    const at = [side * 5, 5, side * 3];
    render.push(bandArch(`split-resonator-${side}`, PALETTE.cut, at, 4.3, 7, 1.35, 2.1, -0.2, Math.PI * 1.15, Math.PI / 2, 14, { taper: 0.35 }));
    render.push(bandArch(`indigo-receiver-${side}`, PALETTE.indigo, [side * 5 + 0.02, 5, side * 3], 3.2, 5.7, 0.6, 1.5, 0.05, Math.PI, Math.PI / 2, 14));
    const inlay = geom(`copper-inlay-${side}`, PALETTE.copper);
    for (let i = 0; i < 7; i++) {
      const a = 0.16 + (Math.PI * 0.86) * (i + 0.5) / 7;
      const da = 0.05;
      prism(inlay, [
        [3.3 * Math.cos(a - da), 7 * Math.sin(a - da) * 0.98 + 0.1, 1.02],
        [4.28 * Math.cos(a - da), 7.32 * Math.sin(a - da), 1.02],
        [4.28 * Math.cos(a + da), 7.32 * Math.sin(a + da), 1.02],
        [3.3 * Math.cos(a + da), 7 * Math.sin(a + da) * 0.98 + 0.1, 1.02],
      ], 0.14);
    }
    render.push(transform(inlay, at, Math.PI / 2));
    render.push(boxForm(`resonator-cap-${side}`, PALETTE.chalk, { at: [side * 5, 4.68, side * 3], size: [5.5, 0.34, 9.5] }));
    // Coarse collision for the arc band just above the plinth top: the visible
    // band is the only part of the arc a hitscan can reach from a terrace jump
    // apex (4.45 m). Quads sit inside the visible band, so nothing decorative
    // becomes cover and no false cover appears in the arch opening.
    const bandEnds = side < 0
      ? [{z0: -7.32, z1: -5.9}, {z0: -0.1, z1: 1.33}]
      : [{z0: -1.33, z1: 0.1}, {z0: 5.9, z1: 7.32}];
    for (const [i, end] of bandEnds.entries()) {
      collision.push({
        id: `resonator-band-end-${side}-${i}`, material: PALETTE.cut, walkable: false,
        vertices: [[side * 5 - 1.05, 4.45, end.z0], [side * 5 - 1.05, 6.0, end.z0],
          [side * 5 + 1.05, 6.0, end.z1], [side * 5 + 1.05, 4.45, end.z1]],
      });
    }
    notes.push({ id: `split-resonator-${side}`, collision: 'inside-box+band-ends', reason: 'arc feet sit inside the 5x9x4.5 exact resonator block; the visible band 4.45-6.0 m above the plinth top is covered by two coarse quads per resonator; the arch opening and the band above 6 m (1.55 m above the highest reachable eye) are intentionally not collision' });
  }

  // Outside the movement bounds: pure skyline, never collision.
  render.push(bandArch('distant-sail', PALETTE.chalk, [-10, 12, -31], 13, 10, 3, 1, 0.15, Math.PI * 0.93, -0.3, 12));
  for (let i = 0; i < 8; i++) render.push(bandArch(`stratum-${i}`, PALETTE.cut, [0, 1 + i * 0.65, -27], 24, 1 + i * 0.05, 0.5, 0.3, 0, Math.PI, 0, 8));
  notes.push({ id: 'distant-sail+strata', collision: 'none-outside-bounds', reason: 'authored beyond the +-24 Z movement bound; only skyline is visible over the 7 m boundary block' });

  return { render, collision, notes };
}

function lacunaInfill(arena) {
  // Retaining skirts for the two 1.5 m terraces and their 1:6 ramps. These are
  // genuinely low and genuinely walkable-blocking, so the exact triangles stay
  // in BOTH lists: same vertices render the face and answer source rays, and
  // their diagonal edges are the movement barrier.
  const render = [], collision = [];
  for (const surface of arena.terrain.surfaces.filter(s => s.id !== 'court')) {
    for (let i = 0; i < surface.vertices.length; i++) {
      const a = surface.vertices[i], b = surface.vertices[(i + 1) % surface.vertices.length];
      const a0 = [a[0], 0, a[2]], b0 = [b[0], 0, b[2]];
      // Shared ramp/terrace join is internal, not an exposed wall.
      if (a[2] === -22 && b[2] === -22) continue;
      if (a[1] > 0) {
        const id = `${surface.id}-infill-${i}a`;
        render.push({ id, material: PALETTE.cut, walkable: false, vertices: [a, a0, b], triangles: [[0, 1, 2]] });
        collision.push({ id, material: PALETTE.cut, walkable: false, vertices: [a, a0, b], triangles: [[0, 1, 2]] });
      }
      if (b[1] > 0) {
        const id = `${surface.id}-infill-${i}b`;
        render.push({ id, material: PALETTE.cut, walkable: false, vertices: [b, a0, b0], triangles: [[0, 1, 2]] });
        collision.push({ id, material: PALETTE.cut, walkable: false, vertices: [b, a0, b0], triangles: [[0, 1, 2]] });
      }
    }
  }
  return { render, collision };
}

function vermilionArt() {
  const render = [], collision = [], notes = [];

  // Crown (bravo): five smooth folded ribbons radiating from the centre.
  for (let i = 0; i < 5; i++) {
    render.push(foldedSheet(`crown-fold-${i}`, PALETTE.vermilion, {
      at: [0, 7.8 + i * 0.24, 0], width: 6.6, length: 19, amplitude: 1.75, waves: 2, rise: 1.25,
      yaw: i * Math.PI * 2 / 5, thickness: 0.2, cols: 18, rows: 6,
    }));
  }
  // Fan (alpha): a real blade fan over the north fold point, jade under-ribs.
  render.push(bladeFan('fan-blades', PALETTE.vermilion, { at: [0, 6.2, -17], blades: 9, hub: 1.2, length: 15, width: 4.6, sweep: Math.PI * 0.8, lift: 1.5, amplitude: 0.85 }));
  render.push(bladeFan('fan-blades-upper', PALETTE.ivory, { at: [0, 9.6, -17], blades: 6, hub: 0.8, length: 10, width: 3.4, sweep: Math.PI * 0.58, lift: 1.0, yaw: Math.PI, amplitude: 0.6, thickness: 0.12 }));
  // Pleats (charlie): serial jade enamel folds.
  for (let i = 0; i < 6; i++) {
    render.push(foldedSheet(`pleat-${i}`, i % 2 ? PALETTE.jade : PALETTE.vermilion, {
      at: [(i - 2.5) * 2.3, 6.6 + (i % 2) * 0.5, 17], width: 2.5, length: 12, amplitude: 1.25, waves: 1, rise: 0.7,
      yaw: 0.18, thickness: 0.14, cols: 9, rows: 5,
    }));
  }
  // Ivory tension members with an inner hardware rib and a keystone.
  for (const z of [-17, 0, 17]) for (const side of [-1, 1]) {
    const at = [side * 6, 4, z];
    render.push(bandArch(`ivory-tension-${z}-${side}`, PALETTE.ivory, at, 4, 6, 0.42, 0.5, 0, Math.PI, Math.PI / 2, 10));
    render.push(bandArch(`ivory-tension-inner-${z}-${side}`, PALETTE.hardware, at, 3.6, 5.6, 0.14, 0.62, 0.14, Math.PI - 0.14, Math.PI / 2, 10));
    render.push(boxForm(`ivory-keystone-${z}-${side}`, PALETTE.ivory, { at: localToWorld(at, Math.PI / 2, [0, 6.3, 0]), size: [0.86, 0.9, 1.0] }));
  }
  notes.push({ id: 'crown/fan/pleat/tension', collision: 'none-overhead', reason: 'lowest visible vertex of any vermilion or ivory form is 3.7 m (tension band foot); standing eye is 1.45 m and the jump apex from flat ground stays under 3.6 m, so no reachable eye or movement path touches them' });
  return { render, collision, notes };
}

function nacreArt() {
  const render = [], collision = [], notes = [];

  for (let z = -24; z <= 24; z += 8) {
    render.push(bandArch(`vault-${z}`, PALETTE.pearl, [0, 0, z], 28, 17, 1.5, 1.5, 0, Math.PI, 0, 12, { taper: 0.3 }));
    // Joint band shares the same z centre and is radially inset, so a single
    // foot proxy can follow the inner edge of both bands without a z mismatch.
    render.push(bandArch(`vault-joint-${z}`, PALETTE.joint, [0, 0, z], 26.5, 15.62, 0.35, 1.1, 0, Math.PI, 0, 12));
    // Ground feet: the only part of a rib a player can touch. The proxy faces
    // follow the joint band's ellipse within 5 cm and stop at 4.5 m, where the
    // rib is already 1.55 m above the highest reachable eye.
    const outerAt = y => 28 * Math.sqrt(Math.max(0, 1 - (y / 17) ** 2)) - 0.05;
    const innerAt = y => 26.15 * Math.sqrt(Math.max(0, 1 - (y / 15.62) ** 2)) + 0.05;
    for (const side of [-1, 1]) {
      collision.push(...footVolume(`vault-foot-${z}-${side}`, PALETTE.pearl, {
        z0: z - 0.75, z1: z + 0.75, y0: 0, y1: 4.5, slices: 2,
        outer: y => side * outerAt(y), inner: y => side * innerAt(y),
      }));
    }
  }
  notes.push({ id: 'vault-ribs', collision: 'feet-only-proxy', reason: 'each rib crosses ground at x=+-27 inside the +-30 bounds; the rib and its radial joint band above 4.5 m are overhead, above every reachable eye ray' });

  for (let z = -5; z <= 5; z += 2) {
    render.push(plateRing(`nacre-drum-${z}`, PALETTE.pearl, { at: [0, 7.8, z], rx: 5.9, ry: 5.5, width: 1.35, depth: 1.5, segments: 12, step: (z + 5) * 0.06 }));
    render.push(plateRing(`drum-service-${z}`, PALETTE.amber, { at: [0, 7.8, z + 0.85], rx: 4.5, ry: 4.1, width: 0.22, depth: 0.28, segments: 12 }));
  }
  notes.push({ id: 'drum', collision: 'none-decorative', reason: 'drum plates sit inside the 12x12x6 exact memory-housing block footprint, so they are unreachable and need no separate collision' });
  return { render, collision, notes };
}

// ---------------------------------------------------------------------------
// entry points
// ---------------------------------------------------------------------------

export function buildArt(recipe) {
  if (recipe.id === 'lacuna-court') {
    const art = lacunaArt(), infill = lacunaInfill(recipe.arena);
    return { render: [...art.render, ...infill.render], collision: [...art.collision, ...infill.collision], notes: art.notes };
  }
  if (recipe.id === 'vermilion-fold') return vermilionArt();
  if (recipe.id === 'nacre-engine') return nacreArt();
  throw new Error(`Unknown identity map art: ${recipe.id}`);
}

/** Back-compatible accessor for callers that only want visible triangles. */
export function art(recipe) {
  return buildArt(recipe).render;
}

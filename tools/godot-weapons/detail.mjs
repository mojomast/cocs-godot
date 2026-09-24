// Deterministic detail augmentation for the ten first-person weapon exports.
//
// Source geometry (`game/weapon-models/**`, locked) is never moved, scaled or
// removed. This module bolts *additional* hard-surface geometry onto the same
// assemblies the source authors, so the merged GLB regains real detail while
// every anchor, sight line and grip station stays exactly where it was.
//
// Material roles come from `ctx.detail` (export.mjs):
//   dark   - source receiver/breech tone (existing material)
//   light  - source machined tone (existing material)
//   glow   - the weapon's own data.mjs colour, emissive (existing material)
//   trim   - NEW shared machined-steel tone (moving action hardware)
//   cavity - NEW shared recess tone (vents, port mouths, shadow gaps)
//
// Positions are authored in weapon space (+Z stock, -Z muzzle, y = bore line)
// and converted into the owning assembly's local frame, so detail that belongs
// to a moving part (feed, bolt, barrel, break-action hinge) travels with it.
//
// Deterministic: no randomness, no environment reads, fixed arithmetic only,
// every geometry cached through ctx.geo by full parameter key.
//
// SECOND PASS - weapon identity/silhouette. The first detail pass dressed every
// weapon with the same vocabulary, so the ten receivers still read as one
// family. This pass keeps the six identity channels (channel 1 is the dominant
// silhouette idea) but authors *bold* shape language per weapon: one dominant
// mass, one dominant projection, one dominant terminator, with the small
// greebles demoted to support. Triangle cost stays inside the documented band;
// the exporter re-measures every anchor and `tools/godot-weapons/verify.mjs`
// gates the pairwise silhouette IoU from `silhouette.mjs`.
//
// Locality rules that bound every primitive below:
//   * detail never enters the sight corridor (measured; the exporter refuses),
//   * detail never comes within 45 mm of a grip station (measured, exported,
//     and re-checked live by godot/tests/first_person/detail.gd),
//   * detail never enters the 12 mm sight-line capsule,
//   * feed/receiver/muzzle detail is authored in *weapon space* and rebased
//     into the owning moving assembly, so it travels with reload/hinge motion.

const TAU = Math.PI * 2;

// Channel copy of record for the manifest (mirrors WEAPON_IDENTITY.md).
// Primitive vocabulary triangle cost: box 12, open tube 2*seg, closed cone or
// disc 4*seg, hoop 2*radial*seg. Detail is a small number of *large* primitives
// plus a controlled amount of greeble, so the silhouette moves first.
export const IDENTITY = [
  {id: 0, massing: 'slender carbine: slim dorsal spine, squared front trunnion, long perforated barrel shroud',
    feed: 'box magazine: magwell flare, witness slot, floorplate lip, ambi catch',
    muzzle: 'slotted flash hider: six-port sleeve with crown ring',
    stock: 'skeleton stock: two rails and a slotted comb, grip palm swell',
    sight: 'iron notch/post, toothed optic rail with a bolted front-sight base block',
    accent: 'cyan trim, emissive charge conduit on the left flank, perforated handguard shroud'},
  {id: 1, massing: 'fat launch tube: flared rear venturi bell, trumpet blast-deflector muzzle, heavy forward collars',
    feed: 'breech latch: hinged loading gate, latch handle, seal stripe',
    muzzle: 'trumpet blast deflector with an eight-port crown ring',
    stock: 'shoulder tube, folding support strut, thick butt pad, vertical foregrip',
    sight: 'iron, plus a folded launcher leaf ladder on the left flank',
    accent: 'orange trim, emissive venturi dot ring, exposed venturi ribs and strap loops'},
  {id: 2, massing: 'long low twin-rail sled: rails run the muzzle and fork forward, rear battery slab',
    feed: 'energy cell: housing, charge window, retaining clips, discharge lead',
    muzzle: 'twin forked rail prongs with a coaxial accelerator ring behind them',
    stock: 'skeleton stock with cheek piece, angled grip',
    sight: 'integrated x3.6 scope with a single elevation turret on the sled',
    accent: 'violet trim, emissive rail tips and accelerator coils, exposed coil rings'},
  {id: 3, massing: 'wide break-action block: ventilated top rib, barrel-selector bar, twin chamber collars',
    feed: 'break-action breech: extractor knuckles, twin chamber faces',
    muzzle: 'twin ported choke sleeves with slanted ports',
    stock: 'wood-tone shoulder stock, comb, squared grip, barrel band',
    sight: 'iron with a brass bead on the top rib',
    accent: 'cream/brass trim, emissive chamber witness, brass rib rail'},
  {id: 4, massing: 'bulbous orb chamber clamped in a slab cradle, slab power pack below',
    feed: 'energy cell: twin cell tubes, windows, heavy latch',
    muzzle: 'three-prong plasma focus cage closing on a front core ring',
    stock: 'short stock with heat-shield plate, grip fin stack',
    sight: 'iron notch/post on a bolted base block over the vented chamber',
    accent: 'blue trim, emissive orb windows and cell windows, ribbed heat sink'},
  {id: 5, massing: 'chunky revolver frame: top strap over a flared drum, legs each side of the cylinder',
    feed: 'revolver drum: fluted rims, indexer yoke, hinge, index marks',
    muzzle: 'heavy bored muzzle, four lateral ports, flared front collar',
    stock: 'shoulder stock, recoil pad, thumb rest',
    sight: 'iron, plus a folded launcher ladder and quadrant on the left flank',
    accent: 'red-orange trim, emissive drum index window, angled slats'},
  {id: 6, massing: 'open fork emitter frame: twin forward prongs, flank capacitor plates, C-yoke barrel',
    feed: 'energy cell: capacitor plates, coil leads, cell housing',
    muzzle: 'twin emitter prongs with discharge tips and a tuning bridge',
    stock: 'insulated cheek plate on the stock, coil-wrapped grip',
    sight: 'iron on an insulated sight rib',
    accent: 'ice-blue trim, emissive discharge tips, exposed coils and insulator discs'},
  {id: 7, massing: 'massive reinforced breech: trunnion discs, left-flank carry handle, heavy flared bell',
    feed: 'ammunition box: lid, latch, belt run into the breech',
    muzzle: 'heavy flared bell with eight radial ports',
    stock: 'heavy stock with recoil buffer, sturdy grip',
    sight: 'iron with a side range drum below the sight line',
    accent: 'amber trim, emissive arming indicator, belt run and shell loops'},
  {id: 8, massing: 'slim precision rifle: long under-receiver chassis spine, folded bipod, rear monopod',
    feed: 'box magazine: witness slot, baseplate, funnel magwell',
    muzzle: 'slim multi-baffle brake with a heat band behind it',
    stock: 'chassis stock, adjustable cheek riser, rear monopod stub',
    sight: 'integrated x3.0 scope with paired elevation and windage turrets',
    accent: 'tan trim, emissive heat band, ribbed barrel flutes'},
  {id: 9, massing: 'stamped SMG: stub receiver, oversized quad-stack magazine, wire stock',
    feed: 'box magazine: oversized quad-stack body, coupling clamp, witness slot',
    muzzle: 'short ported sleeve with a thread collar',
    stock: 'telescoping wire stock with butt plate, light trigger housing',
    sight: 'iron on a stamped rib with a rear drum',
    accent: 'green trim, emissive chamber-port witness, stamped ribs and oversized magazine'},
];

// Material slots the detail pass uses per assembly. export.mjs verifies the
// merged bucket set equals this plan, which is what keeps every weapon at
// exactly eight material batches.
export const SLOTS = [
  {body: ['dark', 'light', 'glow'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light']},
  {body: ['dark', 'light', 'glow'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light']},
  {body: ['dark', 'light'], feed: ['light', 'glow'], bolt: ['trim'], barrel: ['cavity', 'light', 'glow']},
  {body: ['dark', 'light', 'glow'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light']},
  {body: ['dark', 'light', 'glow'], feed: ['light', 'glow'], bolt: ['trim'], barrel: ['cavity', 'light']},
  {body: ['dark', 'light', 'glow'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light']},
  {body: ['dark', 'light', 'glow'], feed: ['light'], bolt: ['trim'], barrel: ['cavity', 'light', 'glow']},
  {body: ['dark', 'light', 'glow'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light']},
  {body: ['dark', 'light'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light', 'glow']},
  {body: ['dark', 'light', 'glow'], feed: ['dark', 'light'], bolt: ['trim'], barrel: ['cavity', 'light']},
];

// Source material remaps that hold the eight-batch budget without touching any
// geometry: the reciprocating action is finished in the shared trim tone, the
// barrel's blued hardware moves to the shared recess tone, and the three
// cell-fed weapons' retaining bar joins the cell body tone.
export function remapFor(id) {
  return {
    bolt: {dark: 'trim', light: 'trim'},
    barrel: id === 6 ? {dark: 'light'} : {dark: 'cavity'},
    feed: id === 6 ? {dark: 'light', glow: 'light'} : [2, 4].includes(id) ? {dark: 'light'} : {},
  };
}

// Interpolated hardpoints shared by every kit.
export function hardpoints(id, ch) {
  const [w, h, len, mz, my, r, stockLen] = ch;
  const front = -len;
  return {
    w, h, len, mz, my, r, stockLen, front,
    top: my + h / 2, bot: my - h / 2, halfW: w / 2,
    rearZ: -.065, frontZ: front - .04,
    railY: my + h / 2 + .012, railHalf: .036,
    barrelLen: front - mz, boreMidZ: (front + mz) / 2,
  };
}

// ---------------------------------------------------------------------------
// Material tone identity (port-side presentation, documented in
// port/native-weapon-detail/WEAPON_IDENTITY.md).
//
// The base tones stay the source palette (`#222f37` blued steel, `#73848a`
// machined aluminium) and the two shared detail materials (`detail-trim`,
// `detail-cavity`) stay byte-identical on every weapon - that is the arsenal
// signature. On top of it each weapon's *own* dark/light instances are mixed a
// fixed fraction toward that weapon's `data.mjs` colour and finished with a
// per-family surface recipe, so the ten weapons stop reading as ten copies of
// one grey gun. Batches are per (assembly, role): this costs zero draw calls.
// ---------------------------------------------------------------------------

// Explicit recipe (source of truth, checked for distinctness by verify.mjs):
// each tone is a mix of the source palette (`#222f37` dark, `#73848a` light)
// toward the weapon's data.mjs colour, then tuned by hand so no two weapons
// share a metal value. Weapons whose source colours are close (7/8) are pushed
// in opposite directions (amber ochre vs light desert tan).
export const TONES = [
  {dark: '#24393a', light: '#6d9391'}, // 0 pulse    - cyan service grey
  {dark: '#2d3327', light: '#757f66'}, // 1 rocket   - drab green tube paint
  {dark: '#2b2a3d', light: '#86829c'}, // 2 rail     - violet-grey anodised
  {dark: '#333a24', light: '#8f8f60'}, // 3 scatter  - olive with brass
  {dark: '#20344a', light: '#6486a8'}, // 4 plasma   - cold steel blue
  {dark: '#3a2a26', light: '#7e6862'}, // 5 grenade  - oxblood parkerised
  {dark: '#24404a', light: '#89adb3'}, // 6 shock    - ice cyan
  {dark: '#3b2f1b', light: '#a87f4a'}, // 7 flak     - amber ochre
  {dark: '#3f3a2f', light: '#b1a68d'}, // 8 marksman - light desert tan
  {dark: '#1c352c', light: '#5b7f75'}, // 9 SMG      - dark green phosphated
];

export function toneFor(id) {
  return TONES[id];
}

// Surface finish per mechanism family: how the same two tones are worked.
// metalness/roughness for the dark and the light tone.
export const FINISH = [
  {dark: [.52, .40], light: [.46, .34]}, // 0 pulse    - standard service finish
  {dark: [.30, .58], light: [.26, .52]}, // 1 rocket   - painted launch tube
  {dark: [.48, .30], light: [.58, .24]}, // 2 rail     - anodised precision
  {dark: [.38, .52], light: [.30, .46]}, // 3 scatter  - blued steel and wood-oil
  {dark: [.58, .26], light: [.66, .20]}, // 4 plasma   - polished alloy
  {dark: [.42, .56], light: [.36, .50]}, // 5 grenade  - heavy matte parkerised
  {dark: [.34, .36], light: [.30, .30]}, // 6 shock    - passivated ice-steel
  {dark: [.26, .62], light: [.22, .56]}, // 7 flak     - thick cast armour paint
  {dark: [.55, .26], light: [.62, .22]}, // 8 marksman - lapped match finish
  {dark: [.28, .54], light: [.24, .48]}, // 9 SMG      - stamped and phosphated
];

class Detail {
  constructor(T, ctx) {
    this.T = T;
    this.ctx = ctx;
    this.stats = {body: 0, feed: 0, bolt: 0, barrel: 0, triangles: 0, primitives: 0, channels: {}};
    this.boxes = [];
    this._inverse = new Map();
    this.owner = 'body';
    this.channel = 'massing';
  }

  _matrix(parent, pos, rot, scale) {
    const T = this.T;
    let inverse = this._inverse.get(parent);
    if (!inverse) {
      parent.updateMatrixWorld(true);
      inverse = parent.matrixWorld.clone().invert();
      this._inverse.set(parent, inverse);
    }
    const target = new T.Matrix4().compose(
      new T.Vector3(pos[0], pos[1], pos[2]),
      new T.Quaternion().setFromEuler(new T.Euler(rot[0], rot[1], rot[2])),
      new T.Vector3(scale[0] ?? 1, scale[1] ?? 1, scale[2] ?? 1),
    );
    return {local: new T.Matrix4().multiplyMatrices(inverse, target), world: target};
  }

  _add(parent, key, make, role, pos, rot = [0, 0, 0], scale = [1, 1, 1]) {
    const T = this.T;
    const geometry = this.ctx.geo(key, make);
    const mesh = new T.Mesh(geometry, this.ctx.detail[role]);
    mesh.name = key;
    const {local, world} = this._matrix(parent, pos, rot, scale);
    local.decompose(mesh.position, mesh.quaternion, mesh.scale);
    mesh.userData.detailChannel = this.channel;
    parent.add(mesh);
    const triangles = (geometry.index ? geometry.index.count : geometry.attributes.position.count) / 3;
    const box = new T.Box3().setFromBufferAttribute(geometry.attributes.position).applyMatrix4(world);
    // Hard guard: a non-finite transform would silently pass the corridor and
    // hand-clearance comparisons (NaN compares false), so refuse it here.
    if (![local.elements, world.elements].every(m => m.every(Number.isFinite)))
      throw new Error(`Non-finite detail transform: ${key}`);
    this.stats[this.owner] = (this.stats[this.owner] ?? 0) + triangles;
    this.stats.triangles += triangles;
    this.stats.primitives += 1;
    this.channel && (this.stats.channels[this.channel] = (this.stats.channels[this.channel] ?? 0) + triangles);
    this.boxes.push({a: this.owner, c: this.channel, k: key,
      min: [+box.min.x.toFixed(5), +box.min.y.toFixed(5), +box.min.z.toFixed(5)],
      max: [+box.max.x.toFixed(5), +box.max.y.toFixed(5), +box.max.z.toFixed(5)]});
    return mesh;
  }

  // Switch the owning assembly and identity channel of the detail that follows,
  // so stats and clearance boxes are attributed to the right moving part.
  enter(owner, channel) {
    this.owner = owner;
    this.channel = channel;
  }

  slot(parent, role, w, h, d, pos, rot = [0, 0, 0]) {
    return this._add(parent, `detail-slot|${w}|${h}|${d}`, () => new this.T.BoxGeometry(w, h, d), role, pos, rot);
  }

  tube(parent, role, r, length, pos, rot = [Math.PI / 2, 0, 0], seg = 10, caps = false) {
    return this._add(parent, `detail-tube|${r}|${length}|${seg}|${caps}`,
      () => new this.T.CylinderGeometry(r, r, length, seg, 1, !caps), role, pos, rot);
  }

  cone(parent, role, r1, r2, length, pos, rot = [Math.PI / 2, 0, 0], seg = 10) {
    return this._add(parent, `detail-cone|${r1}|${r2}|${length}|${seg}`,
      () => new this.T.CylinderGeometry(r1, r2, length, seg, 1, false), role, pos, rot);
  }

  disc(parent, role, r, thickness, pos, rot = [Math.PI / 2, 0, 0], seg = 10) {
    return this._add(parent, `detail-disc|${r}|${thickness}|${seg}`,
      () => new this.T.CylinderGeometry(r, r, thickness, seg, 1, false), role, pos, rot);
  }

  hoop(parent, role, r, tube, pos, rot = [0, 0, 0], seg = 12, radial = 4) {
    return this._add(parent, `detail-hoop|${r}|${tube}|${seg}|${radial}`,
      () => new this.T.TorusGeometry(r, tube, radial, seg), role, pos, rot);
  }

  // Partial torus: strap loops, frame arches, yoke bands.
  strap(parent, role, r, tube, arc, pos, rot = [0, 0, 0], seg = 12, radial = 4) {
    return this._add(parent, `detail-strap|${r}|${tube}|${arc}|${seg}|${radial}`,
      () => new this.T.TorusGeometry(r, tube, radial, seg, arc), role, pos, rot);
  }

  // Two legs and a crossbar: carrying handle / support frame.
  // `span` runs along X (axis 'x') or Z (axis 'z'); `height` is the leg length.
  handle(parent, role, span, height, depth, thickness, pos, axis = 'x') {
    const [x, y, z] = pos;
    const along = axis === 'x' ? [1, 0, 0] : [0, 0, 1];
    const across = axis === 'x' ? [0, 0, 1] : [1, 0, 0];
    const half = (span - thickness) / 2;
    for (const s of [-1, 1]) {
      this.slot(parent, role, across[0] ? depth : thickness, height, across[2] ? depth : thickness,
        [x + along[0] * half * s, y - height / 2, z + along[2] * half * s]);
    }
    this.slot(parent, role, along[0] ? span : depth, thickness, along[2] ? span : depth, [x, y, z]);
  }

  // n identical fins spread along a step vector.
  fins(parent, role, count, w, h, d, pos, step, rot = [0, 0, 0]) {
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i - (count - 1) / 2;
      this.slot(parent, role, w, h, d, [pos[0] + step[0] * t, pos[1] + step[1] * t, pos[2] + step[2] * t], rot);
    }
  }

  // A ring of identical blocks around the bore: ports, prongs, ribs.
  crown(parent, role, count, w, h, d, center, radius, phase = 0, rot = null) {
    for (let i = 0; i < count; i++) {
      const a = TAU * i / count + phase;
      this.slot(parent, role, w, h, d,
        [center[0] + Math.sin(a) * radius, center[1] + Math.cos(a) * radius, center[2]],
        rot ?? [0, 0, -a]);
    }
  }
}

// ---------------------------------------------------------------------------
// Shared kits.
// ---------------------------------------------------------------------------

// Reciprocating-action hardware: the carrier and charging handle are finished
// in the shared trim tone and given serrations, a knurled knob and a case-guide
// lip, so the authoritative carrier travel the handling profile exports reads
// clearly in the viewmodel (motion exaggeration is legibility only; the stroke
// itself stays exactly what tools/godot-weapons/handling.mjs authors).
function boltKit(d, bolt, hp, opts = {}) {
  if (!bolt) return;
  const {my, len, halfW} = hp;
  const x = halfW + .013;
  if (opts.minimal) {
    d.disc(bolt, 'trim', .013, .016, [halfW + .030, my + .015, -len * .38], [0, 0, Math.PI / 2], 8);
    d.slot(bolt, 'trim', .010, .018, .048, [x + .013, my + .015, -len * .45]);
    return;
  }
  d.fins(bolt, 'trim', 4, .012, .009, .012, [x + .015, my + .015, -len * .45], [0, 0, .013]);
  d.disc(bolt, 'trim', .013, .018, [halfW + .030, my + .015, -len * .38], [0, 0, Math.PI / 2], 10);
  d.slot(bolt, 'trim', .010, .020, .052, [x + .013, my + .015, -len * .47]);
  d.slot(bolt, 'trim', .014, .008, .040, [x + .004, my - .004, -len * .42], [0, 0, .18]);
}

// Toothed rail plus a bolted front-sight base. Everything stays at or below the
// rail top and on the rail flanks, so the sight corridor is untouched.
function railKit(d, body, hp, opts) {
  const {top, my, len, rearZ, frontZ, railY, railHalf} = hp;
  if (opts.minimal) {
    // Integrated-optic weapons dress only the turret hardware: the Rail Lance
    // carries a single elevation turret on its sled, the Marksman a paired set.
    const z = -.055 - .160, count = opts.turrets ?? 2;
    for (const s of [-1, 1].slice(0, count)) d.slot(body, 'light', .020, .026, .026, [s * .040, top + .019, z]);
    return;
  }
  const span = rearZ - frontZ;
  for (let i = 0; i < (opts.teeth ?? 3); i++) {
    const z = frontZ + span * (.18 + .30 * i);
    for (const s of [-1, 1]) d.slot(body, 'light', .010, .020, .016, [s * (railHalf + .005), railY - .002, z]);
  }
  d.slot(body, 'dark', .078, .026, .046, [0, railY - .003, frontZ + .004]);
  for (const s of [-1, 1]) d.slot(body, 'light', .010, .014, .012, [s * .044, railY - .001, frontZ + .004]);
  if (opts.scope) {
    // Optic turrets sit beside the tube (outside it) on the source mount posts.
    const scopeY = top + .079, z = -.055 - .160;
    for (const s of [-1, 1]) {
      d.disc(body, 'light', .010, .018, [s * .055, scopeY, z], [0, 0, Math.PI / 2], 8);
      d.slot(body, 'light', .024, .030, .030, [s * .040, top + .019, z]);
    }
    d.slot(body, 'dark', .026, .013, .038, [0, scopeY + .056, z]);
  }
}

// Ejection-port treatment at the authored station.
function portKit(d, body, hp, pos) {
  const x = hp.halfW + .006;
  d.slot(body, 'dark', .012, .034, .056, [x, pos[1], pos[2]]);
  d.slot(body, 'light', .014, .010, .062, [x + .004, pos[1] + .026, pos[2]], [0, 0, -.18]);
  d.slot(body, 'light', .010, .008, .020, [x + .002, pos[1] - .021, pos[2] - .021]);
}

// Heat-zone louvres on the lower barrel flanks, exactly around HeatZone.
function heatVents(d, barrel, hp, count, spread) {
  const {my, r, mz, barrelLen} = hp;
  const start = mz + barrelLen * .30;
  for (let i = 0; i < count; i++) {
    const z = start - spread * (i - (count - 1) / 2);
    for (const s of [-1, 1]) {
      const a = s * (.55 + .95 * (count === 1 ? .5 : i / (count - 1)));
      const radius = r + .004;
      d.slot(barrel, 'cavity', .014, .022, .026,
        [Math.sin(a) * radius, my - Math.cos(a) * radius, z], [0, 0, Math.PI + a]);
    }
  }
}

// A slotted sleeve around a bore with a machined rim. Shape, radius and
// position follow the identity channel; only the tessellation is ours.
function muzzleSleeve(d, barrel, hp, opts = {}) {
  const {mz, my, r} = hp;
  const x = opts.x ?? 0, radius = opts.radius ?? r + .014;
  const length = opts.length ?? .060, ports = opts.ports ?? 6;
  const role = opts.role ?? 'cavity', z0 = mz + .004;
  d.tube(barrel, role, radius, length, [x, my, z0 + length / 2], [Math.PI / 2, 0, 0], opts.seg ?? 10);
  for (let i = 0; i < ports; i++) {
    const a = TAU * i / ports + (opts.phase ?? 0);
    d.slot(barrel, role, .014, .016, .014,
      [x + Math.sin(a) * radius * .86, my + Math.cos(a) * radius * .86, z0 + length * (opts.portAt ?? .55)], [0, 0, -a]);
  }
  if (opts.crown !== false) {
    // Machined rim: an open tube reads as a chunky collar at one third of the
    // cost of the old torus and does not change the bore.
    d.tube(barrel, 'light', radius + .005, .018, [x, my, z0 + length + .012], [Math.PI / 2, 0, 0], 12);
  }
  return {radius, z0, z1: z0 + length};
}

// Fixed weapon-space point on the rotated source magazine axis, used to extend
// a magazine without moving the source mesh. `tilt` is the source rotation and
// `down` the distance below the source magazine center.
function feedAxis(fb, tilt, down) {
  // `fb` is a three.js Box3 from the exporter (or the named-key fallback).
  const c = [(fb.min.x + fb.max.x) / 2, (fb.min.y + fb.max.y) / 2, (fb.min.z + fb.max.z) / 2];
  const angle = tilt ?? 0;
  return [c[0], c[1] - Math.cos(angle) * down, c[2] + Math.sin(angle) * down];
}

// ---------------------------------------------------------------------------
// Per-weapon detail: the concrete expression of the six identity channels.
// `bd` is the pre-pass weapon-space bounds map for body/feed/bolt/barrel.
// ---------------------------------------------------------------------------

// 0 Pulse Rifle - the slender carbine. One long perforated shroud, a slim
// dorsal spine and a skeleton stock; nothing chunky anywhere.
function pulseRifle(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW, railY} = hp;
  const body = g, barrel = parts.barrel, mag = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.04, y: bot - .30, z: -.30}, max: {x: .04, y: bot, z: -.18}};
  const guardLen = hp.barrelLen * .64, guardZ = front - guardLen / 2;
  d.enter('body', 'massing');
  // Dorsal spine: a low rail of machined blocks along the receiver crown and a
  // squared front trunnion where the shroud begins.
  d.slot(body, 'light', .038, .018, len * .70, [0, top + .007, -len * .44]);
  for (let i = 0; i < 3; i++) d.slot(body, 'dark', .030, .012, .020, [0, top + .014, -len * .20 - .090 * i]);
  d.slot(body, 'dark', .050, .026, .062, [0, top + .004, -len * .64]);
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .010, h * .34, len * .56, [s * (halfW + .005), my - .012, -len * .46]);
    d.slot(body, 'dark', .008, h * .10, len * .28, [s * (halfW + .008), my - h * .30, -len * .52]);
    d.slot(body, 'light', .014, .046, .022, [s * (halfW + .004), my + .014, -len + .012]);
  }
  portKit(d, body, hp, [halfW + .010, my + h * .12, -len * .40]);
  d.enter('feed', 'feed');
  if (mag) {
    // Slim box magazine, dressed as the identity channel describes: flare,
    // witness slot, floorplate lip and an ambidextrous catch.
    d.slot(mag, 'dark', .084, .024, .104, [0, fb.max.y - .006, (fb.min.z + fb.max.z) / 2]);
    d.slot(mag, 'light', .010, .034, .028, [fb.max.x + .005, fb.min.y + .115, (fb.min.z + fb.max.z) / 2]);
    d.fins(mag, 'dark', 3, .008, .012, .014, [fb.max.x + .002, fb.min.y + .150, fb.min.z + .020], [0, .020, 0]);
    d.slot(mag, 'light', .076, .018, fb.max.z - fb.min.z + .010, [0, fb.min.y - .008, (fb.min.z + fb.max.z) / 2]);
    d.slot(mag, 'dark', .090, .014, .028, [0, fb.min.y + .030, fb.max.z - .004]);
  }
  d.enter('barrel', 'muzzle');
  // Perforated shroud: a real tube around the rear barrel with two rows of
  // perforations, so the muzzle end reads as a vented barrel, not a plain rod.
  d.tube(barrel, 'light', r + .026, guardLen, [0, my, guardZ]);
  for (let i = 0; i < 4; i++) {
    const z = guardZ - guardLen * .30 + .075 * i;
    for (const s of [-1, 1]) {
      const a = s * .95;
      d.slot(barrel, 'cavity', .012, .018, .034,
        [Math.sin(a) * (r + .026) * .99, my + Math.cos(a) * (r + .026) * .99, z], [0, 0, -a]);
    }
  }
  d.tube(barrel, 'cavity', r + .030, .022, [0, my, front - .010]);
  d.tube(barrel, 'light', r + .032, .016, [0, my, front - .030]);
  muzzleSleeve(d, barrel, hp, {ports: 6, length: .070, radius: r + .018});
  heatVents(d, barrel, hp, 3, .13);
  d.enter('body', 'stock');
  // Skeleton stock: two rails and a slotted comb leave daylight through the
  // rear of the weapon, the carbine's own read.
  d.slot(body, 'light', .030, .030, stockLen * .72, [0, my + .014, stockLen * .42]);
  d.slot(body, 'light', .030, .026, stockLen * .58, [0, my - .056, stockLen * .38]);
  d.slot(body, 'dark', .050, .020, .034, [0, my - .020, stockLen * .26]);
  d.slot(body, 'dark', .072, .026, .026, [0, my - .020, stockLen + .004]);
  d.slot(body, 'light', .046, .014, .030, [0, bot - .052, .030]);
  d.slot(body, 'dark', .040, .018, .018, [0, bot - .174, -.026]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.enter('body', 'accent');
  d.slot(body, 'glow', .005, .010, .200, [-(halfW + .012), my + .024, -len * .52]);
  d.slot(body, 'light', .016, .018, .028, [-(halfW + .026), my - h * .40, guardZ - guardLen * .30]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 1 Rocket Launcher - the fat tube. A trumpet blast deflector at the muzzle
// and a flared venturi bell at the shoulder, with heavy collars between.
function rocketLauncher(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, latch = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.15, y: my - .14, z: -.38}, max: {x: -.05, y: my - .10, z: -.22}};
  d.enter('body', 'massing');
  // Launch tube: two long rail strips, then the rear venturi bell. The bell is
  // the weapon's signature: it flares *outward* past the source tube radius.
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, .074, len * .70, [s * (halfW + .006), my + .050, -len * .44]);
    d.slot(body, 'dark', .010, .048, len * .30, [s * (halfW + .010), my - .058, -len * .30]);
  }
  // The source vents the tube rearward; author the bell *behind* the corridor
  // limit (z > +0.095) so the flare hangs off the shoulder end of the tube.
  const venturiZ = .135;
  // The bell top stays 20 mm below the sight line (y = top + .075): the ADS
  // target gap above the front post is measured at 4x4 px and must stay open.
  d.cone(body, 'dark', r + .012, r + .055, .070, [0, my, venturiZ], [Math.PI / 2, 0, 0], 12);
  d.tube(body, 'light', r + .059, .018, [0, my, venturiZ + .044]);
  d.crown(body, 'light', 4, .024, .014, .024, [0, my, venturiZ], r + .030, TAU / 8);
  d.crown(body, 'glow', 4, .020, .014, .012, [0, my, venturiZ + .048], r + .060, TAU / 8);
  // Heavy forward collars, sized and placed to clear the live support hand
  // (the station clears the barrel by only ~13 mm, so they sit at the muzzle
  // end where the hand never travels).
  for (const z of [mz + .070, mz + .022]) {
    d.tube(body, 'light', r + .008, .024, [0, my, z]);
    d.tube(body, 'dark', r + .011, .008, [0, my, z + .016]);
  }
  d.enter('body', 'accent');
  d.enter('feed', 'feed');
  if (latch) {
    d.slot(latch, 'light', .084, .014, .014, [fb.max.x - .046, fb.min.y + .060, fb.min.z - .006]);
    d.slot(latch, 'dark', .092, .016, .012, [fb.max.x - .046, fb.min.y + .036, fb.min.z - .008]);
    d.slot(latch, 'light', .046, .014, .038, [fb.max.x - .046, fb.max.y + .006, fb.min.z + .044]);
    d.slot(latch, 'dark', .070, .010, .060, [fb.max.x - .046, fb.min.y + .012, fb.min.z - .046]);
  }
  d.enter('barrel', 'muzzle');
  // Trumpet blast deflector: an outward flare, a recessed mouth and a ring of
  // radial relief ports; the bore is still the source bore.
  d.cone(barrel, 'light', r + .024, r + .046, .052, [0, my, mz + .032], [Math.PI / 2, 0, 0], 14);
  d.tube(barrel, 'cavity', r + .048, .016, [0, my, mz + .006]);
  d.crown(barrel, 'cavity', 8, .018, .022, .018, [0, my, mz + .048], r + .030, TAU / 16);
  d.enter('body', 'stock');
  // Shoulder support: a folding strut, a thick butt pad and a vertical
  // foregrip well forward of the support hand.
  d.slot(body, 'light', .036, .106, .030, [.104, my - .062, -.150], [0, 0, -.22]);
  d.slot(body, 'dark', .156, .104, .032, [0, my - .030, stockLen + .008]);
  d.slot(body, 'light', .060, .020, .072, [0, my - .086, stockLen - .030]);
  d.slot(body, 'dark', .052, .132, .062, [0, my - .212, -.380]);
  d.slot(body, 'light', .040, .022, .074, [0, my - .150, -.380]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 2, scope: false});
  const ladderY = top - .020, lx = -(halfW + .014);
  d.slot(body, 'dark', .014, .038, .130, [lx, ladderY, -.130], [0, 0, .10]);
  for (let i = 0; i < 4; i++) d.slot(body, 'light', .010, .026, .012, [lx - .008, ladderY + .006, -.084 - .030 * i], [0, 0, .10]);
  d.slot(body, 'light', .012, .014, .024, [lx - .010, ladderY + .034, -.190]);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .010, .010, .010, [halfW + .020, my - .052, -.150]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 2 Rail Lance - the long low sled. Twin rails run the whole barrel and fork
// forward past the muzzle; a battery slab and coil rings carry the energy read.
function railLance(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, cell = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .20, z: -.37}, max: {x: .07, y: bot - .05, z: -.19}};
  const railX = .066, railY = my + .038;
  // The locked source construction for the Rail Lance (twin accelerator rails
  // plus an integrated x3.6 optic, with the optic's author-tessellated rings
  // preserved) already spends ~6.1k triangles, so this weapon's detail is
  // authored to a tight ceiling: the forked rail tips, the accelerator rings
  // and the battery slab - no optional dressing.
  d.enter('body', 'massing');
  for (const s of [-1, 1]) d.slot(body, 'light', .012, h * .38, len * .60, [s * (halfW + .005), my - h * .06, -len * .44]);
  d.slot(body, 'dark', w * .80, .016, len * .72, [0, top + .012, -len * .52]);
  d.enter('barrel', 'accent');
  for (const s of [-1, 1]) {
    // Rail tips: the sled's rails continue past the muzzle as two flat prongs.
    d.slot(barrel, 'light', .022, .048, .150, [s * railX, railY - .020, mz - .062]);
    d.slot(barrel, 'glow', .012, .016, .034, [s * railX, railY - .020, mz - .142]);
    // Accelerator collars on the rails.
    d.tube(barrel, 'glow', .042, .018, [s * railX, railY + .006, -.34]);
    d.slot(barrel, 'light', .034, .074, .018, [s * railX, railY, -.245]);
  }
  d.enter('feed', 'feed');
  if (cell) {
    // Front-face clips only: the reload palm grips the cell's left flank.
    d.slot(cell, 'light', .104, .014, .012, [0, fb.max.y - .060, fb.min.z - .006]);
    d.slot(cell, 'glow', .012, .040, .034, [fb.max.x + .004, fb.max.y - .078, fb.max.z - .020]);
  }
  d.enter('body', 'massing');
  // Battery slab under the receiver: the sled's power body.
  d.slot(body, 'dark', .150, .052, .210, [0, bot - .030, -.210]);
  d.slot(body, 'light', .100, .014, .034, [0, bot - .056, -.150]);
  d.enter('barrel', 'muzzle');
  for (const s of [-1, 1]) {
    d.tube(barrel, 'cavity', r + .058, .016, [s * railX, my, mz + .030]);
    d.slot(barrel, 'light', .012, .020, .076, [s * railX, my + .044, mz + .048]);
  }
  heatVents(d, barrel, hp, 1, .12);
  d.enter('body', 'stock');
  d.slot(body, 'light', .030, .028, stockLen * .70, [0, top - .020, stockLen * .42]);
  d.slot(body, 'dark', .070, .024, .024, [0, my - .020, stockLen + .002]);
  // Rear battery pack: the sled's power shoulder, behind the sight corridor.
  d.slot(body, 'light', .132, .036, .086, [0, top - .035, stockLen - .078]);
  d.slot(body, 'dark', .030, .024, .098, [0, top - .012, stockLen - .078]);
  d.slot(body, 'light', .060, .014, .026, [0, top - .035, stockLen - .116]);
  d.enter('body', 'sight');
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp, {minimal: true});
}

// 3 Scattergun - the wide break action. A ventilated top rib over twin bores,
// a broad fore-end and a barrel band; the outline is wide and blunt.
function scattergun(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, breech = parts.magazine;
  const x = .12, barrelLen = hp.barrelLen;
  d.enter('body', 'massing');
  // Wide ventilated top rib along the receiver crown.
  d.slot(body, 'light', w * .82, .020, len * .70, [0, top - .006, -len * .46]);
  for (let i = 0; i < 5; i++) d.slot(body, 'dark', .070, .016, .018, [0, top + .002, -len * .24 - .062 * i]);
  // Wide breech-block flanks and a selector bar on the left.
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, h * .46, len * .30, [s * (halfW + .006), my - .004, -len * .30]);
    d.slot(body, 'dark', .012, h * .16, len * .44, [s * (halfW + .010), my - h * .30, -len * .46]);
  }
  d.slot(body, 'dark', .018, .030, .150, [-(halfW + .014), my + .020, -len * .40]);
  d.slot(body, 'light', .022, .022, .030, [-(halfW + .022), my + .038, -len * .32]);
  d.enter('feed', 'feed');
  if (breech) {
    for (const s of [-1, 1]) {
      d.disc(breech, 'dark', .048, .018, [s * x, my - .040, mz + barrelLen * .98], [Math.PI / 2, 0, 0], 10);
      d.slot(breech, 'light', .020, .046, .030, [s * x, my - .030, -.124]);
    }
    d.slot(breech, 'light', .116, .016, .042, [0, my + .048, -.150]);
    d.slot(breech, 'light', .032, .016, .036, [0, my + .072, -.130]);
    d.slot(breech, 'dark', .230, .014, .052, [0, my - .004, -.196]);
  }
  d.enter('barrel', 'muzzle');
  for (const s of [-1, 1]) {
    muzzleSleeve(d, barrel, hp, {ports: 4, length: .056, radius: r + .024, crown: false, x: s * x, phase: .4});
    d.tube(barrel, 'light', r + .030, .018, [s * x, my, mz + .004]);
  }
  d.enter('barrel', 'accent');
  // Brass rib between the bores, with the bead at the muzzle end.
  d.slot(barrel, 'light', .028, .014, barrelLen * .68, [0, my + r + .012, (front + mz) / 2 + .02]);
  d.slot(barrel, 'light', .020, .012, .016, [0, my + r + .024, mz + .030]);
  // Barrel band and the wide fore-end under the bores.
  d.slot(barrel, 'dark', .304, .032, .044, [0, my - r - .030, mz + .170]);
  d.slot(body, 'light', w * .88, .042, .170, [0, my - r - .048, front + .095]);
  for (let i = 0; i < 4; i++) d.slot(body, 'dark', w * .78, .012, .014, [0, my - r - .064, front + .045 + .036 * i]);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .62, h * .34, stockLen * .70, [0, my + h * .22, stockLen * .40]);
  d.slot(body, 'dark', .146, .062, .030, [0, my - .030, stockLen + .008]);
  d.slot(body, 'light', .062, .030, .042, [-.100, my - .075, -.036], [0, 0, .20]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 2, scope: false});
  d.slot(body, 'light', .012, .012, .012, [-.030, top + .015, front - .05]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 4 Plasma Driver - the orb chamber. A bulbous clamped chamber dominates the
// middle of the weapon and a three-prong focus cage reaches past the muzzle.
function plasmaDriver(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, cell = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .20, z: -.37}, max: {x: .07, y: bot - .02, z: -.19}};
  const orbZ = -.345, orbR = .122;
  d.enter('body', 'massing');
  // The chamber: two turned bulbs on the bore axis (a big rear bulb and a
  // smaller forward one), clamped by slab frames and lit through side windows.
  // Nothing else on the weapon is this round; the top stays under the corridor
  // floor (top + .026) by construction.
  d.disc(body, 'light', orbR, .150, [0, my, orbZ]);
  d.disc(body, 'light', .098, .090, [0, my, orbZ - .075]);
  d.tube(body, 'dark', .102, .016, [0, my, orbZ - .026]);
  d.disc(body, 'dark', orbR + .004, .022, [0, my, orbZ + .078]);
  for (const s of [-1, 1]) {
    d.slot(body, 'glow', .006, .048, .078, [s * (orbR + .002), my, orbZ]);
    d.slot(body, 'dark', .020, .156, .176, [s * (orbR + .010), my - .020, orbZ]);
    d.slot(body, 'light', .014, .026, .040, [s * (orbR + .022), my + .062, orbZ - .030]);
  }
  d.slot(body, 'dark', .190, .020, .120, [0, top - .014, -.300]);
  // Cradle strap under the chamber: a half-hoop clamp, well clear of the
  // reload hand (which reaches the cell two stations forward).
  d.strap(body, 'dark', orbR + .012, .016, Math.PI, [0, my, orbZ], [0, 0, Math.PI], 10, 3);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .056, .012, .022, [0, my + h * .29, -.432]);
  d.slot(body, 'light', .068, .016, .016, [0, my + h * .29, -.448]);
  d.enter('feed', 'feed');
  if (cell) {
    // Twin cell tubes under the chamber.
    for (const s of [-1, 1]) {
      d.tube(cell, 'light', .026, .150, [s * .038, fb.max.y - .062, -.280]);
      d.disc(cell, 'glow', .022, .012, [s * .038, fb.max.y - .062, fb.min.z - .010]);
    }
    d.slot(cell, 'dark', .132, .020, .150, [0, fb.max.y - .010, -.280]);
    d.slot(cell, 'light', .124, .016, .026, [0, fb.min.y + .016, fb.min.z - .012]);
  }
  d.enter('barrel', 'muzzle');
  // Focus cage: three prongs closing on a front core ring past the muzzle.
  for (let i = 0; i < 3; i++) {
    const a = TAU * i / 3;
    d.slot(barrel, 'light', .018, .048, .140, [Math.sin(a) * (r + .042), my + Math.cos(a) * (r + .042), mz + .080], [0, 0, -a]);
  }
  d.tube(barrel, 'light', r + .062, .020, [0, my, mz + .156]);
  d.disc(barrel, 'cavity', r + .030, .014, [0, my, mz + .170]);
  heatVents(d, barrel, hp, 3, .13);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .60, h * .28, stockLen * .58, [0, my + h * .20, stockLen * .36]);
  d.slot(body, 'dark', .106, .058, .024, [0, my - .050, stockLen - .012]);
  // Round flank heat exchangers above the chamber: the orb's own shoulder
  // silhouette, outside the sight corridor (|x| > 46 mm) by construction.
  for (const s of [-1, 1]) {
    d.disc(body, 'light', .058, .020, [s * (halfW + .024), my + .056, -.150], [0, 0, Math.PI / 2], 10);
  }
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 5 Grenade Launcher - the squat drum. A top strap bridges a flared, slatted
// drum; the frame is chunky and low and the muzzle is a heavy collar.
function grenadeLauncher(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, drum = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.20, y: my - .30, z: -.38}, max: {x: .14, y: my - .04, z: -.12}};
  const drumY = my - .17, drumZ = -.25;
  d.enter('body', 'massing');
  // Revolver frame: a top strap over the drum with two legs down its sides.
  d.slot(body, 'dark', .206, .026, .176, [0, my - .006, drumZ]);
  for (const s of [-1, 1]) d.slot(body, 'dark', .024, .128, .032, [s * .090, my - .076, drumZ]);
  d.slot(body, 'light', .030, .020, .180, [0, my - .022, drumZ - .020]);
  d.slot(body, 'glow', .020, .016, .018, [0, my - .026, drumZ + .052]);
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, .070, len * .58, [s * (halfW + .005), my - .024, -len * .40]);
    d.slot(body, 'dark', .010, .050, .132, [s * (halfW + .012), my - .092, -.150]);
  }
  d.enter('feed', 'feed');
  if (drum) {
    // Flared drum rims and angled slats: the cylinder reads immediately.
    for (const s of [-1, 1]) {
      d.disc(drum, 'light', .148, .018, [0, drumY, drumZ + s * .118], [Math.PI / 2, 0, 0], 14);
      d.crown(drum, 'dark', 6, .040, .016, .014, [0, drumY, drumZ + s * .130], .118, TAU / 12);
    }
    d.slot(drum, 'light', .018, .034, .016, [0, drumY + .140, drumZ]);
    d.slot(drum, 'light', .028, .028, .024, [fb.max.x - .006, drumY, drumZ + .060]);
    d.slot(drum, 'dark', .026, .050, .040, [0, fb.min.y + .012, drumZ + .020]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 4, length: .060, radius: r + .022});
  d.tube(barrel, 'light', r + .032, .022, [0, my, mz + .006]);
  d.cone(barrel, 'cavity', r + .036, r + .014, .032, [0, my, mz + .076]);
  heatVents(d, barrel, hp, 3, .10);
  d.enter('body', 'accent');
  for (const s of [-1, 1]) d.fins(body, 'light', 4, .014, .030, .020, [s * (halfW + .014), my - .026, -len * .62], [0, 0, .35]);
  d.slot(body, 'dark', .086, .014, .032, [-.060, my - h * .38, -.120]);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .66, h * .32, stockLen * .62, [0, my + h * .20, stockLen * .36]);
  d.slot(body, 'dark', .122, .070, .028, [0, my - .040, stockLen - .012]);
  d.slot(body, 'light', .052, .022, .036, [.082, my - .062, -.044]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 2, scope: false});
  const lx = -(halfW + .016);
  d.slot(body, 'dark', .014, .038, .142, [lx, top - .036, -.170], [0, 0, .12]);
  for (let i = 0; i < 5; i++) d.slot(body, 'light', .010, .024, .010, [lx - .008, top - .028, -.108 - .028 * i], [0, 0, .12]);
  d.slot(body, 'light', .014, .016, .026, [lx - .010, top + .002, -.230]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 6 Shock Beam - the fork. Twin prongs carry the discharge past the muzzle and
// a tuning bridge ties them, while the barrel keeps the source C-yokes.
function shockBeam(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, cell = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .20, z: -.37}, max: {x: .07, y: bot - .05, z: -.19}};
  const x = .092;
  d.enter('body', 'massing');
  // Flank capacitor plates: two stacked slabs each side, with an insulator disc.
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .020, .078, .200, [s * (halfW + .016), my + .028, -len * .40]);
    d.slot(body, 'light', .016, .052, .130, [s * (halfW + .022), my - .052, -len * .30]);
    d.disc(body, 'dark', .032, .022, [s * (halfW + .034), my + .010, -len * .62], [0, 0, Math.PI / 2], 10);
    d.disc(body, 'light', .020, .030, [s * (halfW + .048), my + .010, -len * .62], [0, 0, Math.PI / 2], 8);
  }
  d.slot(body, 'light', w * .78, .016, .022, [0, top - .014, front + .020]);
  // Dorsal capacitor comb: square plates standing off both receiver flanks -
  // the Shock Beam's square counterpoint to the Plasma Driver's round discs.
  for (const s of [-1, 1]) d.fins(body, 'light', 4, .012, .088, .028, [s * (halfW + .012), top + .030, -len * .36], [0, 0, .03]);
  d.slot(body, 'glow', .006, .012, .180, [-(halfW + .012), top + .074, -len * .36]);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .005, .010, .140, [-(halfW + .014), my + .036, -len * .60]);
  d.enter('feed', 'feed');
  if (cell) {
    d.slot(cell, 'light', .120, .020, .026, [0, fb.min.y + .018, fb.min.z - .012]);
    for (const s of [-1, 1]) {
      d.disc(cell, 'light', .034, .020, [s * .040, fb.max.y - .046, fb.min.z - .012], [Math.PI / 2, 0, 0], 10);
      d.slot(cell, 'light', .014, .026, .074, [s * (fb.max.x + .004), fb.max.y - .030, fb.min.z + .016]);
    }
  }
  d.enter('barrel', 'muzzle');
  // The fork: two long prongs reach past the muzzle with glow discharge tips
  // and a tuning bridge, so the emitter end is unmistakably open.
  for (const s of [-1, 1]) {
    d.slot(barrel, 'light', .024, .058, .250, [s * x, my + .012, mz - .112]);
    d.cone(barrel, 'light', .017, .007, .056, [s * x, my + .012, mz - .264]);
    d.slot(barrel, 'glow', .016, .026, .040, [s * x, my + .012, mz - .206]);
    d.slot(barrel, 'cavity', .008, .062, .056, [s * (x - .016), my + .012, mz - .066]);
  }
  d.slot(barrel, 'cavity', .216, .018, .026, [0, my + .008, mz - .222]);
  d.disc(barrel, 'light', .040, .024, [0, my + .008, mz - .222], [0, 0, Math.PI / 2], 10);
  heatVents(d, barrel, hp, 3, .10);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .60, h * .28, stockLen * .56, [0, my + h * .20, stockLen * .34]);
  d.slot(body, 'light', .068, .028, stockLen * .52, [0, my + h * .30, stockLen * .42]);
  d.slot(body, 'dark', .096, .048, .022, [0, my - .040, stockLen - .012]);
  // Rear capacitor stack: three insulated discs behind the sight corridor,
  // the Shock Beam's signature rear mass.
  for (let i = 0; i < 3; i++) d.disc(body, i === 1 ? 'glow' : 'light', .050, .018, [0, top - .008, .106 + .028 * i], [Math.PI / 2, 0, 0], 12);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 7 Flak Cannon - the boxy breech. Trunnion discs and a left-flank carry
// handle carry the read; the muzzle ends in a heavy flared bell.
function flakCannon(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, box = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.25, y: bot - .30, z: -.38}, max: {x: .11, y: bot - .02, z: -.18}};
  d.enter('body', 'massing');
  // Reinforced breech: long slab flanks, a trunnion disc each side, a top rib.
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .018, .104, len * .54, [s * (halfW + .008), my + .030, -len * .40]);
    d.slot(body, 'dark', .012, .058, .140, [s * (halfW + .012), my - .062, -len * .26]);
    d.disc(body, 'dark', .050, .028, [s * (halfW + .028), my - .022, -len * .36], [0, 0, Math.PI / 2], 12);
    d.disc(body, 'light', .028, .034, [s * (halfW + .048), my - .022, -len * .36], [0, 0, Math.PI / 2], 8);
  }
  d.slot(body, 'light', w * .58, .030, .140, [0, top - .006, -.070]);
  // Left-flank carry handle: legs and a bar, clear of the sight corridor.
  d.handle(body, 'light', .140, .086, .022, .020, [-(halfW + .024), top + .060, -.020], 'z');
  d.enter('body', 'accent');
  // Belt run up the left flank into the breech.
  for (let i = 0; i < 7; i++) {
    d.slot(body, 'light', .020, .018, .016, [-(halfW + .012), my - .118 + .030 * i, -.268 + .020 * i], [0, 0, .30]);
  }
  d.slot(body, 'dark', .024, .018, .112, [-(halfW + .018), my - .110, -.212]);
  d.slot(body, 'glow', .014, .014, .014, [0, top + .006, -.078]);
  d.enter('feed', 'feed');
  if (box) {
    const centre = [(fb.min.x + fb.max.x) / 2, (fb.min.z + fb.max.z) / 2];
    d.slot(box, 'dark', fb.max.x - fb.min.x - .004, .024, fb.max.z - fb.min.z - .010, [centre[0], fb.min.y - .016, centre[1]]);
    for (const s of [-1, 1]) {
      d.slot(box, 'light', .014, .030, fb.max.z - fb.min.z - .022, [centre[0] + s * (fb.max.x - fb.min.x - .020) / 2, fb.min.y + .072, centre[1]]);
    }
    d.slot(box, 'light', .058, .020, .068, [centre[0], fb.max.y - .006, centre[1]]);
    // Shell loops along the box front face.
    for (let i = 0; i < 4; i++) {
      d.slot(box, 'light', .014, .016, .012, [centre[0] - .060 + .040 * i, fb.min.y + .150, fb.min.z - .008]);
    }
  }
  d.enter('barrel', 'muzzle');
  // Heavy flared bell with eight radial ports.
  d.cone(barrel, 'light', r + .020, r + .076, .058, [0, my, mz + .036], [Math.PI / 2, 0, 0], 14);
  d.tube(barrel, 'cavity', r + .078, .016, [0, my, mz + .006]);
  d.crown(barrel, 'cavity', 8, .020, .024, .020, [0, my, mz + .052], r + .058, TAU / 16);
  heatVents(d, barrel, hp, 4, .14);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .58, h * .32, stockLen * .62, [0, my + h * .20, stockLen * .38]);
  d.slot(body, 'dark', .140, .078, .030, [0, my - .040, stockLen + .006]);
  d.slot(body, 'light', .054, .026, .042, [0, bot - .196, -.034]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.disc(body, 'light', .024, .028, [-(halfW + .020), my + h * .16, -.120], [0, 0, Math.PI / 2], 10);
  d.slot(body, 'dark', .012, .018, .018, [-(halfW + .034), my + h * .16, -.120]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 8 Marksman Rifle - the long precision rifle. A chassis spine runs under the
// receiver, a folded bipod hangs off the barrel and a monopod steadies the butt.
function marksmanRifle(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, mag = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .30, z: -.30}, max: {x: .07, y: bot, z: -.18}};
  d.enter('body', 'massing');
  // Chassis spine under the receiver and a low cheek rail on the crown.
  d.slot(body, 'light', w * .72, .038, len * .74, [0, bot - .020, -len * .46]);
  d.slot(body, 'dark', .020, .022, len * .30, [0, bot - .042, -len * .30]);
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .30, len * .52, [s * (halfW + .005), my - .020, -len * .46]);
    d.slot(body, 'dark', .010, h * .14, len * .30, [s * (halfW + .010), my - h * .28, -len * .34]);
  }
  d.slot(body, 'light', .038, .012, .110, [0, top + .004, -.140]);
  portKit(d, body, hp, [halfW + .010, my + h * .12, -len * .40]);
  d.enter('feed', 'feed');
  if (mag) {
    d.slot(mag, 'light', fb.max.x - fb.min.x + .008, .018, .024, [0, fb.min.y + .016, fb.max.z + .010]);
    d.slot(mag, 'light', .010, .028, .022, [fb.max.x + .004, fb.min.y + .070, (fb.min.z + fb.max.z) / 2]);
    d.fins(mag, 'light', 2, .010, .010, .010, [0, fb.min.y + .072, fb.min.z - .006], [.020, 0, 0]);
    d.slot(mag, 'dark', .096, .020, .028, [0, fb.max.y - .020, (fb.min.z + fb.max.z) / 2 + .004]);
  }
  d.enter('barrel', 'muzzle');
  const brake = r + .012;
  d.tube(barrel, 'cavity', brake, .104, [0, my, mz + .056]);
  for (let i = 0; i < 2; i++) d.tube(barrel, 'cavity', brake + .006, .014, [0, my, mz + .024 + .032 * i], [Math.PI / 2, 0, 0], 8);
  d.tube(barrel, 'light', brake + .008, .022, [0, my, mz + .118]);
  d.tube(barrel, 'glow', r + .012, .016, [0, my, mz + .140]);
  heatVents(d, barrel, hp, 3, .16);
  // Folded bipod: hinge block and two legs under the barrel, forward of the
  // support hand.
  d.slot(barrel, 'dark', .048, .032, .044, [0, my - r - .034, -len - .160]);
  for (const s of [-1, 1]) {
    d.slot(barrel, 'light', .014, .024, .132, [s * .052, my - r - .086, -len - .216], [.34, 0, s * .30]);
    d.slot(barrel, 'cavity', .020, .014, .022, [s * .052, my - r - .146, -len - .264]);
  }
  d.enter('barrel', 'accent');
  d.fins(barrel, 'light', 4, .016, .018, .056, [0, my - r - .007, mz + .250], [.10, 0, 0]);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .64, h * .28, stockLen * .58, [0, my + h * .20, stockLen * .34]);
  d.slot(body, 'dark', .098, .050, .024, [0, my - .050, stockLen - .012]);
  // Adjustable cheek riser and a rear monopod stub.
  d.slot(body, 'light', .072, .026, .120, [0, top + .016, stockLen * .44]);
  d.slot(body, 'dark', .020, .074, .020, [0, my - .078, stockLen + .018]);
  d.slot(body, 'light', .038, .014, .044, [0, my - .118, stockLen + .028]);
  d.slot(body, 'light', .026, .026, stockLen * .80, [0, bot - .026, stockLen * .52]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {minimal: true, scope: true, turrets: 2});
  // Optic bridge: a riser rail under the scope along the barrel crown (its top
  // stays below the scope corridor radius by construction).
  d.slot(body, 'dark', .044, .024, .300, [0, top + .014, -.350]);
  for (let i = 0; i < 3; i++) d.slot(body, 'light', .050, .012, .024, [0, top + .028, -.240 - .070 * i]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

// 9 Submachine Gun - the stub with the oversized magazine. A quad-stack body
// hangs far below the receiver and the wire stock telescopes at the rear.
function submachineGun(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, mag = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.03, y: bot - .22, z: -.30}, max: {x: .03, y: bot, z: -.18}};
  const guardLen = hp.barrelLen * .46, guardZ = front - guardLen / 2;
  const magZ = feedAxis(fb, -.14, .195);
  d.enter('body', 'massing');
  // Stamped receiver: rib rows and a flared magwell lip.
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .36, len * .58, [s * (halfW + .005), my - .014, -len * .42]);
    d.fins(body, 'dark', 3, .010, .024, .012, [s * (halfW + .011), my - .020, -len * .22], [0, 0, .070]);
  }
  d.slot(body, 'dark', w * .66, h * .11, .028, [0, my - h * .44, -len * .70]);
  d.slot(body, 'light', w * .84, .016, .064, [0, bot - .014, -len * .34]);
  portKit(d, body, hp, [halfW + .010, my + h * .12, -len * .40]);
  d.enter('feed', 'feed');
  if (mag) {
    // Oversized quad-stack magazine: a wide body below the source mag with a
    // coupling clamp, stamped ribs, a witness window and a floorplate.
    d.slot(mag, 'light', .088, .200, .140, [magZ[0], magZ[1], magZ[2]], [-.14, 0, 0]);
    d.slot(mag, 'dark', .096, .022, .150, [magZ[0], magZ[1] + .075, magZ[2] - .010], [-.14, 0, 0]);
    for (const s of [-1, 1]) {
      d.fins(mag, 'dark', 3, .010, .044, .016, [s * .046, magZ[1] - .020, magZ[2] + .008], [0, 0, .020], [-.14, 0, 0]);
    }
    d.slot(mag, 'light', .006, .052, .034, [fb.max.x + .008, magZ[1] - .040, magZ[2] + .020], [-.14, 0, 0]);
    d.slot(mag, 'dark', .100, .022, .156, [magZ[0], magZ[1] - .108, magZ[2] + .016], [-.14, 0, 0]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 5, length: .046});
  heatVents(d, barrel, hp, 3, .09);
  d.enter('body', 'stock');
  // Telescoping wire stock: the source bars plus cross struts, a butt plate
  // and a sling loop.
  for (const s of [-1, 1]) d.slot(body, 'dark', .016, .020, stockLen * .80, [s * .056, my + .004, stockLen * .52]);
  d.slot(body, 'light', .104, .066, .026, [0, my - .020, stockLen - .014]);
  d.slot(body, 'dark', .022, .016, .022, [0, my + .004, stockLen * .34]);
  d.slot(body, 'light', .046, .018, .020, [-(halfW + .014), my - .030, stockLen * .58]);
  d.slot(body, 'light', .048, .020, .038, [0, bot - .070, -.100]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  // Rear drum: the SMG's stamped sight, a chunky drum hung off the rear-sight
  // base on the left flank (clear of the sight corridor by construction).
  d.disc(body, 'light', .028, .020, [-(halfW + .026), top + .036, -.030], [0, 0, Math.PI / 2], 12);
  d.disc(body, 'dark', .014, .030, [-(halfW + .026), top + .036, -.030], [0, 0, Math.PI / 2], 8);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .005, .010, .140, [-(halfW + .011), my + .022, -len * .56]);
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .58, guardLen * .90, [s * (halfW + .017), my, guardZ]);
    d.fins(body, 'dark', 3, .010, .026, .014, [s * (halfW + .025), my + .004, guardZ - guardLen * .16], [0, 0, .060]);
  }
  d.slot(body, 'dark', w * .48, .012, .044, [0, bot - .050, guardZ - guardLen * .28]);
}

const BUILDERS = [pulseRifle, rocketLauncher, railLance, scattergun, plasmaDriver,
  grenadeLauncher, shockBeam, flakCannon, marksmanRifle, submachineGun];

// Build one weapon's detail and return the accumulator (stats + clearance
// boxes) for the manifest. `bounds` holds the pre-pass weapon-space AABBs of
// the four source assemblies so feeds and stocks are dressed where the source
// construction actually puts them.
export function buildDetail(id, g, ctx, ch, parts, bounds) {
  const detail = new Detail(ctx.T, ctx);
  BUILDERS[id](detail, g, hardpoints(id, ch), parts, bounds);
  return detail;
}

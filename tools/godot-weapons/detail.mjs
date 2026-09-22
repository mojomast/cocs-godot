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
// Channel 3D detail is the concrete expression of the six identity channels in
// port/native-weapon-detail/WEAPON_IDENTITY.md.

const TAU = Math.PI * 2;

// Channel copy of record for the manifest (mirrors WEAPON_IDENTITY.md).
export const IDENTITY = [
  {id: 0, massing: 'slender carbine receiver, dorsal spine, squared front trunnion, paired side plates',
    feed: 'box magazine: magwell flare, witness slot, floorplate lip, ambi catch',
    muzzle: 'slotted flash hider: six-port sleeve with crown ring',
    stock: 'polymer stock with cheek riser and sling slot, grip palm swell',
    sight: 'iron notch/post, toothed optic rail with a bolted front-sight base block',
    accent: 'cyan trim, emissive charge conduit on the left flank, perforated handguard shroud'},
  {id: 1, massing: 'fat launch tube, flared rear venturi, heavy forward collars',
    feed: 'breech latch: hinged loading gate, latch handle, seal stripe',
    muzzle: 'belted bore with a blast-deflector crown ring and radial ports',
    stock: 'shoulder tube, folding support strut, thick butt pad, vertical foregrip',
    sight: 'iron, plus a folded launcher leaf ladder on the left flank',
    accent: 'orange trim, emissive venturi dot ring, exposed venturi ribs and strap loops'},
  {id: 2, massing: 'long low twin-rail sled with staggered side plates',
    feed: 'energy cell: housing, charge window, retaining clips, discharge lead',
    muzzle: 'twin accelerator rings with standoff prongs',
    stock: 'skeleton stock with cheek piece, angled grip',
    sight: 'integrated x3.6 scope with a single elevation turret on the sled',
    accent: 'violet trim, emissive accelerator coils, exposed coil rings'},
  {id: 3, massing: 'wide breech block, barrel-selector bar, twin chamber collars',
    feed: 'break-action breech: extractor knuckles, twin chamber faces',
    muzzle: 'twin ported choke sleeves with slanted ports',
    stock: 'wood-tone shoulder stock, comb, squared grip, barrel band',
    sight: 'iron with a brass bead on the top rib',
    accent: 'cream/brass trim, emissive chamber witness, brass rib rail'},
  {id: 4, massing: 'bulbous vented chamber in a cradle frame, slab power pack',
    feed: 'energy cell: twin cell tubes, windows, heavy latch',
    muzzle: 'three-prong plasma focus cage with a front core ring',
    stock: 'short stock with heat-shield plate, grip fin stack',
    sight: 'iron notch/post on a bolted base block over the vented chamber',
    accent: 'blue trim, emissive chamber window and cell windows, ribbed heat sink'},
  {id: 5, massing: 'chunky revolver frame with a top strap over the drum',
    feed: 'revolver drum: flutes, indexer yoke, hinge, index marks',
    muzzle: 'heavy bored muzzle, four lateral ports, front collar',
    stock: 'shoulder stock, recoil pad, thumb rest',
    sight: 'iron, plus a folded launcher ladder and quadrant on the left flank',
    accent: 'red-orange trim, emissive drum index window, angled slats'},
  {id: 6, massing: 'open fork/yoke emitter frame with flank capacitor plates',
    feed: 'energy cell: capacitor plates, coil leads, cell housing',
    muzzle: 'twin emitter prongs with discharge tips and a tuning bridge',
    stock: 'insulated cheek plate on the stock, coil-wrapped grip',
    sight: 'iron on an insulated sight rib',
    accent: 'ice-blue trim, emissive discharge tips, exposed coils and insulator discs'},
  {id: 7, massing: 'massive reinforced breech with a trunnion and top carry handle',
    feed: 'ammunition box: lid, latch, belt run into the breech',
    muzzle: 'heavy flared muzzle with eight radial ports',
    stock: 'heavy stock with recoil buffer, sturdy grip',
    sight: 'iron with a side range drum below the sight line',
    accent: 'amber trim, emissive arming indicator, belt run and shell loops'},
  {id: 8, massing: 'slim precision receiver with a chassis spine',
    feed: 'box magazine: witness slot, baseplate, funnel magwell',
    muzzle: 'slim multi-baffle brake with a heat band behind it',
    stock: 'chassis stock, adjustable cheek riser, rear monopod stub',
    sight: 'integrated x3.0 scope with paired elevation and windage turrets',
    accent: 'tan trim, emissive heat band, ribbed barrel flutes'},
  {id: 9, massing: 'stamped receiver with a rib pattern and flared magwell',
    feed: 'box magazine: stamped ribs, witness slot, floorplate',
    muzzle: 'short ported sleeve with a thread collar',
    stock: 'telescoping wire stock with butt plate, light trigger housing',
    sight: 'iron on a stamped rib with a rear drum',
    accent: 'green trim, emissive chamber port witness, stamped ribs and vented shroud'},
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
// Primitive vocabulary. Triangle cost: box 12, open tube 2*seg, cone 4*seg,
// hoop 2*radial*seg, disc 4*seg. Each weapon's detail is 45-90 primitives.
// ---------------------------------------------------------------------------

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

  // n identical fins spread along a step vector.
  fins(parent, role, count, w, h, d, pos, step, rot = [0, 0, 0]) {
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i - (count - 1) / 2;
      this.slot(parent, role, w, h, d, [pos[0] + step[0] * t, pos[1] + step[1] * t, pos[2] + step[2] * t], rot);
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

// A slotted sleeve around a bore, with a crown ring. Used by hiders/brakes.
function muzzleSleeve(d, barrel, hp, opts = {}) {
  const {mz, my, r} = hp;
  const x = opts.x ?? 0, radius = opts.radius ?? r + .014;
  const length = opts.length ?? .060, ports = opts.ports ?? 6;
  const role = opts.role ?? 'cavity', z0 = mz + .004;
  d.tube(barrel, role, radius, length, [x, my, z0 + length / 2]);
  for (let i = 0; i < ports; i++) {
    const a = TAU * i / ports + (opts.phase ?? 0);
    d.slot(barrel, role, .014, .016, .014,
      [x + Math.sin(a) * radius * .86, my + Math.cos(a) * radius * .86, z0 + length * (opts.portAt ?? .55)], [0, 0, -a]);
  }
  if (opts.crown !== false) {
    d.hoop(barrel, 'light', radius + .004, .008, [x, my, z0 + length + .006], [0, 0, 0], 12, 4);
  }
  return {radius, z0, z1: z0 + length};
}

// ---------------------------------------------------------------------------
// Per-weapon detail: the concrete expression of the six channels.
// `bd` is the pre-pass weapon-space bounds map for body/feed/bolt/barrel.
// ---------------------------------------------------------------------------

function pulseRifle(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW, rearZ, frontZ, railY} = hp;
  const body = g, barrel = parts.barrel, mag = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.04, y: bot - .30, z: -.30}, max: {x: .04, y: bot, z: -.18}};
  const guardLen = hp.barrelLen * .48, guardZ = front - guardLen / 2;
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .40, len * .58, [s * (halfW + .005), my - h * .02, -len * .46]);
    d.fins(body, 'dark', 3, .010, .026, .014, [s * (halfW + .010), my - h * .02, -len * .26], [0, 0, .075]);
    d.slot(body, 'dark', .008, h * .14, len * .40, [s * (halfW + .004), my - h * .30, -len * .58]);
  }
  d.slot(body, 'light', .050, .012, .060, [0, top - .006, -.012]);
  d.slot(body, 'light', w * .78, h * .26, .014, [0, my, -len + .007]);
  portKit(d, body, hp, [halfW + .010, my + h * .12, -len * .40]);
  d.enter('feed', 'feed');
  if (mag) {
    d.slot(mag, 'dark', .084, .024, .104, [0, fb.max.y - .006, (fb.min.z + fb.max.z) / 2]);
    d.fins(mag, 'dark', 3, .008, .012, .014, [fb.max.x + .005, fb.min.y + .115, (fb.min.z + fb.max.z) / 2], [0, .020, 0]);
    d.slot(mag, 'light', .010, .030, .026, [fb.max.x + .005, fb.min.y + .115, (fb.min.z + fb.max.z) / 2]);
    d.slot(mag, 'light', .076, .018, fb.max.z - fb.min.z + .010, [0, fb.min.y - .008, (fb.min.z + fb.max.z) / 2]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 6, length: .056});
  heatVents(d, barrel, hp, 4, .11);
  d.enter('body', 'stock');
  d.slot(body, 'light', Math.min(.10, w * .60), .026, .046, [0, my + h * .16, stockLen - .10]);
  d.slot(body, 'dark', .028, .044, .020, [0, my - .012, stockLen + .004]);
  d.slot(body, 'light', .044, .014, .030, [0, bot - .050, .030]);
  d.slot(body, 'dark', .040, .018, .018, [0, bot - .172, -.026]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.enter('body', 'accent');
  d.slot(body, 'glow', .005, .010, .200, [-(halfW + .012), my + .024, -len * .52]);
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, h * .66, guardLen * .94, [s * (halfW + .020), my, guardZ]);
    d.fins(body, 'dark', 4, .010, .030, .016, [s * (halfW + .029), my + .006, guardZ - guardLen * .20], [0, 0, .075]);
    d.slot(body, 'light', .016, .018, .028, [s * (halfW + .024), my - h * .40, guardZ - guardLen * .34]);
  }
  d.slot(body, 'dark', w * .50, .014, .048, [0, bot - .050 - .008, guardZ - guardLen * .30]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function rocketLauncher(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW, rearZ, frontZ} = hp;
  const body = g, barrel = parts.barrel, latch = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.15, y: my - .14, z: -.38}, max: {x: -.05, y: my - .10, z: -.22}};
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, .066, len * .66, [s * (halfW + .006), my + .052, -len * .45]);
    d.slot(body, 'dark', .010, .048, len * .30, [s * (halfW + .010), my - .056, -len * .30]);
  }
  d.hoop(body, 'light', r + .012, .012, [0, my, front + .020], [0, 0, 0], 14, 4);
  d.slot(body, 'light', w * .84, h * .16, .028, [0, top - .010, front + .028]);
  d.enter('body', 'accent');
  for (let i = 0; i < 6; i++) {
    const a = TAU * i / 6;
    d.slot(body, 'light', .014, .026, .116, [Math.sin(a) * (r + .004), my + Math.cos(a) * (r + .004), .046], [0, 0, -a]);
  }
  d.hoop(body, 'dark', r + .014, .012, [0, my, .118], [0, 0, 0], 14, 4);
  for (let i = 0; i < 6; i++) {
    const a = TAU * (i + .5) / 6;
    d.slot(body, 'glow', .024, .018, .012, [Math.sin(a) * (r + .010), my + Math.cos(a) * (r + .010), .122], [0, 0, -a]);
  }
  for (const s of [-1, 1]) d.slot(body, 'dark', .022, .048, .026, [s * (halfW - .022), my - .090, -.150]);
  d.enter('feed', 'feed');
  if (latch) {
    for (const dy of [-.026, .026]) d.slot(latch, 'light', .084, .012, .012, [fb.max.x - .046, fb.min.y + .035 + dy, fb.min.z - .004]);
    d.slot(latch, 'dark', .092, .014, .010, [fb.max.x - .046, fb.min.y + .035, fb.min.z - .006]);
    d.slot(latch, 'light', .046, .014, .038, [fb.max.x - .046, fb.max.y + .006, fb.min.z + .044]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 8, length: .054, radius: r + .010});
  d.hoop(barrel, 'light', r + .020, .012, [0, my, mz + .008], [0, 0, 0], 14, 4);
  d.enter('body', 'stock');
  d.slot(body, 'light', .050, .140, .030, [0, my - .040, stockLen - .030]);
  d.slot(body, 'dark', .130, .086, .026, [0, my - .040, stockLen - .012]);
  d.slot(body, 'light', .028, .096, .030, [.090, my - .150, -.300], [0, 0, -.30]);
  d.slot(body, 'dark', .050, .116, .060, [0, my - .212, -.360]);
  d.slot(body, 'light', .056, .018, .066, [0, my - .158, -.360]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 2, scope: false});
  const ladderY = top - .022, lx = -(halfW + .014);
  d.slot(body, 'dark', .014, .036, .126, [lx, ladderY, -.130], [0, 0, .10]);
  for (let i = 0; i < 4; i++) d.slot(body, 'light', .010, .026, .012, [lx - .008, ladderY + .006, -.084 - .030 * i], [0, 0, .10]);
  d.slot(body, 'light', .012, .014, .024, [lx - .010, ladderY + .034, -.190]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function railLance(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, cell = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .20, z: -.37}, max: {x: .07, y: bot - .05, z: -.19}};
  const railX = .066, railY = my + .038;
  // The locked source construction for the Rail Lance (twin accelerator rails
  // plus an integrated x3.6 optic, with the optic's author-tessellated rings
  // preserved) already spends ~6.1k triangles, so this weapon's detail is
  // authored to a tight ceiling: the accelerator rings, the coil signature, the
  // receiver plates and the action knob - no optional dressing.
  d.enter('body', 'massing');
  for (const s of [-1, 1]) d.slot(body, 'light', .012, h * .38, len * .60, [s * (halfW + .005), my - h * .06, -len * .44]);
  d.slot(body, 'light', w * .80, h * .18, .018, [0, top - .012, front + .018]);
  d.enter('barrel', 'accent');
  for (const s of [-1, 1]) {
    d.hoop(barrel, 'glow', .036, .006, [s * railX, railY + .006, -.34], [0, 0, 0], 8, 3);
    d.slot(barrel, 'light', .034, .074, .018, [s * railX, railY, -.245]);
  }
  d.enter('feed', 'feed');
  if (cell) {
    // Front-face clips only: the reload palm grips the cell's left flank.
    d.slot(cell, 'light', .104, .014, .012, [0, fb.max.y - .060, fb.min.z - .006]);
  }
  d.enter('barrel', 'muzzle');
  for (const s of [-1, 1]) {
    d.hoop(barrel, 'cavity', r + .058, .010, [s * railX, my, mz + .030], [0, 0, 0], 10, 3);
    d.slot(barrel, 'light', .012, .020, .076, [s * railX, my + .044, mz + .048]);
  }
  heatVents(d, barrel, hp, 1, .12);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp, {minimal: true});
}

function scattergun(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, breech = parts.magazine;
  const x = .12, barrelLen = hp.barrelLen;
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'dark', .016, h * .52, len * .40, [s * (halfW + .004), my - h * .04, -len * .28]);
    d.slot(body, 'light', .012, h * .28, len * .18, [s * (halfW + .012), my + h * .10, -len * .62]);
  }
  d.slot(body, 'light', w * .76, .018, .026, [0, my - h * .44, -len * .62]);
  d.enter('feed', 'feed');
  if (breech) {
    for (const s of [-1, 1]) {
      d.disc(breech, 'dark', .046, .018, [s * x, my - .040, mz + barrelLen * .98], [Math.PI / 2, 0, 0], 10);
      d.slot(breech, 'light', .020, .044, .028, [s * x, my - .030, -.124]);
    }
    d.slot(breech, 'light', .116, .016, .042, [0, my + .048, -.150]);
    d.slot(breech, 'light', .030, .014, .034, [0, my + .070, -.130]);
  }
  d.enter('barrel', 'muzzle');
  for (const s of [-1, 1]) {
    muzzleSleeve(d, barrel, hp, {ports: 4, length: .048, radius: r + .020, crown: false, x: s * x, phase: .4});
    d.hoop(barrel, 'light', r + .024, .009, [s * x, my, mz + .005], [0, 0, 0], 12, 4);
  }
  d.enter('barrel', 'accent');
  d.slot(barrel, 'light', .024, .014, barrelLen * .70, [0, my + r + .005, (front + mz) / 2 + .02]);
  d.fins(barrel, 'cavity', 4, .280, .018, .014, [0, my - r - .038, (front + mz) / 2 - .02], [-.085, 0, 0]);
  d.slot(barrel, 'light', .300, .024, .046, [0, my - r - .048, mz + .140]);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .58, h * .32, stockLen * .68, [0, my + h * .22, stockLen * .40]);
  d.slot(body, 'dark', .096, .048, .026, [0, my - .040, stockLen - .012]);
  d.slot(body, 'light', .052, .024, .038, [-.085, my - .070, -.030], [0, 0, .20]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 2, scope: false});
  d.slot(body, 'light', .012, .012, .012, [-.030, top + .015, front - .05]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function plasmaDriver(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, cell = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .20, z: -.37}, max: {x: .07, y: bot - .02, z: -.19}};
  d.enter('body', 'massing');
  d.hoop(body, 'light', h * .60, .014, [0, my - .01, -.140], [0, 0, 0], 10, 4);
  d.hoop(body, 'light', h * .54, .012, [0, my - .01, -.300], [0, 0, 0], 10, 4);
  for (const s of [-1, 1]) {
    d.fins(body, 'dark', 4, .012, .104, .016, [s * (halfW + .010), my + .030, -.240], [0, 0, .055]);
    d.slot(body, 'dark', .014, .038, .144, [s * (halfW + .008), my - .070, -.300]);
  }
  d.slot(body, 'light', w * .82, h * .15, .022, [0, top - .014, front + .022]);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .056, .012, .022, [0, my + h * .29, -.432]);
  d.slot(body, 'light', .068, .016, .016, [0, my + h * .29, -.448]);
  d.enter('feed', 'feed');
  if (cell) {
    d.slot(cell, 'light', .124, .016, .026, [0, fb.min.y + .016, fb.min.z - .012]);
    for (const s of [-1, 1]) {
      d.slot(cell, 'light', .034, .026, .034, [s * .042, fb.max.y - .040, fb.min.z - .010]);
      d.slot(cell, 'light', .014, .028, .026, [s * .042, fb.min.y + .052, fb.min.z - .008]);
    }
    d.slot(cell, 'dark', .104, .018, .130, [0, fb.max.y + .008, (fb.min.z + fb.max.z) / 2]);
    d.slot(cell, 'light', .014, .086, .014, [fb.max.x + .006, fb.max.y - .078, fb.max.z - .014]);
  }
  d.enter('barrel', 'muzzle');
  d.hoop(barrel, 'cavity', r + .034, .011, [0, my, mz + .030], [0, 0, 0], 12, 4);
  d.hoop(barrel, 'cavity', r + .030, .010, [0, my, mz + .084], [0, 0, 0], 12, 4);
  for (let i = 0; i < 3; i++) {
    const a = TAU * i / 3;
    d.slot(barrel, 'light', .014, .024, .090, [Math.sin(a) * (r + .026), my + Math.cos(a) * (r + .026), mz + .058], [0, 0, -a]);
  }
  heatVents(d, barrel, hp, 3, .13);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .60, h * .28, stockLen * .58, [0, my + h * .20, stockLen * .36]);
  d.slot(body, 'dark', .106, .058, .024, [0, my - .050, stockLen - .012]);
  d.fins(body, 'dark', 2, .012, .056, .014, [-(halfW + .010), my - .112, -.060], [0, 0, .30]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function grenadeLauncher(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, drum = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.20, y: my - .30, z: -.38}, max: {x: .14, y: my - .04, z: -.12}};
  const drumY = my - .17, drumZ = -.25;
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, .066, len * .56, [s * (halfW + .005), my - .030, -len * .40]);
    d.slot(body, 'dark', .010, .048, .130, [s * (halfW + .012), my - .090, -.150]);
  }
  d.slot(body, 'light', .058, .014, .250, [0, my - h * .40, drumZ]);
  d.slot(body, 'light', .020, .086, .030, [-(halfW - .010), my - h * .42, drumZ + .088], [0, 0, .18]);
  d.enter('feed', 'feed');
  if (drum) {
    d.hoop(drum, 'light', .128, .010, [0, drumY, fb.max.z - .008], [0, 0, 0], 14, 4);
    for (let i = 0; i < 6; i++) {
      const a = TAU * i / 6;
      d.disc(drum, 'dark', .024, .012, [Math.sin(a) * .072, drumY + Math.cos(a) * .072, fb.max.z - .008], [0, 0, 0], 8);
    }
    d.slot(drum, 'light', .028, .028, .024, [fb.max.x - .006, drumY, drumZ + .060]);
    d.slot(drum, 'dark', .024, .046, .038, [0, fb.min.y + .010, drumZ + .020]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 4, length: .058});
  d.hoop(barrel, 'light', r + .026, .011, [0, my, mz + .006], [0, 0, 0], 14, 4);
  heatVents(d, barrel, hp, 3, .10);
  d.enter('body', 'accent');
  for (const s of [-1, 1]) {
    d.fins(body, 'light', 4, .014, .028, .018, [s * (halfW + .012), my - .030, -len * .60], [0, 0, .35]);
  }
  d.slot(body, 'dark', .086, .014, .032, [-.058, my - h * .38, -.120]);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .64, h * .30, stockLen * .60, [0, my + h * .18, stockLen * .36]);
  d.slot(body, 'dark', .116, .066, .026, [0, my - .040, stockLen - .012]);
  d.slot(body, 'light', .050, .020, .034, [.078, my - .060, -.040]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 2, scope: false});
  const lx = -(halfW + .016);
  d.slot(body, 'dark', .014, .038, .142, [lx, top - .036, -.170], [0, 0, .12]);
  for (let i = 0; i < 5; i++) d.slot(body, 'light', .010, .024, .010, [lx - .008, top - .028, -.108 - .028 * i], [0, 0, .12]);
  d.slot(body, 'light', .014, .016, .026, [lx - .010, top + .002, -.230]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function shockBeam(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, cell = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .20, z: -.37}, max: {x: .07, y: bot - .05, z: -.19}};
  const x = .09;
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .014, .060, len * .52, [s * (halfW + .006), my + .034, -len * .42]);
    d.slot(body, 'dark', .012, .042, .116, [s * (halfW + .008), my - .052, -len * .30]);
    d.disc(body, 'light', .032, .028, [s * (halfW + .026), my + .048, -.220], [0, 0, Math.PI / 2], 10);
    d.hoop(body, 'dark', .034, .008, [s * (halfW + .012), my + .048, -.220], [0, 0, Math.PI / 2], 10, 4);
  }
  d.slot(body, 'light', w * .78, h * .15, .020, [0, top - .016, front + .020]);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .005, .010, .140, [-(halfW + .014), my + .036, -len * .60]);
  d.enter('feed', 'feed');
  if (cell) {
    d.slot(cell, 'light', .118, .020, .026, [0, fb.min.y + .018, fb.min.z - .012]);
    for (const s of [-1, 1]) {
      d.disc(cell, 'light', .032, .020, [s * .038, fb.max.y - .046, fb.min.z - .012], [Math.PI / 2, 0, 0], 10);
      d.slot(cell, 'light', .014, .024, .070, [s * (fb.max.x + .004), fb.max.y - .030, fb.min.z + .016]);
    }
  }
  d.enter('barrel', 'muzzle');
  for (const s of [-1, 1]) {
    for (let i = 0; i < 3; i++) d.disc(barrel, 'light', .028, .010, [s * x, my, mz + .086 + .148 * i], [0, 0, 0], 10);
    d.slot(barrel, 'glow', .018, .038, .026, [s * x, my + .016, mz + .018]);
    d.hoop(barrel, 'light', .032, .009, [s * x, my + .036, mz + .044], [0, 0, 0], 10, 4);
  }
  d.slot(barrel, 'light', .146, .020, .028, [0, my + .046, mz + .206]);
  heatVents(d, barrel, hp, 3, .10);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .60, h * .28, stockLen * .56, [0, my + h * .20, stockLen * .34]);
  d.slot(body, 'light', .068, .028, stockLen * .52, [0, my + h * .30, stockLen * .42]);
  d.slot(body, 'dark', .096, .048, .022, [0, my - .040, stockLen - .012]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function flakCannon(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, box = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.25, y: bot - .30, z: -.38}, max: {x: .11, y: bot - .02, z: -.18}};
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .016, .076, len * .58, [s * (halfW + .006), my + .040, -len * .42]);
    d.slot(body, 'dark', .012, .056, .132, [s * (halfW + .012), my - .060, -len * .24]);
  }
  d.slot(body, 'light', w * .54, .028, .104, [0, top - .010, -.060]);
  d.hoop(body, 'light', r + .016, .012, [0, my, front + .024], [0, 0, 0], 14, 4);
  d.enter('body', 'accent');
  // Belt run from the box up the left flank into the breech (clear of the
  // reload hand, which reaches only the box mouth below it).
  for (let i = 0; i < 7; i++) {
    d.slot(body, 'light', .020, .018, .016, [-(halfW + .012), my - .118 + .030 * i, -.268 + .020 * i], [0, 0, .30]);
  }
  d.slot(body, 'dark', .024, .018, .112, [-(halfW + .018), my - .110, -.212]);
  d.slot(body, 'glow', .014, .014, .014, [0, top + .004, -.078]);
  d.enter('feed', 'feed');
  if (box) {
    d.slot(box, 'dark', fb.max.x - fb.min.x - .004, .022, fb.max.z - fb.min.z - .010, [(fb.min.x + fb.max.x) / 2, fb.min.y - .016, (fb.min.z + fb.max.z) / 2]);
    for (const s of [-1, 1]) d.slot(box, 'light', .014, .028, fb.max.z - fb.min.z - .022, [(fb.min.x + fb.max.x) / 2 + s * (fb.max.x - fb.min.x - .020) / 2, fb.min.y + .070, (fb.min.z + fb.max.z) / 2]);
    d.slot(box, 'light', .056, .018, .064, [(fb.min.x + fb.max.x) / 2, fb.max.y - .006, (fb.min.z + fb.max.z) / 2]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 8, length: .066, radius: r + .026, crown: false});
  d.hoop(barrel, 'light', r + .034, .013, [0, my, mz + .010], [0, 0, 0], 14, 4);
  d.cone(barrel, 'cavity', r + .048, r + .016, .028, [0, my, mz + .082], [Math.PI / 2, 0, 0], 14);
  heatVents(d, barrel, hp, 4, .14);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .58, h * .32, stockLen * .62, [0, my + h * .20, stockLen * .38]);
  d.slot(body, 'dark', .134, .076, .028, [0, my - .040, stockLen - .014]);
  d.slot(body, 'light', .054, .026, .042, [0, bot - .196, -.034]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.disc(body, 'light', .024, .028, [-(halfW + .020), my + h * .16, -.120], [0, 0, Math.PI / 2], 10);
  d.slot(body, 'dark', .012, .018, .018, [-(halfW + .034), my + h * .16, -.120]);
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

function marksmanRifle(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, mag = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.07, y: bot - .30, z: -.30}, max: {x: .07, y: bot, z: -.18}};
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .40, len * .58, [s * (halfW + .005), my - h * .04, -len * .46]);
    d.slot(body, 'dark', .010, h * .16, len * .34, [s * (halfW + .010), my - h * .28, -len * .34]);
  }
  d.slot(body, 'light', w * .78, h * .17, .020, [0, top - .012, front + .020]);
  d.slot(body, 'light', .038, .010, .100, [0, top - .006, -.020]);
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
  d.tube(barrel, 'cavity', brake, .082, [0, my, mz + .046]);
  for (let i = 0; i < 2; i++) d.hoop(barrel, 'cavity', brake + .004, .008, [0, my, mz + .024 + .032 * i], [0, 0, 0], 8, 4);
  d.hoop(barrel, 'light', brake + .006, .008, [0, my, mz + .090], [0, 0, 0], 10, 4);
  d.hoop(barrel, 'glow', r + .008, .006, [0, my, mz + .108], [0, 0, 0], 10, 4);
  heatVents(d, barrel, hp, 3, .16);
  d.enter('barrel', 'accent');
  d.fins(barrel, 'light', 4, .016, .018, .056, [0, my - r - .007, mz + .250], [.10, 0, 0]);
  d.enter('body', 'stock');
  d.slot(body, 'light', w * .62, h * .28, stockLen * .58, [0, my + h * .20, stockLen * .34]);
  d.slot(body, 'dark', .096, .048, .024, [0, my - .050, stockLen - .012]);
  d.slot(body, 'light', .076, .024, .044, [0, my + h * .31, stockLen * .48]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {minimal: true, scope: true});
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);
}

function submachineGun(d, g, hp, parts, bd) {
  const {w, h, len, mz, my, r, stockLen, front, top, bot, halfW} = hp;
  const body = g, barrel = parts.barrel, mag = parts.magazine;
  const fb = bd.feed ?? {min: {x: -.03, y: bot - .22, z: -.30}, max: {x: .03, y: bot, z: -.18}};
  const guardLen = hp.barrelLen * .48, guardZ = front - guardLen / 2;
  d.enter('body', 'massing');
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .38, len * .58, [s * (halfW + .005), my - h * .02, -len * .42]);
    d.fins(body, 'dark', 3, .010, .024, .012, [s * (halfW + .011), my - h * .02, -len * .22], [0, 0, .070]);
  }
  d.slot(body, 'dark', w * .66, h * .11, .026, [0, my - h * .44, -len * .70]);
  d.slot(body, 'light', w * .82, h * .13, .018, [0, my - h * .30, -len * .30]);
  portKit(d, body, hp, [halfW + .010, my + h * .12, -len * .40]);
  d.enter('feed', 'feed');
  if (mag) {
    d.slot(mag, 'dark', fb.max.x - fb.min.x + .008, .022, fb.max.z - fb.min.z + .006, [0, fb.max.y - .006, (fb.min.z + fb.max.z) / 2]);
    d.fins(mag, 'dark', 4, .008, .010, .012, [fb.max.x + .005, fb.min.y + .090, (fb.min.z + fb.max.z) / 2], [0, .016, 0]);
    d.slot(mag, 'light', .010, .026, .020, [fb.max.x + .004, fb.min.y + .058, (fb.min.z + fb.max.z) / 2]);
    d.slot(mag, 'light', fb.max.x - fb.min.x + .004, .016, fb.max.z - fb.min.z + .004, [0, fb.min.y - .008, (fb.min.z + fb.max.z) / 2]);
  }
  d.enter('barrel', 'muzzle');
  muzzleSleeve(d, barrel, hp, {ports: 5, length: .046});
  heatVents(d, barrel, hp, 4, .09);
  d.enter('body', 'stock');
  for (const s of [-1, 1]) d.slot(body, 'dark', .016, .020, stockLen * .80, [s * .056, my + .004, stockLen * .52]);
  d.slot(body, 'light', .104, .066, .026, [0, my - .020, stockLen - .014]);
  d.slot(body, 'light', .048, .020, .038, [0, bot - .070, -.100]);
  d.enter('body', 'sight');
  railKit(d, body, hp, {teeth: 3, scope: false});
  d.disc(body, 'light', .018, .020, [0, top + .004, -.100], [0, 0, Math.PI / 2], 10);
  d.enter('body', 'accent');
  d.slot(body, 'glow', .005, .010, .140, [-(halfW + .011), my + .022, -len * .56]);
  for (const s of [-1, 1]) {
    d.slot(body, 'light', .012, h * .58, guardLen * .90, [s * (halfW + .017), my, guardZ]);
    d.fins(body, 'dark', 3, .010, .026, .014, [s * (halfW + .025), my + .004, guardZ - guardLen * .16], [0, 0, .060]);
  }
  d.slot(body, 'dark', w * .48, .012, .042, [0, bot - .048 - .006, guardZ - guardLen * .28]);
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
  d.enter('bolt', 'bolt');
  boltKit(d, parts.bolt, hp);

}

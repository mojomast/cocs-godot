// Authored first-person weapon-handling data, exported into the generated
// manifest/GLB pipeline by export.mjs. Presentation only: no damage, spread,
// recoil or ammo authority is defined here.
//
// Anchor coordinates are authored in weapon space (+Z stock, -Z muzzle), the
// same convention as the existing Muzzle/Sight/Grip anchors, and are rebased
// into the *actual moving assembly* they belong to (bolt carrier, feed,
// barrel) by export.mjs, exactly like the existing muzzle anchors.
//
// Mechanisms below follow the source builders in game/weapon-models/chassis.mjs:
//   - every chassis authors one reciprocating carrier group named `bolt`
//     (carrier + charging paddle; the carrier race stays on the body),
//   - every chassis authors one `feed` group (box magazine, drum, cell or
//     breech latch depending on family),
//   - the barrel group is `barrel-assembly` / `shock-emitter` / `flak-barrel`.
// No source model authors a hammer mesh, so no `Hammer` anchor is invented
// here; see port/native-weapon-handling/README.md for the reported gap.

// Per-family reload behaviour. All motion is a pure function of the
// authoritative reload progress, so it can never run outside the source
// reloading window. `flourish` is a bounded seat/dip wobble multiplied by the
// same window curve: exactly zero at progress 0.0 and 1.0, presentation only,
// never a timing or ammo authority.
export const RELOAD = {
  magazine: {kind: 'magazine', drop: 0.17, slide: 0.035, roll: 0.14, tilt: 0.0, hinge: 0.0,
    flourish: {amount: 0.055, rate: 3.0, lift: 0.05, spin: 0.30}},
  cell: {kind: 'cell', drop: 0.12, slide: 0.05, roll: -0.10, tilt: 0.0, hinge: 0.0,
    flourish: {amount: 0.070, rate: 2.0, lift: 0.04, spin: -0.55}},
  drum: {kind: 'drum', drop: 0.055, slide: 0.02, roll: 0.06, tilt: 0.0, hinge: 0.0,
    flourish: {amount: 0.090, rate: 2.0, lift: 0.02, spin: 0.85}},
  breech: {kind: 'breech', drop: 0.02, slide: -0.03, roll: 0.0, tilt: 0.30, hinge: 0.0,
    flourish: {amount: 0.045, rate: 2.0, lift: 0.03, spin: 0.35}},
  tube: {kind: 'tube', drop: 0.015, slide: -0.02, roll: 0.0, tilt: 0.24, hinge: 0.0,
    flourish: {amount: 0.035, rate: 2.0, lift: 0.02, spin: 0.30}},
  break: {kind: 'break', drop: 0.0, slide: 0.0, roll: 0.0, tilt: 0.18, hinge: 0.30,
    flourish: {amount: 0.030, rate: 2.0, lift: 0.01, spin: 0.20}},
};

// Weapon id -> family handling. `eject` marks a receiver-side casing port the
// source mechanism actually has; the weapon-effects controller still owns
// whether a casing is pooled (`Profiles.ITEMS[id].case`). `strokeScale`
// shortens the carrier travel for breech latches and drums, whose authored
// bolt group is a latch rather than a rifle carrier.
const FAMILY = [
  {mechanism: 'kinetic', reload: 'magazine', eject: true, charge: true, strokeScale: 1.0, heat: {gain: 0.050, cool: 0.28}},
  {mechanism: 'launcher', reload: 'tube', eject: false, charge: true, strokeScale: 0.8, heat: {gain: 0.180, cool: 0.50}},
  {mechanism: 'energy', reload: 'cell', eject: false, charge: true, strokeScale: 1.0, heat: {gain: 0.090, cool: 0.40}},
  {mechanism: 'break', reload: 'break', eject: true, charge: false, strokeScale: 0.6, heat: {gain: 0.170, cool: 0.46}},
  {mechanism: 'energy', reload: 'cell', eject: true, charge: true, strokeScale: 1.0, heat: {gain: 0.095, cool: 0.42}},
  {mechanism: 'drum', reload: 'drum', eject: true, charge: true, strokeScale: 0.5, heat: {gain: 0.150, cool: 0.44}},
  {mechanism: 'energy', reload: 'cell', eject: false, charge: true, strokeScale: 1.0, heat: {gain: 0.085, cool: 0.38}},
  {mechanism: 'breech', reload: 'breech', eject: true, charge: true, strokeScale: 0.7, heat: {gain: 0.160, cool: 0.48}},
  {mechanism: 'kinetic', reload: 'magazine', eject: true, charge: true, strokeScale: 1.0, heat: {gain: 0.120, cool: 0.42}},
  {mechanism: 'kinetic', reload: 'magazine', eject: true, charge: true, strokeScale: 0.9, heat: {gain: 0.055, cool: 0.30}},
];

// Feed-body station per family. Distinct from GripReload, which stays the left
// hand contact; these mirror the source feed geometry positions exactly.
function feedStation(id, ch) {
  const [, h, , , my] = ch;
  switch (FAMILY[id].reload) {
    case 'magazine': return {name: 'Magazine', position: [0, my - h / 2 - (id === 9 ? .125 : id === 8 ? .075 : .125), -.24]};
    case 'cell': return {name: 'Cell', position: [0, my - h / 2 - .09, -.28]};
    case 'drum': return {name: 'Drum', position: [0, my - .17, -.25]};
    case 'breech': return {name: 'Feed', position: id === 7 ? [-.07, my - h / 2 - .10, -.28] : [0, my - .04, -.18]};
    case 'break': return {name: 'Feed', position: [0, my - .04, -.18]};
    default: return {name: 'Feed', position: [-.10, my - .13, -.30]};
  }
}

// Authored stations in weapon space. Kept beside the chassis row they derive
// from so a source chassis change is visible in one diff.
export function handlingAnchors(id, ch, parts) {
  const [w, h, len, mz, my] = ch;
  const front = -len;
  const family = FAMILY[id];
  const anchors = [];
  // Reciprocating carrier: the source authors the carrier at x=w/2+.013,
  // z=-len*.45 and its charging paddle at x=w/2+.032, z=-len*.38.
  if (parts.bolt) {
    anchors.push({name: 'Bolt', position: [w / 2 + .013, my + .015, -len * .45], owner: parts.bolt});
    anchors.push({name: 'Charging', position: [w / 2 + .032, my + .015, -len * .38], owner: parts.bolt});
  }
  // Casing port: right receiver wall, in line with the carrier's rear travel.
  if (family.eject) {
    anchors.push({name: 'Ejection', position: [w / 2 + .010, my + h * .12, -len * .40], owner: null});
  }
  if (parts.magazine) {
    const station = feedStation(id, ch);
    anchors.push({name: station.name, position: station.position, owner: parts.magazine});
  }
  // Heat region: hot barrel steel forward of the receiver, seated on the lower
  // barrel surface so a rising plume always starts *below* the sight line. It
  // still rides the barrel assembly, so it follows recoil, break-action hinge
  // and weapon switching.
  if (parts.barrel) {
    anchors.push({name: 'HeatZone', position: [0, my - ch[5] * .5, mz + (front - mz) * .30], owner: parts.barrel});
  }
  return anchors;
}

// Cycle parameters. The bolt interval is derived from the source `feel.kick`
// recovery rate so automatic weapons cycle visibly faster than heavy ones.
export function handlingProfile(id, ch, info) {
  const [, , len, , , r] = ch;
  const family = FAMILY[id];
  const rate = Math.max(1, Number(info?.feel?.kick?.[2]) || 12);
  const interval = 1 / rate;
  const stroke = Math.min(.06, Math.max(.035, len * .11)) * family.strokeScale;
  return {
    mechanism: family.mechanism,
    cycle: Math.min(.12, interval * .88),
    stroke,
    // A side charging handle is rigidly attached to the carrier in the source
    // model, so it travels exactly the authored carrier stroke; only its
    // timings differ (slow rack vs fast cycle).
    charge: family.charge ? stroke : 0,
    reload: RELOAD[family.reload],
    heat: {gain: family.heat.gain, cool: family.heat.cool, cap: 1.0},
    eject: family.eject,
    barrelRadius: r,
  };
}

// Idle sway character per weapon family: presentation only, consumed by
// rig.gd's `advance` and multiplied by (1 - aim_weight) there, so it is exactly
// zero at settled ADS and can never move the sight picture. Amplitudes stay
// under 2.2 mm / 0.0032 rad: unread at hip and far below the reticle corridor
// clearance the framing gates measure. The rate/skew pair is what makes a
// launcher breathe slowly and heavily while the SMG jitters.
const SWAY = [
  {rate: 1.90, x: .0012, y: .0009, roll: .0014, skewY: .83, skewRoll: .50}, // pulse carbine: steady hum
  {rate: 0.62, x: .0018, y: .0022, roll: .0032, skewY: .67, skewRoll: .38}, // rocket: heavy slow breathe
  {rate: 0.78, x: .0008, y: .0006, roll: .0009, skewY: .55, skewRoll: .45}, // rail: braced long-rail drift
  {rate: 1.08, x: .0014, y: .0012, roll: .0020, skewY: .95, skewRoll: .62}, // scattergun: break-action sway
  {rate: 2.30, x: .0010, y: .0008, roll: .0012, skewY: 1.15, skewRoll: .70}, // plasma: fast energy flutter
  {rate: 0.68, x: .0016, y: .0018, roll: .0026, skewY: .72, skewRoll: .40}, // grenade: drum-heavy roll
  {rate: 2.85, x: .0009, y: .0007, roll: .0010, skewY: 1.32, skewRoll: .82}, // shock: crackling jitter
  {rate: 0.86, x: .0017, y: .0015, roll: .0024, skewY: .78, skewRoll: .48}, // flak: breech-heavy breathe
  {rate: 0.42, x: .0007, y: .0006, roll: .0008, skewY: .48, skewRoll: .30}, // marksman: near-still precision
  {rate: 3.40, x: .0013, y: .0011, roll: .0022, skewY: 1.26, skewRoll: .92}, // SMG: tight fast jitter
];

export function presentationProfile(id, ch, info) {
  const sway = SWAY[id] ?? SWAY[0];
  const feel = info?.feel ?? {};
  return {
    sway: {...sway},
    // Bolt/shroud legibility: bright action hardware plus a bounded rattle that
    // is exactly zero at rest, so the authoritative carrier travel is untouched.
    rattle: Number((Math.min(.35, Math.max(.10, (feel.kick?.[0] ?? .05) * 2.4))).toFixed(4)),
  };
}

// Deterministic authoring for the three runtime Moth dressing profiles that were
// missing: vesper-viaduct, abyssal-pressureworks and stormglass-causeway.
//
// Every selector below is a glTF material name read out of the map's own art
// GLB, and every placement is anchored to a real structure, port, gate or
// surface in port/native-multiplayer-worlds/worlds/<map>.json. Nothing here is
// invented: run `node author.mjs --check` and check.mjs to prove it.
//
//   node author.mjs --write    rewrite the three profile JSON files
//   node author.mjs --check    fail if the committed JSON differs from this source
import {writeFileSync, readFileSync, existsSync} from 'node:fs';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const PROFILE_DIR = resolve(ROOT, 'godot/multiplayer_worlds/dressing/profiles');

// Authored map palette (see each map's blender author / map_materials.py).
const VESPER_PALETTE = {sandstone: 'bb9370', brick: '984e36', plaster: 'b1816b', slate: '293449',
  iron: '252d37', quay: '535969', cobbles: '77605b', asphalt: '3e424c', glass: '243c58', water: '224675', letter: 'f1c27b'};
const ABYSSAL_PALETTE = {navy: '6d8b9c', coral: 'ac655c', ivory: 'cdd6c8', copper: '9d7051',
  cyan: '57c4cf', amber: 'dca45e', glass: '286b83'};
const STORMGLASS_PALETTE = {asphalt: '849095', concrete: 'c4cbcb', salt: 'e2e7e2', amber: 'f8ce6f',
  teal: '69adb1', brick: 'b89381', glass: '6fb5c0', steel: '93a4a8', ocean: '4b8493'};

// Family response floors shared by every entry, matching the three accepted
// profiles: no accent gain, no phase pulse, private macro/wear/variation only.
const base = (family, variant, tint, response, seed) => ({
  variant, tint,
  lut_gain: 0, pulse_speed: 0, pulse_depth: 0,
  detail_strength: 0.06, ao_strength: 0.14,
  roughness_variation: 0.1,
  ...response,
  variation_mode: 'organic', variation_strength: 0.3, variation_scale: 0.07, variation_seed: seed,
});

const material = (source, family, options) => ({source, family, options});

const panel = ({id, position, rotation_degrees, size, texture, tint, essential = false,
  normal, wear_mask, opacity, feather, seed}) => {
  const entry = {id, position, rotation_degrees, size, texture, tint, essential};
  if (normal !== undefined) entry.normal = normal;
  if (wear_mask !== undefined) {
    entry.wear_mask = wear_mask;
    entry.opacity = opacity;
    entry.feather = feather;
    entry.seed = seed;
  }
  return entry;
};
const sign = (id, position, rotation_degrees, size, text, foreground, background, essential = true) =>
  ({id, position, rotation_degrees, size, text, foreground, background, essential});
const pocket = (id, kind, position, size, color, count) => ({id, kind, position, size, color, count});

// ---------------------------------------------------------------- vesper -----
// Three graded terraces (quay y=0, cobble y=12, asphalt y=24), seven through-halls
// at x -66/0/66 and z -85/0/85, a civic clock at x=22, a stair at x 29.6-34.4,
// and the canal at y=-2 spanning z=-110.
const VESPER_HALLS = [
  {id: 'ticket-concourse', x: -66, z: 85, w: 48, d: 28, height: 13, y: 24, counters: true},
  {id: 'platform-gallery', x: 0, z: 85, w: 36, d: 28, height: 18, y: 24, counters: true},
  {id: 'east-station', x: 66, z: 85, w: 48, d: 28, height: 15, y: 24, counters: true},
  {id: 'west-courtyard', x: -66, z: 0, w: 48, d: 30, height: 9, y: 0, counters: false},
  {id: 'east-post-office', x: 66, z: 0, w: 48, d: 30, height: 11, y: 0, counters: false},
  {id: 'bonded-warehouse', x: -66, z: -85, w: 48, d: 26, height: 10, y: 0, counters: false},
  {id: 'canal-service', x: 66, z: -85, w: 48, d: 26, height: 9, y: 0, counters: false},
];
// parcel-bay-label plates: 3 x 0.7 x 0.3 sandstone on both hall faces.
const VESPER_PARCEL = VESPER_HALLS.filter(h => !h.counters);
const VESPER_TICKET = VESPER_HALLS.filter(h => h.counters);

function vesperPanels() {
  const panels = [];
  let seed = 610400;
  // Parcel-bay label plates on the four non-ticket halls (both elevations).
  for (const hall of VESPER_PARCEL) {
    for (const side of [-1, 1]) {
      panels.push(panel({
        id: `parcel-plate-${hall.id}-${side < 0 ? 'n' : 's'}`,
        position: [hall.x, hall.y + 0.7, hall.z + side * (hall.d / 2 + 0.18)],
        rotation_degrees: [0, side < 0 ? 0 : 180, 0],
        size: [3, 0.3], texture: 'brushed_metal', normal: 'baked:metal', tint: '8d8a80',
      }));
    }
  }
  // Ticket-desk dividers are 0.08 x 0.65 x 1.1 iron plates; dress one per counter
  // line on the three ticket halls (south elevation).
  for (const hall of VESPER_TICKET) {
    for (const dx of [-hall.w / 3, 0, hall.w / 3]) {
      if (hall.id === 'platform-gallery' && Math.abs(dx) < 1) continue;
      panels.push(panel({
        id: `desk-divider-${hall.id}-${dx}`,
        position: [hall.x + dx, hall.y + 1.48, hall.z + hall.d / 2 - 4 + 1.15],
        rotation_degrees: [0, 180, 0],
        size: [1.1, 0.65], texture: 'brushed_metal', normal: 'baked:metal', tint: '8d8a80',
      }));
    }
  }
  // Stair nosings: 80 sandstone risers from (32, 12, 25) to (32, 24, 65).
  for (const i of [4, 16, 28, 40, 52, 64]) {
    panels.push(panel({
      id: `stair-nosing-${i}`,
      position: [32, 12 + i * 0.15 + 0.09, 25 + i * 0.5],
      rotation_degrees: [0, 0, 0],
      size: [4, 0.16], texture: 'hazard_stripes', tint: 'b08a52',
    }));
  }
  // Quay coping along the canal cut (city-grade quay deck, z -104..-65 at y=0).
  for (const x of [-120, -72, -24, 24, 72, 120]) {
    panels.push(panel({
      id: `quay-coping-${x}`,
      position: [x, 0.16, -104],
      rotation_degrees: [0, 0, 0],
      size: [6, 0.3], texture: 'weathered_concrete-worn', tint: '8d8a80',
      wear_mask: 'weathered_concrete', opacity: 0.18, feather: 0.4, seed: seed++,
    }));
  }
  // Ramp footings where cobble meets quay and asphalt meets cobble.
  for (const x of [-100, 0, 100]) {
    panels.push(panel({
      id: `cobble-ramp-foot-${x}`,
      position: [x, 0.24, -65],
      rotation_degrees: [0, 0, 0],
      size: [7, 0.44], texture: 'weathered_concrete-worn', tint: '8d8a80',
      wear_mask: 'weathered_concrete', opacity: 0.16, feather: 0.4, seed: seed++,
    }));
  }
  // Clock movement behind the civic dial (dial at 22,55,12.4 on the letter material).
  panels.push(panel({
    id: 'clock-movement', position: [22, 55, 12.18], rotation_degrees: [0, 0, 0],
    size: [5, 5], texture: 'circuit_board-etch', tint: '7c6a52',
  }));
  // Tram service covers along the rail line, plus the two canal crossings.
  for (const z of [-60, 0, 60]) {
    panels.push(panel({
      id: `tram-cover-${z}`, position: [-2, 13.4, z], rotation_degrees: [0, 0, 0],
      size: [2, 1.2], texture: 'metal_grating', tint: '6d6a62',
    }));
  }
  for (const x of [-100, 100]) {
    panels.push(panel({
      id: `canal-crossing-grate-${x}`, position: [x, 0.1, -108], rotation_degrees: [0, 0, 0],
      size: [4, 10], texture: 'metal_grating', tint: '6d6a62',
    }));
  }
  return panels;
}

function vesperSigns() {
  const signs = [];
  const fg = 'e8e2d2', bg = '2a2f3a';
  // Terrace levels, read on approach from the quay.
  signs.push(sign('quay-level-west', [-100, 1.6, -63], [0, 0, 0], [3.5, 0.66], 'LEVEL 0\nQUAY', fg, bg));
  signs.push(sign('quay-level-east', [100, 1.6, -63], [0, 0, 0], [3.5, 0.66], 'LEVEL 0\nQUAY', fg, bg));
  signs.push(sign('cobble-level-west', [-100, 13.6, -23], [0, 0, 0], [3.5, 0.66], 'LEVEL 1\nCOBBLE', fg, bg));
  signs.push(sign('cobble-level-east', [100, 13.6, -23], [0, 0, 0], [3.5, 0.66], 'LEVEL 1\nCOBBLE', fg, bg));
  signs.push(sign('upper-deck-west', [-100, 25.6, 68], [0, 0, 0], [3.5, 0.66], 'LEVEL 2\nUPPER DECK', fg, bg));
  signs.push(sign('upper-deck-east', [100, 25.6, 68], [0, 0, 0], [3.5, 0.66], 'LEVEL 2\nUPPER DECK', fg, bg));
  // Clock square objective, mounted either side of the tower plinth.
  signs.push(sign('clock-square-west', [-6.5, 14.6, 0], [0, 90, 0], [3.2, 0.66], 'CLOCK SQUARE\nCIVIC', fg, bg));
  signs.push(sign('clock-square-east', [6.5, 14.6, 0], [0, -90, 0], [3.2, 0.66], 'CLOCK SQUARE\nCIVIC', fg, bg));
  // Parcel halls keep their baked lettering; dress the opposite elevation.
  signs.push(sign('parcel-bays-west', [-66, 8.4, 15.4], [0, 180, 0], [3.8, 0.66], 'PARCEL BAYS\nWEST', fg, bg));
  signs.push(sign('parcel-bays-east', [66, 8.4, 15.4], [0, 180, 0], [3.8, 0.66], 'PARCEL BAYS\nEAST', fg, bg));
  signs.push(sign('bonded-dock', [-66, 8.4, -98.4], [0, 180, 0], [3.8, 0.66], 'BONDED DOCK', fg, bg));
  signs.push(sign('canal-service', [66, 8.4, -98.4], [0, 180, 0], [3.8, 0.66], 'CANAL SERVICE', fg, bg));
  // Station portals (east/west doors) on the portico lintels at y+5.3.
  signs.push(sign('ticket-hall-portal', [-41.6, 28, 85], [0, 90, 0], [4.4, 0.66], 'TICKET HALL', fg, bg));
  signs.push(sign('platforms-portal-east', [18.4, 28, 85], [0, 90, 0], [4.4, 0.66], 'PLATFORMS 1 - 6', fg, bg));
  signs.push(sign('platforms-portal-west', [-18.4, 28, 85], [0, -90, 0], [4.4, 0.66], 'PLATFORMS 1 - 6', fg, bg));
  signs.push(sign('east-station-portal', [41.6, 28, 85], [0, -90, 0], [4.4, 0.66], 'EAST STATION', fg, bg));
  // Canal crossings at the far quay.
  signs.push(sign('canal-crossing-west', [-100, 1.6, -116], [0, 180, 0], [4.4, 0.66], 'CANAL CROSSING', fg, bg));
  signs.push(sign('canal-crossing-east', [100, 1.6, -116], [0, 180, 0], [4.4, 0.66], 'CANAL CROSSING', fg, bg));
  return signs;
}

function vesperPockets() {
  return [
    pocket('canal-mist-west', 'mist', [-100, 0.9, -108], [8, 2, 3], '9fb3c4', 10),
    pocket('canal-mist-east', 'mist', [100, 0.9, -108], [8, 2, 3], '9fb3c4', 10),
    pocket('cobble-ramp-dust', 'dust', [-60, 13.2, -25], [4, 1.6, 4], 'b3a894', 6),
    pocket('clock-square-dust', 'dust', [0, 13.2, 0], [4, 1.6, 4], 'b3a894', 6),
    pocket('ticket-hall-vent', 'vent', [-66, 28, 70], [3, 2, 2], 'a9b6bd', 6),
    pocket('platform-gallery-vent', 'vent', [0, 28, 70], [3, 2, 2], 'a9b6bd', 6),
  ];
}

const vesper = {
  version: 1,
  map_id: 'vesper-viaduct',
  geometry_hash: '27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7',
  materials: [
    // 34 cornice/window pieces, 80 terrace surfaces and every hand-cut trim cube.
    material('sandstone', 'pearl-ceramic', base('pearl-ceramic', 'cast', VESPER_PALETTE.sandstone,
      {tiles_per_metre: 1.3, roughness: 0.86, albedo_gain: 1.35, texture_strength: 0.34, texture_saturation: 0.08, normal_strength: 0.12, metallic: 0.02, specular_strength: 0.2}, 610420)),
    material('brick', 'pearl-ceramic', base('pearl-ceramic', 'worn', VESPER_PALETTE.brick,
      {tiles_per_metre: 1.3, roughness: 0.88, albedo_gain: 1.3, texture_strength: 0.3, texture_saturation: 0.05, normal_strength: 0.1, metallic: 0.02, specular_strength: 0.2}, 610421)),
    material('plaster', 'enamel-glaze', base('enamel-glaze', 'stucco', VESPER_PALETTE.plaster,
      {tiles_per_metre: 1.1, roughness: 0.82, albedo_gain: 1.25, texture_strength: 0.26, texture_saturation: 0.06, normal_strength: 0.08, metallic: 0, specular_strength: 0.24}, 610422)),
    material('slate', 'pearl-ceramic', base('pearl-ceramic', 'polished', VESPER_PALETTE.slate,
      {tiles_per_metre: 1.4, roughness: 0.55, albedo_gain: 1.4, texture_strength: 0.28, texture_saturation: 0.12, normal_strength: 0.14, metallic: 0.05, specular_strength: 0.3}, 610423)),
    material('quay', 'regolith', base('regolith', 'scoured', VESPER_PALETTE.quay,
      {tiles_per_metre: 1.4, roughness: 0.9, albedo_gain: 1.8, texture_strength: 0.3, texture_saturation: 0.1, normal_strength: 0.12, metallic: 0.02, specular_strength: 0.18}, 610424)),
    material('cobbles', 'regolith', base('regolith', 'scoured', VESPER_PALETTE.cobbles,
      {tiles_per_metre: 1.6, roughness: 0.93, albedo_gain: 2.0, texture_strength: 0.36, texture_saturation: 0.14, normal_strength: 0.16, metallic: 0.02, specular_strength: 0.16}, 610425)),
    material('asphalt', 'pearl-ceramic', base('pearl-ceramic', 'worn', VESPER_PALETTE.asphalt,
      {tiles_per_metre: 1.2, roughness: 0.92, albedo_gain: 1.15, texture_strength: 0.24, texture_saturation: 0, normal_strength: 0.08, metallic: 0.02, specular_strength: 0.14}, 610426)),
    // Tram rails, roof trusses, tiebeams, clock hands: authored metallic 0.65.
    material('iron', 'brushed-alloy', base('brushed-alloy', 'default', VESPER_PALETTE.iron,
      {tiles_per_metre: 1.5, roughness: 0.42, albedo_gain: 1.35, texture_strength: 0.2, texture_saturation: 0, normal_strength: 0.06, metallic: 0.6, specular_strength: 0.3}, 610427)),
  ],
  panels: vesperPanels(),
  signs: vesperSigns(),
  pockets: vesperPockets(),
  // Transparent glazing, the canal surface and the baked Blender font faces keep
  // their one-sided/transmissive materials: a triplanar finish would expose
  // mirrored glyph backs and turn the glass opaque.
  preserve_materials: ['glass', 'letter', 'water'],
  budgets: {material_variants: 8, panels: 48, signs: 20, motes: 64},
};

// --------------------------------------------------------------- abyssal -----
// Twelve pressure vessels in three districts (terraced-laboratories y 0-6,
// pump-energy y 10, residential-operations y 20), nine coral reefs along
// z -110..-116, and the pressure-equalizer core at (44, 20, 8) under an amber cap.
const ABYSSAL_VESSELS = [
  {id: 'vessel-0-0', name: 'INTAKE QUARANTINE', district: 'LABORATORIES', x: -94, y: 6, z: -68, w: 40, d: 40, h: 10, port: 's', pc: [-94, -48]},
  {id: 'vessel-0-1', name: 'SPECTROMETRY', district: 'LABORATORIES', x: -34, y: 4, z: -78, w: 40, d: 40, h: 10, port: 's', pc: [-34, -58]},
  {id: 'vessel-0-2', name: 'REEF OBSERVATION', district: 'LABORATORIES', x: 31, y: 2, z: -68, w: 40, d: 40, h: 10, port: 's', pc: [31, -48]},
  {id: 'vessel-0-3', name: 'SAMPLE ARCHIVE', district: 'LABORATORIES', x: 91, y: 0, z: -58, w: 40, d: 40, h: 10, port: 's', pc: [91, -38]},
  {id: 'vessel-1-0', name: 'FREIGHT LOCK', district: 'PUMP ENERGY', x: -91, y: 10, z: 0, w: 44, d: 44, h: 15, port: 'e', pc: [-69, 0]},
  {id: 'vessel-1-1', name: 'PUMP CATHEDRAL', district: 'PUMP ENERGY', x: -32, y: 10, z: 0, w: 44, d: 44, h: 15, port: 'e', pc: [-10, 0]},
  {id: 'vessel-1-2', name: 'EQUALIZER ATRIUM', district: 'PUMP ENERGY', x: 34, y: 10, z: 0, w: 44, d: 44, h: 24, port: 'e', pc: [56, 0]},
  {id: 'vessel-1-3', name: 'DISTRIBUTION HALL', district: 'PUMP ENERGY', x: 94, y: 10, z: 0, w: 44, d: 44, h: 15, port: 'w', pc: [72, 0]},
  {id: 'vessel-2-0', name: 'RESIDENTIAL COMMONS', district: 'OPERATIONS', x: -98, y: 20, z: 68, w: 38, d: 36, h: 9, port: 'n', pc: [-98, 50]},
  {id: 'vessel-2-1', name: 'MEDICAL OPERATIONS', district: 'OPERATIONS', x: -39, y: 20, z: 78, w: 38, d: 36, h: 9, port: 'n', pc: [-39, 60]},
  {id: 'vessel-2-2', name: 'MISSION CONTROL', district: 'OPERATIONS', x: 26, y: 20, z: 64, w: 38, d: 36, h: 9, port: 'n', pc: [26, 46]},
  {id: 'vessel-2-3', name: 'EMERGENCY REFUGE', district: 'OPERATIONS', x: 87, y: 20, z: 72, w: 38, d: 36, h: 9, port: 'n', pc: [87, 54]},
];
// Port face orientation: outward normal of the named port.
const PORT_FACE = {
  n: {offset: [0, -0.5], rotation: [0, 180, 0]},
  s: {offset: [0, 0.5], rotation: [0, 0, 0]},
  e: {offset: [0.5, 0], rotation: [0, 90, 0]},
  w: {offset: [-0.5, 0], rotation: [0, -90, 0]},
};
// Copper port seals are 1 x 7 x 1 boxes centred on the port jambs at port.y + 3.5,
// straddling a 10 m (labs/residential) or 14 m (pump) opening.
const ABYSSAL_SEALS = [
  {vessel: 'vessel-0-0', side: 'e'}, {vessel: 'vessel-0-1', side: 's'}, {vessel: 'vessel-0-2', side: 'e'},
  {vessel: 'vessel-0-3', side: 'w'}, {vessel: 'vessel-1-0', side: 'n'}, {vessel: 'vessel-1-1', side: 'w'},
  {vessel: 'vessel-1-2', side: 'n'}, {vessel: 'vessel-1-3', side: 's'}, {vessel: 'vessel-2-0', side: 'e'},
  {vessel: 'vessel-2-1', side: 'e'}, {vessel: 'vessel-2-2', side: 'w'}, {vessel: 'vessel-2-3', side: 'w'},
];
// Coral reef columns: x, z, radius, base y, height.
const ABYSSAL_REEFS = [[-110, -110, 7, -12, 42], [-83, -116, 8, -15, 46], [-56, -110, 9, -18, 50],
  [-29, -116, 7, -12, 54], [-2, -110, 8, -15, 42], [25, -116, 9, -18, 46], [52, -110, 7, -12, 50],
  [79, -116, 8, -15, 54], [106, -110, 9, -18, 42]];
// Ivory bay canopies over the south (observation) elevations of the lab vessels.
const ABYSSAL_CANOPIES = [[-94, -48], [-34, -58], [31, -48], [91, -38], [-98, 50], [-39, 60]];

function abyssalPanels() {
  const panels = [];
  let seed = 610500;
  const byId = Object.fromEntries(ABYSSAL_VESSELS.map(v => [v.id, v]));
  for (const entry of ABYSSAL_SEALS) {
    const vessel = byId[entry.vessel];
    const ports = {
      n: {c: [vessel.x, vessel.z - vessel.d / 2]}, s: {c: [vessel.x, vessel.z + vessel.d / 2]},
      e: {c: [vessel.x + vessel.w / 2, vessel.z]}, w: {c: [vessel.x - vessel.w / 2, vessel.z]},
    };
    const face = PORT_FACE[entry.side];
    const center = ports[entry.side].c;
    panels.push(panel({
      id: `port-seal-${entry.vessel}-${entry.side}`,
      position: [center[0] + face.offset[0], vessel.y + 3.5, center[1] + face.offset[1]],
      rotation_degrees: face.rotation,
      size: [0.9, 5], texture: 'metal-oxide', tint: '8a8f84',
      wear_mask: 'weathered_concrete', opacity: 0.14, feather: 0.4, seed: seed++,
    }));
  }
  // Cyan instrument strips read out above each ivory/coral workstation bench.
  for (const [x, z, y] of [[-104, -78, 6.75], [-84, -78, 6.75], [-44, -88, 4.75], [-24, -88, 4.75],
    [21, -78, 2.75], [41, -78, 2.75], [81, -68, 0.75], [101, -68, 0.75]]) {
    panels.push(panel({
      id: `instrument-readout-${x}-${z}`,
      position: [x, y + 0.86, z - 1.2], rotation_degrees: [0, 180, 0],
      size: [2.6, 0.9], texture: 'holographic_grid', tint: '8fc4cc',
    }));
  }
  // Ivory bay canopy lights on the lab/residential canopy fascias.
  for (const [x, z] of ABYSSAL_CANOPIES) {
    panels.push(panel({
      id: `canopy-lamp-${x}-${z}`, position: [x, 12.2, z + 0.3], rotation_degrees: [0, 0, 0],
      size: [2.4, 0.5], texture: 'hex_paneling', normal: 'baked:hex_paneling', tint: 'd8e2dc',
    }));
  }
  // Amber pressure cap on the equalizer core (plates at y=30 and y=32, x 40..48, z 4..12).
  panels.push(panel({
    id: 'core-cap-warning', position: [44, 31, 3.85], rotation_degrees: [0, 180, 0],
    size: [8, 2.4], texture: 'hazard_stripes', tint: 'dca45e',
  }));
  panels.push(panel({
    id: 'core-cap-warning-east', position: [48.15, 31, 8], rotation_degrees: [0, 90, 0],
    size: [8, 2.4], texture: 'hazard_stripes', tint: 'dca45e',
  }));
  // Damp silt collecting on the coral reef skirts.
  for (const [x, z, r, base, h] of [ABYSSAL_REEFS[0], ABYSSAL_REEFS[2], ABYSSAL_REEFS[4],
    ABYSSAL_REEFS[6], ABYSSAL_REEFS[8]]) {
    panels.push(panel({
      id: `reef-silt-${x}`, position: [x, base + h * 0.32, z + r + 0.2], rotation_degrees: [0, 0, 0],
      size: [r * 1.2, 0.4], texture: 'weathered_concrete-damp', tint: '7f8a86',
      wear_mask: 'weathered_concrete', opacity: 0.16, feather: 0.4, seed: seed++,
    }));
  }
  // Pump spine deck grates.
  for (const x of [-61.5, -8.5, 45, 83]) {
    panels.push(panel({
      id: `pump-spine-grate-${x}`, position: [x, 10.12, 0], rotation_degrees: [0, 0, 0],
      size: [3, 14], texture: 'metal_grating', tint: '6f7a80',
    }));
  }
  return panels;
}

function abyssalSigns() {
  const signs = [];
  const fg = 'dbe7e4', bg = '1d2f38';
  for (const vessel of ABYSSAL_VESSELS) {
    const face = PORT_FACE[vessel.port];
    signs.push(sign(`vessel-${vessel.id}`, [vessel.pc[0] + face.offset[0] * 1.4, vessel.y + 8.2, vessel.pc[1] + face.offset[1] * 1.4],
      face.rotation, [4.6, 0.66], `${vessel.name}\n${vessel.district}`, fg, bg));
  }
  signs.push(sign('objective-reef', [-34, 6.2, -70], [0, 0, 0], [4.2, 0.66], 'REEF LAB\nSECTOR 1', fg, bg));
  signs.push(sign('objective-equalizer', [34, 12.2, 8], [0, 0, 0], [4.2, 0.66], 'EQUALIZER\nSECTOR 2', fg, bg));
  signs.push(sign('objective-operations', [26, 22.2, 56], [0, 0, 0], [4.2, 0.66], 'OPERATIONS\nSECTOR 3', fg, bg));
  return signs;
}

function abyssalPockets() {
  const pockets = [];
  // Observation glazing haze on the four south lab elevations. Each pocket is one
  // bounded mote volume, so the 26 m glazing takes one volume rather than one
  // oversized one.
  for (const [x, z, y] of [[-94, -88, 7.2], [-34, -98, 5.2], [31, -88, 3.2], [91, -78, 1.2]]) {
    pockets.push(pocket(`observation-mist-${x}`, 'mist', [x, y + 2.6, z + 0.4], [8, 5.3, 0.6], '9fc2c6', 6));
  }
  pockets.push(pocket('equalizer-core-vent', 'vent', [44, 32.4, 8], [7, 2, 7], 'b7cfd0', 8));
  for (const [x, z, r, b, h] of [ABYSSAL_REEFS[1], ABYSSAL_REEFS[4], ABYSSAL_REEFS[7]]) {
    pockets.push(pocket(`reef-silt-dust-${x}`, 'dust', [x, b + h + 1.2, z], [7, 2, 7], 'b6ab97', 4));
  }
  pockets.push(pocket('pump-cathedral-dust', 'dust', [-32, 12.2, 0], [8, 2, 8], 'b6ab97', 6));
  return pockets;
}

const abyssal = {
  version: 1,
  map_id: 'abyssal-pressureworks',
  geometry_hash: '32366a6c3df7f95f8d89281c5f83b24d9583cefeb4c0099790303d15349b53be',
  materials: [
    // Vessel decks, crowns and splayed roof facets.
    material('navy', 'brushed-alloy', base('brushed-alloy', 'default', ABYSSAL_PALETTE.navy,
      {tiles_per_metre: 1.3, roughness: 0.62, albedo_gain: 1.3, texture_strength: 0.22, texture_saturation: 0.1, normal_strength: 0.08, metallic: 0.35, specular_strength: 0.24}, 610520)),
    // Bay canopies, overhead ribs and workstation benches.
    material('ivory', 'pearl-ceramic', base('pearl-ceramic', 'cast', ABYSSAL_PALETTE.ivory,
      {tiles_per_metre: 1.35, roughness: 0.8, albedo_gain: 1.3, texture_strength: 0.26, texture_saturation: 0.04, normal_strength: 0.1, metallic: 0.02, specular_strength: 0.22}, 610521)),
    // 68 port seals plus the pressure-equalizer core column.
    material('copper', 'oxidised-copper', base('oxidised-copper', 'default', ABYSSAL_PALETTE.copper,
      {tiles_per_metre: 1.2, roughness: 0.66, albedo_gain: 1.35, texture_strength: 0.24, texture_saturation: 0.12, normal_strength: 0.1, metallic: 0.4, specular_strength: 0.24}, 610522)),
    // Bay screens and the coral reef growths: the living surface of the habitat.
    material('coral', 'bioluminescent-membrane', base('bioluminescent-membrane', 'veined', ABYSSAL_PALETTE.coral,
      {tiles_per_metre: 1.1, roughness: 0.72, albedo_gain: 1.15, texture_strength: 0.28, texture_saturation: 0.16, normal_strength: 0.16, metallic: 0, specular_strength: 0.18}, 610523)),
    // Instrument readouts: glazed, faintly self-lit glass.
    material('cyan', 'polar-ice', base('polar-ice', 'glazed', ABYSSAL_PALETTE.cyan,
      {tiles_per_metre: 1.4, roughness: 0.2, albedo_gain: 1.6, texture_strength: 0.2, texture_saturation: 0.2, normal_strength: 0.12, metallic: 0, specular_strength: 0.36}, 610524)),
    // The amber pressure cap: a warning plate, which is what hazard-industrial is for.
    material('amber', 'hazard-industrial', base('hazard-industrial', 'default', ABYSSAL_PALETTE.amber,
      {tiles_per_metre: 1.1, roughness: 0.6, albedo_gain: 1.25, texture_strength: 0.3, texture_saturation: 0.1, normal_strength: 0.14, metallic: 0.2, specular_strength: 0.26}, 610525)),
  ],
  panels: abyssalPanels(),
  signs: abyssalSigns(),
  pockets: abyssalPockets(),
  // Observation glazing is a transparent, shot-through surface; keep it.
  preserve_materials: ['glass'],
  budgets: {material_variants: 6, panels: 48, signs: 20, motes: 56},
};

// ------------------------------------------------------------ stormglass -----
// A coastal barrier circuit: 21 asphalt road segments, 10 observatory terminals,
// 22 quay workshops, three barrier gates and a concrete sea wall.
const STORMGLASS_GATES = [
  {id: 'gate-1', x: -10, z: -122.5},
  {id: 'gate-14', x: -200, z: 55},
  {id: 'gate-18', x: -77.5, z: -42.5},
];
// Observatory terminals: district id, x, z, height, south face z.
const STORMGLASS_TERMINALS = [
  ['district-0-1', -90, -105, 22], ['district-0-2', -63, -105, 16], ['district-1-0', -41, -103, 16],
  ['district-1-1', -15, -98, 22], ['district-2-0', 30, -87, 16], ['district-2-1', 54, -75, 22],
  ['district-3-1', 103, -37, 22], ['district-19-0', -93, -97, 16], ['district-19-1', -111, -102, 22],
];
// Quay workshop blocks, read from their brick body batches.
const STORMGLASS_WORKSHOPS = [
  ['district-7-1', 81, 141, 11], ['district-7-2', 70, 155, 11], ['district-8-0', 40, 171, 14],
  ['district-8-2', 10, 174, 14], ['district-9-0', -22, 164, 8], ['district-10-2', -52, 158, 11],
  ['district-11-1', -108, 142, 14], ['district-12-2', -142, 138, 8], ['district-13-0', -178, 128, 11],
  ['district-14-2', -228, 43, 14], ['district-17-1', -101, -21, 14], ['district-18-1', -100, -32, 8],
];
// Sea-wall segments (concrete, 2.8 m tall) that carry the salt bloom.
const STORMGLASS_SEAWALL = [[-94, -144], [-7, -136], [72, -110], [134, -61], [164, 6], [155, 69],
  [114, 106], [70, 138], [24, 161], [-21, 151], [-54, 147], [-95, 139], [-138, 125], [-183, 109],
  [-214, 55], [-194, 7], [-140, -5], [-98, -10], [-91, -39], [-131, -67]];

function stormglassPanels() {
  const panels = [];
  let seed = 610600;
  // Gate status boards on the raised storm leaves (teal, y 9..15).
  for (const gate of STORMGLASS_GATES) {
    for (const side of [-1, 1]) {
      panels.push(panel({
        id: `gate-readout-${gate.id}-${side < 0 ? 'n' : 's'}`,
        position: [gate.x, 12, gate.z + side * 0.6], rotation_degrees: [0, side < 0 ? 0 : 180, 0],
        size: [2.4, 1.6], texture: 'circuit_board-etch', tint: '7fa3a8',
      }));
    }
  }
  // Counterweight warning plates (amber, y 12.5..21.5) on each gate buttress pair.
  for (const gate of STORMGLASS_GATES) {
    for (const side of [-1, 1]) {
      panels.push(panel({
        id: `leaf-warning-${gate.id}-${side < 0 ? 'a' : 'b'}`,
        position: [gate.x + side * 4.24, 17, gate.z + side * 3.5], rotation_degrees: [0, side < 0 ? 0 : 180, 0],
        size: [3.2, 1], texture: 'hazard_stripes', tint: 'f0c070',
      }));
    }
  }
  // Service hatches on the observatory terminal plinths.
  for (const [id, x, z] of [STORMGLASS_TERMINALS[0], STORMGLASS_TERMINALS[1], STORMGLASS_TERMINALS[3],
    STORMGLASS_TERMINALS[5], STORMGLASS_TERMINALS[6], STORMGLASS_TERMINALS[8]]) {
    panels.push(panel({
      id: `terminal-hatch-${id}`, position: [x, 1.6, z + 7.1], rotation_degrees: [0, 0, 0],
      size: [1.6, 1], texture: 'brushed_metal', normal: 'baked:metal', tint: '8b9a9e',
    }));
  }
  // Salt bloom on the seaward face of ten sea-wall segments.
  for (const [x, z] of [STORMGLASS_SEAWALL[0], STORMGLASS_SEAWALL[1], STORMGLASS_SEAWALL[2],
    STORMGLASS_SEAWALL[4], STORMGLASS_SEAWALL[6], STORMGLASS_SEAWALL[8], STORMGLASS_SEAWALL[12],
    STORMGLASS_SEAWALL[15], STORMGLASS_SEAWALL[17], STORMGLASS_SEAWALL[19]]) {
    panels.push(panel({
      id: `seawall-salt-bloom-${x}-${z}`, position: [x, 1.35, z + 1.45], rotation_degrees: [0, 0, 0],
      size: [7, 2.2], texture: 'weathered_concrete-worn', tint: 'c9cfc9',
      wear_mask: 'weathered_concrete', opacity: 0.18, feather: 0.4, seed: seed++,
    }));
  }
  // Road shoulder drainage grates either side of each gate.
  for (const gate of STORMGLASS_GATES) {
    for (const side of [-1, 1]) {
      panels.push(panel({
        id: `shoulder-grate-${gate.id}-${side < 0 ? 'a' : 'b'}`,
        position: [gate.x + side * 4, 0.06, gate.z + side * 6.5], rotation_degrees: [0, 0, 0],
        size: [3, 1.6], texture: 'metal_grating', tint: '79868a',
      }));
    }
  }
  return panels;
}

function stormglassSigns() {
  const signs = [];
  const fg = 'e2ecea', bg = '20363a';
  for (const gate of STORMGLASS_GATES) {
    const number = gate.id.split('-')[1];
    for (const side of [-1, 1]) {
      signs.push(sign(`gate-${number}-${side < 0 ? 'north' : 'south'}`, [gate.x, 22.9, gate.z + side * 0.6],
        [0, side < 0 ? 0 : 180, 0], [5.4, 0.72], `BARRIER GATE ${number}\nSTORM BARRIER`, fg, bg));
    }
  }
  for (const [id, x, z, height] of STORMGLASS_TERMINALS) {
    signs.push(sign(`terminal-${id}`, [x, height - 2.2, z + 7.1], [0, 0, 0], [5.6, 0.72],
      `OBSERVATORY TERMINAL\n${id.toUpperCase().replace('DISTRICT-', 'D')}`, fg, bg));
  }
  for (const [id, x, z, height] of [STORMGLASS_WORKSHOPS[0], STORMGLASS_WORKSHOPS[3],
    STORMGLASS_WORKSHOPS[6], STORMGLASS_WORKSHOPS[9], STORMGLASS_WORKSHOPS[10]]) {
    signs.push(sign(`workshop-${id}`, [x, height - 2.2, z + 7.1], [0, 0, 0], [5.6, 0.72],
      `QUAY WORKSHOP\n${id.toUpperCase().replace('DISTRICT-', 'D')}`, fg, bg));
  }
  signs.push(sign('start-finish-line', [-66, 5.2, -141], [0, 0, 0], [6.4, 0.72], 'START / FINISH\nGRAND PRIX', fg, bg));
  return signs;
}

function stormglassPockets() {
  const pockets = [];
  // Sea spray blowing over the seawall on the exposed western straight.
  for (const [x, z] of [[-94, -144], [-7, -136], [-91, -39], [-131, -67]]) {
    pockets.push(pocket(`seawall-spray-${x}`, 'mist', [x, 3.4, z + 3], [8, 2.4, 4], 'b6ccd2', 8));
  }
  // Storm vents at the barrier gate machinery.
  for (const gate of STORMGLASS_GATES) {
    pockets.push(pocket(`gate-vent-${gate.id}`, 'vent', [gate.x, 24.6, gate.z], [6, 2, 6], 'a9c0c6', 6));
  }
  // Road grit and salt dust along the circuit shoulders.
  for (const [x, z] of [[-90, -130], [-10, -123], [-200, 55], [-77.5, -42.5], [114, 106]]) {
    pockets.push(pocket(`road-grit-${x}-${z}`, 'dust', [x, 0.6, z], [8, 1.2, 8], 'b3ab97', 5));
  }
  return pockets;
}

const stormglass = {
  version: 1,
  map_id: 'stormglass-causeway',
  geometry_hash: '6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48',
  materials: [
    // 21 circuit road segments at y=0.
    material('asphalt', 'pearl-ceramic', base('pearl-ceramic', 'worn', STORMGLASS_PALETTE.asphalt,
      {tiles_per_metre: 1.2, roughness: 0.9, albedo_gain: 1.2, texture_strength: 0.26, texture_saturation: 0, normal_strength: 0.08, metallic: 0.02, specular_strength: 0.14}, 610620)),
    // Sea wall, barrier buttresses and quay foundations.
    material('concrete', 'pearl-ceramic', base('pearl-ceramic', 'cast', STORMGLASS_PALETTE.concrete,
      {tiles_per_metre: 1.3, roughness: 0.86, albedo_gain: 1.25, texture_strength: 0.28, texture_saturation: 0.03, normal_strength: 0.1, metallic: 0.02, specular_strength: 0.2}, 610621)),
    // The salt crust that caps every cornice and reflector in the city.
    material('salt', 'polar-ice', base('polar-ice', 'default', STORMGLASS_PALETTE.salt,
      {tiles_per_metre: 1.2, roughness: 0.62, albedo_gain: 1.35, texture_strength: 0.3, texture_saturation: 0.05, normal_strength: 0.18, metallic: 0, specular_strength: 0.28}, 610622)),
    // Gate counterweights: the storm barrier's warning mass.
    material('amber', 'hazard-industrial', base('hazard-industrial', 'default', STORMGLASS_PALETTE.amber,
      {tiles_per_metre: 1.1, roughness: 0.6, albedo_gain: 1.2, texture_strength: 0.3, texture_saturation: 0.08, normal_strength: 0.14, metallic: 0.2, specular_strength: 0.26}, 610623)),
    // Terminal and workshop bodies, and the raised gate leaves: cracked storm glass.
    material('teal', 'enamel-glaze', base('enamel-glaze', 'crackle', STORMGLASS_PALETTE.teal,
      {tiles_per_metre: 1.1, roughness: 0.24, albedo_gain: 1.3, texture_strength: 0.26, texture_saturation: 0.14, normal_strength: 0.18, metallic: 0.04, specular_strength: 0.38}, 610624)),
    // Gantries, pistons and roof machinery (authored metallic 0.5).
    material('steel', 'brushed-alloy', base('brushed-alloy', 'plate', STORMGLASS_PALETTE.steel,
      {tiles_per_metre: 1.4, roughness: 0.44, albedo_gain: 1.3, texture_strength: 0.2, texture_saturation: 0.04, normal_strength: 0.08, metallic: 0.5, specular_strength: 0.3}, 610625)),
    // Quay workshop bodies.
    material('brick', 'pearl-ceramic', base('pearl-ceramic', 'worn', STORMGLASS_PALETTE.brick,
      {tiles_per_metre: 1.3, roughness: 0.88, albedo_gain: 1.3, texture_strength: 0.3, texture_saturation: 0.06, normal_strength: 0.1, metallic: 0.02, specular_strength: 0.2}, 610626)),
  ],
  panels: stormglassPanels(),
  signs: stormglassSigns(),
  pockets: stormglassPockets(),
  // Window glazing and the sea plane stay transmissive.
  preserve_materials: ['glass', 'ocean'],
  budgets: {material_variants: 7, panels: 48, signs: 24, motes: 80},
};

const PROFILES = {
  'vesper-viaduct': vesper,
  'abyssal-pressureworks': abyssal,
  'stormglass-causeway': stormglass,
};

export function build(mapId) {
  if (!PROFILES[mapId]) throw Error(`unknown map ${mapId}`);
  return PROFILES[mapId];
}

export function serialise(mapId) {
  return `${JSON.stringify(build(mapId), null, 2)}\n`;
}

export const MAP_IDS = Object.keys(PROFILES);

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2] ?? '--check';
  let failures = 0;
  for (const mapId of MAP_IDS) {
    const path = resolve(PROFILE_DIR, `${mapId}.json`);
    const text = serialise(mapId);
    if (mode === '--write') {
      writeFileSync(path, text);
      console.log(`WROTE ${path}`);
    } else if (!existsSync(path)) {
      console.error(`MISSING ${path}`);
      failures++;
    } else if (readFileSync(path, 'utf8') !== text) {
      console.error(`DRIFT ${path}: committed JSON differs from author.mjs`);
      failures++;
    } else {
      const p = build(mapId);
      const motes = p.pockets.reduce((sum, e) => sum + e.count, 0);
      console.log(`OK ${mapId}: materials=${p.materials.length} panels=${p.panels.length} ` +
        `signs=${p.signs.length} pockets=${p.pockets.length} motes=${motes} preserve=${p.preserve_materials.length}`);
    }
  }
  process.exitCode = failures ? 1 : 0;
}
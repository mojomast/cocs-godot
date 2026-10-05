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
// The last argument overrides the private variation defaults, which is how the
// seven accepted Foundry materials keep their authored manufactured/organic split
// while the three maps this lane authored keep the shared floor.
const base = (family, variant, tint, response, seed, variation = {}) => ({
  variant, tint,
  lut_gain: 0, pulse_speed: 0, pulse_depth: 0,
  detail_strength: 0.06, ao_strength: 0.14,
  roughness_variation: 0.1,
  ...response,
  variation_mode: 'organic', variation_strength: 0.3, variation_scale: 0.07, variation_seed: seed,
  ...variation,
});

const material = (source, family, options) => ({source, family, options});

// Placement convention, read off binder.gd: every panel and sign is a QuadMesh
// whose front face is its local +Z, and both panel.gdshader and wear_panel.gdshader
// declare cull_back. So a yaw of 0 faces +Z, 90 faces +X, 180 faces -Z and -90
// faces -X, and the plate is mounted a short way off the solid it dresses, offset
// along the direction it faces (panel.gdshader: "mounted 32 mm off an existing
// solid"). Horizontal dressing uses pitch instead: -90 faces up, +90 faces down.
const FACE_UP = [-90, 0, 0];
const FACE_DOWN = [90, 0, 0];
const faceYaw = (fx, fz) => [0, Math.round(Math.atan2(fx, fz) * 180 / Math.PI), 0];

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
// The twelve iron street-cover-cap plates, three per terrace level (y 1.6 quay,
// 13.6 cobble, 25.6 upper deck), read off terrain.surfaces.
const VESPER_STREET_COVERS = [[-112, 1.6, -78], [-36, 1.6, -78], [36, 1.6, -78], [112, 1.6, -78],
  [-112, 13.6, 7], [-36, 13.6, 7], [36, 13.6, 7], [112, 13.6, 7],
  [-112, 25.6, 92], [-36, 25.6, 92], [36, 25.6, 92], [112, 25.6, 92]];
// The six quay-rail-cap runs on both quay lips (z -104 and z -116). The 188 m
// centre run carries two inspection plates, the 34 m end runs one each.
const VESPER_QUAY_RAILS = [[-123, 1.5, -104], [-47, 1.5, -104], [47, 1.5, -104], [123, 1.5, -104],
  [-123, 1.5, -116], [-47, 1.5, -116], [47, 1.5, -116], [123, 1.5, -116]];
// The four canal-bridge parapet caps (x +-94/+-106, 12 m long at y 1.4).
const VESPER_BRIDGE_PARAPETS = [[-106, 1.4, -110], [-94, 1.4, -110], [94, 1.4, -110], [106, 1.4, -110]];
// The ten chimney caps on the mid terrace block, the row band that flanks the
// civic arcade and therefore the block the player walks most.
const VESPER_CHIMNEY_CAPS = [[-82, 35.1, 45], [-74, 38.1, 45], [-66, 41.1, 45], [-58, 35.1, 45],
  [-50, 38.1, 45], [54, 35.1, 45], [62, 38.1, 45], [70, 41.1, 45], [78, 35.1, 45], [86, 38.1, 45]];
// The ten terrace row caps on the same band (8 x 22 m plaster/brick roofs).
const VESPER_ROW_CAPS = [[-84, 33.1, 45], [-76, 36.1, 45], [-68, 39.1, 45], [-60, 33.1, 45],
  [-52, 36.1, 45], [52, 33.1, 45], [60, 36.1, 45], [68, 39.1, 45], [76, 33.1, 45], [84, 36.1, 45]];
// The ten arcade pier caps either side of the clock square.
const VESPER_ARCADE_PIERS = [[-90, 34, 66], [-78, 34, 66], [-66, 34, 66], [-54, 34, 66], [-42, 34, 66],
  [42, 34, 66], [54, 34, 66], [66, 34, 66], [78, 34, 66], [90, 34, 66]];
// The three public hall roof ridges (slate), one maintenance hatch each.
const VESPER_HALL_RIDGES = [[-66, 39, 78], [0, 44, 78], [66, 41, 78]];

function vesperPanels() {
  const panels = [];
  let seed = 610400;
  // Parcel-bay label plates on the four non-ticket halls (both elevations).
  // Orientation fix (R7 follow-up): each plate sits 0.18 m off the elevation it
  // dresses, so it must face away from that wall. side -1 is the -Z elevation
  // (faces -Z, yaw 180) and side +1 the +Z elevation (faces +Z, yaw 0). The first
  // pass emitted the inverted pair, which cull_back made invisible.
  for (const hall of VESPER_PARCEL) {
    for (const side of [-1, 1]) {
      panels.push(panel({
        id: `parcel-plate-${hall.id}-${side < 0 ? 'n' : 's'}`,
        position: [hall.x, hall.y + 0.7, hall.z + side * (hall.d / 2 + 0.18)],
        rotation_degrees: [0, side < 0 ? 180 : 0, 0],
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
  // --- second pass: every remaining named solid on the terraces gets dressed ---
  // Street service covers: diamond-plate inspection hatches on the twelve iron
  // street-cover-cap plates, lying flat on the cover.
  for (const [x, y, z] of VESPER_STREET_COVERS) {
    panels.push(panel({
      id: `street-cover-hatch-${x}-${z}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [2.6, 2.6], texture: 'diamond_plate', normal: 'baked:diamond_plate', tint: '6d6a62',
    }));
  }
  // Quay edge rail walks: grating plates along the iron quay rail caps.
  VESPER_QUAY_RAILS.forEach(([x, y, z], i) => {
    panels.push(panel({
      id: `quay-rail-walk-${i}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [6, 0.5], texture: 'metal_grating', tint: '6d6a62',
    }));
  });
  // Canal bridge parapets: no-standing bands on the four parapet caps.
  for (const [x, y, z] of VESPER_BRIDGE_PARAPETS) {
    panels.push(panel({
      id: `bridge-parapet-band-${x}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [0.5, 8], texture: 'hazard_stripes', tint: 'b08a52',
    }));
  }
  // Chimney caps: soot bloom around the flue on the mid-block flues.
  for (const [x, y, z] of VESPER_CHIMNEY_CAPS) {
    panels.push(panel({
      id: `chimney-cap-soot-${x}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [1.1, 1.4], texture: 'riveted_armor-scorched', tint: '6f6157',
    }));
  }
  // Terrace row roofs: weathered membrane patches over the mid-block row caps.
  for (const [x, y, z] of VESPER_ROW_CAPS) {
    panels.push(panel({
      id: `terrace-cap-membrane-${x}-${z}`, position: [x, y + 0.03, z], rotation_degrees: FACE_UP,
      size: [6, 14], texture: 'rough_stucco-weathered', tint: '8a8076',
      wear_mask: 'rough_stucco', opacity: 0.2, feather: 0.4, seed: seed++,
    }));
  }
  // Arcade piers: hazard bands on all ten pier caps.
  for (const [x, y, z] of VESPER_ARCADE_PIERS) {
    panels.push(panel({
      id: `arcade-pier-band-${x}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [1.6, 2.8], texture: 'hazard_stripes', tint: 'b08a52',
    }));
  }
  // Public hall roofs: maintenance hatches on the three ticket-hall ridges.
  for (const [x, y, z] of VESPER_HALL_RIDGES) {
    panels.push(panel({
      id: `hall-roof-hatch-${x}`, position: [x, y + 0.06, z], rotation_degrees: FACE_UP,
      size: [5, 5], texture: 'brushed_metal', normal: 'baked:metal', tint: '8d8a80',
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
  // --- second pass: the two steps objectives and the four terrace districts ---
  // Steps objectives, mounted on the terrace retaining walls above the
  // cobble-level street covers, facing in along each boulevard.
  signs.push(sign('objective-west-steps', [-112, 15.4, 7], [0, 90, 0], [3.5, 0.66], 'WEST STEPS\nGRAB', fg, bg));
  signs.push(sign('objective-east-steps', [112, 15.4, 7], [0, -90, 0], [3.5, 0.66], 'EAST STEPS\nGRAB', fg, bg));
  // Arcade fascias, read on approach up the civic stair.
  signs.push(sign('arcade-west', [-66, 33.4, 70.08], [0, 180, 0], [3.8, 0.66], 'CLOCK ARCADE\nMARKET ROW', fg, bg));
  signs.push(sign('arcade-east', [66, 33.4, 70.08], [0, 180, 0], [3.8, 0.66], 'CLOCK ARCADE\nCIVIC ARCADE', fg, bg));
  // Terrace block fascias, on the row caps that enclose the two housing bands.
  signs.push(sign('terrace-north', [-84, 35.4, 119.08], [0, 180, 0], [3.8, 0.66], 'NORTH TERRACE\nHOUSING', fg, bg));
  signs.push(sign('terrace-south', [-84, 18.9, -58.08], [0, 0, 0], [3.8, 0.66], 'SOUTH TERRACE\nDEPOTS', fg, bg));
  return signs;
}

function vesperPockets() {
  return [
    pocket('canal-mist-west', 'mist', [-100, 1.4, -108], [8, 3, 4], '9fb3c4', 12),
    pocket('canal-mist-east', 'mist', [100, 1.4, -108], [8, 3, 4], '9fb3c4', 12),
    pocket('cobble-ramp-dust', 'dust', [-60, 13.2, -25], [4, 1.6, 4], 'b3a894', 7),
    pocket('clock-square-dust', 'dust', [0, 13.2, 0], [4, 1.6, 4], 'b3a894', 7),
    pocket('ticket-hall-vent', 'vent', [-66, 28, 70], [4, 3, 4], 'a9b6bd', 8),
    pocket('platform-gallery-vent', 'vent', [0, 28, 70], [4, 3, 4], 'a9b6bd', 8),
    // --- second pass: the far quay, both hall roofs, the stair and the arcade ---
    pocket('far-quay-mist', 'mist', [0, 1.4, -118], [8, 2.6, 4], '9fb3c4', 8),
    pocket('roof-vent-ticket-concourse', 'vent', [-66, 42, 85], [8, 3, 8], 'a9b6bd', 8),
    pocket('roof-vent-east-station', 'vent', [66, 44, 85], [8, 3, 8], 'a9b6bd', 8),
    pocket('civic-stair-dust', 'dust', [32, 18.2, 45], [4, 2, 4], 'b3a894', 6),
    pocket('chimney-ash-west', 'ash', [-66, 42.3, 45], [2.4, 2.4, 2.4], 'a49a8c', 6),
    pocket('arcade-dust', 'dust', [-66, 34.4, 67.25], [8, 2, 5], 'b3a894', 5),
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
  // Raised toward the profile.gd hard caps (32/96/24/96) by the second pass.
  budgets: {material_variants: 8, panels: 96, signs: 24, motes: 96},
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
// Every vessel carries two ivory bay canopies, centred at (x +- 11, z + 10) and
// 5.8 m above the deck, whichever way its port faces.
const ABYSSAL_CANOPY_OFFSET = 11;
const ABYSSAL_CANOPY_RISE = 5.8;
// Vessel crowns: the walkable octagon that caps every vessel roof, read off
// terrain.surfaces "*-crown". Lab and pump crowns are 25-32 m across, the
// residential ones only 13 m, so the hatch plate is sized to suit.
const ABYSSAL_CROWNS = [
  {id: 'vessel-0-0', x: -94, y: 19, z: -68, plate: 3},
  {id: 'vessel-0-1', x: -34, y: 17, z: -78, plate: 3},
  {id: 'vessel-0-2', x: 31, y: 15, z: -68, plate: 3},
  {id: 'vessel-0-3', x: 91, y: 13, z: -58, plate: 3},
  {id: 'vessel-1-0', x: -91, y: 30, z: 0, plate: 3},
  {id: 'vessel-1-1', x: -32, y: 30, z: 0, plate: 3},
  {id: 'vessel-1-2', x: 34, y: 39, z: 0, plate: 3},
  {id: 'vessel-1-3', x: 94, y: 30, z: 0, plate: 3},
  {id: 'vessel-2-0', x: -98, y: 30.5, z: 68, plate: 2},
  {id: 'vessel-2-1', x: -39, y: 30.5, z: 78, plate: 2},
  {id: 'vessel-2-2', x: 26, y: 30.5, z: 64, plate: 2},
  {id: 'vessel-2-3', x: 87, y: 30.5, z: 72, plate: 2},
];
// Deck inspection plates, read off the "*-deck" octagons, are deliberately not
// emitted: see the note at the end of abyssalPanels().
// Coral observation sills: the four laboratory vessels are the only ones with
// glazing, and each carries one 26 m sill on its seaward elevation.
const ABYSSAL_SILLS = [[-94, 6.6, -88], [-34, 4.6, -98], [31, 2.6, -88], [91, 0.6, -78]];
// Link galleries: the three low-maintenance bypasses, three pump-spine decks and
// three operations galleries, each with its ramp centre, deck level and deck depth.
const ABYSSAL_GALLERY_DECKS = [
  {id: 'low-maintenance-bypass-0', x: -64, y: 5, z: -73, d: 20, name: 'MAINTENANCE BYPASS\nQUARANTINE LINK'},
  {id: 'low-maintenance-bypass-1', x: -1.5, y: 3, z: -73, d: 20, name: 'MAINTENANCE BYPASS\nSPECTROMETRY LINK'},
  {id: 'low-maintenance-bypass-2', x: 61, y: 1, z: -63, d: 20, name: 'MAINTENANCE BYPASS\nARCHIVE LINK'},
  {id: 'broad-pump-spine-0', x: -61.5, y: 10, z: 0, d: 14, name: 'BROAD PUMP SPINE\nFREIGHT LOCK'},
  {id: 'broad-pump-spine-1', x: 1, y: 10, z: 0, d: 14, name: 'BROAD PUMP SPINE\nPUMP CATHEDRAL'},
  {id: 'broad-pump-spine-2', x: 64, y: 10, z: 0, d: 14, name: 'BROAD PUMP SPINE\nEQUALIZER ATRIUM'},
  {id: 'operations-gallery-0', x: -68.5, y: 20, z: 73, d: 20, name: 'OPERATIONS GALLERY\nCOMMONS LINK'},
  {id: 'operations-gallery-1', x: -6.5, y: 20, z: 71, d: 24, name: 'OPERATIONS GALLERY\nMEDICAL LINK'},
  {id: 'operations-gallery-2', x: 56.5, y: 20, z: 68, d: 18, name: 'OPERATIONS GALLERY\nCONTROL LINK'},
];

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
  for (const [x, z, r, base, h] of ABYSSAL_REEFS) {
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
  // --- second pass: every crown, canopy, port mouth and glazed sill ------------
  // Crown service hatches on the twelve vessel crowns.
  for (const crown of ABYSSAL_CROWNS) {
    panels.push(panel({
      id: `crown-hatch-${crown.id}`, position: [crown.x, crown.y + 0.03, crown.z],
      rotation_degrees: FACE_UP, size: [crown.plate, crown.plate],
      texture: 'brushed_metal', normal: 'baked:metal', tint: '8fa0a4',
    }));
  }
  // Bay canopy light troughs: one under each of the twenty-four ivory canopies,
  // facing down out of the 0.4 m fascia gap.
  for (const vessel of ABYSSAL_VESSELS) {
    for (const side of [-1, 1]) {
      panels.push(panel({
        id: `canopy-trough-${vessel.id}-${side < 0 ? 'w' : 'e'}`,
        position: [vessel.x + side * ABYSSAL_CANOPY_OFFSET, vessel.y + ABYSSAL_CANOPY_RISE - 0.45, vessel.z + 10],
        rotation_degrees: FACE_DOWN, size: [5, 2.4], texture: 'holographic_grid', tint: '8fc4cc',
      }));
    }
  }
  // Port threshold plates: the deck plate every player crosses at a port mouth,
  // laid flat and turned to run with the opening.
  for (const vessel of ABYSSAL_VESSELS) {
    const face = PORT_FACE[vessel.port];
    // PORT_FACE.offset is a half-width step along the outward normal of the port.
    const yaw = faceYaw(face.offset[0] * 2, face.offset[1] * 2)[1];
    panels.push(panel({
      id: `port-threshold-${vessel.id}`,
      position: [vessel.pc[0] + face.offset[0] * 1.2, vessel.y + 0.03, vessel.pc[1] + face.offset[1] * 1.2],
      rotation_degrees: [-90, yaw, 0],
      size: [vessel.w >= 44 ? 8 : 6, 3],
      texture: 'diamond_plate', normal: 'baked:diamond_plate', tint: '8d9aa0',
    }));
  }
  // Coral observation sills: cyan instrument bays along the four glazed labs.
  for (const [x, y, z] of ABYSSAL_SILLS) {
    panels.push(panel({
      id: `observation-bay-${x}`, position: [x, y, z - 0.16], rotation_degrees: [0, 180, 0],
      size: [8, 0.9], texture: 'holographic_grid', tint: '8fc4cc',
    }));
  }
  // Deliberately not dressed: the twelve vessel deck plates and the six gallery
  // deck grates. Both would fit the geometry, but the panel group is already at
  // 93 of its 96 cap with the four families above, and a crown hatch reads from
  // further away than a plate in a deck corner.
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
  // --- second pass: every one of the nine link galleries gets a wayfinding ---
  // board, hung under its deck ceiling so it is read on approach along the spine.
  for (const gallery of ABYSSAL_GALLERY_DECKS) {
    signs.push(sign(`gallery-${gallery.id}`, [gallery.x, gallery.y + 2.8, gallery.z - gallery.d / 2 + 1],
      [0, 0, 0], [4.6, 0.66], gallery.name, fg, bg));
  }
  return signs;
}

function abyssalPockets() {
  const pockets = [];
  // Observation glazing haze on the four south lab elevations. Each pocket is one
  // bounded mote volume, so the 26 m glazing takes one volume rather than one
  // oversized one.
  for (const [x, z, y] of [[-94, -88, 7.2], [-34, -98, 5.2], [31, -88, 3.2], [91, -78, 1.2]]) {
    pockets.push(pocket(`observation-mist-${x}`, 'mist', [x, y + 2.6, z + 0.4], [8, 5.3, 0.6], '9fc2c6', 8));
  }
  pockets.push(pocket('equalizer-core-vent', 'vent', [44, 32.4, 8], [7, 2, 7], 'b7cfd0', 12));
  for (const [x, z, r, b, h] of [ABYSSAL_REEFS[1], ABYSSAL_REEFS[4], ABYSSAL_REEFS[7]]) {
    pockets.push(pocket(`reef-silt-dust-${x}`, 'dust', [x, b + h + 1.2, z], [7, 2, 7], 'b6ab97', 6));
  }
  pockets.push(pocket('pump-cathedral-dust', 'dust', [-32, 12.2, 0], [8, 2, 8], 'b6ab97', 8));
  // --- second pass: three more mote volumes, filling the twelve-pocket cap ---
  pockets.push(pocket('reef-silt-dust--29', 'dust', [-29, 43.2, -116], [6, 2, 6], 'b6ab97', 6));
  pockets.push(pocket('reef-silt-dust-52', 'dust', [52, 39.2, -110], [6, 2, 6], 'b6ab97', 6));
  pockets.push(pocket('operations-gallery-dust', 'dust', [-6.5, 21.4, 71], [8, 2, 8], 'b6ab97', 8));
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
  // Raised toward the profile.gd hard caps (32/96/24/96) by the second pass.
  budgets: {material_variants: 6, panels: 96, signs: 24, motes: 96},
};

// ------------------------------------------------------------ stormglass -----
// A coastal barrier circuit: 21 asphalt road segments, 10 observatory terminals,
// 22 quay workshops, three barrier gates and a concrete sea wall.
const STORMGLASS_GATES = [
  {id: 'gate-1', x: -10, z: -122.5},
  {id: 'gate-14', x: -200, z: 55},
  {id: 'gate-18', x: -77.5, z: -42.5},
];
// Each gate's raised storm leaf, in STORMGLASS_GATES order. A raised leaf lies
// across the road, so the two elevations a driver actually reads are the pair of
// leaf faces perpendicular to the direction of travel, and the axis differs per
// gate: gate-1's road runs mostly along X, gate-14's and gate-18's mostly along Z.
// Numbers are the span of the terrain's "gate-N-raised-leaf-*" walls; `axis` is
// the normal of the two readable faces, `low`/`high` their plane coordinates.
const STORMGLASS_LEAF_FACES = [
  {axis: 'x', low: -14.423, high: -5.577}, {axis: 'z', low: 50.391, high: 59.609},
  {axis: 'z', low: -50.486, high: -34.514},
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
// --- second pass tables, all read off the map's own terrain ---------------
// The twenty-one inner "barrier-city" walls, one per circuit straight. Each entry
// is the wall midpoint, the yaw that turns a plate to face the road (derived from
// the wall's own outward perpendicular, signed towards its sea-wall twin) and the
// plate length the straight can carry.
const STORMGLASS_CITY_WALLS = [
  {id: 'barrier-city-0', x: -85.605, z: -116, yaw: 180, plate: 12},
  {id: 'barrier-city-1', x: -12.904, z: -108.801, yaw: 169.38, plate: 12},
  {id: 'barrier-city-2', x: 58.277, z: -85.209, yaw: 153.435, plate: 12},
  {id: 'barrier-city-3', x: 111.402, z: -43.955, yaw: 129.289, plate: 12},
  {id: 'barrier-city-4', x: 136.089, z: 9.149, yaw: 98.746, plate: 12},
  {id: 'barrier-city-5', x: 130.306, z: 55.621, yaw: 60.945, plate: 12},
  {id: 'barrier-city-6', x: 95.929, z: 83.55, yaw: 21.801, plate: 12},
  {id: 'barrier-city-7', x: 54.862, z: 112.468, yaw: 48.814, plate: 12},
  {id: 'barrier-city-8', x: 21.271, z: 133.55, yaw: 6.34, plate: 12},
  {id: 'barrier-city-9', x: -14.442, z: 119.182, yaw: -40.601, plate: 12},
  {id: 'barrier-city-10', x: -51.093, z: 113.071, yaw: 29.745, plate: 12},
  {id: 'barrier-city-11', x: -90.295, z: 106.479, yaw: -37.875, plate: 12},
  {id: 'barrier-city-12', x: -131.538, z: 94.704, yaw: 14.036, plate: 12},
  {id: 'barrier-city-13', x: -166.748, z: 86.118, yaw: -41.186, plate: 12},
  {id: 'barrier-city-14', x: -185.789, z: 54.669, yaw: -78.69, plate: 12},
  {id: 'barrier-city-15', x: -175.774, z: 28.243, yaw: -147.995, plate: 12},
  {id: 'barrier-city-16', x: -134.557, z: 24.765, yaw: 169.695, plate: 12},
  {id: 'barrier-city-17', x: -77.134, z: 9.915, yaw: -146.31, plate: 12},
  {id: 'barrier-city-18', x: -63.652, z: -45.866, yaw: -65.556, plate: 12},
  {id: 'barrier-city-19', x: -103.507, z: -88.195, yaw: -15.255, plate: 12},
  {id: 'barrier-city-20', x: -123.474, z: -105.306, yaw: -108.435, plate: 9.02},
];
// The twenty-one asphalt road segments: centre, the yaw that runs a plate along
// the segment, and the dash length the segment can carry.
const STORMGLASS_ROADS = [
  {id: 'road-0', x: -90, z: -130, yaw: -180, plate: 12},
  {id: 'road-1', x: -10, z: -122.5, yaw: 169.38, plate: 12},
  {id: 'road-2', x: 65, z: -97.5, yaw: 153.435, plate: 12},
  {id: 'road-3', x: 122.5, z: -52.5, yaw: 129.289, plate: 12},
  {id: 'road-4', x: 150, z: 7.5, yaw: 98.746, plate: 12},
  {id: 'road-5', x: 142.5, z: 62.5, yaw: 60.945, plate: 12},
  {id: 'road-6', x: 105, z: 95, yaw: 21.801, plate: 12},
  {id: 'road-7', x: 62.5, z: 125, yaw: 48.814, plate: 12},
  {id: 'road-8', x: 22.5, z: 147.5, yaw: 6.34, plate: 12},
  {id: 'road-9', x: -17.5, z: 135, yaw: 139.399, plate: 12},
  {id: 'road-10', x: -52.5, z: 130, yaw: -150.255, plate: 12},
  {id: 'road-11', x: -92.5, z: 122.5, yaw: -37.875, plate: 12},
  {id: 'road-12', x: -135, z: 110, yaw: 14.036, plate: 12},
  {id: 'road-13', x: -175, z: 97.5, yaw: -41.186, plate: 12},
  {id: 'road-14', x: -200, z: 55, yaw: -78.69, plate: 12},
  {id: 'road-15', x: -185, z: 17.5, yaw: -147.995, plate: 12},
  {id: 'road-16', x: -137.5, z: 10, yaw: -10.305, plate: 12},
  {id: 'road-17', x: -87.5, z: 0, yaw: 33.69, plate: 12},
  {id: 'road-18', x: -77.5, z: -42.5, yaw: 114.444, plate: 12},
  {id: 'road-19', x: -117.5, z: -77.5, yaw: -15.255, plate: 12},
  {id: 'road-20', x: -137.5, z: -107.5, yaw: -108.435, plate: 12},
];
// The ten observatory-terminal elevations that face the circuit. The terminals
// are rotated off axis, so each entry carries the face the racing line actually
// sees, the yaw that turns a plate onto it and the terminal's own height (the
// tenth terminal, district-1-2, has no other dressing entry yet).
const STORMGLASS_TERMINAL_FRONTS = [
  {id: 'district-0-1', x: -90, z: -112.18, yaw: 180, plate: 8, height: 22},
  {id: 'district-0-2', x: -63.333, z: -112.18, yaw: 180, plate: 8, height: 16},
  {id: 'district-1-0', x: -39.951, z: -109.985, yaw: 169.38, plate: 8, height: 16},
  {id: 'district-1-1', x: -13.284, z: -104.985, yaw: 169.38, plate: 8, height: 22},
  {id: 'district-1-2', x: 13.383, z: -99.985, yaw: 169.38, plate: 8, height: 16},
  {id: 'district-2-0', x: 33.697, z: -93.228, yaw: 153.435, plate: 8, height: 16},
  {id: 'district-2-1', x: 57.031, z: -81.561, yaw: 153.435, plate: 8, height: 22},
  {id: 'district-3-1', x: 108.708, z: -41.216, yaw: 129.289, plate: 8, height: 22},
  {id: 'district-19-0', x: -94.478, z: -89.692, yaw: -15.255, plate: 6.4, height: 16},
  {id: 'district-19-1', x: -112.811, z: -94.692, yaw: -15.255, plate: 6.4, height: 22},
];
// The six gate buttress elevations that look down the racing line, two per gate.
const STORMGLASS_BUTTRESS_FACES = [
  {id: 'gate-1-buttress-1', x: -8.506, z: -102.815, yaw: 89.694, plate: 5.6},
  {id: 'gate-1-buttress--1', x: -7.808, z: -138.253, yaw: -20.933, plate: 7},
  {id: 'gate-14-buttress-1', x: -182.297, z: 46.262, yaw: -158.377, plate: 5.6},
  {id: 'gate-14-buttress--1', x: -215.432, z: 58.85, yaw: 90.997, plate: 7},
  {id: 'gate-18-buttress-1', x: -62.246, z: -55.032, yaw: -145.243, plate: 5.6},
  {id: 'gate-18-buttress--1', x: -91.654, z: -35.244, yaw: 104.131, plate: 7},
];
// The three steel gate gantries (y 22..24) that span the road.
const STORMGLASS_GANTRY_TOPS = [
  {id: 'gate-1', x: -12.457, z: -122.961, yaw: 79.38, plate: 12},
  {id: 'gate-14', x: -199.51, z: 57.451, yaw: -168.69, plate: 12},
  {id: 'gate-18', x: -76.465, z: -40.224, yaw: -155.56, plate: 12},
];

function stormglassPanels() {
  const panels = [];
  let seed = 610600;
  // Gate status boards on the raised storm leaves.
  // Orientation fix (R7 follow-up): the first pass offset the boards by
  // gate.z +- 0.6 and yawed them 0/180, which put them inside the raised leaf's
  // own volume facing each other, so cull_back hid them from every approach. A
  // raised leaf lies across the road, so the two elevations a driver reads are
  // the leaf faces perpendicular to travel, and that axis is per gate (see
  // STORMGLASS_LEAF_FACES). Each board goes 0.18 m off its face, facing away
  // from it: yaw 0 is +Z, so -Z is 180, -X is -90 and +X is 90.
  STORMGLASS_GATES.forEach((gate, i) => {
    const leaf = STORMGLASS_LEAF_FACES[i];
    // The face normal and the yaw that turns a plate to look down the road.
    const outward = plane => (plane === leaf.low ? -1 : 1);
    for (const end of ['low', 'high']) {
      const dir = outward(leaf[end]);
      const yaw = leaf.axis === 'x' ? (dir < 0 ? -90 : 90) : (dir < 0 ? 180 : 0);
      panels.push(panel({
        id: `gate-readout-${gate.id}-${end}`,
        position: leaf.axis === 'x' ? [leaf[end] + dir * 0.18, 12, gate.z] : [gate.x, 12, leaf[end] + dir * 0.18],
        rotation_degrees: [0, yaw, 0], size: [2.4, 1.6],
        texture: 'circuit_board-etch', tint: '7fa3a8',
      }));
    }
  });
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
  // --- second pass: the whole circuit gets marked, lit and warned ----------
  // Inner-wall salt bloom on all twenty-one barrier-city walls, the circuit-side
  // twin of the sea-wall bloom above.
  for (const wall of STORMGLASS_CITY_WALLS) {
    const fx = Math.sin(wall.yaw * Math.PI / 180), fz = Math.cos(wall.yaw * Math.PI / 180);
    panels.push(panel({
      id: `city-wall-salt-bloom-${wall.id}`, position: [wall.x + fx * 0.18, 1.35, wall.z + fz * 0.18],
      rotation_degrees: [0, wall.yaw, 0], size: [wall.plate, 2.2],
      texture: 'weathered_concrete-worn', tint: 'c9cfc9',
      wear_mask: 'weathered_concrete', opacity: 0.18, feather: 0.4, seed: seed++,
    }));
  }
  // Circuit centre-line dashes, one per asphalt segment.
  for (const road of STORMGLASS_ROADS) {
    panels.push(panel({
      id: `centre-line-${road.id}`, position: [road.x, 0.06, road.z],
      rotation_degrees: [-90, road.yaw, 0], size: [road.plate, 0.45],
      texture: 'hazard_stripes', tint: 'd8d4c2',
    }));
  }
  // Circuit-facing glazing bands on all ten observatory terminals.
  for (const front of STORMGLASS_TERMINAL_FRONTS) {
    panels.push(panel({
      id: `terminal-glazing-${front.id}`, position: [front.x, front.height - 6, front.z],
      rotation_degrees: [0, front.yaw, 0], size: [front.plate, 1.8],
      texture: 'holographic_grid', tint: '9fd2d8',
    }));
  }
  // Counterweight hazard bands on the six buttress faces the driver sees.
  for (const face of STORMGLASS_BUTTRESS_FACES) {
    panels.push(panel({
      id: `buttress-hazard-${face.id}`, position: [face.x, 4.2, face.z],
      rotation_degrees: [0, face.yaw, 0], size: [face.plate, 0.9],
      texture: 'hazard_stripes', tint: 'f0c070',
    }));
  }
  // Gantry walkway plates along the top of the three steel gantries.
  for (const gantry of STORMGLASS_GANTRY_TOPS) {
    panels.push(panel({
      id: `gantry-walk-${gantry.id}`, position: [gantry.x, 24.02, gantry.z],
      rotation_degrees: [-90, gantry.yaw, 0], size: [gantry.plate, 3],
      texture: 'metal_grating', tint: '79868a',
    }));
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
  // --- second pass: the three named districts the circuit runs through -------
  // (worlds/stormglass-causeway.json districts[]), each read on approach.
  signs.push(sign('district-weather-terminal', [-90, 6.5, -112.18], [0, 180, 0], [8, 0.72],
    'GLAZED WEATHER TERMINAL\nSECTORS 0-3, 19-20', fg, bg));
  signs.push(sign('district-freight-bore', [152, 8, 5], [0, -90, 0], [7, 0.72],
    'ARCHED FREIGHT BORE\nSECTORS 4-6', fg, bg));
  signs.push(sign('district-stepped-quay', [39.49, 9, 163.4], [0, 180, 0], [7, 0.72],
    'STEPPED QUAY\nSURGEWORKS', fg, bg));
  return signs;
}

function stormglassPockets() {
  const pockets = [];
  // Sea spray blowing over the seawall on the exposed western straight.
  for (const [x, z] of [[-94, -144], [-7, -136], [-91, -39], [-131, -67]]) {
    pockets.push(pocket(`seawall-spray-${x}`, 'mist', [x, 4.2, z + 3], [8, 4, 6], 'b6ccd2', 10));
  }
  // Storm vents at the barrier gate machinery.
  for (const gate of STORMGLASS_GATES) {
    pockets.push(pocket(`gate-vent-${gate.id}`, 'vent', [gate.x, 25.4, gate.z], [8, 3, 7], 'a9c0c6', 9));
  }
  // Road grit and salt dust along the circuit shoulders.
  for (const [x, z] of [[-90, -130], [-10, -123], [-200, 55], [-77.5, -42.5], [114, 106]]) {
    pockets.push(pocket(`road-grit-${x}-${z}`, 'dust', [x, 0.9, z], [8, 2.4, 8], 'b3ab97', 5));
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
  // Raised toward the profile.gd hard caps (32/96/24/96) by the second pass.
  // Pockets stay at twelve: profile.gd caps that group at twelve outright, with
  // no per-profile budget to raise, so the extra density went into mote counts
  // and volumes instead.
  budgets: {material_variants: 7, panels: 96, signs: 24, motes: 96},
};

// ----------------------------------------------------------- gravemill ------
// --- Foundry anchors, all read off the promoted R7 GLB ------------------------
// The tap catwalk (G4 / grating) is one continuous deck, y+ 7.07..7.33, spanning
// x -100..101 and z -110..-8: a single plate per crossing would repeat the same
// surface, so the crossings below are where the five bunker rows and the three
// gates actually meet the catwalk, x from the G5.bunker.* and gate bboxes.
const GRAVEMILL_CATWALK = [
  [-94, -107.16], [-50, -101], [22, -90.92], [96, -80.56], [134, -75.24],
  [-10, -122.5], [-200, 55], [-77.5, -42.5],
];
// Grain decks (G4 / timber, y 8.8..9.2, x 46.2..88, z -30..-26) on the kiln side.
const GRAVEMILL_GRAIN_DECKS = [[52, 9.2], [64, 9.2], [76, 9.2], [88, 9.2], [46.2, 9.2]];
// Kiln refractory fronts (R6 / refractory, z -29.45, x 45..57, y 0..11): three
// real kiln faces, one per buttress, plus the arch crown at y+ 5.
const GRAVEMILL_KILN_FRONTS = [44, 80, 104];
const GRAVEMILL_KILN_ARCH = [[50.5, 5.02, -29.98], [56.79, 5.02, -29.98]];
// Cooling nave plinth (R6 / plinth, y+ 12, x -90.3..-39.4, z 12.8..40.7) and the
// four pier caps that stand on it (y+ 20, x -92.8/-75.5/-58.1/-40.8 and +33..+41 z).
const GRAVEMILL_NAVE_PIER_CAPS = [
  [-92, 20, 13], [-74.7, 20, 15.4], [-57.3, 20, 17.9], [-40, 20, 20.4],
  [-92, 20, 33], [-74.7, 20, 35.4], [-57.3, 20, 37.9], [-40, 20, 40.4],
];
// Ore-bin surge shells (R6 / ore-shell): the five bunker rows, drum centre and
// the height the shell tops out at.
const GRAVEMILL_ORE_SHELLS = [[-50, 6.05], [22, 8.6], [96, 8.6], [134, 6.05], [-100, 8.6]];
// Crusher / furnace machine faces (R6 / machine): the four crusher drum flanks at
// x -88.9..-87.6 (west headframe) and the assay platform edge at x 60.5.
const GRAVEMILL_MACHINE_FACES = [[-88.9, 21.8, -72.5], [-87.6, 24.1, -72.5], [60.5, 9.4, -6.7]];
// Headframe crossrails (G4 / ribbed): the four z faces at -36.98 and -34.98 carry
// the maintenance-walk markings along x.
const GRAVEMILL_CROSSRAIL_MARKS = [[-72, -36.8, 25], [-48, -36.8, 25], [22, -36.8, 25], [64, -34.8, 25]];
// Ground decks (R6 / ground, y+ 8 and y+ 5.33): the two wide terraces that carry
// the approach to the crusher and the transfer cut.
const GRAVEMILL_GROUND_DECKS = [[-110, 8.1, -60], [-40, 8.1, -60], [30, 8.1, -60], [-140, 5.4, -100], [-40, 5.4, -100]];

// The 37 / 20 / 3 placements author.py already accepted, carried over row for
// row so this pass is additive: every number below is the one the shipped profile
// has emitted since the first dressing pass. Row shape:
//   panel  [id, position, rotation, size, texture, tint, essential, ?wear_mask, ?opacity, ?feather, ?seed]
//   sign   [id, position, rotation, size, text, foreground, background, essential]
//   pocket [id, kind, position, size, color, count]
const GRAVEMILL_PANEL_ROWS = [
  ['crusher--72-abrasion--5', [-76.993761, 4.4, -25.824565], [0, 172.03038960567864, 0], [3.5, 2.6], 'metal', '9b9588', false],
  ['crusher--72-abrasion-0', [-71.993761, 4.4, -25.124565], [0, 172.03038960567864, 0], [3.5, 2.6], 'metal', '9b9588', false],
  ['crusher--72-abrasion-5', [-66.993761, 4.4, -24.424565], [0, 172.03038960567864, 0], [3.5, 2.6], 'metal', '9b9588', false],
  ['crusher--72-grease', [-72.006239, 3.6, -9.035435], [0, -7.96961039432136, 0], [8, 0.8], 'weathered_concrete-worn', '686158', false, 'weathered_concrete', 0.154, 0.4, 610027],
  ['crusher--72-hazard', [-71.993761, 5.4, -25.124565], [0, 172.03038960567864, 0], [7, 0.45], 'hazard_stripes', 'c6ae72', false],
  ['crusher--48-abrasion--5', [-52.993761, 6.08, -15.464565], [0, 172.03038960567864, 0], [3.5, 2.6], 'metal', '9b9588', false],
  ['crusher--48-abrasion-0', [-47.993761, 6.08, -14.764565], [0, 172.03038960567864, 0], [3.5, 2.6], 'metal', '9b9588', false],
  ['crusher--48-abrasion-5', [-42.993761, 6.08, -14.064565], [0, 172.03038960567864, 0], [3.5, 2.6], 'metal', '9b9588', false],
  ['crusher--48-grease', [-48.006239, 5.28, 1.324565], [0, -7.96961039432136, 0], [8, 0.8], 'weathered_concrete-worn', '686158', false, 'weathered_concrete', 0.154, 0.4, 610032],
  ['crusher--48-hazard', [-47.993761, 7.08, -14.764565], [0, 172.03038960567864, 0], [7, 0.45], 'hazard_stripes', 'c6ae72', false],
  ['crusher-back-soot--94', [-93.993761, 3.0, 9.795435], [0, 172.03038960567864, 0], [5, 4], 'weathered_concrete-worn', '8b8173', false, 'weathered_concrete', 0.132, 0.4, 610034],
  ['crusher-back-soot--81', [-80.993761, 3.0, 11.615435], [0, 172.03038960567864, 0], [5, 4], 'weathered_concrete-worn', '8b8173', false, 'weathered_concrete', 0.132, 0.4, 610035],
  ['crusher-back-soot--61', [-60.993761, 3.0, 14.415435], [0, 172.03038960567864, 0], [5, 4], 'weathered_concrete-worn', '8b8173', false, 'weathered_concrete', 0.132, 0.4, 610036],
  ['crusher-back-soot--44', [-43.993761, 3.0, 16.795435], [0, 172.03038960567864, 0], [5, 4], 'weathered_concrete-worn', '8b8173', false, 'weathered_concrete', 0.132, 0.4, 610037],
  ['cooling--84--1-waterline', [-83.993761, 12.8, 17.595435], [0, 172.03038960567864, 0], [5.2, 1.2], 'weathered_concrete-worn', 'aba798', false, 'weathered_concrete', 0.121, 0.4, 610038],
  ['cooling--84--1-vent-grate', [-83.993761, 14.6, 17.595435], [0, 172.03038960567864, 0], [3, 1.3], 'metal_grating', '9b9c95', false],
  ['cooling--84-1-waterline', [-84.006239, 12.8, 30.884565], [0, -7.96961039432136, 0], [5.2, 1.2], 'weathered_concrete-worn', 'aba798', false, 'weathered_concrete', 0.121, 0.4, 610040],
  ['cooling--84-1-vent-grate', [-84.006239, 14.6, 30.884565], [0, -7.96961039432136, 0], [3, 1.3], 'metal_grating', '9b9c95', false],
  ['cooling--48--1-waterline', [-47.993761, 12.8, 22.635435], [0, 172.03038960567864, 0], [5.2, 1.2], 'weathered_concrete-worn', 'aba798', false, 'weathered_concrete', 0.121, 0.4, 610042],
  ['cooling--48--1-vent-grate', [-47.993761, 14.6, 22.635435], [0, 172.03038960567864, 0], [3, 1.3], 'metal_grating', '9b9c95', false],
  ['cooling--48-1-waterline', [-48.006239, 12.8, 35.924565], [0, -7.96961039432136, 0], [5.2, 1.2], 'weathered_concrete-worn', 'aba798', false, 'weathered_concrete', 0.121, 0.4, 610044],
  ['cooling--48-1-vent-grate', [-48.006239, 14.6, 35.924565], [0, -7.96961039432136, 0], [3, 1.3], 'metal_grating', '9b9c95', false],
  ['assay-0-32-enamel', [48.493761, 19.0, 38.834565], [0, -7.96961039432136, 0], [12, 2], 'weathered_concrete', 'c5bdab', false],
  ['assay-0-40-enamel', [48.506239, 19.0, 46.745435], [0, 172.03038960567864, 0], [12, 2], 'weathered_concrete', 'c5bdab', false],
  ['assay-1-32-enamel', [66.993761, 19.0, 41.424565], [0, -7.96961039432136, 0], [15, 2], 'weathered_concrete', 'c5bdab', false],
  ['assay-1-40-enamel', [67.006239, 19.0, 49.335435], [0, 172.03038960567864, 0], [15, 2], 'weathered_concrete', 'c5bdab', false],
  ['assay-2-32-enamel', [84.493761, 19.0, 43.874565], [0, -7.96961039432136, 0], [10, 2], 'weathered_concrete', 'c5bdab', false],
  ['assay-2-40-enamel', [84.506239, 19.0, 51.785435], [0, 172.03038960567864, 0], [10, 2], 'weathered_concrete', 'c5bdab', false],
  ['kiln-44-heat', [44.006239, 6.0, -15.384565], [0, 172.03038960567864, 0], [2.5, 9], 'weathered_concrete-worn', '998473', false, 'weathered_concrete', 0.143, 0.4, 610052],
  ['kiln-44-hazard', [44.006239, 1.5, -15.384565], [0, 172.03038960567864, 0], [2.5, 0.65], 'hazard_stripes', 'd4b578', false],
  ['kiln-80-heat', [80.006239, 6.0, -10.344565], [0, 172.03038960567864, 0], [2.5, 9], 'weathered_concrete-worn', '998473', false, 'weathered_concrete', 0.143, 0.4, 610054],
  ['kiln-80-hazard', [80.006239, 1.5, -10.344565], [0, 172.03038960567864, 0], [2.5, 0.65], 'hazard_stripes', 'd4b578', false],
  ['kiln-104-heat', [104.006239, 6.0, -6.984565], [0, 172.03038960567864, 0], [2.5, 9], 'weathered_concrete-worn', '998473', false, 'weathered_concrete', 0.143, 0.4, 610056],
  ['kiln-104-hazard', [104.006239, 1.5, -6.984565], [0, 172.03038960567864, 0], [2.5, 0.65], 'hazard_stripes', 'd4b578', false],
  ['kiln-rear-52-soot', [52.006239, 4.0, 29.235435], [0, 172.03038960567864, 0], [9, 6], 'weathered_concrete-worn', '8b8277', false, 'weathered_concrete', 0.132, 0.4, 610058],
  ['kiln-rear-72-soot', [72.006239, 4.0, 32.035435], [0, 172.03038960567864, 0], [9, 6], 'weathered_concrete-worn', '8b8277', false, 'weathered_concrete', 0.132, 0.4, 610059],
  ['kiln-rear-94-soot', [94.006239, 4.0, 35.115435], [0, 172.03038960567864, 0], [9, 6], 'weathered_concrete-worn', '8b8277', false, 'weathered_concrete', 0.132, 0.4, 610060],
];

const GRAVEMILL_SIGN_ROWS = [
  ['crusher--72-isolate', [-71.990988, 6.4, -25.144372], [0, 172.03038960567864, 0], [6, 0.9], 'ISOLATE / PINCH', 'e8e3cf', '554532', true],
  ['crusher--48-isolate', [-47.990988, 8.08, -14.784372], [0, 172.03038960567864, 0], [6, 0.9], 'ISOLATE / PINCH', 'e8e3cf', '554532', true],
  ['crusher-sector', [-93.990988, 7.0, -65.224372], [0, 172.03038960567864, 0], [9, 1.3], 'CRUSHER / C1', 'e8e3cf', '253239', true],
  ['cooling--84--1-circuit', [-83.990988, 15.65, 17.575628], [0, 172.03038960567864, 0], [4.8, 0.5], 'C2 / RETURN', 'e8e3cf', '253239', true],
  ['cooling--84-1-circuit', [-84.009012, 15.65, 30.904372], [0, -7.96961039432136, 0], [4.8, 0.5], 'C2 / RETURN', 'e8e3cf', '253239', true],
  ['cooling--48--1-circuit', [-47.990988, 15.65, 22.615628], [0, 172.03038960567864, 0], [4.8, 0.5], 'C2 / RETURN', 'e8e3cf', '253239', true],
  ['cooling--48-1-circuit', [-48.009012, 15.65, 35.944372], [0, -7.96961039432136, 0], [4.8, 0.5], 'C2 / RETURN', 'e8e3cf', '253239', true],
  ['cooling-sector', [-72.990988, 18.4, 15.715628], [0, 172.03038960567864, 0], [5, 1.0], 'COOLING / C2', 'e8e3cf', '253239', true],
  ['assay-0-32-station', [48.490988, 19.0, 38.854372], [0, -7.96961039432136, 0], [7.5, 0.85], 'A3 / SAMPLE 01', 'e8e3cf', '365358', true],
  ['assay-0-40-station', [48.509012, 19.0, 46.725628], [0, 172.03038960567864, 0], [7.5, 0.85], 'A3 / SAMPLE 01', 'e8e3cf', '365358', true],
  ['assay-1-32-station', [66.990988, 19.0, 41.444372], [0, -7.96961039432136, 0], [7.5, 0.85], 'A3 / SAMPLE 02', 'e8e3cf', '365358', true],
  ['assay-1-40-station', [67.009012, 19.0, 49.315628], [0, 172.03038960567864, 0], [7.5, 0.85], 'A3 / SAMPLE 02', 'e8e3cf', '365358', true],
  ['assay-2-32-station', [84.490988, 19.0, 43.894372], [0, -7.96961039432136, 0], [7.5, 0.85], 'A3 / SAMPLE 03', 'e8e3cf', '365358', true],
  ['assay-2-40-station', [84.509012, 19.0, 51.765628], [0, 172.03038960567864, 0], [7.5, 0.85], 'A3 / SAMPLE 03', 'e8e3cf', '365358', true],
  ['assay-sector', [73.009012, 18.5, 36.155628], [0, 172.03038960567864, 0], [5, 1.0], 'ASSAY / A3', 'e8e3cf', '253239', true],
  ['kiln-sector', [74.009012, 11.0, 32.295628], [0, 172.03038960567864, 0], [10, 1.3], 'FURNACE / F4', 'e8e3cf', '253239', true],
  ['kiln-danger', [56.009012, 6.9, 29.775628], [0, 172.03038960567864, 0], [11, 1.0], 'HOT STOCK / KEEP CLEAR', 'e8e3cf', '554532', true],
  ['transfer-sector', [0.021339, 6.0, -77.872718], [0, 160.835249245064, 0], [12, 1.0], 'TRANSFER / T0', 'e8e3cf', '253239', true],
  ['service--132', [-131.990988, 2.0, -116.544372], [0, 172.03038960567864, 0], [7.5, 0.8], 'SERVICE / LOOP', 'e8e3cf', '253239', true],
  ['service-134', [134.009012, 2.0, -79.304372], [0, 172.03038960567864, 0], [7.5, 0.8], 'SERVICE / LOOP', 'e8e3cf', '253239', true],
];

const GRAVEMILL_POCKET_ROWS = [
  ['crusher-ore-dust', 'dust', [-72, 25.3, -17.08], [3, 1, 2], 'b1a58e', 12],
  ['kiln-hot-ash', 'ash', [64, 33, 0.96], [4, 2, 4], 'bdb1a2', 12],
  ['cooling-return-vent', 'vent', [-84, 18, 18.74], [3, 2, 2], 'bdcfcb', 8],
];

function gravemillPanels() {
  const panels = [];
  let seed = 610300;
  // The 37 accepted first-pass panels, byte-identical.
  for (const [id, position, rotation, size, texture, tint, essential, wear, opacity, feather, panelSeed] of GRAVEMILL_PANEL_ROWS) {
    panels.push(panel({
      id, position, rotation_degrees: rotation, size, texture, tint, essential,
      ...(wear ? {wear_mask: wear, opacity, feather, seed: panelSeed} : {}),
    }));
  }
  // --- R7 pass: the ten promoted roles finally get dressed, not just covered ---
  // Tap catwalk walking plates (G4 / grating, flat on the deck).
  for (const [x, z] of GRAVEMILL_CATWALK) {
    panels.push(panel({
      id: `tap-catwalk-plate-${x}-${z}`, position: [x, 7.35, z], rotation_degrees: FACE_UP,
      size: [4, 3], texture: 'metal_grating', normal: 'baked:metal_grating', tint: '8d9298',
    }));
  }
  // Grain deck boards (G4 / timber, flat on the 9.2 m deck).
  for (const [x, y] of GRAVEMILL_GRAIN_DECKS) {
    panels.push(panel({
      id: `grain-deck-board-${x}`, position: [x, y + 0.02, -28], rotation_degrees: FACE_UP,
      size: [6, 3.4], texture: 'rough_stucco-weathered', tint: '7a6042',
      wear_mask: 'rough_stucco', opacity: 0.18, feather: 0.4, seed: seed++,
    }));
  }
  // Kiln refractory fronts: a heat-shadow band and a hazard band on each of the
  // three kiln faces, plus the arch crown.
  for (const x of GRAVEMILL_KILN_FRONTS) {
    panels.push(panel({
      id: `kiln-refractory-heat-${x}`, position: [x, 6, -29.63], rotation_degrees: [0, 0, 0],
      size: [2.5, 9], texture: 'weathered_concrete-worn', tint: '998473',
      wear_mask: 'weathered_concrete', opacity: 0.16, feather: 0.4, seed: seed++,
    }));
    panels.push(panel({
      id: `kiln-refractory-hazard-${x}`, position: [x, 1.5, -29.63], rotation_degrees: [0, 0, 0],
      size: [2.5, 0.65], texture: 'hazard_stripes', tint: 'd4b578',
    }));
  }
  for (const [x, y, z] of GRAVEMILL_KILN_ARCH) {
    panels.push(panel({
      id: `kiln-arch-crown-${x}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [4, 1], texture: 'weathered_concrete-worn', tint: '8f7f6c',
      wear_mask: 'weathered_concrete', opacity: 0.14, feather: 0.4, seed: seed++,
    }));
  }
  // Cooling nave pier caps: soot on all eight caps the nave roof stands on.
  for (const [x, y, z] of GRAVEMILL_NAVE_PIER_CAPS) {
    panels.push(panel({
      id: `nave-pier-soot-${x}-${z}`, position: [x, y + 0.02, z], rotation_degrees: FACE_UP,
      size: [1.4, 1.5], texture: 'weathered_concrete-worn', tint: '8b8173',
      wear_mask: 'weathered_concrete', opacity: 0.16, feather: 0.4, seed: seed++,
    }));
  }
  // Ore-bin shell collars: verdigris plates around each surge shell mouth.
  for (const [x, y] of GRAVEMILL_ORE_SHELLS) {
    panels.push(panel({
      id: `ore-shell-collar-${x}`, position: [x, y + 0.05, -90.92], rotation_degrees: FACE_UP,
      size: [5, 5], texture: 'metal-oxide', tint: '7f8a7c',
    }));
  }
  // Machine faces: brushed access plates on the crusher drum flanks and the assay
  // platform edge, offset off the face along the direction each one faces.
  for (const [x, y, z] of GRAVEMILL_MACHINE_FACES) {
    panels.push(panel({
      id: `machine-access-${x}`, position: [x, y, z], rotation_degrees: [0, x < 0 ? -90 : 90, 0],
      size: [3.5, 2.4], texture: 'brushed_metal', normal: 'baked:metal', tint: '9b9588',
    }));
  }
  // Headframe crossrail marks: hazard bands on the four maintenance-walk faces.
  for (const [x, z, y] of GRAVEMILL_CROSSRAIL_MARKS) {
    panels.push(panel({
      id: `crossrail-mark-${x}-${z}`, position: [x, y, z], rotation_degrees: [0, 0, 0],
      size: [8, 0.45], texture: 'hazard_stripes', tint: 'c6ae72',
    }));
  }
  // Ground decks: grit scars where the approach runs onto each terrace.
  for (const [x, y, z] of GRAVEMILL_GROUND_DECKS) {
    panels.push(panel({
      id: `ground-scuff-${x}-${z}`, position: [x, y, z], rotation_degrees: FACE_UP,
      size: [9, 6], texture: 'weathered_concrete-worn', tint: '86827a',
      wear_mask: 'weathered_concrete', opacity: 0.15, feather: 0.4, seed: seed++,
    }));
  }
  return panels;
}

function gravemillSigns() {
  const signs = [];
  const fg = 'e8e3cf', bg = '253239';
  // The 20 accepted first-pass signs, byte-identical.
  for (const [id, position, rotation, size, text, foreground, background, essential] of GRAVEMILL_SIGN_ROWS) {
    signs.push(sign(id, position, rotation, size, text, foreground, background, essential));
  }
  // --- R7 pass: four wayfinding boards, the exact room the sign cap leaves ----
  // 20 accepted + 4 = the profile.gd hard cap of 24, so these four are chosen to
  // name the newly dressed roles rather than repeat a district already labelled:
  // the tap catwalk at its north and south ends, and the two hottest kiln faces.
  // Ids are prefixed by role so they cannot collide with the panel families.
  signs.push(sign('tap-caution-north', [-94, 8.6, -108.86], [0, 0, 0], [5.4, 0.8],
    'TAP WALKWAY\nMIND THE GRATE', fg, bg, true));
  signs.push(sign('tap-caution-south', [134, 8.6, -76.94], [0, 0, 0], [5.4, 0.8],
    'TAP WALKWAY\nMIND THE GRATE', fg, bg, true));
  for (const x of GRAVEMILL_KILN_FRONTS.slice(0, 2)) {
    signs.push(sign(`kiln-heat-board-${x}`, [x, 9.6, -29.75], [0, 0, 0], [2.5, 0.8],
      'HOT / KEEP OFF', fg, '554532', true));
  }
  return signs;
}

function gravemillPockets() {
  const pockets = [
    // The 3 accepted first-pass pockets, byte-identical.
    ...GRAVEMILL_POCKET_ROWS.map(([id, kind, position, size, color, count]) =>
      pocket(id, kind, position, size, color, count)),
    // R7 pass: mote volumes over the newly dressed decks and faces, all above
    // machinery so they stay outside eye-height projectile lines as the first
    // three were.
    pocket('catwalk-dust-north', 'dust', [-94, 9.4, -107.16], [6, 2, 6], 'b1a58e', 8),
    pocket('catwalk-dust-south', 'dust', [134, 9.4, -75.24], [6, 2, 6], 'b1a58e', 8),
    pocket('ore-shell-dust-22', 'dust', [22, 10.6, -90.92], [6, 2, 6], 'b6ab97', 7),
    pocket('ore-shell-dust-134', 'dust', [134, 8.1, -75.24], [6, 2, 6], 'b6ab97', 7),
    pocket('nave-plinth-vent', 'vent', [-65, 14.4, 26], [8, 2.6, 8], 'bdcfcb', 8),
    pocket('kiln-arch-vent', 'vent', [50.5, 6.6, -29.98], [5, 2, 4], 'bdb1a2', 7),
  ];
  return pockets;
}
// Foundry R7 promoted ten finish-role materials that the pre-R7 profile had
// never seen, so the binder reported incomplete_coverage with ten unmatched
// selectors. Every entry below is read out of the promoted GLB: the selector
// names come from its glTF materials array, and the R6/G4 role bindings
// (resource, metallic, tile density) come from revision6/bindings.json and
// revision5/material-lineage.json.
const GRAVEMILL_R7_PALETTE = {
  machine: '6e737a', roof: '7b8288', wall: '8b857a', plinth: '6f6a62',
  refractory: '8d5238', oreShell: '6f6350', ground: '7a766c',
  ribbed: '767c82', grating: '71787d', timber: '8a6b48',
};
// The seven GM / roles author.py already accepted, re-emitted unchanged so the
// existing 37 panels, 20 signs and 3 pockets keep their exact numbers.
const GRAVEMILL_LEGACY_MATERIALS = [
  ['GM / soot', 'pearl-ceramic', 'cast', '777872', 1.35, 0.79, 1.25, 0.24, 'organic', 0.3, 610240],
  ['GM / mineral', 'pearl-ceramic', 'worn', 'b5ab97', 1.15, 0.91, 1.35, 0.35, 'organic', 0.3, 610241],
  ['GM / copper', 'oxidised-copper', 'default', '8b9682', 1.2, 0.67, 1.35, 0.22, 'organic', 0.3, 610242],
  ['GM / brass', 'brushed-alloy', 'default', 'a78a58', 1.4, 0.55, 1.3, 0.18, 'manufactured', 0.12, 610243],
  ['GM / ore', 'pearl-ceramic', 'worn', 'a7856c', 1.25, 0.89, 1.35, 0.32, 'organic', 0.3, 610244],
  ['GM / chalk', 'pearl-ceramic', 'cast', 'c4bcaa', 1.4, 0.82, 1.2, 0.22, 'organic', 0.3, 610246],
  ['GM / cooling-floor', 'pearl-ceramic', 'cast', '93948b', 1.2, 0.78, 1.3, 0.3, 'organic', 0.3, 610247],
];
// The ten promoted R7 roles. Family/variant is chosen from each role's own
// authored resource: forge-steel and ribbed-steel are machined/alloy stock
// (brushed-alloy), aggregate and cast-seams are cast mineral (pearl-ceramic),
// terracotta is fired brick (pearl-ceramic worn), oxidized-iron is ore
// (oxidised-copper), iron-grate is grating (brushed-alloy grating), and
// timber-weather is the one organic built surface (regolith verdant is the
// only wood-adjacent read in the library, at low texture strength).
const GRAVEMILL_R7_ROLES = [
  ['R6 / machine', 'brushed-alloy', 'plate', GRAVEMILL_R7_PALETTE.machine, 1.1, 0.46, 1.9, 0.3, 0.42, 0.36],
  ['R6 / roof', 'hazard-industrial', 'corrugated', GRAVEMILL_R7_PALETTE.roof, 1.0, 0.42, 1.4, 0.34, 0.3, 0.34],
  ['R6 / wall', 'pearl-ceramic', 'cast', GRAVEMILL_R7_PALETTE.wall, 0.35, 0.85, 1.25, 0.26, 0.02, 0.22],
  ['R6 / plinth', 'pearl-ceramic', 'cast', GRAVEMILL_R7_PALETTE.plinth, 0.35, 0.9, 1.2, 0.24, 0.02, 0.2],
  ['R6 / refractory', 'pearl-ceramic', 'worn', GRAVEMILL_R7_PALETTE.refractory, 0.5, 0.88, 1.35, 0.32, 0.02, 0.22],
  ['R6 / ore-shell', 'oxidised-copper', 'pitted', GRAVEMILL_R7_PALETTE.oreShell, 0.7, 0.7, 1.6, 0.3, 0.25, 0.3],
  ['R6 / ground', 'regolith', 'scoured', GRAVEMILL_R7_PALETTE.ground, 0.3, 0.93, 1.6, 0.3, 0.0, 0.2],
  ['G4 / ribbed', 'brushed-alloy', 'plate', GRAVEMILL_R7_PALETTE.ribbed, 1.0, 0.44, 1.8, 0.3, 0.38, 0.34],
  ['G4 / grating', 'brushed-alloy', 'grating', GRAVEMILL_R7_PALETTE.grating, 1.0, 0.46, 1.7, 0.28, 0.4, 0.36],
  ['G4 / timber', 'regolith', 'verdant', GRAVEMILL_R7_PALETTE.timber, 0.9, 0.9, 1.2, 0.18, 0.0, 0.2],
];

const gravemill = {
  version: 1,
  map_id: 'gravemill-foundry',
  geometry_hash: '8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f',
  materials: [
    ...GRAVEMILL_LEGACY_MATERIALS.map(([source, family, variant, tint, density, roughness,
      gain, strength, mode, variation, seed]) => material(source, family, base(family, variant, tint, {
        tiles_per_metre: density, roughness, albedo_gain: gain, texture_strength: strength,
        texture_saturation: source === 'GM / copper' ? 0.08 : 0,
        normal_strength: source === 'GM / brass' ? 0.06 : 0.1,
        metallic: source === 'GM / copper' ? 0.38 : (source === 'GM / brass' ? 0.46 : 0.02),
        specular_strength: 0.22, detail_strength: 0.08, ao_strength: 0.16,
        roughness_variation: 0.1, glow: false, lut_gain: 0, pulse_speed: 0, pulse_depth: 0,
      }, seed, {variation_mode: mode, variation_strength: variation}))),
    // The ten promoted R7 roles: response floors match the seven above (no
    // accent gain, no phase pulse), so no R6/G4 surface invents an emission the
    // authored art does not carry.
    ...GRAVEMILL_R7_ROLES.map(([source, family, variant, tint, density, roughness, gain,
      strength, metallic, specular], i) => material(source, family, base(family, variant, tint, {
        tiles_per_metre: density, roughness, albedo_gain: gain, texture_strength: strength,
        texture_saturation: 0, normal_strength: 0.1, metallic, specular_strength: specular,
        detail_strength: 0.08, ao_strength: 0.16, roughness_variation: 0.1,
        glow: false, lut_gain: 0, pulse_speed: 0, pulse_depth: 0,
      }, 610280 + i,
      // Manufactured roles (alloy stock, roof, grate) get the private variation
      // off; the mineral and timber roles keep it on, matching the convention the
      // other three maps already use. This has to go through base()'s last
      // argument rather than the response object: response is spread *before* the
      // private-variation defaults, so keys set there are silently overwritten.
      (metallic > 0.1 || source === 'R6 / roof')
        ? {variation_mode: 'manufactured', variation_strength: 0.12}
        : {variation_mode: 'organic', variation_strength: 0.3}))),
  ],
  panels: gravemillPanels(),
  signs: gravemillSigns(),
  pockets: gravemillPockets(),
  // GM / orange is the authored luminaire batch (emissiveFactor [1, .2375, .03125],
  // emissiveStrength 1.6, 328 triangles in one primitive). A triplanar finish would
  // disable culling and expose the mirrored backs of those lamp housings, so the
  // imported material stays.
  preserve_materials: ['GM / orange'],
  budgets: {material_variants: 17, panels: 96, signs: 24, motes: 96},
};

const PROFILES = {
  'vesper-viaduct': vesper,
  'abyssal-pressureworks': abyssal,
  'stormglass-causeway': stormglass,
  'gravemill-foundry': gravemill,
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
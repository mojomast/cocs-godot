// Abyssal corrective service-cave candidate, forked from frozen revision 2.
// Source-only. Imports the accepted base recipe; never rewrites the frozen
// authority JSON, the base recipe module or the runtime profile in place.
//
// Added walkable surfaces are XZ-disjoint from every existing walkable deck and
// at a single height each (highest-floor semantics stay unambiguous). The two
// terraces connect through the row-0 observation bays by removing only the low
// sill panel there (the header and non-blocking glazing stay). Scenic roofs on
// six vessels are marked for replacement so the Blender builder emits three
// distinct district forms instead of six clones; the base roof facets are
// non-walkable, so traversal is unchanged by that substitution.
import {recipe as base, ID} from '../recipe.mjs';
import {readFileSync} from 'node:fs';
export {ID};
export const LAYOUT_REVISION = 2;
export const SERVICE_CAVE = JSON.parse(readFileSync(new URL('./service_cave.json', import.meta.url), 'utf8'));
export const REPLACED_ROOF_HOSTS = ['vessel-0-0', 'vessel-0-2', 'vessel-0-3', 'vessel-1-1', 'vessel-1-3', 'vessel-2-0'];
// Low sill panels removed to open the two service bays; header, jambs and the
// non-blocking glazing remain. Never a general shell removal.
export const OPENED_BAYS = ['vessel-0-0-window-sill-', 'vessel-0-3-window-sill-'];

const fan = vertices => Array.from({length: vertices.length - 2}, (_, i) => [0, i + 1, i + 2]);
const surface = (m, id, vertices, material, walkable) =>
  m.terrain.surfaces.push({id, material, walkable, vertices, triangles: fan(vertices)});
const retain = (m, id, x0, z0, x1, z1, yBottom, yTop, material = 'basalt-strata') => {
  const vertices = [[x0, yBottom, z0], [x1, yBottom, z1], [x1, yTop, z1], [x0, yTop, z0]];
  for (let i = 1; i < vertices.length - 1; i++) m.terrain.walls.push({id: id + '-' + i, material, vertices: [vertices[0], vertices[i], vertices[i + 1]]});
};
const rect = (cx, cz, w, d, y) => [[cx - w / 2, y, cz + d / 2], [cx + w / 2, y, cz + d / 2], [cx + w / 2, y, cz - d / 2], [cx - w / 2, y, cz - d / 2]];
const deck = (m, id, cx, cz, w, d, y, material, walkable = true) => {
  surface(m, id, rect(cx, cz, w, d, y), material, walkable);
  return {id, x: cx, z: cz, w, d, y};
};
// Ramp quad; low edge (zLow) at yLow, high edge (zHigh) at yHigh.
const ramp = (m, id, xMin, xMax, zLow, zHigh, yLow, yHigh, material) =>
  surface(m, id, [[xMin, yHigh, zHigh], [xMax, yHigh, zHigh], [xMax, yLow, zLow], [xMin, yLow, zLow]], material, true);

export function recipe() {
  const m = base();

  // 1. Open exactly the two low window sills that lead onto the new terraces.
  m.terrain.walls = m.terrain.walls.filter(w => !OPENED_BAYS.some(prefix => w.id.startsWith(prefix)));

  // 2. Six cloned vessel roofs are marked for replacement by three district forms.
  const hosts = new Set(REPLACED_ROOF_HOSTS);
  m.terrain.surfaces = m.terrain.surfaces.filter(s =>
    ![...hosts].some(id => s.id.startsWith(id + '-roof-facet-') || s.id === id + '-crown'));

  // 3. Bounded dry-service terraces + a sunken SE utility pocket.
  const [swForm, seForm] = SERVICE_CAVE.forms;
  const sw = deck(m, ...['id', 'x', 'z', 'w', 'd', 'y'].map(k => swForm.deck[k]), 'cast-seams');
  deck(m, 'service-bridge-sw', -94, -89.5, 36, 3, 6, 'cast-seams');
  const se = deck(m, ...['id', 'x', 'z', 'w', 'd', 'y'].map(k => seForm.deck[k]), 'cast-seams');
  deck(m, 'service-bridge-se', 91, -81.5, 24, 7, 0, 'cast-seams');
  const pocket = deck(m, 'utility-pocket-se', 91, -105, 24, 8, -4, 'deep-silt');
  ramp(m, 'utility-ramp-se', 85, 97, -101, -95, -4, 0, 'deep-silt');

  // 4. Retaining/wall structure with openings only at the bay connections.
  retain(m, 'service-terrace-sw.west', sw.x - sw.w / 2, sw.z - sw.d / 2, sw.x - sw.w / 2, sw.z + sw.d / 2, sw.y, sw.y + 4);
  retain(m, 'service-terrace-sw.south', sw.x - sw.w / 2, sw.z - sw.d / 2, sw.x + sw.w / 2, sw.z - sw.d / 2, sw.y, sw.y + 4);
  retain(m, 'service-terrace-sw.east', sw.x + sw.w / 2, sw.z - sw.d / 2, sw.x + sw.w / 2, sw.z + sw.d / 2, sw.y, sw.y + 4);
  retain(m, 'service-terrace-se.west', se.x - se.w / 2, se.z - se.d / 2, se.x - se.w / 2, se.z + se.d / 2, se.y, se.y + 4);
  retain(m, 'service-terrace-se.east', se.x + se.w / 2, se.z - se.d / 2, se.x + se.w / 2, se.z + se.d / 2, se.y, se.y + 4);
  retain(m, 'utility-pocket-se.west', 79, -109, 79, -101, -4, 0);
  retain(m, 'utility-pocket-se.south', 91, -109, 103, -109, -4, 0);
  retain(m, 'utility-pocket-se.east', 103, -109, 103, -101, -4, 0);

  // 5. Route + authored navigation seeds across the new traversal.
  const route = (id, width, points) => {
    m.routes.push({id, width, points});
    for (let i = 1; i < points.length; i++) {
      const a = points[i - 1], b = points[i], n = Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / 3);
      for (let j = 0; j <= n; j++) m.navNodes.push({x: a[0] + (b[0] - a[0]) * j / n, z: a[1] + (b[1] - a[1]) * j / n});
    }
  };
  route('service-loop-southwest', 6, [[-94, -86], [-94, -96], [-108, -96], [-94, -96], [-76, -96]]);
  route('service-loop-southeast', 5, [[91, -78], [91, -90], [83, -90], [99, -90], [91, -90], [91, -105]]);

  // 6. Versioned revision metadata for the Blender builder and source tests.
  m.art.revision2 = {
    layoutRevision: LAYOUT_REVISION,
    authorityScope: 'bounded-dry-service-terraces',
    openedBays: [...OPENED_BAYS],
    replacedRoofHosts: [...REPLACED_ROOF_HOSTS],
    districts: ['terraced-laboratories', 'pump-energy', 'residential-operations'],
    decks: [sw, se, pocket].map(d => ({...d, nontraversal: false})),
    exteriorServiceCave: SERVICE_CAVE.forms.map(f => ({id: f.id, retainedSide: f.retainedSide, nontraversal: true})),
    layoutModule: 'tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective/layout.py'
  };
  m.design = {...(m.design || {}), walkableRelief: Math.max(24, Number(m.design?.walkableRelief) || 0)};
  return m;
}

// Stormglass revision 2 — coastal scenic relief and distinct harbour structures.
// Source-only. Imports the accepted base recipe and adds an *art-only* scenic
// layout. The 28 m flat Puma road, barriers, race gates, collision surfaces and
// navigation are byte-for-byte the accepted base: zero drivable relief is
// retained truthfully. No mode changes; exactly `puma-race` stays registered.
import {makeStormglass, ID} from '../recipe.mjs';
export {ID};
export const LAYOUT_REVISION = 2;
export const SCENIC_CLASSES = ['seawall', 'grandstand', 'cliff-stair', 'checkpoint-arch', 'lighthouse', 'quay-crane', 'terminal-facade'];

const unit = (x, z) => { const d = Math.hypot(x, z); return {x: x / d, z: z / d}; };

export function recipe() {
  const m = makeStormglass();
  const line = m.race.centerline;
  const tangents = line.map((a, i) => { const b = line[(i + 1) % line.length]; return unit(b.x - a.x, b.z - a.z); });
  // Same mitred lateral frame the base road uses (outer is sea side, inner city).
  const at = (i, t, lateral) => {
    const a = line[i], b = line[(i + 1) % line.length], u = tangents[i];
    return {x: a.x + (b.x - a.x) * t - u.z * lateral, z: a.z + (b.z - a.z) * t + u.x * lateral,
      heading: Math.atan2(u.x, u.z)};
  };
  const anchor = (id, cls, i, t, lateral, extra = {}) => ({id, cls, ...at(i, t, lateral), lateral, ...extra});

  // All scenery sits at |lateral| >= 16.5 m, i.e. outside the 14 m barrier and
  // the 28 m road envelope; it carries no collision, floor or navigation.
  const seawallHeights = [4, 6, 8, 10, 12];
  const seawalls = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20].map((i, k) =>
    anchor(`seawall-${i}`, 'seawall', i, 0.5, 17 + (k % 2) * 3, {height: seawallHeights[k % seawallHeights.length], buttress: k % 3 === 0}));
  const grandstands = [2, 8, 13, 19].map((i, k) => anchor(`grandstand-${i}`, 'grandstand', i, 0.5, -19 - (k % 2) * 3, {tiers: 4 + k}));
  const cliffs = [3, 9, 15, 20].map((i, k) => anchor(`cliff-${i}`, 'cliff-stair', i, 0.35 + 0.3 * (k % 2), 30 + (k % 3) * 6, {flights: 3 + (k % 3), drop: 8 + k * 2}));
  const gates = [1, 14, 18].map((i, k) => anchor(`checkpoint-arch-${i}`, 'checkpoint-arch', i, 0.5, 0, {variant: k, span: 30, clearHeight: 10}));
  const lighthouse = anchor('lighthouse', 'lighthouse', 20, 0.85, 34, {height: 34});
  const cranes = [8, 12, 16].map((i, k) => anchor(`quay-crane-${i}`, 'quay-crane', i, 0.5, 20 + k * 2, {variant: k, boom: 18 - k * 3}));
  const facades = [0, 1, 19, 20].map((i, k) => anchor(`terminal-facade-${i}`, 'terminal-facade', i, 0.6, -26 - (k % 2) * 4, {variant: k % 3, bays: 3 + (k % 2)}));

  m.art.revision2 = {
    layoutRevision: LAYOUT_REVISION,
    nontraversal: true,
    scenicClasses: [...SCENIC_CLASSES],
    roadWidth: m.metrics.roadWidth,
    roadRelief: m.metrics.roadRelief,
    scenery: {seawalls, grandstands, cliffs, gates, lighthouse, cranes, facades},
    layoutModule: 'tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/layout.py'
  };
  return m;
}

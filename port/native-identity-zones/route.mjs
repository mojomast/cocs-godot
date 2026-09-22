// Launcher-facing contract for the identity zone route.
//
// The lead owns the common launcher/package tables; this module is the single
// description of what this route needs, so a launcher copy cannot drift from
// the authority or the scene. Everything is static data plus the two owned
// entry points (authority factory, scene path).
import {createIdentityZoneAuthority} from './authority.mjs';
import {IDENTITY_ZONE_IDS, IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE} from './catalog.mjs';
import {identityTeamPool} from './match.mjs';
import {routeBetween} from './fixtures.mjs';

export const IDENTITY_ZONE_ROUTE = Object.freeze({
  experience: 'identity-zones',
  mapId: IDENTITY_ZONE_MAP_ID,
  mode: IDENTITY_ZONE_MODE,
  scene: 'res://native_arenas/identity_zone_demo.tscn',
  endpointPath: '/native-zones',
  authority: createIdentityZoneAuthority,
  limits: Object.freeze({bots:Object.freeze([0, 7]), seconds:Object.freeze([60, 900]), score:Object.freeze([1, 900])}),
});

/** Every authored team spawn has a supported ground route to every zone.
 * Returns the route table the graphical driver consumes.
 */
export function planZoneRoutes(arena) {
  const zones = arena.objectiveZones.map((zone, index) => ({id:IDENTITY_ZONE_IDS[index],
    x:zone.x, z:zone.z, radius:zone.radius, y:zone.y}));
  const routes = [];
  for (const team of [0, 1]) {
    for (const spawnPoint of identityTeamPool(arena, team)) {
      for (const zone of zones) {
        let waypoints;
        try { waypoints = routeBetween(arena, spawnPoint, [zone.x, zone.z]); }
        catch { waypoints = [[zone.x, zone.z]]; }
        routes.push({team, zone:zone.id, start:spawnPoint, waypoints:waypoints.map(point => [point[0], point[1]])});
      }
    }
  }
  return {mapId:IDENTITY_ZONE_MAP_ID, mode:IDENTITY_ZONE_MODE, zones, routes};
}

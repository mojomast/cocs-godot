// Launcher-facing route contract: the values the lead's launcher/package
// tables must carry, the scene constants they must agree with, and the route
// table the graphical acceptance depends on.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {readNativeArena} from '../../native-arenas/schema.mjs';
import {IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE} from '../catalog.mjs';
import {IDENTITY_ZONE_ROUTE, planZoneRoutes} from '../route.mjs';

const MAP = IDENTITY_ZONE_MAP_ID;

test('launcher route contract matches the composition scene and the authority', () => {
  assert.equal(IDENTITY_ZONE_ROUTE.experience, 'identity-zones');
  assert.equal(IDENTITY_ZONE_ROUTE.mapId, MAP);
  assert.equal(IDENTITY_ZONE_ROUTE.mode, IDENTITY_ZONE_MODE);
  assert.equal(IDENTITY_ZONE_ROUTE.scene, 'res://native_arenas/identity_zone_demo.tscn');
  assert.equal(IDENTITY_ZONE_ROUTE.endpointPath, '/native-zones');
  assert.deepEqual(IDENTITY_ZONE_ROUTE.limits.bots, [0, 7]);
  assert.deepEqual(IDENTITY_ZONE_ROUTE.limits.seconds, [60, 900]);
  assert.deepEqual(IDENTITY_ZONE_ROUTE.limits.score, [1, 900]);
  assert.equal(typeof IDENTITY_ZONE_ROUTE.authority, 'function');
  const scene = readFileSync('godot/native_arenas/identity_zone_demo.gd', 'utf8');
  assert.match(scene, /const MAP_ID := "vermilion-fold"/);
  assert.match(scene, /const MODE := "domination"/);
  assert.match(scene, /const BOT_RANGE := Vector2i\(0, 7\)/);
  assert.match(scene, /const SECONDS_RANGE := Vector2i\(60, 900\)/);
  assert.match(scene, /const SCORE_RANGE := Vector2i\(1, 900\)/);
  assert.match(scene, new RegExp(`/native-zones\\|\/`), 'scene accepts the owned endpoint path');
});

test('every authored team spawn routes to every zone, mirrored in length', () => {
  const data = readNativeArena(MAP);
  const table = planZoneRoutes(data.arena);
  assert.equal(table.routes.length, 18);
  for (const zone of table.zones) {
    for (const team of [0, 1]) {
      const rows = table.routes.filter(route => route.zone === zone.id && route.team === team);
      assert.equal(rows.length, 3);
      for (const row of rows) {
        assert.ok(row.waypoints.length > 0, JSON.stringify(row));
        const last = row.waypoints.at(-1);
        assert.ok(Math.hypot(last[0] - zone.x, last[1] - zone.z) <= zone.radius, `route ends inside ${zone.id}`);
      }
      const west = rows.map(row => routeLength(row)).sort((a, b) => a - b);
      const mirror = planZoneRoutes(data.arena).routes
        .filter(route => route.zone === zone.id && route.team === 1 - team)
        .map(row => routeLength(row)).sort((a, b) => a - b);
      // Both authored pools are x-mirrored, so the two teams' route lengths are
      // identical point by point; a drift here means the map lost its symmetry.
      west.forEach((length, index) => assert.ok(Math.abs(length - mirror[index]) < 1e-6));
    }
  }
});
const routeLength = row => {
  let length = 0, previous = row.start;
  for (const point of row.waypoints) { length += Math.hypot(point[0] - previous[0], point[1] - previous[1]); previous = point; }
  return length;
};

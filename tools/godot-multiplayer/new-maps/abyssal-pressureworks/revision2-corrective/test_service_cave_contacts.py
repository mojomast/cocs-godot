"""Source-only P1 reproduction and exact XZ separation for corrected solid forms.

Frozen T GLB is an archival failure fixture; current layout/authority are a new
candidate identity and cannot acquire native acceptance from these checks.
"""
import hashlib
import json
import math
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tools/map-variety-support'))
import layout
import geometry
from service_cave_contacts import T_GLB, glb_triangles, segment_hits, triangles_from_authority, triangles_from_specs


def point_segment_distance(point, a, b):
    delta = [b[i] - a[i] for i in (0, 1)]
    length = sum(d * d for d in delta)
    t = max(0, min(1, sum((point[i] - a[i]) * delta[i] for i in (0, 1)) / length)) if length else 0
    return math.dist(point, [a[i] + t * delta[i] for i in (0, 1)])


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def polygons_distance(first, second):
    for poly, other in ((first, second), (second, first)):
        # Convex, independently of winding.
        for point in poly:
            sides = [cross(other[i], other[(i + 1) % len(other)], point) for i in range(len(other))]
            if min(sides) >= -1e-8 or max(sides) <= 1e-8:
                return 0.0
    for a, b in ((first, second), (second, first)):
        for i, point in enumerate(a):
            nxt = a[(i + 1) % len(a)]
            for j, other in enumerate(b):
                after = b[(j + 1) % len(b)]
                c1, c2 = cross(point, nxt, other), cross(point, nxt, after)
                c3, c4 = cross(other, after, point), cross(other, after, nxt)
                if c1 * c2 <= 0 and c3 * c4 <= 0:
                    return 0.0
    return min(point_segment_distance(point, other[i], other[(i + 1) % len(other)])
               for a, other in ((first, second), (second, first))
               for point in a for i in range(len(other)))


class ServiceCaveContactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((HERE / 'candidate.json').read_text())
        cls.arena = cls.data['arena']
        cls.cave = [s for s in layout.parts(cls.arena) if s['name'].startswith('service-cave.')]
        cls.authority = list(triangles_from_authority(cls.arena))
        cls.archived = list(glb_triangles())

    def test_frozen_native_glb_reproduces_reviewed_p1_without_restamping_it(self):
        report = json.loads((ROOT / 'port/finish/map-variety/native-T-20261003/abyssal-pressureworks/material-report.json').read_text())
        frozen = json.loads((HERE.parent / 'revision2/candidate.json').read_text())
        self.assertEqual(hashlib.sha256(T_GLB.read_bytes()).hexdigest(), report['glbSha256'])
        self.assertEqual(report['geometryHash'], '5fea4aada721903cea26897fb6a17befaf146c576c095dc712feebef626adfa2')
        self.assertEqual(frozen['geometryHash'], report['geometryHash'])
        self.assertNotEqual(self.data['geometryHash'], report['geometryHash'])
        cases = [((-106, 7.2, -97), (-106, 7.2, -100), 'deep-silt', -98.35),
                 ((-94, 10, -98.5), (-94, 5, -98.5), 'salt-limestone', 8.6),
                 ((91, 4, -92.5), (91, -1, -92.5), 'salt-limestone', 2.6)]
        for start, end, material, coordinate in cases:
            hits = segment_hits(start, end, self.archived)
            self.assertTrue(any(material in name and abs(point[2 if material == 'deep-silt' else 1] - coordinate) < .002
                                for _, name, point in hits), (start, hits[:8]))

    def test_corrected_parts_and_authority_disagree_nowhere_on_reviewed_rays(self):
        self.assertEqual(len(self.cave), 14)  # both ledges, twelve real fins
        rendered = list(triangles_from_specs(self.cave))
        for start, end, expected_floor in [((-106, 7.2, -97), (-106, 7.2, -100), None),
                                           ((-94, 10, -98.5), (-94, 5, -98.5), 6),
                                           ((91, 4, -92.5), (91, -1, -92.5), 0)]:
            self.assertEqual(segment_hits(start, end, rendered), [], (start, end))
            authority_hits = segment_hits(start, end, self.authority)
            if expected_floor is None:
                self.assertEqual(authority_hits, [])
            else:
                self.assertTrue(any(abs(point[1] - expected_floor) < 1e-5 for _, _, point in authority_hits))
        for spec in self.cave:
            geometry.validate_spec(spec)
            self.assertEqual(len(spec['faces']), 6)
            self.assertTrue(all(len(face) == 4 for face in spec['faces']))

    def test_all_fourteen_solid_xz_footprints_clear_every_walkable_triangle_by_capsule_margin(self):
        walkable = []
        for surface in self.arena['terrain']['surfaces']:
            if surface.get('walkable') is False:
                continue
            for face in surface['triangles']:
                triangle = [surface['vertices'][j] for j in face]
                if geometry.polygon_normal(triangle)[1] <= 1e-8:
                    continue
                walkable.append((surface['id'], [(p[0], p[2]) for p in triangle]))
        self.assertGreater(len(walkable), 100)
        for spec in self.cave:
            footprint = [(spec['vertices'][i][0], spec['vertices'][i][2]) for i in (0, 4, 5, 1)]
            distance, ident = min((polygons_distance(footprint, triangle), ident) for ident, triangle in walkable)
            self.assertGreater(distance, layout.SERVICE_CAVE['bodyClearance'] + spec['bevel'] + .05,
                               (spec['name'], ident, distance))

    def test_full_retained_walls_shield_forms_without_closing_observation_bays(self):
        walls = self.arena['terrain']['walls']
        for form in layout.SERVICE_CAVE['forms']:
            d = form['deck']
            side = form['retainedSide']
            wall = [w for w in walls if w['id'].startswith(d['id'] + '.' + side + '-')]
            self.assertEqual(len(wall), 2, form['id'])
            points = [p for part in wall for p in part['vertices']]
            if side == 'south':
                self.assertEqual((min(p[0] for p in points), max(p[0] for p in points)), (d['x'] - d['w']/2, d['x'] + d['w']/2))
                self.assertTrue(all(p[2] == d['z'] - d['d']/2 for p in points))
            else:
                self.assertEqual((min(p[2] for p in points), max(p[2] for p in points)), (d['z'] - d['d']/2, d['z'] + d['d']/2))
                self.assertTrue(all(p[0] == d['x'] + d['w']/2 for p in points))
            self.assertEqual((min(p[1] for p in points), max(p[1] for p in points)), (d['y'], d['y'] + 4))
        for prefix in self.arena['art']['revision2']['openedBays']:
            self.assertFalse(any(w['id'].startswith(prefix) for w in walls))
        self.assertTrue(any(w['id'].startswith('vessel-0-0-window-header') for w in walls))


if __name__ == '__main__':
    unittest.main()

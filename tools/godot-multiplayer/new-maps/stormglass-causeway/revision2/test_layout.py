"""Bounded source checks for the Stormglass revision-2 layout, composition and materials.

No bpy, Blender, engine or network. Every layout spec is dispatched through the
real pure geometry validation, the basis round-trips, cameras track target
height, and the render composition covers the complete revised authority (road,
barriers, vault, buildings) while the road/race stay untouched.
"""
import json
import math
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tools' / 'map-variety-support'))
import layout  # noqa: E402
import manifest  # noqa: E402
import geometry  # noqa: E402
import composition  # noqa: E402


def load(path):
    return json.loads(Path(path).read_text())


def _normalize(v):
    length = math.sqrt(sum(c * c for c in v))
    return tuple(c / length for c in v)


class LayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.authority = load(HERE / 'candidate.json')
        cls.arena = cls.authority['arena']
        cls.bindings = load(HERE / 'materials.bindings.json')['materials']
        cls.pack = manifest.load_pack()
        cls.parts = layout.parts(cls.arena)
        cls.base = composition.compose(cls.arena)

    def test_coordinate_basis_round_trips_through_blender_and_gltf(self):
        for point in ((0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (-3, 7, -2), (12.5, -6, 3.25)):
            self.assertEqual(geometry.roundtrip(point), point)
        self.assertEqual(geometry.source_to_blender((0, 1, 0)), (0, 0, 1))
        self.assertEqual(geometry.source_to_blender((0, 0, 1)), (0, -1, 0))
        self.assertEqual(geometry.prism_size_to_blender((2, 3, 4)), (2, 4, 3))

    def test_every_layout_spec_passes_real_pure_geometry_validation(self):
        self.assertTrue(self.parts)
        for spec in self.parts:
            self.assertIn(spec['op'], ('mesh', 'pipe'))
            geometry.validate_spec(spec)
            if spec['op'] == 'mesh':
                for face in spec['faces']:
                    self.assertTrue(all(isinstance(i, int) and 0 <= i < len(spec['vertices']) for i in face), spec['name'])
                    self.assertGreater(geometry.polygon_area([spec['vertices'][i] for i in face]), 1e-9, spec['name'])

    def test_checkpoint_arch_variants_are_valid_geometry(self):
        gates = self.arena['art']['revision2']['scenery']['gates']
        self.assertEqual(len({g['variant'] for g in gates}), 3)
        arch_parts = [p for p in self.parts if p['name'].startswith('checkpoint-arch-')]
        self.assertTrue(arch_parts)
        for spec in arch_parts:
            geometry.validate_spec(spec)

    def test_non_cosmetic_variants_exist(self):
        scenery = self.arena['art']['revision2']['scenery']
        self.assertEqual(sorted({s['height'] for s in scenery['seawalls']}), [4, 6, 8, 10, 12])
        self.assertEqual(len({s['tiers'] for s in scenery['grandstands']}), 4)
        self.assertEqual(len({s['variant'] for s in scenery['facades']}), 3)

    def test_composition_covers_the_complete_revised_authority(self):
        surface_ids = {s['id'] for s in self.arena['terrain']['surfaces']}
        wall_ids = {w['id'] for w in self.arena['terrain']['walls']}
        mesh_ids = {m['id'] for m in self.arena['art']['meshes']}
        base_ids = {s['name'] for s in self.base}
        for ident in surface_ids | wall_ids | mesh_ids:
            self.assertIn(ident, base_ids, 'missing render base ' + ident)
        # The road itself is present and authored scenery is additive.
        self.assertIn('road-0', base_ids)
        self.assertTrue(any(layout.classify(p['name']) == 'seawall' for p in self.parts))

    def test_road_race_and_terrain_are_not_in_the_authored_layout(self):
        # Scenery parts never use a terrain surface id and never touch race data.
        surface_ids = {s['id'] for s in self.arena['terrain']['surfaces']}
        for spec in self.parts:
            self.assertNotIn(spec['name'], surface_ids)
        self.assertTrue(all(spec['sector'] in {'seawall', 'grandstand', 'cliff-stair', 'checkpoint-arch', 'lighthouse', 'quay-crane', 'terminal-facade'} for spec in self.parts))

    def test_composition_materials_are_all_reviewed_bindings(self):
        used = {spec['material'] for spec in self.base + self.parts}
        self.assertTrue(used <= set(self.bindings), used - set(self.bindings))
        self.assertIn('asphalt', self.bindings)
        self.assertIn('ocean', self.bindings)

    def test_material_plan_resolves_real_pack_bytes_and_explicit_root(self):
        plan = self.pack.bindings_plan(self.bindings)
        self.assertEqual(set(plan), set(self.bindings))
        for name, entry in plan.items():
            if entry['role'] == 'preserve':
                continue
            self.assertTrue(Path(entry['albedoFile']).is_file(), name)
            self.assertTrue(0 < entry['tilesPerMeter'] <= 16, name)
        self.assertEqual(manifest.load_pack(str(ROOT)).manifest_sha, self.pack.manifest_sha)

    def test_unknown_material_fails_closed(self):
        with self.assertRaises(KeyError):
            self.pack.bindings_plan({'x': {'role': 'surface', 'material': 'not-in-pack', 'normal': True}})

    def test_ring_and_arch_orientations_are_intentional(self):
        ring = geometry.ring_mesh_src('r', (0, 5, 0), 1.0, 2.0, 0.3, 'm', 's')
        ys = [v[1] for v in ring['vertices']]
        self.assertAlmostEqual(max(ys) - min(ys), 0.3, places=6)
        arch = geometry.arch_mesh_src('a', (0, 0), 10.0, 15.0, 2.0, 4.0, 0.0, 'm', 's')
        ys = [v[1] for v in arch['vertices']]
        self.assertGreater(max(ys), 10.0 + 15.0 * 0.99)
        self.assertAlmostEqual(min(ys), 10.0, places=6)

    def test_box_faces_are_outward_wound(self):
        for heading in (0.0, 0.7, -1.9):
            spec = geometry.box_mesh_src('b', (3, 4, 5), (4, 1.5, 3), heading, 'm', 's')
            for face in spec['faces']:
                points = [spec['vertices'][i] for i in face]
                normal = geometry.polygon_normal(points)
                centre = tuple(sum(p[k] for p in points) / len(points) for k in range(3))
                outward = sum(normal[k] * (centre[k] - (3, 4, 5)[k]) for k in range(3))
                self.assertGreater(outward, 0, 'inward face at heading %s' % heading)

    def test_camera_forward_tracks_target_height(self):
        for name, (eye, target) in layout.PROBE_CAMERAS.items():
            forward = _normalize(tuple(target[i] - eye[i] for i in range(3)))
            converted = geometry.source_direction_to_blender(forward)
            difference = _normalize(tuple(geometry.source_to_blender(target)[i] - geometry.source_to_blender(eye)[i] for i in range(3)))
            for a, b in zip(converted, difference):
                self.assertAlmostEqual(a, b, places=9, msg=name)
            if target[1] != eye[1]:
                self.assertGreater(abs(forward[1]), 1e-6, name + ' ignores target height')


if __name__ == '__main__':
    unittest.main()

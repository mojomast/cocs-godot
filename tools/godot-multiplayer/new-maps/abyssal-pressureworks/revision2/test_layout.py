"""Bounded source checks for the Abyssal revision-2 layout, composition and materials.

No bpy, Blender, engine or network. Every layout spec is dispatched through the
real pure geometry validation (faces are valid outward index tuples with nonzero
area; pipes through blender_kit's own ring builder), the coordinate basis
round-trips through Blender/glTF, cameras track target height, and the render
composition covers the complete revised authority.
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
        self.assertEqual(geometry.source_to_blender((0, 1, 0)), (0, 0, 1))   # +Y_up -> +Z
        self.assertEqual(geometry.source_to_blender((0, 0, 1)), (0, -1, 0))  # +Z -> -Y
        self.assertEqual(geometry.source_to_blender((1, 0, 0)), (1, 0, 0))
        self.assertEqual(geometry.blender_to_gltf(geometry.source_to_blender((0, 5, 0))), (0, 5, 0))
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

    def test_arch_and_vent_dimensions_are_valid_for_every_variant(self):
        vaults = [p for p in self.parts if layout.classify(p['name']) == 'pressure-vault']
        self.assertGreaterEqual(len(vaults), 6)
        for gate in self.arena['art']['revision2']['replacedRoofHosts']:
            self.assertFalse(self.arena['terrain']['surfaces'][0]['id'].startswith(gate + '-x'))
        # Vent jambs must leave a real opening and rise above the wall.
        vents = [p for p in self.parts if 'hab-vent' in p['name']]
        self.assertTrue(vents)
        for spec in vents:
            geometry.validate_spec(spec)

    def test_every_declared_class_is_built_with_variants(self):
        self.assertEqual({layout.classify(p['name']) for p in self.parts}, set(layout.CLASSES))
        self.assertGreaterEqual(len({p['name'].split('.', 1)[1].split('.')[0] for p in self.parts if layout.classify(p['name']) == 'pressure-vault'}), 3)

    def test_composition_covers_the_complete_revised_authority(self):
        surface_ids = {s['id'] for s in self.arena['terrain']['surfaces']}
        wall_ids = {w['id'] for w in self.arena['terrain']['walls']}
        base_ids = {s['name'] for s in self.base}
        for ident in surface_ids | {w['id'] for w in self.arena['terrain']['walls']}:
            self.assertIn(ident, base_ids, 'missing render base ' + ident)
        for window in self.arena['art'].get('windows', []):
            self.assertIn(window['id'], base_ids)
        for piece in self.arena['art'].get('pieces', []):
            self.assertIn(piece['id'], base_ids)
        # The six replaced roofs are absent from authority and render, and their
        # substitutes are present as authored vaults.
        for host in self.arena['art']['revision2']['replacedRoofHosts']:
            self.assertFalse(any(i.startswith(host + '-roof-facet-') or i == host + '-crown' for i in surface_ids))
            self.assertFalse(any(i.startswith(host + '-roof-facet-') or i == host + '-crown' for i in base_ids))
            self.assertTrue(any(p['name'].startswith(host + '.') for p in self.parts), 'no substitute for ' + host)
        # Every new walkable terrace/pocket and its retaining wall render.
        for deck in self.arena['art']['revision2']['decks']:
            self.assertIn(deck['id'], surface_ids)
            self.assertIn(deck['id'], base_ids)
        for wall in self.arena['terrain']['walls']:
            self.assertIn(wall['id'], base_ids)

    def test_composition_materials_are_all_reviewed_bindings(self):
        used = {spec['material'] for spec in self.base + self.parts}
        self.assertTrue(used <= set(self.bindings), used - set(self.bindings))

    def test_material_plan_resolves_real_pack_bytes_and_explicit_root(self):
        plan = self.pack.bindings_plan(self.bindings)
        self.assertEqual(set(plan), set(self.bindings))
        for name, entry in plan.items():
            if entry['role'] == 'preserve':
                continue
            self.assertTrue(Path(entry['albedoFile']).is_file(), name)
            self.assertTrue(0 < entry['tilesPerMeter'] <= 16, name)
        rerouted = manifest.load_pack(str(ROOT))
        self.assertEqual(rerouted.manifest_sha, self.pack.manifest_sha)

    def test_unknown_material_fails_closed(self):
        with self.assertRaises(KeyError):
            self.pack.bindings_plan({'x': {'role': 'surface', 'material': 'not-in-pack', 'normal': True}})

    def test_ring_and_arch_orientations_are_intentional(self):
        ring = geometry.ring_mesh_src('r', (0, 5, 0), 1.0, 2.0, 0.3, 'm', 's')
        ys = [v[1] for v in ring['vertices']]
        self.assertAlmostEqual(max(ys) - min(ys), 0.3, places=6)  # horizontal band: Y is thickness
        self.assertGreater(max(abs(v[0]) for v in ring['vertices']), 1.9)
        self.assertGreater(max(abs(v[2]) for v in ring['vertices']), 1.9)
        arch = geometry.arch_mesh_src('a', (0, 0), 10.0, 15.0, 2.0, 4.0, 0.0, 'm', 's')
        ys = [v[1] for v in arch['vertices']]
        self.assertGreater(max(ys), 10.0 + 15.0 * 0.99)  # rises a full radius: vertical
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

    def test_original_reef_and_accepted_author_details_are_present(self):
        names = {p['name'] for p in self.base}
        for spec in self.base:
            geometry.validate_spec(spec)
        for index in range(len(self.arena['art']['reefs'])):
            self.assertIn('reef-%d-escarpment' % index, names)
            for arm in range(5):
                self.assertIn('reef-%d-branch-%d' % (index, arm), names)
                self.assertIn('reef-%d-tip-%d' % (index, arm), names)
        for index in range(8):
            self.assertIn('escarpment-bed-%d' % index, names)
        for host in self.arena['art']['revision2']['replacedRoofHosts']:
            self.assertTrue(any(n.startswith(host + '-external-load-rib-') for n in names))
            self.assertTrue(any(n.startswith(host + '-pressure-ring-') for n in names))
        self.assertEqual(len(composition.labels_for_arena(self.arena)), 12)

    def test_replacement_roof_and_buttress_caps_face_up(self):
        for spec in self.parts:
            if spec['name'].endswith('.vault-crown') or spec['name'].startswith('reef-buttress.'):
                face = spec['faces'][-1]
                normal = geometry.polygon_normal([spec['vertices'][i] for i in face])
                self.assertGreater(normal[1], 0, spec['name'])
        crown = next(s for s in self.parts if s['name'].endswith('.vault-crown'))
        self.assertEqual(crown['material'], 'ceramic-enamel')


if __name__ == '__main__':
    unittest.main()

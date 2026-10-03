"""Bounded source checks for the Stormglass revision-2 scenic layout + materials.

No bpy, Blender, engine or network. Validates the authored class specs, that
every referenced material is an exact reviewed binding resolved to real pack
bytes, and that unknown materials fail closed.
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


def load(path):
    return json.loads(Path(path).read_text())


class LayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.authority = load(HERE / 'candidate.json')
        cls.bindings = load(HERE / 'materials.bindings.json')['materials']
        cls.pack = manifest.load_pack()
        cls.parts = layout.parts(cls.authority['arena'])

    def test_every_declared_class_is_built(self):
        self.assertTrue(self.parts)
        self.assertEqual({layout.classify(p['name']) for p in self.parts}, set(layout.CLASSES))

    def test_non_cosmetic_variants_exist(self):
        scenery = self.authority['arena']['art']['revision2']['scenery']
        self.assertEqual(sorted({s['height'] for s in scenery['seawalls']}), [4, 6, 8, 10, 12])
        self.assertEqual(len({s['tiers'] for s in scenery['grandstands']}), 4)
        self.assertEqual(len({s['variant'] for s in scenery['gates']}), 3)
        self.assertEqual(len({s['variant'] for s in scenery['facades']}), 3)

    def test_every_referenced_material_is_a_reviewed_binding(self):
        used = {p['material'] for p in self.parts}
        self.assertTrue(used <= set(self.bindings), used - set(self.bindings))
        self.assertGreaterEqual(len(used), 6)

    def test_all_geometry_is_finite_and_inside_the_review_envelope(self):
        for part in self.parts:
            values = []
            for arg in part['args']:
                if isinstance(arg, (int, float)):
                    values.append(arg)
                elif isinstance(arg, (list, tuple)):
                    for item in arg:
                        values.extend(item if isinstance(item, (list, tuple)) else [item])
            for number in values:
                if isinstance(number, (int, float)):
                    self.assertTrue(math.isfinite(number), part['name'])
            if part['op'] == 'mesh':
                for vertex in part['args'][0]:
                    self.assertEqual(len(vertex), 3, part['name'])
                    self.assertLessEqual(abs(vertex[0]), 320, part['name'])
                    self.assertLessEqual(abs(vertex[1]), 260, part['name'])
                    self.assertTrue(-80 < vertex[2] < 60, part['name'] + ' vertical')

    def test_material_plan_resolves_real_pack_bytes(self):
        plan = self.pack.bindings_plan(self.bindings)
        self.assertEqual(set(plan), set(self.bindings))
        for name, entry in plan.items():
            if entry['role'] == 'preserve':
                continue
            self.assertTrue(Path(entry['albedoFile']).is_file(), name)
            self.assertTrue(0 < entry['tilesPerMeter'] <= 16, name)
            if entry['normalFile']:
                self.assertTrue(Path(entry['normalFile']).is_file(), name)

    def test_unknown_material_fails_closed(self):
        with self.assertRaises(KeyError):
            self.pack.bindings_plan({'x': {'role': 'surface', 'material': 'not-in-pack', 'normal': True}})
        with self.assertRaises(ValueError):
            self.pack.bindings_plan({'x': {'role': 'invented', 'material': 'salt-limestone', 'normal': True}})

    def test_probe_cameras_are_finite(self):
        self.assertGreaterEqual(len(layout.PROBE_CAMERAS), 6)
        for name, pair in layout.PROBE_CAMERAS.items():
            self.assertTrue(all(math.isfinite(v) for point in pair for v in point), name)

    def test_artifacts_exist_and_share_the_geometry_hash(self):
        for name in ('author.py', 'recipe.mjs', 'build.mjs', 'materials.bindings.json', 'arena.json', 'probes.json'):
            self.assertTrue((HERE / name).is_file(), name)
        self.assertEqual(self.authority['geometryHash'], load(HERE / 'probes.json')['geometryHash'])


if __name__ == '__main__':
    unittest.main()

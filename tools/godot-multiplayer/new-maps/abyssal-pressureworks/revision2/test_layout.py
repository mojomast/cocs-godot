"""Bounded source checks for the Abyssal revision-2 layout and material hooks.

No bpy, Blender, engine or network. Validates the authored class specs, that
every referenced material is an exact reviewed binding resolved to real pack
bytes, and that unknown materials fail closed.
"""
import importlib.util
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
        classes = {layout.classify(p['name']) for p in self.parts}
        self.assertEqual(classes, set(layout.CLASSES))
        for name, (variants, _hero) in layout.CLASSES.items():
            self.assertGreaterEqual(variants, 1, name)

    def test_pressure_vault_has_three_distinct_forms(self):
        vault = [p for p in self.parts if layout.classify(p['name']) == 'pressure-vault']
        signature = {p['name'].split('.', 1)[1].split('.')[0] for p in vault}
        self.assertIn('vault', signature)
        self.assertTrue(any(s.startswith('pressure-rib') for s in signature))
        self.assertTrue(any(s.startswith('hab') for s in signature))

    def test_every_referenced_material_is_a_reviewed_binding(self):
        used = {p['material'] for p in self.parts}
        self.assertTrue(used <= set(self.bindings), used - set(self.bindings))
        self.assertGreaterEqual(len(used), 6)
        for part in self.parts:
            self.assertIn(part['op'], {'mesh', 'prism', 'curved_rib', 'pipe', 'framed_bay'})
            self.assertTrue(part['sector'])

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
                    self.assertLessEqual(abs(vertex[0]), 140, part['name'])
                    self.assertLessEqual(abs(vertex[1]), 140, part['name'])
                    self.assertTrue(-50 < vertex[2] < 45, part['name'] + ' vertical')

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
            self.pack.bindings_plan({'made-up': {'role': 'surface', 'material': 'not-in-pack', 'normal': True}})
        with self.assertRaises(ValueError):
            self.pack.bindings_plan({'made-up': {'role': 'invented', 'material': 'copper-patina', 'normal': True}})

    def test_probe_cameras_are_finite(self):
        self.assertGreaterEqual(len(layout.PROBE_CAMERAS), 6)
        for name, (eye, target) in layout.PROBE_CAMERAS.items():
            self.assertEqual(len(eye), 3, name)
            self.assertEqual(len(target), 3, name)
            self.assertTrue(all(math.isfinite(v) for v in (*eye, *target)), name)

    def test_author_and_build_artifacts_exist(self):
        for name in ('author.py', 'recipe.mjs', 'build.mjs', 'materials.bindings.json', 'arena.json', 'probes.json'):
            self.assertTrue((HERE / name).is_file(), name)
        self.assertEqual(self.authority['geometryHash'], load(HERE / 'probes.json')['geometryHash'])


if __name__ == '__main__':
    unittest.main()

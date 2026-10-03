"""Geometry contract checks without importing or launching Blender."""
import importlib.util
import math
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location('map_variety_kit', Path(__file__).with_name('blender_kit.py'))
kit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kit)


class RecordingKit(kit.Kit):
    def mesh(self, name, vertices, faces, material, **kwargs):
        self.parts.append((name, vertices, faces, material, kwargs))
        return name


class SourceKitTests(unittest.TestCase):
    def setUp(self):
        self.kit = RecordingKit(object(), object(), {'frame': object(), 'trim': object()},
                                {'frame': 1.2, 'trim': 2.4})
        self.kit.parts = []

    def test_vault_is_solid_curved_editable_part(self):
        self.kit.curved_rib('vault', (0, 0, 2), 2, 2.2, .3, 0, math.pi, 'frame', segments=20)
        name, vertices, faces, material, _ = self.kit.parts[0]
        self.assertEqual(name, 'vault')
        self.assertEqual(material, 'frame')
        self.assertEqual(len(vertices), 84)
        self.assertEqual(len(faces), 82)
        self.assertGreater(max(v[2] for v in vertices), 4.1)
        self.assertEqual(len({tuple(round(n, 3) for n in v) for v in vertices}), 84)

    def test_bay_has_recess_stepped_sill_and_curved_lintel(self):
        self.kit.framed_bay('archive', (0, 0, 0), 4, 5, .45,
                            frame='frame', trim='trim', sector='library', arch=True)
        names = [part[0] for part in self.kit.parts]
        self.assertEqual(len(names), 7)
        self.assertIn('archive.arched-lintel', names)
        self.assertIn('archive.reveal', names)
        self.assertIn('archive.stepped-sill', names)
        self.assertTrue(all(part[4]['sector'] == 'library' for part in self.kit.parts))
        self.assertEqual(kit._phase('archive'), kit._phase('archive'))
        self.assertNotEqual(kit._phase('archive'), kit._phase('observatory'))


if __name__ == '__main__':
    unittest.main()

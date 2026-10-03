"""Pure source contract checks for R adapter split and accepted map palettes."""
import json
import pathlib
import sys
import unittest
from types import SimpleNamespace

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import build_entry
import manifest
import preserved


def bindings(map_id):
    path = ROOT / 'tools/godot-multiplayer/new-maps' / map_id / 'revision2/materials.bindings.json'
    return json.loads(path.read_text())['materials']


class PreservedContractTests(unittest.TestCase):
    def test_exact_palettes_and_adapter_boundary(self):
        cases = {
            'abyssal-pressureworks': {'glass': '#286b83', 'observation-glass': '#286b83',
                                      'cyan': '#57c4cf', 'equalizer-emissive': '#57c4cf', 'amber': '#dca45e'},
            'stormglass-causeway': {'glass': [0.16, 0.46, 0.53], 'harbour-glass': [0.16, 0.46, 0.53],
                                    'amber': [0.94, 0.62, 0.16], 'ocean': [0.07, 0.23, 0.29]},
        }
        pack = manifest.load_pack(ROOT)
        for map_id, palette in cases.items():
            full = bindings(map_id)
            pbr, authored = preserved.split_bindings(full, map_id)
            self.assertEqual(set(authored), set(palette))
            self.assertTrue(all(binding['role'] in ('surface', 'team') and type(binding['normal']) is bool for binding in pbr.values()))
            self.assertEqual({n: b['colorSrgb'] for n, b in authored.items()}, palette)
            self.assertEqual(set(pbr) | set(authored), set(full))
            self.assertTrue(all(preserved.linear_color(b['colorSrgb']) != (0, 0, 0) for b in authored.values()))
            self.assertEqual(set(pack.bindings_plan(full)), set(full))

    def test_missing_unknown_and_incomplete_preserve_fail_closed(self):
        full = bindings('abyssal-pressureworks')
        for name, edit in [('glass', {'alpha': -1}), ('amber', {'emissionStrength': float('nan')}),
                           ('cyan', {'tilesPerMeter': 0}), ('glass', {'material': 'not-in-pack'}),
                           ('amber', {'colorSrgb': '#notrgb'})]:
            altered = {k: dict(v) for k, v in full.items()}
            altered[name].update(edit)
            with self.assertRaises(ValueError):
                preserved.split_bindings(altered, 'abyssal-pressureworks')
        for name in ('amber', 'improvised-glass'):
            altered = {k: dict(v) for k, v in full.items()}
            if name == 'amber':
                del altered['amber']
            else:
                altered[name] = dict(full['glass'])
            with self.assertRaises(ValueError):
                preserved.split_bindings(altered, 'abyssal-pressureworks')
        altered = {k: dict(v) for k, v in full.items()}
        altered['navy']['role'] = 'unknown'
        with self.assertRaises(ValueError):
            preserved.split_bindings(altered, 'abyssal-pressureworks')

    def test_fake_adapter_api_rejects_preserve_and_proves_exact_keys(self):
        pack = manifest.load_pack(ROOT)
        pbr, authored = preserved.split_bindings(bindings('abyssal-pressureworks'), 'abyssal-pressureworks')
        calls = []

        def adapter(root, given, *, output_dir=None, with_report=False):
            calls.append((root, set(given), output_dir, with_report))
            if any(b['role'] == 'preserve' for b in given.values()):
                raise ValueError('R rejects preserved roles')
            return ({n: object() for n in given}, {n: 1 for n in given},
                    {'pack': {'baseSha256': pack.base_sha, 'overlaySha256': pack.overlay_sha},
                     'materials': {n: {} for n in given}})

        materials, density, report = build_entry.request_pack_materials(
            SimpleNamespace(load_materials=adapter), ROOT, pbr, ROOT / 'converted', pack)
        self.assertEqual(set(materials), set(pbr))
        self.assertEqual(set(density), set(pbr))
        self.assertEqual(set(report['materials']), set(pbr))
        self.assertEqual(calls[0][1], set(pbr))
        self.assertTrue(calls[0][3])
        with self.assertRaises(ValueError):
            build_entry.request_pack_materials(SimpleNamespace(load_materials=adapter), ROOT,
                                               {**pbr, **authored}, ROOT / 'converted', pack)
        self.assertEqual(len(calls), 1)

    def test_exported_color_must_be_pixel_correct_derived_srgb(self):
        decode = lambda data: (1, 1, bytearray(data))
        source = bytes((64, 0, 255, 128))
        encoded = round((1.055 * (64 / 255) ** (1 / 2.4) - .055) * 255)
        self.assertEqual(build_entry.verify_png_pixels(source, bytes((encoded, 0, 255, 128)), decode, srgb=True), 1)
        with self.assertRaises(ValueError):
            build_entry.verify_png_pixels(source, source, decode, srgb=True)
        self.assertEqual(build_entry.verify_png_pixels(source, source, decode, srgb=False), 1)
        with self.assertRaises(ValueError):
            build_entry.verify_png_pixels(source, bytes((64, 0, 255, 0)), decode, srgb=False)


if __name__ == '__main__':
    unittest.main()

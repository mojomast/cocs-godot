"""Meaningful negative closure/coverage gates, runnable without engine imports."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
import struct

spec = importlib.util.spec_from_file_location('finish_validate', Path(__file__).with_name('validate.py'))
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.texture = 'res://source_operators/moth_finish/assets/panel.png'
        file = self.root / 'godot' / self.texture[6:]
        file.parent.mkdir(parents=True)
        file.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + struct.pack('>II', 64, 64) + bytes([8, 2]))
        self.manifest = {'version': 1, 'finishes': {'paint': {'albedo': self.texture, 'albedo_mode': 'modulate', 'metallic': .2, 'roughness_gain': .9, 'normal_strength': .2}}}
        self.profile = {'version': 1, 'operator_id': 'meta', 'bindings': [{'source_material': 'paint', 'role': 'armor', 'finish': 'paint'}], 'preserve_materials': [{'source_material': 'sourceTeamIvory', 'reason': 'team shape'}], 'overlay_finishes': dict.fromkeys(['panel', 'board', 'vent'], 'paint')}
        self.rows = [{'material': 'paint', 'mesh': 'body', 'uv0': True, 'tangent': False, 'material_traits': {}},
                     {'material': 'sourceTeamIvory', 'mesh': 'marker', 'uv0': True, 'tangent': False, 'material_traits': {}}]

    def check(self):
        return validator.check_profile(self.profile, self.manifest, 'meta', self.rows, self.root)

    def test_valid_body_coverage(self):
        self.assertEqual(self.check()['coverage'][0]['status'], 'matched')

    def test_protected_emission(self):
        self.rows[0]['material_traits']['emissiveFactor'] = [0, .2, 0]
        with self.assertRaises(AssertionError): self.check()

    def test_missing_uv(self):
        self.rows[0]['uv0'] = False
        with self.assertRaises(AssertionError): self.check()

    def test_malformed_scalar(self):
        for value in (float('nan'), -1, 2, True, '0.5'):
            self.manifest['finishes']['paint']['metallic'] = value
            with self.assertRaises(AssertionError): self.check()

    def test_conflicting_preserve(self):
        self.profile['preserve_materials'].append({'source_material': 'paint', 'reason': 'sensor'})
        with self.assertRaises(AssertionError): self.check()

    def test_texture_escape(self):
        self.manifest['finishes']['paint']['albedo'] = self.texture.replace('assets/', 'assets/../')
        with self.assertRaises(AssertionError): self.check()

    def test_missing_binding(self):
        self.profile['bindings'][0]['source_material'] = 'not_exported'
        with self.assertRaises(AssertionError): self.check()

    def test_provenance_cannot_be_omitted(self):
        with self.assertRaises(AssertionError):
            validator.check_provenance(self.manifest, self.root, self.check()['textures'])


class ActualContentIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[3]
        cls.manifest = __import__('json').loads((cls.root / 'godot/source_operators/moth_finish/manifest.json').read_text())
        cls.profiles = {op: __import__('json').loads((cls.root / f'godot/source_operators/moth_finish/profiles/{op}.json').read_text()) for op in validator.OPS}
        cls.reports = {op: validator.check_profile(cls.profiles[op], cls.manifest, op,
                      validator.inventory(cls.root / f'godot/source_operators/generated/{op}.glb'), cls.root) for op in validator.OPS}
        cls.textures = {key: value for entry in cls.reports.values() for key, value in entry['textures'].items()}

    def test_all_real_finish_tokens_and_source_coverage(self):
        used = {b['finish'] for p in self.profiles.values() for b in p['bindings']}
        used.update(f for p in self.profiles.values() for f in p['overlay_finishes'].values())
        self.assertEqual(used, set(self.manifest['finishes']))
        self.assertEqual(len(used), 63)
        self.assertEqual(len(self.textures), 116)
        covered = [c for r in self.reports.values() for c in r['coverage']]
        self.assertEqual(len(covered), 1014)
        self.assertEqual(sum(c['status'] == 'matched' for c in covered), 538)
        self.assertEqual(sum(c['status'] == 'excluded' for c in covered), 476)
        self.assertTrue(all((t['width'], t['height']) == (256, 256) for t in self.textures.values()))

    def test_actual_provenance_graph(self):
        self.assertEqual(len(validator.check_provenance(self.manifest, self.root, self.textures)), 6)

    def test_explicit_rubber_normal_omission(self):
        for profile in self.profiles.values():
            for binding in profile['bindings']:
                if binding['role'] != 'rubber': continue
                finish = self.manifest['finishes'][binding['finish']]
                self.assertNotIn('normal', finish)
                self.assertEqual(finish['normal_strength'], 0)

    def test_real_hash_dimension_and_channel_tampering(self):
        path = next(iter(self.textures))
        for field, value in [('png_sha256', '0' * 64), ('dimensions', [1, 1]), ('channels', 4)]:
            manifest = copy.deepcopy(self.manifest)
            manifest['textures'][path][field] = value
            with self.assertRaises(AssertionError): validator.check_provenance(manifest, self.root, self.textures)

    def test_real_moth_source_tampering(self):
        manifest = copy.deepcopy(self.manifest)
        manifest['provenance']['moth_sources']['carbon_fiber']['png_sha256'] = '0' * 64
        with self.assertRaises(AssertionError): validator.check_provenance(manifest, self.root, self.textures)

    def test_unknown_texture_derivation_source(self):
        manifest = copy.deepcopy(self.manifest)
        manifest['textures'][next(iter(self.textures))]['moth_keys'] = ['textures/invented']
        with self.assertRaises(AssertionError): validator.check_provenance(manifest, self.root, self.textures)


if __name__ == '__main__':
    unittest.main()

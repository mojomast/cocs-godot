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
        file.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\0' * 8 + struct.pack('>II', 64, 64))
        self.manifest = {'version': 1, 'finishes': {'paint': {'albedo': self.texture, 'albedo_mode': 'modulate', 'metallic': .2, 'roughness_gain': .9, 'normal_strength': .2}}}
        self.profile = {'version': 1, 'operator_id': 'meta', 'bindings': [{'source_material': 'paint', 'role': 'armor', 'finish': 'paint'}], 'preserve_materials': [{'source_material': 'sourceTeamIvory', 'reason': 'team shape'}], 'overlay_finishes': dict.fromkeys(['panel', 'board', 'vent'], 'paint')}
        self.rows = [{'material': 'paint', 'mesh': 'body', 'uv0': True, 'tangent': False, 'material_traits': {}}]

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


if __name__ == '__main__':
    unittest.main()

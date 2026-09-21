import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import wave

import inventory


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in inventory.ROOTS:
            (self.root / folder).mkdir(parents=True)
        fixtures = {
            'game/view.mjs': 'export function robotModel() {}',
            'game/moth-baked.mjs': 'export const MOTH_BAKED = {};\n\nexport default MOTH_BAKED;',
            'assets/moth/manifest.json': '{"jobs":[]}',
            'public/music/manifest.json': '{"samples":[]}',
            'public/audio/announcer/manifest.json': '{"clips":[]}',
        }
        for p, text in fixtures.items():
            self.put(p, text)

    def put(self, path, text):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def test_deterministic_and_read_only(self):
        before = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        first = inventory.render(inventory.build(self.root))
        self.assertEqual(first, inventory.render(inventory.build(self.root)))
        self.assertNotIn(str(self.root), first)
        after = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)

    def test_missing_required_cli(self):
        (self.root / 'game/view.mjs').unlink()
        result = subprocess.run([sys.executable, '-B', inventory.__file__, '--root', str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertIn('missing required source: game/view.mjs', result.stderr)

    def test_malformed_json(self):
        self.put('public/music/manifest.json', '{')
        with self.assertRaises(ValueError):
            inventory.build(self.root)

    def test_missing_reference_reported(self):
        self.put('public/music/manifest.json', json.dumps({'samples': [{'id': 'x', 'instrument': 'bell', 'file': 'missing.ogg', 'fallback': 'missing.m4a'}]}))
        result = inventory.build(self.root)
        self.assertEqual(len(result['references']), 2)
        self.assertTrue(all(not r['exists'] for r in result['references']))

    def test_traversal_rejected(self):
        for name in ('../secret', '/absolute', 'foo\\bar'):
            with self.assertRaises(ValueError):
                inventory.safe(self.root, name)

    def test_symlink_rejected(self):
        (self.root / 'public/link').symlink_to(self.root / 'game/view.mjs')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            inventory.build(self.root)

    def test_javascript_never_evaluated(self):
        self.put('game/moth-baked.mjs', 'export const MOTH_BAKED = runCode();')
        with self.assertRaises(ValueError):
            inventory.build(self.root)

    def test_wav_and_hash_mismatch(self):
        p = self.root / 'public/audio/announcer/test.wav'
        with wave.open(str(p), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(24000)
            w.writeframes(b'\0\0' * 24)
        self.put('public/audio/announcer/manifest.json', json.dumps({'clips': [{'file': 'test.wav', 'cue': 'test', 'sha256': 'wrong'}]}))
        result = inventory.build(self.root)
        record = next(f for f in result['files'] if f['path'].endswith('.wav'))
        self.assertEqual(record['wav']['frames'], 24)
        self.assertFalse(result['references'][0]['hash_matches_manifest'])

    def test_audit_outputs_excluded(self):
        before = inventory.render(inventory.build(self.root))
        self.put('port/asset-audit/inventory.json', 'ignored')
        self.assertEqual(before, inventory.render(inventory.build(self.root)))


if __name__ == '__main__':
    unittest.main()

"""Pure source guards only; never launch an engine or create native output."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
import json

from native_harness import HERE, IDENTITY, guard_output, validate_export


class HarnessContracts(unittest.TestCase):
    def test_route_endpoint_is_inside_preserved_wall_and_only_nav_changed(self):
        previous = json.loads((HERE.parent / 'revision2-corrective/candidate.json').read_text())
        current = json.loads((HERE / 'candidate.json').read_text())
        self.assertEqual(current['geometryHash'], IDENTITY)
        old, new = previous['arena'], current['arena']
        for key in ('terrain', 'blocks', 'spawns', 'pickups', 'objectiveZones',
                    'teamSpawns', 'flagSpawns', 'candidateModes'):
            self.assertEqual(new[key], old[key], key)
        changed = [i for i, (a, b) in enumerate(zip(old['navNodes'], new['navNodes'])) if a != b]
        self.assertEqual(changed, list(range(469, 475)))
        self.assertEqual(old['navNodes'][474], {'x': -76, 'z': -96})
        self.assertEqual(new['navNodes'][474], {'x': -77.5, 'z': -96})
        self.assertGreater(abs(new['navNodes'][474]['x'] - (-76)), .52 + .05)

    def test_requires_new_external_namespaced_non_symlink_root(self):
        with TemporaryDirectory(dir='/tmp/opencode') as directory:
            parent = Path(directory)
            allowed = parent / 'abyssal-corrective-V-unit'
            self.assertEqual(guard_output(allowed), allowed)
            for invalid in (parent, parent / 'native-T-20261003',
                            parent / 'abyssal-corrective-V-accepted',
                            parent / 'abyssal-corrective-V-worlds'):
                with self.assertRaises(ValueError):
                    guard_output(invalid)
            allowed.mkdir()
            with self.assertRaises(ValueError):
                guard_output(allowed)
            link = parent / 'abyssal-corrective-V-link'
            link.symlink_to(allowed, target_is_directory=True)
            with self.assertRaises(ValueError):
                guard_output(link)

    def test_rejects_wrong_and_truncated_export_before_geometry(self):
        with TemporaryDirectory(dir='/tmp/opencode') as directory:
            path = Path(directory) / 'bad.glb'
            path.write_bytes(b'glTF\x02')
            with self.assertRaisesRegex(ValueError, 'Missing, changed'):
                validate_export(path, {'glbSha256': 'wrong'})
            import hashlib
            with self.assertRaisesRegex(ValueError, 'Truncated GLB'):
                validate_export(path, {'glbSha256': hashlib.sha256(path.read_bytes()).hexdigest()})

if __name__ == '__main__':
    unittest.main()

"""Portable fail-closed loader tests; no real archive is required."""
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from archived_fixture import archive_bytes,archive_json,PINS,PROBES

class FixtureTests(unittest.TestCase):
    def test_explicit_root_required_even_inside_U_worktree(self):
        with patch.dict(os.environ,{},clear=True):
            with self.assertRaisesRegex(ValueError,'Set COCS_BOTANICAL'):archive_bytes(PROBES)

    def test_missing_file_fails_without_fallback(self):
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'COCS_BOTANICAL_U_FIXTURE_ROOT':tmp}):
            with self.assertRaises(FileNotFoundError):archive_bytes(PROBES)

    def test_wrong_hash_is_rejected_before_json_parse(self):
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'COCS_BOTANICAL_U_FIXTURE_ROOT':tmp}):
            p=Path(tmp)/PROBES;p.parent.mkdir(parents=True);p.write_bytes(b'not JSON')
            with self.assertRaisesRegex(ValueError,'SHA256 mismatch'):archive_json(PROBES)

    def test_unknown_path_and_escape_rejected(self):
        with self.assertRaisesRegex(ValueError,'Unpinned'):archive_bytes('../authority.json')
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'COCS_BOTANICAL_U_FIXTURE_ROOT':tmp}):
            p=Path(tmp)/PROBES;p.parent.mkdir(parents=True);p.symlink_to('/etc/hosts')
            with self.assertRaisesRegex(ValueError,'escapes'):archive_bytes(PROBES)

    def test_returns_the_verified_bytes(self):
        data=b'{"fixture":"loader unit test only"}'
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'COCS_BOTANICAL_U_FIXTURE_ROOT':tmp}),patch.dict(PINS,{PROBES:hashlib.sha256(data).hexdigest()}):
            p=Path(tmp)/PROBES;p.parent.mkdir(parents=True);p.write_bytes(data)
            self.assertEqual(archive_json(PROBES),{'fixture':'loader unit test only'})

if __name__=='__main__':unittest.main()

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from art_binding import art_bytes,inspect_pair,ARTS
from fixture_inputs import ROOT,SOURCE_PINS,sha

class ArtBinding(unittest.TestCase):
    def test_accepted_exact_parent_art_is_nonempty_and_counted_from_actual_glb(self):
        authority=(ROOT/SOURCE_PINS['accepted'][0]).read_bytes()
        record=inspect_pair('accepted',authority,art_bytes('accepted'))
        self.assertEqual(record['triangles'],54804);self.assertEqual(record['meshInstances'],11)
        self.assertEqual(len(record['materials']),11);self.assertFalse(record['nativeReady'])
    def test_accepted_art_cannot_substitute_for_candidate_even_with_valid_candidate_json(self):
        authority=(ROOT/SOURCE_PINS['candidate'][0]).read_bytes()
        with self.assertRaisesRegex(ValueError,'fallback forbidden'):
            inspect_pair('candidate',authority,art_bytes('accepted'))
    def test_static_json_without_recipe_is_rejected_even_if_supplied_byte_pin_is_updated(self):
        path,digest=SOURCE_PINS['accepted'];data=json.loads((ROOT/path).read_bytes());del data['recipeHash']
        raw=json.dumps(data).encode()
        with patch.dict(SOURCE_PINS,{'accepted':(path,sha(raw))}):
            with self.assertRaisesRegex(ValueError,'static substitution forbidden'):inspect_pair('accepted',raw,art_bytes('accepted'))
    def test_missing_and_tampered_candidate_files_do_not_fall_back(self):
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'COCS_BOTANICAL_X_FIXTURE_ROOT':tmp}):
            with self.assertRaises(FileNotFoundError):art_bytes('candidate')
            path=Path(tmp)/ARTS['candidate']['path'];path.parent.mkdir(parents=True);path.write_bytes(b'tampered')
            with self.assertRaisesRegex(ValueError,'SHA256 mismatch'):art_bytes('candidate')
if __name__=='__main__':unittest.main()

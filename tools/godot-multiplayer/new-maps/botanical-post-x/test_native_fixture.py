import json
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
import uuid
from unittest.mock import patch
from fixture_inputs import x_bytes,X_PINS,HERE,ROOT
from prepare_native import setup

class FutureFixture(unittest.TestCase):
    def test_source_cases_have_sixty_walk_native_trials(self):
        config=json.loads(subprocess.check_output(['node',str(HERE/'native_cases.mjs')],cwd=ROOT))
        self.assertEqual(len(config['groups']),6)
        self.assertEqual(sum(len(g['trials']) for g in config['groups'].values()),60)
        self.assertEqual({g['radius'] for g in config['groups'].values()},{.35,.42})
        for g in config['groups'].values():
            self.assertEqual(len(g['trials']),10)
            for t in g['trials']:
                self.assertEqual(t['start'][0],t['goal'][0])
                low,high=sorted([t['start'][1],t['goal'][1]])
                self.assertAlmostEqual(low,12 if g['run']=='civic' else 22,places=10)
                self.assertAlmostEqual(high,24,places=10)
    def test_missing_candidate_art_cannot_create_a_fixture_or_use_accepted_fallback(self):
        attempt='source-test-'+uuid.uuid4().hex
        dest=ROOT/'godot/tests/new_maps/botanical_post_x'/attempt
        with patch.dict(os.environ,{},clear=True):
            with self.assertRaisesRegex(ValueError,'no fallback'):setup(attempt)
        self.assertFalse(dest.exists())
    def test_pinned_archive_inputs_fail_closed(self):
        path=next(iter(X_PINS))
        with patch.dict(os.environ,{},clear=True):
            with self.assertRaisesRegex(ValueError,'Explicit'):x_bytes(path)
        with tempfile.TemporaryDirectory() as tmp,patch.dict(os.environ,{'COCS_BOTANICAL_X_FIXTURE_ROOT':tmp}):
            with self.assertRaises(FileNotFoundError):x_bytes(path)
            p=Path(tmp)/path;p.parent.mkdir(parents=True);p.write_text('{}')
            with self.assertRaisesRegex(ValueError,'hash mismatch'):x_bytes(path)
            with self.assertRaisesRegex(ValueError,'Unpinned'):x_bytes('unknown.glb')
if __name__=='__main__':unittest.main()

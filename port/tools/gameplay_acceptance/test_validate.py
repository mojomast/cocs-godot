import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

from validate import validate

CATALOG = Path(__file__).resolve().parents[2] / 'gameplay-acceptance/catalog.json'


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(CATALOG.read_text())

    def rejects(self, substring):
        self.assertTrue(any(substring in e for e in validate(self.data)), validate(self.data))

    def test_valid_catalog(self):
        self.assertEqual(validate(self.data), [])

    def test_missing_required_field(self):
        del self.data['scenarios'][0]['actions']
        self.rejects('scenarios.PICKUP-HEALTH.actions: expected nonempty list')

    def test_duplicate_scenario(self):
        self.data['scenarios'].append(copy.deepcopy(self.data['scenarios'][0]))
        self.rejects('duplicate ID PICKUP-HEALTH')

    def test_duplicate_evidence(self):
        self.data['evidence'].append(copy.deepcopy(self.data['evidence'][0]))
        self.rejects('duplicate ID core')

    def test_bad_reference(self):
        self.data['scenarios'][0]['evidence_refs'] = ['invented']
        self.rejects('unknown reference invented')

    def test_bad_dependency(self):
        self.data['scenarios'][0]['depends_on'] = ['missing']
        self.rejects('unknown reference missing')

    def test_self_dependency(self):
        self.data['scenarios'][0]['depends_on'] = ['PICKUP-HEALTH']
        self.rejects('self dependency')

    def test_missing_evidence_classification(self):
        del self.data['evidence'][0]['classification']
        self.rejects('expected explicit evidence classification')

    def test_invalid_classification(self):
        self.data['evidence'][0]['classification'] = 'passed'
        self.rejects('expected explicit evidence classification')

    def test_no_unearned_gameplay_pass(self):
        self.data['scenarios'][0]['acceptance_status'] = 'passed'
        self.rejects('validator is not gameplay proof')

    def test_wrong_types_do_not_crash(self):
        for value in [None, [], 3, 'catalog']:
            self.assertEqual(validate(value), ['catalog: expected object'])
        self.data['scenarios'] = [None, {'id': []}]
        self.rejects('expected object')

    def test_blank_text(self):
        self.data['scenarios'][0]['capture'] = [' ']
        self.rejects('capture[0]: expected nonblank string')

    def test_cli_valid(self):
        result = subprocess.run([sys.executable, '-B', str(Path(__file__).with_name('validate.py')), str(CATALOG)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('gameplay acceptance NOT evaluated', result.stdout)

    def test_cli_missing_file(self):
        result = subprocess.run([sys.executable, '-B', str(Path(__file__).with_name('validate.py')), str(CATALOG.with_name('does-not-exist.json'))], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('catalog:', result.stdout)


if __name__ == '__main__':
    unittest.main()

"""Source-only evidence-oracle tests; never starts the runner or native processes."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('kick_live', Path(__file__).with_name('kick-live.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class EvidenceOracle(unittest.TestCase):
    def fixture(self):
        records = [{'kind': 'setup'}, {'kind': 'input', 'input': {'melee': True}}]
        for index in range(6):
            records.append({'kind': 'accepted', 'event': {'id': index+10, 'time': index*.4,
                            'outcome': 'hit' if index < 3 else 'miss'},
                            'health': [{'health': 100}, {'health': [55, 10, 0, 0, 0, 0][index]}]})
        report = {'passed': True, 'events': [{'event': row['event'].copy()} for row in records[2:]], 'captures': []}
        return report, records

    def test_missing_native_images_cannot_pass(self):
        report, records = self.fixture()
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as folder:
            checks = runner.validate(report, records, Path(folder), 'chain')
        self.assertTrue(checks['same_ordered_ids'])
        self.assertTrue(checks['normal_health_progression'])
        self.assertFalse(all(checks.values()))
        self.assertFalse(checks['contact_10_step_1'])

    def test_duplicate_or_reordered_delivery_fails(self):
        report, records = self.fixture()
        report['events'][1] = report['events'][0]
        checks = runner.validate(report, records, Path('/nonexistent'), 'chain')
        self.assertFalse(checks['same_ordered_ids'])

    def test_unearned_damage_or_extra_acceptance_fails(self):
        report, records = self.fixture()
        records[2]['health'][1]['health'] = 54
        records.append(records[-1])
        checks = runner.validate(report, records, Path('/nonexistent'), 'chain')
        self.assertFalse(checks['normal_health_progression'])
        self.assertFalse(checks['bounded_actions'])
        self.assertFalse(checks['cooldowns'])


if __name__ == '__main__':
    unittest.main()

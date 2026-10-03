import unittest
from p_failure_diagnosis import applied_match, campaign, completed_failure


class DiagnosisTests(unittest.TestCase):
    def test_round_and_epoch_prevent_false_application_of_reused_sequence(self):
        received = {'round': 1, 'inputEpoch': 3, 'seq': 14}
        rows = [{'kind': 'applied', 'round': 2, 'inputEpoch': 3, 'inputSeq': 14},
                {'kind': 'applied', 'round': 1, 'inputEpoch': 4, 'inputSeq': 14}]
        self.assertEqual(applied_match(rows, received), [])
        matching = {'kind': 'applied', 'round': 1, 'inputEpoch': 3, 'inputSeq': 14}
        self.assertEqual(applied_match(rows + [matching], received), [matching])

    def test_gap_does_not_bridge_rounds_and_missing_application_is_retained(self):
        rows = [{'kind': 'received', 'round': 2, 'observedMs': 1},
                {'kind': 'received', 'round': 1, 'seq': 1, 'inputEpoch': 3, 'observedMs': 100, 'controls': {}},
                {'kind': 'received', 'round': 1, 'seq': 2, 'inputEpoch': 3, 'observedMs': 905, 'controls': {'x': 1}}]
        result = campaign(rows)
        self.assertEqual(result[0]['gap_ms'], 805)
        self.assertEqual(result[0]['applied'], [])
        self.assertIsNone(result[0]['next_received'])

    def test_running_or_passed_attempt_is_never_diagnosed_as_failure(self):
        for status in ['running', 'passed', 'unrun']:
            with self.assertRaises(ValueError):
                completed_failure({'attempts': {'x': [{'status': status}]}}, 'x')


if __name__ == '__main__': unittest.main()

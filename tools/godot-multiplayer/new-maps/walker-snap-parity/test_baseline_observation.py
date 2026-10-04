"""Regression for the reviewed P1: the observation factory must not assist."""
import re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
class BaselineObservation(unittest.TestCase):
    def test_observation_has_only_baseline_factory_and_one_step(self):
        text=(ROOT/'godot/tests/walker_snap_parity/diagnostic.gd').read_text()
        factories=re.findall(r'\b(\w+)\.new\(\)',text)
        self.assertEqual(factories,['Baseline'])
        self.assertNotIn('candidate_telemetry',text)
        self.assertNotIn(' as Original',text)
        self.assertNotIn(' as Parity',text)
        self.assertEqual(text.count('super.step_record(body,input)'),1)
        self.assertLess(text.index('Pair.compare(body,old)'),text.index('super.step_record(body,input)'))
        self.assertIn('receipt.comparisonCollected = true',text)
        self.assertIn('if allowed!=[GROUPS[0]]',text)
        self.assertNotRegex(text,r'body\.(move_and_collide|move_and_slide|global_position\s*=)')
if __name__=='__main__':unittest.main()

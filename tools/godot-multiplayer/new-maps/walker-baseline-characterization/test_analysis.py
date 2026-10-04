import math,unittest
from inspect_ak import inspect,HERE,ROOT,STAGE,load,chart_csv
class OfflineAnalysisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.report,cls.rows=inspect()
    def test_bound_frozen_observations_and_asymmetry(self):
        r=self.report;self.assertEqual(r['outcome'],'unexpected_baseline_arrival')
        self.assertEqual([(p['caseIndex'],p['role']) for p in r['profiles']],[(0,0),(0,1),(1,0),(1,1),(2,0)])
        self.assertEqual(len(self.rows),317)
        self.assertEqual(r['radius042Plus45'],'UNRUN; no symmetry inference')
    def test_contact_threshold_contrast_without_relabeling_guard(self):
        p=self.report['profiles'];small=p[0];large=p[-1]
        self.assertGreater(small['targetSlideAngleMin'],51)
        first=large['firstTargetSlide'];self.assertEqual(first['frame'],404)
        self.assertEqual(first['targetContactsStrict46Compatible'],0)
        self.assertEqual(first['targetContactsEngineAngleCompatible'],2)
        self.assertTrue(first['grounded']);self.assertFalse(first['onWall'])
        self.assertEqual(large['positiveYFrames'],[404,405,406,407,408])
    def test_baselines_unassisted_and_candidates_sustained(self):
        for p in self.report['profiles']:
            self.assertEqual(p['faults'],[])
            if not p['role']:self.assertEqual(p['appliedFrames'],[]);self.assertEqual(p['appliedUpCount'],0)
            else:self.assertEqual(len(p['appliedFrames']),1);self.assertEqual(p['verifiedLifts'],1);self.assertEqual(p['landingStreak'],7);self.assertTrue(p['tailSevenOrdinaryGrounded'])
    def test_fixed_height_design_within_strict_source_limit(self):
        text=(ROOT/'godot/tests/walker_step_up/sweep_proposal.gd').read_text()
        self.assertIn('const STEP_LIMIT := .25',text);self.assertIn('rise+GUARD>=STEP_LIMIT',text)
        for h in [.15,.18,.20]:self.assertLess(h+.0001,.25)
        self.assertEqual(len([(h,yaw) for h in [.15,.18,.20] for yaw in [-45,45]]),6)
        d=load(HERE/'design.json')
        self.assertEqual([(x['radius'],x['rise'],x['yawDegrees']) for x in d['matrix']],[(.35,.15,-45),(.35,.15,45)]+[(.42,h,y) for h in [.15,.18,.20] for y in [-45,45]])
        self.assertEqual(d['maximumTotalResponses'],len(d['matrix'])*(d['settleResponsesPerProfile']+d['maxInputResponsesPerProfile']))
        self.assertFalse(d['adaptiveHeightsOrRetries']);self.assertFalse(d['selectionDuringInvocation'])
    def test_serialized_analysis_is_reproducible(self):
        self.assertEqual(load(HERE/'comparison.json'),self.report)
        self.assertEqual((HERE/'frames.csv').read_text(),chart_csv(self.rows).replace('\r\n','\n'))
if __name__=='__main__':unittest.main()

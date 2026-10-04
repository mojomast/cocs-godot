"""Offline existing-receipt assertions, not native qualification."""
import copy,math,unittest
from analyze import *
class DiagnosisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.r=analyze(load(STAGE/'positive-step-admission-result.json'));cls.a=cls.r['applications'][-1]
    def test_frozen_inventory_and_current_sources(self):self.assertEqual(verify()['AMEntries'],60)
    def test_failed_normal_not_velocity_endpoint_or_plane(self):
        a=self.a;q=a['queries'][-1];c=q['contactAnalysis'][0]
        self.assertFalse(a['guardPassed']);self.assertEqual(a['endpointError'],0);self.assertEqual(a['epsilon'],1e-6)
        self.assertTrue(c['staticVelocityExactlyZero']);self.assertLess(c['pointPlaneErrorCanonical'],1e-6)
        self.assertFalse(a['planeGuardReached']);self.assertLess(c['normalAnalysis']['rawUpDot'],math.cos(a['parameters']['floorAngle']))
        self.assertAlmostEqual(c['normalAnalysis']['rawDotAngleDegrees'],47.47699234145,places=8)
        self.assertEqual(a['verifiedLifts'],0);self.assertFalse(a['reached'])
    def test_unit_length_does_not_explain_threshold_difference(self):
        for a in self.r['applications']:
            for q in a['queries']:
                for c in q['contactAnalysis']:
                    n=c['normalAnalysis'];self.assertLess(n['unitLengthError'],1e-7)
                    self.assertLess(abs(n['normalizedAngleDegrees']-n['rawDotAngleDegrees']),1e-5)
        n=self.a['queries'][-1]['contactAnalysis'][0]['normalAnalysis']
        self.assertGreater(n['normalizedAngleDegrees'],46+math.degrees(.01))
    def test_queries_distinct_same_target_and_full_basis(self):
        a=self.a;old,short,full,guard=a['queries'];o=old['rawRequestResponse'];s=short['rawRequestResponse'];f=full['rawRequestResponse'];g=guard['rawRequestResponse']
        for key in ['from','motion','travel','safeFraction','unsafeFraction']:self.assertEqual(o[key],s[key])
        self.assertEqual(f['from']['basis'],g['from']['basis']);self.assertNotEqual(f['from']['origin'],g['from']['origin'])
        self.assertEqual(f['maxCollisions'],4);self.assertEqual(g['maxCollisions'],32)
        rid=f['contacts'][0]['colliderRid'];identity=guard['contactAnalysis'][0]['resolvedIdentityTelemetry']
        self.assertEqual(identity['colliderRid'],rid);self.assertEqual(identity['colliderShapeIndex'],0);self.assertEqual(identity['localShapeIndex'],0)
        self.assertEqual(f['contacts'][0]['colliderId'],g['contacts'][0]['colliderId']);self.assertIsNone(guard['contactAnalysis'][0]['ridDirectlyRecorded'])
    def test_full4_matches_returned_floor_not_internal_trace(self):
        a=self.a;f=a['queries'][2]['rawRequestResponse']
        self.assertEqual(f['contacts'][0]['normal'],a['actualParent']['after']['floorNormal'])
        self.assertAlmostEqual(f['travel'][1],a['actualParent']['parentPositionDelta'][1],places=12)
        self.assertIsNone(a['actualParent']['internalSnapRequest']);self.assertFalse(a['preflightAtPredictedEndpointRecorded'])
        self.assertTrue(a['guardFromMatchesActual'])
    def test_pass_controls_also_have_distinct_normals(self):
        for a in self.r['applications'][:2]:
            self.assertTrue(a['guardPassed']);self.assertEqual(a['verifiedLifts'],1)
            self.assertAlmostEqual(a['actualParent']['floorNormalAnalysis']['rawDotAngleDegrees'],34.91021256,places=6)
            self.assertAlmostEqual(a['queries'][-1]['contactAnalysis'][0]['normalAnalysis']['rawDotAngleDegrees'],36.67732574,places=6)
    def test_conditional_recovery_arithmetic_not_requested_down_endpoint(self):
        q=self.a['queries'][-1];v=q['rawRequestResponse'];res=q['conditionalGodotPhysicsRecoveryResidual']
        self.assertEqual(v['safeFraction'],1);self.assertEqual(v['unsafeFraction'],1)
        self.assertGreater(res[1],0);self.assertGreater(abs(res[0]),.008)
        self.assertNotEqual(q['conditionalGodotPhysicsRestSampleOrigin'],[x+y for x,y in zip(v['from']['origin'],v['motion'])])
        self.assertAlmostEqual(q['conditionalGodotPhysicsRestSampleOrigin'][1],.04573061876,places=10)
    def test_export_reproducible_and_raw_preserved(self):
        self.assertEqual(load(HERE/'comparison.json'),self.r)
        changed=copy.deepcopy(load(STAGE/'positive-step-admission-result.json'))
        changed['records'][2]['profiles'][1]['frames'][-1]['proposal']['responseGuard']['support']['contacts'][0]['normal']=[0,1,0]
        self.assertNotEqual(analyze(changed),self.r)
if __name__=='__main__':unittest.main()

import math,unittest
from inspect_ai import inspect,typed_numeric_member,HERE,ROOT,STAGE

class SourceDiagnosisTests(unittest.TestCase):
    def test_actual_frozen_AI_and_dual_host_replay(self):
        r=inspect()
        self.assertEqual(r['modeledMembershipFailures'],678)
        self.assertEqual(r['profilesHostPassed'],68)
        self.assertEqual(r['firstWitness']['pointer'],'/records/0/profiles/1/settle/0/appliedUpCount')
        self.assertTrue(r['allJSONIntegersBelow2pow53'])
    def test_targeted_membership_model_is_not_python_numeric_equality(self):
        for v in [0.0,1.0]:
            self.assertIn(v,[0,1])
            self.assertFalse(typed_numeric_member(v,[0,1]))
        for v in [0,1]:self.assertTrue(typed_numeric_member(v,[0,1]))
        for v in [False,True,-1,2,.5,None,'0']:self.assertFalse(typed_numeric_member(v,[0,1]))
    def test_proposed_numeric_contract_rejects_nonfinite_and_bool(self):
        # Proposed fix contract ONLY, never installed in acceptance predicates.
        def contract(v):return type(v) in (int,float) and math.isfinite(v) and (v==0 or v==1)
        for v in [0,1,0.,1.]:self.assertTrue(contract(v))
        for v in [False,True,-1,2,.5,None,'0',math.inf,math.nan]:self.assertFalse(contract(v))
    def test_original_predicates_and_driver_unchanged_and_not_wired(self):
        for name in ['policy.gd','evidence.gd','driver.gd']:
            self.assertEqual((ROOT/'godot/tests/walker_parity_admission'/name).read_bytes(),(STAGE/'tests/walker_parity_admission'/name).read_bytes())
        driver=(STAGE/'tests/walker_parity_admission/driver.gd').read_text()
        finish=driver.split('func finish(',1)[1].split('func predecessors(',1)[0]
        self.assertNotIn('Policy.successful',finish)
        self.assertNotIn('diagnostic.gd',driver)
    def test_diagnostic_has_no_entrypoint_or_effectful_calls(self):
        gd=(HERE/'diagnostic.gd').read_text()
        for token in ['FileAccess','OS.','PhysicsServer','Node3D','func _initialize','static var','printerr','quit(','store_string']:
            self.assertNotIn(token,gd)
        self.assertIn('up in [0,1]',gd)
        self.assertIn('report.location = "Evidence.profile.undetermined"',gd)
        self.assertIn('"nativeCountersKnown":false',gd)
        self.assertIn('records.size()!=34',gd)
        self.assertIn('settles.size()>20',gd)
        self.assertIn('frames.size()>2',gd)

if __name__=='__main__':unittest.main()

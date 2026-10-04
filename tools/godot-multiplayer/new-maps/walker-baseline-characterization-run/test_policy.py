import copy,json,math,unittest
from policy import *
from receipt_fixtures import receipt,SOURCE,GRANT,DEPS
class PolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.r=receipt()
    def rejected(self,change):
        r=copy.deepcopy(self.r);change(r);self.assertFalse(successful(r,SOURCE,GRANT,ENGINE))
    def test_complete_mixed_collection(self):
        self.assertTrue(successful(self.r,SOURCE,GRANT,ENGINE));self.assertIn('unresolved_at_cap',replay(self.r,SOURCE,GRANT,ENGINE))
    def test_all_json_numbers_as_doubles(self):
        r=json.loads(json.dumps(self.r),parse_int=float);self.assertTrue(successful(r,SOURCE,GRANT,ENGINE))
    def test_reference_contradiction_collects_without_selection(self):
        r=receipt(['arrived']*8);self.assertTrue(successful(r,SOURCE,GRANT,ENGINE));self.assertFalse(r['referenceAgreement']);self.assertIsNone(r['selectedHeight'])
    def test_matrix_drop_duplicate_reorder(self):
        for action in [lambda r:r['records'].pop(),lambda r:r['records'].__setitem__(1,copy.deepcopy(r['records'][0])),lambda r:r['records'].reverse()]:self.rejected(action)
    def test_height_and_plane_mutations(self):
        for key,val in [('rise',.15),('rise',float('nan')),('radius',.35),('yawDegrees',0)]:
            self.rejected(lambda r,k=key,v=val:r['records'][6]['spec'].__setitem__(k,v))
        self.rejected(lambda r:r['records'][6]['geometry']['target'].__setitem__('plane',.15))
        self.rejected(lambda r:r['records'][6]['geometry']['target']['faces'][0].__setitem__(1,.15))
    def test_support_actual_transform_and_query_flags(self):
        for key,val in [('motion',[0,.0201,0]),('recoveryAsCollision',False),('collideSeparationRay',False),('excludeBodies',[300]),('safeFraction',.9),('bodyRid',999),('maxCollisions',64)]:
            self.rejected(lambda r,k=key,v=val:r['records'][0]['frames'][-1]['support'].__setitem__(k,v))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['support']['from']['origin'].__setitem__(1,.15))
    def test_support_mutation_and_nonfinite(self):
        self.rejected(lambda r:r['records'][0]['frames'][-1]['support']['after']['velocity'].__setitem__(0,1))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['support']['contacts'][0]['normal'].__setitem__(1,float('inf')))
    def test_block_requires_every_target_witness_and_intent(self):
        self.rejected(lambda r:r['records'][0]['frames'][-80].__setitem__('slides',[]))
        self.rejected(lambda r:r['records'][0]['frames'][-1].__setitem__('input',[0,0]))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['slides'][0].__setitem__('rid',999))
    def test_mixed_steep_target_base_support_allowed_not_walkable_target(self):
        self.assertTrue(successful(self.r,SOURCE,GRANT,ENGINE))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['support']['contacts'][1].__setitem__('normal',[0,1,0]))
    def test_false_floor_and_missing_base(self):
        self.rejected(lambda r:r['records'][0]['frames'][-1]['support']['contacts'][0].__setitem__('point',[0,.1,0]))
        self.rejected(lambda r:r['records'][0]['settle'][-1]['support'].__setitem__('hit',False))
    def test_arrival_requires_three_support_frames(self):
        self.rejected(lambda r:r['records'][2]['frames'][-2]['support'].__setitem__('hit',False))
        self.rejected(lambda r:r['records'][2]['frames'][-1]['support']['contacts'][0]['point'].__setitem__(1,.20))
    def test_unresolved_is_not_blocked(self):
        self.rejected(lambda r:r['records'][3].__setitem__('outcome','blocked_with_target_witness'))
        self.rejected(lambda r:r['records'][3]['frames'].pop())
    def test_clock_reset_teleport_motion_and_parameters(self):
        for key,val in [('frame',9999),('delta',.02),('timeScale',True),('timeScale',1.0000001),('parentCalls',True),('parentCalls',1.0000001)]:self.rejected(lambda r,k=key,v=val:r['records'][0]['frames'][-1].__setitem__(k,v))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['before']['transform']['origin'].__setitem__(1,.1))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['after']['parentDelta'].__setitem__(1,.1))
        self.rejected(lambda r:r['records'][0]['frames'][-1]['parameters'].__setitem__('snap',.4))
        self.rejected(lambda r:r.__setitem__('finishedUnix',100))
    def test_faults_and_unknown_outcomes_never_success(self):
        for outcome in ['fault','unrun_after_fault','unknown']:
            self.rejected(lambda r,o=outcome:r['records'][0].__setitem__('outcome',o))
        self.rejected(lambda r:r.__setitem__('outcome','unknown_fault'))
        self.rejected(lambda r:r.__setitem__('selectedHeight',.18))
        self.rejected(lambda r:r.__setitem__('faultCode','unknown'))
        self.rejected(lambda r:r['records'][0].__setitem__('parameters',[]))
    def test_grant_exact_schema_expiry_engine_scope(self):
        g=dict(phase=PHASE,mode=MODE,allowedGroups=[GROUP],grantId='FUTURE-TEST-ONLY',authorized=True,expiresUnix=101,sourceSha256=SOURCE,engineSha256=ENGINE)
        def check(v):validate(v,group=GROUP,mode=MODE,grant_id=g['grantId'],source_hash=SOURCE,engine_hash=ENGINE,now=100)
        check(g)
        for key,value in [('expiresUnix',100),('expiresUnix',True),('expiresUnix',float('inf')),('allowedGroups',[GROUP,GROUP]),('phase','parity-admission-synthetic-v1'),('engineSha256','d'*64),('extra',0)]:
            with self.assertRaises(ValueError):check(g|{key:value})
if __name__=='__main__':unittest.main()

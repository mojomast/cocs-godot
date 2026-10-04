"""Complete synthetic receipts and frozen read-only lineage; no native staging."""
import copy,hashlib,importlib.util,json,math,sys,unittest
from pathlib import Path
from unittest.mock import patch
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('_calibrated_test_loader',HERE/'cli.py');loader=importlib.util.module_from_spec(spec);spec.loader.exec_module(loader)
policy=loader.module('policy');evidence=loader.module('evidence');fixtures=loader.module('receipt_fixtures');prepare=loader.module('prepare');derive=loader.module('derive_sources')
class CalibratedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.receipts={g:fixtures.campaign_fixture(g) for g in policy.GROUPS}
    def mutate(self,change,group=policy.GROUPS[2]):
        r=copy.deepcopy(self.receipts[group]);change(r);self.assertFalse(policy.successful(r,group,'s','g','e'))
    def test_complete_new_receipts_all_groups_and_double_numbers(self):
        for group,r in self.receipts.items():
            self.assertTrue(policy.successful(r,group,'s','g','e'))
            self.assertTrue(policy.successful(json.loads(json.dumps(r),parse_int=float),group,'s','g','e'))
    def test_exact_positive_matrix_no_020_fallback(self):
        specs=evidence.canonical(policy.GROUPS[2]);self.assertEqual([(s['radius'],s['rise'],round(math.degrees(s['yaw']))) for s in specs],[(.35,.15,-45),(.35,.15,45),(.42,.18,-45),(.42,.18,45)])
        self.mutate(lambda r:r['records'][2]['spec'].__setitem__('rise',.20))
        self.mutate(lambda r:r['records'][2]['spec'].__setitem__('radius',.35))
        self.mutate(lambda r:r['records'][2]['spec'].__setitem__('rise',float('nan')))
    def test_selection_is_external_to_immutable_AL_and_bound_to_actual_counts(self):
        selection=prepare.load(HERE/'selection.json')
        path=prepare.ROOT/'godot/tests/walker_baseline_characterization/baseline-characterization-al-01/radius-rise-result.json';al=prepare.load(path)
        self.assertEqual(prepare.sha(path),selection['ALNativeSha256']);self.assertIsNone(al['selectedHeight'])
        self.assertEqual(sum(len(p['settle'])+len(p['frames']) for p in al['records']),selection['ALSupportObservations'])
        self.assertEqual(sum(p['blockedStreak'] for p in al['records']),selection['ALBlockedWindowResponses'])
        self.assertTrue(al['referenceAgreement']);self.assertEqual(al['records'][3]['outcome'],'arrived')
        for i in [4,5]:self.assertEqual(al['records'][i]['outcome'],'blocked_with_target_witness');self.assertEqual(al['records'][i]['spec']['rise'],.18)
        self.assertIsNone(selection['fallbackHeight']);self.assertFalse(selection['candidateFeasibilityEstablished'])
    def test_negative_and_inclined_census_exactly_match_original(self):
        spec=importlib.util.spec_from_file_location('_calibrated_original_evidence_test',derive.OLD/'evidence.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
        self.assertEqual(evidence.IDS,old.IDS);self.assertEqual(evidence.REASONS,old.REASONS)
        for group in policy.GROUPS[:2]:self.assertEqual(evidence.canonical(group),old.canonical(group))
    def test_positive_wrong_015_plan_and_guard_support_rejected(self):
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0]['proposal'].__setitem__('landingY',.15))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0]['proposal']['responseGuard']['support']['contacts'][0]['point'].__setitem__(1,.15))
    def test_wrong_015_final_support_and_actual_mesh_rejected(self):
        self.mutate(lambda r:r['records'][2]['profiles'][1]['finalSupport']['query']['contacts'][0]['point'].__setitem__(1,.15))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['geometry'][0]['shapeData']['faces'][0].__setitem__(1,.15))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['target']['faces'][0].__setitem__(1,.15))
    def test_group_requires_all_four_pairs(self):
        self.mutate(lambda r:r['records'].pop())
        self.mutate(lambda r:r['records'].__setitem__(3,copy.deepcopy(r['records'][2])))
        self.mutate(lambda r:r.__setitem__('completedPairs',3))
        self.mutate(lambda r:r['records'][3].__setitem__('status','unrun'))
    def test_arrival_without_verified_lift_fails(self):
        self.mutate(lambda r:r['records'][2]['profiles'][1].__setitem__('verifiedLifts',0))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0].__setitem__('appliedUpCount',0))
    def test_baseline_every_stall_requires_target_not_wrong_wall(self):
        self.mutate(lambda r:r['records'][2]['profiles'][0]['frames'][-60].__setitem__('slides',[]))
        self.mutate(lambda r:r['records'][2]['profiles'][0]['frames'][-1]['slides'][0].__setitem__('colliderRid',999))
        self.mutate(lambda r:r['records'][2]['profiles'][0]['frames'][-1].__setitem__('input',[0,0]))
        self.mutate(lambda r:r['records'][2]['profiles'][0].__setitem__('reached',True))
    def test_p1_forward_and_guard_operands_not_relaxed(self):
        for key,value in [('horizontalBudget',[0,0,0]),('expectedFinal',[0,.18,1]),('upMotion',[.01,.2,0])]:
            self.mutate(lambda r,k=key,v=value:r['records'][2]['profiles'][1]['frames'][0]['proposal'].__setitem__(k,v))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0]['proposal']['responseGuard'].__setitem__('epsilon',.001))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0]['proposal']['responseGuard']['support'].__setitem__('motion',[0,.0201,0]))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0]['proposal']['responseGuard']['support'].__setitem__('recoveryAsCollision',False))
    def test_terminal_fault_and_interrupted_counts_never_pass(self):
        self.mutate(lambda r:r.__setitem__('failedProfiles',1));self.mutate(lambda r:r.__setitem__('interruptedPairs',1))
        self.mutate(lambda r:r['records'][2]['profiles'][1]['frames'][0].__setitem__('candidateFault','parity_policy_rejected:test'))
    def test_original_receipts_cannot_be_calibrated_prerequisites(self):
        ak=prepare.ROOT.parent/'cocs-walker-parity-admission-ak/godot/tests/walker_parity_admission/parity-admission-ak-01'
        for group in policy.GROUPS[:2]:
            r=prepare.load(ak/(group+'-result.json'));self.assertFalse(policy.successful(r,group,r['sourceSha256'],r['grantSha256'],r['engineSha256']))
        al=prepare.load(prepare.ROOT/'godot/tests/walker_baseline_characterization/baseline-characterization-al-01/radius-rise-result.json')
        self.assertFalse(policy.successful(al,policy.GROUPS[2],al['sourceSha256'],al['grantSha256'],al['engineSha256']))
        self.mutate(lambda r:r['records'][2]['profiles'].__setitem__(0,copy.deepcopy(al['records'][4])))
    def test_new_grant_scope_engine_and_finite_expiry(self):
        g=dict(phase=policy.PHASE,mode=policy.MODE,allowedGroups=policy.GROUPS,grantId='TEST-NOT-AUTHORITY',authorized=True,expiresUnix=101,sourceSha256='a'*64,engineSha256=policy.ENGINE)
        def check(x):policy.validate(x,group=policy.GROUPS[2],mode=policy.MODE,grant_id=g['grantId'],source_hash='a'*64,engine_hash=policy.ENGINE,now=100)
        check(g)
        for k,v in [('phase','parity-admission-synthetic-v1'),('allowedGroups',policy.GROUPS[::-1]),('expiresUnix',100),('expiresUnix',True),('expiresUnix',float('inf')),('extra',0)]:
            with self.assertRaises(ValueError):check(g|{k:v})
    def test_predecessors_exact_fresh_headers_audits_and_logs(self):
        group=policy.GROUPS[1];r=self.receipts[policy.GROUPS[0]];s=fixtures.supervisor_fixture(native_hash='h')
        with patch.object(prepare,'load',side_effect=[r,s]),patch.object(prepare,'sha',return_value='h'),patch.object(Path,'read_text',return_value='banner\n'):
            self.assertEqual(len(prepare.dependencies(prepare.ROOT,group,'s','g','e')['predecessors']),1)
        bad=copy.deepcopy(s);bad['releaseAudits'][1]['utc']=bad['releaseAudits'][0]['utc']
        with patch.object(prepare,'load',side_effect=[r,bad]),patch.object(prepare,'sha',return_value='h'),self.assertRaises(ValueError):prepare.dependencies(prepare.ROOT,group,'s','g','e')
        with patch.object(prepare,'load',side_effect=[r,s]),patch.object(prepare,'sha',return_value='h'),patch.object(Path,'read_text',return_value='ADMISSION_FAILURE {}'),self.assertRaises(ValueError):prepare.dependencies(prepare.ROOT,group,'s','g','e')
        with patch.object(prepare,'load',side_effect=FileNotFoundError()),self.assertRaises(FileNotFoundError):prepare.dependencies(prepare.ROOT,group,'s','g','e')
    def test_derived_delta_and_exact_candidate_guard_methods(self):
        for dest,(_,text) in derive.render().items():self.assertEqual(dest.read_text(),text)
        stage=prepare.ROOT.parent/'cocs-walker-parity-admission-ak/godot/tests/walker_parity_admission/parity-admission-ak-01'
        for n in ['exploration/walker.gd','tests/walker_parity_admission/candidate.gd','tests/walker_parity_response/planner.gd','tests/walker_snap_parity/planner.gd','tests/walker_snap_parity/query_pair.gd','tests/walker_step_up/response_guard.gd','tests/walker_step_up/sweep_proposal.gd','tests/walker_step_up/controls_v2.gd','tests/walker_admission/fixtures_v4.gd']:
            self.assertEqual((prepare.ROOT/'godot'/n).read_bytes(),(stage/n).read_bytes(),n)
        old=(derive.GD/'evidence.gd').read_text();new=(derive.NEWGD/'evidence.gd').read_text()
        for name,nextname in [('guarded','guard_operands'),('guard_operands','supervisor_ok')]:
            def body(t):return t.split('static func '+name+'(',1)[1].split('static func '+nextname+'(',1)[0]
            self.assertEqual(body(old),body(new))
    def test_module_cache_names_are_not_shadowed(self):
        before={k:sys.modules.get(k) for k in ['policy','prepare','evidence','receipt_fixtures']}
        loader.module('supervisor');self.assertEqual(before,{k:sys.modules.get(k) for k in before})
        self.assertTrue(policy.__name__.startswith('_calibrated_admission_'))
    def test_source_contract_and_write_once_mock_no_stage(self):
        pins=prepare.load(HERE/'review-pins.json');prepare.verify_inputs(prepare.ROOT,pins)
        c=prepare.source('calibrated-admission-review-only',pins);self.assertEqual(c['positiveCases'],evidence.canonical(policy.GROUPS[2]));self.assertFalse(c['autoStart']);self.assertIsNone(c['grant'])
        with patch.object(Path,'exists',return_value=True),patch.object(prepare,'write') as write:
            with self.assertRaises(FileExistsError):prepare.build('calibrated-admission-review-only','unused','unused')
        write.assert_not_called()
if __name__=='__main__':unittest.main()

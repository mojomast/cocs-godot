"""P1 regressions: serialized traces and actual mocked supervisor/dependency path.

GDScript checks here are structural only. No parser or native evaluation occurs.
"""
import copy,json,math,re,tempfile,unittest
from pathlib import Path
from evidence import canonical,IDS,REASONS,supervisor_ok
from policy import GROUPS,successful
from prepare import HERE,ROOT,sha,dependencies
from receipt_fixtures import campaign_fixture,supervisor_fixture
import test_admission as previous_tests

def duplicated_empty(r):
    for row in r['records']:
        row['spec']={'id':'no-input','radius':.35}
        for p in row['profiles']:p.update(settle=[],frames=[],outcome='never_executed')
def empty_traces(r):
    for row in r['records']:
        for p in row['profiles']:p.update(settle=[],frames=[])

class ActualPathTests(unittest.TestCase):
    setUp=previous_tests.PreparationTests.setUp;tearDown=previous_tests.PreparationTests.tearDown;build=previous_tests.PreparationTests.build;invoke=previous_tests.SupervisorTests.invoke
    def test_reviewer_duplicate_empty_child_cannot_admit_or_chain(self):
        code,receipt=self.invoke(native_mutation=duplicated_empty,check_dependency=True)
        self.assertEqual(code,1);self.assertTrue(receipt['failed']);self.assertTrue(receipt['releasedCleanly']);self.assertIsNotNone(receipt['nativeReceiptSha256'])
    def test_valid_census_empty_trace_child_cannot_admit_or_chain(self):
        code,receipt=self.invoke(native_mutation=empty_traces,check_dependency=True)
        self.assertEqual(code,1);self.assertTrue(receipt['failed']);self.assertTrue(receipt['releasedCleanly'])

class CampaignTests(unittest.TestCase):
    def check(self,r,group):return successful(json.loads(json.dumps(r)),group,'s','g','e')
    def test_complete_serialized_operands_for_all_three_groups(self):
        for group in GROUPS:self.assertTrue(self.check(campaign_fixture(group),group),group)
    def test_exact_order_census_not_deduplicated(self):
        for group in GROUPS:
            source=campaign_fixture(group)
            for mutation in ['missing','duplicate','reverse','radius','substitute','yaw']:
                if group==GROUPS[0] and mutation=='yaw':continue
                with self.subTest(group=group,mutation=mutation):
                    r=copy.deepcopy(source)
                    if mutation=='missing':r['records'].pop()
                    if mutation=='duplicate':r['records'][1]['spec']=copy.deepcopy(r['records'][0]['spec'])
                    if mutation=='reverse':r['records'][0]['spec'],r['records'][1]['spec']=r['records'][1]['spec'],r['records'][0]['spec']
                    if mutation=='radius':r['records'][0]['spec']['radius']=.42
                    if mutation=='substitute':r['records'][0]['spec']['id']='not-the-fixture'
                    if mutation=='yaw':r['records'][0]['spec']['yaw']=0
                    self.assertFalse(self.check(r,group))
    def test_trace_outcome_parameter_clock_and_witness_mutations(self):
        for name in ['empty','outcome','settle-count','input-count','clock','returned','reason','witness','radius','kinematic-pair','interrupted']:
            with self.subTest(name=name):
                r=campaign_fixture(GROUPS[0]);p=r['records'][0]['profiles'][1]
                if name=='empty':p['frames']=[]
                if name=='outcome':p['outcome']='never_executed'
                if name=='settle-count':p['settle'].pop()
                if name=='input-count':p['frames']*=2
                if name=='clock':p['frames'][0]['frame']+=1
                if name=='returned':p['frames'][0]['returned']=False
                if name=='reason':p['frames'][0]['proposal']['reason']='no_input'
                if name=='witness':p['frames'][0]['proposal']['stages']=[]
                if name=='radius':p['parameters']['shape']['radius']=.42
                if name=='kinematic-pair':
                    for row in p['settle']+p['frames']:
                        row['before']['transform']['origin'][0]=.01;row['after']['transform']['origin'][0]=.01
                if name=='interrupted':p['status']='interrupted'
                self.assertFalse(self.check(r,GROUPS[0]))
    def test_ab_variable_counts_and_jump_intent(self):
        r=campaign_fixture(GROUPS[0]);rows={x['spec']['id']:x for x in r['records']}
        self.assertEqual(len(rows['airborne']['profiles'][0]['settle']),1)
        self.assertEqual(len(rows['jumping']['profiles'][0]['settle']),20)
        self.assertEqual(len(rows['jumping']['profiles'][0]['frames']),2)
        rows['jumping']['profiles'][1]['frames'][0]['jump']=False
        self.assertFalse(self.check(r,GROUPS[0]))
    def test_inclined_headon_lowband_identity_and_stall(self):
        for change in ['normal','point','path','stall','target','empty']:
            with self.subTest(change=change):
                r=campaign_fixture(GROUPS[1]);p=r['records'][0]['profiles'][1]
                c=p['frames'][0]['proposal']['stages'][0]['contacts'][0]
                if change=='normal':c['normal']=[0,1,0]
                if change=='point':c['point'][1]=.3
                if change=='path':c['collider']='/root/Other'
                if change=='stall':p['stallCount']=119
                if change=='target':p['target']['faces'][0][1]=.16
                if change=='empty':p['frames']=[]
                self.assertFalse(self.check(r,GROUPS[1]))
    def test_positive_claims_require_applied_lift_and_arrival_operands(self):
        for change in ['no-up','no-guard','no-query','wrong-rid','no-hold','wrong-footprint','baseline-stall','no-baseline-target']:
            with self.subTest(change=change):
                r=campaign_fixture(GROUPS[2]);base,p=r['records'][0]['profiles'];row=p['frames'][0]
                if change=='no-up':row['appliedUpCount']=0
                if change=='no-guard':row['proposal']['responseGuard']['passed']=False
                if change=='no-query':row['telemetry']['finalSupportQueryReached']=False
                if change=='wrong-rid':p['finalSupport']['query']['contacts'][0]['colliderRid']=999
                if change=='no-hold':p['ordinaryLandingStreak']=2
                if change=='wrong-footprint':p['frames'][-1]['after']['transform']['origin']=[0,.15,0]
                if change=='baseline-stall':base['stallCount']=119
                if change=='no-baseline-target':del base['target']
                self.assertFalse(self.check(r,GROUPS[2]))
    def test_numeric_booleans_and_malformed_records(self):
        for bad in [None,False,'x',[],{}]:
            r=campaign_fixture(GROUPS[0]);r['records'][0]['profiles'][0]['frames'][0]=bad
            self.assertFalse(self.check(r,GROUPS[0]))
        r=campaign_fixture(GROUPS[0]);r['records'][0]['profiles'][0]['frames'][0]['timeScale']=True
        self.assertFalse(self.check(r,GROUPS[0]))

class SupervisorReceiptTests(unittest.TestCase):
    def test_independent_contradictions_reject_real_file_dependency_path(self):
        native=campaign_fixture(GROUPS[0])
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as tmp:
            dest=Path(tmp);result=dest/(GROUPS[0]+'-result.json');receipt=dest/(GROUPS[0]+'-supervisor.json');result.write_text(json.dumps(native))
            good=supervisor_fixture(native_hash=sha(result));receipt.write_text(json.dumps(good))
            self.assertEqual(len(dependencies(dest,GROUPS[1],'s','g','e')['predecessors']),1)
            changes={'returnCode':-9,'stopReason':'engine_script_error','supervisorError':'failure','invalidNativeReceipt':'partial','phase':'old','mode':'single-response','failed':0,'releasedCleanly':1,'partialCountersMayBeUnknown':True,'cleanupErrors':[{'operation':'failed'}],'nativeReceiptSha256':'wrong','lockReleasePendingUnix':1791072001.,'positiveAdmission':True,'nativeOutcome':'never_executed'}
            for key,value in changes.items():
                with self.subTest(key=key):
                    s=copy.deepcopy(good);s[key]=value;receipt.write_text(json.dumps(s))
                    self.assertFalse(supervisor_ok(s,GROUPS[0],'s','g','e',sha(result)))
                    with self.assertRaises(ValueError):dependencies(dest,GROUPS[1],'s','g','e')
            for problem in ['duplicate','unparseable','invalid-date','reverse','false','zero','survivor','error','no-owner','reused-identity','zero-return-bool']:
                with self.subTest(problem=problem):
                    s=copy.deepcopy(good);a=s['releaseAudits']
                    if problem=='duplicate':a[1]['utc']=a[0]['utc']
                    if problem=='unparseable':a[1]['utc']='later'
                    if problem=='invalid-date':a[1]['utc']='2026-02-30T00:00:02.000000+00:00'
                    if problem=='reverse':a.reverse()
                    if problem=='false':a[1]['measured']=False
                    if problem=='zero':a[1]['measured']=0
                    if problem=='survivor':a[1]['members']=[{'pid':456}]
                    if problem=='error':a[1]['error']='permission'
                    if problem=='no-owner':del s['owned']
                    if problem=='reused-identity':s['owned']['pgid']=999
                    if problem=='zero-return-bool':s['returnCode']=False
                    receipt.write_text(json.dumps(s))
                    with self.assertRaises(ValueError):dependencies(dest,GROUPS[1],'s','g','e')
    def test_native_failure_never_overridden_by_clean_release(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as tmp:
            dest=Path(tmp);p=dest/(GROUPS[0]+'-result.json');r=campaign_fixture(GROUPS[0]);r['failed']=True;p.write_text(json.dumps(r))
            (dest/(GROUPS[0]+'-supervisor.json')).write_text(json.dumps(supervisor_fixture(native_hash=sha(p))))
            with self.assertRaises(ValueError):dependencies(dest,GROUPS[1],'s','g','e')

class StructuralParityTests(unittest.TestCase):
    def test_frozen_census_and_both_call_paths(self):
        gd=(ROOT/'godot/tests/walker_parity_admission/evidence.gd').read_text()
        self.assertEqual(json.loads(re.search(r'const IDS := (\[.*\])',gd)[1]),IDS)
        self.assertEqual(json.loads(re.search(r'const REASONS := (\[.*\])',gd)[1]),REASONS)
        controls=(ROOT/'godot/tests/walker_step_up/controls_v2.gd').read_text()
        self.assertEqual(json.loads(re.search(r'return (\[.*?\])',controls,re.S)[1]),IDS)
        self.assertIn('return Evidence.campaign(r,group)',(ROOT/'godot/tests/walker_parity_admission/policy.gd').read_text())
        self.assertIn('Policy.Evidence.supervisor_ok(s,prior,source_hash,grant_hash,engine_hash,h.resultSha256)',(ROOT/'godot/tests/walker_parity_admission/driver.gd').read_text())
        # Structural correspondence only: field presence and common function set
        # expose accidental missing branches; they do not execute GDScript.
        py=(HERE/'evidence.py').read_text()
        functions=['canonical','spec_equal','profile','campaign','target','inclined_witness','support','footprint','supervisor_ok']
        for name in functions:self.assertIn('def '+name+'(',py);self.assertIn('static func '+name+'(',gd)
        fields=['returnCode','stopReason','supervisorError','invalidNativeReceipt','cleanupErrors','releaseAudits','lockAcquiredUnix','lockReleasePendingUnix','owned','startTicks','ordinaryLandingStreak','targetRid','finalSupport','totalAttempts','totalApplied','totalVerified','totalParentCalls']
        for field in fields:self.assertIn(field,py);self.assertIn(field,gd)

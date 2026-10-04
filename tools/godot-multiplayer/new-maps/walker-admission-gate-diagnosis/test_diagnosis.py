"""Portable Python/source-structural checks. GDScript remains unparsed/unrun."""
import copy,datetime,json,math,re,sys,unittest
from pathlib import Path
from inspect_ah import AH,STAGE,HERE,ROOT,inspect,utc_microseconds,load,sha
from evidence import supervisor_ok
sys.path.insert(0,str(HERE.parent/'walker-parity-admission'))
import test_admission as previous

class OfflineTests(unittest.TestCase):
    def test_actual_AH_gate_comparison_and_preservation(self):
        result=inspect()
        self.assertEqual(result['AHInventoryVerified'],42)
        self.assertEqual(len(result['profileChecks']),68)
        self.assertEqual(result['gateTable'][-1]['status'],'unobserved')
        self.assertEqual([a['gapMicroseconds'] for a in result['auditSourceModel']],[None,216686,219609])
        self.assertTrue(all(a['withinRecordedLockInterval'] for a in result['auditSourceModel']))
        self.assertTrue(all(a['binary64UlpMicroseconds']<1 for a in result['auditSourceModel']))
    def successful_supervisor(self,s):
        return supervisor_ok(s,'negative-controls',s['sourceSha256'],s['grantSha256'],s['engineSha256'],s['nativeReceiptSha256'])
    def test_same_second_fractions_retained_by_existing_host_and_source_model(self):
        s=load(STAGE/'negative-controls-supervisor.json')
        values=['2026-10-04T05:31:35.'+f'{u:06d}'+'+00:00' for u in [100000,300000,500000]]
        for audit,value in zip(s['releaseAudits'],values):audit['utc']=value
        self.assertTrue(self.successful_supervisor(s))
        exact=[utc_microseconds(t) for t in values]
        reconstructed=[int(datetime.datetime.fromisoformat(t[:19]+'+00:00').timestamp())+float('0.'+t[20:26]) for t in values]
        self.assertEqual([b-a for a,b in zip(exact,exact[1:])],[200000,200000])
        self.assertTrue(all(a<b for a,b in zip(reconstructed,reconstructed[1:])))
    def test_microsecond_midnight_carry_and_valid_leap_day(self):
        values=['2026-10-04T23:59:59.999999+00:00','2026-10-05T00:00:00.000000+00:00','2026-10-05T00:00:00.000001+00:00']
        exact=[utc_microseconds(v) for v in values]
        self.assertEqual([b-a for a,b in zip(exact,exact[1:])],[1,1])
        s=load(STAGE/'negative-controls-supervisor.json');s['lockAcquiredUnix']=(exact[0]-1000000)/1e6;s['lockReleasePendingUnix']=(exact[-1]+1000000)/1e6
        for a,v in zip(s['releaseAudits'],values):a['utc']=v
        self.assertTrue(self.successful_supervisor(s))
        self.assertEqual(utc_microseconds('2024-03-01T00:00:00.000000+00:00')-utc_microseconds('2024-02-29T23:59:59.999999+00:00'),1)
    def test_invalid_calendar_timezone_and_fraction_schema(self):
        invalid=['2026-02-29T00:00:00.000000+00:00','2026-02-30T00:00:00.000000+00:00','2026-10-04T24:00:00.000000+00:00','2026-10-04T00:00:60.000000+00:00','2026-10-04T05:31:35.10000+00:00','2026-10-04T05:31:35.1000000+00:00','2026-10-04T05:31:35.100000-00:00','2026-10-04T05:31:35.100000+01:00','2026-10-04T05:31:35.100000Z',None,False]
        for value in invalid:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):utc_microseconds(value)
                s=load(STAGE/'negative-controls-supervisor.json');s['releaseAudits'][1]['utc']=value
                self.assertFalse(self.successful_supervisor(s))
    def test_duplicates_and_reverse_order_still_reject(self):
        for reverse in [False,True]:
            s=load(STAGE/'negative-controls-supervisor.json')
            if reverse:s['releaseAudits'].reverse()
            else:s['releaseAudits'][1]['utc']=s['releaseAudits'][0]['utc']
            self.assertFalse(self.successful_supervisor(s))

class DiagnosticSourceTests(unittest.TestCase):
    def test_every_silent_admission_guard_now_has_a_stable_label(self):
        code=(ROOT/'godot/tests/walker_parity_admission/driver.gd').read_text()
        labels=set(re.findall(r'fail_admission\("([a-z_.]+)"',code))
        self.assertEqual(labels,{'args.duplicate_or_malformed','args.unknown','args.count','args.group','args.mode','output.exists','dependencies.hash','dependencies.binding_schema','dependencies.predecessor_count','dependencies.predecessor_missing','dependencies.predecessor_schema','predecessor.native_hash','predecessor.supervisor_hash','predecessor.native_policy','predecessor.supervisor_policy','grant.hash','grant.policy','source.binding_schema','source.input_namespace','source.input_hash'})
        init=code.split('func _initialize()',1)[1].split('func fail_admission',1)[0]
        run=code.split('func run()',1)[1].split('ready = true',1)[0]
        pred=code.split('func predecessors(',1)[1].split('func run()',1)[0]
        self.assertNotIn('quit(2)',init+run+pred)
        self.assertNotIn('return false',pred)
    def test_stderr_only_bounded_metadata_no_untrusted_values_or_file_writes(self):
        code=(ROOT/'godot/tests/walker_parity_admission/driver.gd').read_text();body=code.split('func fail_admission(',1)[1].split('func finish(',1)[0]
        self.assertIn('printerr("ADMISSION_FAILURE "+JSON.stringify(diagnostic))',body)
        self.assertIn('quit(2)',body);self.assertIn('"nativeCountersKnown":false',body)
        self.assertIn('"physicalCallCounts":null',body);self.assertIn('group if group in Policy.GROUPS else null',body)
        for forbidden in ['FileAccess','grant_id','OS.get_cmdline','Node3D.new','load(']:self.assertNotIn(forbidden,body)
        self.assertIn('if not admission_failure_reported:',body)
        maximum={'schema':'parity-admission-gate-failure-v1','stage':'pre_world_admission','code':'dependencies.predecessor_missing','phase':'parity-admission-synthetic-v1','mode':'synthetic-controls','group':'inclined-landing-rejections','failed':True,'exitCode':2,'nativeCountersKnown':False,'physicalCallCounts':None,'hashes':{k:'f'*64 for k in ['sourceSha256','grantSha256','engineSha256','dependenciesSha256','predecessorNativeSha256','predecessorSupervisorSha256']},'details':{'predecessor':'inclined-landing-rejections','predicate':'Evidence.supervisor_ok','inputSha256':'f'*64,'expectedSha256':'f'*64}}
        self.assertLess(len(json.dumps(maximum)),2048)
    def test_validators_and_timestamp_code_identical_to_frozen_AH(self):
        for name in ['evidence.gd','policy.gd','candidate.gd','observe.gd']:
            self.assertEqual((ROOT/'godot/tests/walker_parity_admission'/name).read_bytes(),(STAGE/'tests/walker_parity_admission'/name).read_bytes())
        gd=(STAGE/'tests/walker_parity_admission/evidence.gd').read_text()
        self.assertIn('seconds+float("0."+text.substr(20,6))',gd)
        self.assertIn('if instant<=previous or instant>s.lockReleasePendingUnix: return false',gd)
        self.assertIn('Time.get_datetime_string_from_unix_time(seconds)!=whole',gd)
        pins=load(HERE.parent/'walker-parity-admission/review-pins.json')
        self.assertEqual(sha(ROOT/'godot/tests/walker_parity_admission/driver.gd'),pins['stageInputs']['godot/tests/walker_parity_admission/driver.gd'])

class SupervisorDiagnosticTests(unittest.TestCase):
    setUp=previous.PreparationTests.setUp;tearDown=previous.PreparationTests.tearDown;build=previous.PreparationTests.build;invoke=previous.SupervisorTests.invoke
    def test_diagnostic_rejects_even_mock_exit_zero_and_passing_native_summary(self):
        code,r=self.invoke(fast_error='ADMISSION_FAILURE {"failed":true,"exitCode":2,"code":"predecessor.native_policy"}\n',check_dependency=True)
        self.assertEqual(code,1);self.assertTrue(r['failed']);self.assertTrue(r['releasedCleanly'])
        self.assertEqual(r['stopReason'],'admission_failure')
        self.assertTrue(r['partialCountersMayBeUnknown'])

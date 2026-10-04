"""All child launches/signals/ownership are mocked; only synthetic log/JSON files."""
import argparse,json,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch,Mock,MagicMock
from test_calibrated import loader,fixtures,policy
s=loader.module('supervisor')
class SupervisorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.native=fixtures.campaign_fixture(policy.GROUPS[0]);cls.native['dependenciesSha256']='d'
    def run_case(self,*,text='',native=True,poll=None,identity=None,members=None,write_error=False,launch_error=False,timeout=False,restore_error=False):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode',prefix='calibrated-offline-') as directory:
            dest=Path(directory);group=policy.GROUPS[0];report=dict(phase=policy.PHASE,mode=policy.MODE,group=group,sourceSha256='s',grantSha256='g',engineSha256='e',dependenciesSha256='d',lockAcquiredUnix=time.time()-1,releaseAudits=[],processGroupTrace=[],failed=True,releasedCleanly=False)
            child=Mock(pid=123);child.poll.side_effect=poll or [0];child.wait.return_value=0
            def popen(*args,**kwargs):
                if launch_error:raise OSError('mock launch')
                kwargs['stdout'].write(text.encode());kwargs['stdout'].flush()
                if native:(dest/(group+'-result.json')).write_text(json.dumps(self.native))
                return child
            owned={'pid':123,'pgid':123,'startTicks':456}
            def signal(number,handler):
                if handler=='original' and restore_error:raise OSError('restore failure')
                return 'original'
            with patch.object(s.subprocess,'Popen',side_effect=popen) as launch,patch.object(s.runtime,'identity',side_effect=identity or (lambda pid:owned)),patch.object(s.runtime,'members',side_effect=members or (lambda pgid:[])),patch.object(s.signal,'signal',side_effect=signal) as signals,patch.object(s.os,'killpg') as kill,patch.object(s.time,'sleep'),patch.object(s.time,'monotonic',side_effect=[0,181] if timeout else None,return_value=0),patch.object(s,'write',side_effect=OSError('write') if write_error else s.write),patch.object(s.sys.stderr,'write'):
                code=s.collect(dest,group,['NEVER-EXECUTE'],report)
            self.assertEqual(launch.call_count,1);self.assertEqual(sum(c.args[1]=='original' for c in signals.call_args_list),3)
            return code,report,kill.call_count
    def test_complete_receipt_three_audits_and_strict_supervisor(self):
        code,r,_=self.run_case();self.assertEqual(code,0);self.assertTrue(r['releasedCleanly']);self.assertEqual(len(r['releaseAudits']),3);self.assertFalse(r['partialCountersMayBeUnknown']);self.assertIsNone(r['physicalCallCounts'])
    def test_fast_exit_error_markers_fail_even_zero_exit(self):
        for text in ['SCRIPT ERROR: mock\n\n','Parse Error: mock','ADMISSION_FAILURE {}']:
            code,r,_=self.run_case(text=text);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly']);self.assertTrue(r['partialCountersMayBeUnknown'])
    def test_missing_receipt_unknown_counters(self):
        code,r,_=self.run_case(native=False);self.assertEqual(code,1);self.assertTrue(r['partialCountersMayBeUnknown']);self.assertIsNone(r['physicalCallCounts'])
    def test_polling_gate_stops_owned_once(self):
        code,r,k=self.run_case(text='ADMISSION_FAILURE {}',poll=[None]);self.assertEqual(code,1);self.assertEqual(k,1)
    def test_timeout_stops_once_without_retry(self):
        code,r,k=self.run_case(poll=[None],timeout=True);self.assertEqual(code,1);self.assertEqual(k,1);self.assertEqual(r['stopReason'],'external_timeout')
    def test_unknown_audits_cannot_mean_empty(self):
        def denied(pgid):raise PermissionError('mock proc')
        code,r,_=self.run_case(members=denied);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly']);self.assertTrue(all(not x['measured'] and x['members'] is None for x in r['releaseAudits']))
    def test_pid_reuse_refuses_signal(self):
        ids=iter([{'pid':123,'pgid':123,'startTicks':456},{'pid':123,'pgid':123,'startTicks':999}])
        code,r,k=self.run_case(identity=lambda pid:next(ids));self.assertEqual(code,1);self.assertEqual(k,0);self.assertFalse(r['releasedCleanly'])
    def test_launch_and_write_failures_restore_handlers(self):
        code,r,_=self.run_case(launch_error=True);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
        code,r,_=self.run_case(write_error=True);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly']);self.assertFalse(r['positiveAdmission'])
    def test_esrch_still_needs_three_measured_audits(self):
        report={'releaseAudits':[]};owned={'pid':123,'pgid':123,'startTicks':456}
        with patch.object(s.runtime,'identity',return_value=owned),patch.object(s.runtime,'members',side_effect=[[owned],[],[],[]]),patch.object(s.os,'killpg',side_effect=ProcessLookupError()),patch.object(s.time,'sleep'):s.runtime.audit_release(owned,report)
        self.assertTrue(report['releasedCleanly']);self.assertEqual(len(report['releaseAudits']),3)
    def test_duplicate_scope_rejected(self):
        with patch.object(s.sys.stderr,'write'),self.assertRaises(SystemExit):s.parser().parse_args(['--group','negative-controls','--group','positive-step-admission'])
    def test_restore_failure_does_not_override_measured_release(self):
        code,r,_=self.run_case(restore_error=True);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly']);self.assertFalse(r['positiveAdmission']);self.assertTrue(r['cleanupErrors'])
    def main_mock(self,missing):
        from test_calibrated import prepare
        group=policy.GROUPS[1] if missing else policy.GROUPS[0]
        dest=s.ROOT/'godot/tests/walker_calibrated_admission/calibrated-admission-review-only'
        a=argparse.Namespace(fixture=str(dest),engine='/tmp/opencode/mock-unexecuted-godot',al_root='AL-readonly',ak_root='AK-readonly',group=group,mode=policy.MODE,grant_id='TEST-IN-MEMORY',grant_sha256='b'*64)
        g=dict(phase=policy.PHASE,mode=policy.MODE,allowedGroups=policy.GROUPS,grantId=a.grant_id,authorized=True,expiresUnix=200,sourceSha256='a'*64,engineSha256=policy.ENGINE)
        consumed=set();events=[];lock=MagicMock();ancestry=prepare.lineage_identity()
        def write(path,data):consumed.add(path.name);events.append(path.name)
        def collect(path,grp,argv,report):
            self.assertIn(group+'-start.json',consumed);self.assertEqual(events[0],'locked');return 0
        def sha(path):return policy.ENGINE if path.name=='mock-unexecuted-godot' else 'b'*64 if path.name=='grant.json' else 'c'*64 if path.name.endswith('-dependencies.json') else 'a'*64
        with patch.object(Path,'open',return_value=lock),patch.object(Path,'is_file',return_value=True),patch.object(Path,'exists',lambda p:p.name in consumed),patch.object(s,'sha',side_effect=sha),patch.object(s,'load',return_value=g),patch.object(s,'validate_stage',return_value={'lineage':ancestry}),patch.object(s,'lineage',return_value=ancestry),patch.object(s.time,'time',return_value=100),patch.object(s.fcntl,'flock',side_effect=lambda *a:events.append('locked')),patch.object(s,'dependencies',side_effect=FileNotFoundError('predecessor') if missing else None,return_value={'predecessors':{}}),patch.object(s,'write',side_effect=write),patch.object(s,'collect',side_effect=collect) as run,patch.object(s.subprocess,'Popen') as popen:
            if missing:
                with self.assertRaises(FileNotFoundError):s.main(a)
                run.assert_not_called();self.assertEqual(consumed,set())
            else:
                self.assertEqual(s.main(a),0)
                with self.assertRaises(FileExistsError):s.main(a)
                self.assertEqual(run.call_count,1)
        popen.assert_not_called();self.assertTrue(lock.__exit__.called)
    def test_missing_prerequisite_prevents_any_consumption_or_launch(self):self.main_mock(True)
    def test_group_consumed_before_launch_and_cannot_retry(self):self.main_mock(False)
if __name__=='__main__':unittest.main()

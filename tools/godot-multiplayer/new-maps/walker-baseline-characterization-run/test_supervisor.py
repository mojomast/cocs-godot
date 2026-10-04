"""No child jobs: every Popen, process identity, signal and audit is mocked."""
import argparse,copy,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch,Mock,MagicMock
import supervisor as s
from receipt_fixtures import receipt,SOURCE,GRANT,DEPS
from policy import ENGINE,GROUP
class SupervisorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.native=receipt()
    def run_case(self,*,text='',native=True,returncode=0,poll=None,identity=None,members=None,write_error=False,launch_error=False,timeout=False):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode',prefix='baseline-offline-supervisor-') as directory:
            dest=Path(directory);report=dict(sourceSha256=SOURCE,grantSha256=GRANT,engineSha256=ENGINE,dependenciesSha256=DEPS,releaseAudits=[],processGroupTrace=[],failed=True,releasedCleanly=False)
            child=Mock(pid=123);child.poll.side_effect=poll or [returncode];child.wait.return_value=returncode
            def popen(*args,**kwargs):
                if launch_error:raise OSError('mock launch failure')
                kwargs['stdout'].write(text.encode());kwargs['stdout'].flush()
                if native:(dest/(GROUP+'-result.json')).write_text(json.dumps(self.native))
                return child
            owned={'pid':123,'pgid':123,'startTicks':456}
            with patch.object(s.subprocess,'Popen',side_effect=popen) as launch,patch.object(s.runtime,'identity',side_effect=identity or (lambda pid:owned)),patch.object(s.runtime,'members',side_effect=members or (lambda pgid:[])),patch.object(s.signal,'signal',return_value='original') as signals,patch.object(s.os,'killpg') as kill,patch.object(s.time,'sleep'),patch.object(s.time,'monotonic',side_effect=[0,181] if timeout else None,return_value=0),patch.object(s,'write',side_effect=OSError('write') if write_error else s.write),patch.object(s.sys.stderr,'write'):
                code=s.collect(dest,['NEVER-EXECUTE'],report)
            self.assertEqual(launch.call_count,1)
            self.assertEqual(sum(c.args[1]=='original' for c in signals.call_args_list),3)
            return code,report,kill.call_count
    def test_complete_receipt_and_three_audits(self):
        code,r,_=self.run_case();self.assertEqual(code,0);self.assertTrue(r['releasedCleanly']);self.assertEqual(len(r['releaseAudits']),3);self.assertFalse(r['partialCountersMayBeUnknown']);self.assertIsNone(r['physicalCallCounts'])
    def test_fast_exit_log_scanned(self):
        for text in ['SCRIPT ERROR: mock\n\n','Parse Error: mock','ADMISSION_FAILURE {"code":"unknown"}']:
            code,r,_=self.run_case(text=text);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly']);self.assertTrue(r['partialCountersMayBeUnknown'])
    def test_missing_receipt_unknown_counts(self):
        code,r,_=self.run_case(native=False);self.assertEqual(code,1);self.assertTrue(r['partialCountersMayBeUnknown']);self.assertTrue(r['releasedCleanly'])
    def test_polling_marker_stops_without_retry(self):
        code,r,k=self.run_case(text='ADMISSION_FAILURE {}',poll=[None]);self.assertEqual(code,1);self.assertEqual(k,1)
    def test_permission_audit_unknown_not_empty(self):
        def denied(pgid):raise PermissionError('mock /proc')
        code,r,_=self.run_case(members=denied);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly']);self.assertTrue(all(x['members'] is None and not x['measured'] for x in r['releaseAudits']))
    def test_pid_reuse_refuses_signal(self):
        identities=iter([{'pid':123,'pgid':123,'startTicks':456},{'pid':123,'pgid':123,'startTicks':999}])
        code,r,k=self.run_case(identity=lambda pid:next(identities));self.assertEqual(code,1);self.assertEqual(k,0);self.assertFalse(r['releasedCleanly'])
    def test_launch_failure_and_write_failure_restore_handlers(self):
        code,r,_=self.run_case(launch_error=True);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
        code,r,_=self.run_case(write_error=True);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly']);self.assertTrue(r['cleanupErrors'])
    def test_esrch_requires_measured_empty_audits(self):
        report={'releaseAudits':[]};owned={'pid':123,'pgid':123,'startTicks':456}
        with patch.object(s.runtime,'identity',return_value=owned),patch.object(s.runtime,'members',side_effect=[[owned],[],[],[]]),patch.object(s.os,'killpg',side_effect=ProcessLookupError()),patch.object(s.time,'sleep'):
            s.runtime.audit_release(owned,report)
        self.assertTrue(report['releasedCleanly']);self.assertEqual(len(report['releaseAudits']),3)
    def test_duplicate_cli_rejected(self):
        with patch.object(s.sys.stderr,'write'),self.assertRaises(SystemExit):s.parser().parse_args(['--mode','baseline-only','--mode','baseline-only'])
    def test_timeout_kills_owned_once_and_stays_failed(self):
        code,r,k=self.run_case(poll=[None],timeout=True);self.assertEqual(code,1);self.assertEqual(k,1);self.assertEqual(r['stopReason'],'external_timeout');self.assertTrue(r['releasedCleanly'])
    def test_log_cap_is_failure(self):
        code,r,_=self.run_case(text='x'*(s.LOG_CAP+1));self.assertEqual(code,1);self.assertEqual(r['stopReason'],'log_cap')
    def test_consumption_before_launch_and_no_retry_under_lock(self):
        from prepare import LINEAGE
        from policy import PHASE,MODE
        dest=s.ROOT/'godot/tests/walker_baseline_characterization/baseline-characterization-al-01'
        a=argparse.Namespace(fixture=str(dest),engine='/tmp/opencode/mock-unexecuted-godot',ak_root='mock-readonly',group=GROUP,mode=MODE,grant_id='TEST-IN-MEMORY',grant_sha256=GRANT)
        grant=dict(phase=PHASE,mode=MODE,allowedGroups=[GROUP],grantId=a.grant_id,authorized=True,expiresUnix=200,sourceSha256=SOURCE,engineSha256=ENGINE)
        consumed=set();events=[];lock=MagicMock()
        def write(path,data):consumed.add(path.name);events.append(path.name)
        def collect(path,argv,report):
            self.assertIn(GROUP+'-start.json',consumed);self.assertEqual(events[0],'locked');self.assertIn('--group='+GROUP,argv);return 0
        def sha(path):return ENGINE if path.name=='mock-unexecuted-godot' else GRANT if path.name=='grant.json' else DEPS if path.name.endswith('-dependencies.json') else SOURCE
        with patch.object(Path,'open',return_value=lock),patch.object(Path,'is_file',return_value=True),patch.object(Path,'exists',lambda p:p.name in consumed),patch.object(s,'sha',side_effect=sha),patch.object(s,'load',return_value=grant),patch.object(s,'validate_stage',return_value={'lineage':LINEAGE}),patch.object(s,'lineage',return_value=LINEAGE),patch.object(s.time,'time',return_value=100),patch.object(s.fcntl,'flock',side_effect=lambda *a:events.append('locked')),patch.object(s,'write',side_effect=write),patch.object(s,'collect',side_effect=collect),patch.object(s.subprocess,'Popen') as popen:
            self.assertEqual(s.main(a),0)
            with self.assertRaises(FileExistsError):s.main(a)
        popen.assert_not_called();self.assertTrue(lock.__exit__.called)
if __name__=='__main__':unittest.main()

import contextlib,fcntl,io,json,re,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from policy import PHASE,MODE,GROUP,validate
from prepare import ROOT,HERE,PROJECT,build,validate_stage,verify_archive,load,sha,digest
from supervisor import parser,argv_for,EXTERNAL_SECONDS
import supervisor

class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.g={'phase':PHASE,'mode':MODE,'allowedGroups':[GROUP],'grantId':'AF-test-only','authorized':True,'expiresUnix':101.,'sourceSha256':'a'*64,'engineSha256':'b'*64}
        self.args=dict(group=GROUP,mode=MODE,grant_id='AF-test-only',source_hash='a'*64,engine_hash='b'*64,now=100.)
    def test_exact_contract(self):validate(self.g,**self.args)
    def test_reject_modes_groups_and_unknown_permissions(self):
        for field,value in [('mode','candidate'),('mode','paritycandidate'),('phase','snap-query-parity-only-v1'),('allowedGroups',['positive']),('allowedGroups',['map']),('allowedGroups',['ref']),('allowedGroups',[GROUP,GROUP]),('allowedGroups',[GROUP,'snap-parity-candidate']),('allowedGroups',GROUP),('authorized',1),('grantId',''),('sourceSha256','0'*64),('engineSha256','c'*64),('expiresUnix',True),('expiresUnix',float('inf')),('expiresUnix',99)]:
            bad={**self.g,field:value}
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):validate(bad,**self.args)
        for key in self.g:
            bad=self.g.copy();del bad[key]
            with self.assertRaises(ValueError):validate(bad,**self.args)
        for key in ['debug','simulation','candidate','continueAfterKnownBaselineFailure','groups','override']:
            with self.assertRaises(ValueError):validate({**self.g,key:False},**self.args)
    def test_cli_no_bypass_duplicates_abbreviation_or_debug(self):
        args=['--fixture','/stage','--ae-root','/ae','--engine','/explicit/godot','--group',GROUP,'--mode',MODE,'--grant-id','AF-test-only','--grant-sha256','a'*64]
        with contextlib.redirect_stderr(io.StringIO()):
            for extra in [['--mode',MODE],['--grant-id','again'],['--debug'],['--simulation'],['--candidate']]:
                with self.assertRaises(SystemExit):parser().parse_args(args+extra)
            with self.assertRaises(SystemExit):parser().parse_args(args[:-2])
        parsed=parser().parse_args(args)
        command=argv_for(Path('/explicit/godot'),Path('/stage'),parsed)
        self.assertEqual(command[0],'/explicit/godot');self.assertNotIn('--editor',command)
        self.assertIn('--single-threaded-scene',command)
        parsed.mode='paritycandidate'
        with self.assertRaises(ValueError):argv_for(Path('/explicit/godot'),Path('/stage'),parsed)
    def test_gd_policy_has_exact_python_vocabulary_and_required_keys(self):
        gd=(ROOT/'godot/tests/walker_snap_compare/policy.gd').read_text()
        for key,value in [('PHASE',PHASE),('MODE',MODE),('GROUP',GROUP)]:self.assertIn(f'const {key} := "{value}"',gd)
        keys=json.loads(re.search(r'const GRANT_KEYS := (\[.*\])',gd)[1])
        self.assertEqual(set(keys),set(self.g))
        for expression in ['grant.size()!=GRANT_KEYS.size()','grant.allowedGroups!=[GROUP]','grant.authorized is bool','grant.expiresUnix is float or grant.expiresUnix is int','hash_valid(source_hash)','grant.mode!=MODE']:
            self.assertIn(expression,gd)
    def test_baseline_factory_readonly_dependency_closure_and_bounds(self):
        pins=load(HERE/'review-pins.json');text=(ROOT/'godot/tests/walker_snap_compare/driver.gd').read_text()
        self.assertEqual(re.findall(r'(\w+)\.new\(',text),['Walker'])
        self.assertEqual(text.count('body.step('),1)
        self.assertNotRegex(text,r'body\.(move_and_collide|move_and_slide|global_position\s*=)')
        self.assertLess(text.index('Pair.compare('),text.index('body.step('))
        self.assertIn('before!=after_queries',text)
        self.assertIn('create_timer(170)',text);self.assertIn('range(60)',text);self.assertEqual(EXTERNAL_SECONDS,180)
        for name,h in pins['stageInputs'].items():
            self.assertEqual(sha(ROOT/name),h)
            source=(ROOT/name).read_text()
            self.assertNotIn('candidate_telemetry',source)
            self.assertNotIn('candidate.gd',source)
            for dep in re.findall(r'preload\("([^"]+)"\)',source):
                relative='godot/'+dep[6:] if dep.startswith('res://') else str(Path(name).parent/dep)
                self.assertIn(relative,pins['stageInputs'])
        self.assertIn('plan.raised,plan.horizontalBudget,6,true,false',(ROOT/'godot/tests/walker_snap_parity/query_pair.gd').read_text())
        for name in ['godot/tests/walker_step_up/sweep_proposal.gd','godot/tests/walker_snap_parity/query_pair.gd']:
            self.assertNotRegex((ROOT/name).read_text(),r'\.(move_and_collide|move_and_slide)\(')

class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='snap-compare-unit-',dir='/tmp/opencode')
        self.base=Path(self.tmp.name);self.root=self.base/'repo';self.root.mkdir();self.stage=self.base/'scratch';self.stage.mkdir();self.ae=self.base/'ae';self.ae.mkdir()
        rows={}
        for i in range(46):
            p=self.ae/f'evidence-{i}.txt';p.write_text(str(i));rows[p.name]={'sha256':sha(p),'bytes':p.stat().st_size}
        self.manifest=self.ae/'manifest.json';self.manifest.write_text(json.dumps({'files':rows}))
        script=self.root/'godot/test.gd';script.parent.mkdir();script.write_text('extends SceneTree\n')
        self.pins={'AEManifestPath':'manifest.json','AEManifestSha256':sha(self.manifest),'hostInputs':{},'productionDependencies':{'godot/test.gd':sha(script)},'stageInputs':{'godot/test.gd':sha(script)},'projectSha256':digest(PROJECT.encode())}
    def tearDown(self):self.tmp.cleanup()
    def build(self,name='snap-compare-af-01'):
        return build(name,self.ae,root=self.root,stage_parent=self.stage,pins=self.pins)
    def test_real_prepare_write_once_and_validate_no_launch(self):
        with patch('subprocess.Popen',side_effect=AssertionError('no children')):
            dest=self.build();validate_stage(dest,root=self.root,pins=self.pins)
        self.assertEqual(load(dest/'source.json')['AEIdentity']['filesVerified'],46)
        self.assertFalse((dest/'grant.json').exists());self.assertFalse((dest/'comparison-result.json').exists())
        with self.assertRaises(FileExistsError):self.build()
        (dest/'test.gd').write_text('tampered')
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)
    def test_bad_archive_manifest_and_single_file_are_fail_closed_before_write(self):
        (self.ae/'evidence-45.txt').write_text('tampered')
        with self.assertRaises(ValueError):self.build()
        self.assertEqual(list(self.stage.iterdir()),[])
        self.manifest.write_text('{}')
        with self.assertRaises(ValueError):self.build()
    def test_source_pin_and_namespace_and_symlink_rejection(self):
        for name in ['snap-compare-AF-01','snap-compare-af/01','../snap-compare-af','snap-compare--af','snap-parity-af-01']:
            with self.assertRaises(ValueError):self.build(name)
        (self.stage/'snap-compare-af-01').symlink_to(self.ae,target_is_directory=True)
        with self.assertRaises(ValueError):self.build()
        (self.stage/'snap-compare-af-01').unlink()
        (self.root/'godot/test.gd').write_text('modified')
        with self.assertRaises(ValueError):self.build()
    def test_json_duplicate_keys_rejected(self):
        p=self.base/'duplicate.json';p.write_text('{"mode":"compare-only","mode":"candidate"}')
        with self.assertRaises(ValueError):load(p)
    def test_unlisted_stage_script_and_receipt_manifest_substitution_rejected(self):
        dest=self.build();rogue=dest/'extra.gd';rogue.write_text('extends Node')
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)
        rogue.unlink();receipt=load(dest/'source.json');receipt['files']['res://test.gd']='0'*64
        (dest/'source.json').write_text(json.dumps(receipt))
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)

class SupervisorTests(unittest.TestCase):
    setUp=PreparationTests.setUp
    tearDown=PreparationTests.tearDown
    build=PreparationTests.build
    # Exercise the actual supervisor control flow with a mocked child, never an engine.
    def setup_invocation(self):
        self.stage=self.root/'godot/tests/walker_snap_compare';self.stage.mkdir(parents=True)
        dest=self.build();engine=self.base/'explicit-binary';engine.write_bytes(b'unit-test placeholder, never executable')
        grant={'phase':PHASE,'mode':MODE,'allowedGroups':[GROUP],'grantId':'AF-unit','authorized':True,'expiresUnix':9999999999,'sourceSha256':sha(dest/'source.json'),'engineSha256':sha(engine)}
        (dest/'grant.json').write_text(json.dumps(grant))
        args=parser().parse_args(['--fixture',str(dest),'--ae-root',str(self.ae),'--engine',str(engine),'--group',GROUP,'--mode',MODE,'--grant-id','AF-unit','--grant-sha256',sha(dest/'grant.json')])
        return dest,args
    def supervisor_context(self,stack):
        stack.enter_context(patch.object(supervisor,'ROOT',self.root))
        stack.enter_context(patch.object(supervisor,'LOCK',self.base/'lock'))
        stack.enter_context(patch.object(supervisor,'validate_stage',side_effect=lambda d:validate_stage(d,root=self.root,pins=self.pins)))
        real_load=load
        stack.enter_context(patch.object(supervisor,'load',side_effect=lambda p:self.pins if p==HERE/'review-pins.json' else real_load(p)))
    def test_external_deadline_owned_kill_and_three_empty_audits(self):
        dest,args=self.setup_invocation()
        owned={'pid':123456789,'pgid':123456789,'startTicks':777}
        with contextlib.ExitStack() as stack:
            self.supervisor_context(stack)
            launch=stack.enter_context(patch.object(supervisor.subprocess,'Popen'))
            launch.return_value.pid=owned['pid'];launch.return_value.poll.return_value=None;launch.return_value.wait.return_value=-9
            stack.enter_context(patch.object(supervisor,'identity',return_value=owned))
            stack.enter_context(patch.object(supervisor,'members',return_value=[]))
            stack.enter_context(patch.object(supervisor.time,'monotonic',side_effect=[0,181,181]))
            stack.enter_context(patch.object(supervisor.time,'sleep'))
            kill=stack.enter_context(patch.object(supervisor.os,'killpg'))
            self.assertEqual(supervisor.main(args),1)
            kill.assert_called_once_with(owned['pgid'],supervisor.signal.SIGKILL)
            self.assertTrue(launch.call_args.kwargs['start_new_session'])
        report=load(dest/'supervisor-result.json')
        self.assertEqual(report['stopReason'],'external_timeout');self.assertTrue(report['failed'])
        self.assertEqual(len(report['releaseAudits']),3);self.assertTrue(report['releasedCleanly'])
        self.assertEqual(report['owned'],owned)
    def test_nonwaiting_lock_never_launches_when_held(self):
        dest,args=self.setup_invocation()
        with contextlib.ExitStack() as stack:
            self.supervisor_context(stack)
            launch=stack.enter_context(patch.object(supervisor.subprocess,'Popen',side_effect=AssertionError('must not launch')))
            held=stack.enter_context((self.base/'lock').open('a+'));fcntl.flock(held,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):supervisor.main(args)
            launch.assert_not_called()
        self.assertFalse((dest/'supervisor-start.json').exists())
    def run_residual_cleanup(self,*,signal_error=None,audits=None,reused=False,write_error=False):
        dest,args=self.setup_invocation()
        owned={'pid':123456789,'pgid':123456789,'startTicks':777}
        residual={**owned,'pid':123456790,'startTicks':778}
        handlers={n:supervisor.signal.getsignal(n) for n in [supervisor.signal.SIGTERM,supervisor.signal.SIGHUP,supervisor.signal.SIGINT]}
        real_write=supervisor.write
        def write_receipt(path,value):
            # Receipt attempts take place while the nonwaiting lock is still held.
            with (self.base/'lock').open('a+') as other:
                with self.assertRaises(BlockingIOError):fcntl.flock(other,fcntl.LOCK_EX|fcntl.LOCK_NB)
            if write_error and path.name=='supervisor-result.json':raise OSError('receipt disk failure')
            real_write(path,value)
        def completed_child(**kwargs):
            (dest/'comparison-result.json').write_text(json.dumps({'comparisonCollected':True,'failed':False,'mode':MODE,'group':GROUP,'sourceSha256':sha(dest/'source.json'),'grantSha256':args.grant_sha256}))
            return 0
        with contextlib.ExitStack() as stack:
            self.supervisor_context(stack)
            launch=stack.enter_context(patch.object(supervisor.subprocess,'Popen'))
            launch.return_value.pid=owned['pid'];launch.return_value.poll.return_value=0;launch.return_value.wait.side_effect=completed_child
            stack.enter_context(patch.object(supervisor,'identity',side_effect=[owned,{**owned,'startTicks':999} if reused else None]))
            census=stack.enter_context(patch.object(supervisor,'members',side_effect=[[residual]]+(audits if audits is not None else [[],[],[]])))
            stack.enter_context(patch.object(supervisor.time,'sleep'))
            kill=stack.enter_context(patch.object(supervisor.os,'killpg',side_effect=signal_error))
            stack.enter_context(patch.object(supervisor,'write',side_effect=write_receipt))
            stderr=stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            code=supervisor.main(args)
            self.assertEqual(census.call_count,4)
            if reused:kill.assert_not_called()
            else:kill.assert_called_once_with(owned['pgid'],supervisor.signal.SIGKILL)
        self.assertEqual({n:supervisor.signal.getsignal(n) for n in handlers},handlers)
        with (self.base/'lock').open('a+') as other:fcntl.flock(other,fcntl.LOCK_EX|fcntl.LOCK_NB)
        report=json.loads(stderr.getvalue()) if write_error else load(dest/'supervisor-result.json')
        self.assertEqual(len(report['releaseAudits']),3)
        return code,report
    def test_residual_exit_esrch_requires_three_empty_audits(self):
        code,report=self.run_residual_cleanup(signal_error=ProcessLookupError('already exited'))
        self.assertEqual(code,0);self.assertFalse(report['failed']);self.assertTrue(report['releasedCleanly'])
        self.assertTrue(report['residualGroupDisappearedBeforeSignal'])
        self.assertTrue(all(a['measured'] and a['members']==[] for a in report['releaseAudits']))
    def test_permission_error_fails_even_with_empty_audits(self):
        code,report=self.run_residual_cleanup(signal_error=PermissionError('denied'))
        self.assertEqual(code,1);self.assertTrue(report['failed']);self.assertFalse(report['releasedCleanly'])
        self.assertIn('PermissionError',report['cleanupErrors'][0]['error'])
    def test_esrch_with_survivor_is_not_release_proof(self):
        code,report=self.run_residual_cleanup(signal_error=ProcessLookupError(),audits=[[],[{'pid':123456790}],[]])
        self.assertEqual(code,1);self.assertFalse(report['releasedCleanly'])
    def test_audit_error_records_unknown_and_continues(self):
        code,report=self.run_residual_cleanup(audits=[PermissionError('proc denied'),[],[]])
        self.assertEqual(code,1);self.assertFalse(report['releasedCleanly'])
        self.assertIsNone(report['releaseAudits'][0]['members']);self.assertFalse(report['releaseAudits'][0]['measured'])
    def test_reused_leader_never_signalled_even_if_later_audits_empty(self):
        code,report=self.run_residual_cleanup(reused=True)
        self.assertEqual(code,1);self.assertFalse(report['releasedCleanly'])
    def test_receipt_write_failure_restores_handlers_releases_lock_and_reports_failure(self):
        code,report=self.run_residual_cleanup(write_error=True)
        self.assertEqual(code,1);self.assertTrue(report['failed'])
        self.assertEqual(report['cleanupErrors'][-1]['operation'],'write_result')

if __name__=='__main__':unittest.main()

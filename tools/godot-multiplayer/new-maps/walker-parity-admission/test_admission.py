import ast,contextlib,copy,fcntl,io,json,re,struct,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import policy,supervisor
from policy import PHASE,MODE,GROUPS,COUNTS,validate,successful
from prepare import ROOT,HERE,PROJECT,build,validate_stage,load,sha,digest,dependencies
from audit import check_lifecycle,lift_limit
from receipt_fixtures import campaign_fixture,supervisor_fixture

def passed(group,source='s',grant='g',engine='e'):
    return campaign_fixture(group,source,grant,engine)

class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.g={'phase':PHASE,'mode':MODE,'allowedGroups':GROUPS.copy(),'grantId':'unit','authorized':True,'expiresUnix':101.,'sourceSha256':'a'*64,'engineSha256':'b'*64}
        self.kw=dict(group=GROUPS[0],mode=MODE,grant_id='unit',source_hash='a'*64,engine_hash='b'*64,now=100.)
    def test_subset_and_exact_schema(self):
        validate(self.g,**self.kw);validate({**self.g,'allowedGroups':[GROUPS[0]]},**self.kw)
        for k in self.g:
            bad=self.g.copy();del bad[k]
            with self.assertRaises(ValueError):validate(bad,**self.kw)
        for key in ['debug','simulation','continueAfterFailure','queue','groups']:
            with self.assertRaises(ValueError):validate({**self.g,key:False},**self.kw)
    def test_wrong_phase_modes_groups_expiry_and_hash(self):
        for k,v in [('phase','parity-response-only-v1'),('mode','single-response'),('allowedGroups',['map']),('allowedGroups',['reference']),('allowedGroups',[GROUPS[0]]*2),('allowedGroups',GROUPS[::-1]),('authorized',1),('expiresUnix',True),('expiresUnix',float('nan')),('expiresUnix',99),('sourceSha256','c'*64),('engineSha256','d'*64),('grantId','wrong')]:
            with self.subTest(k=k,v=v),self.assertRaises(ValueError):validate({**self.g,k:v},**self.kw)
    def test_receipt_counts_and_partial_cannot_pass(self):
        for group in GROUPS:self.assertTrue(successful(passed(group),group,'s','g','e'))
        r=passed(GROUPS[0])
        for k,v in [('failed',True),('unrunPairs',1),('interruptedProfiles',1),('completedPairs',33),('passedPairs',True),('sourceSha256','wrong'),('positiveAdmission',True)]:self.assertFalse(successful({**r,k:v},GROUPS[0],'s','g','e'))
        r['records'][0]['profiles'][1]['appliedUpCount']=1;self.assertFalse(successful(r,GROUPS[0],'s','g','e'))
        r=passed(GROUPS[2]);r['records'][0]['profiles'][0]['reached']=True;self.assertFalse(successful(r,GROUPS[2],'s','g','e'))
    def test_cli_duplicates_unknown_or_missing_reject(self):
        args=['--fixture','/f','--ag-root','/ag','--af-root','/af','--engine','/bin','--group',GROUPS[0],'--mode',MODE,'--grant-id','u','--grant-sha256','a'*64]
        supervisor.parser().parse_args(args)
        with contextlib.redirect_stderr(io.StringIO()):
            for extra in [['--group',GROUPS[0]],['--grant-id','again'],['--debug'],['--simulation'],['--continue']]:
                with self.assertRaises(SystemExit):supervisor.parser().parse_args(args+extra)
            with self.assertRaises(SystemExit):supervisor.parser().parse_args(args[:-2])

class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='parity-admission-unit-',dir='/tmp/opencode');self.base=Path(self.tmp.name);self.root=self.base/'repo';self.root.mkdir();self.stage=self.base/'scratch';self.stage.mkdir()
        self.pins={'stageInputs':{},'hostInputs':{},'productionDependencies':{},'projectSha256':digest(PROJECT.encode())}
        for label,n in [('AG',29),('AF',24)]:
            base=self.base/label;base.mkdir();rows={}
            for i in range(n):
                p=base/f'{i}.txt';p.write_text(str(i));rows[p.name]={'sha256':sha(p),'bytes':p.stat().st_size}
            manifest=base/'manifest.json';manifest.write_text(json.dumps({'files':rows}));self.pins.update({label+'ManifestPath':'manifest.json',label+'ManifestSha256':sha(manifest),label+'Producer':'unit'})
        p=self.root/'godot/fake.gd';p.parent.mkdir();p.write_text('extends Node\n');self.pins['stageInputs']['godot/fake.gd']=sha(p);self.pins['productionDependencies']['godot/fake.gd']=sha(p)
    def tearDown(self):self.tmp.cleanup()
    def build(self,name='parity-admission-unit-01'):return build(name,self.base/'AG',self.base/'AF',root=self.root,stage_parent=self.stage,pins=self.pins)
    def test_actual_preparation_writeonce_and_tamper(self):
        with patch('subprocess.Popen',side_effect=AssertionError('no child')):dest=self.build();validate_stage(dest,root=self.root,pins=self.pins)
        self.assertFalse((dest/'grant.json').exists())
        with self.assertRaises(FileExistsError):self.build()
        (dest/'fake.gd').write_text('tamper')
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)
    def test_AF_AG_pin_mismatch_prevents_writes(self):
        for label in ['AF','AG']:
            file=self.base/label/'0.txt';raw=file.read_bytes();file.write_text('tamper')
            with self.assertRaises(ValueError):self.build()
            self.assertEqual(list(self.stage.iterdir()),[]);file.write_bytes(raw)
        self.pins['AGManifestSha256']='0'*64
        with self.assertRaises(ValueError):self.build()
    def test_namespace_symlinks_and_extra_stage_files(self):
        for name in ['parity-admission-AH-01','../escape','parity-response-a','parity-admission--a']:
            with self.assertRaises(ValueError):self.build(name)
        (self.stage/'parity-admission-unit-01').symlink_to(self.base/'AF',target_is_directory=True)
        with self.assertRaises(ValueError):self.build()
        (self.stage/'parity-admission-unit-01').unlink();dest=self.build();(dest/'evil.gd').write_text('x')
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)
    def test_duplicate_json_and_source_fingerprint(self):
        p=self.base/'duplicate.json';p.write_text('{"phase":"x","phase":"y"}')
        with self.assertRaises(ValueError):load(p)
        (self.root/'godot/fake.gd').write_text('drift')
        with self.assertRaises(ValueError):self.build()
    def test_predecessors_require_bound_complete_release_and_native_hash(self):
        dest=self.build();self.assertEqual(dependencies(dest,GROUPS[0],'s','g','e')['predecessors'],{})
        with self.assertRaises(FileNotFoundError):dependencies(dest,GROUPS[1],'s','g','e')
        p=dest/(GROUPS[0]+'-result.json');s=dest/(GROUPS[0]+'-supervisor.json');r=passed(GROUPS[0]);p.write_text(json.dumps(r))
        report=supervisor_fixture(native_hash=sha(p));s.write_text(json.dumps(report))
        self.assertEqual(len(dependencies(dest,GROUPS[1],'s','g','e')['predecessors']),1)
        for field,value in [('unrunPairs',1),('completedProfiles',67),('failed',True),('grantSha256','other')]:
            p.write_text(json.dumps({**r,field:value}));report['nativeReceiptSha256']=sha(p);s.write_text(json.dumps(report))
            with self.assertRaises(ValueError):dependencies(dest,GROUPS[1],'s','g','e')
        p.write_text(json.dumps(r));report['nativeReceiptSha256']=sha(p);report['releaseAudits'][1]['measured']=False;s.write_text(json.dumps(report))
        with self.assertRaises(ValueError):dependencies(dest,GROUPS[1],'s','g','e')

class LifecycleTests(unittest.TestCase):
    def rows(self,kinds):
        result=[];up=verified=parents=attempts=0
        for frame,kind in enumerate(kinds):
            accepted=kind!='ordinary';fault=kind in ['rejected','up-fault'];a=1 if kind in ['pass','up-fault'] else 0;p=0 if fault else 1
            up+=a;parents+=p;attempts+=int(accepted);verified+=int(kind=='pass')
            result.append({'frame':frame,'returned':True,'proposal':{'accepted':kind!='rejected'},'appliedUpCount':a,'responseGuardPassed':kind=='pass','candidateFault':'fault' if fault else '',
                'lifecycle':{'returned':True,'originalProof':{'accepted':accepted},'ordinary':not accepted,'parentCalls':p,'totalApplied':up,'totalVerified':verified,'totalParentCalls':parents,'totalAttempts':attempts}})
        return result
    def test_ordinary_then_two_guarded_then_ordinary_counts(self):
        self.assertEqual(check_lifecycle(self.rows(['ordinary','pass','pass','ordinary']),.35,True),{'applied':2,'verified':2,'parentCalls':4,'attempts':2,'terminalFault':False})
    def test_rejected_parity_has_zero_calls_and_no_continuation(self):
        r=check_lifecycle(self.rows(['ordinary','rejected']),.42,True);self.assertEqual(r['applied'],0);self.assertEqual(r['parentCalls'],1)
        with self.assertRaises(ValueError):check_lifecycle(self.rows(['rejected','ordinary']),.35,True)
    def test_duplicate_frame_partial_counter_and_double_up(self):
        for change in ['duplicate','partial','double']:
            rows=self.rows(['ordinary','pass'])
            if change=='duplicate':rows[1]['frame']=0
            if change=='partial':rows[1]['returned']=False
            if change=='double':rows[1]['appliedUpCount']=2
            with self.assertRaises(ValueError):check_lifecycle(rows,.35,True)
    def test_lift_caps_negative_gate_and_counter_drift(self):
        self.assertEqual([lift_limit(.35),lift_limit(.42)],[9,11])
        with self.assertRaises(ValueError):check_lifecycle(self.rows(['pass']*10),.35,True)
        with self.assertRaises(ValueError):check_lifecycle(self.rows(['pass']),.35,False)
        rows=self.rows(['pass']);rows[0]['lifecycle']['totalVerified']=2
        with self.assertRaises(ValueError):check_lifecycle(rows,.35,True)

class SupervisorTests(unittest.TestCase):
    setUp=PreparationTests.setUp;tearDown=PreparationTests.tearDown;build=PreparationTests.build
    def invoke(self,*,signal_error=None,audits=None,reused=False,write_error=False,deadline=False,held=False,fast_error=False,native_mutation=None,check_dependency=False,group_override=None):
        self.stage=self.root/'godot/tests/walker_parity_admission';self.stage.mkdir(parents=True);dest=self.build();engine=self.base/'binary';engine.write_bytes(b'nonexecutable mock')
        group=group_override or GROUPS[0];g={'phase':PHASE,'mode':MODE,'allowedGroups':GROUPS[:GROUPS.index(group)+1],'grantId':'unit','authorized':True,'expiresUnix':9999999999,'sourceSha256':sha(dest/'source.json'),'engineSha256':sha(engine)};(dest/'grant.json').write_text(json.dumps(g))
        a=supervisor.parser().parse_args(['--fixture',str(dest),'--ag-root',str(self.base/'AG'),'--af-root',str(self.base/'AF'),'--engine',str(engine),'--group',group,'--mode',MODE,'--grant-id','unit','--grant-sha256',sha(dest/'grant.json')])
        for prior in GROUPS[:GROUPS.index(group)]:
            native=dest/(prior+'-result.json');native.write_text(json.dumps(passed(prior,g['sourceSha256'],a.grant_sha256,g['engineSha256'])))
            (dest/(prior+'-supervisor.json')).write_text(json.dumps(supervisor_fixture(prior,g['sourceSha256'],a.grant_sha256,g['engineSha256'],sha(native))))
        owned={'pid':123456789,'pgid':123456789,'startTicks':777};residual={**owned,'pid':123456790,'startTicks':778};runtime=supervisor.runtime
        handlers={n:supervisor.signal.getsignal(n) for n in [supervisor.signal.SIGTERM,supervisor.signal.SIGHUP,supervisor.signal.SIGINT]};real_write=supervisor.write
        def writer(path,value):
            with (self.base/'lock').open('a+') as other:
                with self.assertRaises(BlockingIOError):fcntl.flock(other,fcntl.LOCK_EX|fcntl.LOCK_NB)
            if write_error and path.name.endswith('-supervisor.json'):raise OSError('disk failure')
            real_write(path,value)
        def done(**kwargs):
            r=passed(group,sha(dest/'source.json'),a.grant_sha256,sha(engine));r['dependenciesSha256']=sha(dest/(group+'-dependencies.json'));(dest/(group+'-result.json')).write_text(json.dumps(r))
            if native_mutation:
                native_mutation(r);(dest/(group+'-result.json')).write_text(json.dumps(r))
            if fast_error:(dest/(group+'.log')).write_text(fast_error if isinstance(fast_error,str) else 'SCRIPT ERROR: mock\n')
            return -9 if deadline else 0
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(supervisor,'ROOT',self.root));stack.enter_context(patch.object(supervisor,'LOCK',self.base/'lock'))
            stack.enter_context(patch.object(supervisor,'validate_stage',side_effect=lambda d:validate_stage(d,root=self.root,pins=self.pins)))
            stack.enter_context(patch.object(supervisor,'load',side_effect=lambda p:self.pins if p==HERE/'review-pins.json' else load(p)))
            launch=stack.enter_context(patch.object(supervisor.subprocess,'Popen'));launch.return_value.pid=owned['pid'];launch.return_value.poll.return_value=None if deadline else 0;launch.return_value.wait.side_effect=done
            stack.enter_context(patch.object(runtime,'identity',side_effect=[owned,owned,None] if deadline else [owned,{**owned,'startTicks':999} if reused else None]))
            census=stack.enter_context(patch.object(runtime,'members',side_effect=[[],[],[],[],[]] if deadline else [[residual]]+(audits if audits is not None else [[],[],[]])))
            stack.enter_context(patch.object(supervisor.time,'sleep'))
            if deadline:stack.enter_context(patch.object(supervisor.time,'monotonic',side_effect=[0,181,181]))
            kill=stack.enter_context(patch.object(supervisor.os,'killpg',side_effect=signal_error));stack.enter_context(patch.object(supervisor,'write',side_effect=writer));stderr=stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            if held:
                lock=stack.enter_context((self.base/'lock').open('a+'));fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with self.assertRaises(BlockingIOError):supervisor.main(a)
                launch.assert_not_called();return
            code=supervisor.main(a);self.assertEqual(census.call_count,5 if deadline else 4)
            if reused:kill.assert_not_called()
            else:kill.assert_called_once_with(owned['pgid'],supervisor.signal.SIGKILL)
        self.assertEqual({n:supervisor.signal.getsignal(n) for n in handlers},handlers)
        with (self.base/'lock').open('a+') as other:fcntl.flock(other,fcntl.LOCK_EX|fcntl.LOCK_NB)
        r=json.loads(stderr.getvalue()) if write_error else load(dest/(group+'-supervisor.json'));self.assertEqual(len(r['releaseAudits']),3)
        if check_dependency:
            with self.assertRaises(ValueError):dependencies(dest,GROUPS[1],sha(dest/'source.json'),a.grant_sha256,sha(engine))
        return code,r
    def test_nonwaiting_lock(self):self.invoke(held=True)
    def test_deadline_cleanup_is_not_success(self):
        code,r=self.invoke(deadline=True);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly'])
    def test_residual_exit_race(self):
        code,r=self.invoke(signal_error=ProcessLookupError());self.assertEqual(code,0);self.assertTrue(r['residualGroupDisappearedBeforeSignal'])
    def test_permission_error_despite_empty_audits(self):
        code,r=self.invoke(signal_error=PermissionError());self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_surviving_member(self):
        code,r=self.invoke(signal_error=ProcessLookupError(),audits=[[],[{'pid':123456790}],[]]);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_unknown_audit(self):
        code,r=self.invoke(audits=[PermissionError(),[],[]]);self.assertEqual(code,1);self.assertIsNone(r['releaseAudits'][0]['members'])
    def test_reused_identity(self):
        code,r=self.invoke(reused=True);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_receipt_failure(self):
        code,r=self.invoke(write_error=True);self.assertEqual(code,1);self.assertTrue(r['failed'])
    def test_fast_error(self):
        code,r=self.invoke(fast_error=True);self.assertEqual(code,1);self.assertEqual(r['stopReason'],'engine_script_error')

class SourceTests(unittest.TestCase):
    def test_AG_application_body_exact_copy_and_frozen_planner(self):
        old=(ROOT/'godot/tests/walker_parity_response/candidate.gd').read_text();new=(ROOT/'godot/tests/walker_parity_admission/candidate.gd').read_text()
        self.assertEqual(old.split('func step(',1)[1],new.split('func apply_single_response(',1)[1])
        self.assertEqual(old.split('func state()',1)[1].split('func step(',1)[0],new.split('func state()',1)[1].split('func apply_single_response(',1)[0])
        self.assertIn('preload("res://tests/walker_parity_response/planner.gd")',new)
        self.assertNotRegex(new,r'(global_position|velocity)\s*=')
        self.assertIn('if frame==last_response_frame',new);self.assertIn('if total_applied>=lift_limit',new)
    def test_closure_and_original_guard_hashes(self):
        pins=load(HERE/'review-pins.json')
        for name,h in {**pins['stageInputs'],**pins['hostInputs']}.items():self.assertEqual(sha(ROOT/name),h)
        for name in pins['stageInputs']:
            for dep in re.findall(r'(?:preload\(|extends )"([^"]+)"',(ROOT/name).read_text()):
                resolved='godot/'+dep[6:] if dep.startswith('res://') else str(Path(name).parent/dep);self.assertIn(resolved,pins['stageInputs'])
        ag=load(HERE.parent/'walker-parity-response/review-pins.json')
        for name in ['godot/tests/walker_parity_response/planner.gd','godot/tests/walker_step_up/response_guard.gd','godot/tests/walker_snap_parity/planner.gd']:
            self.assertEqual(pins['stageInputs'][name],ag['stageInputs'][name])
        self.assertEqual(policy.PHASE,PHASE);self.assertEqual(supervisor.runtime.PHASE,'parity-response-only-v1')
    def test_GD_contract_and_real_goal_clearance(self):
        gd=(ROOT/'godot/tests/walker_parity_admission/policy.gd').read_text()
        self.assertIn('const PHASE := "'+PHASE+'"',gd);self.assertEqual(json.loads(re.search(r'const GROUPS := (\[.*\])',gd)[1]),GROUPS)
        self.assertEqual(json.loads(re.search(r'const COUNTS := (\[.*\])',gd)[1]),[34,4,4])
        fixtures=(ROOT/'godot/tests/walker_admission/fixtures_v4.gd').read_text();self.assertIn('"goal":1.0',fixtures);self.assertIn('"maxResponses":240',fixtures)
        for r in [.35,.42]:self.assertGreater(1.0,r+.02);self.assertLess(1.0,3-r-.02)
        driver=(ROOT/'godot/tests/walker_parity_admission/driver.gd').read_text();self.assertIn('ordinaryLandingStreak<3',driver);self.assertIn('unexpected_baseline_arrival',driver);self.assertIn('create_timer(170)',driver)
        obs=(ROOT/'godot/tests/walker_parity_admission/observe.gd').read_text();self.assertIn('hit.get_collider_rid(i)!=fixture.topRid',obs);self.assertIn('hit.get_collision_point(i).y',obs)
    def test_original_endpoint_and_support_counterexamples(self):
        import sys
        sys.path.insert(0,str(HERE.parent/'walker-step-up'));from response_oracle import agrees,budget
        ae=load(HERE.parent/'walker-snap-parity/AE-witness.json')['response']
        self.assertFalse(agrees(ae['proposal']['expectedFinal'],ae['after'],ae['proposal']['horizontalBudget'],ae['proposal']['horizontalBudget'],(42,0),(42,0)))
        self.assertEqual(budget(ae['proposal']['expectedFinal'],ae['after']),1e-6)
        self.assertFalse(agrees((0,.12,.1),(.04,.10,.08),(0,0,.1),(0,0,.1),(42,0),(42,0)))
        self.assertFalse(agrees((0,.12,.1),(0,.12,.1),(0,0,.1),(0,0,.1),(42,0),(42,1)))
if __name__=='__main__':unittest.main()

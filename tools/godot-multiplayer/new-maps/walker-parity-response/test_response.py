import ast,contextlib,fcntl,io,json,math,re,struct,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from policy import PHASE,MODE,GROUP,validate
from prepare import ROOT,HERE,PROJECT,build,validate_stage,load,sha,digest,verify_archive
import supervisor

class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.g={'phase':PHASE,'mode':MODE,'allowedGroups':[GROUP],'grantId':'unit-only','authorized':True,'expiresUnix':101.,'sourceSha256':'a'*64,'engineSha256':'b'*64}
        self.args=dict(group=GROUP,mode=MODE,grant_id='unit-only',source_hash='a'*64,engine_hash='b'*64,now=100.)
    def test_exact_contract(self):validate(self.g,**self.args)
    def test_phase_mode_permissions_and_seals_fail_closed(self):
        for field,value in [('phase','snap-query-compare-only-v1'),('mode','compare-only'),('mode','positive'),('allowedGroups',['query-compare']),('allowedGroups',['map']),('allowedGroups',['ref']),('allowedGroups',[GROUP,GROUP]),('allowedGroups',[GROUP,'positive']),('authorized',1),('grantId',''),('sourceSha256','0'*64),('engineSha256','c'*64),('expiresUnix',True),('expiresUnix',float('inf')),('expiresUnix',99)]:
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):validate({**self.g,field:value},**self.args)
        for key in self.g:
            bad=self.g.copy();del bad[key]
            with self.assertRaises(ValueError):validate(bad,**self.args)
        for key in ['debug','simulation','continueAfterFailure','groups','override','secondResponse']:
            with self.assertRaises(ValueError):validate({**self.g,key:False},**self.args)
    def test_cli_rejects_duplicate_unknown_and_missing_options(self):
        args=['--fixture','/stage','--af-root','/af','--engine','/explicit/godot','--group',GROUP,'--mode',MODE,'--grant-id','unit-only','--grant-sha256','a'*64]
        with contextlib.redirect_stderr(io.StringIO()):
            for extra in [['--mode',MODE],['--grant-id','again'],['--debug'],['--simulation'],['--candidate'],['--ae-root','/ae']]:
                with self.assertRaises(SystemExit):supervisor.parser().parse_args(args+extra)
            with self.assertRaises(SystemExit):supervisor.parser().parse_args(args[:-2])
        parsed=supervisor.parser().parse_args(args);command=supervisor.argv_for(Path('/explicit/godot'),Path('/stage'),parsed)
        self.assertEqual(command[0],'/explicit/godot');self.assertNotIn('--editor',command);self.assertIn('--single-threaded-scene',command)
        parsed.mode='compare-only'
        with self.assertRaises(ValueError):supervisor.argv_for(Path('/explicit/godot'),Path('/stage'),parsed)
    def test_gd_policy_vocabulary(self):
        gd=(ROOT/'godot/tests/walker_parity_response/policy.gd').read_text()
        for key,value in [('PHASE',PHASE),('MODE',MODE),('GROUP',GROUP)]:self.assertIn(f'const {key} := "{value}"',gd)
        self.assertEqual(set(json.loads(re.search(r'const KEYS := (\[.*\])',gd)[1])),set(self.g))
        for expression in ['grant.size()!=KEYS.size()','grant.allowedGroups!=[GROUP]','grant.authorized is bool','grant.expiresUnix is float or grant.expiresUnix is int','hash_valid(source_hash)','grant.mode!=MODE']:self.assertIn(expression,gd)
    def test_success_requires_one_up_parent_and_guard_not_collection_alone(self):
        r={'phase':PHASE,'mode':MODE,'group':GROUP,'sourceSha256':'s','grantSha256':'g','engineSha256':'e','failed':False,'candidateResponseCollected':True,'responseGuardPassed':True,'candidateAttempts':1,'appliedUpCount':1,'parentResponseCount':1,'positiveAdmission':False,'nativeStepAdmission':False,'outcome':'single_response_guard_passed_not_positive_admission'}
        self.assertTrue(supervisor.successful_response(r,'s','g','e'))
        for field,value in [('responseGuardPassed',False),('appliedUpCount',0),('appliedUpCount',True),('appliedUpCount',2),('parentResponseCount',0),('candidateAttempts',2),('failed',True),('positiveAdmission',True),('outcome','parity_policy_rejected'),('engineSha256','wrong')]:
            self.assertFalse(supervisor.successful_response({**r,field:value},'s','g','e'))

class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='parity-response-unit-',dir='/tmp/opencode');self.base=Path(self.tmp.name)
        self.root=self.base/'repo';self.root.mkdir();self.stage=self.base/'scratch';self.stage.mkdir();self.af=self.base/'af';self.af.mkdir()
        rows={}
        for i in range(24):
            p=self.af/f'evidence-{i}.txt';p.write_text(str(i));rows[p.name]={'sha256':sha(p),'bytes':p.stat().st_size}
        self.manifest=self.af/'manifest.json';self.manifest.write_text(json.dumps({'files':rows}))
        script=self.root/'godot/test.gd';script.parent.mkdir();script.write_text('extends SceneTree\n')
        self.pins={'AFManifestPath':'manifest.json','AFManifestSha256':sha(self.manifest),'hostInputs':{},'productionDependencies':{'godot/test.gd':sha(script)},'stageInputs':{'godot/test.gd':sha(script)},'projectSha256':digest(PROJECT.encode())}
    def tearDown(self):self.tmp.cleanup()
    def build(self,name='parity-response-unit-01'):return build(name,self.af,root=self.root,stage_parent=self.stage,pins=self.pins)
    def test_real_prepare_writeonce_and_validate_no_launch(self):
        with patch('subprocess.Popen',side_effect=AssertionError('no children')):
            dest=self.build();validate_stage(dest,root=self.root,pins=self.pins)
        self.assertEqual(load(dest/'source.json')['AFIdentity']['filesVerified'],24)
        self.assertFalse((dest/'grant.json').exists());self.assertFalse((dest/'response-result.json').exists())
        with self.assertRaises(FileExistsError):self.build()
        (dest/'test.gd').write_text('tampered')
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)
    def test_bad_inventory_or_member_prevents_first_write(self):
        (self.af/'evidence-23.txt').write_text('tampered')
        with self.assertRaises(ValueError):self.build()
        self.assertEqual(list(self.stage.iterdir()),[])
        self.manifest.write_text('{}')
        with self.assertRaises(ValueError):self.build()
    def test_source_namespace_and_symlink_pins(self):
        for name in ['parity-response-AG-01','parity-response-a/01','../parity-response-a','parity-response--a','snap-compare-af-01']:
            with self.assertRaises(ValueError):self.build(name)
        (self.stage/'parity-response-unit-01').symlink_to(self.af,target_is_directory=True)
        with self.assertRaises(ValueError):self.build()
        (self.stage/'parity-response-unit-01').unlink();(self.root/'godot/test.gd').write_text('modified')
        with self.assertRaises(ValueError):self.build()
    def test_duplicate_json_keys(self):
        p=self.base/'duplicate.json';p.write_text('{"mode":"single-response","mode":"positive"}')
        with self.assertRaises(ValueError):load(p)
    def test_unlisted_file_and_substituted_source_receipt(self):
        dest=self.build();rogue=dest/'extra.gd';rogue.write_text('extends Node')
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)
        rogue.unlink();receipt=load(dest/'source.json');receipt['files']['res://test.gd']='0'*64;(dest/'source.json').write_text(json.dumps(receipt))
        with self.assertRaises(ValueError):validate_stage(dest,root=self.root,pins=self.pins)

class SupervisorTests(unittest.TestCase):
    setUp=PreparationTests.setUp
    tearDown=PreparationTests.tearDown
    build=PreparationTests.build
    def invoke(self,*,signal_error=None,audits=None,reused=False,write_error=False,deadline=False,held=False,fast_error=False):
        self.stage=self.root/'godot/tests/walker_parity_response';self.stage.mkdir(parents=True);dest=self.build()
        engine=self.base/'binary';engine.write_bytes(b'not executable; mocked only')
        grant={'phase':PHASE,'mode':MODE,'allowedGroups':[GROUP],'grantId':'unit','authorized':True,'expiresUnix':9999999999,'sourceSha256':sha(dest/'source.json'),'engineSha256':sha(engine)}
        (dest/'grant.json').write_text(json.dumps(grant))
        args=supervisor.parser().parse_args(['--fixture',str(dest),'--af-root',str(self.af),'--engine',str(engine),'--group',GROUP,'--mode',MODE,'--grant-id','unit','--grant-sha256',sha(dest/'grant.json')])
        owned={'pid':123456789,'pgid':123456789,'startTicks':777};residual={**owned,'pid':123456790,'startTicks':778}
        handlers={n:supervisor.signal.getsignal(n) for n in [supervisor.signal.SIGTERM,supervisor.signal.SIGHUP,supervisor.signal.SIGINT]};real_write=supervisor.write
        def write_receipt(path,value):
            with (self.base/'lock').open('a+') as other:
                with self.assertRaises(BlockingIOError):fcntl.flock(other,fcntl.LOCK_EX|fcntl.LOCK_NB)
            if write_error and path.name=='supervisor-result.json':raise OSError('receipt disk failure')
            real_write(path,value)
        def completed(**kwargs):
            if fast_error:(dest/'supervisor.log').write_text('SCRIPT ERROR: mock fast exit\n')
            (dest/'response-result.json').write_text(json.dumps({'phase':PHASE,'mode':MODE,'group':GROUP,'sourceSha256':sha(dest/'source.json'),'grantSha256':args.grant_sha256,'engineSha256':sha(engine),'failed':False,'candidateResponseCollected':True,'responseGuardPassed':True,'candidateAttempts':1,'appliedUpCount':1,'parentResponseCount':1,'positiveAdmission':False,'nativeStepAdmission':False,'outcome':'single_response_guard_passed_not_positive_admission'}))
            return -9 if deadline else 0
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(supervisor,'ROOT',self.root));stack.enter_context(patch.object(supervisor,'LOCK',self.base/'lock'))
            stack.enter_context(patch.object(supervisor,'validate_stage',side_effect=lambda d:validate_stage(d,root=self.root,pins=self.pins)))
            stack.enter_context(patch.object(supervisor,'load',side_effect=lambda p:self.pins if p==HERE/'review-pins.json' else load(p)))
            launch=stack.enter_context(patch.object(supervisor.subprocess,'Popen'));launch.return_value.pid=owned['pid'];launch.return_value.poll.return_value=None if deadline else 0;launch.return_value.wait.side_effect=completed
            stack.enter_context(patch.object(supervisor,'identity',side_effect=[owned,owned,None] if deadline else [owned,{**owned,'startTicks':999} if reused else None]))
            census=stack.enter_context(patch.object(supervisor,'members',side_effect=[[],[],[],[],[]] if deadline else [[residual]]+(audits if audits is not None else [[],[],[]])))
            stack.enter_context(patch.object(supervisor.time,'sleep'))
            if deadline:stack.enter_context(patch.object(supervisor.time,'monotonic',side_effect=[0,181,181]))
            kill=stack.enter_context(patch.object(supervisor.os,'killpg',side_effect=signal_error));stack.enter_context(patch.object(supervisor,'write',side_effect=write_receipt));stderr=stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            if held:
                lock=stack.enter_context((self.base/'lock').open('a+'));fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with self.assertRaises(BlockingIOError):supervisor.main(args)
                launch.assert_not_called();self.assertFalse((dest/'supervisor-start.json').exists());return
            code=supervisor.main(args)
            self.assertEqual(census.call_count,5 if deadline else 4)
            if reused:kill.assert_not_called()
            else:kill.assert_called_once_with(owned['pgid'],supervisor.signal.SIGKILL)
            self.assertTrue(launch.call_args.kwargs['start_new_session'])
        self.assertEqual({n:supervisor.signal.getsignal(n) for n in handlers},handlers)
        with (self.base/'lock').open('a+') as other:fcntl.flock(other,fcntl.LOCK_EX|fcntl.LOCK_NB)
        report=json.loads(stderr.getvalue()) if write_error else load(dest/'supervisor-result.json');self.assertEqual(len(report['releaseAudits']),3)
        return code,report
    def test_deadline_remains_failure_with_clean_release(self):
        code,r=self.invoke(deadline=True);self.assertEqual(code,1);self.assertTrue(r['releasedCleanly']);self.assertEqual(r['stopReason'],'external_timeout')
    def test_nonwaiting_lock(self):self.invoke(held=True)
    def test_fast_script_error_cannot_be_overridden_by_success_receipt(self):
        code,r=self.invoke(fast_error=True);self.assertEqual(code,1);self.assertEqual(r['stopReason'],'engine_script_error');self.assertTrue(r['releasedCleanly'])
    def test_residual_exit_race_three_empty_measurements(self):
        code,r=self.invoke(signal_error=ProcessLookupError());self.assertEqual(code,0);self.assertTrue(r['releasedCleanly']);self.assertTrue(r['residualGroupDisappearedBeforeSignal'])
    def test_permission_error_fails_despite_empty_audits(self):
        code,r=self.invoke(signal_error=PermissionError());self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_esrch_does_not_hide_survivor(self):
        code,r=self.invoke(signal_error=ProcessLookupError(),audits=[[],[{'pid':123456790}],[]]);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_failed_audit_is_unknown_not_empty(self):
        code,r=self.invoke(audits=[PermissionError(),[],[]]);self.assertEqual(code,1);self.assertFalse(r['releaseAudits'][0]['measured']);self.assertIsNone(r['releaseAudits'][0]['members'])
    def test_pid_reuse_never_signals(self):
        code,r=self.invoke(reused=True);self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_receipt_write_failure_restores_handlers_and_lock(self):
        code,r=self.invoke(write_error=True);self.assertEqual(code,1);self.assertTrue(r['failed']);self.assertEqual(r['cleanupErrors'][-1]['operation'],'write_result')

class SourceTests(unittest.TestCase):
    def test_kinematic_numeric_shape_api_and_frozen_query_projection(self):
        import xml.etree.ElementTree as ET
        xml=ET.parse(HERE.parent/'walker-admission/KinematicCollision3D.xml').getroot()
        self.assertEqual(xml.find(".//method[@name='get_collider_shape']/return").attrib['type'],'Object')
        self.assertEqual(xml.find(".//method[@name='get_collider_shape_index']/return").attrib['type'],'int')
        self.assertEqual(len(xml.findall(".//method[@name='get_depth']/param")),0)
        pair=(ROOT/'godot/tests/walker_snap_parity/query_pair.gd').read_text()
        self.assertIn('full.travel.length()>body.safe_margin else Vector3.ZERO',pair)
        self.assertIn('body.up_direction*full.travel.dot(body.up_direction)',pair)
        frozen=(ROOT/'godot/tests/walker_snap_parity/planner.gd').read_text()
        for clause in ['if not plan.accepted: return plan','result.get_collision_count()>=4','result.get_collider_rid(i)!=plan.supportRid','result.get_collider_shape(i)!=int(plan.supportShape)','parent_snap_contact_off_certified_plane','cos(body.floor_max_angle)']:
            self.assertIn(clause,frozen)
    def test_candidate_closure_is_distinct_from_AF(self):
        pins=load(HERE/'review-pins.json');af=load(HERE.parent/'walker-snap-compare/review-pins.json')
        self.assertEqual(len(pins['stageInputs']),13);self.assertEqual(len(af['stageInputs']),9)
        self.assertFalse(any('candidate.gd' in p or '/planner.gd' in p for p in af['stageInputs']))
        self.assertIn('godot/tests/walker_parity_response/candidate.gd',pins['stageInputs'])
        for name,h in pins['stageInputs'].items():
            self.assertEqual(sha(ROOT/name),h)
            for dep in re.findall(r'(?:preload\(|extends )"([^"]+)"',(ROOT/name).read_text()):
                relative='godot/'+dep[6:] if dep.startswith('res://') else str(Path(name).parent/dep)
                self.assertIn(relative,pins['stageInputs'])
        for name,h in af['stageInputs'].items():self.assertEqual(sha(ROOT/name),h)
    def test_single_factory_and_first_trigger_stops(self):
        driver=(ROOT/'godot/tests/walker_parity_response/driver.gd').read_text();candidate=(ROOT/'godot/tests/walker_parity_response/candidate.gd').read_text()
        self.assertEqual(re.findall(r'(\w+)\.new\(',driver),['Candidate'])
        self.assertEqual(driver.count('body.step('),1);self.assertEqual(candidate.count('move_and_collide('),1)
        self.assertIn('if not original.accepted:',driver);self.assertIn('body.ordinary_step(',driver)
        self.assertIn('finish("single_response_guard_passed_not_positive_admission",false,0);return',driver)
        self.assertIn('range(60)',driver);self.assertIn('create_timer(170)',driver);self.assertEqual(supervisor.EXTERNAL_SECONDS,180)
        self.assertIn('if response_attempts!=0',candidate);self.assertNotRegex(candidate,r'(global_position|velocity)\s*=')
        self.assertLess(candidate.index('move_and_collide('),candidate.index('telemetry.beforeParent'))
        self.assertLess(candidate.index('telemetry.beforeParent'),candidate.index('ResponseGuard.inspect('))
        self.assertIn('get_collider_shape_index(index)',candidate)
    def test_original_guard_postconditions_and_AF_supervisor_lifecycle_unchanged(self):
        pins=load(HERE/'review-pins.json');guard='godot/tests/walker_step_up/response_guard.gd';self.assertEqual(sha(ROOT/guard),pins['stageInputs'][guard])
        old=(ROOT/'godot/tests/walker_snap_parity/candidate.gd').read_text();new=(ROOT/'godot/tests/walker_parity_response/candidate.gd').read_text()
        for line in old.splitlines():
            if 'candidate_fault =' in line and ('elif ' in line or 'if not response.passed' in line):self.assertIn(line.strip(),new)
        old_py=(HERE.parent/'walker-snap-compare/supervisor.py').read_text();new_py=(HERE/'supervisor.py').read_text()
        for name in ['Once','identity','members','cleanup_error','audit_release']:
            def subtree(text):return ast.dump(next(n for n in ast.parse(text).body if isinstance(n,(ast.FunctionDef,ast.ClassDef)) and n.name==name),include_attributes=False)
            self.assertEqual(subtree(old_py),subtree(new_py))
    def test_AF_trace_float32_projection_and_AE_guard_counterexamples(self):
        import sys
        sys.path.insert(0,str(HERE.parent/'walker-step-up'));from response_oracle import agrees,budget
        f32=lambda v:struct.unpack('<f',struct.pack('<f',v))[0]
        raw=ROOT/'godot/tests/walker_snap_compare/snap-compare-af-01/comparison-result.json'
        manifest_path=HERE.parent/'walker-snap-compare-af/evidence/artifact-inventory.json'
        self.assertEqual(sha(manifest_path),load(HERE/'review-pins.json')['AFManifestSha256'])
        manifest=load(manifest_path)
        self.assertEqual(sha(raw),manifest['files'][str(raw.relative_to(ROOT))]['sha256'])
        event=load(raw)['records'][-1];pair=event['comparison'];s=pair['short32'];p=pair['parentSnap4']
        short=f32(f32(s['from']['origin'][1])+f32(s['travel'][1]));projected=f32(f32(p['from']['origin'][1])+f32(p['travel'][1]))
        self.assertGreater(abs(p['travel'][1]),p['margin']);self.assertAlmostEqual(short-projected,21.845102310180664e-6,places=15)
        ae=load(HERE.parent/'walker-snap-parity/AE-witness.json')['response'];self.assertEqual(projected,f32(ae['after'][1]))
        self.assertEqual(pair['parentForward6']['travel'],pair['parentForward6']['motion']);self.assertEqual(event['wholeFrameDelta'],[0,0,0])
        self.assertFalse(agrees(ae['proposal']['expectedFinal'],ae['after'],ae['proposal']['horizontalBudget'],ae['proposal']['horizontalBudget'],(42,0),(42,0)))
        self.assertEqual(budget(ae['proposal']['expectedFinal'],ae['after']),1e-6)
        self.assertFalse(agrees((0,.12,.10),(.04,.10,.08),(0,0,.1),(0,0,.1),(42,0),(42,0)))
        self.assertFalse(agrees((0,.12,.1),(0,.12,.1),(0,0,.1),(0,0,.1),(42,0),(42,1)))
        planner=(ROOT/'godot/tests/walker_parity_response/planner.gd').read_text();self.assertNotIn('.087755',planner);self.assertIn('forward.travel!=forward.motion',planner)

if __name__=='__main__':unittest.main()

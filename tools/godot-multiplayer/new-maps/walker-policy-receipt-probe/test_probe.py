"""Portable source/contract tests. Child lifecycle is mocked; no native staging."""
import copy,json,math,tempfile,time,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch,Mock
import contract as C
import prepare as P
import supervisor as S
import ownership as O

def native_result():
    r={'phase':C.PHASE,'mode':C.MODE,'group':C.GROUP,'sourceSha256':'a'*64,'grantSha256':'b'*64,'engineSha256':C.ENGINE,'receiptSha256':C.RECEIPT,'originalSourceSha256':C.AI_SOURCE,'originalGrantSha256':C.AI_GRANT,'originalPolicySha256':C.POLICY,'originalEvidenceSha256':C.EVIDENCE,'clonePolicySha256':'c'*64,'cloneEvidenceSha256':'d'*64,'probeCollected':True,'originalPolicyResult':False,'correctedPolicyResult':True,'controls':[{'name':name,'type':C.CONTROL_TYPES[i],'integerGuard':i<6,'originalMembership':i<2,'numericDomain':i<4} for i,name in enumerate(C.CONTROL_NAMES)],'mutants':[{'name':name,'correctedPolicyResult':False} for name in C.MUTANTS],'candidateRecords':678,'membershipFailures':678,'variantAgreementPass':True,'mutantRejectionsPass':True,'hypothesisConfirmed':True,'diagnostic':{'schema':'ai-policy-source-diagnostic-v1','originalPolicyResult':False,'location':'undetermined','nativeCountersKnown':False,'physicalCallCounts':None},'positiveAdmission':False,'nativeStepAdmission':False,'productionPromotion':False,'candidateMapWalks':0}
    return r
def collected(r):return C.collected(r,'a'*64,'b'*64,C.ENGINE,'c'*64,'d'*64)
def grant():return {'phase':C.PHASE,'mode':C.MODE,'allowedGroups':[C.GROUP],'grantId':'TEST-NOT-AUTHORITY','authorized':True,'expiresUnix':time.time()+1000,'sourceSha256':'a'*64,'engineSha256':C.ENGINE}

class ContractTests(unittest.TestCase):
    def test_confirmed_and_disproved_are_both_collections(self):
        r=native_result();self.assertTrue(collected(r))
        r['correctedPolicyResult']=False;r['hypothesisConfirmed']=False;self.assertTrue(collected(r))
        r['originalPolicyResult']=True;r['diagnostic']['originalPolicyResult']=True;self.assertTrue(collected(r))
    def test_contradictory_confirmation_rejected(self):
        for field,value in [('originalPolicyResult',True),('correctedPolicyResult',False),('membershipFailures',0),('variantAgreementPass',False),('mutantRejectionsPass',False)]:
            r=native_result();r[field]=value;self.assertFalse(collected(r),field)
    def test_scope_and_hashes_never_relabel_campaign(self):
        for key,value in [('phase','parity-admission-synthetic-v1'),('group','negative-controls'),('receiptSha256','0'*64),('originalSourceSha256','0'*64),('engineSha256','0'*64),('cloneEvidenceSha256','0'*64),('positiveAdmission',True),('candidateMapWalks',1)]:
            r=native_result();r[key]=value;self.assertFalse(collected(r),key)
    def test_control_tamper_requires_consistent_nonconfirmation(self):
        r=native_result();r['controls'][2]['originalMembership']=True;self.assertFalse(collected(r))
        r['variantAgreementPass']=False;r['hypothesisConfirmed']=False;self.assertTrue(collected(r))
        r['mutants'][0]['correctedPolicyResult']=True;self.assertFalse(collected(r))
        r['mutantRejectionsPass']=False;self.assertTrue(collected(r))
    def test_invalid_shapes_booleans_duplicate_controls(self):
        for change in [lambda r:r.update(candidateRecords=True),lambda r:r.update(extra=1),lambda r:r['controls'].pop(),lambda r:r['controls'].__setitem__(1,r['controls'][0]),lambda r:r['controls'][0].update(numericDomain=1),lambda r:r['diagnostic'].update(path='/untrusted')]:
            r=native_result();change(r);self.assertFalse(collected(r))
    def test_grant_exact_keys_scope_expiry_and_hash(self):
        g=grant();C.validate_grant(g,C.GROUP,C.MODE,g['grantId'],'a'*64,C.ENGINE,time.time())
        for k,v in [('allowedGroups',[C.GROUP,'negative-controls']),('phase','synthetic'),('authorized',1),('expiresUnix',math.nan),('expiresUnix',0),('sourceSha256','0'*64),('engineSha256','0'*64),('extra',False)]:
            x=copy.deepcopy(g);x[k]=v
            with self.assertRaises(ValueError):C.validate_grant(x,C.GROUP,C.MODE,g['grantId'],'a'*64,C.ENGINE,time.time())
    def test_native_diagnostic_bounds_and_operand_schema(self):
        r=native_result();d=r['diagnostic'];d.update(location='Evidence.profile.lifecycle_invariant',caseIndex=0,profileIndex=1,sourceLine=139,recordSection='settle',recordIndex=0,checks=[True,True,True,False,True,True],checkOrder=['returned','frame','integer_up','up_membership','parent_calls','accepted_type'],up={'type':3,'number':0},allowed=[{'type':2,'number':0},{'type':2,'number':1}],numericAlternative=True)
        self.assertTrue(collected(r));self.assertLess(len(json.dumps(r).encode()),8192)
        d['checks'][3]=True;self.assertFalse(collected(r));d['checks'][3]=False
        r['originalPolicyResult']=True;d['originalPolicyResult']=True;r['hypothesisConfirmed']=False;self.assertFalse(collected(r))
        r['originalPolicyResult']=False;d['originalPolicyResult']=False;r['hypothesisConfirmed']=True
        d['up']['number']=math.nan;self.assertFalse(collected(r))
    def test_marker_single_bounded_and_errors_override(self):
        line='PROBE_RESULT '+json.dumps(native_result())+'\n';self.assertEqual(S.extract(line),native_result())
        for text in [line+line,line+'SCRIPT ERROR: fast exit',line+'Parse Error: fast',line+'ADMISSION_FAILURE {}',line+'PROBE_FAILURE {}','PROBE_RESULT '+(' '*8193)+'{}']:
            with self.assertRaises(ValueError):S.extract(text)
    def test_duplicate_json_keys_rejected(self):
        with self.assertRaises(ValueError):S.extract('PROBE_RESULT {"x":1,"x":2}')

class SourceTests(unittest.TestCase):
    def test_exact_one_clause_and_one_import_only(self):
        s=P.sources();e=s[P.OLD+'evidence.gd'];p=s[P.OLD+'policy.gd'];ce=s['probe/cloned_evidence.gd'];cp=s['probe/cloned_policy.gd']
        self.assertEqual(ce.replace(P.REPLACEMENT,P.NEEDLE),e)
        self.assertEqual(cp.replace(b'preload("cloned_evidence.gd")',b'preload("evidence.gd")'),p)
        self.assertIn(b'not integer(up) or (up != 0 and up != 1)',ce)
        self.assertEqual(sum(n.endswith('.gd') for n in s),6)
    def test_missing_duplicate_or_modified_source_fails_closed(self):
        s=P.sources();e=s[P.OLD+'evidence.gd'];p=s[P.OLD+'policy.gd']
        for bad in [e.replace(P.NEEDLE,b'false'),e+P.NEEDLE,e+b'\n']:
            with self.assertRaises(ValueError):P.clone(bad,p)
    def test_minimal_closure_no_scene_controller_or_world(self):
        s=P.sources()
        for n,b in s.items():
            for forbidden in [b'Walker',b'PhysicsServer',b'Node3D.new',b'CharacterBody3D',b'[autoload]',b'run/main_scene']:
                self.assertNotIn(forbidden,b,n)
        driver=s['probe/driver.gd']
        self.assertIn(b'worker_pool/max_threads=1',s['project.godot'])
        self.assertIn(b'170000',driver);self.assertIn(b'>8192',driver)
        self.assertNotIn(b'FileAccess.WRITE',driver)
    def test_actual_AI40_readonly_and_current_pins(self):
        p=P.verify_ai(P.ROOT.parent/'cocs-walker-parity-admission-ai');self.assertEqual(P.sha(p),C.RECEIPT);P.verify_host()
    def test_build_never_creates_grant_or_runs(self):
        text=(P.HERE/'prepare.py').read_text()
        self.assertNotIn('subprocess',text)
        self.assertNotIn("write(dest/'grant.json'",text)
        with patch.object(P,'verify_host'),patch.object(P,'verify_ai',return_value=Path('unused')):
            for name in ['../escape','UPPER','negative-controls','policy-receipt-probe-']:
                with self.assertRaises(ValueError):P.build(name,'unused')
    def test_virtual_stage_seals_reject_tampering_without_staging(self):
        content=P.sources();dest=P.PARENT/'policy-receipt-probe-test-01'
        hashes={n:P.sha_bytes(b) for n,b in content.items()}
        config={'phase':C.PHASE,'mode':C.MODE,'group':C.GROUP,'namespace':dest.name,'files':hashes,'receiptSha256':C.RECEIPT,'AIManifestSha256':C.AI_MANIFEST,'hostPinsSha256':'e'*64}
        def check(c,bad_file=None):
            def digest(p):
                if p==P.HERE/'review-pins.json':return 'e'*64
                return '0'*64 if str(p.relative_to(dest))==bad_file else C.RECEIPT if p.name=='frozen-negative.json' else hashes[str(p.relative_to(dest))]
            with patch.object(P,'verify_host'),patch.object(P,'load',return_value=c),patch.object(P,'sha',side_effect=digest),patch.object(Path,'resolve',lambda p:p),patch.object(Path,'rglob',return_value=[]):return P.validate_stage(dest)
        self.assertEqual(check(config),config)
        for name in list(hashes)+['frozen-negative.json']:
            with self.assertRaises(ValueError):check(config,name)
        for field in ['phase','receiptSha256','AIManifestSha256']:
            bad=copy.deepcopy(config);bad[field]='wrong'
            with self.assertRaises(ValueError):check(bad)
    def test_write_once_metadata(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode',prefix='probe-write-test-') as td:
            p=Path(td)/'metadata.json';P.write(p,{'first':True})
            with self.assertRaises(FileExistsError):P.write(p,{'second':True})
            self.assertEqual(P.load(p),{'first':True})

class LifecycleTests(unittest.TestCase):
    def invoke(self,kind='ok',returncode=0):
        # Metadata-only sandbox. No native scripts or fixture staging; Popen mocked.
        with tempfile.TemporaryDirectory(prefix='probe-mock-',dir='/tmp/opencode') as td:
            dest=Path(td);engine=dest/'not-an-engine';engine.touch()
            (dest/'grant.json').write_text(json.dumps(grant()))
            a=SimpleNamespace(fixture=str(dest),engine=str(engine),ai_root='unused',group=C.GROUP,mode=C.MODE,grant_id='TEST-NOT-AUTHORITY',grant_sha256='b'*64)
            config={'files':{'probe/cloned_policy.gd':'c'*64,'probe/cloned_evidence.gd':'d'*64}}
            own={'pid':99999999,'pgid':99999999,'startTicks':123}
            def digest(p):return C.ENGINE if p==engine else 'b'*64 if p.name=='grant.json' else 'a'*64
            def spawn(*args,**kw):
                text='PROBE_RESULT '+json.dumps(native_result())+'\n'
                if kind=='script':text+='SCRIPT ERROR: fast exit\n'
                if kind=='duplicate':text+=text
                kw['stdout'].write(text.encode());kw['stdout'].flush()
                if kind=='spawn_error':raise OSError('mock launch error')
                child=Mock(pid=own['pid']);child.poll.return_value=returncode;child.wait.return_value=returncode
                if kind=='timeout':child.poll.return_value=None
                return child
            with patch.object(S,'LOCK',dest/'lock'),patch.object(S,'EXTERNAL_SECONDS',-1 if kind=='timeout' else 180),patch.object(S,'validate_stage',return_value=config),patch.object(S,'verify_ai'),patch.object(S,'sha',side_effect=digest),patch.object(S.subprocess,'Popen',side_effect=spawn) as popen,patch.object(O,'identity',return_value=own),patch.object(O,'members',return_value=[]),patch.object(O.os,'killpg') as kill,patch.object(O.time,'sleep'),patch.object(S.signal,'signal'):
                code=S.main(a);report=json.loads((dest/'probe-supervisor.json').read_text())
                self.assertEqual(popen.call_count,1)
                with self.assertRaises(FileExistsError):S.main(a)
                self.assertEqual(popen.call_count,1)
                return code,report,kill.call_count
    def test_success_collection_has_three_empty_audits_and_no_promotion(self):
        code,r,kills=self.invoke();self.assertEqual(code,0);self.assertTrue(r['probeCollected']);self.assertTrue(S.release_valid(r));self.assertFalse(r['positiveAdmission']);self.assertEqual(kills,0)
    def test_fast_exit_error_overrides_valid_result(self):
        code,r,_=self.invoke('script');self.assertEqual(code,1);self.assertEqual(r['stopReason'],'engine_script_error')
    def test_nonzero_exit_cannot_be_collection_success(self):
        code,r,_=self.invoke(returncode=2);self.assertEqual(code,1);self.assertTrue(r['failed'])
    def test_duplicate_record_is_failure(self):
        code,r,_=self.invoke('duplicate');self.assertEqual(code,1);self.assertFalse(r['probeCollected'])
    def test_timeout_signals_only_verified_owned_group(self):
        code,r,kills=self.invoke('timeout');self.assertEqual(code,1);self.assertEqual(r['stopReason'],'external_timeout');self.assertEqual(kills,1)
    def test_launch_failure_consumes_attempt_and_cannot_claim_release(self):
        code,r,_=self.invoke('spawn_error');self.assertEqual(code,1);self.assertFalse(r['releasedCleanly'])
    def test_esrch_requires_empty_measured_audits(self):
        own={'pid':100,'pgid':100,'startTicks':10};r={'releaseAudits':[]}
        with patch.object(O,'identity',return_value=None),patch.object(O,'members',side_effect=[[own],[],[],[]]),patch.object(O.os,'killpg',side_effect=ProcessLookupError),patch.object(O.time,'sleep'):
            O.audit_release(own,r)
        self.assertTrue(r['releasedCleanly']);self.assertEqual(len(r['releaseAudits']),3)
    def test_reused_identity_refuses_signal_and_release(self):
        own={'pid':100,'pgid':100,'startTicks':10};r={'releaseAudits':[]}
        with patch.object(O,'identity',return_value={**own,'startTicks':20}),patch.object(O,'members',return_value=[]),patch.object(O.os,'killpg') as kill,patch.object(O.time,'sleep'):
            O.audit_release(own,r)
        kill.assert_not_called();self.assertFalse(r['releasedCleanly'])
    def test_unmeasured_or_duplicate_audit_never_releases(self):
        _,r,_=self.invoke()
        r['releaseAudits'][1]=copy.deepcopy(r['releaseAudits'][0]);self.assertFalse(S.release_valid(r))
        r['releaseAudits'][1]['measured']=False;self.assertFalse(S.release_valid(r))
    def test_partial_handler_setup_is_inside_finally(self):
        # Structural supplement: successful native parsing is not claimed.
        text=(P.HERE/'supervisor.py').read_text()
        self.assertLess(text.index('        try:\n            for number'),text.index('handlers[number]=signal.signal'))
        self.assertIn('for number,handler in handlers.items():',text)
        self.assertIn('fcntl.LOCK_EX|fcntl.LOCK_NB',text)

if __name__=='__main__':unittest.main()

"""Offline AG one-response regression and synthetic serialized-campaign attacks.
No GDScript execution, Godot import, subprocess or native admission claim.
"""
import copy,json,math,unittest,hashlib
from pathlib import Path
from evidence import guarded,negative_stages,support,inclined_witness,canonical,spec_equal
from policy import GROUPS,successful
from prepare import ROOT,HERE
from receipt_fixtures import campaign_fixture,ag_record
import test_admission as previous

def ag_unit():
    native=copy.deepcopy(ag_record());old=native['records'][-1];params=native['parameters']
    row={'proposal':old['parityProposal'],'telemetry':old['candidateTelemetry'],'before':old['beforeOriginalProof'],'after':old['afterCandidate'],'bodyRid':native['bodyRid'],'floorConstantSpeed':params['floorConstantSpeed'],'wholeFrameDelta':old['wholeFrameDelta'],'slides':old['slides'],'input':old['input'],'sprint':old['sprint'],'jump':old['jump'],'actualDelta':old['actualDelta']}
    # New serialization fields: identity already recorded by AG at top level and
    # in upRequest, and pinned fresh-parameter exclusion defaults. Raw operands stay intact.
    row['proposal']['responseGuard']['support'].update(bodyRid=native['bodyRid'],excludeBodies=[],excludeObjects=[])
    p={'targetRid':native['targetRid'],'parameters':{'bodyRid':native['bodyRid'],'margin':params['safeMargin'],'floorAngle':params['floorMaxAngle'],'walk':params['walkSpeed']}}
    return row,p

class SupportOperandTests(unittest.TestCase):
    def archive(self,label,namespace,name):
        old=json.loads((HERE/'source-provenance.json').read_text());root=Path(old['archives'][label]['root'])
        path=root/name
        if not path.is_file():self.skipTest('Explicit historical '+label+' producer not present')
        manifest_path=HERE.parent/namespace/'evidence/artifact-inventory.json'
        self.assertEqual(hashlib.sha256(manifest_path.read_bytes()).hexdigest(),old['archives'][label]['manifestSha256'])
        manifest=json.loads(manifest_path.read_text());self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),manifest['files'][name]['sha256'])
        return json.loads(path.read_text())
    def test_all34_historical_AB_baseline_stage_predicates(self):
        r=self.archive('AB','walker-step-ab','godot/tests/walker_step_up/walker-step-AB-01/controls-result.json')
        self.assertEqual(len(r['records']),34)
        for row,spec in zip(r['records'],canonical(GROUPS[0])):
            self.assertEqual({'id':row['id'],'radius':row['radius']},spec)
            self.assertTrue(negative_stages(row['profiles'][0]['observer'],row['id']),spec)
    def test_all4_historical_AD_baseline_inclined_witnesses(self):
        r=self.archive('AD','walker-admission-ad','godot/tests/walker_admission/admission-AD-01/inclined-landing-rejections-result.json')
        self.assertEqual(len(r['records']),4)
        for row,spec in zip(r['records'],canonical(GROUPS[1])):
            self.assertTrue(spec_equal(row['spec'],spec));count=0
            for frame in row['profiles'][0]['frames']:
                plan=frame['baselineObserver']
                if plan['reason']!='no_continuous_flat_landing':continue
                paths=[c['collider'] for s in plan['stages'] if s['name']=='intent' for c in s['contacts'] if c['collider'].endswith('/InclinedLanding')]
                self.assertTrue(paths)
                self.assertTrue(inclined_witness(plan,{'path':paths[0],'direction':[math.sin(spec['yaw']),0,math.cos(spec['yaw'])]}));count+=1
            self.assertEqual(count,row['profiles'][0]['inclinedPolicyWitnesses']);self.assertGreater(count,0)
    def test_AG_actual_guard_one_response_not_full_admission(self):
        path=ROOT/'godot/tests/walker_parity_response/parity-response-ag-01/response-result.json'
        manifest=json.loads((HERE.parent/'walker-parity-response-ag/evidence/artifact-inventory.json').read_text())
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),manifest['files'][str(path.relative_to(ROOT))]['sha256'])
        row,p=ag_unit();self.assertTrue(guarded(row,p))
        self.assertGreater(row['wholeFrameDelta'][1],0)
        self.assertLess(row['after']['parentPositionDelta'][1],0)
        self.assertLess(row['after']['parentRealVelocity'][1],0)
        self.assertNotEqual(row['proposal']['responseGuard']['support']['travel'],[0,0,0])
        self.assertFalse(successful(ag_record(),GROUPS[2],'s','g','e'))
    def test_actual_AG_guard_rejects_contradictory_motion_without_upgrading_archive(self):
        row,p=ag_unit();row['proposal']['responseGuard']['lastMotion']=[10,0,0]
        self.assertFalse(guarded(row,p))
    def check_mutants(self,arrival):
        original=campaign_fixture(GROUPS[2]);self.assertTrue(successful(original,GROUPS[2],'s','g','e'))
        mutations={
            'hit':lambda q:q.update(hit=False),
            'valid-result':lambda q:q.update(validResult=False),
            'origin':lambda q:q['from'].update(origin=[999,999,999]),
            'basis':lambda q:q['from']['basis'].__setitem__(0,[9,0,0]),
            'upward':lambda q:q.update(motion=[0,100,0]),
            'wrong-down-length':lambda q:q.update(motion=[0,-.3,0]),
            'margin':lambda q:q.update(margin=42),
            'contact-limit':lambda q:q.update(maxCollisions=0),
            'recovery':lambda q:q.update(recoveryAsCollision=False),
            'rays':lambda q:q.update(collideSeparationRay=False),
            'numeric-flag':lambda q:q.update(collideSeparationRay=1),
            'excluded-body':lambda q:q.update(excludeBodies=[100]),
            'excluded-object':lambda q:q.update(excludeObjects=[101]),
            'test-only':lambda q:q.update(testOnly=False),
            'body-rid':lambda q:q.update(bodyRid=999),
            'reversed':lambda q:q.update(safeFraction=.9,unsafeFraction=.1),
            'negative-safe':lambda q:q.update(safeFraction=-.1),
            'unsafe-over-one':lambda q:q.update(unsafeFraction=1.1),
            'nan-safe':lambda q:q.update(safeFraction=float('nan')),
            'inf-unsafe':lambda q:q.update(unsafeFraction=float('inf')),
            'boolean-fraction':lambda q:q.update(safeFraction=False),
            'nan-travel':lambda q:q.update(travel=[0,float('nan'),0]),
            'inf-remainder':lambda q:q.update(remainder=[float('inf'),0,0]),
            'missing-transform':lambda q:q.pop('from'),
            'count-mismatch':lambda q:q.update(collisionCount=0),
            'saturated':lambda q:q.update(contacts=q['contacts']*32),
            'no-contacts':lambda q:q.update(contacts=[]),
            'zero-normal':lambda q:q['contacts'][0].update(normal=[0,0,0]),
            'nonunit-normal':lambda q:q['contacts'][0].update(normal=[0,2,0]),
            'nan-normal':lambda q:q['contacts'][0].update(normal=[0,float('nan'),0]),
            'steep-normal':lambda q:q['contacts'][0].update(normal=[math.sin(math.radians(47)),math.cos(math.radians(47)),0]),
            'plane':lambda q:q['contacts'][0].update(point=[0,.3,0]),
            'local-shape':lambda q:q['contacts'][0].update(localShape=1),
            'support-shape':lambda q:q['contacts'][0].update(colliderShape=1),
            'moving':lambda q:q['contacts'][0].update(velocity=[.001,0,0]),
            'negative-depth':lambda q:q['contacts'][0].update(depth=-.1),
            'nan-depth':lambda q:q['contacts'][0].update(depth=float('nan')),
        }
        for label,mutate in mutations.items():
            with self.subTest(path='arrival' if arrival else 'guard',mutation=label):
                r=copy.deepcopy(original);p=r['records'][0]['profiles'][1]
                q=p['finalSupport']['query'] if arrival else p['frames'][0]['proposal']['responseGuard']['support']
                mutate(q)
                self.assertTrue(r['passed']);self.assertTrue(p['frames'][0]['responseGuardPassed'])
                self.assertFalse(successful(r,GROUPS[2],'s','g','e'))
        r=copy.deepcopy(original);p=r['records'][0]['profiles'][1]
        if arrival:p['finalSupport']['query']['contacts'][0]['colliderRid']=999
        else:p['frames'][0]['telemetry']['finalSupportIdentities'][0]['colliderRid']=999
        self.assertFalse(successful(r,GROUPS[2],'s','g','e'))
    def test_guard_support_mutants_individually(self):self.check_mutants(False)
    def test_arrival_support_mutants_individually(self):self.check_mutants(True)
    def test_guard_operands_individually(self):
        original=campaign_fixture(GROUPS[2])
        mutations={
            'guard-motion':lambda row:row['proposal']['responseGuard'].update(lastMotion=[10,0,0]),
            'actual-parent-motion':lambda row:row['after'].update(lastMotion=[10,0,0]),
            'budget':lambda row:row['proposal'].update(horizontalBudget=[0,0,.1]),
            'actual-endpoint':lambda row:row['proposal']['responseGuard'].update(actualFinal=[99,0,0]),
            'expected-endpoint':lambda row:row['proposal'].update(expectedFinal=[99,0,0]),
            'down-axis':lambda row:row['proposal']['raised']['origin'].__setitem__(0,.1),
            'parent-slides':lambda row:row['after'].update(slideCount=1),
            'guard-slides':lambda row:row['proposal']['responseGuard'].update(slideCount=1),
            'platform':lambda row:row['after'].update(platformVelocity=[1,0,0]),
            'angular-platform':lambda row:row['after'].update(platformAngularVelocity=[0,1,0]),
            'constant-speed':lambda row:row.update(floorConstantSpeed=True),
            'not-grounded':lambda row:row['after'].update(grounded=False),
            'floor-normal':lambda row:row['after'].update(floorNormal=[1,0,0]),
            'up-request-motion':lambda row:row['telemetry']['upRequest'].update(motion=[0,-.2,0]),
            'up-request-body':lambda row:row['telemetry']['upRequest'].update(bodyRid=999),
            'up-request-test':lambda row:row['telemetry']['upRequest'].update(testOnly=True),
            'up-actual-travel':lambda row:row['telemetry'].update(actualUpTravel=[0,10,0]),
            'up-modeled-pose':lambda row:row['telemetry']['upRequest']['modeledRaised']['origin'].__setitem__(1,10),
            'up-over-bound':lambda row:row['proposal'].update(upMotion=[0,.3,0]),
            'grounded-velocity':lambda row:row['after'].update(velocity=[0,1,0]),
            'parent-accounting':lambda row:row['proposal'].update(parentPositionDelta=[0,10,0]),
            'wrong-epsilon':lambda row:row['proposal']['responseGuard'].update(epsilon=.02),
            'wrong-live-body':lambda row:row.update(bodyRid=999),
        }
        for name,mutate in mutations.items():
            with self.subTest(name=name):
                r=copy.deepcopy(original);row=r['records'][0]['profiles'][1]['frames'][0];mutate(row)
                self.assertTrue(row['proposal']['responseGuard']['passed'])
                self.assertFalse(successful(r,GROUPS[2],'s','g','e'))
    def test_valid_numeric_boundaries_and_default_exclusions(self):
        row,p=ag_unit();self.assertTrue(guarded(row,p))
        q=row['proposal']['responseGuard']['support'];q.update(excludeBodies=[],excludeObjects=[],testOnly=True,collisionCount=len(q['contacts']))
        q['contacts'][0]['velocity']=[.000009,0,0] # unchanged Godot zero-approx, not 1um velocity tolerance
        self.assertTrue(guarded(row,p))
        q['contacts'][0]['velocity']=[.00001,0,0]
        self.assertFalse(guarded(row,p))
    def test_python_gd_operand_structural_parity_only(self):
        py=(HERE/'evidence.py').read_text();gd=(ROOT/'godot/tests/walker_parity_admission/evidence.gd').read_text()
        for field in ['maxCollisions','recoveryAsCollision','collideSeparationRay','safeFraction','unsafeFraction','collisionCount','floorConstantSpeed','lastMotion','platformVelocity','platformAngularVelocity','upMotion','modeledRaised','actualWholeFrameDelta','excludeBodies','excludeObjects']:
            self.assertIn(field,py);self.assertIn(field,gd)
        for function in ['guard_operands','same_transform','budget','zero']:
            self.assertIn('def '+function+'(',py);self.assertIn('static func '+function+'(',gd)

class PositiveSupervisorTests(unittest.TestCase):
    setUp=previous.PreparationTests.setUp;tearDown=previous.PreparationTests.tearDown;build=previous.PreparationTests.build;invoke=previous.SupervisorTests.invoke
    def test_mock_positive_bad_guard_is_failure_despite_summary(self):
        def mutate(r):r['records'][0]['profiles'][1]['frames'][0]['proposal']['responseGuard']['lastMotion']=[10,0,0]
        code,r=self.invoke(group_override=GROUPS[2],native_mutation=mutate)
        self.assertEqual(code,1);self.assertTrue(r['failed']);self.assertFalse(r['positiveAdmission']);self.assertTrue(r['releasedCleanly'])
    def test_mock_positive_bad_support_request_is_failure(self):
        def mutate(r):r['records'][0]['profiles'][1]['frames'][0]['proposal']['responseGuard']['support']['motion']=[0,100,0]
        code,r=self.invoke(group_override=GROUPS[2],native_mutation=mutate)
        self.assertEqual(code,1);self.assertTrue(r['failed']);self.assertFalse(r['positiveAdmission'])

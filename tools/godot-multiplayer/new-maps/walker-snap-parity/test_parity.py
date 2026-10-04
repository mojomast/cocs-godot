import hashlib,json,math,struct,sys,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-step-up'))
from response_oracle import agrees,budget
def f32(value):return struct.unpack('<f',struct.pack('<f',value))[0]
def project(travel,margin):
    return (0.,f32(travel[1]),0.) if math.sqrt(sum(x*x for x in travel))>margin else (0.,0.,0.)
class Parity(unittest.TestCase):
    def setUp(self):
        self.w=json.loads((HERE/'AE-witness.json').read_text());self.r=self.w['response'];self.p=self.r['proposal']
    def test_ae_endpoint_is_reproduced_by_float32_vector_add_not_decimal_tolerance(self):
        down=next(s for s in self.p['stages'] if s['name']=='down')
        expected=f32(f32(down['from']['origin'][1])+f32(down['travel'][1]))
        self.assertEqual(expected,f32(self.p['expectedFinal'][1]))
        actual=f32(self.r['after'][1]);self.assertEqual(actual,f32(f32(self.p['raised']['origin'][1])+f32(self.r['parentPositionDelta'][1])))
        self.assertAlmostEqual(expected-actual,2.1845102310180664e-5,places=15)
        self.assertEqual(self.p['responseGuard']['epsilon'],1e-6)
    def test_query_settings_are_not_equivalent_and_full_result_is_unknown(self):
        down=next(s for s in self.p['stages'] if s['name']=='down')
        self.assertEqual(down['maxCollisions'],32)
        self.assertAlmostEqual(-down['motion'][1],.175564289093018)
        self.assertGreater(self.w['parameters']['snap'],-down['motion'][1])
        self.assertNotIn('support',self.p['responseGuard'])
        self.assertFalse(self.p['responseGuard']['passed'])
    def test_parent_projection_threshold_and_lateral_cancellation(self):
        self.assertEqual(project((.001,-.015,0),.02),(0.,0.,0.))
        self.assertEqual(project((0.,-.02,0.),.02),(0.,0.,0.))
        self.assertEqual(project((.001,-.03,.002),.02),(0.,f32(-.03),0.))
    def test_sub_tread_foot_is_edge_support_not_full_landing(self):
        down=next(s for s in self.p['stages'] if s['name']=='down')
        normal=down['contacts'][0]['normal'];angle=math.degrees(math.acos(normal[1]/math.sqrt(sum(v*v for v in normal))))
        self.assertLess(angle,46);self.assertAlmostEqual(angle,34.863,places=2)
        self.assertLess(self.p['expectedFinal'][1],self.p['landingY'])
        self.assertEqual(down['contacts'][0]['colliderShape'],0)
        self.assertAlmostEqual(self.r['wholeFrameDelta'][1]-self.r['parentPositionDelta'][1],self.p['raised']['origin'][1]-self.r['before'][1],places=7)
    def test_existing_p1_counterexample_and_identity_remain_failures(self):
        self.assertFalse(agrees((0,.12,.10),(.04,.10,.08),(0,0,.1),(0,0,.1),(42,0),(42,0)))
        self.assertFalse(agrees((0,.12,.1),(0,.12,.1),(0,0,.1),(0,0,.1),(42,0),(42,1)))
        self.assertFalse(agrees(self.p['expectedFinal'],self.r['after'],self.p['horizontalBudget'],self.p['horizontalBudget'],(42,0),(42,0)))
        self.assertEqual(budget(self.p['expectedFinal'],self.r['after']),1e-6)
    def test_pinned_engine_callpath_parameters_and_projection(self):
        refs=HERE.parent/'walker-step-up/references';index=json.loads((refs/'index.json').read_text())
        for name in ['character_body_3d.cpp','physics_body_3d.cpp']:
            raw=(refs/name).read_bytes();self.assertEqual(hashlib.sha256(raw).hexdigest(),index['files'][name]['sha256'])
        text=(refs/'character_body_3d.cpp').read_text();snap=text.split('void CharacterBody3D::apply_floor_snap() {')[1].split('void CharacterBody3D::_snap_on_floor')[0]
        for token in ['MAX(floor_snap_length, margin)','parameters.max_collisions = 4','parameters.recovery_as_collision = true','parameters.collide_separation_ray = true','move_and_collide(parameters, result, true, false)','result.travel.length() > margin','up_direction * up_direction.dot(result.travel)']:
            self.assertIn(token,snap)
    def test_candidate_application_and_guard_are_unchanged_except_binding_and_telemetry(self):
        def statements(path):
            text=path.read_text().split('var last_step_proposal:')[1]
            return [s for line in text.splitlines() if (s:=line.split('#')[0].strip()) and s!='response.observedSlides = Slides.capture(self)']
        self.assertEqual(statements(ROOT/'godot/tests/walker_step_up/candidate_walker.gd'),statements(ROOT/'godot/tests/walker_snap_parity/candidate.gd'))
        text=(ROOT/'godot/tests/walker_snap_parity/candidate.gd').read_text()
        self.assertIn('preload("res://tests/walker_step_up/response_guard.gd")',text)
if __name__=='__main__':unittest.main()

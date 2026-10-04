import ast,hashlib,json,math,re,struct,sys,unittest
from pathlib import Path
import xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'walker-step-up'))
from source_geometry import certified_patch,cross,swept_clearance,first_down_hit
from response_oracle import agrees
from phase import PHASE,GROUPS,validate
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
def rotated(v,yaw):return (f32(math.cos(yaw)*v[0]+math.sin(yaw)*v[2]),f32(v[1]),f32(-math.sin(yaw)*v[0]+math.cos(yaw)*v[2]))
def faces(yaw,incline=0):
    a,b,c,d=[rotated(p,yaw) for p in [(-2,.15,0),(-2,.15+3*math.tan(math.radians(incline)),3),(2,.15+3*math.tan(math.radians(incline)),3),(2,.15,0)]]
    return [(a,b,c),(a,c,d)]
class Admission(unittest.TestCase):
    def test_flat_world_baked_topology_and_whole_width_support_both_headings(self):
        for yaw in [math.pi/4,-math.pi/4]:
            poly=certified_patch(faces(yaw));self.assertIsNotNone(poly)
            for radius in [.35,.42]:
                for x in [-radius-.02,radius+.02]:
                    for z in [.0201,radius+.0601]:
                        p=rotated((x,.15,z),yaw);q=(p[0],p[2])
                        self.assertTrue(all(cross(poly[i],poly[(i+1)%len(poly)],q)>=0 for i in range(len(poly))))
    def test_finite_capsule_meets_edge_and_requires_lift_with_mirrored_rotation(self):
        for yaw in [math.pi/4,-math.pi/4]:
            for radius in [.35,.42]:
                # Analytic contact witness, not a runtime spawn/teleport. Native
                # driver starts at -1 and reaches its own contact pose by input.
                y=.0166673660278;effective=radius+.02
                z=-math.sqrt(effective**2-(y+radius-.15)**2)-.0001
                foot=rotated((0,y,z),yaw);motion=rotated((0,0,.1),yaw)
                top=faces(yaw);lift=.15-y+.0201
                self.assertLess(swept_clearance(foot,motion,top,radius),0)
                self.assertGreater(swept_clearance(foot,(0,lift,0),top,radius),0)
                raised=(foot[0],foot[1]+lift,foot[2])
                self.assertGreater(swept_clearance(raised,motion,top,radius),0)
                end=tuple(a+b for a,b in zip(raised,motion))
                self.assertIsNotNone(first_down_hit(end,lift+.0201,top,radius))
    def test_actual_steep_surface_not_transform_rejection_or_flat_mock(self):
        for yaw in [math.pi/4,-math.pi/4]:
            triangles=faces(yaw,47)
            self.assertIsNone(certified_patch(triangles))
            a,b,c=triangles[0];u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
            normal=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
            angle=math.degrees(math.acos(normal[1]/math.sqrt(sum(n*n for n in normal))))
            self.assertAlmostEqual(angle,47,places=4);self.assertGreater(angle,46)
            for radius in [.35,.42]:
                foot=rotated((0,.016667366,-.32-(radius-.35)*.6),yaw)
                self.assertLess(swept_clearance(foot,rotated((0,0,.1),yaw),triangles,radius),0)
    def test_rotated_response_cannot_pass_with_wrong_vector_or_support(self):
        for yaw in [math.pi/4,-math.pi/4]:
            motion=rotated((0,0,.1),yaw)
            self.assertTrue(agrees((0,.12,0),(0,.12,0),motion,motion,(42,0),(42,0)))
            self.assertFalse(agrees((0,.12,0),(0,.12,0),motion,(0,0,.1),(42,0),(42,0)))
            self.assertFalse(agrees((0,.12,0),(0,.12,0),motion,motion,(42,0),(42,1)))
    def test_official_index_api_and_both_future_telemetry_consumers(self):
        raw=(HERE/'KinematicCollision3D.xml').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),json.loads((HERE/'api-reference.json').read_text())['sha256'])
        tree=ET.fromstring(raw)
        for name,kind in [('get_collider_shape','Object'),('get_collider_shape_index','int')]:
            method=tree.find(f"./methods/method[@name='{name}']")
            self.assertEqual(method.find('return').get('type'),kind)
            self.assertEqual(method.find('param').get('default'),'0')
        for name in ['candidate_telemetry_v4.gd','driver_v4.gd']:
            self.assertIn('Slides.capture(', (ROOT/'godot/tests/walker_admission'/name).read_text())
    def test_phase_parity_and_all_map_groups_denied(self):
        gd=(ROOT/'godot/tests/walker_admission/fixtures_v4.gd').read_text()
        listed=json.loads(re.search(r'const GROUPS := (\[[^\n]+\])',gd)[1])
        self.assertEqual(list(GROUPS),listed)
        grant={'phase':PHASE,'allowedGroups':list(GROUPS)}
        for group in GROUPS:validate(grant,group)
        historical=json.loads((HERE.parent/'walker-step-up/acceptance-plan.json').read_text())
        for group in ['controls']+[g['id'] for g in historical['groups']]:
            with self.assertRaises(ValueError):validate({'phase':PHASE,'allowedGroups':[group]},group)
        for extra in [{'groups':list(GROUPS)},{'continueAfterKnownBaselineFailure':False},{'phase':'controls-reference-only-v3'},{'allowedGroups':[GROUPS[0],GROUPS[0]]}]:
            altered={**grant,**extra}
            with self.assertRaises(ValueError):validate(altered,GROUPS[0])
    def test_python_sources_compile_and_candidate_adapter_only_observes(self):
        for name in ['prepare.py','run_group.py','phase.py']:ast.parse((HERE/name).read_text())
        source=(ROOT/'godot/tests/walker_admission/candidate_telemetry_v4.gd').read_text()
        self.assertEqual(source.count('super.step('),1)
        for forbidden in ['move_and_slide(', 'move_and_collide(', 'velocity =','position =','candidate_fault =']:self.assertNotIn(forbidden,source)
if __name__=='__main__':unittest.main()

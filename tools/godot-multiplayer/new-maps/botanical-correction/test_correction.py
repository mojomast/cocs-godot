"""Actual-U counterexamples first; successor pure geometry, never native claims."""
import copy
import math
import unittest
from collections import Counter
from source_scene import ROOT,load,scene,k,RayIndex,authority_triangles
from geometry import glb_triangles,ray_distance,normal,center
from base_craft import base_craft_plan
from capsule import Capsules,segment_triangle
from archived_fixture import archive_bytes

class CorrectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old={m:load(m,r)['arena'] for m,r in [('parallax-observatory','districts-v3'),('vesper-viaduct','urban-v2')]}
        cls.new={m:load(m,r)['arena'] for m,r in [('parallax-observatory','districts-v4'),('vesper-viaduct','urban-v3')]}
        cls.scenes={m:scene(a) for m,a in cls.new.items()}

    def verify_frozen_actual_U_counterexamples(self):
        for m,rev,o,d,max_dist,expected in [
            ('parallax-observatory','districts-v3',[48,12.5,-31.9],[-1,0,0],4,0),
            ('vesper-viaduct','urban-v2',[-66.66666666666667,26.8,-57.675],[0,0,-1],.3,.1000015258789)]:
            rows=glb_triangles(archive_bytes(f'port/new-maps/{m}/variety/{rev}/{m}.glb'))
            actual=RayIndex([r['vertices'] for r in rows]).ray(o,d,max_dist)
            collision=RayIndex(authority_triangles(self.old[m])).ray(o,d,max_dist)
            self.assertAlmostEqual(actual,expected,places=5)
            if m.startswith('vesper'):self.assertGreater(abs(actual-collision),.049)
            else:self.assertEqual(collision,0)

    def test_finite_capsule_math_detects_faces_edges_caps(self):
        self.assertEqual(segment_triangle([0,0,-1],[0,0,1],[[-2,-2,0],[2,-2,0],[0,2,0]]),0)
        t=[[.3,1,-1],[.3,1,1],[.3,2,0]]
        self.assertIsNotNone(Capsules([t]).overlaps(0,0,0))
        self.assertIsNone(Capsules([t]).overlaps(-.2,0,0))
        ceiling=[[[-1,1.7,-1],[1,1.7,-1],[0,1.7,1]]]
        self.assertIsNotNone(Capsules(ceiling).overlaps(0,0,0))

    def test_complete_east_aperture_rays_and_capsules_both_directions(self):
        a=self.new['parallax-observatory'];rows,_,_=self.scenes[a['id']]
        source=RayIndex(authority_triangles(a));visual=RayIndex([r['vertices'] for r in rows])
        capsules=Capsules(authority_triangles(a));visual_capsules=Capsules([r['vertices'] for r in rows])
        # Entire six-metre opening, not the old +/-35% lateral samples. Centers
        # include both original side boundaries, with a full .42m body radius.
        for j in range(31):
            z=-37+j*.2
            for h in [.1,.5,1,1.5,1.8,2.1]:
                for x,d in [(48,-1),(44,1)]:
                    self.assertAlmostEqual(source.ray([x,12+h,z],[d,0,0],4),4)
                    self.assertAlmostEqual(visual.ray([x,12+h,z],[d,0,0],4),4)
            for i in list(range(21))+list(reversed(range(21))):
                x=44+i*.2
                # Full contact capsule, only 1mm numerical separation from floor.
                self.assertIsNone(capsules.overlaps(x,12.001,z),(x,z,'authority'))
                self.assertIsNone(visual_capsules.overlaps(x,12.001,z),(x,z,'complete visual'))
                self.assertAlmostEqual(source.ray([x,12.1,z],[0,-1,0],.2),.1,places=6)

    def test_vesper_complete_scene_ray_and_all_canonical_parapets(self):
        a=self.new['vesper-viaduct'];rows,craft,_=self.scenes[a['id']]
        source=RayIndex(authority_triangles(a));visual=RayIndex([r['vertices'] for r in rows])
        o=[-66.66666666666667,26.8,-57.675];d=[0,0,-1]
        self.assertAlmostEqual(source.ray(o,d,.3),.15)
        self.assertAlmostEqual(visual.ray(o,d,.3),.15)
        desc=a['art']['baseCraft']['canonicalSolids']['descriptors']
        self.assertEqual(len(desc),60);self.assertEqual(sum(d['replacement']['kind']=='kit' for d in desc),6)
        self.assertFalse(any(r['name']=='row-roof-parapet' for r in craft['lineage']))
        # Every retained legacy parapet is now a world-space shell with the same
        # render/collision faces, including inward/outward side, caps and ends.
        for d in desc:
            if d['replacement']['kind']!='authority':continue
            walls=[w['vertices'] for w in a['terrain']['walls'] if w.get('id','').startswith(d['id']+'-w')]
            caps=[s for s in a['terrain']['surfaces'] if s['id'].startswith(d['id']+'-')]
            self.assertEqual(len(walls),8);self.assertEqual(len(caps),2)
            for axis in range(3):
                for side in (0,1):
                    p=[(lo+hi)/2 for lo,hi in zip(d['min'],d['max'])];p[axis]=(d['min'] if side==0 else d['max'])[axis]
                    direction=[0,0,0];direction[axis]=1 if side==0 else -1
                    o=[v-.02*n for v,n in zip(p,direction)]
                    self.assertAlmostEqual(source.ray(o,direction,.04),visual.ray(o,direction,.04),places=6)

    def test_new_east_grade_finite_capsules_against_complete_source_scene(self):
        a=self.new['parallax-observatory'];rows,_,_=self.scenes[a['id']]
        source=Capsules(authority_triangles(a));visual=Capsules([r['vertices'] for r in rows])
        # A capsule rests on a sloped plane with lower hemisphere centre at
        # r/cos(slope) above centreline support, not r. This is geometric contact,
        # not an enlarged wall tolerance. 1mm separates contact numerically.
        lift=.42*(math.sqrt(1+(12/25.5)**2)-1)+.001
        for i in list(range(103))+list(reversed(range(103))):
            z=-37.5-i*.25;y=12+i*.25*12/25.5
            for x in [48,49.5,51]:
                self.assertIsNone(source.overlaps(x,y+lift,z),(x,y,z,'authority'))
                self.assertIsNone(visual.overlaps(x,y+lift,z),(x,y,z,'complete visual'))

    def test_entire_authority_wall_shell_no_offset_or_missing_triangle(self):
        # Covers all legacy AND new authority walls across both worlds, not only
        # the two regressions or new Kit components. RenderSource=kit is tested
        # through the complete captured Kit geometry above.
        key=lambda t:tuple(sorted(tuple(round(x,7) for x in v) for v in t))
        for m,a in self.new.items():
            rows,_,shell=self.scenes[m]
            expected=Counter(key(w['vertices']) for w in a['terrain']['walls'] if w.get('renderSource')!='kit')
            actual=Counter(key(r['vertices']) for r in rows if r['role']=='authority.wall')
            self.assertEqual(actual,expected)
            self.assertEqual(shell['nonTriangleWalls'],0)

    def test_compiled_floor_union_keeps_the_open_lightwell(self):
        rows,_,shell=self.scenes['parallax-observatory']
        self.assertIsNotNone(shell['floorUnion'])
        visual=RayIndex([r['vertices'] for r in rows])
        # A ray starting above court level must reach the actual descended
        # floor/ramp, not an old coplanar union slab left across the well.
        for x,y in [(32,8),(40,10),(43.5,11.75)]:
            self.assertAlmostEqual(visual.ray([x,12.2,-34.13],[0,-1,0],5),12.2-y,places=6)

    def test_craft_policy_is_opt_in_and_preserves_domes_dishes(self):
        old=base_craft_plan(self.old['parallax-observatory'],ROOT)
        new=self.scenes['parallax-observatory'][1]
        protected=lambda p:[r for r in p['lineage'] if any(s in r['name'] for s in ('dome','dish','oculus'))]
        self.assertTrue(protected(old));self.assertEqual(protected(old),protected(new))
        a=copy.deepcopy(self.new['vesper-viaduct'])
        a['art']['baseCraft']['canonicalSolids']['descriptors'][0]['min'][0]+=.05
        with self.assertRaisesRegex(ValueError,'canonical parapet'):base_craft_plan(a,ROOT)
        a=copy.deepcopy(self.new['vesper-viaduct'])
        missing=next(w for w in a['terrain']['walls'] if w.get('id','').startswith('canonical-row-parapet-'))
        a['terrain']['walls'].remove(missing)
        with self.assertRaisesRegex(ValueError,'canonical parapet shell'):base_craft_plan(a,ROOT)

if __name__=='__main__':unittest.main()

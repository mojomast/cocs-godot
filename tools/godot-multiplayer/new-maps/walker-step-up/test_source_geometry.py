import math
import json
import hashlib
import struct
import unittest
from source_geometry import *

class SourceFeasibility(unittest.TestCase):
    def test_actual_z_first_tread_needs_forward_lift_then_finite_down_support(self):
        foot=(32.,12.0166673660278,24.7000026702881);tread=rect(30,34,25,25.5,12.15)
        self.assertLess(swept_clearance(foot,(0,0,.1),tread),0)
        lift=12.15-foot[1]+.02+GUARD
        self.assertGreater(swept_clearance(foot,(0,lift,0),tread),0)
        raised=add(foot,(0,lift,0));self.assertGreater(swept_clearance(raised,(0,0,.1),tread),0)
        edge=add(raised,(0,0,.1));landing=first_down_hit(edge,lift+.02+GUARD,tread)
        self.assertIsNotNone(landing);self.assertGreater(landing[1],foot[1]);self.assertLess(landing[1]-foot[1],.25)
        self.assertLess(landing[2],25) # finite-cap edge support before centre crosses riser
        vertical=landing[1]+.35-12.15
        normal=(0,vertical/.37,(landing[2]-25)/.37)
        self.assertAlmostEqual(sum(v*v for v in normal),1.,places=7)
        self.assertTrue(floor_normal_valid(normal))
        self.assertTrue(support_patch(tread,(32,12.15,25)))

    def test_up_sweep_rejects_low_ceiling_even_when_forward_destination_is_clear(self):
        foot=(32,12.0166673660278,24.7000026702881);ceiling=rect(30,34,24,24.9,13.9)
        self.assertGreater(swept_clearance(foot,(0,0,0),ceiling),0)
        self.assertLess(swept_clearance(foot,(0,.153433,0),ceiling),0)

    def test_raised_forward_sweep_catches_overhang_missed_by_up_only_check(self):
        foot=(32,12.0166673660278,24.7000026702881);ceiling=rect(30,34,25.12,26,13.78)
        lift=12.15-foot[1]+.02+GUARD
        self.assertGreater(swept_clearance(foot,(0,lift,0),ceiling),0)
        self.assertLess(swept_clearance(add(foot,(0,lift,0)),(0,0,.1),ceiling),0)

    def test_tall_wall_and_strict_boundaries_are_surface_relative_not_foot_margin_relative(self):
        for rise in [.25,.25000001,.3,.31,1.]:self.assertFalse(strict_rise(12,12+rise))
        self.assertTrue(strict_rise(12,12.15));self.assertTrue(strict_rise(12,12+.249))
        # Margin-raised feet would incorrectly make a .25 wall look like .2333.
        self.assertTrue(strict_rise(12.0166673660278,12.25))
        self.assertFalse(strict_rise(12,12.25))

    def test_full_capsule_path_rejects_tall_solid_vertical_wall(self):
        foot=(32,12.0166673660278,24.7000026702881)
        wall=[((30,12,25),(34,12,25),(34,15,25)),((30,12,25),(34,15,25),(30,15,25))]
        self.assertLess(swept_clearance(add(foot,(0,.25,0)),(0,0,.1),wall),0)

    def test_pit_has_no_down_support_and_narrow_shelf_has_no_continuous_patch(self):
        edge=(32,12.1701,24.8)
        self.assertIsNone(first_down_hit(edge,.1736,rect(30,34,25,25.5,10)))
        self.assertFalse(support_patch(rect(31.9,32.1,25,25.5,12.15),(32,12.15,25)))
        self.assertFalse(support_patch(rect(30,34,25,25.15,12.15),(32,12.15,25)))

    def test_two_overlapping_triangles_with_equal_total_area_do_not_certify_a_hole(self):
        a,b,c,d=(30,12.15,25),(34,12.15,25),(34,12.15,25.5),(30,12.15,25.5)
        self.assertIsNone(certified_patch([(a,b,c),(a,b,d)])) # shared outside edge, overlap + hole
        self.assertIsNotNone(certified_patch([(a,b,c),(a,c,d)]))

    def test_support_certificate_does_not_weld_a_sub_guard_slit_or_ignore_an_internal_hole(self):
        slit=rect(30,31.999999,25,25.5,12.15)+rect(32.000001,34,25,25.5,12.15)
        self.assertIsNone(certified_patch(slit))
        ring=rect(30,34,25,25.15,12.15)+rect(30,34,25.25,25.5,12.15)+rect(30,31.9,25.15,25.25,12.15)+rect(32.1,34,25.15,25.25,12.15)
        self.assertIsNone(certified_patch(ring))

    def test_steep_floor_lateral_corner_and_no_intent_fail_closed(self):
        self.assertTrue(floor_normal_valid((0,1,0)))
        self.assertFalse(floor_normal_valid((0,math.cos(math.radians(47)),0)))
        for kwargs in [{'input_length':0},{'grounded':False},{'vy':-1},{'vy':1},{'jump':True},
                       {'moving':True},{'approach_cosine':math.cos(math.pi/4)},{'attempts':1}]:
            self.assertFalse(eligibility(**kwargs),kwargs)

    def test_both_radii_require_full_width_and_depth_on_real_tread(self):
        for radius in [.35,.42]:
            for x in [30.5,31.25,32,32.75,33.5]:
                self.assertTrue(support_patch(rect(30,34,25,25.5,12.15),(x,12.15,25),radius))
            self.assertFalse(support_patch(rect(30,34,25,25.5,12.15),(30.1,12.15,25),radius))

    def test_point42_capsule_has_an_independent_analytic_pose_not_reused_native_point35_pose(self):
        radius=.42;effective=radius+.02;y=12.0166673660278
        standoff=math.sqrt(effective**2-(y+radius-12.15)**2)+GUARD
        foot=(32,y,25-standoff);tread=rect(30,34,25,25.5,12.15)
        self.assertLess(swept_clearance(foot,(0,0,.1),tread,radius=radius),0)
        lift=12.15-y+.02+GUARD
        self.assertGreater(swept_clearance(foot,(0,lift,0),tread,radius=radius),0)
        raised=add(foot,(0,lift,0))
        self.assertGreater(swept_clearance(raised,(0,0,.1),tread,radius=radius),0)
        self.assertIsNotNone(first_down_hit(add(raised,(0,0,.1)),lift+.02+GUARD,tread,radius=radius))

    def test_no_edge_ladder_on_stacked_tiny_shelves(self):
        for index in range(1,8):
            y=12+.15*index
            self.assertFalse(support_patch(rect(30,34,25,25.08,y),(32,y,25)))

    def test_actual_candidate_all_94_tread_faces_fit_five_lane_support_certificates(self):
        path=HERE.parents[3]/'port/new-maps/vesper-viaduct/variety/urban-v3/authority.json'
        raw=path.read_bytes();self.assertEqual(hashlib.sha256(raw).hexdigest(),'397cedc8f5583a229bb3f65ed94d9a8c74c30fd4132b57bd4e754299a47c67ec')
        surfaces=json.loads(raw)['arena']['terrain']['surfaces'];counts={}
        for prefix,lanes in [('civic-stair-', [30.5,31.25,32,32.75,33.5]),('roof-ramp-step-',[16.5,17.25,18,18.75,19.5])]:
            selected=[s for s in surfaces if s['id'].startswith(prefix)];counts[prefix]=len(selected)
            for surface in selected:
                # The actual standard Godot Vector3/ConcavePolygonShape stores
                # float32. This is explicit conversion, not epsilon welding.
                f32=lambda v:struct.unpack('<f',struct.pack('<f',v))[0]
                triangles=[tuple(tuple(f32(v) for v in surface['vertices'][i]) for i in face) for face in surface['triangles']]
                y=triangles[0][0][1];z=min(p[2] for t in triangles for p in t)
                for radius in [.35,.42]:
                    for x in lanes:self.assertTrue(support_patch(triangles,(x,y,z),radius), (surface['id'],radius,x))
        self.assertEqual(counts,{'civic-stair-':80,'roof-ramp-step-':14})

if __name__=='__main__':unittest.main()

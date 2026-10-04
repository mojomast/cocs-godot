"""Continuous finite capsule/AABB certificate. Source geometry, not Godot.

The capsule's axial segment is foot+[r,1.8-r] Y, equivalent to the
actual .9 shape offset and total height1.8 (hemispheres included).
Squared segment/AABB distance is separable. Each axial interval distance
is piecewise affine during translation; squared distance is piecewise
quadratic. Enumerate its breakpoints and stationary points, not time samples.
"""
import math
import re
import unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
MARGIN=.02
ROUND=.0001

def box_from_fixture():
    source=(ROOT/'godot/tests/walker_step_up/controls_v2.gd').read_text()
    match=re.search(r'if id=="overhang-forward": box\(world,Vector3\(([^)]+)\),Vector3\(([^)]+)\),"ForwardOverhang"\)',source)
    center=[float(v) for v in match[1].split(',')]
    size=[float(v) for v in match[2].split(',')]
    return tuple(c-s/2 for c,s in zip(center,size)),tuple(c+s/2 for c,s in zip(center,size))

def segment_box_sweep_distance(foot,motion,radius,box):
    lo,hi=box
    seglo=(foot[0],foot[1]+radius,foot[2])
    seghi=(foot[0],foot[1]+1.8-radius,foot[2])
    breaks={0.,1.}
    for i,v in enumerate(motion):
        if v:
            for boundary in [(lo[i]-seghi[i])/v,(hi[i]-seglo[i])/v]:
                if 0<boundary<1:breaks.add(boundary)
    def squared(t):
        return sum(max(lo[i]-seghi[i]-motion[i]*t,0.,seglo[i]+motion[i]*t-hi[i])**2 for i in range(3))
    ordered=sorted(breaks)
    candidates=list(ordered)
    for a,b in zip(ordered,ordered[1:]):
        mid=(a+b)/2;aa=bb=0.
        for i,v in enumerate(motion):
            if seghi[i]+v*mid<lo[i]:c,d=lo[i]-seghi[i],-v
            elif seglo[i]+v*mid>hi[i]:c,d=seglo[i]-hi[i],v
            else:c=d=0.
            aa+=d*d;bb+=c*d
        if aa:candidates.append(max(a,min(b,-bb/aa)))
    return math.sqrt(min(squared(t) for t in candidates))

def clearance(foot,motion,radius,box):
    return segment_box_sweep_distance(foot,motion,radius,box)-radius-MARGIN

def robustness_bounds(radius,box):
    # Source admission envelope, not observed native statistics:
    # settled foot Y [0,.0201], lateral |X|<=.0001, start Z nominal ±.0001;
    # raised Y [.1700,.1902] covers GUARD=.0001, rounding ±.0001 and
    # permitted extra upward recovery [0,.0201]. Forward travel .1±.0001.
    # Whole UP remains inside X/Z intervals, Y[0,.1902]. The closest possible
    # upper axial endpoint is at maximum Y and maximum Z; both gaps stay
    # positive. This corner distance bounds every intermediate up position.
    front=box[0][2];z=-.32-(radius-.35)*.6
    up_lower=math.hypot(front-(z+ROUND),box[0][1]-(.1902+1.8-radius))-radius-MARGIN
    # At forward endpoint, all feet remain before the front and all upper
    # axial endpoints below lower box face. Distance maximized at smallest
    # endpoint Z and smallest raised Y. Segment is inside the finite box X
    # range. Thus this bound proves intersection for the entire uncertainty
    # set; endpoint intersection implies continuous forward sweep collision.
    far_z=z-ROUND+.1-ROUND
    low_raised=.1700
    y_gap=box[0][1]-(low_raised+1.8-radius)
    forward_upper=math.hypot(front-far_z,y_gap)-radius-MARGIN
    return up_lower,forward_upper

class OverhangCertificate(unittest.TestCase):
    def test_actual_fixture_dimensions_and_reason(self):
        lo,hi=box_from_fixture()
        self.assertAlmostEqual(lo[2],.08);self.assertAlmostEqual(lo[1],1.78)
        self.assertEqual((lo[0],hi[0]),(-2.,2.))
        text=(ROOT/'godot/tests/walker_step_up/controls_v2.gd').read_text()
        self.assertIn('"overhang-forward": reasons = ["raised_path_blocked"]',text)

    def test_continuous_sweeps_for_both_capsules_and_envelope_extremes(self):
        box=box_from_fixture()
        for radius in [.35,.42]:
            z=-.32-(radius-.35)*.6
            for foot_y in [0.,.0166673660278,.0201]:
                for dz in [-ROUND,ROUND]:
                    for recovery in [0.,.0201]:
                        for rounding in [-ROUND,ROUND]:
                            foot=(ROUND,foot_y,z+dz)
                            raised=.1701+recovery+rounding
                            self.assertGreater(clearance(foot,(0,0,0),radius,box),.02)
                            self.assertGreater(clearance(foot,(0,raised-foot_y,0),radius,box),.02)
                            self.assertLess(clearance((ROUND,raised,z+dz),(0,0,.1-ROUND),radius,box),-.025)

    def test_interval_certificate_covers_between_extremes_not_only_samples(self):
        for radius in [.35,.42]:
            up_lower,forward_upper=robustness_bounds(radius,box_from_fixture())
            self.assertGreater(up_lower,.021)
            self.assertLess(forward_upper,-.025)

    def test_old_box_reproduces_reviewer_clearance_counterexample(self):
        old=((-2.,1.78,.12),(2.,1.88,1.))
        for radius,expected in [(.35,.0057231495),(.42,.00584527585)]:
            z=-.32-(radius-.35)*.6
            value=clearance((0,.1701,z),(0,0,.1),radius,old)
            self.assertGreater(value,.005)
            self.assertAlmostEqual(value,expected,places=6)

    def test_finite_box_kernel_checks_side_and_end_edges_not_infinite_plane(self):
        box=((0,0,0),(1,1,1))
        # Capsule axial segment overlaps box Y; closest approach is the
        # finite X/Z corner, at a stationary time interior to this translation.
        self.assertAlmostEqual(segment_box_sweep_distance((-1,0,-1),(2,0,-1),.35,box),math.sqrt(1.8))
        self.assertGreater(clearance((3,0,0),(0,0,1),.35,box),1.)

if __name__=='__main__':unittest.main()

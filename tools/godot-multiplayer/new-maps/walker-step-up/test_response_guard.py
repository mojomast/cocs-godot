import math
import unittest
from response_oracle import agrees,budget
from source_geometry import support_patch
class ResponseGuard(unittest.TestCase):
    def test_review_counterexample_cannot_pass_on_progress_length_and_grounded_alone(self):
        self.assertFalse(agrees((0,.12,.10),(.04,.10,.08),(0,0,.10),(0,0,.10),(123,0),(123,0)))
    def test_small_float32_rounding_allowed_but_margin_sized_error_never_is(self):
        expected=(32,12.15,25.1);ulp=2**-18
        self.assertTrue(agrees(expected,(32+ulp,12.15,25.1),(0,0,.1),(0,0,.1),(123,0),(123,0)))
        self.assertFalse(agrees(expected,(32+.001,12.15,25.1),(0,0,.1),(0,0,.1),(123,0),(123,0)))
        self.assertIsNone(budget((1024,0,0)))
    def test_identity_and_unobserved_collision_path_are_not_inferred_from_equal_height(self):
        for support,slides in [((124,0),0),((123,1),0),((123,0),1)]:
            self.assertFalse(agrees((32,.12,25),(32,.12,25),(0,0,.1),(0,0,.1),(123,0),support,slides))
    def test_rotated_heading_requires_vector_agreement_not_equal_length(self):
        h=.1/math.sqrt(2)
        self.assertFalse(agrees((32,.12,25),(32,.12,25),(h,0,h),(-h,0,h),(123,0),(123,0)))
    def test_triangle_and_pentagon_check_every_hull_edge(self):
        tri=[((0,0,0),(3,0,0),(0,0,3))]
        self.assertTrue(support_patch(tri,(.5,0,.4)))
        self.assertFalse(support_patch(tri,(2.5,0,.4)))
        v=[(0,0,0),(2,0,0),(2,0,2),(1,0,3),(0,0,2)]
        pent=[(v[0],v[i],v[i+1]) for i in range(1,4)]
        self.assertTrue(support_patch(pent,(1,0,.4)))
        self.assertFalse(support_patch(pent,(.1,0,.4))) # omitted fifth edge previously admitted negative X
if __name__=='__main__':unittest.main()

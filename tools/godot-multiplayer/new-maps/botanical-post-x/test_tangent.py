import json
import unittest
from fixture_inputs import HERE
from uv_basis import basis,solve,cross,dot
class Tangents(unittest.TestCase):
    def test_actual_exported_uv_derivative_not_neighbor_hand_guess(self):
        p=json.loads((HERE/'parallax-tangent-evidence-v2.json').read_text())
        for corner,n in enumerate(p['normals']):
            b=basis(p['positions'],p['uv'],n,corner)
            self.assertAlmostEqual(b['area'],.0905817259,places=9)
            self.assertAlmostEqual(b['uvJacobian'],-.0452908629,places=9)
            self.assertEqual(b['dPdu'],(2.,0.,0.));self.assertEqual(b['dPdv'],(0.,0.,2.))
            self.assertEqual(solve([b]),(1.,0.,0.,-1.))
            self.assertLess(dot(cross(n,(1,0,0)),b['dPdv']),0)
    def test_uv_flip_changes_derived_hand_not_normal_or_tangent_direction(self):
        p=json.loads((HERE/'parallax-tangent-evidence-v2.json').read_text())
        uv=[(u,-v) for u,v in p['uv']]
        self.assertEqual(solve([basis(p['positions'],uv,p['normals'][0],0)]),(1.,0.,0.,1.))
    def test_degenerate_and_conflicting_incidents_fail_closed(self):
        p=json.loads((HERE/'parallax-tangent-evidence-v2.json').read_text())
        with self.assertRaises(ValueError):basis(p['positions'],[(0,0)]*3,p['normals'][0],0)
        a=basis(p['positions'],p['uv'],p['normals'][0],0)
        b=basis(p['positions'],[(u,-v) for u,v in p['uv']],p['normals'][0],0)
        with self.assertRaises(ValueError):solve([a,b])
if __name__=='__main__':unittest.main()

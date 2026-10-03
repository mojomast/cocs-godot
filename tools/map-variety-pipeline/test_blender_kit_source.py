"""Geometry contract checks without importing or launching Blender."""
import importlib.util
import math
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location('map_variety_kit', Path(__file__).with_name('blender_kit.py'))
kit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kit)


class RecordingKit(kit.Kit):
    def mesh(self, name, vertices, faces, material, **kwargs):
        self.parts.append((name, vertices, faces, material, kwargs))
        return name


class SourceKitTests(unittest.TestCase):
    def setUp(self):
        self.kit = RecordingKit(object(), object(), {'frame': object(), 'trim': object()},
                                {'frame': 1.2, 'trim': 2.4})
        self.kit.parts = []

    def test_vault_is_solid_curved_editable_part(self):
        self.kit.curved_rib('vault', (0, 0, 2), 2, 2.2, .3, 0, math.pi, 'frame', segments=20)
        name, vertices, faces, material, _ = self.kit.parts[0]
        self.assertEqual(name, 'vault')
        self.assertEqual(material, 'frame')
        self.assertEqual(len(vertices), 84)
        self.assertEqual(len(faces), 82)
        self.assertGreater(max(v[2] for v in vertices), 4.1)
        self.assertEqual(len({tuple(round(n, 3) for n in v) for v in vertices}), 84)

    def intersects_portal(self, x, z):
        """Horizontal view ray at fixed X/Z against real face triangles."""
        origin, direction = (x, -2, z), (0, 1, 0)
        def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
        def dot(a,b): return sum(n*m for n,m in zip(a,b))
        def sub(a,b): return tuple(n-m for n,m in zip(a,b))
        for _, vertices, faces, _, _ in self.kit.parts:
            for face in faces:
                for i in range(1,len(face)-1):
                    a,b,c=(vertices[j] for j in (face[0],face[i],face[i+1]))
                    edge1,edge2=sub(b,a),sub(c,a)
                    p=cross(direction,edge2)
                    determinant=dot(edge1,p)
                    if abs(determinant)<1e-9: continue
                    inverse=1/determinant
                    t=sub(origin,a)
                    u=dot(t,p)*inverse
                    q=cross(t,edge1)
                    v=dot(direction,q)*inverse
                    distance=dot(edge2,q)*inverse
                    if u>=-1e-8 and v>=-1e-8 and u+v<=1+1e-8 and 0<distance<4:
                        return True
        return False

    def test_arch_and_flat_portals_have_real_clear_aperture(self):
        for arch in (True,False):
            with self.subTest(arch=arch):
                self.kit.parts.clear()
                self.kit.framed_bay('archive', (0, 0, 0), 4, 5, .45,
                                    frame='frame', trim='trim', sector='library', arch=arch)
                self.assertFalse(self.intersects_portal(0, 2.5))
                self.assertFalse(self.intersects_portal(1.65, 2.5))
                self.assertTrue(self.intersects_portal(1.95, 2.5))
                self.assertTrue(self.intersects_portal(0, 4.94))
                self.assertTrue(all(part[4]['sector'] == 'library' for part in self.kit.parts))
        self.assertEqual(kit._phase('archive'), kit._phase('archive'))
        self.assertNotEqual(kit._phase('archive'), kit._phase('observatory'))

    def test_manifold_rings_stay_non_degenerate_at_ninety_degree_turn(self):
        path = [(0,0,0),(2,0,0),(2,0,2),(2,2,2)]
        rings = kit._pipe_rings(path, .2, 12)
        self.assertEqual(len(rings), len(path))
        for point,ring in zip(path,rings):
            self.assertEqual(len(set(ring)), 12)
            for vertex in ring:
                self.assertAlmostEqual(math.dist(vertex,point), .2, places=6)
        with self.assertRaisesRegex(ValueError,'U-turn'):
            kit._pipe_rings([(0,0,0),(2,0,0),(.1,0,0)], .2, 12)
        with self.assertRaisesRegex(ValueError,'Coincident'):
            kit._pipe_rings([(0,0,0),(0,0,0)], .2, 12)


if __name__ == '__main__':
    unittest.main()

import copy
import unittest
from proposal import *

class Diagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=(NATIVE/'candidate.glb').read_bytes();cls.g=EmbeddedGlb(cls.raw)
        cls.sg,cls.inventory,cls.faces=source_faces(cls.g)
        cls.report=json.loads((NATIVE/'evidence/native-import.json').read_text())
        cls.ng,_=native_faces(cls.report,(NATIVE/'evidence/native-streams.bin').read_bytes())

    def test_all_faces_node_scoped_and_duplicate_multiplicity(self):
        result=compare(self.sg,self.ng);c=result['counts']
        self.assertEqual((c['matchedGeometryFaces'],c['strictEquivalentFaces']),(155553,155521))
        self.assertEqual((c['mismatchedFaces'],c['mismatchedCorners'],c['w']),(32,48,48))
        self.assertEqual((c['ambiguousBasisGroups'],c['missingGeometryGroups']),(0,0))
        self.assertEqual(c['duplicateGroups'],228)
        for f in result['mismatches']:
            self.assertFalse(f['sourceDerivative']['defined']);self.assertGreater(f['sourceDerivative']['area'],0)
            for c in f['corners']:
                self.assertEqual(c['flags'],['w']);self.assertEqual(c['sourceBinormalLength'],0)
                self.assertIsNone(c['binormalAngleDegrees'])

    def test_corrected_first_failure_one_corner_not_two(self):
        a=next(f for f in self.faces if f['node']=='wayfinding-2' and f['face']==965)
        b=next(f for rows in self.ng.values() for f in rows if f['node']=='wayfinding-2' and f['face']==963)
        self.assertEqual(key(a['corners']),key(b['corners']))
        self.assertEqual([c['T'][3] for c in a['corners']],[-1,-1,-1])
        self.assertEqual([c['T'][3] for c in b['corners']],[1,-1,-1])
        self.assertFalse(strict(a['corners'],b['corners']))
        for ca,cb in zip(a['corners'],b['corners']):self.assertEqual(simulate_surface_sign(ca['N'],ca['T']),cb['T'][3])

    def test_multiset_requires_counts_not_closest_handedness(self):
        self.assertEqual(len(maximum_matching([-1,-1],[-1,1],lambda a,b:a==b)),1)
        self.assertEqual(len(maximum_matching([-1,1],[1,-1],lambda a,b:a==b)),2)
        f=copy.deepcopy(self.faces[0]['corners']);wrong=copy.deepcopy(f);wrong[0]['T']=(*wrong[0]['T'][:3],-wrong[0]['T'][3])
        self.assertFalse(strict(f,wrong))

    def test_proposal_all_incidents_and_bin_boundary(self):
        imagined,report=propose(self.raw);g=EmbeddedGlb(imagined)
        self.assertEqual(len(report['records']),16);self.assertEqual(report['permittedBINPositions'],256)
        self.assertEqual(report['changedBINBytes'],64)
        self.assertEqual(g.doc,self.g.doc)
        allowed={i for r in report['records'] for i in range(r['binOffset'],r['binOffset']+16)}
        self.assertTrue(all(a==b for i,(a,b) in enumerate(zip(g.binary,self.g.binary)) if i not in allowed))
        for r in report['records']:
            self.assertEqual(len(r['incidents']),3);self.assertEqual(r['proposed'][3],-1)
            self.assertEqual(dot(r['N'],r['proposed'][:3]),0)
            self.assertEqual(simulate_surface_sign(r['N'],r['proposed']),-1)

    def test_no_forged_pass_for_old_native_or_sign_only_fix(self):
        imagined,_=propose(self.raw);sg,_,_=source_faces(EmbeddedGlb(imagined));result=compare(sg,self.ng)
        self.assertEqual(result['counts']['strictEquivalentFaces'],155521)
        self.assertEqual(result['counts']['Tdirection'],48)
        self.assertEqual(result['counts']['w'],48)
        # Merely changing old w to +1 cannot turn a parallel frame into a basis.
        self.assertEqual(norm(cross((-1,0,0),(1,0,0))),0)

    def test_rank_one_policy_rejects_full_rank_or_conflicting_normals(self):
        full=[{'P':p,'UV':uv,'N':(0,0,1),'T':(1,0,0,1)} for p,uv in zip(((0,0,0),(1,0,0),(0,1,0)),((0,0),(1,0),(0,1)))]
        with self.assertRaisesRegex(ValueError,'Not rank-one'):rank_one_basis(full,0)
        f=next(f for f in self.faces if f['node']=='wayfinding-2' and f['face']==965)
        cs=copy.deepcopy(f['corners']);ci=next(i for i,c in enumerate(cs) if c['vertex']==1026)
        valid=rank_one_basis(cs,ci);self.assertEqual(valid,(0.,1.,0.,-1.))
        cs[ci]['N']=(0,1,0)
        with self.assertRaisesRegex(ValueError,'Conflicting extrusion'):rank_one_basis(cs,ci)

if __name__=='__main__':unittest.main()

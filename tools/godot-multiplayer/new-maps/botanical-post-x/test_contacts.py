import json
import unittest
from fixture_inputs import HERE,source
from diagnose_contacts import check,colliders

class Contacts(unittest.TestCase):
    def test_all_184_original_failures_have_exact_source_geometry(self):
        fixture=json.loads((HERE/'contacts-evidence.json').read_text());maps={v:colliders(source(v)['arena']) for v in ['accepted','candidate']}
        self.assertEqual(len(fixture['records']),368);self.assertEqual(len(fixture['candidateOnlyContactPositions']),13)
        for r in fixture['records']:
            for c in r['contacts']:
                self.assertEqual(c['triangles'],maps[r['variant']][c['nativeCollider']]['triangles'])
                self.assertEqual(check(r['foot'],c['triangles']),c['originalCapsule'])
                self.assertTrue(c['originalCapsule']['overlaps'])
                self.assertTrue(c['gameEnvelopeCapsule']['overlaps'])
    def test_exact_nav490_tread_counterexample_and_flat_landing(self):
        t=colliders(source('candidate')['arena'])['civic-stair-12Collider']['triangles']
        p=[32,13.8,30.90909090909091]
        self.assertTrue(check(p,t)['overlaps']);self.assertTrue(check(p,t,.42,1.8)['overlaps'])
        # A real flat landing one tread deep has no impending tread overlap.
        self.assertFalse(check([32,13.95,31.25],t,.42,1.8)['overlaps'])
    def test_thirteen_extras_and_one_different_accepted_roof_contact(self):
        f=json.loads((HERE/'contacts-evidence.json').read_text())
        accepted={r['id']:r for r in f['records'] if r['variant']=='accepted'}
        roof=[r for r in f['records'] if r['variant']=='candidate' and 'roof-access-ramp' in r['id']]
        self.assertEqual(len(roof),14)
        both=[r for r in roof if accepted[r['id']]['contacts']]
        self.assertEqual([r['id'] for r in both],['candidate-route:roof-access-ramp:2:35'])
        self.assertEqual({c['nativeCollider'] for c in accepted[both[0]['id']]['contacts']},{'OverheadSide2104','OverheadSide2105'})

if __name__=='__main__':unittest.main()

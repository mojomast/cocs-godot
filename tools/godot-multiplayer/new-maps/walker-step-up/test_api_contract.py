"""Static API/document checks only; these do NOT parse or execute GDScript."""
import hashlib
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent
class ApiContract(unittest.TestCase):
    def test_recorded_official_api_snapshots_are_exact(self):
        index=json.loads((HERE/'references/index.json').read_text())
        for name,record in index['files'].items():
            raw=(HERE/'references'/name).read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(),record['sha256'])
    def test_query_signature_and_live_shape_owner_return_type(self):
        server=ET.parse(HERE/'references/PhysicsServer3D.xml')
        method=server.find("./methods/method[@name='body_test_motion']")
        self.assertEqual(method.find('return').get('type'),'bool')
        self.assertEqual([p.get('type') for p in method.findall('param')],['RID','PhysicsTestMotionParameters3D','PhysicsTestMotionResult3D'])
        owners=ET.parse(HERE/'references/CollisionObject3D.xml').find("./methods/method[@name='get_shape_owners']/return")
        self.assertEqual(owners.get('type'),'PackedInt32Array')
    def test_policy_has_distinct_reference_and_candidate_profiles(self):
        plan=json.loads((HERE/'acceptance-plan.json').read_text())
        self.assertFalse(plan['productionPromotion']);self.assertIsNone(plan['nativeGrant'])
        self.assertEqual(plan['totalWalkTrials'],70)
        self.assertEqual(len(plan['groups']),7)
        self.assertTrue(plan['groups'][0]['referenceOnly'])
        self.assertEqual(sum(g.get('requiredPassed',0) for g in plan['groups']),60)
        for group in plan['groups']:
            self.assertEqual(len(group['trials']),10)
            self.assertEqual(group['timeoutSeconds'],180)
if __name__=='__main__':unittest.main()

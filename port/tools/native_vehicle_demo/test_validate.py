import copy
import json
import pathlib
import unittest
from validate_driving import verify

EVIDENCE=pathlib.Path(__file__).resolve().parents[2]/'native-puma-driving/evidence/edbe276a-8da2-4050-86f0-dda4905a0747'

class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.text=(EVIDENCE/'ion-speedway.log').read_text()
        self.wire=json.loads((EVIDENCE/'ion-speedway-wire.json').read_text())
    def test_genuine_replay(self):
        self.assertEqual(verify('ion-speedway',self.text,self.wire)['status'],'PASS')
    def test_missing_receipts_rejected(self):
        self.wire['inputs']=[]
        with self.assertRaises(AssertionError): verify('ion-speedway',self.text,self.wire)
    def test_mismatched_server_positions_rejected(self):
        for row in self.wire['samples']: row['vehicle']['x']+=100
        with self.assertRaises(AssertionError): verify('ion-speedway',self.text,self.wire)
    def test_mismatched_actor_rejected(self):
        for row in self.wire['samples']: row['actor']=999
        with self.assertRaises(AssertionError): verify('ion-speedway',self.text,self.wire)
    def test_cleanup_failure_rejected(self):
        self.wire['cleanup']['serverClosed']=False
        with self.assertRaises(AssertionError): verify('ion-speedway',self.text,self.wire)
    def test_non_neutral_release_rejected(self):
        for row in self.wire['inputs']: row['input']['x']=1
        with self.assertRaises(AssertionError): verify('ion-speedway',self.text,self.wire)
    def test_duplicate_sequence_rejected(self):
        self.wire['inputs'].append(copy.deepcopy(self.wire['inputs'][-1]))
        with self.assertRaises(AssertionError): verify('ion-speedway',self.text,self.wire)

if __name__=='__main__': unittest.main()

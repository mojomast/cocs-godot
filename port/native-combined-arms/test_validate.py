"""Negative replay tests mutate copies of retained live evidence, never a server."""
import copy, json, os, pathlib, unittest
from validate import verify
class Replay(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        selected=os.environ.get('COMBINED_EVIDENCE')
        if selected: root=pathlib.Path(selected)
        else:
            roots=[p.parent for p in pathlib.Path(__file__).with_name('evidence').glob('*/summary.json') if json.loads(p.read_text()).get('status')=='PASS']
            if not roots: raise RuntimeError('Run live acceptance first or set COMBINED_EVIDENCE')
            root=max(roots,key=lambda p:p.stat().st_mtime)
        cls.text=(root/'native.log').read_text()
        cls.wire=json.loads((root/'wire.json').read_text())
    def test_live_replay(self): verify(self.text,self.wire)
    def reject(self, wire, text=None):
        with self.assertRaises(AssertionError): verify(self.text if text is None else text,wire)
    def test_missing_receipts(self):
        w=copy.deepcopy(self.wire); w['inputs']=[]; self.reject(w)
    def test_changed_vehicle_source_y(self):
        w=copy.deepcopy(self.wire)
        for s in w['samples']:
            for v in s['vehicles']: v['y']+=1
        self.reject(w)
    def test_changed_source_actor(self):
        w=copy.deepcopy(self.wire)
        for s in w['samples']: s['actor']['id']=1
        self.reject(w)
    def test_duplicate_receipt(self):
        w=copy.deepcopy(self.wire); w['inputs'].append(w['inputs'][0]); self.reject(w)
    def test_no_completion(self):
        self.reject(self.wire,'\n'.join(l for l in self.text.splitlines() if not l.startswith('CA_COMPLETE ')))
    def test_cleanup_failure(self):
        w=copy.deepcopy(self.wire); w['cleanup']['sockets']=1; self.reject(w)
    def test_interact_never_ACKed(self):
        w=copy.deepcopy(self.wire)
        for s in w['samples']: s['ack']=0
        self.reject(w)
if __name__=='__main__': unittest.main()

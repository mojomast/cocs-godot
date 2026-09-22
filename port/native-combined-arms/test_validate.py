"""Negative replay tests mutate copies of retained live evidence, never a server."""
import copy, json, os, pathlib, unittest
from validate import verify
class Replay(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        selected=os.environ.get('COMBINED_EVIDENCE')
        if selected: root=pathlib.Path(selected)
        else:
            # Pin genuine driving evidence: filesystem mtimes after a fresh
            # checkout can otherwise select the unrelated launcher-only PASS.
            root=pathlib.Path(__file__).with_name('evidence')/'9216ae2e-c5ad-4c37-8e04-772855d11fba'
        if json.loads((root/'summary.json').read_text()).get('status')!='PASS':
            raise RuntimeError('Replay requires successful retained driving evidence')
        cls.text=(root/'native.log').read_text()
        cls.wire=json.loads((root/'wire.json').read_text())
    def test_live_replay(self): verify(self.text,self.wire)
    def reject(self, wire, text=None):
        with self.assertRaises(AssertionError): verify(self.text if text is None else text,wire)
    def test_missing_receipts(self):
        w=copy.deepcopy(self.wire); w['inputs']=[]; self.reject(w)
    def test_one_missing_driving_receipt(self):
        w=copy.deepcopy(self.wire)
        # Preserve mount/exit/brake witnesses: losing an ordinary drive packet
        # must still invalidate a claim of complete queue/receipt correlation.
        q=next(json.loads(line[len('CA_QUEUE '):]) for line in self.text.splitlines()
               if line.startswith('CA_QUEUE ') and json.loads(line[len('CA_QUEUE '):])['stage']=='drive')
        w['inputs']=[i for i in w['inputs'] if i['seq']!=q['seq']]
        self.reject(w)
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

"""Source/finite-domain checks only. No native parser, stage or child."""
import hashlib,importlib.util,json,math,sys,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
AI=ROOT.parent/'cocs-walker-parity-admission-ai'
AJ=ROOT.parent/'cocs-walker-policy-receipt-probe-aj'
AI_STAGE=AI/'godot/tests/walker_parity_admission/parity-admission-ai-01'
AJ_STAGE=AJ/'godot/tests/walker_policy_receipt_probe/policy-receipt-probe-aj-01'
OLD=b'not up in [0,1]';NEW=b'(up != 0 and up != 1)'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
class CorrectionTests(unittest.TestCase):
    def test_one_clause_only_and_exact_native_probe_clone_bytes(self):
        before=(AI_STAGE/'tests/walker_parity_admission/evidence.gd').read_bytes()
        after=(ROOT/'godot/tests/walker_parity_admission/evidence.gd').read_bytes()
        self.assertEqual(before.count(OLD),1);self.assertEqual(after.count(OLD),0)
        self.assertEqual(before.replace(OLD,NEW),after)
        self.assertEqual(after,(AJ_STAGE/'probe/cloned_evidence.gd').read_bytes())
        self.assertIn(b'not integer(up) or '+NEW,after)
        self.assertIn(b'return num(v) and v==floor(v)',after)
        self.assertIn(b'return (v is int or v is float) and is_finite(float(v))',after)
    def test_finite_numeric_domain_and_invalid_types(self):
        # Reference contract, not GDScript execution. Godot observations are AJ only.
        def domain(v):return type(v) in (int,float) and math.isfinite(v) and v==math.floor(v) and not (v!=0 and v!=1)
        for v in [0,1,0.,1.]:self.assertTrue(domain(v))
        for v in [-1,2,.5,False,True,'0','1',None,math.nan,math.inf,-math.inf]:self.assertFalse(domain(v))
    def test_current_pins_and_unchanged_policy_driver(self):
        pins=json.loads((HERE.parent/'walker-parity-admission/review-pins.json').read_text())
        for group in ['stageInputs','hostInputs','productionDependencies']:
            for n,h in pins[group].items():self.assertEqual(sha(ROOT/n),h,n)
        for name in ['policy.gd','driver.gd','candidate.gd']:
            self.assertEqual((ROOT/'godot/tests/walker_parity_admission'/name).read_bytes(),(AI_STAGE/'tests/walker_parity_admission'/name).read_bytes())
    def test_frozen_AI_AJ_inventories_and_observations(self):
        for root,namespace,count,digest in [(AI,'walker-parity-admission-ai',40,'e9f57119b10ac400430573e59253d78e714832743855094013ecba57797abd96'),(AJ,'walker-policy-receipt-probe-aj',23,'dc49cc762bb1eab492e480c429c3528d982154943f32332f9e0d35029d5a030f')]:
            p=root/'tools/godot-multiplayer/new-maps'/namespace/'evidence/artifact-inventory.json'
            self.assertEqual(sha(p),digest);rows=json.loads(p.read_text())['files'];self.assertEqual(len(rows),count)
            for n,row in rows.items():self.assertEqual(sha(root/n),row['sha256']);self.assertEqual((root/n).stat().st_size,row['bytes'])
        r=json.loads((AJ_STAGE/'probe-result.json').read_text())
        self.assertIs(r['originalPolicyResult'],False);self.assertIs(r['correctedPolicyResult'],True)
        self.assertEqual((len(r['controls']),len(r['mutants']),r['membershipFailures']),(15,7,678))
    def test_legacy_probe_fails_closed_in_corrected_worktree(self):
        # No pin widening, monkeypatch, staging or prep launch. Historical tool
        # intentionally requires its original checkout for future preparation.
        directory=HERE.parent/'walker-policy-receipt-probe'
        sys.path.insert(0,str(directory))
        try:
            spec=importlib.util.spec_from_file_location('_numeric_legacy_prepare',directory/'prepare.py')
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            with self.assertRaisesRegex(ValueError,'original source pins'):module.sources()
            with self.assertRaisesRegex(ValueError,'host source pin'):module.verify_host()
        finally:sys.path.remove(str(directory))
if __name__=='__main__':unittest.main()

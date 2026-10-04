"""Read-only source/lineage checks; no GDScript parser or native staging."""
import hashlib,json,re,unittest
from pathlib import Path
from unittest.mock import patch
import prepare
from policy import MATRIX,AK_RESULT,number,ENGINE_ANGLE,direction,dot,length
class SourceTests(unittest.TestCase):
    def test_pins_and_immutable_approved_design(self):
        pins=prepare.load(prepare.HERE/'review-pins.json');prepare.verify_inputs(prepare.ROOT,pins)
        self.assertEqual(len(pins['productionDependencies']),15)
        receipt=prepare.load(prepare.ROOT/'tools/godot-multiplayer/new-maps/walker-baseline-characterization/source-receipt.json')
        for n,h in receipt['files'].items():self.assertEqual(prepare.sha(prepare.ROOT/'tools/godot-multiplayer/new-maps/walker-baseline-characterization'/n),h)
    def test_minimal_transitive_closure_without_candidate(self):
        pins=prepare.load(prepare.HERE/'review-pins.json');names=set(pins['stageInputs']);self.assertEqual(len(names),7)
        reached=set();todo=['godot/tests/walker_baseline_characterization/driver.gd']
        while todo:
            name=todo.pop()
            if name in reached:continue
            reached.add(name);text=(prepare.ROOT/name).read_text()
            for path in re.findall(r'preload\("([^"]+)"\)',text):todo.append('godot/'+path[6:] if path.startswith('res://') else str(Path(name).parent/path))
        self.assertEqual(reached,names)
        text='\n'.join((prepare.ROOT/n).read_text() for n in names)
        self.assertNotIn('Proposal',text);self.assertNotIn('Candidate.new',text);self.assertEqual(text.count('PhysicsServer3D.body_test_motion('),1)
        driver=(prepare.ROOT/'godot/tests/walker_baseline_characterization/driver.gd').read_text()
        self.assertEqual(driver.count('body.step('),1);self.assertEqual(driver.count('Walker.new()'),1);self.assertIn('create_timer(170)',driver)
    def test_canonical_source_contract_no_authority(self):
        pins=prepare.load(prepare.HERE/'review-pins.json');c=prepare.source('baseline-characterization-al-01',pins)
        self.assertEqual(c['matrix'],MATRIX);self.assertEqual(len(c['files']),8);self.assertFalse(c['autoStart']);self.assertFalse(c['queued']);self.assertIsNone(c['grant'])
        self.assertEqual([(x['radius'],x['rise'],x['yawDegrees']) for x in MATRIX],[(.35,.15,-45),(.35,.15,45),(.42,.15,-45),(.42,.15,45),(.42,.18,-45),(.42,.18,45),(.42,.20,-45),(.42,.20,45)])
        c['queued']=0
        with patch.object(prepare,'load',side_effect=lambda path:c if path.name=='source.json' else pins):
            with self.assertRaisesRegex(ValueError,'typed source flags'):prepare.validate_stage(prepare.ROOT/'godot/tests/walker_baseline_characterization/baseline-characterization-al-01')
    def test_namespace_and_no_case_cli(self):
        for bad in ['Baseline-characterization-al-01','baseline-characterization-AL-01','baseline-characterization-a/../b','other']:
            with self.assertRaises(ValueError):prepare.namespace(prepare.ROOT/bad)
    def test_AK_lineage_failed_positive_not_required_pass(self):
        root=prepare.ROOT.parent/'cocs-walker-parity-admission-ak';self.assertEqual(prepare.lineage(root),prepare.LINEAGE)
        r=prepare.load(root/prepare.AK_RECEIPT);self.assertEqual(r['outcome'],'unexpected_baseline_arrival')
        self.assertEqual(prepare.sha(root/prepare.AK_RECEIPT),AK_RESULT)
    def test_actual_AK_small_radius_stall_obstruction_compatible(self):
        # AK has no per-frame baseline downward-support query. This checks only
        # the newly required ordinary contact/stall operands actually in AK.
        import math
        r=prepare.load(prepare.ROOT.parent/'cocs-walker-parity-admission-ak'/prepare.AK_RECEIPT)
        for case in r['records'][:2]:
            p=case['profiles'][0];d=[math.sin(case['spec']['yaw']),0,math.cos(case['spec']['yaw'])]
            for frame in p['frames'][-120:]:
                self.assertLess(length(frame['wholeFrameDelta']),.0001);self.assertEqual(frame['input'],[0,-1]);self.assertTrue(frame['after']['grounded'])
                contacts=[c for c in frame['slides'] if c['colliderRid']==p['targetRid']]
                self.assertTrue(any(0<c['point'][1]<.25 and c['normal'][1]<math.cos(ENGINE_ANGLE) and -(c['normal'][0]*d[0]+c['normal'][2]*d[2])/math.hypot(c['normal'][0],c['normal'][2])>=.98 for c in contacts))
    def test_write_once_attempt_rejected_before_writes(self):
        with patch.object(Path,'exists',return_value=True),patch.object(prepare,'write') as write:
            with self.assertRaises(FileExistsError):prepare.build('baseline-characterization-al-01','unused')
        write.assert_not_called()
if __name__=='__main__':unittest.main()

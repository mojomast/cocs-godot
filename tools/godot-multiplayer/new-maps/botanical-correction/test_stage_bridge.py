"""Source-only successor bridge gates; no engines and no actual artifact stubs."""
import json
import shutil
import unittest
import uuid
import math
import subprocess
from unittest.mock import patch
from stage_config import MAPS,ROOT,paths,source,sha,read
from stage_bridge import setup,validate_setup,stage,render_scripts
from stage_commands import commands

class StageBridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.attempt='source-test-'+uuid.uuid4().hex
        try:
            for m in MAPS:setup(cls.attempt,m)
        except Exception:
            cls.tearDownClass();raise
    @classmethod
    def tearDownClass(cls):
        # Only unique source-only fixtures created by this test invocation.
        for m in MAPS:
            for path in paths(cls.attempt,m):
                if path.exists():shutil.rmtree(path)
        for path in paths(cls.attempt,next(iter(MAPS))):
            if path.parent.exists() and not any(path.parent.iterdir()):path.parent.rmdir()

    def test_closed_identity_paths_and_pending_state(self):
        for m,entry in MAPS.items():
            out,dest,record=validate_setup(self.attempt,m)
            self.assertEqual(record['geometryHash'],entry[1]);self.assertEqual(record['recipeHash'],entry[2])
            self.assertIsNone(record['glbSha256']);self.assertIsNone(record['masterSha256'])
            self.assertFalse((dest/'manifest.json').exists());self.assertFalse((out/'masters').exists())
            self.assertIn('/botanical_correction/',str(dest));self.assertIn(self.attempt,str(out))
        for a in ['../bad','A','bad/escape','bad..','/tmp/foreign']:
            with self.assertRaises(ValueError):paths(a,'helix-conservatory')
        with self.assertRaises(ValueError):paths(self.attempt,'unknown-map')
        original=MAPS['helix-conservatory']
        with patch.dict(MAPS,{'helix-conservatory':(original[0],'0'*64,*original[2:])}):
            with self.assertRaisesRegex(ValueError,'identity'):source('helix-conservatory')

    def test_blender_style_script_loading_without_sibling_import_path(self):
        driver=ROOT/'tools/godot-multiplayer/new-maps/botanical-correction/attempt_job.py'
        subprocess.run(['python3','-I','-B','-c',
            'import runpy; runpy.run_path('+repr(str(driver))+', run_name="source_import_check")'],cwd=ROOT,check=True)

    def test_attempt_immutability_and_unbuilt_artifact_rejection(self):
        for m in MAPS:
            out,dest=paths(self.attempt,m);before=sha(out/'source.json')
            with self.assertRaises(FileExistsError):setup(self.attempt,m)
            with self.assertRaises(FileNotFoundError):stage(self.attempt,m)
            self.assertEqual(sha(out/'source.json'),before)
            self.assertFalse((dest/'manifest.json').exists());self.assertFalse((dest/'candidate.glb').exists())

    def test_drift_and_wrong_attempt_fail_before_stage(self):
        m='helix-conservatory';out,dest=paths(self.attempt,m);p=dest/'source-probes.json';data=p.read_bytes()
        try:
            p.write_bytes(data+b' ')
            with self.assertRaisesRegex(ValueError,'drift'):validate_setup(self.attempt,m)
        finally:p.write_bytes(data)
        record=out/'source.json';data=record.read_bytes()
        try:
            d=json.loads(data);d['attempt']='wrong-attempt';record.write_text(json.dumps(d))
            with self.assertRaisesRegex(ValueError,'identity'):validate_setup(self.attempt,m)
        finally:record.write_bytes(data)

    def test_adapted_native_contract_and_explicit_bounds(self):
        for m in MAPS:
            scripts=render_scripts(self.attempt,m)
            self.assertNotIn('res://tests/new_maps/botanical_stage/',str(scripts))
            self.assertIn('return DIR',scripts['staged.gd'])
            self.assertIn('"'+MAPS[m][1]+'"',scripts['profile_schema.gd'])
            self.assertIn('force_disable_compression',scripts['staged.gd'])
            self.assertIn('rgba8Sha256',scripts['import.gd'])
            physics=scripts['physics.gd']
            self.assertIn('adjacent_count != 4',physics);self.assertIn('Vector3(.005,0,.005)',physics)
            self.assertIn('>.0001',physics);self.assertIn('>.04',physics)
            self.assertIn('capsule.radius = .42 if',physics);self.assertIn('capsule.height/2.0+.05',physics)
            self.assertIn('Receipt exists; use a new attempt',physics)
            self.assertIn('Capture exists; use a new attempt',scripts['capture.gd'])
            jobs=commands(self.attempt,m)
            self.assertEqual([j['timeoutSeconds'] for j in jobs],[1800,900,900,180,900,60,900,120,180,300,180])
            self.assertNotIn('grant.py',str(jobs));self.assertNotIn('serve',str(jobs))

    def test_successor_probes_modes_and_supported_camera_lineage(self):
        for m in MAPS:
            out,dest=paths(self.attempt,m);p=read(dest/'source-probes.json');r=read(out/'source.json')
            kinds={x['kind'] for x in p['points']}
            self.assertTrue({'accepted-route','candidate-route','spawns','objectives','teamSpawns','flags'}<=kinds)
            self.assertTrue(8<=len(p['cameras'])<=10);self.assertEqual(len(r['modes']),5 if m=='helix-conservatory' else 6)
            if m=='parallax-observatory':
                self.assertEqual(sum(x['kind']=='successor-aperture' for x in p['points']),1302)
                self.assertEqual(sum(x['kind']=='successor-grade' for x in p['points']),618)
                self.assertEqual(sum(x['kind']=='aperture' for x in p['raySpecs']),372)
            if m=='vesper-viaduct':self.assertEqual(sum(x['kind']=='canonical-parapet' for x in p['raySpecs']),54*6)
            if m=='helix-conservatory':
                c=next(c for c in p['cameras'] if c['id']=='greenhouse-eye')
                self.assertEqual(c['eye'],c['beforeEye']);self.assertIn('radial',c['targetLineage'])
                self.assertEqual(sum(x['kind']=='frame-post' for x in p['raySpecs']),60)
                # Exact X-02 failure geometry: the old radial ray was coplanar
                # with the inherited angle82 brick seam. Require a real crossing
                # through the SAME post centre, not a wider distance tolerance.
                ray=next(r for r in p['raySpecs'] if r['id']=='post:82:93.2:0.5:1')
                a=math.radians(82);normal=(-math.sin(a),0,math.cos(a))
                old_direction=(-math.cos(a),0,-math.sin(a))
                self.assertAlmostEqual(sum(x*y for x,y in zip(normal,old_direction)),0)
                self.assertGreater(abs(sum(x*y for x,y in zip(normal,ray['direction']))),.25)
                center=[93.2*math.cos(a),16.5,93.2*math.sin(a)]
                for k in range(3):self.assertAlmostEqual(ray['origin'][k]+ray['direction'][k],center[k])

if __name__=='__main__':unittest.main()

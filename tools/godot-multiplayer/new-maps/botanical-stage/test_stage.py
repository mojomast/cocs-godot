"""Source-only regression gates: identity, real transforms, topology, bounds."""
import copy
import json
import math
import subprocess
import sys
import unittest
from config import ROOT, DEST, MAPS, entry, source_manifest, read
from prepare_stage import schema_source, make_profile, prepare_artifacts, probes
from geometry import glb_triangles, TriangleInventory, ray_distance, transform, node_matrix, RayIndex
from glb_test_fixtures import geometry_fixture, encode_glb

class StageTests(unittest.TestCase):
    def test_manifest_is_exact_pending_and_agrees_with_all_author_plans(self):
        manifest=source_manifest()
        self.assertEqual(manifest,read(DEST/'source-manifest.json'))
        for id,m in manifest['maps'].items():
            self.assertEqual(m['geometryHash'],MAPS[id][1])
            self.assertIsNone(m['glbSha256'])
            self.assertEqual(m['artifactStatus'],'pending-build')
            self.assertEqual(len(m['modes']),5 if id=='helix-conservatory' else 6)
            catalog=(ROOT/'godot/multiplayer_worlds/catalog.gd').read_text()
            self.assertIn('"'+id+'": '+json.dumps(m['modes'],separators=(',',':')),catalog)

    def test_stage_refuses_missing_build_without_creating_ready_files(self):
        for id in MAPS:
            if entry(id)[0].EXPORT.exists():continue
            with self.assertRaises(FileNotFoundError):prepare_artifacts(id)
            self.assertFalse((DEST/'artifacts'/id/'manifest.json').exists())

    def test_schema_exact_candidates_and_profiles_preserve_accepted_placements(self):
        self.assertEqual(schema_source(),(DEST/'profile_schema.gd').read_text())
        for id in MAPS:
            self.assertIn(MAPS[id][1],schema_source())
            p,_=make_profile(id,['water','glass'])
            self.assertEqual(p['preserve_materials'],['glass','water'])
            self.assertEqual(p['materials'],[])
            path=ROOT/f'godot/multiplayer_worlds/dressing/profiles/{id}.json'
            if path.exists():
                for group in ('panels','signs','pockets'):self.assertEqual(p[group],read(path)[group])
            else:self.assertEqual(p['signs'],[])

    def test_actual_scene_parent_transforms_are_applied(self):
        doc,binary=geometry_fixture()
        doc['nodes']=[{'children':[1],'translation':[10,20,30]},
                      {'mesh':0,'rotation':[0,0,math.sqrt(.5),math.sqrt(.5)],'scale':[2,2,2]}]
        rows=glb_triangles(encode_glb(doc,binary))
        expected=[[10,20,30],[10,22,30],[8,20,30]]
        for a,b in zip(rows[0]['vertices'],expected):
            for x,y in zip(a,b):self.assertAlmostEqual(x,y)

    def test_triangle_matching_rejects_duplicates_movement_and_winding(self):
        row={'material':'slate','vertices':[[0,0,0],[1,0,0],[0,1,0]]}
        TriangleInventory([row]).match([row],complete=True)
        for bad in ({**row,'material':'brick'}, {**row,'vertices':list(reversed(row['vertices']))},
                    {**row,'vertices':[[.001,0,0],[1,0,0],[0,1,0]]}):
            with self.assertRaises(ValueError):TriangleInventory([bad]).match([row],complete=True)
        with self.assertRaises(ValueError):TriangleInventory([row,row]).match([row],complete=True)
        with self.assertRaises(ValueError):TriangleInventory([row]).match([row,row])

    def test_rays_reject_nan_and_detect_upper_body_not_just_footprints(self):
        wall=[[[0,1,-1],[0,3,-1],[0,3,1]],[[0,1,-1],[0,3,1],[0,1,1]]]
        self.assertAlmostEqual(RayIndex(wall).ray([-1,2,0],[1,0,0],3),1)
        self.assertEqual(RayIndex(wall).ray([-1,.2,0],[1,0,0],3),3)
        for direction in ([1,0],[float('nan'),0,0],[0,0,0]):
            with self.assertRaises(ValueError):ray_distance(wall,[-1,2,0],direction,3)

    def test_dense_probes_cameras_and_original_nav_heights(self):
        for id in MAPS:
            p=probes(id);counts={}
            for row in p['points']:
                counts[row['kind']]=counts.get(row['kind'],0)+1
                self.assertTrue(all(math.isfinite(row[k]) for k in ('x','y','z')))
            self.assertGreater(counts['accepted-route'],1000)
            self.assertGreater(counts['candidate-route'],1000)
            self.assertGreater(counts['accepted-nav'],100)
            self.assertTrue(8<=len(p['cameras'])<=10)
            self.assertEqual(p['cameras'],read(DEST/(id+'-cameras.json'))['cameras'])
            if id=='parallax-observatory':
                well=next(c for c in p['cameras'] if c['id']=='well-descent')
                self.assertEqual(well['ground'],8)
                self.assertTrue(well['comparison'].startswith('repositioned:'))
            if id=='vesper-viaduct':
                self.assertEqual(next(c for c in p['cameras'] if c['id']=='roof-player')['ground'],22)

if __name__=='__main__':unittest.main()

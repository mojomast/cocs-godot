import copy
import struct
import unittest
from successor import *
from native_gate import check_streams

class Contract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=frozen();cls.output,cls.records=compile_art(cls.raw)

    def test_boundaries_and_editable(self):
        self.assertEqual(verify_art(self.raw,self.output)['XChangedBINBytes'],69)
        self.assertEqual(audit_editable(self.raw,self.raw)['triangles'],155553)
        mutant=bytearray(self.output);mutant[-100]^=1
        with self.assertRaises((ValueError,AssertionError)):verify_art(self.raw,bytes(mutant))

    def test_changed_input_and_incident_rejected(self):
        mutant=bytearray(self.raw);mutant[-100]^=1
        with self.assertRaises(ValueError):compile_art(bytes(mutant))
        _,_,faces=census.source_faces(aa.EmbeddedGlb(self.raw))
        f=next(f for f in faces if f['node']=='wayfinding-2' and f['face']==965)
        cs=copy.deepcopy(f['corners']);ci=next(i for i,c in enumerate(cs) if c['vertex']==1026)
        cs[ci]['N']=(0,1,0)
        with self.assertRaises(ValueError):approved_policy.rank_one_basis(cs,ci)

    def test_old_native_rejected_and_synthetic_full_scene(self):
        evidence=AA_ART.parent/'evidence';report=json.loads((evidence/'native-import.json').read_text());raw=(evidence/'native-streams.bin').read_bytes()
        report['artHash']=sha(self.output)
        with self.assertRaises(ValueError):check_streams(self.output,report,raw)
        # Synthesize exact arrays from successor source, independent of old native.
        g=aa.EmbeddedGlb(self.output);blob=bytearray();surfaces=[];tangent_offsets=[]
        for node in g.doc['nodes']:
            p=g.doc['meshes'][node['mesh']]['primitives'][0];a=p['attributes'];arrays=[]
            for field,shape in (('POSITION','VEC3'),('NORMAL','VEC3'),('TEXCOORD_0','VEC2'),('TANGENT','VEC4')):arrays.append(aa.stream(g,a[field],shape))
            ix=[x[0] for x in aa.stream(g,p['indices'],'SCALAR',(5121,5123,5125))]
            surfaces.append({'node':node['name'].replace('.','_'),'surface':0,'material':g.doc['materials'][p['material']]['name'],'offset':len(blob),'vertices':len(arrays[0]),'indices':len(ix)})
            for index,rows in enumerate(arrays):
                if index==3:tangent_offsets.append(len(blob))
                for row in rows:blob.extend(struct.pack('<'+'f'*len(row),*row))
            for i in range(0,len(ix),3):blob.extend(struct.pack('<3I',*reversed(ix[i:i+3])))
        report['surfaces']=surfaces
        proof=check_streams(self.output,report,bytes(blob));self.assertEqual(len(proof['repairedMappings']),51)
        offset=tangent_offsets[0]+12;w=struct.unpack_from('<f',blob,offset)[0];struct.pack_into('<f',blob,offset,-w)
        with self.assertRaises(ValueError):check_streams(self.output,report,bytes(blob))
        struct.pack_into('<f',blob,offset,w)
        report['surfaces']=report['surfaces'][:-1]
        with self.assertRaises(ValueError):check_streams(self.output,report,bytes(blob))

    def test_duplicate_multiset_not_sign_selection(self):
        self.assertEqual(len(census.maximum_matching([-1,-1],[-1,1],lambda a,b:a==b)),1)
        self.assertEqual(len(census.maximum_matching([-1,1],[1,-1],lambda a,b:a==b)),2)

    def test_packed_recipe_provenance_and_queue(self):
        from build import recipe,old_recipe,verify_old_recipe
        encoded=json.dumps(old_recipe(),sort_keys=True)
        class Text:
            def __init__(self,value):self.value=value
            def as_string(self):return self.value
        texts={'PARALLAX_TANGENT_RECIPE.json':Text(encoded),'PARALLAX_TANGENT_COMPILER.py':Text((AA_DIR/'contract.py').read_text())}
        verify_old_recipe({'parallax_tangent_recipe':encoded},texts)
        texts['PARALLAX_TANGENT_COMPILER.py']=Text('changed')
        with self.assertRaises(ValueError):verify_old_recipe({'parallax_tangent_recipe':encoded},texts)
        self.assertEqual(recipe()['sourceAAArtSha256'],AA_SHA)
        queue=json.loads((HERE/'queue.json').read_text())
        self.assertIsNone(queue['grant']);self.assertFalse(queue['autoStart'])

    def test_stage_plan_in_memory_binds_both_variants(self):
        from unittest.mock import patch
        import stage
        attempt='glyph-memory-test';out=stage.attempt_path(attempt)
        dest=ROOT/'godot/tests/new_maps/parallax_glyph'/attempt
        master=b'synthetic-master-not-native-evidence'
        report=json.dumps({'actualArtHash':sha(self.output),'actualMasterHash':sha(master)}).encode()
        memory={out/'parallax-glyph-tangents.glb':self.output,out/'parallax-glyph-tangents.blend':master,
            out/'build-report.json':report,out/'reopen-report.json':report}
        original=Path.read_bytes
        def read(path):return memory[path] if path in memory else original(path)
        def write(path,data):memory[path]=data;return len(data)
        with patch.object(stage,'require_grant',return_value={}),patch.object(Path,'mkdir'),\
             patch.object(Path,'read_bytes',read),patch.object(Path,'read_text',lambda p,*a,**k:read(p).decode()),\
             patch.object(Path,'write_bytes',write),patch.object(Path,'write_text',lambda p,t,*a,**k:write(p,t.encode())),\
             patch.object(Path,'iterdir',lambda p:iter([q for q in memory if q.parent==p])),\
             patch.object(Path,'is_file',lambda p:p in memory):
            self.assertEqual(stage.prepare(attempt,Path('unused')),dest)
        manifest=json.loads(memory[dest/'manifest.json'])
        self.assertEqual(manifest['glbSha256'],sha(self.output));self.assertEqual(manifest['source']['acceptedArtSha256'],AA_SHA)
        self.assertNotIn('exportAudit',manifest)
        probes=json.loads(memory[dest/'probes.json']);self.assertEqual(len(probes['cameras']),12)
        self.assertTrue(all(c['eye']==c['beforeEye'] and 'comparison' in c for c in probes['cameras']))
        text=memory[dest/'staged.gd'].decode()
        self.assertIn('"candidate.glb" if candidate else "before-AA-failed.glb"',text)
        self.assertIn('if true:',text)

if __name__=='__main__':unittest.main()

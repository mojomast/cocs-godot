"""Pinned X fixture tests run wholly in memory; no production outputs."""
import copy
import struct
import unittest
from contract import EmbeddedGlb, SOURCE_SHA, MASTER_SHA, TANGENT, VERTICES, encode, pinned, repair, verify, sha, source_face
from editable import audit, compare_materials
from material_contract import verify_native_materials

class ParallaxContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = pinned()
        cls.output, cls.proof = repair(cls.original)

    def test_three_exclusive_corners_and_exact_outside_bytes(self):
        source, successor = EmbeddedGlb(self.original), EmbeddedGlb(self.output)
        self.assertEqual(sha(self.original), SOURCE_SHA)
        self.assertEqual((self.proof['changedBytes'], self.proof['allowedBytes']), (5, 48))
        self.assertEqual(verify(self.original, self.output)['zeroWaivers'], 0)
        _, _, layout = source.accessor(48, 'VEC4', (5126,), 'tangent')
        allowed = {i for v in VERTICES for i in range(layout[0] + v*layout[1], layout[0] + v*layout[1] + 16)}
        self.assertEqual(len(allowed), 48)
        self.assertEqual({i for i, (a,b) in enumerate(zip(source.binary,successor.binary)) if a != b} <= allowed, True)
        self.assertEqual(source.doc['materials'], successor.doc['materials'])
        self.assertEqual(source.doc['meshes'], successor.doc['meshes'])
        self.assertEqual(source.doc['images'], successor.doc['images'])
        self.assertEqual(source.doc['scenes'], successor.doc['scenes'])
        self.assertEqual(source_face(successor)[3][24049:24052], [TANGENT]*3)

    def test_pinned_input_and_output_mutations_reject(self):
        source = EmbeddedGlb(self.original); successor = EmbeddedGlb(self.output)
        with self.assertRaisesRegex(ValueError, 'Exact X'): repair(self.output)
        with self.assertRaisesRegex(ValueError, 'master'):  # production dependencies both pinned
            from unittest.mock import patch
            with patch('contract.MASTER_SHA', 'wrong'): pinned()
        blob = bytearray(successor.binary)
        mesh = successor.doc['meshes'][9]['primitives'][0]
        _, _, layout = successor.accessor(mesh['attributes']['TANGENT'], 'VEC4', (5126,), 'tangent')
        struct.pack_into('<f', blob, layout[0] + 24050*layout[1] + 12, 1.)
        with self.assertRaisesRegex(ValueError, 'canonical'): verify(self.original, encode(successor.doc, blob))
        blob = bytearray(successor.binary)
        struct.pack_into('<f', blob, layout[0] + 2*layout[1], .125)
        with self.assertRaisesRegex(ValueError, 'canonical'): verify(self.original, encode(successor.doc, blob))
        doc = copy.deepcopy(successor.doc)
        doc['materials'][6]['pbrMetallicRoughness']['roughnessFactor'] = .25
        with self.assertRaisesRegex(ValueError, 'canonical'): verify(self.original, encode(doc, successor.binary))
        with self.assertRaisesRegex(ValueError, 'Exact X'): repair(encode(source.doc, successor.binary))

    def test_real_editable_scene_and_material_counterexamples(self):
        self.assertEqual(audit(self.original, self.original)['triangles'], 155553)
        g = EmbeddedGlb(self.original)
        def modified(fn):
            doc = copy.deepcopy(g.doc); fn(doc)
            return encode(doc, g.binary)
        def clamp(d):
            mat = next(m for m in d['materials'] if m['name'] == 'saltstone')
            slot = mat['pbrMetallicRoughness']['baseColorTexture']
            tex = d['textures'][slot['index']]
            sampler = copy.deepcopy(d['samplers'][tex['sampler']]); sampler['wrapS'] = 33071
            tex['sampler'] = len(d['samplers']); d['samplers'].append(sampler)
        def emissive(d):
            next(m for m in d['materials'] if m['name'] == 'parallax.optics')['emissiveTexture'] = {'index':0}
        for change in (clamp, emissive):
            with self.subTest(change=change.__name__), self.assertRaisesRegex(ValueError, 'texture/render semantics'):
                audit(modified(change), self.original)
        # Index churn is acceptable when texture, sampler, decoded pixels and
        # source emissive/metallic factors really are equivalent.
        def remap(d):
            n = len(d['textures']); d['textures'].reverse()
            for m in d['materials']:
                for obj in (m, m.get('pbrMetallicRoughness', {})):
                    for key, value in obj.items():
                        if key.endswith('Texture'): value['index'] = n - 1 - value['index']
        self.assertEqual(audit(modified(remap), self.original)['triangles'], 155553)
        # Geometry must reject actual UV drift even though material equivalence passes.
        blob = bytearray(g.binary)
        ix = g.doc['meshes'][9]['primitives'][0]['attributes']['TEXCOORD_0']
        _, _, layout = g.accessor(ix, 'VEC2', (5126,), 'UV')
        struct.pack_into('<f', blob, layout[0], struct.unpack_from('<f', blob, layout[0])[0] + .01)
        with self.assertRaisesRegex(ValueError, 'geometry/normal/UV'): audit(encode(g.doc, blob), self.original)

    def test_native_field_gate_reuses_r7_color_precision_for_real_parallax_materials(self):
        g = EmbeddedGlb(self.output)
        def srgb(x): return 12.92*x if x <= .0031308 else 1.055*x**(1/2.4)-.055
        report = {'materials':{}}
        for m in g.doc['materials']:
            p = m.get('pbrMetallicRoughness', {})
            base = p.get('baseColorFactor',[1,1,1,1]); em = m.get('emissiveFactor',[0,0,0])
            color = lambda v: '(' + ', '.join(f'{x:.4f}' for x in v) + ')'
            report['materials'][m['name']] = {'albedo':color([*(srgb(x) for x in base[:3]),base[3]]),
                'emission':color([*(srgb(x) for x in em),1]), 'metallic':p.get('metallicFactor',1),
                'roughness':p.get('roughnessFactor',1), 'normalScale':m.get('normalTexture',{}).get('scale',1),
                'emissionEnergy':1, 'emissionEnabled':any(x>0 for x in em) or 'emissiveTexture' in m,
                'roughnessChannel':1 if 'metallicRoughnessTexture' in p else 0}
        self.assertEqual(verify_native_materials(g, report),14)
        report['materials']['saltstone']['normalScale'] = 0
        with self.assertRaisesRegex(ValueError, 'normalScale'): verify_native_materials(g, report)

if __name__ == '__main__': unittest.main()

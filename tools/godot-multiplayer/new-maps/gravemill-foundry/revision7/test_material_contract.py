"""P1 regressions on actual pinned R6 bytes, exclusively in memory."""
import unittest
from tangents import *
from production import audit_editable_export
from material_contract import compare_materials, semantics, verify_native_materials

class MaterialContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=SOURCE.read_bytes();cls.g=gate(cls.raw)

    def mutate(self,fn):
        doc=copy.deepcopy(self.g.doc);fn(doc)
        return encode(doc,self.g.binary)

    def test_actual_counterexamples_rejected_by_full_editable_audit(self):
        def clamp(d):
            ground=next(m for m in d['materials'] if m['name']=='R6 / ground')
            texture=d['textures'][ground['pbrMetallicRoughness']['baseColorTexture']['index']]
            sampler=copy.deepcopy(d['samplers'][texture['sampler']]);sampler.update(wrapS=33071,wrapT=33071)
            texture['sampler']=len(d['samplers']);d['samplers'].append(sampler)
        def emissive(d):next(m for m in d['materials'] if m['name']=='GM / orange')['emissiveTexture']={'index':0}
        for fn in (clamp,emissive):
            with self.subTest(mutation=fn.__name__):
                with self.assertRaisesRegex(ValueError,'Material texture/render semantics changed'):
                    audit_editable_export(self.mutate(fn))

    def test_actual_baseline_and_semantically_remapped_export_pass(self):
        self.assertTrue(audit_editable_export(self.raw)['allMaterialPixelsAndPBRMatch'])
        def remap(d):
            n=len(d['textures']);d['textures'].reverse()
            for m in d['materials']:
                for obj in (m,m.get('pbrMetallicRoughness',{})):
                    for key,value in obj.items():
                        if key.endswith('Texture'):value['index']=n-1-value['index'];value['texCoord']=0
            n=len(d['images']);d['images'].reverse()
            for t in d['textures']:
                t['source']=n-1-t['source'];t['sampler']=1-t['sampler']
            d['samplers'].reverse()
            for s in d['samplers']:s.update(wrapS=10497,wrapT=10497,extras={'note':'metadata only'})
        self.assertTrue(audit_editable_export(self.mutate(remap))['allMaterialPixelsAndPBRMatch'])

    def test_sampler_defaults_enums_coordinates_and_unsupported_semantics(self):
        mutations=[lambda d:d['samplers'][0].update(magFilter=9987),
            lambda d:d['samplers'][0].update(minFilter=9999),
            lambda d:d['samplers'][0].update(wrapS=1),
            lambda d:d['samplers'][0].pop('minFilter'),
            lambda d:d['samplers'][0].update(minFilter=9728),
            lambda d:d['materials'][0]['normalTexture'].update(texCoord=1),
            lambda d:d['materials'][0]['normalTexture'].update(extensions={'KHR_texture_transform':{'offset':[.1,0]}}),
            lambda d:d['materials'][0].update(extensions={'KHR_materials_unlit':{}}),
            lambda d:d['textures'][0].update(extensions={'UNKNOWN':{}}),
            lambda d:d['materials'][0].update(unknownShading=.5),
            lambda d:d['materials'][0].update(occlusionTexture={'index':0,'strength':.5}),
            lambda d:d['materials'][0].update(alphaCutoff=.2),
            lambda d:d['materials'][0].update(doubleSided=False)]
        for i,fn in enumerate(mutations):
            with self.subTest(mutation=i),self.assertRaises(ValueError):
                compare_materials(self.g,gate(self.mutate(fn)))
        # A missing filter is implementation-defined and differs from explicit linear/mipmap.
        doc=copy.deepcopy(self.g.doc);doc['samplers'][0].pop('minFilter')
        a=gate(encode(doc,self.g.binary));compare_materials(a,a)

    def test_emissive_binding_pixels_and_occlusion_strength_compared(self):
        doc=copy.deepcopy(self.g.doc);m=doc['materials'][9]
        m['emissiveTexture']={'index':0};m['occlusionTexture']={'index':1,'strength':.5}
        a=gate(encode(doc,self.g.binary));compare_materials(a,a)
        for key,value in [('emissiveTexture',{'index':1}),('occlusionTexture',{'index':1,'strength':.6})]:
            changed=copy.deepcopy(doc);changed['materials'][9][key]=value
            with self.assertRaises(ValueError):compare_materials(a,gate(encode(changed,self.g.binary)))

    def test_actual_historical_native_field_schema_and_mutants(self):
        report=json.loads((R6/'evidence/W/native-import.json').read_text())
        self.assertEqual(verify_native_materials(self.g,report),18)
        mutations={'albedo':'(0.8, 0.19, 0.025, 1.0)','emission':'(1.0, 0.2375, 0.03125, 1.0)',
            'metallic':.1,'roughness':.4,'normalScale':.2,'emissionEnergy':1.0,'emissionEnabled':False,'roughnessChannel':1}
        for key,value in mutations.items():
            changed=copy.deepcopy(report);changed['materials']['GM / orange'][key]=value
            with self.subTest(field=key),self.assertRaisesRegex(ValueError,'Native'):
                verify_native_materials(self.g,changed)
        changed=copy.deepcopy(report);changed['materials']['R6 / ground']['normalScale']=.35
        with self.assertRaisesRegex(ValueError,'normalScale'):verify_native_materials(self.g,changed)

if __name__=='__main__':unittest.main()

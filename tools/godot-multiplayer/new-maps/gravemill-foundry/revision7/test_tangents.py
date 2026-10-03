"""Source-only in-memory fixtures; no production artifact or engine invocation."""
import copy
import struct
import unittest
from tangents import *
from test_source import fixture  # Reviewed small R6 serializer fixture; no writes.

def small(transform=lambda u,v:(u,v),shared=False,conflict=False,reverse=False):
    raw,_,_=fixture();g=gate(raw);doc=copy.deepcopy(g.doc);blob=bytearray(g.binary)
    p=doc['meshes'][0]['primitives'][0];tan=p['attributes']['TANGENT']
    _,_,layout=g.accessor(tan,'VEC4',(5126,),'TANGENT');struct.pack_into('<4f',blob,layout[0],0,0,0,1)
    _,_,layout=g.accessor(p['attributes']['TEXCOORD_0'],'VEC2',(5126,),'TEXCOORD_0')
    for i,(u,v) in enumerate(values(g,p['attributes']['TEXCOORD_0'])):
        struct.pack_into('<2f',blob,layout[0]+i*layout[1],*transform(u,v))
    _,_,il=g.accessor(p['indices'],'SCALAR',(5125,),'index')
    indices=[0,1,2,1,3,2]
    if shared:indices=[0,1,2,0,3,2]
    if reverse:indices=[0,2,1,1,3,2]
    if conflict:
        struct.pack_into('<2f',blob,layout[0]+3*layout[1],-1,1)
    struct.pack_into('<6I',blob,il[0],*indices)
    return encode(doc,blob),{(tan,0)}

class UVBasis(unittest.TestCase):
    def test_native_gate_has_no_fallback_waiver(self):
        from native_check import verify_streams
        raw,ids=small();result,_=repair(raw,source_sha=sha(raw),expected=ids)
        g=gate(result);_,_,p,s,faces=next(rows(g));data=bytearray()
        for field,width in [('POSITION',3),('NORMAL',3),('TEXCOORD_0',2),('TANGENT',4)]:
            for value in s[field]:data.extend(struct.pack('<'+'f'*width,*value))
        indices=[i for f in faces for i in reversed(f)]
        data.extend(struct.pack('<'+'I'*len(indices),*indices))
        report={'artHash':sha(result),'surfaces':[{'offset':0,'vertices':len(s['POSITION']),'indices':len(indices),'material':g.doc['materials'][p['material']]['name']}]}
        self.assertEqual(verify_streams(result,report,data)['undefinedTangentWaivers'],0)
        struct.pack_into('<4f',data,len(s['POSITION'])*32,-.0000305185,0,-1,1)
        with self.assertRaisesRegex(ValueError,'no zero-tangent exemption'):verify_streams(result,report,data)

    def test_reflected_and_reversed_uv_orientation(self):
        cases=[(lambda u,v:(u,v),False,(1,0,0,1)),(lambda u,v:(-u,v),False,(-1,0,0,-1)),
            (lambda u,v:(u,-v),False,(1,0,0,-1)),(lambda u,v:(-u,-v),False,(-1,0,0,1)),
            (lambda u,v:(u,v),True,(1,0,0,1))]
        for transform,reverse,want in cases:
            with self.subTest(want=want,reverse=reverse):
                raw,ids=small(transform,reverse=reverse);result,changes=repair(raw,source_sha=sha(raw),expected=ids)
                self.assertEqual(changes[0]['tangent'],want)
                self.assertEqual(verify(raw,result,source_sha=sha(raw),expected=ids)['repairedEntries'],1)

    def test_shared_vertex_accumulates_all_incidents(self):
        raw,ids=small(shared=True);_,changes=repair(raw,source_sha=sha(raw),expected=ids)
        self.assertEqual(len(changes[0]['incidents']),2)
        self.assertEqual(changes[0]['tangent'],(1,0,0,1))
        bs=[i['basis'] for i in changes[0]['incidents']]
        self.assertEqual(solve(bs),solve(list(reversed(bs))))

    def test_conflicting_shared_uv_handedness_rejected(self):
        raw,ids=small(shared=True,conflict=True)
        with self.assertRaisesRegex(ValueError,'Ambiguous shared tangent'):repair(raw,source_sha=sha(raw),expected=ids)

    def test_same_handedness_but_conflicting_shared_directions_rejected(self):
        points=[(0,0,0),(1,0,0),(0,1,0)];n=(0,0,1)
        a=basis(points,[(0,0),(1,0),(0,1)],n,0)
        b=basis(points,[(0,0),(0,-1),(1,0)],n,0)
        self.assertEqual(a['sign'],b['sign'])
        with self.assertRaisesRegex(ValueError,'Ambiguous shared tangent directions'):solve([a,b])

    def test_additional_zero_unknown_inventory_rejected(self):
        raw,ids=small();g=gate(raw);blob=bytearray(g.binary)
        a=next(iter(ids))[0];_,_,layout=g.accessor(a,'VEC4',(5126,),'TANGENT')
        struct.pack_into('<4f',blob,layout[0]+layout[1],0,0,0,1);changed=encode(g.doc,blob)
        with self.assertRaisesRegex(ValueError,'inventory differs'):repair(changed,source_sha=sha(changed),expected=ids)

class RealR6(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=SOURCE.read_bytes();cls.output,cls.changes=repair(cls.raw)
        cls.report=verify(cls.raw,cls.output)

    def test_exact_seven_corner_mapping_and_non_degeneracy(self):
        self.assertEqual((self.report['triangles'],self.report['primitives']),(87566,32))
        self.assertEqual({(c['accessor'],c['vertex']) for c in self.changes},EXPECTED)
        self.assertEqual(sorted(i['face'] for c in self.changes for i in c['incidents']),[682,2283,2284,2285,2303,2304,2305])
        for c in self.changes:
            self.assertEqual(len(c['incidents']),1)
            i=c['incidents'][0];self.assertGreater(i['basis']['area'],.01);self.assertGreater(abs(i['basis']['uvJacobian']),.001)
            t=c['tangent'];n=unit(i['normal']);self.assertAlmostEqual(norm(t[:3]),1,places=6);self.assertLess(abs(dot(n,t[:3])),1e-6)
            # Independent sign check from UV derivatives, not old invalid w or
            # Godot's default fallback. Invalid xyz makes the old sign unusable.
            ps,uv=i['trianglePositions'],i['triangleUV'];e1=sub(ps[1],ps[0]);e2=sub(ps[2],ps[0]);a=sub(uv[1],uv[0]);b=sub(uv[2],uv[0]);det=a[0]*b[1]-a[1]*b[0]
            dv=mul(sub(mul(e2,a[0]),mul(e1,b[0])),1/det)
            self.assertGreater(dot(mul(cross(n,t[:3]),t[3]),dv),0)
            self.assertLess(dot(unit(t[:3]),unit((-.0000305185,0,-1))),.1)

    def test_editable_export_audit_accepts_baseline_rejects_uv_and_material_drift(self):
        from production import audit_editable_export
        self.assertEqual(audit_editable_export(self.raw)['triangles'],87566)
        g=gate(self.raw);doc=copy.deepcopy(g.doc)
        doc['materials'][0].setdefault('normalTexture',{})['scale']=.987654
        with self.assertRaisesRegex(ValueError,'Material PBR/emission fields changed'):
            audit_editable_export(encode(doc,g.binary))
        _,_,p,_,_=next(rows(g));blob=bytearray(g.binary)
        _,_,layout=g.accessor(p['attributes']['TEXCOORD_0'],'VEC2',(5126,),'TEXCOORD_0')
        value=struct.unpack_from('<f',blob,layout[0])[0]
        struct.pack_into('<f',blob,layout[0],value+.01)
        with self.assertRaisesRegex(ValueError,'Editable master differs'):
            audit_editable_export(encode(g.doc,blob))

    def test_all_other_bytes_and_materials_indices_are_unchanged(self):
        old=gate(self.raw);new=gate(self.output);ranges=set()
        for c in self.changes:ranges.update(range(c['binOffset'],c['binOffset']+16))
        self.assertEqual(len(ranges),112)
        self.assertEqual(old.doc['materials'],new.doc['materials']);self.assertEqual(old.doc['accessors'],new.doc['accessors'])
        self.assertEqual(old.doc['meshes'],new.doc['meshes']);self.assertEqual(old.doc['images'],new.doc['images'])
        self.assertEqual(len(old.binary),len(new.binary))
        self.assertTrue(all(a==b for index,(a,b) in enumerate(zip(old.binary,new.binary)) if index not in ranges))

    def test_strict_gate_and_out_of_scope_tangent_change_reject(self):
        g=gate(self.output);doc=copy.deepcopy(g.doc);doc['scenes'][doc['scene']]['nodes']=[]
        with self.assertRaisesRegex(ValueError,'Scene has no root nodes'):verify(self.raw,encode(doc,g.binary))
        doc=copy.deepcopy(g.doc);p=doc['meshes'][0]['primitives'][0];doc['bufferViews'][doc['accessors'][p['indices']]['bufferView']]['byteLength']=1
        with self.assertRaisesRegex(ValueError,'exceeds bufferView'):verify(self.raw,encode(doc,g.binary))
        blob=bytearray(g.binary);_,_,layout=g.accessor(p['attributes']['TANGENT'],'VEC4',(5126,),'TANGENT')
        struct.pack_into('<f',blob,layout[0],.5)
        with self.assertRaisesRegex(ValueError,'Unexpected successor bytes'):verify(self.raw,encode(g.doc,blob))

    def test_wrong_godot_fallback_is_not_accepted(self):
        g=gate(self.output);blob=bytearray(g.binary);c=self.changes[0]
        struct.pack_into('<4f',blob,c['binOffset'],-.0000305185,0,-1,1)
        with self.assertRaisesRegex(ValueError,'Unexpected successor bytes'):verify(self.raw,encode(g.doc,blob))

if __name__=='__main__':unittest.main()

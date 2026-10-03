"""P1 regressions: actual R5 + reviewed pack, composed only in memory.

The synthetic library is a test fixture, not a Blender/native R6 artifact.
No GLB, image, import cache, art identity or built receipt is written.
"""
import copy
import json
import struct
import unittest
import zlib

from compose import compose
from finish import GLB,HERE,ROOT,read,plan,glb_parts,primitives,access
from glb_contract import gate,EmbeddedGlb
from material_pack import load_pack,linear_rgba,srgb_png
from test_source import glb,fixture
from verify import verify

def library_fixture():
    resources,_=load_pack(ROOT);doc={'asset':{'version':'2.0'},'bufferViews':[],'materials':[],'images':[],'textures':[]};blob=bytearray()
    def texture(raw,name):
        blob.extend(b'\0'*(-len(blob)%4))
        doc['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':len(raw)});blob.extend(raw)
        doc['images'].append({'name':name,'bufferView':len(doc['bufferViews'])-1,'mimeType':'image/png'})
        doc['textures'].append({'source':len(doc['images'])-1})
        return {'index':len(doc['textures'])-1}
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    for name,b in read(HERE/'bindings.json').items():
        channels=resources[b['resource']]['channels']
        color=texture(srgb_png(channels['albedo']['path'].read_bytes()),name+'-color')
        normal=texture(channels['normal']['path'].read_bytes(),name+'-normal');normal['scale']=b['normalStrength']
        w,h,pixels=linear_rgba(channels['roughness']['path'].read_bytes())
        packed=bytearray()
        for y in range(h):
            packed.append(0)
            for x in range(w):packed.extend((255,pixels[(y*w+x)*4],255,255))
        rough=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(packed))+chunk(b'IEND',b'')
        doc['materials'].append({'name':name,'normalTexture':normal,'pbrMetallicRoughness':{'baseColorTexture':color,
            'metallicRoughnessTexture':texture(rough,name+'-roughness'),'metallicFactor':b['metallic'],'roughnessFactor':1}})
    return glb(doc,bytes(blob))

class RealR5Contract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=read(HERE/'finish-plan.json')
        cls.output=compose(cls.plan,library_fixture())
        parsed=EmbeddedGlb(cls.output);cls.doc=parsed.doc;cls.binary=parsed.binary

    def test_valid_real_r5_composition_and_exact_stream_bytes(self):
        self.assertEqual(plan(),self.plan)  # Material directions and prior plan immutable.
        result=verify(self.output,self.plan)
        self.assertEqual((result['triangles'],result['primitives']),(87566,32))
        source=gate(GLB.read_bytes());output=gate(self.output)
        for parts in source.doc['meshes']:
            for p in parts['primitives']:
                for name in ('POSITION','NORMAL','TANGENT'):
                    index=p['attributes'][name]
                    self.assertEqual(source.doc['accessors'][index],output.doc['accessors'][index])
                    view=source.doc['accessors'][index]['bufferView']
                    self.assertEqual(source.view_bytes(view),output.view_bytes(view))

    def reject(self,mutate,message):
        doc=copy.deepcopy(self.doc);mutate(doc)
        raw=glb(doc,self.binary)
        with self.assertRaisesRegex(ValueError,message):verify(raw,self.plan)
        # Public source-read inventory helpers must not bypass the same gate.
        with self.assertRaisesRegex(ValueError,message):list(primitives(doc,self.binary))

    def test_exact_repro_empty_default_scene(self):
        self.reject(lambda d:d['scenes'][d['scene']].update(nodes=[]),'Scene has no root nodes')

    def test_exact_repro_removed_root_mesh(self):
        def mutate(d):
            roots=d['scenes'][d['scene']]['nodes']
            root=next(i for i in roots if 'mesh' in d['nodes'][i]);roots.remove(root)
        self.reject(mutate,'Orphan meshes')

    def test_exact_repro_one_byte_used_index_view(self):
        def mutate(d):
            p=d['meshes'][d['nodes'][d['scenes'][d['scene']]['nodes'][0]]['mesh']]['primitives'][0]
            d['bufferViews'][d['accessors'][p['indices']]['bufferView']]['byteLength']=1
        self.reject(mutate,'index accessor exceeds bufferView bytes')

class AdapterContract(unittest.TestCase):
    def test_related_reference_stride_index_and_finite_contracts(self):
        source,_,_=fixture();parsed=EmbeddedGlb(source)
        def index_overflow(d,b):
            a=d['accessors'][d['meshes'][0]['primitives'][0]['indices']];v=d['bufferViews'][a['bufferView']]
            struct.pack_into('<I',b,v['byteOffset'],4)
        def nonfinite(d,b):struct.pack_into('<f',b,0,float('nan'))
        cases=[
            ('node ref',lambda d,b:d['scenes'][0].update(nodes=[999]),'scene node index'),
            ('mesh ref',lambda d,b:d['nodes'][0].update(mesh=999),'node mesh index'),
            ('accessor ref',lambda d,b:d['meshes'][0]['primitives'][0]['attributes'].update(POSITION=999),'POSITION accessor index'),
            ('stride',lambda d,b:d['bufferViews'][0].update(byteStride=4),'alignment/stride'),
            ('index bounds',index_overflow,'Index exceeds'),
            ('cycle',lambda d,b:d['nodes'][0].update(children=[0]),'Cyclic or multiply-parented'),
            ('repeated node',lambda d,b:d['scenes'][0].update(nodes=[0,0]),'Cyclic or multiply-parented'),
            ('finite',nonfinite,'Nonfinite POSITION')]
        for name,mutate,message in cases:
            with self.subTest(name=name):
                doc=copy.deepcopy(parsed.doc);blob=bytearray(parsed.binary);mutate(doc,blob)
                with self.assertRaisesRegex(ValueError,message):glb_parts(glb(doc,bytes(blob)))
                with self.assertRaisesRegex(ValueError,message):access(doc,bytes(blob),0)

    def test_embedded_container_declared_length_and_chunk_bounds(self):
        source,_,_=fixture();parsed=EmbeddedGlb(source)
        # Encode without the fixture helper, which deliberately recomputes the
        # correct buffer length. The malformed declaration must survive packing.
        doc=copy.deepcopy(parsed.doc);doc['buffers'][0]['byteLength']+=4
        data=json.dumps(doc).encode();data+=b' '*(-len(data)%4);blob=parsed.binary
        raw=struct.pack('<III',0x46546c67,2,28+len(data)+len(blob))+struct.pack('<I4s',len(data),b'JSON')+data+struct.pack('<I4s',len(blob),b'BIN\0')+blob
        with self.assertRaisesRegex(ValueError,'BIN byteLength/padding mismatch'):gate(raw)
        with self.assertRaisesRegex(ValueError,'Malformed GLB header'):gate(source[:-1])

if __name__=='__main__':unittest.main()

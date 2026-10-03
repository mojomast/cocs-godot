"""Tiny in-memory serializer fixtures only; never build actual R6 assets."""
import collections
import json
import struct
import unittest
from unittest.mock import patch
import compose
from finish import access,glb_parts,sha,primitives
from verify import corners

def glb(doc,blob):
    doc['buffers']=[{'byteLength':len(blob)}]
    j=json.dumps(doc).encode();j+=b' '*(-len(j)%4);blob+=b'\0'*(-len(blob)%4)
    return struct.pack('<III',0x46546c67,2,28+len(j)+len(blob))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(blob),b'BIN\0')+blob

def fixture():
    blob=bytearray();views=[];acc=[]
    def stream(values,fmt,kind,component=5126):
        raw=b''.join(struct.pack('<'+fmt,*v) for v in values);views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(raw)});blob.extend(raw)
        acc.append({'bufferView':len(views)-1,'count':len(values),'componentType':component,'type':kind});return len(acc)-1
    attrs={'POSITION':stream([(0,0,0),(1,0,0),(0,1,0),(1,1,0)],'fff','VEC3'),
        'NORMAL':stream([(0,0,1)]*4,'fff','VEC3'),'TANGENT':stream([(1,0,0,1)]*4,'ffff','VEC4'),
        'TEXCOORD_0':stream([(0,0),(1,0),(0,1),(1,1)],'ff','VEC2')}
    indices=stream([(i,) for i in (0,1,2,1,3,2)],'I','SCALAR',5125)
    doc={'asset':{'version':'2.0'},'bufferViews':views,'accessors':acc,'nodes':[{'name':'fixture','mesh':0}],
        'meshes':[{'primitives':[{'attributes':attrs,'indices':indices,'material':0}]}],
        'materials':[{'name':'GM / orange','emissiveFactor':[.8,.19,.025]}],'images':[],'textures':[]}
    source=glb(doc,bytes(blob));library=glb({'asset':{'version':'2.0'},'materials':[{'name':'R6 / machine'}]},b'')
    plan={'sourceGLBSha256':sha(source),'geometryHash':'fixture-geometry','assignments':[{'node':'fixture','primitive':0,
        'roles':['GM / orange','R6 / machine'],'uvScale':{'GM / orange':1,'R6 / machine':.5}}]}
    return source,library,plan

class Composition(unittest.TestCase):
    def output(self):
        source,library,plan=fixture()
        with patch.object(compose,'GLB') as path:
            path.read_bytes.return_value=source
            result=compose.compose(plan,library)
        return glb_parts(source),glb_parts(result)

    def test_exact_oriented_geometry_and_basis_after_split(self):
        (old,before),(new,after)=self.output()
        def inventory(d,b):
            return collections.Counter(tuple(tuple(streams[k][i] for k in ('POSITION','NORMAL','TANGENT')) for i in f)
                for _,_,_,streams,faces in primitives(d,b) for f in faces)
        self.assertEqual(inventory(old,before),inventory(new,after))
        self.assertEqual(len(new['meshes'][0]['primitives']),2)
        self.assertEqual(new['materials'][0],old['materials'][0])

    def test_uv_scale_is_material_local(self):
        (_,before),(new,after)=self.output()
        for _,_,p,streams,faces in primitives(new,after):
            role=new['materials'][p['material']]['name'];scale=.5 if role=='R6 / machine' else 1
            self.assertEqual(streams['TEXCOORD_0'],[(0,0),(scale,0),(0,scale),(scale,scale)])
            self.assertEqual(streams['TANGENT'],[(1,0,0,1)]*4)

    def test_source_identity_and_coverage_fail_closed(self):
        source,library,plan=fixture()
        with patch.object(compose,'GLB') as path:
            path.read_bytes.return_value=source
            plan['sourceGLBSha256']='wrong'
            with self.assertRaises(AssertionError):compose.compose(plan,library)
            plan['sourceGLBSha256']=sha(source);plan['assignments'][0]['roles'].pop()
            with self.assertRaises(AssertionError):compose.compose(plan,library)

if __name__=='__main__':unittest.main()

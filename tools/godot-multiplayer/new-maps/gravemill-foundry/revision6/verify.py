"""Future actual-art verifier; source checks do not create a built receipt."""
import collections
import math
import struct
from finish import HERE, ROOT, R5, GLB, read, primitives, glb_parts, sha, access
from material_pack import load_pack, srgb_png, linear_rgba

def f32(x):return struct.unpack('<f',struct.pack('<f',x))[0]
def corners(streams, face, scale=1):
    return tuple((streams['POSITION'][i],streams['NORMAL'][i],streams['TANGENT'][i],tuple(f32(x*scale) for x in streams['TEXCOORD_0'][i])) for i in face)

def planned_inventory(plan):
    doc,blob=glb_parts(GLB.read_bytes());inventory=collections.Counter()
    for (node,pi,p,streams,faces),row in zip(primitives(doc,blob),plan['assignments']):
        assert node['name']==row['node'] and pi==row['primitive'] and len(faces)==len(row['roles'])
        for face,role in zip(faces,row['roles']):
            inventory[(role,corners(streams,face,row['uvScale'][role]))]+=1
    return inventory

def verify(raw,plan):
    doc,blob=glb_parts(raw);old,_=glb_parts(GLB.read_bytes());got=collections.Counter();batches=0
    for node,pi,p,streams,faces in primitives(doc,blob):
        batches+=1;role=doc['materials'][p['material']]['name']
        for face in faces:got[(role,corners(streams,face))]+=1
    assert got==planned_inventory(plan),'Position/oriented triangle/normal/tangent/UV/material coverage changed'
    assert batches==plan['plannedPrimitives']
    orange=lambda d:next(m for m in d['materials'] if m['name']=='GM / orange')
    assert orange(doc)==orange(old),'Exact accepted luminaire fields changed'
    assert doc['materials'][:len(old['materials'])]==old['materials'],'Retained R5 materials changed'
    assert doc['asset']['extras']['geometryHash']==plan['geometryHash']
    resources,_=load_pack(ROOT);bindings=read(HERE/'bindings.json')
    def image(slot):
        im=doc['images'][doc['textures'][slot['index']]['source']];v=doc['bufferViews'][im['bufferView']];o=v.get('byteOffset',0)
        return blob[o:o+v['byteLength']]
    checked=[]
    for mat in doc['materials']:
        if mat['name'] not in bindings:continue
        b=bindings[mat['name']];channels=resources[b['resource']]['channels'];pbr=mat['pbrMetallicRoughness']
        assert abs(pbr.get('metallicFactor',1)-b['metallic'])<1e-6
        assert image(pbr['baseColorTexture'])==srgb_png(channels['albedo']['path'].read_bytes())
        assert sha(image(mat['normalTexture']))==channels['normal']['sha256']
        assert abs(mat['normalTexture'].get('scale',1)-b['normalStrength'])<1e-6
        w,h,src=linear_rgba(channels['roughness']['path'].read_bytes());ew,eh,dst=linear_rgba(image(pbr['metallicRoughnessTexture']))
        assert (w,h)==(ew,eh) and max(abs(src[i]-dst[i+1]) for i in range(0,len(src),4))<=1
        checked.append(mat['name'])
    assert set(checked)==set(bindings)
    return {'visualRevision':6,'artHash':sha(raw),'geometryHash':plan['geometryHash'],'triangles':sum(got.values()),'primitives':batches,
        'bytes':len(raw),'exactR5PositionsNormalsTangentsAndOrientedTriangleMultiplicity':True,'plannedUniformUVScaling':True,
        'preservedOrangeExact':True,'newMaterialsPixelChecked':checked,'nativeVisualAcceptance':'pending'}

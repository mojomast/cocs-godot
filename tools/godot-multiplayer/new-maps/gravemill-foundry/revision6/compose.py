"""Lossless geometry composition: re-batch R5 indices, copy its vertex streams.

Called only during the future authorized build. Material-library GLB is produced
by Blender from the same editable R6 master. No geometry from that intermediate
export is used: normals/tangents/positions remain exact R5 float32 bytes.
"""
import collections
import copy
import json
import struct
from finish import GLB, glb_parts, primitives, sha
from glb_contract import EmbeddedGlb, gate

def compose(plan, library):
    raw=GLB.read_bytes();doc,source=glb_parts(raw)
    assert sha(raw)==plan['sourceGLBSha256']
    doc=copy.deepcopy(doc);blob=bytearray(source)
    material_library=EmbeddedGlb(library)
    lib,libblob=material_library.doc,material_library.binary
    def view(data, target=None):
        blob.extend(b'\0'*(-len(blob)%4));v={'buffer':0,'byteOffset':len(blob),'byteLength':len(data)}
        if target: v['target']=target
        blob.extend(data);doc['bufferViews'].append(v);return len(doc['bufferViews'])-1
    def accessor(values, kind, fmt, target):
        data=b''.join(struct.pack('<'+fmt,*v) for v in values)
        a={'bufferView':view(data,target),'componentType':5126 if fmt[0]=='f' else 5125,'count':len(values),'type':kind}
        doc['accessors'].append(a);return len(doc['accessors'])-1
    sam_offset=len(doc.get('samplers',[]))
    doc.setdefault('samplers',[]).extend(copy.deepcopy(lib.get('samplers',[])))
    image_ids={}
    for i,image in enumerate(doc.get('images',[])):
        v=doc['bufferViews'][image['bufferView']];off=v.get('byteOffset',0)
        image_ids[sha(blob[off:off+v['byteLength']])]=i
    texture_ids={}
    def texture(index):
        if index in texture_ids:return texture_ids[index]
        tex=copy.deepcopy(lib['textures'][index]);image=lib['images'][tex['source']]
        v=lib['bufferViews'][image['bufferView']];off=v.get('byteOffset',0);data=libblob[off:off+v['byteLength']];digest=sha(data)
        if digest not in image_ids:
            new=copy.deepcopy(image);new['bufferView']=view(data);image_ids[digest]=len(doc['images']);doc['images'].append(new)
        tex['source']=image_ids[digest]
        if 'sampler' in tex:tex['sampler']+=sam_offset
        texture_ids[index]=len(doc['textures']);doc['textures'].append(tex)
        return texture_ids[index]
    material_ids={m['name']:i for i,m in enumerate(doc['materials'])}
    for mat in lib['materials']:
        if not mat['name'].startswith('R6 / '):continue
        new=copy.deepcopy(mat)
        def remap(obj):
            if isinstance(obj,dict):
                for k,v in obj.items():
                    if k.endswith('Texture') and isinstance(v,dict):v['index']=texture(v['index'])
                    else:remap(v)
            elif isinstance(obj,list):
                for v in obj:remap(v)
        remap(new);material_ids[new['name']]=len(doc['materials']);doc['materials'].append(new)
    for field in ('extensionsUsed','extensionsRequired'):
        if field in lib:doc[field]=sorted(set(doc.get(field,[])+lib[field]))
    rows={(r['node'],r['primitive']):r for r in plan['assignments']}
    original,source=glb_parts(raw)
    for node,pi,p,streams,faces in primitives(original,source):
        row=rows[node['name'],pi];groups=collections.defaultdict(list)
        assert len(faces)==len(row['roles'])
        for face,role in zip(faces,row['roles']):groups[role].extend(face)
        # R5 currently has one primitive per node. Fail rather than overwrite
        # silently if its immutable baseline contract ever changes.
        assert pi==0 and len(original['meshes'][node['mesh']]['primitives'])==1
        output=[]
        for role,indices in sorted(groups.items()):
            new=copy.deepcopy(p);new['material']=material_ids[role]
            new['indices']=accessor([(i,) for i in indices],'SCALAR','I',34963)
            scale=row['uvScale'][role]
            if scale!=1:
                new['attributes']['TEXCOORD_0']=accessor([(u*scale,v*scale) for u,v in streams['TEXCOORD_0']],'VEC2','ff',34962)
            output.append(new)
        doc['meshes'][node['mesh']]['primitives']=output
    for node in doc['nodes']:
        node.setdefault('extras',{}).update({'visualRevision':6,'sourceVisualRevision':5,'geometryHash':plan['geometryHash']})
    doc['asset'].setdefault('extras',{}).update({'visualRevision':6,'sourceGLBSha256':plan['sourceGLBSha256'],
        'geometryHash':plan['geometryHash'],'finishPlanSha256':sha(json.dumps(plan,sort_keys=True).encode()),'acceptance':'pending native visual review'})
    doc['buffers']=[{'byteLength':len(blob)}]
    header=json.dumps(doc,separators=(',',':')).encode();header+=b' '*(-len(header)%4);blob.extend(b'\0'*(-len(blob)%4))
    result=struct.pack('<III',0x46546c67,2,28+len(header)+len(blob))+struct.pack('<I4s',len(header),b'JSON')+header+struct.pack('<I4s',len(blob),b'BIN\0')+blob
    gate(result)  # Actual composed bytes must satisfy the same pre-inventory gate.
    return result

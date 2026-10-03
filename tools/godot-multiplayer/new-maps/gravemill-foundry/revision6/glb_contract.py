"""Foundry's narrow static producer gate over the shared embedded GLB validator."""
import json
from pathlib import Path
import struct
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from map_variety.glb_geometry import EmbeddedGlb, item

FIELDS={'POSITION':'VEC3','NORMAL':'VEC3','TANGENT':'VEC4','TEXCOORD_0':'VEC2'}

def gate(raw):
    glb=EmbeddedGlb(raw)
    parts,_,_=glb.geometry()  # Container, active scene, references, backing, finite streams.
    doc=glb.doc
    # R5/R6 streams are already in world coordinates; Foundry does not evaluate
    # node transforms. Require every exported node in the active scene so an
    # unreachable node cannot conceal invalid refs/cycles or a second instance.
    pending=list(reversed(doc['scenes'][doc['scene']]['nodes']));order=[]
    while pending:
        index=pending.pop();node=doc['nodes'][index];order.append(index)
        if any(k in node for k in ('matrix','translation','rotation','scale')):
            raise ValueError('Foundry requires baked node transforms')
        pending.extend(reversed(node.get('children',[])))
    if set(order)!=set(range(len(doc['nodes']))):raise ValueError('Foundry orphan nodes outside default scene')
    # Composition retains some unused source accessors; validate their backing
    # too. Reuse accessor() rather than maintaining a second bounds decoder.
    for index,a in enumerate(doc['accessors']):
        if not isinstance(a,dict):raise ValueError('Invalid Foundry accessor entry')
        shape=a.get('type')
        if shape not in ('SCALAR','VEC2','VEC3','VEC4'):raise ValueError('Unsupported Foundry accessor shape')
        glb.accessor(index,shape,(5121,5123,5125) if shape=='SCALAR' else (5126,),
                     'index' if shape=='SCALAR' else 'Foundry stream')
    for p in parts:
        if set(p['attributes'])!=set(FIELDS) or 'indices' not in p:
            raise ValueError('Foundry requires indexed POSITION/NORMAL/TANGENT/TEXCOORD_0')
    glb.foundry_node_order=order
    return glb

def parts(raw):
    glb=gate(raw)
    return glb.doc,glb.binary

def from_parts(doc,blob):
    # Revalidate callers' mutable dictionaries, not an identity-based cache.
    data=json.dumps(doc,separators=(',',':')).encode();data+=b' '*(-len(data)%4)
    return gate(struct.pack('<III',0x46546c67,2,28+len(data)+len(blob))+
        struct.pack('<I4s',len(data),b'JSON')+data+struct.pack('<I4s',len(blob),b'BIN\0')+blob)

def values(glb,index):
    a=item(glb.doc.get('accessors'),index,'Foundry accessor index');shape=a.get('type')
    if shape not in ('SCALAR','VEC2','VEC3','VEC4'):raise ValueError('Unsupported Foundry accessor shape')
    _,count,layout=glb.accessor(index,shape,(5121,5123,5125) if shape=='SCALAR' else (5126,),
        'index' if shape=='SCALAR' else 'Foundry stream')
    return list(glb.values(count,layout))

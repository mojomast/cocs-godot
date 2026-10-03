"""Seven-entry Foundry tangent successor. No engine imports or artifact writes."""
import collections
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
R6=HERE.parent/'revision6'
sys.path.insert(0,str(R6))
from glb_contract import gate, values

SOURCE=ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb'
SOURCE_SHA='945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c'
AUTHORITY='61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879'
EXPECTED={(48,3244),(53,5151),(53,5186),(53,5155),(53,5207),(53,5242),(53,5211)}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):return math.sqrt(dot(a,a))
def unit(a):
    size=norm(a)
    if not math.isfinite(size) or size<=1e-20:raise ValueError('Undefined direction')
    return mul(a,1/size)
def projected(t,n):return unit(sub(t,mul(n,dot(n,t))))
def rows(glb):
    for ni in glb.foundry_node_order:
        node=glb.doc['nodes'][ni]
        if 'mesh' not in node:continue
        for pi,p in enumerate(glb.doc['meshes'][node['mesh']]['primitives']):
            streams={k:values(glb,v) for k,v in p['attributes'].items()}
            indices=[v[0] for v in values(glb,p['indices'])]
            yield node,pi,p,streams,[indices[i:i+3] for i in range(0,len(indices),3)]

def basis(points,uv,normal,corner):
    e1,e2=sub(points[1],points[0]),sub(points[2],points[0])
    u1,u2=sub(uv[1],uv[0]),sub(uv[2],uv[0]);det=u1[0]*u2[1]-u1[1]*u2[0]
    area=norm(cross(e1,e2))/2
    if area<=1e-12 or abs(det)<=1e-15:raise ValueError('Degenerate geometry or UV Jacobian')
    t=mul(sub(mul(e1,u2[1]),mul(e2,u1[1])),1/det)
    b=mul(sub(mul(e2,u1[0]),mul(e1,u2[0])),1/det)
    n=unit(normal);pt=projected(t,n)
    hand=dot(cross(n,pt),b)
    if abs(hand)<=1e-15:raise ValueError('Undefined UV handedness')
    a=sub(points[(corner+1)%3],points[corner]);c=sub(points[(corner+2)%3],points[corner])
    angle=math.atan2(norm(cross(a,c)),dot(a,c))
    if angle<=0:raise ValueError('Zero corner angle')
    return {'t':unit(t),'b':unit(b),'projected':pt,'sign':1.0 if hand>0 else -1.0,
            'weight':angle,'area':area,'uvJacobian':det,'normal':n}

def solve(incidents):
    """Mikk-style corner-angle accumulation; seam conflicts fail closed.

    This is not a general MikkTSpace replacement. Only an existing exported
    vertex with agreeing incident bases is admissible; splitting requires a
    separately reviewed contract. Never select one arbitrary incident face.
    """
    if not incidents:raise ValueError('No incident corners')
    first=incidents[0];n=first['normal']
    if any(norm(sub(i['normal'],n))>1e-7 or i['sign']!=first['sign'] for i in incidents):
        raise ValueError('Ambiguous shared tangent: normals or UV handedness conflict; split required')
    t=projected(tuple(sum(i['t'][k]*i['weight'] for i in incidents) for k in range(3)),n)
    b=tuple(sum(i['b'][k]*i['weight'] for i in incidents) for k in range(3))
    if any(dot(t,i['projected'])<1-1e-8 for i in incidents):
        raise ValueError('Ambiguous shared tangent directions; split required')
    sign=1.0 if dot(cross(n,t),b)>0 else -1.0
    if sign!=first['sign']:raise ValueError('Accumulated handedness conflict')
    result=struct.unpack('<4f',struct.pack('<4f',*t,sign))
    if abs(norm(result[:3])-1)>1e-6 or abs(dot(result[:3],n))>1e-6:raise ValueError('Invalid repaired basis')
    return result

def inventory(glb,expected):
    bad=collections.defaultdict(list)
    for node,pi,p,s,faces in rows(glb):
        for fi,face in enumerate(faces):
            for ci,vertex in enumerate(face):
                tangent=s['TANGENT'][vertex];identity=(p['attributes']['TANGENT'],vertex)
                if norm(tangent[:3])>=.5:continue
                if tangent[:3]!=(0.0,0.0,0.0):raise ValueError('Unknown nonzero invalid tangent')
                points=[s['POSITION'][i] for i in face];uv=[s['TEXCOORD_0'][i] for i in face]
                derived=basis(points,uv,s['NORMAL'][vertex],ci)
                bad[identity].append({'node':node['name'],'primitive':pi,'face':fi,'corner':ci,
                    'indices':face,'material':glb.doc['materials'][p['material']]['name'],
                    'position':s['POSITION'][vertex],'normal':s['NORMAL'][vertex],'uv':s['TEXCOORD_0'][vertex],
                    'trianglePositions':points,'triangleUV':uv,'sourceTangent':tangent,'basis':derived})
    if set(bad)!=set(expected):raise ValueError('Invalid tangent entry inventory differs from pinned set')
    return bad

def encode(doc,blob):
    header=json.dumps(doc,separators=(',',':')).encode();header+=b' '*(-len(header)%4)
    return struct.pack('<III',0x46546c67,2,28+len(header)+len(blob))+struct.pack('<I4s',len(header),b'JSON')+header+struct.pack('<I4s',len(blob),b'BIN\0')+bytes(blob)

def successor_doc(source):
    doc=copy.deepcopy(source)
    doc['asset'].setdefault('extras',{}).update({'visualRevision':7,'tangentSuccessorOf':SOURCE_SHA,'tangentPolicy':'Only seven pinned invalid tangent entries repaired; all other streams/materials unchanged'})
    for node in doc['nodes']:node.setdefault('extras',{}).update({'visualRevision':7})
    return doc

def repair(raw,*,source_sha=SOURCE_SHA,expected=EXPECTED):
    if sha(raw)!=source_sha:raise ValueError('Source artifact identity mismatch')
    source=gate(raw);bad=inventory(source,expected);blob=bytearray(source.binary);changes=[];used=set()
    for (accessor,vertex),incidents in sorted(bad.items()):
        _,_,layout=source.accessor(accessor,'VEC4',(5126,),'TANGENT')
        offset=layout[0]+vertex*layout[1]
        if set(range(offset,offset+16)) & used:raise ValueError('Aliased repair storage')
        used.update(range(offset,offset+16));tangent=solve([i['basis'] for i in incidents])
        struct.pack_into('<4f',blob,offset,*tangent)
        changes.append({'accessor':accessor,'vertex':vertex,'binOffset':offset,'tangent':tangent,'incidents':incidents})
    result=encode(successor_doc(source.doc),blob);gate(result)
    return result,changes

def verify(raw,output,*,source_sha=SOURCE_SHA,expected=EXPECTED):
    # Exact whole-BIN comparison enforces byte identity for all valid tangents,
    # positions, normals, UVs, indices, images and even unused stream backing.
    canonical,changes=repair(raw,source_sha=source_sha,expected=expected)
    want=gate(canonical);actual=gate(output)
    if actual.doc!=want.doc or actual.binary!=want.binary:raise ValueError('Unexpected successor bytes outside deterministic seven-entry repair')
    for node,pi,p,s,faces in rows(actual):
        for face in faces:
            for ci,v in enumerate(face):
                if norm(s['TANGENT'][v][:3])<.5:raise ValueError('Invalid tangent survived')
                if (p['attributes']['TANGENT'],v) not in expected:continue
                b=basis([s['POSITION'][i] for i in face],[s['TEXCOORD_0'][i] for i in face],s['NORMAL'][v],ci)
                t=s['TANGENT'][v]
                if abs(norm(t[:3])-1)>1e-6 or abs(dot(unit(s['NORMAL'][v]),t[:3]))>1e-6 or dot(unit(t[:3]),b['projected'])<1-1e-8 or t[3]!=b['sign']:
                    raise ValueError('Repaired corner fails UV basis check')
    parts,triangles,_=actual.geometry()
    return {'visualRevision':7,'artHash':None,'scope':'In-memory/source verification until authorized production writes an actual artifact',
        'triangles':triangles,'primitives':len(parts),'repairedEntries':len(changes),'changes':changes,
        'allOtherBinaryBytesIdentical':True,'materialsAndImagesIdentical':True,'vertexSplits':0,'geometryHash':AUTHORITY}

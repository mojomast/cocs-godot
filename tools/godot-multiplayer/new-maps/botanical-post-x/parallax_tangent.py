"""Pinned in-memory localized tangent proposal. Never writes a GLB/master.

Three corners share one nondegenerate indexed face and no other incidents.
Repairing only the zero corner would leave opposite-handed neighboring bases.
"""
import struct
import sys
from fixture_inputs import HERE,X_PINS,x_bytes,sha,write
sys.path.insert(0,str(HERE.parent/'map_variety'))
from glb_geometry import EmbeddedGlb
from uv_basis import basis,solve,norm,dot,cross
PATH=next(p for p in X_PINS if p.endswith('parallax-observatory.glb'))
EXPECTED={24049:(0.,0.,0.,1.),24050:(1.,0.,0.,1.),24051:(1.,0.,0.,1.)}

def plan(raw):
    if sha(raw)!=X_PINS[PATH]:raise ValueError('Exact X Parallax export required')
    g=EmbeddedGlb(raw);mesh=g.doc['meshes'][9];p=mesh['primitives'][0]
    if mesh['name']!='art.accepted-craft.saltstone.001' or p['attributes']['TANGENT']!=48:raise ValueError('Primitive identity drift')
    if g.doc['materials'][p['material']]['name']!='saltstone' or not g.doc['materials'][p['material']].get('normalTexture'):raise ValueError('Normal-mapped material identity drift')
    normal_texture=g.doc['materials'][p['material']]['normalTexture']
    if normal_texture.get('texCoord',0)!=0 or normal_texture.get('extensions'):raise ValueError('Normal UV channel/transform needs separate derivation')
    nodes=[n for n in g.doc['nodes'] if n.get('mesh')==9]
    if len(nodes)!=1 or any(k in nodes[0] for k in ['matrix','rotation','scale','translation']):raise ValueError('Unexpected basis node transform')
    consumers=[(mi,pi) for mi,m in enumerate(g.doc['meshes']) for pi,primitive in enumerate(m['primitives']) if primitive['attributes'].get('TANGENT')==48]
    if consumers!=[(9,0)]:raise ValueError('Tangent accessor has additional primitive consumers')
    def values(key,shape):
        _,n,layout=g.accessor(p['attributes'][key],shape,[5126],key)
        return list(g.values(n,layout))
    positions=values('POSITION','VEC3');uv=values('TEXCOORD_0','VEC2');normals=values('NORMAL','VEC3');tangents=values('TANGENT','VEC4')
    _,n,layout=g.accessor(p['indices'],'SCALAR',[5121,5123,5125],'index');indices=[v[0] for v in g.values(n,layout)]
    faces=[indices[i:i+3] for i in range(0,len(indices),3)];face=faces[11823]
    if face!=list(EXPECTED):raise ValueError('Incident index drift')
    if [positions[i] for i in face][0]!=(68.77897644042969,24.,-66.25537872314453):raise ValueError('Position drift')
    changes=[];blob=bytearray(g.binary);allowed=set()
    _,_,tl=g.accessor(48,'VEC4',[5126],'TANGENT')
    for corner,vertex in enumerate(face):
        incidents=[j for j,f in enumerate(faces) if vertex in f]
        if incidents!=[11823] or tangents[vertex]!=EXPECTED[vertex]:raise ValueError('Shared neighbor or source basis drift')
        b=basis([positions[i] for i in face],[uv[i] for i in face],normals[vertex],corner)
        tangent=solve([b]);offset=tl[0]+vertex*tl[1]
        if allowed.intersection(range(offset,offset+16)):raise ValueError('Aliased storage')
        allowed.update(range(offset,offset+16));struct.pack_into('<4f',blob,offset,*tangent)
        changes.append({'accessor':48,'vertex':vertex,'binOffset':offset,'incidentTriangles':incidents,
            'before':tangents[vertex],'proposed':tangent,'basis':b,
            'reason':'zero tangent' if norm(tangents[vertex][:3])==0 else 'valid direction but W disagrees with the actual exported UV derivative'})
    changed={i for i,(a,b) in enumerate(zip(g.binary,blob)) if a!=b}
    if not changed<=allowed:raise ValueError('Unexpected binary change')
    # Whole-BIN equality outside the local entries plus alias checks protect
    # all other streams and images, even if malformed storage shared the range.
    for ai,accessor in enumerate(g.doc['accessors']):
        if ai==48:continue
        _,count,layout=g.accessor(ai,accessor['type'],[5121,5123,5125,5126],'unmodified-stream')
        start,stride,fmt=layout;size=struct.calcsize(fmt)
        if any(0<=off-start and (off-start)//stride<count and (off-start)%stride<size for off in changed):raise ValueError('Repair aliases another accessor')
    for image in g.doc['images']:
        view=g.doc['bufferViews'][image['bufferView']];start,length=g._view(view)
        if bytes(blob[start:start+length])!=g.binary[start:start+length]:raise ValueError('Repair aliases embedded image')
    for change in changes:
        t=struct.unpack_from('<4f',blob,change['binOffset']);b=change['basis']
        if abs(norm(t[:3])-1)>1e-6 or abs(dot(t[:3],b['normal']))>1e-6 or t[3]!=b['sign']:raise ValueError('Proposal basis invalid')
        if dot(tuple(x*t[3] for x in cross(b['normal'],t[:3])),b['b'])<1-1e-8:raise ValueError('UV bitangent reconstruction invalid')
    return {'scope':'in-memory source qualification only; no artifact written or native basis proved','sourceGlbSha256':sha(raw),
        'artifactSha256':None,'proposedVisualRevision':'parallax-tangent-local-v1','geometryHashUnchanged':True,
        'material':'saltstone','normalTexture':normal_texture,'identityTransformNode':nodes[0]['name'],
        'mesh':mesh['name'],'primitive':0,'primitiveLocalTriangle':11823,'indices':face,
        'positions':[positions[i] for i in face],'normals':[normals[i] for i in face],'uv':[uv[i] for i in face],
        'changes':changes,'changedBinaryByteOffsets':sorted(changed),'allowedTangentBytes':len(allowed),
        'allOtherBinaryBytesIdentical':True,'materialsImagesPositionsNormalsUVIndicesUnchanged':True,
        'nativeBasisStatus':'unproven; ensure_tangents and array presence are not per-corner basis proof',
        'recommendation':'Review this three-corner local proposal; do not blindly copy neighboring +1 handedness into the zero corner'}
if __name__=='__main__':
    result=plan(x_bytes(PATH));write(HERE/'parallax-tangent-evidence-v2.json',result)
    print('One face, three local corners: UV-derived tangent [1,0,0,-1]; no output artifact')

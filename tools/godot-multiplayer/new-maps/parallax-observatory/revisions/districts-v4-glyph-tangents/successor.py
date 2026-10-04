"""AA + exactly sixteen reviewed rank-one glyph tangents; in-memory compiler."""
import copy
import json
from dependencies import *

def compile_art(raw):
    if sha(raw)!=AA_SHA:raise ValueError('Exact approved AA input required')
    imagined,policy=approved_policy.propose(raw)
    g=aa.EmbeddedGlb(imagined);doc=copy.deepcopy(g.doc)
    doc['asset'].setdefault('extras',{}).update(visualRevision=REVISION,tangentPredecessorSha256=AA_SHA,glyphTangentPolicy=POLICY)
    for node in doc['nodes']:node.setdefault('extras',{})['visualRevision']=REVISION
    result=aa.encode(doc,g.binary);aa.EmbeddedGlb(result).geometry()
    return result,policy['records']

def verify_art(raw,result):
    expected,records=compile_art(raw)
    actual=aa.EmbeddedGlb(result);parts,count,_=actual.geometry()
    if result!=expected:raise ValueError('Output is not the deterministic sixteen-entry successor')
    before=aa.EmbeddedGlb(raw)
    allowed={i for r in records for i in range(r['binOffset'],r['binOffset']+16)}
    changed={i for i,(a,b) in enumerate(zip(before.binary,actual.binary)) if a!=b}
    if len(changed)!=64 or len(allowed)!=256 or not changed<=allowed:raise ValueError('AA BIN boundary changed')
    x=aa.EmbeddedGlb(aa.pinned());_,_,layout=x.accessor(48,'VEC4',(5126,),'TANGENT')
    combined=allowed|{i for v in aa.VERTICES for i in range(layout[0]+v*layout[1],layout[0]+v*layout[1]+16)}
    delta={i for i,(a,b) in enumerate(zip(x.binary,actual.binary)) if a!=b}
    if len(delta)!=69 or len(combined)!=304 or not delta<=combined:raise ValueError('Original X nineteen-entry boundary changed')
    _,inventory,_=census.source_faces(actual)
    inv=inventory['uniqueVertexRecords']
    if inv['parallelNT'] or inv['zeroT'] or inv['nonunitT'] or inv['nonorthogonalNT']!=4729:raise ValueError('Successor basis inventory differs from reviewed bounded scope')
    if count!=155553 or len(parts)!=39:raise ValueError('Geometry inventory changed')
    return {'visualRevision':REVISION,'actualArtHash':None,'geometryHash':aa.GEOMETRY,'triangles':count,'primitives':len(parts),
        'AAChangedBINBytes':64,'AAPermittedPositions':256,'XChangedBINBytes':69,'XPermittedPositions':304,
        'glyphRecords':records,'zeroTangents':0,'fullyParallelNT':0,'remainingNonorthogonalEntries':4729,
        'scope':'Deterministic source/in-memory contract; faithful import does not establish universal UV basis or final art acceptance'}

def audit_editable(raw,baseline):
    """AA-pinned version of the frozen complete world P/N/UV/material audit."""
    if sha(baseline)!=AA_SHA:raise ValueError('Editable audit requires pinned AA')
    old,new=aa.EmbeddedGlb(baseline),aa.EmbeddedGlb(raw)
    old_nodes={n['name']:n for n in old.doc['nodes']};new_nodes={n['name']:n for n in new.doc['nodes']}
    if set(old_nodes)!=set(new_nodes):raise ValueError('Editable node identity changed')
    for name,node in old_nodes.items():
        other=new_nodes[name]
        for field,default in (('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])):
            if any(abs(a-b)>1e-6 for a,b in zip(node.get(field,default),other.get(field,default))):raise ValueError('Editable original leaf TRS changed')
    aa.source_face(old)
    a=census.C.defaultdict(list);b=census.C.defaultdict(list)
    for key,cs in aa_editable.faces(old):a[key].append(cs)
    for key,cs in aa_editable.faces(new):b[key].append(cs)
    if set(a)!=set(b):raise ValueError('Editable world geometry/material role changed')
    maximum=[0.,0.,0.];count=0
    def errors(x,y):return [max(abs(u-v) for c,d in zip(x,y) for u,v in zip(c[j],d[j])) for j in range(3)]
    for key,rows in a.items():
        other=b[key]
        pairs=census.maximum_matching(rows,other,lambda x,y:all(e<=t for e,t in zip(errors(x,y),(1e-5,1e-4,1e-5))))
        if len(rows)!=len(other) or len(pairs)!=len(rows):raise ValueError('Editable P/N/UV/oriented multiplicity drift')
        count+=len(rows)
        for i,j in pairs:maximum=[max(u,v) for u,v in zip(maximum,errors(rows[i],other[j]))]
    if count!=155553:raise ValueError('Editable face inventory changed')
    aa_editable.compare_materials(old,new)
    return {'triangles':count,'maxWorldPositionNormalUVError':maximum,'materialPixelsSamplersPBREmissionEquivalent':True,'flatRoots':39}

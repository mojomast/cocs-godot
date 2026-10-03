"""Unapproved 16-entry degenerate-UV policy experiment; GLB bytes stay in memory."""
from census import *

EXPECTED={(a,v) for a in (165,170) for v in (1026,1027,1038,1039,1050,1051,1062,1063)}
def rank_one_basis(cs,corner):
    """Explicit new policy, not a claimed unique Mikk/UV solution.

    Tangent follows the geometric edge with zero UV change (glyph extrusion).
    Its orientation retains w=-1 and aligns B with observable increasing V.
    Reject disagreement, a full-rank UV map, or missing/ambiguous extrusion.
    """
    d=derivative(cs)
    if d['defined'] or d['area']<=1e-12 or d['uvJacobian']!=0:raise ValueError('Not rank-one UV geometry')
    n=cs[corner]['N'];w=cs[corner]['T'][3];axes=[];v_edges=[]
    for i,j in ((0,1),(1,2),(2,0)):
        p=sub(cs[j]['P'],cs[i]['P']);uv=sub(cs[j]['UV'],cs[i]['UV'])
        if uv==(0.,0.) and norm(p)>0:axes.append(unit(p))
        elif uv[1]!=0:v_edges.append(tuple(x/uv[1] for x in p))
    if not axes or not v_edges:raise ValueError('No observable extrusion/V direction')
    t=axes[0]
    if abs(dot(n,t))>1e-7 or any(abs(dot(t,a))<1-1e-8 for a in axes):raise ValueError('Conflicting extrusion direction')
    b=tuple(x*w for x in cross(n,t));alignment=[dot(b,v) for v in v_edges]
    if all(v<0 for v in alignment):t=tuple(-v for v in t)
    elif not all(v>0 for v in alignment):raise ValueError('Conflicting observable V orientation')
    return (*(0. if v==0 else v for v in t),w)

def simulate_surface_sign(n,t):
    # SurfaceTool::_create_list then commit_to_arrays. Exact zero cross yields
    # d=0 and the d<0 ? -1 : +1 branch, regardless of the stored input sign.
    b=tuple(x*t[3] for x in unit(cross(n,t[:3])))
    return -1. if dot(b,cross(n,t[:3]))<0 else 1.

def propose(raw):
    if sha(raw)!=ART_SHA:raise ValueError('Pinned AA artifact required')
    g=EmbeddedGlb(raw);_,inventory,faces=source_faces(g)
    bad={(r['accessor'],r['vertex']) for r in inventory['badVertexRecords'] if 'parallelNT' in r['flags']}
    if bad!=EXPECTED:raise ValueError('Pinned 16-entry inventory changed')
    incidents=C.defaultdict(list)
    for f in faces:
        for ci,c in enumerate(f['corners']):
            k=(f['accessor'],c['vertex'])
            if k in bad:incidents[k].append((f,ci))
    blob=bytearray(g.binary);allowed=set();rows=[]
    for k,items in sorted(incidents.items()):
        candidates=[rank_one_basis(f['corners'],ci) for f,ci in items]
        if len(set(candidates))!=1:raise ValueError('All-incident rank-one basis conflict')
        t=candidates[0];c=items[0][0]['corners'][items[0][1]]
        assert simulate_surface_sign(c['N'],c['T'])==1 and simulate_surface_sign(c['N'],t)==-1
        assert norm(t[:3])==1 and dot(c['N'],t[:3])==0
        _,_,layout=g.accessor(k[0],'VEC4',(5126,),'TANGENT');offset=layout[0]+k[1]*layout[1]
        allowed.update(range(offset,offset+16));struct.pack_into('<4f',blob,offset,*t)
        rows.append({'accessor':k[0],'vertex':k[1],'old':c['T'],'N':c['N'],'proposed':t,'binOffset':offset,
            'incidents':[{'node':f['node'],'mesh':f['mesh'],'primitive':f['primitive'],'face':f['face'],'corner':f['corners'][ci]['corner'],'area':f['derivative']['area'],'uvJacobian':f['derivative']['uvJacobian']} for f,ci in items]})
    changed={i for i,(a,b) in enumerate(zip(g.binary,blob)) if a!=b};assert changed<=allowed
    # Validate hypothetical output's actual container/accessor/scene backing,
    # without emitting an artifact or changing the approved 3-corner compiler.
    from contract import encode
    imagined=encode(g.doc,blob);check=EmbeddedGlb(imagined);check.geometry()
    _,after,_=source_faces(check);assert after['uniqueVertexRecords'].get('parallelNT',0)==0
    return imagined,{'status':'UNAPPROVED policy proposal only; no actual artifact/master/native output',
        'sourceAAHash':ART_SHA,'actualSuccessorHash':None,'grant':None,'autoStart':False,'records':rows,
        'changedBINBytes':len(changed),'permittedBINPositions':len(allowed),'outsideBINRecordsExact':True,
        'normalUVIndexMaterialAndJSONUnchanged':True,'predictedSurfaceToolSignsAllMinusOne':True,
        'limitations':'Rank-one UVs cannot define unique dP/du. This extrusion-aligned fallback is an explicit new shading policy requiring approval and fresh native proof; not a waiver or a sign-only patch.'}

if __name__=='__main__':
    _,report=propose((NATIVE/'candidate.glb').read_bytes())
    (HERE/'proposal.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='records'},indent=2))

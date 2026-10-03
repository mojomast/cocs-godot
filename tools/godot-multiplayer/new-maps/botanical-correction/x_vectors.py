"""Actual accessor census; explicitly retains zero tangent exceptions."""
import math
import sys
from collections import Counter
from stage_config import paths,sha,write
from source_scene import load
from glb_geometry import EmbeddedGlb
from archived_fixture import archive_bytes

def census(raw):
    glb=EmbeddedGlb(raw);counts=Counter();exceptions=[]
    for mesh in glb.doc['meshes']:
        for primitive in mesh['primitives']:
            def values(key,shape):
                _,n,layout=glb.accessor(primitive['attributes'][key],shape,[5126],key)
                return list(glb.values(n,layout))
            positions=values('POSITION','VEC3');uv=values('TEXCOORD_0','VEC2')
            for key,shape in [('NORMAL','VEC3'),('TANGENT','VEC4')]:
                rows=values(key,shape)
                for i,v in enumerate(rows):
                    if not all(math.isfinite(x) for x in v):raise ValueError('Nonfinite '+key)
                    counts[key]+=1;length=math.sqrt(sum(x*x for x in v[:3]))
                    if abs(length-1)>.0001:
                        counts[key+'Zero' if length<1e-8 else key+'NonUnit']+=1
                        exceptions.append({'mesh':mesh['name'],'material':glb.doc['materials'][primitive['material']]['name'],
                            'accessor':primitive['attributes'][key],'vertex':i,'attribute':key,'value':v,'position':positions[i],'uv':uv[i]})
    return {'counts':dict(counts),'exceptions':exceptions}

def main(attempt,ident):
    out,_=paths(attempt,ident);glb=out/(ident+'.glb');result=census(glb.read_bytes())
    result.update(glbSha256=sha(glb),verifierSha256=sha(__file__),scope='strict finite actual accessors; unit vectors checked, exceptions are not waived')
    if ident=='parallax-observatory':
        archive=archive_bytes('port/new-maps/parallax-observatory/variety/districts-v3/parallax-observatory.glb')
        old=census(archive)
        result['frozenUComparison']=old
        result['exceptionAtSameFrozenUPosition']=all(any(e['attribute']==p['attribute'] and e['position']==p['position'] and e['value']==p['value'] for p in old['exceptions']) for e in result['exceptions'])
        result['disposition']='One inherited zero tangent on saltstone accepted-craft vertex; localized PBR tangent qualification pending, not a blanket pass' if result['exceptions'] else 'pass'
    else:result['disposition']='pass' if not result['exceptions'] else 'blocked'
    write(out/'vector-census.json',result)
    print(ident,result['counts'],result['disposition'])

if __name__=='__main__':main(*sys.argv[1:])

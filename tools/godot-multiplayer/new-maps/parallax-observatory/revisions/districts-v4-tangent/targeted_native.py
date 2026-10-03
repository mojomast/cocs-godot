"""AA diagnostic: unique geometry/UV incidence for the three repaired corners."""
import json
import math
import struct
from contract import EmbeddedGlb, VERTICES, TANGENT, pinned, source_face, sha
from uv_basis import basis, dot, cross, norm

def check(artifact, report, raw):
    if report['artHash'] != sha(artifact): raise ValueError('Different imported artifact')
    g = EmbeddedGlb(artifact)
    positions, normals, uv, tangents, indices = source_face(g)
    points = [positions[v] for v in VERTICES]
    coords = [uv[v] for v in VERTICES]
    found = []
    for surface in report['surfaces']:
        if surface['material'] != 'saltstone': continue
        size = surface['vertices']; off = surface['offset']; arrays = []
        for width in (3,3,2,4):
            arrays.append([struct.unpack_from('<'+'f'*width, raw, off+i*width*4) for i in range(size)])
            off += size*width*4
        ids = struct.unpack_from('<'+'I'*surface['indices'],raw,off)
        for fi in range(0,len(ids),3):
            corners = [tuple(arr[i] for arr in arrays) for i in ids[fi:fi+3]]
            selected = []
            for point, tex in zip(points,coords):
                matches = [i for i,c in enumerate(corners) if max(abs(a-b) for a,b in zip(c[0],point))<=1e-5 and c[2]==tex]
                if len(matches)!=1:break
                selected.append(corners[matches[0]])
            if len(selected)==3 and len(set(id(c) for c in selected))==3:
                found.append((surface,fi//3,selected))
    if len(found)!=1: raise ValueError('Repaired geometry/UV face not unique: '+str(len(found)))
    surface,face,cs=found[0];rows=[]
    for ci,c in enumerate(cs):
        derived=basis(points,coords,c[1],ci)
        t=c[3]
        if (abs(norm(t[:3])-1)>1e-3 or abs(dot(derived['normal'],t[:3]))>2e-4 or
            t[3]!=derived['sign'] or dot(tuple(x*t[3] for x in cross(derived['normal'],t[:3])),derived['b'])<.999):
            raise ValueError('Repaired native UV basis differs: '+str((ci,t)))
        rows.append({'accessor':48,'vertex':VERTICES[ci],'sourceTangent':(0.,0.,0.,1.) if ci==0 else (1.,0.,0.,1.),
            'canonicalTangent':TANGENT,'nativeTangent':t,'nativePosition':c[0],'nativeUV':c[2],
            'nativeNormal':c[1],'sourceFace':11823,'nativeFace':face,'nativeNode':surface['node']})
    return {'scope':'targeted three-corner actual import only; all-face native verifier blocked separately',
        'artifactSha256':sha(artifact),'surface':surface['node'],'sourceFace':11823,'nativeFace':face,'uniqueGeometryUVMatches':1,'corners':rows}

if __name__=='__main__':
    from pathlib import Path
    p=Path(__file__).resolve().parent
    stage=Path('godot/tests/new_maps/parallax_tangent/evidence')
    artifact=(p/'native/AA02/parallax-observatory-tangent.glb').read_bytes()
    result=check(artifact,json.loads((stage/'native-import.json').read_text()),(stage/'native-streams.bin').read_bytes())
    (p/'native/AA02/targeted-three.json').write_text(json.dumps(result,indent=2)+'\n')
    print('AA targeted three-corner actual native proof',len(result['corners']))

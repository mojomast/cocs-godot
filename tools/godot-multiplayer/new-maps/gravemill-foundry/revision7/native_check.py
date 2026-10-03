"""Future actual Godot readback gate: every tangent compared, no zero waiver."""
import collections
from tangents import *
from production import material_pixels
from material_pack import linear_rgba

def canonical(cs):
    start=min(range(3),key=lambda j:tuple(c[0] for c in cs[j:]+cs[:j]))
    cs=cs[start:]+cs[:start];return tuple(c[0] for c in cs),cs

def verify_streams(artifact,report,raw):
    if report['artHash']!=sha(artifact):raise ValueError('Native artifact identity mismatch')
    g=gate(artifact);expected=collections.defaultdict(list);count=0;maximum=[0,0,0]
    for _,_,p,s,faces in rows(g):
        role=g.doc['materials'][p['material']]['name']
        for f in faces:
            cs=[(s['POSITION'][i],s['NORMAL'][i],s['TEXCOORD_0'][i],s['TANGENT'][i]) for i in reversed(f)]
            if any(norm(c[3][:3])<.5 for c in cs):raise ValueError('Invalid source tangent: no native waiver')
            k,cs=canonical(cs);expected[role,k].append(cs)
    for surface in report['surfaces']:
        offset=surface['offset'];size=surface['vertices'];arrays=[]
        for width in (3,3,2,4):
            arrays.append([struct.unpack_from('<'+'f'*width,raw,offset+i*width*4) for i in range(size)]);offset+=size*width*4
        indices=struct.unpack_from('<'+'I'*surface['indices'],raw,offset)
        for start in range(0,len(indices),3):
            cs=[tuple(a[i] for a in arrays) for i in indices[start:start+3]]
            if any(not math.isfinite(v) for c in cs for a in c for v in a):raise ValueError('Nonfinite native stream')
            k,cs=canonical(cs);choices=expected[surface['material'],k]
            errors=[[max(abs(x-y) for a,b in zip(cs,want) for x,y in zip(a[j],b[j])) for j in (1,2,3)] for want in choices]
            match=next((i for i,e in enumerate(errors) if e[0]<=.0002 and e[1]==0 and e[2]<=.0002),None)
            if match is None:raise ValueError('Native position/normal/UV/tangent/handedness mismatch; no zero-tangent exemption')
            maximum=[max(a,b) for a,b in zip(maximum,errors[match])];choices.pop(match);count+=1
    if any(expected.values()):raise ValueError('Native triangle multiplicity differs')
    return {'triangles':count,'maxNormalUVTangentError':maximum,'undefinedTangentWaivers':0}

def main():
    out=HERE/'evidence/native-import';artifact=(ROOT/'godot/multiplayer_worlds/art/revisions/gravemill-foundry-r7.glb').read_bytes()
    verify(SOURCE.read_bytes(),artifact)
    report=json.loads((out/'native-import.json').read_text());proof=verify_streams(artifact,report,(out/'native-streams.bin').read_bytes())
    g=gate(artifact);checked=0
    for mat in g.doc['materials']:
        wanted=material_pixels(g,mat)
        for label,(w,h,pixels) in wanted.items():
            channel='roughness' if label=='roughnessMetallic' else label
            path=ROOT/'godot'/report['materials'][mat['name']]['images'][channel]['path'].removeprefix('res://')
            aw,ah,actual=linear_rgba(path.read_bytes())
            if label=='roughnessMetallic':actual=bytes(v for i,v in enumerate(actual) if i%4 in (1,2))
            if (aw,ah,bytes(actual))!=(w,h,pixels):raise ValueError('Native material pixels changed')
            checked+=1
    proof.update({'artHash':sha(artifact),'materialChannelsChecked':checked,'manualVisualAcceptance':'pending'})
    (out/'native-proof.json').write_text(json.dumps(proof,indent=2)+'\n')

if __name__=='__main__':main()

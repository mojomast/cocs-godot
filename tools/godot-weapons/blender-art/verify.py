"""Static contract on the *actual exported* GLBs; no Blender or Godot required."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
ART=ROOT/'godot/first_person/art'
MASTER=Path(__file__).parent/'masters'
SOURCE=ROOT/'godot/first_person/generated'
CANON=json.loads((SOURCE/'manifest.json').read_text())
WORLD=json.loads((ROOT/'godot/source_operators/generated/world_weapons/manifest.json').read_text())

def glb(path):
    raw=path.read_bytes()
    assert raw[:4]==b'glTF' and struct.unpack_from('<I',raw,8)[0]==len(raw),path
    size=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+size]), raw[28+size:]

def vertices(doc,binary,mesh):
    for primitive in doc['meshes'][mesh]['primitives']:
        access=doc['accessors'][primitive['attributes']['POSITION']]
        view=doc['bufferViews'][access['bufferView']]
        offset=view.get('byteOffset',0)+access.get('byteOffset',0)
        stride=view.get('byteStride',12)
        for i in range(access['count']): yield struct.unpack_from('<fff',binary,offset+i*stride)

def rotate(point,q):
    x,y,z,w=q; px,py,pz=point
    # q * p * conjugate(q), including Blender-authored rods.
    tx=2*(y*pz-z*py);ty=2*(z*px-x*pz);tz=2*(x*py-y*px)
    return (px+w*tx+y*tz-z*ty,py+w*ty+z*tx-x*tz,pz+w*tz+x*ty-y*tx)

def profile(doc,binary):
    names={n['name'] for n in doc['nodes']}
    assert {'body','feed','bolt'}.issubset(names)
    assert 'barrel-assembly' in names or 'shock-emitter' in names or 'flak-barrel' in names
    roles={n['name'].rsplit('-',1)[-1] for n in doc['nodes'] if 'mesh' in n}
    assert {'dark','light','glow','trim','cavity'}.issubset(roles), roles
    # Fixed world-space projection cells; each silhouette samples actual vertex
    # positions, not design metadata or the canonical source-export masks.
    side=set(); top=set(); triangles=0
    for node in doc['nodes']:
        if 'mesh' not in node: continue
        q=node.get('rotation',[0,0,0,1]); t=node.get('translation',[0,0,0]); s=node.get('scale',[1,1,1])
        for p in vertices(doc,binary,node['mesh']):
            x,y,z=rotate(tuple(p[i]*s[i] for i in range(3)),q)
            x+=t[0];y+=t[1];z+=t[2]
            side.add((round((z+1.35)*54),round((y+.5)*54)))
            top.add((round((z+1.35)*54),round((x+.28)*54)))
        triangles+=sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][node['mesh']]['primitives'])
    return side,top,triangles,len([n for n in doc['nodes'] if 'mesh' in n]),roles

def main():
    metrics=[]; outlines=[]
    for id in range(10):
        w=CANON['weapons'][id]; old=WORLD['weapons'][id]
        assert w['id']==old['id']==id
        for base,item in ((SOURCE,w),(ROOT/'godot/source_operators/generated/world_weapons',old)):
            assert hashlib.sha256((base/item['file']).read_bytes()).hexdigest()==item['sha256'],f'canonical geometry changed {id}'
        profiles=[]
        for low in (False,True):
            key='world' if low else 'weapon'
            path=ART/f'{key}-{id}.glb'
            doc,bin=glb(path)
            p=profile(doc,bin); profiles.append(p)
            assert p[2] <= (1250 if low else 6500),(id,key,p[2])
            assert p[3] <= 16,(id,key,p[3])
            assert (MASTER/f'{key}-{id}.blend').stat().st_size>50000
        assert profiles[1][2] < profiles[0][2]*.35,(id,'world LOD')
        outlines.append(profiles[0][:2]); metrics.append({'id':id,'name':w['name'],
            'firstPersonTriangles':profiles[0][2],'worldTriangles':profiles[1][2],
            'firstPersonBatches':profiles[0][3],'worldBatches':profiles[1][3]})
    max_ious={}
    for axis in (0,1):
        pairs=[]
        for i in range(10):
            for j in range(i+1,10):
                a,b=outlines[i][axis],outlines[j][axis]
                pairs.append((len(a&b)/len(a|b),i,j))
        worst=max(pairs)
        max_ious['side' if axis==0 else 'top']=round(worst[0],4)
        assert worst[0]<.54,('art silhouettes too similar',axis,worst)
    print(json.dumps({'sourceExports':'sha256 intact','art':metrics,'maxVertexProfileIoU':max_ious},indent=2))

if __name__=='__main__': main()

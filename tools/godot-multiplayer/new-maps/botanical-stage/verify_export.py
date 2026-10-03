"""Future artifact proof: world transforms, winding, union coverage and rays.

No engine invocation. A proof is produced only from actual build/reopen files.
"""
import argparse
import math
from collections import Counter
from config import HERE, ROOT, DEST, MAPS, entry, read, sha
from geometry import (glb_triangles, TriangleInventory, authority_triangles,
                      RayIndex, normal, center, volume, sub, cross, length, PRECISION, BEVEL)
from export_audit import audit_glb
import kit_expander


def verify(map_id):
    author,data,_,_,_=entry(map_id)
    evidence=HERE/'evidence'/map_id
    build=read(evidence/'build-report.json');reopen=read(evidence/'reopen-report.json');measured=read(evidence/'evaluated.json')
    for report in (build,reopen,measured):
        if report['geometryHash']!=data['geometryHash']:raise ValueError('Stale artifact receipt')
    if measured['glbSha256']!=sha(author.EXPORT) or reopen['glbSha256']!=sha(author.EXPORT) or measured['masterSha256']!=sha(author.MASTER):
        raise ValueError('Artifact bytes do not match fresh reopen proof')
    if measured['cameras']!=read(DEST/(map_id+'-cameras.json'))['cameras']:raise ValueError('Master cameras differ from prepared native cameras')
    audit=audit_glb(author.EXPORT,ROOT,read(author.BINDINGS),
        expected_materials=build['exportAudit']['usedMaterials'],expected_triangles=len(measured['exportTriangles']))
    rows=glb_triangles(author.EXPORT.read_bytes())
    TriangleInventory(rows).match(measured['exportTriangles'],complete=True)
    # Validate every raw candidate floor-union triangle against actual GLB,
    # preserving winding/material/multiplicity, not just total area or bounds.
    shell=kit_expander.shell_plan(data['arena'])
    shell_rows=[]
    for material,bucket in shell['surfaces'].items():
        for face in bucket['faces']:
            for i in range(1,len(face)-1):
                shell_rows.append({'material':material,'vertices':[[bucket['vertices'][j][0],bucket['vertices'][j][2],-bucket['vertices'][j][1]] for j in (face[0],face[i],face[i+1])]})
    TriangleInventory(rows).match(shell_rows)
    from source_geometry import CaptureKit,world_vertices
    import kit_build
    expected={}
    for directive in data['arena']['art']['kit']:
        kit=CaptureKit()
        for op in kit_expander.expand_kit([directive],set(read(author.BINDINGS)['materials'])):kit_build.create_assembly(kit,op)
        for obj in kit.source.objects:expected[obj.name]=obj
    if set(measured['components'])!=set(expected):raise ValueError('Incomplete component lineage')
    inventory=TriangleInventory(rows);components=[];ray_specs=[]
    for name,component in measured['components'].items():
        original=expected[name];vertices=world_vertices(original)
        if component['sourceFaces']!=[list(f) for f in original.faces] or len(vertices)!=len(component['sourceVertices']):raise ValueError('Changed compiled component topology')
        if any(max(abs(a-b) for a,b in zip(p,q))>PRECISION for p,q in zip(vertices,component['sourceVertices'])):raise ValueError('Changed compiled component world position')
        ids=inventory.match(component['evaluated'])
        actual=[rows[i]['vertices'] for i in ids]
        bounds=[[min(p[k] for t in actual for p in t) for k in range(3)],[max(p[k] for t in actual for p in t) for k in range(3)]]
        before=[[min(p[k] for p in vertices) for k in range(3)],[max(p[k] for p in vertices) for k in range(3)]]
        delta=max(abs(a-b) for v,w in zip(bounds,before) for a,b in zip(v,w))
        if delta>BEVEL:raise ValueError('Evaluated component exceeds 4cm bevel envelope: '+name)
        edges=Counter(tuple(sorted((face[i],face[(i+1)%len(face)]))) for face in original.faces for i in range(len(face)))
        closed=bool(edges) and all(n==2 for n in edges.values())
        signed=volume(actual) if closed else None
        if closed and signed<=0:raise ValueError('Nonpositive actual GLB component winding: '+name)
        components.append({'id':name,'directive':component['directive'],'class':component['class'],
            'triangles':len(actual),'bounds':bounds,'maxBoundsDeltaMetres':delta,'closed':closed,'signedVolume':signed})
        # One representative interior face per solid component; short rays
        # measure source collision versus actual evaluated beveled geometry.
        from source_geometry import SOLIDS
        if component['class'] in SOLIDS:
            faces=[[vertices[f[0]],vertices[f[i]],vertices[f[i+1]]] for f in original.faces for i in range(1,len(f)-1)]
            tri=max(faces,key=lambda t:length(cross(sub(t[1],t[0]),sub(t[2],t[0]))))
            n=normal(tri);c=center(tri)
            ray_specs.append({'id':'solid:'+name,'origin':[p+.15*d for p,d in zip(c,n)],'direction':[-v for v in n],'max':.3,'kind':'solid'})
    # Portal aperture rays include center and lateral/vertical capsule-width
    # samples. Never treat a malformed two-component direction as a 3D ray.
    for portal in data['arena']['art'].get('portals',[]):
        dx,dz=portal['dir'];size=math.hypot(dx,dz)
        if not math.isfinite(size) or size<1e-8:raise ValueError('Invalid portal direction')
        dx,dz=dx/size,dz/size
        for side in (-.35,0,.35):
            for height in (.5,1.5):
                x,y,z=portal['at'];depth=portal['depth']
                ray_specs.append({'id':f'portal:{portal["id"]}:{side}:{height}',
                    'origin':[x-dx*depth/2-dz*side*portal['width'],y+height,z-dz*depth/2+dx*side*portal['width']],
                    'direction':[dx,0,dz],'max':depth,'kind':'portal'})
    # Deliberate local floor probes cover relief, the well opening and roof.
    special={'helix-conservatory':[(-29.5,8,46.5),(-24,8,-45)],
        'parallax-observatory':[(32,8,-34.13),(40,10,-34.13),(43.5,11.75,-34.13),(20,12.4,-34)],
        'vesper-viaduct':[(18,22,45),(18,22+1/7,53.1)]}[map_id]
    for i,(x,y,z) in enumerate(special):ray_specs.append({'id':f'relief:{i}','origin':[x,y+.2,z],'direction':[0,-1,0],'max':.4,'kind':'relief'})
    source=RayIndex(authority_triangles(data['arena']));visual=RayIndex([r['vertices'] for r in rows]);rays=[]
    for spec in ray_specs:
        collision=source.ray(spec['origin'],spec['direction'],spec['max'])
        rendered=visual.ray(spec['origin'],spec['direction'],spec['max'])
        if abs(collision-rendered)>BEVEL:raise ValueError(f'Actual GLB/source ray mismatch {spec["id"]}: {collision}, {rendered}')
        if spec['kind']=='portal' and collision<spec['max']-PRECISION:
            # A horizontal ray can meet the ascending walkable floor beyond an
            # arch. That is not a filled aperture. Prove the hit is walkable
            # support, and still forbid every wall/nonwalkable cap in the span.
            forbidden=[]
            for wall in data['arena']['terrain']['walls']:
                v=wall['vertices'];forbidden.extend([[v[0],v[i],v[i+1]] for i in range(1,len(v)-1)])
            for s in data['arena']['terrain']['surfaces']:
                if not s.get('walkable',True):forbidden.extend([[s['vertices'][i] for i in f] for f in s['triangles']])
            if RayIndex(forbidden).ray(spec['origin'],spec['direction'],spec['max'])<spec['max']-PRECISION:
                raise ValueError('Blocked portal '+spec['id'])
            spec['walkableFloorIntersection']=collision
        rays.append({**spec,'authority':collision,'glb':rendered,'toleranceMetres':BEVEL})
    return {'geometryHash':data['geometryHash'],'glbSha256':sha(author.EXPORT),'masterSha256':sha(author.MASTER),
        'geometryStatus':'actual-export-verified','nativeStatus':'pending','usedMaterials':audit['usedMaterials'],
        'exportAudit':audit,'trianglePrecisionMetres':PRECISION,'bevelEnvelopeMetres':BEVEL,
        'evaluatedExportTriangles':len(rows),'matchedFloorTriangles':len(shell_rows),'floorUnion':shell['floorUnion'],
        'components':components,'rays':rays,'cameras':measured['cameras']}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('map',choices=MAPS)
    result=verify(parser.parse_args().map)
    print('Actual export verified:',result['geometryHash'],result['evaluatedExportTriangles'])

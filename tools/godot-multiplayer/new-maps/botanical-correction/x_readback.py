"""X additive actual-byte capsule and shell receipts; no artifact edits."""
import json
import math
import subprocess
import sys
from stage_config import ROOT,HERE,read,write,sha
from stage_bridge import validate_setup
from source_scene import scene
from geometry import TriangleInventory,glb_triangles,RayIndex
from capsule import Capsules
from test_greenhouse import components,attachments

def main(attempt,ident):
    out,dest,record=validate_setup(attempt,ident)
    target=out/'x-readback-v2.json'
    if target.exists():raise FileExistsError(target)
    manifest=read(dest/'manifest.json');glb=out/(ident+'.glb')
    if sha(glb)!=manifest['glbSha256']:raise ValueError('Actual export drift')
    rows=glb_triangles(glb.read_bytes());inventory=TriangleInventory(rows)
    data=read(out/'authority.json');proof=read(out/'evaluated-proof.json')
    predicted,_,_=scene(data['arena'])
    shell=[r for r in predicted if r['role'] in ('authority.surface','authority.wall','authority.block')]
    matched=inventory.match(shell)
    result={'map':ident,'attempt':attempt,'geometryHash':record['geometryHash'],'glbSha256':sha(glb),'verifierSha256':sha(__file__),
        'masterSha256':sha(out/'masters'/(ident+'.blend')),'completeAuthorityShellFaces':len(matched),
        'numericToleranceMetres':.0001,'visualBevelLimitMetres':.04}
    if ident=='helix-conservatory':
        names=components(data['arena']);triangles=[]
        for name in names:
            ids=inventory.match(proof['components'][name]['evaluated'])
            triangles.extend(rows[i]['vertices'] for i in ids)
        measured={name:proof['components'][name]['sourceVertices'] for name in names}
        joints,edges=attachments(data['arena'],measured,.0001)
        points=json.loads(subprocess.check_output(['node',str(HERE/'route_points.mjs')],cwd=ROOT))
        points+=read(dest/'probes.json')['points']
        if len(points)!=49553 or len(triangles)!=1548:raise ValueError('Frame coverage drift')
        query=Capsules(triangles)
        for p in points:
            if query.overlaps(p['x'],p['y']+.001,p['z']):raise ValueError('Actual frame capsule hit '+str(p))
        result.update(actualFrameFaces=len(triangles),finiteActualFrameCapsules=len(points),completeBearings=joints,groundRootedEdges=edges)
    if ident=='parallax-observatory':
        triangles=[rows[i]['vertices'] for i in matched];query=Capsules(triangles);ground=RayIndex(triangles)
        points=[p for p in read(dest/'probes.json')['points'] if p['kind'].startswith('successor-')]
        if len(points)!=1920:raise ValueError('Aperture/grade coverage drift')
        seams=[]
        for p in points:
            origin=[p['x'],p['y']+.2,p['z']]
            distance=ground.ray(origin,[0,-1,0],.4)
            if abs(distance-.2)>.0001:
                raise ValueError('Actual export support differs by more than 0.1mm '+str(p))
            if query.overlaps(p['x'],p['y']+.05,p['z']):raise ValueError('Actual authority-shell capsule '+str(p))
        result.update(actualShellCapsules=len(points),capsuleRadius=.42,capsuleHeight=1.8,groundSeparation=.05,
            maximumSlopeRequiredSeparation=.42*(math.sqrt(1+(12/25.5)**2)-1),supportSeams=seams,
            scope='actual exported complete authority shell; authored foot Y unchanged; static capsules, controller dynamics pending')
    if ident=='vesper-viaduct':
        descriptors=data['arena']['art']['baseCraft']['canonicalSolids']['descriptors']
        retained=[d for d in descriptors if d['replacement']['kind']=='authority']
        if len(descriptors)!=60 or len(retained)!=54:raise ValueError('Canonical ownership drift')
        result.update(canonicalDescriptors=60,retainedShells=54,replacedByKit=6,
            nativeCanonicalBoundaryRays=sum(r['kind']=='canonical-parapet' for r in read(dest/'probes.json')['rays']))
    write(target,result)
    print(ident,'actual-byte additive checks passed')

if __name__=='__main__':main(*sys.argv[1:])

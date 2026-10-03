"""Pure actual-byte successor gate. Missing future artifacts fail closed.

This does NOT generate a native stage, acceptance receipt, or reuse U evidence.
"""
import argparse
import hashlib
import json
from asset_author import paths,MAPS
from source_scene import scene
from geometry import glb_triangles,TriangleInventory,PRECISION
from test_greenhouse import attachments,components
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify(ident):
    out,master=paths(ident);glb=out/(ident+'.glb')
    authority=json.loads((out/'authority.json').read_text());proof=json.loads((out/'evaluated-proof.json').read_text())
    if proof['geometryHash']!=authority['geometryHash'] or proof['masterSha256']!=sha(master) or proof['glbSha256']!=sha(glb):raise ValueError('Stale successor evidence')
    rows=glb_triangles(glb.read_bytes());TriangleInventory(rows).match(proof['exportTriangles'],complete=True)
    predicted,_,_=scene(authority['arena'])
    # Entire actual world authority shell, including legacy walls and canonical
    # parapet caps. No new-component-only or footprint-only coverage shortcut.
    shell=[r for r in predicted if r['role'] in ('authority.surface','authority.wall','authority.block')]
    TriangleInventory(rows).match(shell)
    inventory=TriangleInventory(rows)
    for name,c in proof['components'].items():inventory.match(c['evaluated'])
    if ident=='helix-conservatory':
        measured={n:proof['components'][n]['sourceVertices'] for n in components(authority['arena'])}
        joints,edges=attachments(authority['arena'],measured,PRECISION)
        # Every actual evaluated member vertex must still be on a measured raw
        # member vertex. Frame profiles/posts intentionally have no moving bevel.
        for name,vertices in measured.items():
            actual_vertices=[p for t in proof['components'][name]['evaluated'] for p in t['vertices']]
            if not actual_vertices:raise ValueError('Empty actual attachment member '+name)
            for q in vertices:
                if not any(max(abs(a-b) for a,b in zip(p,q))<=PRECISION for p in actual_vertices):raise ValueError('Actual attachment cross-section vertex missing '+name)
            for t in proof['components'][name]['evaluated']:
                for p in t['vertices']:
                    if not any(max(abs(a-b) for a,b in zip(p,q))<=PRECISION for q in vertices):raise ValueError('Attachment member deformed '+name)
        print('Actual named frame attachments verified:',len(joints),'ends;',len(edges),'ground-rooted edges')
    print(ident,'actual complete export and full authority shell verified; native gates still pending')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('map',choices=MAPS);verify(p.parse_args().map)

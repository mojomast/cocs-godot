"""Pure complete geometry prediction; reads the real Kit and pinned craft.

No Blender import. Modifier/label tessellation and actual export remain pending.
"""
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/godot-multiplayer/new-maps/map_variety'))
sys.path.insert(0,str(ROOT/'tools/godot-multiplayer/new-maps/botanical-stage'))
import kit_expander as k
import kit_build
from base_craft import base_craft_plan
from source_geometry import CaptureKit,world_vertices
from geometry import RayIndex,authority_triangles

def load(ident,revision):
    return json.loads((ROOT/f'port/new-maps/{ident}/variety/{revision}/authority.json').read_text())

def bucket_rows(buckets,role):
    rows=[]
    for material,b in buckets.items():
        for f in k.outward_faces(b['vertices'],b['faces']):
            for i in range(1,len(f)-1):
                rows.append({'role':role,'material':material,'vertices':[
                    [b['vertices'][j][0],b['vertices'][j][2],-b['vertices'][j][1]] for j in (f[0],f[i],f[i+1])]})
    return rows

def scene(arena):
    shell=k.shell_plan(arena);rows=[]
    rows+=bucket_rows(shell['surfaces'],'authority.surface')
    rows+=bucket_rows(shell['walls'],'authority.wall')
    rows+=bucket_rows(k.structure_plan(arena)['buckets'],'authority.block')
    rows+=bucket_rows(k.piece_plan(arena)['buckets'],'authority.piece')
    rows+=bucket_rows(k.decorative_plan(arena)['buckets'],'art.decorative')
    craft=base_craft_plan(arena,ROOT)
    rows+=bucket_rows(craft['buckets'],'art.accepted-craft')
    kit=CaptureKit()
    materials={d['material'] for d in arena['art']['kit']}
    # expand_kit validates secondary materials against the supplied allowlist.
    prior='districts-v3' if arena['id']=='parallax-observatory' else 'urban-v2'
    path=ROOT/f'tools/godot-multiplayer/new-maps/{arena["id"]}/revisions/{prior}/variety_bindings.json'
    if arena['id']=='helix-conservatory':path=ROOT/'tools/godot-multiplayer/new-maps/helix-conservatory/variety_bindings.json'
    bindings=json.loads(path.read_text())
    for op in k.expand_kit(arena['art']['kit'],set(bindings['materials']))+k.infrastructure_plan(arena):kit_build.create_assembly(kit,op)
    for o in kit.source.objects:
        v=world_vertices(o)
        rows += [{'role':'kit','component':o.name,'material':o.material,'vertices':[v[j] for j in (f[0],f[i],f[i+1])]} for f in o.faces for i in range(1,len(f)-1)]
    return rows,craft,shell

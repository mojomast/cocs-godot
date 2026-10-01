"""Reproducible Blender 4.5 urban facade masters and art-only GLBs.

blender -b -t 1 --python tools/godot-multiplayer/urban/export.py
All playable surfaces, block collision and rays come exclusively from JSON.
"""
import bpy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GENERATED = ROOT / 'godot/multiplayer_worlds/generated'
OUT = ROOT / 'godot/multiplayer_worlds/art'
MASTER = ROOT / 'tools/godot-multiplayer/urban'
OUT.mkdir(parents=True, exist_ok=True)

def material(name, color, metal=0, rough=.76, alpha=1):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, alpha)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = rough
    if alpha < 1:
        mat.surface_render_method = 'DITHERED'
        shader.inputs['Alpha'].default_value = alpha
    return mat

def cube(name, location, size, mat, bevel=0):
    # Recipe/Godot coordinates are X east, Y up, Z south; Blender is Z up.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(location[0],location[2],location[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('soft fabricated edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def sign(name, x, y, z, length, text, ink):
    # Text becomes mesh on export, so the master is self-contained.
    bpy.ops.object.text_add(location=(x, z, y), rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.data.body = text
    obj.data.size = .58
    obj.data.extrude = .012
    obj.data.materials.append(ink)
    bpy.ops.object.convert(target='MESH')
    return obj

for map_id in ('switchyard-ward', 'rainmarket-exchange'):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for old in list(bpy.data.materials):
        bpy.data.materials.remove(old)
    arena = json.loads((GENERATED / f'{map_id}.json').read_text())['arena']
    brick = material('fired ochre brick', (.32,.18,.13))
    mortar = material('warm cut concrete', (.43,.43,.41))
    steel = material('oxidized blue steel', (.11,.22,.27), .73, .42)
    copper = material('market copper signage', (.61,.37,.17), .65, .38)
    glass = material('deep blue shop glazing', (.09,.27,.34), .24, .17, .7)
    ink = material('enamel lettering', (.96,.75,.42), .2, .38)
    stripe = material('road lane paint', (.74,.70,.56), 0, .9)
    # Facades sit exactly on gameplay block footprints. No phantom floor/cover.
    for b in arena['blocks']:
        key=b['id'];x=b['x'];z=b['z'];w=b['w'];d=b['d'];h=b['h'];base=b.get('baseY',0)
        if key.endswith('-mass'):
            cube(key+'-stone-body',(x,(h+base)/2,z),(w-.10,h-base-.08,d-.10),brick)
            # Four varied vertical bays, inset within the solid silhouette.
            for i in range(4):
                xx=x+(i-1.5)*w/4.6
                cube(key+f'-pier-{i}',(xx,1.75,z-d/2-.035),(.28,2.7,.09),mortar)
                cube(key+f'-window-{i}',(xx,1.9,z-d/2-.085),(1.5,1.25,.035),glass)
                cube(key+f'-lintel-{i}',(xx,2.75,z-d/2-.06),(1.7,.15,.1),steel)
            cube(key+'-parapet-front',(x,h+.25,z-d/2),(w+.15,.42,.16),steel)
            cube(key+'-parapet-back',(x,h+.25,z+d/2),(w+.15,.42,.16),steel)
            cube(key+'-parapet-left',(x-w/2,h+.25,z),(.16,.42,d),steel)
            cube(key+'-parapet-right',(x+w/2,h+.25,z),(.16,.42,d),steel)
        elif '-entry-' in key or any(key.startswith(prefix) for prefix in ('west-toolshop','east-service','north-ticket','south-depot','west-foodhall','east-kiosk','north-station','east-warehouse')):
            # Walls are deliberately copied from the arena blocks; broad entry
            # remains 4.2m open with no roof support falsely hiding the shop.
            cube(key+'-wall',(x,(h+base)/2,z),(w,h-base,d),brick if b['material']=='brick' else mortar)
            if w>2 and d<1:
                cube(key+'-cornice',(x,h+.12,z),(w+.05,.16,d+.09),steel)
                for i in range(max(1,int(w//2.2))):
                    xx=x+(-.5+(i+.5)/max(1,int(w//2.2)))*w
                    cube(key+f'-glaze-{i}',(xx,2.25,z+(d/2+.012)),(min(1.25,w/max(1,int(w//2.2))*.7),.9,.024),glass)
        elif key.startswith(('rail-','tram-','stall-')):
            cube(key+'-structural',(x,(h+base)/2,z),(w,h-base,d),steel)
            if key.startswith('stall-'):
                cube(key+'-canopy',(x,h+.15,z),(w+.5,.2,d+.45),copper)
        else:
            # Gameplay collision is visible, without misleading oversize art.
            cube(key+'-cover',(x,(h+base)/2,z),(w,h-base,d),steel if b['material']=='steel' else mortar)
    if map_id == 'switchyard-ward':
        for i,z in enumerate((-14,-7,0,7,14)):
            cube(f'railbed-{i}',(0,.024,z),(.18,.05,4.5),steel)
        for i,(x,z,text) in enumerate(((-18,0,'TOOLS'),(18,0,'SERVICE'),(0,-24,'WARD 08'),(0,24,'DEPOT'))):
            sign(f'sign-{i}',x-1.25,3.65,z-4.72 if z else -4.75,3,text,ink)
    else:
        for i,x in enumerate(range(-32,33,6)):
            cube(f'tram-sleeper-{i}',(x,.02,-14),(.19,.04,4.8),steel)
        for i,(x,z,text) in enumerate(((-25,20,'FOOD HALL'),(26,19,'BAZAAR'),(11,-25,'EXCHANGE'),(28,-17,'WAREHOUSE'))):
            sign(f'sign-{i}',x-2.2,3.62,z-5.7,4,text,ink)
    # Paving/directional marks remain flat and cosmetic. No art-only floating
    # bridges, visual door closures, or walls missing from authority.
    for i in range(-5,6):
        cube(f'lane-mark-{i}',(i*6,.006,0),(2,.012,.10),stripe)
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER / f'{map_id}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f'{map_id}.glb'), export_format='GLB',
                              use_selection=False, export_apply=True, export_materials='EXPORT')
    tris=sum(len(obj.data.polygons) for obj in bpy.data.objects if obj.type=='MESH')
    print(f'URBAN_EXPORTED {map_id} mesh_objects={sum(o.type=="MESH" for o in bpy.data.objects)} triangles={tris}')

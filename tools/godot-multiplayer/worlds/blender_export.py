"""Deterministic, editable Blender master + batched glTF render mesh.

Invoke only after parent grants heavy work:
  blender -b -t 1 --python tools/godot-multiplayer/worlds/blender_export.py -- <map-id>
Each material has one mesh object (limited draw calls); the master preserves
named, individually editable mesh components in source collections.
"""
import json
import math
import pathlib
import sys
import bpy

ROOT = pathlib.Path(__file__).resolve().parents[3]
ID = sys.argv[sys.argv.index('--') + 1]
DATA = json.loads((ROOT / 'port/native-multiplayer-worlds/worlds' / (ID + '.json')).read_text())
ART = ROOT / 'godot/multiplayer_worlds/art/worlds'
ART.mkdir(parents=True, exist_ok=True)
MASTER = ROOT / 'tools/godot-multiplayer/worlds/masters'
MASTER.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

COLORS = {
    'quay': (.34,.45,.48,1), 'tidal-silt': (.2,.39,.47,1), 'granite': (.51,.53,.54,1),
    'spillway': (.37,.55,.61,1), 'iron': (.26,.35,.38,1), 'coral': (.68,.29,.19,1),
    'teal': (.1,.42,.45,1), 'plaster': (.67,.7,.65,1), 'roof': (.24,.32,.37,1),
    'retaining': (.36,.39,.38,1), 'seawall': (.58,.57,.52,1), 'basalt': (.24,.29,.3,1),
    'snowcap': (.82,.88,.87,1), 'sandstone': (.69,.47,.29,1), 'ochre': (.65,.29,.14,1),
    'copper': (.58,.31,.19,1), 'pitch': (.13,.46,.41,1), 'water': (.09,.31,.43,1),
    'island-ground': (.34,.46,.35,1), 'causeway': (.56,.54,.43,1),
    'limestone': (.64,.6,.48,1),
}
materials={}
for name, color in COLORS.items():
    material=bpy.data.materials.new(name)
    material.diffuse_color=color
    material.use_nodes=True
    principled=material.node_tree.nodes.get('Principled BSDF')
    principled.inputs['Base Color'].default_value=color
    principled.inputs['Roughness'].default_value=.84 if name not in ('iron','water') else .42
    materials[name]=material

def collection(name):
    c=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

master=collection('SOURCE - editable architectural pieces')
render=collection('EXPORT - material batches')
groups={}
def emit(name, verts, faces, material, metadata=None):
    material=material if material in materials else 'retaining'
    # Recipes are Y-up, Blender is Z-up. glTF's export_yup rotates Blender Z
    # back into glTF Y; pre-rotate horizontal source Z into negative Blender Y.
    verts=[(x,-z,y) for x,y,z in verts]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj=bpy.data.objects.new(name, mesh)
    master.objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['authoritative_geometry']='recipe'
    for key,value in (metadata or {}).items():
        if isinstance(value,(str,int,float,bool)): obj[key]=value
    group=groups.setdefault(material, [[],[]])
    start=len(group[0]);group[0].extend(verts)
    group[1].extend([tuple(start+i for i in face) for face in faces])

def cube(p, name):
    x,y,z,w,h,d=[p[k] for k in ('x','y','z','w','h','d')]
    verts=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sy in (-1,1) for sz in (-1,1) for sx in (-1,1)]
    faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    emit(name,verts,faces,p['material'],p)

def cone(p,name):
    x,y,z,w,h,d=[p[k] for k in ('x','y','z','w','h','d')]
    n=8;bottom=y-h/2
    ring=[(x+math.cos(i*math.tau/n)*w/2,bottom,z+math.sin(i*math.tau/n)*d/2) for i in range(n)]
    emit(name,ring+[(x,y+h/2,z)],[(i,(i+1)%n,n) for i in range(n)]+[tuple(reversed(range(n)))],p['material'],p)

def ramp(p,name):
    x,z,w,d=[p[k] for k in ('x','z','w','d')]
    a,b=p['y0'],p['y1']
    # End plates are vertical, top is a single continuous support strip.
    v=[(x-w/2,0,z-d/2),(x-w/2,0,z+d/2),(x+w/2,0,z+d/2),(x+w/2,0,z-d/2),
       (x-w/2,a,z-d/2),(x-w/2,a,z+d/2),(x+w/2,b,z+d/2),(x+w/2,b,z-d/2)]
    emit(name,v,[(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)],p['material'],p)

for index, ground in enumerate(DATA['art']['ground']):
    cube({**ground,'y':-.17 if index==0 else .005,'h':.3 if index==0 else .02},'ground.%03d'%index)
for index,p in enumerate(DATA['art']['pieces']):
    {'box':cube,'roof':cube,'cone':cone,'ramp':ramp}[p['kind']](p,'%s.%04d'%(p['kind'],index))

# Preserve editable components in the .blend; export only the per-material batches.
for name,(verts,faces) in groups.items():
    mesh=bpy.data.meshes.new('batch.'+name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new('batch.'+name,mesh)
    render.objects.link(obj)
    obj.data.materials.append(materials[name])
    obj['recipe_id']=ID

bpy.ops.wm.save_as_mainfile(filepath=str(MASTER/(ID+'.blend')))
bpy.ops.object.select_all(action='DESELECT')
for obj in render.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=next(iter(render.objects))
bpy.ops.export_scene.gltf(filepath=str(ART/(ID+'.glb')),export_format='GLB',use_selection=True,
    export_apply=True,export_yup=True,export_materials='EXPORT')
print('WORLD_EXPORT',ID,'pieces',len(master.objects),'batches',len(render.objects))

"""Blender 4.5 background authoring; execute only when the parent grants export.

LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-horde/blackwater_blender.py
One editable .blend master; exports a batched, decoration-only GLB. Source
collisions/walkable decks are exclusively the matching generated JSON recipe.
"""
import bpy
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[2]
recipe = json.loads((root / 'godot/horde_maps/generated/blackwater-reclamation.json').read_text())
output = root / 'godot/horde_maps/art'
output.mkdir(exist_ok=True, parents=True)
master = root / 'tools/godot-horde/masters'
master.mkdir(exist_ok=True, parents=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {
    'steel':(0.085, 0.16, 0.19, 1), 'oxidized':(0.16, 0.29, 0.32, 1),
    'concrete':(0.23, 0.31, 0.32, 1), 'hazard':(0.72, 0.39, 0.12, 1),
    'lamp':(0.20, 0.71, 0.72, 1), 'water':(0.07, 0.27, 0.36, 1),
}
for name, color in materials.items():
    mat = bpy.data.materials.new('BW_' + name)
    mat.diffuse_color = color
    mat.use_nodes = True
    surface = mat.node_tree.nodes.get('Principled BSDF')
    surface.inputs['Base Color'].default_value = color
    surface.inputs['Metallic'].default_value = 0.68 if name in ['steel','oxidized'] else 0.1
    surface.inputs['Roughness'].default_value = 0.48 if name == 'steel' else 0.75

# Accumulate into six immutable material batches. These authored meshes contain
# no colliders and never conceal the JSON side passages; each unit has a local
# name in the Blender collection hierarchy for human editability.
faces = {m:[] for m in materials}
vertices = {m:[] for m in materials}
def prism(name, location, size, material):
    x,y,z = location
    w,h,d = size
    x0,x1=x-w/2,x+w/2
    y0,y1=y-h/2,y+h/2
    z0,z1=z-d/2,z+d/2
    base=len(vertices[material])
    # Blender is Z-up / GLTF export_yup; preserve source X,Y-up,Z-forward.
    vertices[material].extend([(x0,-z0,y0),(x0,-z1,y0),(x0,-z1,y1),(x0,-z0,y1),
                                (x1,-z0,y0),(x1,-z1,y0),(x1,-z1,y1),(x1,-z0,y1)])
    faces[material].extend([tuple(base+i for i in q) for q in
        [(0,1,2,3),(4,7,6,5),(0,4,5,1),(3,2,6,7),(0,3,7,4),(1,5,6,2)]])

def ring(name, x, y, z, outer, inner, depth, material, segments=12):
    # Vertical XZ torus section: twelve rings instead of expensive smooth tubes.
    base=len(vertices[material])
    for i in range(segments):
        angle=2*math.pi*i/segments
        for radius,height in [(outer,-depth/2),(outer,depth/2),(inner,depth/2),(inner,-depth/2)]:
            vertices[material].append((x+radius*math.cos(angle),-(z+radius*math.sin(angle)),y+height))
    for i in range(segments):
        j=(i+1)%segments
        for k in range(4):
            faces[material].append((base+4*i+k,base+4*j+k,base+4*j+(k+1)%4,base+4*i+(k+1)%4))

districts=[('INTAKE',-170),('DISTRIBUTION',-82),('SWITCHYARD',0),('SETTLING',82),('SPILLWAY',170)]
for index,(name,x) in enumerate(districts):
    # Readable distant silhouettes: a distinctive height every district.
    high=18+index*3
    for side in [-1,1]:
        px=x+side*38
        prism(name+'_tower_foot',(px,2,104),(8,4,8),'concrete')
        prism(name+'_tower',(px,high/2,104),(5,high,5),'oxidized')
        ring(name+'_tower_crown',px,high+1,104,6,4.4,1.5,'hazard')
        for level in range(2,int(high)-1,5):
            ring(name+'_brace',px,level,104,4.2,3.5,0.6,'steel')
    # Big open service arches: pillars sit on the flanks, never across a route.
    for z in [-57,-5,57]:
        for side in [-1,1]:
            prism(name+'_arch_leg',(x+side*34,5.5,z),(2,11,2),'steel')
        prism(name+'_arch_lintel',(x,11,z),(70,2,2),'steel')
        for n in range(5):
            prism(name+'_luminaire',(x-24+n*12,10.1,z),(3,0.15,0.8),'lamp')
    # Distinct low-profile machinery around the true center court, ground-bonded.
    for px in [x-34,x+34]:
        for z in [-82,78]:
            ring(name+'_settling_tank',px,2,z,8,6.8,3.6,'oxidized')
            ring(name+'_tank_rim',px,4,z,8.4,7.4,0.65,'hazard')
            prism(name+'_motor',(px,1.2,z),(3,2.4,3),'steel')
    # Gantry rail geometry mirrors the JSON walkable deck, feet land on it.
    for rail in [-16,-8]:
        for side in [-1,1]:
            prism(name+'_gantry_guard',(x,6,rail),(55,2,0.28),'hazard')
        for offset in range(-26,27,8):
            prism(name+'_gantry_post',(x+offset,5.55,rail),(0.25,1.1,0.25),'steel')
    # Cable bridge hangs high and is deliberately decoration-only.
    for j in range(9):
        prism(name+'_cable',(x-40+j*10,15+math.sin(j*math.pi/8)*3,-114),(9,0.18,0.25),'hazard')

for x,z,label in [(-170,78,'FEEDER NORTH'),(-82,-78,'FEEDER SOUTH'),(0,78,'SWITCH PUMP'),(170,-82,'RELIEF VALVE')]:
    # Active gameplay locations occupy these marker centers; ornaments live
    # outside the 5 m interaction radius and cannot suggest fake collision.
    for side in [-1,1]:
        prism(label+'_mount',(x+side*7,1.7,z),(2,3.4,2),'concrete')
        ring(label+'_coil',x+side*7,4,z,2.1,1.5,0.75,'hazard')
    prism(label+'_signal',(x,7,z),(0.7,5,0.7),'lamp')

for material in materials:
    mesh=bpy.data.meshes.new('Blackwater_' + material)
    mesh.from_pydata(vertices[material],[],faces[material]);mesh.update()
    obj=bpy.data.objects.new('DistrictAssemblies_' + material,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(bpy.data.materials['BW_'+material])

bpy.ops.wm.save_as_mainfile(filepath=str(master/'blackwater-reclamation.blend'))
bpy.ops.export_scene.gltf(filepath=str(output/'blackwater-reclamation.glb'),export_format='GLB',
                          export_apply=True,export_yup=True,export_materials='EXPORT',
                          export_cameras=False,export_lights=False)
triangles=sum(len(f)*2 for f in faces.values())
print('BLACKWATER_ART',json.dumps(dict(batches=len(materials),quads=sum(map(len,faces.values())),
                                    triangles=triangles,glb=str(output/'blackwater-reclamation.glb'))))

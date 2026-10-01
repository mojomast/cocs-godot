"""Blender 4.5 background authoring; execute only when the parent grants export.

LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-horde/blackwater_blender.py
One editable .blend master; exports a batched, decoration-only GLB. Source
collisions/walkable decks are exclusively the matching generated JSON recipe.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
recipe = json.loads((root / 'godot/horde_maps/generated/blackwater-reclamation.json').read_text())
output = root / 'godot/horde_maps/art'
output.mkdir(exist_ok=True, parents=True)
master = root / 'tools/godot-horde/masters'
master.mkdir(exist_ok=True, parents=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0
materials = {
    'steel':(0.085, 0.16, 0.19, 1), 'oxidized':(0.16, 0.29, 0.32, 1),
    'concrete':(0.23, 0.31, 0.32, 1), 'hazard':(0.48, 0.30, 0.13, 1),
    'lamp':(0.20, 0.64, 0.68, 1),
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

def beam(name, start, end, radius, material, segments=8):
    # A real eight-sided pipe rather than boxes with dark face seams.
    a=Vector((start[0],-start[2],start[1]));b=Vector((end[0],-end[2],end[1]));axis=(b-a).normalized()
    side=axis.cross(Vector((0,0,1)))
    if side.length<0.05: side=axis.cross(Vector((1,0,0)))
    side.normalize();up=axis.cross(side).normalized()
    base=len(vertices[material])
    for center in (a,b):
        for i in range(segments):
            angle=2*math.pi*i/segments
            p=center+radius*(side*math.cos(angle)+up*math.sin(angle))
            vertices[material].append(tuple(p))
    for i in range(segments):
        j=(i+1)%segments
        faces[material].append((base+i,base+j,base+segments+j,base+segments+i))
    faces[material].append(tuple(base+i for i in reversed(range(segments))))
    faces[material].append(tuple(base+segments+i for i in range(segments)))

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
        for elevation in [4,9,14]:
            beam(name+'_pressure_pipe',(px,elevation,104),(x+side*25,elevation+1,82),0.25,'hazard')
            ring(name+'_pipe_flange',px,elevation,104,1.1,0.72,0.4,'steel')
    # Each district's heavy pumping drum is a source-aligned solid in the JSON.
    chamber_height=13+index*2
    for level in range(3,chamber_height,3):
        ring(name+'_chamber_hoop',x,level,112,8.2,7.0,0.55,'steel',16)
    ring(name+'_chamber_cap',x,chamber_height,112,8.6,6.4,1.2,'hazard',16)
    for side in [-1,1]:
        beam(name+'_header_main',(x+side*38,high*0.7,104),(x+side*8,chamber_height*0.78,112),0.58,'oxidized')
        beam(name+'_header_return',(x+side*8,chamber_height*0.7,112),(x+side*30,7,130),0.24,'hazard')
    # Big open service arches: pillars sit on the flanks, never across a route.
    for z in [-57,-5,57]:
        for side in [-1,1]:
            prism(name+'_arch_leg',(x+side*34,5.5,z),(2,11,2),'steel')
        prism(name+'_arch_lintel',(x,11,z),(70,2,2),'steel')
        for n in range(5):
            prism(name+'_luminaire',(x-24+n*12,10.1,z),(3,0.15,0.8),'lamp')
        for side in [-1,1]:
            beam(name+'_arch_brace',(x+side*34,2.5,z),(x+side*12,10,z),0.28,'oxidized')
            ring(name+'_bearing',x+side*34,5,z,1.4,1.0,0.6,'hazard')
    # Distinct low-profile machinery around the true center court, ground-bonded.
    for px in [x-34,x+34]:
        for z in [-82,78]:
            ring(name+'_settling_tank',px,2,z,8,6.8,3.6,'oxidized')
            ring(name+'_tank_rim',px,4,z,8.4,7.4,0.65,'hazard')
            prism(name+'_motor',(px,1.2,z),(3,2.4,3),'steel')
            for level in [0.5,2.0,3.5]:
                ring(name+'_tank_coil',px,level,z,7.7,7.15,0.22,'steel')
            beam(name+'_feed_pipe',(px,3.8,z),(x,6,z+side*4 if (side:=(-1 if z<0 else 1)) else z),0.25,'hazard')
    # Gantry rail geometry mirrors the JSON walkable deck, feet land on it.
    for rail in [-16,-8]:
        for side in [-1,1]:
            prism(name+'_gantry_guard',(x+side*16.5,6,rail),(23,2,0.28),'hazard')
        for offset in range(-26,27,8):
            if abs(offset)<5: continue
            prism(name+'_gantry_post',(x+offset,5.55,rail),(0.25,1.1,0.25),'steel')
    for offset in range(-26,27,4):
        prism(name+'_gantry_grating',(x+offset,5.035,-12),(0.18,0.035,7.5),'hazard')
    for side in [-1,1]:
        prism(name+'_gantry_lip',(x,5.05,-12+side*3.3),(55,0.08,0.1),'steel')
    # Cable bridge hangs high and is deliberately decoration-only.
    for j in range(9):
        prism(name+'_cable',(x-40+j*10,15+math.sin(j*math.pi/8)*3,-114),(9,0.18,0.25),'hazard')
    # Roof-mounted dry-channel valves are distinct from the first-person
    # interactable station; no inaccessible world prop promises a fake button.
    for z in [-118,126]:
        for side in [-1,1]:
            prism(name+'_inspection_pier',(x+side*12,1.4,z),(5,2.8,4),'concrete')
            beam(name+'_inspection_supply',(x+side*12,2.8,z),(x+side*12,6,z-7),0.32,'steel')

# Both sheltered 410-metre service-tunnel routes receive real roof/column
# collision from JSON. Ribs, conduits and ceiling fixtures are overhead trim.
for side in [-1,1]:
    z=side*169
    for x in range(-200,201,10):
        beam('tunnel_transverse',(x,7.85,z-7),(x,7.85,z+7),0.16,'oxidized')
        prism('tunnel_amber_fixture',(x,8.27,z),(3.4,0.12,0.36),'hazard')
        for pipe_z in [z-5,z+5]:
            ring('tunnel_valve_loop',x,7.6,pipe_z,0.52,0.38,0.18,'steel',8)
    for pipe_z in [z-6,z+6]:
        beam('tunnel_long_cable',(-204,7.7,pipe_z),(204,7.7,pipe_z),0.12,'lamp')

# Distinct circular spillway bowl: inaccessible high flywheel, two source
# collider pylons, cross-bracing. The fighting court between remains open.
for x in [140,200]:
    prism('spillway_pylon_sleeve',(x,8.5,0),(2.6,17,2.6),'oxidized')
    beam('spillway_flywheel_suspension',(x,17,0),(170,23,0),0.45,'steel')
for y in [22.5,23.5]: ring('spillway_flywheel',170,y,0,18,16.8,0.6,'hazard',32)
for angle in range(0,360,30):
    r=math.radians(angle)
    beam('spillway_wheel_spoke',(170,23,0),(170+17*math.cos(r),23,17*math.sin(r)),0.2,'steel')

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

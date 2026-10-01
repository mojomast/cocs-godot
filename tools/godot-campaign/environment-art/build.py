"""Generate editable original biome meshes and compact GLBs; run with Blender --background --python build.py.

All meshes occupy approximately unit XYZ, ground at Y=0 (Blender Z=0).
Export converts Blender Z-up to glTF Y-up. No image dependencies.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "godot/campaign/art/environment"
SOURCE = ROOT / "tools/godot-campaign/environment-art"
OUT.mkdir(parents=True, exist_ok=True)
(SOURCE / "blend").mkdir(exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

COLORS = {
    "bark": (.16,.115,.08), "bark_light": (.31,.23,.14),
    "leaf": (.16,.28,.11), "leaf_light": (.36,.44,.20), "moss": (.25,.37,.16),
    "reed": (.42,.49,.24), "reed_gold": (.65,.51,.27), "seed": (.26,.19,.13),
    "mud": (.36,.29,.23), "wetstone": (.36,.41,.39), "stone": (.47,.49,.44),
    "basalt": (.16,.19,.22), "basalt_edge": (.34,.36,.36), "slag": (.24,.22,.23),
    "rust": (.43,.25,.16), "iron": (.26,.31,.33), "oxide": (.56,.38,.23),
    "highland": (.40,.44,.43), "lichen": (.57,.60,.38), "drygrass": (.48,.48,.27),
}

def mat(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*COLORS[name], 1)
        m.use_nodes = True
        principled = m.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = (*COLORS[name], 1)
        principled.inputs["Roughness"].default_value = .82
        principled.inputs["Metallic"].default_value = .55 if name == "iron" else .0
    return m

def finish(obj, name, material):
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat(material))
    return obj

def tapered(a, b, r0, r1, name, material, sides=7):
    direction = Vector(b) - Vector(a)
    midpoint = (Vector(a)+Vector(b))*.5
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=r0, radius2=r1,
                                    depth=direction.length, location=midpoint)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat('Z','Y').to_euler()
    return finish(obj,name,material)

def orb(name, location, scale, material, segments=10, rings=5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj=bpy.context.object
    obj.scale=scale
    return finish(obj,name,material)

def blade(name, points, widths, material):
    """Curved double-sided leaf, thick enough to read as solid at oblique angles."""
    verts=[]
    for i,p in enumerate(points):
        tangent = Vector(points[min(i+1,len(points)-1)]) - Vector(points[max(0,i-1)])
        lateral = tangent.cross(Vector((0,0,1))).normalized()
        if lateral.length < .1: lateral=Vector((1,0,0))
        verts.extend((Vector(p)-lateral*widths[i], Vector(p)+lateral*widths[i]))
    faces=[]
    for i in range(len(points)-1):
        faces.extend(((i*2,i*2+1,i*2+3,i*2+2),(i*2+2,i*2+3,i*2+1,i*2)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat(material))
    return obj

def rock(name, material, accent, seed=0, layers=4, radius=.43, top=.88):
    rng=random.Random(seed)
    sides=9
    verts=[]
    for j in range(layers):
        h=j/(layers-1)
        for i in range(sides):
            angle=i*math.tau/sides
            irregular=1+.12*math.sin(angle*3+seed)+.10*rng.uniform(-1,1)
            r=radius*irregular*([.72,1.12,.87,.56][j] if layers==4 else [1,1.10,.96,.82,.56][j])
            verts.append((math.cos(angle)*r+.10*h,math.sin(angle)*r-.045*h,h*top))
    faces=[]
    for j in range(layers-1):
        for i in range(sides):
            n=(i+1)%sides
            faces.append((j*sides+i,j*sides+n,(j+1)*sides+n,(j+1)*sides+i))
    faces.append(tuple(reversed(tuple(range(sides)))))
    faces.append(tuple((layers-1)*sides+i for i in range(sides)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat(material))
    obj.data.materials.append(mat(accent))
    for polygon in mesh.polygons:
        polygon.material_index = 1 if polygon.index % 7 == 0 or polygon.index > sides*(layers-1) else 0
    return obj

def tree(seed, sparse=False):
    rng=random.Random(seed)
    tapered((0,0,-.04),(.018,0,.77),.09,.023,'furrowed trunk','bark',9)
    for i in range(5):
        a=i*math.tau/5 +seed*.3
        tapered((0,0,.055),(.19*math.cos(a),.19*math.sin(a),.015),.038,.005,'spreading root','bark_light',5)
    for i in range(7 if not sparse else 5):
        a=i*2.399+seed*.49
        z=.40+i*.043
        reach=.20+(i%3)*.052
        endpoint=(reach*math.cos(a),reach*math.sin(a),.73+(i%2)*.105)
        tapered((.015,0,z),endpoint,.032,.009,'forked branch','bark',6)
        if not sparse:
            orb('leaf clump',endpoint,(.16,.105,.13),'leaf_light' if i%3==0 else 'leaf',8,4)
    if not sparse:
        orb('broken canopy',(0,0,.83),(.18,.16,.12),'leaf',9,5)
    else:
        for i in range(3):
            a=i*2.2
            orb('wind clipped crown',(.12*math.cos(a),.12*math.sin(a),.77+i*.06),(.14,.09,.055),'drygrass',8,4)

def fern(seed, reed=False, dry=False):
    for i in range(7 if not reed else 8):
        a=i*math.tau/(7 if not reed else 8)+seed*.14
        d=(math.cos(a),math.sin(a))
        if reed:
            height=.72+(i%3)*.12
            tapered((0,0,0),(.13*d[0],.13*d[1],height),.016,.005,'reed stem','reed',5)
            if i%3==0: orb('cattail head',(.13*d[0],.13*d[1],height-.07),(.023,.023,.085),'seed',7,5)
            blade('reed leaf',[(0,0,.03),(.09*d[0],.09*d[1],.27),(.22*d[0],.22*d[1],.5)], [.014,.028,0], 'reed_gold' if i%3==0 else 'reed')
        else:
            blade('serrated frond',[(0,0,.035),(.11*d[0],.11*d[1],.29),(.34*d[0],.34*d[1],.48),(.45*d[0],.45*d[1],.32)], [.02,.08,.09,0], 'drygrass' if dry else 'leaf_light' if i%3==0 else 'leaf')
            for j in (1,2):
                base=.18+j*.08
                side=Vector((-d[1],d[0],0))
                center=Vector((base*d[0],base*d[1],.27+j*.07))
                for s in (-1,1):
                    blade('pinna', [center,center+Vector((d[0]*.10,d[1]*.10,.04))+side*s*.07], [.035,0], 'leaf' if not dry else 'drygrass')

def logs():
    tapered((-.43,0,.12),(.44,.07,.14),.14,.105,'weathered fallen log','bark',10)
    for x in (-.35,-.13,.19,.39):
        tapered((x,-.095,.12),(x+.01,.12,.15),.012,.012,'bark fissure','bark_light',5)
    for i in range(4):
        a=i*1.4
        orb('moss pad',(-.24+i*.14,.06*math.sin(a),.22),(.105,.085,.021),'moss',8,4)

def debris(highland=False):
    material='iron' if highland else 'rust'
    for i in range(3):
        a=i*math.tau/3+.2
        tapered((0,0,.10),(.38*math.cos(a),.38*math.sin(a),.03),.036,.02,'twisted bracket',material,4)
    tapered((0,0,.02),(0,0,.27),.10,.08,'cylindrical salvage','iron',8)
    orb('oxidized cap',(0,0,.28),(.105,.105,.025),'oxide' if not highland else 'lichen',8,4)

def produce(key, builder):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    builder()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=key
    # Godot batches the imported Mesh directly rather than instancing the glTF
    # node; bake the active object's transforms so roots stay at local Y=0.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'blend'/f'{key}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{key}.glb'), export_format='GLB', use_selection=True,
                              export_apply=True, export_materials='EXPORT', export_yup=True)
    print('ENV_ASSET',key,len(obj.data.vertices),len(obj.data.polygons),(OUT/f'{key}.glb').stat().st_size)

ASSETS={
 'root_tree':lambda:tree(4), 'crown_tree':lambda:tree(9,True),
 'root_fern':lambda:fern(3), 'silt_reed':lambda:fern(5,True),
 'ember_scrub':lambda:fern(7,dry=True), 'crown_tuft':lambda:fern(2,dry=True),
 'root_rock':lambda:rock('mossy shoulder','stone','moss',11),
 'silt_stone':lambda:rock('water-smoothed stone','wetstone','mud',23,top=.66),
 'ember_basalt':lambda:rock('stacked basalt','basalt','basalt_edge',35,5,top=.83),
 'crown_boulder':lambda:rock('lichen highland boulder','highland','lichen',49,top=.68),
 'root_log':logs, 'silt_bank':lambda:rock('riverbank cobble','mud','wetstone',57,top=.34),
 'ember_slag':lambda:rock('cooled slag','slag','rust',68,top=.31),
 'ember_debris':lambda:debris(False), 'crown_debris':lambda:debris(True),
}
for key, builder in ASSETS.items():produce(key,builder)

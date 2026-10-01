"""Original, dimensionless closed structural shells. Run in Blender 4.5 background.

Local footprint is [-.5,.5] X/Z, base Y=0, roof Y=1. Every vertex stays
inside the corresponding authoritative block, including the bevels/trim.
"""
import bpy
import math
from pathlib import Path
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'godot/campaign/art/structures'
BLENDS = Path(__file__).resolve().parent / 'blend'
OUT.mkdir(parents=True, exist_ok=True)
BLENDS.mkdir(parents=True, exist_ok=True)

PALETTES = {
    'relay': ['#444e4c', '#7a8171', '#303b3c', '#b68357', '#849e95'],
    'outpost': ['#4c5350', '#8b8874', '#263b3b', '#a47854', '#9ea994'],
    'pump': ['#435a5e', '#8c9080', '#293f4a', '#af8558', '#85bbb4'],
    'abutment': ['#626f70', '#a4a69a', '#354a50', '#a48259', '#8db2b0'],
    'refinery': ['#554d48', '#958275', '#35383a', '#b87748', '#d5a66c'],
    'uplink': ['#4f494b', '#968679', '#383d42', '#cb8b51', '#c3b598'],
    'receiver': ['#45535b', '#91a3a0', '#263c48', '#bf9766', '#86b7be'],
    'gate': ['#49555a', '#abb0a3', '#364a4e', '#bd9867', '#a1c2bd'],
}


def srgb(x):
    x = int(x, 16) / 255
    return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4


def material(name, hexcolor, metallic, roughness):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*[srgb(hexcolor[i:i + 2]) for i in (1, 3, 5)], 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = m.diffuse_color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return m


def box(name, loc, scale, mat, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Machined edge / worn corner', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier = obj.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    return obj


def tube(name, loc, radius, depth, mat, vertices=10, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def build(kind, lod):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    colors = PALETTES[kind]
    mats = [material(f'{kind}_{n}', color, .65 if n in (0, 2, 3) else .15, .73 if n in (0, 1) else .43)
            for n, color in enumerate(colors)]
    fine = lod == 0
    # Primary closed masonry/metal mass: no false portals or passable arches.
    core_width = .83 if kind in ('receiver', 'gate', 'refinery') else .88
    box('Closed structural core', (0, .47, 0), (core_width, .91, .85), mats[0], .022)
    box('Cast foundation, sealed to blocked footprint', (0, .075, 0), (.97, .15, .97), mats[1], .012)
    box('Continuous cap flashing', (0, .94, 0), (.97, .10, .97), mats[2], .012)
    # Facade planes and panel recesses sit inside the box footprint.
    for side in (-1, 1):
        z = side * .435
        for x in (-.32, .32):
            box('Exposed load-bearing pier', (x, .52, z), (.115, .75, .115), mats[1], .009)
        box('Recessed blind service bay', (0, .50, side * .433), (.50, .47, .018), mats[2], .005)
        box('Gasketed hatch face', (0, .50, side * .448), (.40, .36, .012), mats[0], .004)
        if fine:
            for y in (.36, .43, .50, .57, .64):
                box('Slatted ventilation', (0, y, side * .458), (.32, .013, .014), mats[3], .003)
            for x in (-.16, .16):
                tube('Hatch bolt', (x, .31, side * .462), .013, .015, mats[1], 8, (math.pi/2, 0, 0))
    for side in (-1, 1):
        box('Side buttress', (side * .44, .35, 0), (.095, .57, .57), mats[1], .012)
        box('Side inset dark reveal', (side * .477, .62, 0), (.012, .24, .42), mats[2], .002)

    if kind in ('relay', 'outpost'):
        # Low, shingled weather hood; all ribs are tied to the original mass.
        for z in (-.29, 0, .29):
            box('Forest station roof rib', (0, .865, z), (.83, .07, .055), mats[3], .01)
        for x in (-.24, .24):
            box('Relay cable trunk', (x, .74, -.478), (.055, .33, .028), mats[2], .008)
        if kind == 'relay':
            box('Fallen mast socket', (0, .945, 0), (.41, .07, .40), mats[3], .01)
            for x in (-.22, .22):
                box('Sheared mast mounting rail', (x, .89, 0), (.035, .12, .72), mats[1], .006)
    elif kind in ('pump', 'abutment'):
        for x in (-.30, .30):
            tube('Intake valve collar', (x, .76, -.434), .105, .08, mats[3], 12)
            tube('Intake dark center', (x, .76, -.482), .059, .01, mats[2], 12)
        if kind == 'abutment':
            for y in (.22, .43, .67):
                box('Flood wall terrace course', (0, y, 0), (.99, .055, .98), mats[1], .012)
        else:
            for z in (-.24, 0, .24):
                box('Grated pump service roof', (0, .994, z), (.72, .011, .05), mats[3], .001)
    elif kind in ('refinery', 'uplink'):
        for x in (-.28, .28):
            box('Heavy refinery corner brace', (x, .5, -.47), (.085, .78, .046), mats[3], .006)
        for y in (.24, .75):
            box('Heat-exchanger header', (0, y, -.48), (.57, .046, .027), mats[1], .005)
        if kind == 'refinery':
            for x in (-.19, .19):
                tube('Exhaust stack in roof silhouette', (x, .905, .12), .055, .18, mats[2], 10)
        else:
            for z in (-.2, .2):
                box('Uplink heat vanes', (0, .92, z), (.50, .12, .045), mats[3], .006)
    else:
        # Crown's repeated radial forms read as an engineered receiver / gate.
        for x in (-.27, .27):
            box('Receiver vertical spine', (x, .53, -.477), (.07, .73, .032), mats[3], .005)
        box('Signal aperture, sealed face', (0, .74, -.478), (.35, .075, .03), mats[4], .007)
        if kind == 'receiver':
            for z in (-.29, .29):
                box('Antenna foot', (0, .98, z), (.49, .026, .08), mats[1], .003)
        else:
            box('Gate tympanum', (0, .83, -.476), (.64, .075, .038), mats[1], .005)
            for x in (-.20, .20):
                box('Gate axial relief', (x, .43, -.48), (.035, .56, .026), mats[4], .003)

    # Collapse equal-material objects to one surface each: bounded draw count.
    for mat in mats:
        objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.data.materials[0] == mat]
        if not objects:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        objects[0].name = mat.name
    # The modeling helper uses Y as up; Blender glTF uses Blender Z as up.
    # Rotate in world space before its Y-up conversion, preserving the fitted
    # normalized footprint and keeping the cap above the foundation in Godot.
    upright = Matrix.Rotation(math.pi / 2, 4, 'X')
    for obj in bpy.context.scene.objects:
        obj.matrix_world = upright @ obj.matrix_world
    bpy.ops.wm.save_as_mainfile(filepath=str(BLENDS / f'{kind}-{lod}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f'{kind}-{lod}.glb'), export_format='GLB', export_yup=True,
                               export_apply=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
    print(f'STRUCTURE {kind} LOD{lod}: {len(bpy.context.scene.objects)} material batches')


for style in PALETTES:
    for detail in (0, 1):
        build(style, detail)

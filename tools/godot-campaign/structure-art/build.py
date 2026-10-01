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


def beam(name, start, end, width, depth, mat):
    a, b = start, end
    obj = box(name, ((a[0]+b[0])/2, (a[1]+b[1])/2, a[2]),
              (width, math.dist(a, b), depth), mat, .006)
    obj.rotation_euler.z = -math.atan2(b[0]-a[0], b[1]-a[1])


def roof(name, mat, ridge=.975):
    # Four real pitched sheet faces / two solid closed gables; no floating trim.
    vertices = [(-.48, .82, -.485), (0, ridge, -.485), (.48, .82, -.485),
                (-.48, .82, .485), (0, ridge, .485), (.48, .82, .485)]
    faces = [(0, 3, 4, 1), (1, 4, 5, 2), (0, 1, 2), (3, 5, 4)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)


def build(kind, lod, profile='top'):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.data.orphans_purge(do_recursive=True)
    colors = PALETTES[kind]
    mats = [material(f'{kind}_{n}', color, .58 if n in (0, 2, 3) else .14, .81 if n in (0, 1) else .49)
            for n, color in enumerate(colors)]
    fine = lod == 0
    # Continuous support on all stories; base plinth only at ground level and
    # roof termination only at the final story. All faces are solid/closed.
    if kind == 'receiver':
        tube('Hexagonal receiver monolith', (0, .50, 0), .43, .97, mats[0], 6, (math.pi/2, 0, 0))
    elif kind == 'outpost':
        box('Forest service cabin', (0, .43, 0), (.82, .84, .85), mats[0], .025)
    elif kind == 'abutment':
        box('Broad coursed river pier', (0, .50, 0), (.91, .98, .93), mats[1], .012)
    elif kind == 'gate':
        box('Closed fortified gate pier', (0, .50, 0), (.90, .98, .86), mats[0], .028)
    else:
        width = .76 if kind == 'relay' else .84
        box('Closed machinery-bearing mass', (0, .50, 0), (width, .97, .84), mats[0], .025)
    if kind not in ('relay', 'outpost'):
        # Story courses may retain a shadow seam, but the structural interior
        # runs flush from 0 to 1. Adjacent modules meet at a real, opaque
        # load-bearing core rather than revealing a 15 cm air gap.
        box('Unbroken inner load core', (0, .50, 0), (.68, 1.0, .70), mats[2], 0)
    if profile == 'base':
        box('Single ground footing', (0, .055, 0), (.98, .11, .98), mats[1], .012)
    if kind == 'outpost':
        if profile == 'top':
            roof('Folded pitched forest hood', mats[1])
            for z in (-.36, .36):
                beam('Exposed pitched timber strut', (-.45, .84, z), (0, .973, z), .027, .03, mats[3])
                beam('Exposed pitched timber strut', (0, .973, z), (.45, .84, z), .027, .03, mats[3])
        for side in (-1, 1):
            box('Inset shutter frame', (0, .48, side*.434), (.44, .32, .015), mats[1], .008)
            box('Sealed shutters', (0, .48, side*.445), (.35, .23, .012), mats[2], .004)
            if fine:
                for y in (.41, .47, .53): box('Weathered shutter rails', (0, y, side*.46), (.34, .012, .012), mats[3], .002)
        for x in (-.36, .36): box('Corner timber', (x, .44, -.45), (.065, .76, .065), mats[1], .008)
    elif kind == 'relay':
        # Fallen relay mount remains unmistakable even without a tall free mast.
        for x in (-.37, .37):
            box('Continuous relay uprights', (x, .52, -.435), (.075, .87, .08), mats[1], .009)
        for x in (-.21, .21):
            box('Exposed vertical cable trunk', (x, .51, -.442), (.06, .76, .042), mats[2], .006)
        box('Sealed coil cavity', (0, .50, -.453), (.26, .42, .025), mats[3], .01)
        if profile == 'top':
            box('Low mast saddle', (0, .935, 0), (.50, .11, .49), mats[1], .012)
            box('Sheared relay cradle', (0, .993, 0), (.29, .012, .47), mats[3], .002)
        if fine:
            for y in (.30, .42, .54, .66): box('Coil winding', (0, y, -.472), (.20, .014, .016), mats[2], .002)
    elif kind == 'pump':
        # Substantial opposed impeller housings and manifolds, not square hatches.
        for x in (-.21, .21):
            tube('Large pump bowl', (x, .49, -.435), .167, .08, mats[1], 14)
            tube('Sealed dark impeller disk', (x, .49, -.481), .118, .012, mats[2], 14)
            tube('Central spindle boss', (x, .49, -.489), .040, .012, mats[3], 10)
            box('Vertical water riser', (x, .50, .44), (.07, 1.0, .07), mats[3], 0)
        box('Cross-connected manifold', (0, .82, -.445), (.70, .075, .08), mats[3], .009)
        if profile == 'top':
            box('Gasketed pump weather lid', (0, .975, 0), (.94, .04, .93), mats[1], .01)
        if fine:
            for x in (-.21, .21):
                for a in range(8):
                    angle = a*math.tau/8
                    tube('Impeller rim fastener', (x + .142*math.cos(angle), .49 + .142*math.sin(angle), -.486),
                         .009, .008, mats[3], 6)
    elif kind == 'abutment':
        for y in (.24, .49, .74):
            box('Cut-stone continuous bed course', (0, y, -.475), (.94, .055, .027), mats[0], .006)
        for x in (-.36, 0, .36):
            box('Vertical masonry bearing rib', (x, .50, -.483), (.055, 1.0, .024), mats[0], 0)
        for x in (-.38, .38):
            beam('Inclined flood buttress', (x, .11, -.46), (x*.70, .85, -.46), .075, .045, mats[2])
        if profile == 'top': box('Bridge pier bearing plate', (0, .98, 0), (.96, .03, .95), mats[2], .006)
        if fine:
            for x in (-.18, .18):
                box('Stone key seam', (x, .37, -.492), (.012, .20, .012), mats[2], .001)
    elif kind == 'refinery':
        # Heat exchanger is a real bank of long parallel blades between headers.
        for x in (-.35, .35):
            box('Vertical refractory support', (x, .50, -.44), (.09, 1.0, .085), mats[1], 0)
        for x in (-.23, -.115, 0, .115, .23):
            box('External heat-exchanger fin', (x, .50, -.467), (.045, .62, .055), mats[3], .007)
        for y in (.18, .83): box('Exchanger header', (0, y, -.47), (.72, .075, .055), mats[2], .006)
        if profile == 'top':
            for x in (-.26, .26):
                tube('Compact chimney behind header', (x, .91, .20), .07, .17, mats[2], 10, (math.pi/2, 0, 0))
        if fine:
            for y in (.28, .70): box('Oxidized coupling', (0, y, -.489), (.49, .024, .012), mats[1], .003)
    elif kind == 'uplink':
        for x in (-.37, .37):
            box('Full-height insulated support', (x, .50, -.438), (.065, 1.0, .075), mats[1], 0)
        box('Deep recessed radiator', (0, .50, -.437), (.55, .69, .024), mats[2], .005)
        for x in (-.24, -.12, 0, .12, .24):
            box('Copper thermal vane', (x, .50, -.473), (.034, .65, .055), mats[3], .003)
        if profile == 'top':
            for x in (-.36, .36):
                beam('Slanted antenna support', (x, .76, -.42), (x*.60, .982, -.42), .055, .05, mats[1])
        if fine:
            for y in (.20, .80): box('Heat header', (0, y, -.483), (.56, .025, .02), mats[1], .004)
    elif kind == 'receiver':
        # Faceted central spine and unbroken external rails define the array.
        for x in (-.38, .38):
            box('Continuous receiver spar', (x, .50, -.38), (.065, 1.0, .075), mats[1], 0)
        box('Sealed deep signal recess', (0, .53, -.388), (.39, .30, .028), mats[2], .008)
        box('Receiver glass-metal plate', (0, .53, -.407), (.29, .20, .018), mats[4], .006)
        if profile == 'top':
            box('Radial receiver crown', (0, .968, 0), (.72, .053, .74), mats[3], .009)
        if fine:
            for y in (.45, .54, .63): box('Signal slot divider', (0, y, -.422), (.25, .011, .012), mats[3], .002)
    else:  # gate
        for x in (-.38, .38):
            beam('Reinforced sloping closed jamb', (x, .11, -.443), (x*.85, .87, -.443), .11, .06, mats[1])
        box('Blind reinforced portal face', (0, .49, -.445), (.47, .63, .026), mats[2], .007)
        box('Central steel seal spine', (0, .49, -.465), (.07, .56, .022), mats[3], .004)
        if profile == 'top': box('Stone gate lintel', (0, .955, 0), (.95, .08, .91), mats[1], .014)
        if fine:
            for y in (.26, .49, .72):
                box('Gate reinforcement bar', (0, y, -.48), (.48, .025, .016), mats[1], .003)

    # The route sees either side of the unrotated recipe block. Reproduce the
    # functional elevation on the reverse wall, rather than leaving a blank
    # dark cube whenever the route approaches from +Z. Roofs/core are excluded.
    if kind != 'outpost':
        front_parts = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and obj.location.z < -.35]
        for obj in front_parts:
            back = obj.copy()
            back.data = obj.data.copy()
            back.name = obj.name + ' / reverse elevation'
            bpy.context.collection.objects.link(back)
            back.location.z *= -1
    # Side-facing elevations have their own load systems; these are particularly
    # important for the long route views approaching the pump and Crown fins.
    if kind in ('pump', 'refinery', 'uplink', 'receiver', 'gate', 'relay'):
        side_mat = mats[3] if kind in ('pump', 'refinery', 'uplink', 'relay') else mats[1]
        for side in (-1, 1):
            for y in (.24, .50, .76):
                box('Side maintenance rib', (side*.44, y, 0), (.045, .035, .69), side_mat, .005)
            if kind in ('uplink', 'receiver', 'relay'):
                for z in (-.26, .26):
                    box('Side continuous rail', (side*.453, .50, z), (.034, 1.0, .045), side_mat, 0)
            elif kind == 'pump':
                box('Side vertical pressure header', (side*.46, .50, 0), (.05, 1.0, .09), mats[1], 0)
            elif kind == 'refinery':
                for z in (-.21, 0, .21):
                    box('Side exchanger cooling fin', (side*.46, .50, z), (.06, 1.0, .045), side_mat, 0)
            else:
                for z in (-.24, .24):
                    box('Side gate bearing spar', (side*.46, .50, z), (.054, 1.0, .058), side_mat, 0)

    # Bake angled braces and cylinder orientations before batching: otherwise
    # a rotated active object makes the imported AABB overly conservative.
    for obj in list(bpy.context.scene.objects):
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
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
    tag = f'{kind}-{profile}-{lod}'
    bpy.ops.wm.save_as_mainfile(filepath=str(BLENDS / f'{tag}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f'{tag}.glb'), export_format='GLB', export_yup=True,
                               export_apply=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
    print(f'STRUCTURE {tag}: {len(bpy.context.scene.objects)} material batches')


for style in PALETTES:
    for profile in (('top',) if style in ('relay', 'outpost') else ('base', 'shaft', 'top')):
        for detail in (0, 1):
            build(style, detail, profile)

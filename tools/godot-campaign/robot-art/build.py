"""Author six articulated security automata in Blender; export rigid GLB assemblies.

Run in background Blender with -t 2. All dimensions are in Godot metres, Y-up;
the glTF exporter performs Blender's Z-up conversion. Each object is local to
the existing Godot joint named by its suffix (L0_Chassis, L0_Hip0, ...).
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "godot/campaign/art/robots"
OUTPUT.mkdir(parents=True, exist_ok=True)
SOURCE = Path(__file__).resolve().parent / 'blend'
SOURCE.mkdir(parents=True, exist_ok=True)
KINDS = ("scrapper", "skirmisher", "sentinel", "mortar", "bulwark", "warden")
PALETTES = {
    "scrapper": (0.47, 0.27, 0.12, 1),
    "skirmisher": (0.27, 0.49, 0.41, 1),
    "sentinel": (0.23, 0.39, 0.54, 1),
    "mortar": (0.49, 0.36, 0.32, 1),
    "bulwark": (0.19, 0.38, 0.44, 1),
    "warden": (0.53, 0.19, 0.14, 1),
}
DARK = (0.045, 0.073, 0.105, 1)
STEEL = (0.37, 0.49, 0.54, 1)
EDGE = (0.68, 0.68, 0.58, 1)
RECESS = (0.025, 0.037, 0.055, 1)
LAMP = (1.0, 0.31, 0.09, 1)
parts = {}
material = None


def save_piece(name, color, bevel=0.0):
    obj = bpy.context.object
    if bevel:
        mod = obj.modifiers.new("machined edge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.affect = 'EDGES'
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    attribute = obj.data.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='CORNER')
    for loop in attribute.data:
        loop.color = color
    parts.setdefault(name, []).append(obj)
    return obj


def box(name, pos, size, color, bevel=0.0, angle=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    save_piece(name, color, bevel)


def cyl(name, pos, radius, depth, color, vertices=10, axis='UP'):
    # Blender's native cylinder axis is Z, which exports as Godot's vertical Y.
    # Explicit Y means a front-facing cylinder along Godot -Z (optics/barrels).
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                      location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    if axis == 'Y':
        obj.rotation_euler.x = math.pi / 2
    elif axis == 'X':
        obj.rotation_euler.y = math.pi / 2
    save_piece(name, color, min(0.016, radius * 0.12))


def link(name, a, b, radius, color, facets=8):
    # Coordinates are supplied in Godot Y-up; Blender swaps Y and -Z.
    start = Vector((a[0], -a[2], a[1]))
    end = Vector((b[0], -b[2], b[1]))
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=facets, radius=radius,
                                      depth=direction.length, location=(start + end) / 2)
    bpy.context.object.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    save_piece(name, color, 0.012)


def build(kind, lod):
    color = PALETTES[kind]
    biped = kind in ('skirmisher', 'bulwark')
    heavy = kind in ('mortar', 'bulwark', 'warden')
    height = 1.12 if biped else (0.72 if heavy else 0.48)
    width = 0.38 if kind == 'skirmisher' else (1.05 if kind == 'warden' else 0.72)
    count = 2 if biped else (3 if kind == 'sentinel' else (6 if kind == 'warden' else 4))
    key = lambda name: f'L{lod}_{name}'
    detail = lod == 0
    mid = lod < 2
    chassis = key('Chassis')
    # Broad massing remains inside original class hit-volume envelope.
    # Recess the black frame below the bevel's lowest upper edge (y=.165).
    # Its previous y=.19 top broke through the enamel shoulder as triangles.
    box(chassis, (0, -0.045, 0), (width, 0.37, 0.84 if not biped else 0.56), DARK, 0.07)
    box(chassis, (0, 0.085, -0.015), (width * 1.05, 0.34, 0.72 if not biped else 0.51), color, 0.09)
    box(chassis, (0, 0.24, 0.08), (width * 0.85, 0.09, 0.36), STEEL, 0.024)
    if mid:
        box(chassis, (0, -0.17, 0), (width * 0.72, 0.13, 0.56), RECESS, 0.025)
        for side in (-1, 1):
            box(chassis, (side * width * 0.46, 0.085, 0.0), (0.12, 0.25, 0.56), color, 0.032)
        if kind in ('mortar', 'warden'):
            for side in (-1, 1):
                box(chassis, (side * width * 0.36, 0.27, 0.16), (0.19, 0.12, 0.39), DARK, 0.03)
    if detail:
        for side in (-1, 1):
            # Keep this shoulder clean. An inset silver strip formerly cut
            # across the main shell's bevel and exposed thin sliver triangles.
            # Side-pod vent slits sit outside the skin instead of under turret.
            for z in (-0.17, -0.08, 0.01):
                box(chassis, (side * (width * 0.46 + 0.067), 0.08, z),
                    (0.014, 0.12, 0.027), RECESS, 0.002)
        box(chassis, (0, -0.02, -0.377), (width * 0.5, 0.12, 0.035), DARK, 0.012)
    if kind == 'skirmisher':
        box(chassis, (-0.29, 0.09, 0), (0.3, 0.25, 0.40), color, 0.055)
        link(chassis, (-0.29, 0.1, 0), (-0.3, -0.38, -0.13), 0.045, STEEL)
    if kind == 'scrapper':
        for side in (-1, 1):
            box(chassis, (side * 0.28, 0.10, -0.34), (0.17, 0.12, 0.36), EDGE, 0.035)
    if kind == 'warden':
        for side in (-1, 1):
            box(chassis, (side * 0.50, 0.13, 0.26), (0.22, 0.2, 0.38), EDGE, 0.037)

    for i in range(count):
        side = -1 if i % 2 == 0 else 1
        origin = [side * width * 0.4, height - 0.12, 0]
        tip = [side * (width * 0.5 + 0.38), 0.09, -0.5 if i < 2 else 0.5]
        if biped:
            tip = [side * width * 0.45, 0.09, 0]
        elif count == 6:
            tip[2] = (-0.65, -0.65, 0, 0, 0.65, 0.65)[i]
        elif count == 3:
            angle = math.tau * i / 3
            tip = [math.sin(angle) * 0.85, 0.09, math.cos(angle) * 0.85]
        origin[2] = tip[2] * 0.5
        knee = (tip[0] - origin[0], (tip[1] - origin[1]) * 0.48,
                (tip[2] - origin[2]) * 0.6 + (0.16 if biped else 0))
        end = tuple(tip[n] - origin[n] - knee[n] for n in range(3))
        upper, shin = key(f'Hip{i}'), key(f'Shin{i}')
        link(upper, (0, 0, 0), knee, 0.10 if heavy else 0.07, DARK)
        link(upper, tuple(v * 0.17 for v in knee), tuple(v * 0.82 for v in knee),
             0.14 if heavy else 0.095, color)
        if mid:
            cyl(upper, (0, 0, 0), 0.11, 0.15, STEEL, 8, 'X')
            if detail:
                link(upper, tuple(v * 0.12 for v in knee), tuple(v * 0.72 for v in knee),
                     0.035, EDGE, 6)
        # LOD2 is baked as one upper assembly to preserve the old hip-only gait.
        if lod == 2:
            end_in_hip = tuple(knee[n] + end[n] for n in range(3))
            link(upper, knee, end_in_hip, 0.10 if heavy else 0.063, STEEL, 6)
            box(upper, end_in_hip, (0.25 if heavy else 0.18, 0.18, 0.38 if biped else 0.23), DARK, 0.022)
        else:
            link(shin, (0, 0, 0), end, 0.105 if heavy else 0.07, STEEL)
            box(shin, end, (0.25 if heavy else 0.18, 0.18, 0.38 if biped else 0.23), DARK, 0.026)
            # Boot bottom is exactly y=0 in world relative to FeetOrigin.
            if detail:
                box(shin, (end[0], end[1] + 0.105, end[2] - 0.035),
                    (0.19 if heavy else 0.13, 0.09, 0.22), color, 0.024)
                cyl(shin, (0, 0, 0), 0.11, 0.16, EDGE, 8, 'X')

    turret = key('Turret')
    # Seat the vertical turntable just below the chassis top: the prior
    # horizontal cylinder cut through the plate and caused jagged streaks.
    cyl(turret, (0, 0.12, 0), width * 0.32, 0.19, RECESS, 8 if mid else 6)
    box(turret, (0, 0.12, 0), (width * 0.84, 0.15, 0.45), color, 0.052)
    box(turret, (0, 0.19, -0.11), (width * 0.68, 0.10, 0.24), DARK, 0.025)
    if mid:
        for side in (-1, 1):
            box(turret, (side * width * 0.34, 0.22, -0.07), (0.10, 0.22, 0.33), EDGE, 0.029)
    if detail:
        for side in (-1, 1):
            box(turret, (side * width * 0.21, 0.279, 0.045), (0.115, 0.016, 0.16), RECESS, 0.005)
    if kind == 'warden':
        for side in (-1, 1):
            box(turret, (side * 0.49, 0.36, 0.04), (0.17, 0.59, 0.23), color, 0.046, -side * 0.18)
            box(turret, (side * 0.49, 0.53, -0.089), (0.095, 0.15, 0.025), LAMP, 0.006)
    if kind == 'sentinel':
        cyl(turret, (0, 0.32, -0.07), 0.17, 0.14, EDGE, 10)
    if kind == 'skirmisher':
        link(turret, (-0.2, 0.2, 0), (-0.27, 0.54, 0.1), 0.027, STEEL, 6)

    optic = key('Optics')
    box(optic, (0, 0.12, -width * 0.36), (width * 0.56, 0.12, 0.055), RECESS, 0.019)
    if kind in ('sentinel', 'warden'):
        for x in (-width * 0.15, 0, width * 0.15):
            cyl(optic, (x, 0.12, -width * 0.397), 0.049 if mid else 0.043, 0.018, LAMP, 8, 'Y')
    else:
        box(optic, (0, 0.12, -width * 0.399), (width * 0.42, 0.045, 0.018), LAMP, 0.012)

    gun = key('Weapon')
    if kind == 'scrapper':
        for side in (-1, 1):
            link(gun, (side * 0.19, 0, 0), (side * 0.34, -0.08, -0.44), 0.092, STEEL)
            box(gun, (side * 0.34, -0.08, -0.45), (0.14, 0.12, 0.09), EDGE, 0.02)
    elif kind == 'mortar':
        box(gun, (0, 0.24, -0.14), (0.44, 0.29, 0.73), color, 0.07)
        cyl(gun, (0, 0.55, -0.33), 0.19, 0.06, RECESS, 10)
        cyl(gun, (0, 0.556, -0.33), 0.13, 0.069, DARK, 10)
        if detail:
            for side in (-1, 1):
                box(gun, (side * 0.22, 0.27, -0.17), (0.07, 0.18, 0.47), EDGE, 0.018)
    else:
        box(gun, (0, 0, -0.2), (0.27 if heavy else 0.16, 0.2, 0.54), DARK, 0.026)
        cyl(gun, (0, 0, -0.5), 0.12 if heavy else 0.078, 0.21, STEEL, 8, 'Y')
        if detail:
            box(gun, (0, 0.11, -0.13), (0.13, 0.065, 0.24), color, 0.018)
    if kind == 'warden':
        for side in (-1, 1):
            box(gun, (side * 0.21, 0.06, -0.35), (0.15, 0.19, 0.49), color, 0.04)

    if kind == 'bulwark':
        shield = key('Shield')
        box(shield, (0, -0.05, -0.15), (0.62, 1.06, 0.2), DARK, 0.055)
        box(shield, (0, -0.02, -0.26), (0.53, 0.95, 0.075), color, 0.05)
        if mid:
            box(shield, (0, 0.06, -0.31), (0.11, 0.73, 0.028), EDGE, 0.009)
            box(shield, (0, 0.32, -0.315), (0.39, 0.055, 0.03), EDGE, 0.009)
        if detail:
            for side in (-1, 1):
                box(shield, (side * 0.17, -0.15, -0.311), (0.09, 0.40, 0.022), RECESS, 0.006)


def finish_meshes():
    for name, members in parts.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in members:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = members[0]
        bpy.ops.object.join()
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        members[0].name = name
        members[0].data.name = name
    parts.clear()


def main():
    global material
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    material = bpy.data.materials.new('Enamel / vertex-color plates')
    material.use_nodes = True
    nodes = material.node_tree.nodes
    attribute = nodes.new('ShaderNodeVertexColor')
    attribute.layer_name = 'Col'
    material.node_tree.links.new(attribute.outputs['Color'], nodes.get('Principled BSDF').inputs['Base Color'])
    nodes.get('Principled BSDF').inputs['Metallic'].default_value = 0.42
    nodes.get('Principled BSDF').inputs['Roughness'].default_value = 0.44
    for kind in KINDS:
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        for mesh in tuple(bpy.data.meshes):
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
        for lod in range(3):
            build(kind, lod)
        finish_meshes()
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f'{kind}.blend'))
        bpy.ops.export_scene.gltf(filepath=str(OUTPUT / f'{kind}.glb'), export_format='GLB',
                                  export_yup=True, export_apply=True, export_materials='EXPORT')
        print('ROBOT_ART', kind, len(bpy.context.scene.objects), 'assemblies')


if __name__ == '__main__':
    main()

"""Deferred Blender authoring. Run ONLY after an explicit heavy-slot grant.

blender -b -t 1 --python tools/godot-multiplayer/new-maps/abyssal-pressureworks/blender_author.py
Source Y-up -> Blender Z-up -> glTF Y-up. No collision exported in the GLB.
"""
import hashlib
import json
import math
import pathlib
import bpy
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/asset-production'))
from moth_finish import finish_scene
ID = 'abyssal-pressureworks'
SOURCE = ROOT / 'port/native-multiplayer-worlds/worlds' / (ID + '.json')
DATA = json.loads(SOURCE.read_text())
HERE = pathlib.Path(__file__).resolve().parent
MASTER = HERE / 'masters' / (ID + '.blend')
EXPORT = ROOT / 'godot/multiplayer_worlds/art/worlds' / (ID + '.glb')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result

editable = collection('01 EDITABLE pressure habitat - source Y-up recipe')
scenery = collection('02 EDITABLE ocean escarpment - nonphysics')
batches = collection('03 EXPORT one mesh per material')
materials = {}
groups = {}
for name, color in DATA['art']['palette'].items():
    rgb = tuple(int(color[i:i+2], 16) / 255 for i in (1, 3, 5))
    # Hex swatches are sRGB; shader values are linear.
    rgb = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055)**2.4 for c in rgb)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*rgb, .22 if name == 'glass' else 1)
    shader.inputs['Roughness'].default_value = .28 if name in ('glass', 'copper') else .72
    shader.inputs['Metallic'].default_value = .65 if name == 'copper' else .08
    mat.diffuse_color = (*rgb, .22 if name == 'glass' else 1)
    mat.use_backface_culling = False
    if name == 'glass':
        shader.inputs['Alpha'].default_value = .22
        mat.surface_render_method = 'DITHERED'
    if name in ('cyan', 'amber'):
        shader.inputs['Emission Color'].default_value = (*rgb, 1)
        shader.inputs['Emission Strength'].default_value = .45
    materials[name] = mat

def emit(name, verts, faces, material, decorative=False):
    verts = [(x, -z, y) for x, y, z in verts]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    (scenery if decorative else editable).objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['recipe_sha256'] = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    obj['physics'] = 'none; source JSON owns authority'
    group = groups.setdefault(material, [[], []])
    offset = len(group[0])
    group[0].extend(verts)
    group[1].extend([tuple(offset + i for i in face) for face in faces])
    return obj

def box(name, x, y, z, w, h, d, material, decorative=False):
    v = [(x + sx*w/2, y + sy*h/2, z + sz*d/2)
         for sy in (-1, 1) for sz in (-1, 1) for sx in (-1, 1)]
    emit(name, v, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1),
                  (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)], material, decorative)

def beam(name, a, b, radius, material, decorative=False, sides=6):
    # A source-frame prism; used for exterior ribs, pipework and reef branches.
    from mathutils import Vector
    a, b = Vector(a), Vector(b)
    axis = (b-a).normalized()
    ref = Vector((0, 1, 0)) if abs(axis.y) < .9 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized() * radius
    v = axis.cross(u).normalized() * radius
    verts = [tuple(point + u*math.cos(i*math.tau/sides) + v*math.sin(i*math.tau/sides))
             for point in (a, b) for i in range(sides)]
    faces = [(i, (i+1) % sides, (i+1) % sides+sides, i+sides) for i in range(sides)]
    faces += [tuple(reversed(range(sides))), tuple(range(sides, 2*sides))]
    emit(name, verts, faces, material, decorative)

# The shell, decks, gallery ramps, ceiling facets and source triangles are
# emitted once. No generic flat-ground or overhead compiler is called here.
for s in DATA['terrain']['surfaces']:
    emit(s['id'], s['vertices'], s['triangles'], s['material'])
for s in DATA['terrain']['walls']:
    emit(s['id'], s['vertices'], [(0, 1, 2)], s['material'])
for p in DATA['art']['pieces']:
    box(p['id'], *(p[k] for k in ('x', 'y', 'z', 'w', 'h', 'd')), p['material'])
for window in DATA['art']['windows']:
    emit(window['id'], window['vertices'], [(0, 1, 2, 3)], 'glass')

# Equalizer face hardware sits on its source-solid casing. Paired pressure
# gauges and five segmented compression bands make the tower read as machinery.
core = next(p for p in DATA['art']['pieces'] if p['id'] == 'pressure-equalizer-core')
cx, cy, cz = (core[k] for k in ('x', 'y', 'z'))
for level in range(5):
    for sign in (-1, 1):
        box(f'equalizer-band-front-{level}-{sign}', cx, cy-8+level*4,
            cz+sign*3.012, 5.8, .28, .025, 'ivory')
        box(f'equalizer-band-side-{level}-{sign}', cx+sign*3.012,
            cy-8+level*4, cz, .025, .28, 5.8, 'ivory')
for sign in (-1, 1):
    box(f'equalizer-pressure-gauge-{sign}', cx+sign*1.4, cy-6,
        cz-3.03, .8, 1.5, .05, 'cyan' if sign < 0 else 'amber')

for r in [s for s in DATA['structures'] if 'silhouette' in s]:
    x, y, z, w, d, h = (r[k] for k in ('x', 'y', 'z', 'w', 'd', 'h'))
    name = r['id']
    # Segmented pressure frames have inner ivory seals, copper dogs and visible
    # inspection fasteners; these occupy the source jamb/lintel surfaces.
    for side, port in r['ports'].items():
        for n, end in enumerate((port['a'], port['b'])):
            for level in (1, 2.5, 4, 5.5):
                box(f'{name}-{side}-locking-dog-{n}-{level}', end[0], y+level,
                    end[1], .7, .5, .7, 'ivory')
        a, b = port['a'], port['b']
        beam(f'{name}-{side}-inner-seal', (a[0], y+7.15, a[1]),
             (b[0], y+7.15, b[1]), .16, 'copper')
    # Service trays run overhead against the upper shell, not through sightlines.
    for sign in (-1, 1):
        beam(name+f'-service-return-{sign}', (x-8, y+h-.7, z+sign*(d/2-3)),
             (x+8, y+h-.7, z+sign*(d/2-3)), .2, 'copper')
        # Consoles are functional-looking assemblies with inset displays and
        # controls; detail is inside their authoritative equipment envelopes.
        for key in range(6):
            box(f'{name}-console-key-{sign}-{key}', x+sign*10-1.5+key*.5,
                y+1.53, z-10.6, .16, .06, .16, 'amber')
        for stripe in range(3):
            box(f'{name}-equipment-vent-{sign}-{stripe}', x+sign*11,
                y+.6+stripe*.4, z+8.49, 2.8, .12, .03, 'copper')
    # Low-cost flush wayfinding, with district-specific palette rather than
    # emissive floodlighting. These are nonblocking markings on existing floors.
    color = 'cyan' if r['district'] == 'terraced-laboratories' else 'amber'
    for sign in (-1, 1):
        box(name+f'-deck-lane-{sign}', x, y+.018, z+sign*3, 14, .018, .12, color)

# Bounded, still ocean background: sculpted branching support reef and massive
# faceted escarpment buttresses. No water simulation, no gameplay colliders.
for i, reef in enumerate(DATA['art']['reefs']):
    x, y, z, radius, height = (reef[k] for k in ('x', 'y', 'z', 'radius', 'height'))
    beam(f'reef-{i}-escarpment', (x, y-10, z), (x+2, y+height*.65, z-2), radius,
         'navy', True, 7)
    for n in range(5):
        a = (x, y+n*height/7, z)
        b = (x+math.cos(n*2.1+i)*radius*1.8, y+height*(.6+n*.09), z-3-math.sin(n)*4)
        beam(f'reef-{i}-branch-{n}', a, b, .4+n*.08, 'coral' if n % 2 else 'copper', True)
        tip = (b[0]+2, b[1]+2, b[2]-1)
        beam(f'reef-{i}-tip-{n}', b, tip, .18, 'ivory', True)

# Retain editable pieces in the master; export only material-batched duplicates.
triangle_count = 0
for name, (verts, faces) in groups.items():
    mesh = bpy.data.meshes.new('batch-'+name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.calc_loop_triangles()
    triangle_count += len(mesh.loop_triangles)
    obj = bpy.data.objects.new('batch-'+name, mesh)
    batches.objects.link(obj)
    obj.data.materials.append(materials[name])
assert triangle_count <= DATA['design']['budgets']['triangles'], triangle_count
assert len(groups) <= DATA['design']['budgets']['materials'], len(groups)
MASTER.parent.mkdir(parents=True, exist_ok=True)
EXPORT.parent.mkdir(parents=True, exist_ok=True)
batches.hide_viewport = True
batches.hide_render = True
finish_scene(ROOT, ID)
bpy.ops.wm.save_as_mainfile(filepath=str(MASTER))
batches.hide_viewport = False
batches.hide_render = False
editable.hide_viewport = True
scenery.hide_viewport = True
bpy.ops.object.select_all(action='DESELECT')
for obj in batches.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format='GLB', use_selection=True,
                         export_yup=True, export_apply=True, export_extras=True,
                         export_cameras=False, export_lights=False)
report = {'id': ID, 'recipeSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'blender': bpy.app.version_string, 'triangles': triangle_count,
          'materialBatches': len(groups), 'editableObjects': len(editable.objects)+len(scenery.objects),
          'master': str(MASTER.relative_to(ROOT)), 'glb': str(EXPORT.relative_to(ROOT)),
          'glbSha256': hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
          'glbBytes': EXPORT.stat().st_size, 'inspection': 'PENDING native views and master reopen'}
(HERE / 'provenance.json').write_text(json.dumps(report, indent=2)+'\n')
print('ABYSSAL_EXPORT', json.dumps(report))

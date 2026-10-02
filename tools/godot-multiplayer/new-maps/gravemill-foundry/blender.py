"""Gravemill Foundry, editable authored master and material-batched glTF.

Requires an explicit parent heavy-slot grant. No external packages or downloads.
blender -b -t 1 --python <this-file> -- [--render] [--evidence=/absolute/path]
Seed and recipe hash are embedded in master, glTF extras and budget report.
"""
import bpy
import hashlib
import json
import math
import pathlib
import random
import sys
import time
from mathutils import Vector

START = time.monotonic()
ROOT = pathlib.Path(__file__).resolve().parents[4]
ID = 'gravemill-foundry'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
EVIDENCE = pathlib.Path(next((v.split('=', 1)[1] for v in ARGS if v.startswith('--evidence=')), '/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/blender'))
EVIDENCE.mkdir(parents=True, exist_ok=True)
raw = (ROOT / 'port/native-multiplayer-worlds/worlds' / (ID + '.json')).read_bytes()
data = json.loads(raw)
derived = json.loads((ROOT / 'godot/multiplayer_worlds/generated' / (ID + '.json')).read_text())
assert hashlib.sha256(raw).hexdigest() == derived['recipeHash']
random.seed(data['seed'])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

COLORS = {'mineral': (.19, .18, .15, 1), 'soot': (.033, .044, .047, 1), 'copper': (.09, .20, .16, 1), 'cooling-floor': (.075, .095, .09, 1), 'brass': (.24, .12, .035, 1), 'ore': (.12, .07, .04, 1), 'orange': (.8, .19, .025, 1), 'chalk': (.30, .29, .24, 1)}
materials = {}
for name, color in COLORS.items():
    mat = bpy.data.materials.new('GM / ' + name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = color
    bs.inputs['Roughness'].default_value = .82 if name in ('mineral', 'ore', 'chalk') else .53
    bs.inputs['Metallic'].default_value = .65 if name in ('soot', 'copper', 'brass') else 0
    if name == 'orange':
        bs.inputs['Emission Color'].default_value = color
        bs.inputs['Emission Strength'].default_value = 2
    materials[name] = mat

def collection(name):
    out = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(out)
    return out

source = collection('01 AUTHORITY / exact source triangles')
detail = collection('02 ARCHITECTURE / editable bounded detail')
export = collection('03 EXPORT / material batches')
review = collection('04 REVIEW / cameras and lighting')
groups = {}
ground_parts = []

def emit(name, vertices, faces, material, coll=detail):
    vertices = [(x, -z, y) for x, y, z in vertices]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    coll.objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['collision_contract'] = 'exact-source' if coll == source else 'bounded cosmetic detail; not authority'
    batch = groups.setdefault(material, [[], []])
    start = len(batch[0])
    batch[0].extend(vertices)
    batch[1].extend(tuple(start + i for i in face) for face in faces)
    return obj

def box(name, x, y, z, w, h, d, material, shear=.14):
    v = [(x + sx*w/2, y + sy*h/2, z + sz*d/2 + shear*sx*w/2) for sy in (-1, 1) for sz in (-1, 1) for sx in (-1, 1)]
    return emit(name, v, [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)], material)

def beam(name, a, b, radius, material, sides=6):
    a, b = Vector(a), Vector(b)
    axis = (b-a).normalized()
    reference = Vector((0, 1, 0)) if abs(axis.y) < .9 else Vector((1, 0, 0))
    u = axis.cross(reference).normalized()*radius
    v = axis.cross(u).normalized()*radius
    vertices = [tuple(p + math.cos(i*math.tau/sides)*u + math.sin(i*math.tau/sides)*v) for p in (a, b) for i in range(sides)]
    faces = [(i, (i+1) % sides, (i+1) % sides+sides, i+sides) for i in range(sides)]
    faces += [tuple(reversed(range(sides))), tuple(range(sides, 2*sides))]
    emit(name, vertices, faces, material)

def hoop(name, x, y, z, radius, tube, material, vertical=True):
    vertices = []
    for i in range(32):
        a = i*math.tau/32
        for j in range(6):
            b = j*math.tau/6
            r = radius + tube*math.cos(b)
            vertices.append((x + r*math.cos(a), y+tube*math.sin(b), z+r*math.sin(a)+.14*r*math.cos(a)) if vertical else (x+tube*math.sin(b), y+r*math.sin(a), z+r*math.cos(a)))
    faces = [(i*6+j, ((i+1) % 32)*6+j, ((i+1) % 32)*6+(j+1) % 6, i*6+(j+1) % 6) for i in range(32) for j in range(6)]
    emit(name, vertices, faces, material)

def floor_y(x, z):
    q = z-.14*x
    bands = [(-180, 0), (-25, 0), (25, 12), (55, 12), (99, 24), (119, 24), (160, 35), (180, 35)]
    for (a, h), (b, k) in zip(bands, bands[1:]):
        if q <= b:
            return h+(k-h)*(q-a)/(b-a)
    return 35

def clip_polygon(vertices, a, b, inside):
    out = []
    sign = 1 if inside else -1
    def distance(p):
        return sign*((b[0]-a[0])*(p[2]-a[1])-(b[1]-a[1])*(p[0]-a[0]))
    for i, p in enumerate(vertices):
        q = vertices[(i+1) % len(vertices)]
        dp, dq = distance(p), distance(q)
        if dp >= -1e-8:
            out.append(p)
        if (dp > 1e-8 and dq < -1e-8) or (dp < -1e-8 and dq > 1e-8):
            t = dp/(dp-dq)
            out.append(tuple(p[k]+(q[k]-p[k])*t for k in range(3)))
    return out

def area(vertices):
    return abs(sum(p[0]*vertices[(i+1) % len(vertices)][2]-vertices[(i+1) % len(vertices)][0]*p[2] for i, p in enumerate(vertices)))/2 if len(vertices) > 2 else 0

def paint_ground(footprint, material):
    # True inlay: split planar source terrain into disjoint material regions.
    # No raised/coplananr decal triangles, depth bias, or visual-only new floor.
    global ground_parts
    bounds = (min(p[0] for p in footprint), max(p[0] for p in footprint), min(p[1] for p in footprint), max(p[1] for p in footprint))
    updated = []
    for vertices, old_material in ground_parts:
        if max(p[0] for p in vertices) < bounds[0] or min(p[0] for p in vertices) > bounds[1] or max(p[2] for p in vertices) < bounds[2] or min(p[2] for p in vertices) > bounds[3]:
            updated.append((vertices, old_material))
            continue
        remainder = vertices
        for i, a in enumerate(footprint):
            if not remainder:
                break
            b = footprint[(i+1) % len(footprint)]
            outside = clip_polygon(remainder, a, b, False)
            if area(outside) > 1e-7:
                updated.append((outside, old_material))
            remainder = clip_polygon(remainder, a, b, True)
        if area(remainder) > 1e-7:
            updated.append((remainder, material))
    ground_parts = updated

def ribbon(name, a, b, width, material, lift=.025):
    dx, dz = b[0]-a[0], b[1]-a[1]
    length = math.hypot(dx, dz)
    nx, nz = -dz/length*width/2, dx/length*width/2
    paint_ground([(a[0]+nx,a[1]+nz),(a[0]-nx,a[1]-nz),(b[0]-nx,b[1]-nz),(b[0]+nx,b[1]+nz)], material)

# Identical coordinates to source, including the oblique geology and vaults.
for surface in data['terrain']['surfaces']:
    if surface.get('walkable'):
        # Each source stratum is planar. Clip its authored polygon in 3D so all
        # new vertices remain exactly on that same authoritative support plane.
        ground_parts.append((surface['vertices'], surface['material']))
    else:
        emit(surface['id'], surface['vertices'], surface['triangles'], surface['material'], source)
for index, wall in enumerate(data['terrain']['walls']):
    # Boundary collision is represented by the outside escarpment below, not a
    # visually enclosing 44m rectangular wall. It is the arena extent only.
    if wall['id'] == 'boundary':
        continue
    if wall['id'].startswith('crusher-drum-contact-'):
        continue  # Same face already emitted by terrain surface.
    vertices = wall['vertices']
    emit(wall['id'] + '-%03d' % index, vertices, [tuple(range(len(vertices)))], wall['material'], source)

# Route surfacing and inset rail lines expose the oblique macro layout at scale.
for ri, route in enumerate(data['routes']):
    width = 15 if ri < 2 else 8 if ri < 4 else 4.5
    for si, (a, b) in enumerate(zip(route['points'], route['points'][1:])):
        ribbon(route['id']+'.paving-%02d' % si, a, b, width, 'cooling-floor' if ri < 2 else 'soot', .018+ri*.002)
        if ri == 0:
            dx, dz = b[0]-a[0], b[1]-a[1]
            length = math.hypot(dx, dz)
            for side in (-1, 1):
                offx, offz = -dz/length*2.1*side, dx/length*2.1*side
                ribbon('ore-rail-%d-%d' % (si, side), (a[0]+offx, a[1]+offz), (b[0]+offx, b[1]+offz), .12, 'brass', .045)
# Sedimentary fault lines are ground-conforming mineral inlays, not false walls.
for q in [-134, -124, -106, -24, -17, -9, 1, 11, 22, 56, 65, 76, 88, 99, 127, 136, 146]:
    for j in range(8):
        x = -182+j*46
        a = (x, q+.14*x)
        b = (x+random.uniform(25, 42), q+.14*(x+36)+random.uniform(-1.2, 1.2))
        if max(abs(a[1]), abs(b[1])) < 141:
            ribbon('mineral-seam-%d-%d' % (q, j), a, b, random.uniform(.08, .3), 'chalk', .009)

for lm in data['art']['landmarks']:
    x, y, z = lm['x'], lm['y'], lm['z']
    label = lm['id']
    if lm['kind'] == 'silo':
        r, h = lm['r'], lm['h']
        profile = lm.get('profile', [(0, r), (h, r)])
        def radius_at(dy):
            for (ay, ar), (by, br) in zip(profile, profile[1:]):
                if dy <= by:
                    return ar+(br-ar)*(dy-ay)/(by-ay)
            return profile[-1][1]
        # Tight rings sit on the actual radial collision shell, not proxy boxes.
        for j in range(1, int(h/3)):
            hoop(label+'.riveted-band-%02d' % j, x, y+j*3, z, radius_at(j*3)-.07, .12, 'brass')
        for j in range(20):
            a = j*math.tau/20
            dx = (r-.06)*math.cos(a)
            dz = (r-.06)*math.sin(a)+.14*dx
            beam(label+'.shell-seam-%02d' % j, (x+dx, y+.2, z+dz), (x+dx, y+profile[1][0]-.2, z+dz), .10, 'soot')
        hoop(label+'.crown', x, y+h-.12, z, radius_at(h)-.2, .18, 'soot')
        # Small inset molten inspection bands: restrained, no giant neon faces.
        if label.startswith('furnace'):
            for j in range(4):
                a = (j+.25)*math.tau/4
                dx = (r+.01)*math.cos(a)
                dz = (r+.01)*math.sin(a)+.14*dx
                beam(label+'.sight-glass-%d' % j, (x+dx, y+4, z+dz), (x+dx, y+6, z+dz), .15, 'orange')
    elif lm['kind'] == 'crusher':
        for j in range(7):
            dx = -7.8+j*2.6
            hoop(label+'.toothed-hoop-%d' % j, x+dx, y, z+.14*dx, 6.98, .12, 'brass', False)
        for side in (-1, 1):
            # End-mounted radial teeth remain on the physical end-cap face.
            for j in range(24):
                a = j*math.tau/24
                beam(label+'.end-rib-%d-%02d' % (side, j), (x+side*8.51, y+2*math.sin(a), z+side*8.5*.14+2*math.cos(a)), (x+side*8.51, y+6.7*math.sin(a), z+side*8.5*.14+6.7*math.cos(a)), .11, 'brass')
    elif lm['kind'] == 'conveyor':
        length = lm['length']
        for j in range(int(length/2)):
            along = -length/2+1+j*2
            if lm.get('axis') == 'x':
                box(label+'.belt-roller-%02d' % j, x+along, y+.65, z+.14*along, .25, .12, 2.8, 'brass')
            else:
                box(label+'.belt-roller-%02d' % j, x, y+.55, z+along, 2.8, .12, .25, 'brass')
        for side in (-1, 1):
            if lm.get('axis') == 'x':
                beam(label+'.top-chord-%d' % side, (x-length/2, y+1.1, z-.14*length/2+side*1.4), (x+length/2, y+1.1, z+.14*length/2+side*1.4), .12, 'copper')
            else:
                beam(label+'.top-chord-%d' % side, (x+side*1.4, y+1.05, z-length/2), (x+side*1.4, y+1.05, z+length/2), .12, 'copper')
            for j in range(int(length/4)):
                a = -length/2+j*4
                if lm.get('axis') == 'x':
                    p = (x+a, y+.1, z+.14*a+side*1.45)
                    q = (x+a+4, y+1.05, z+.14*(a+4)+side*1.45)
                else:
                    p, q = (x+side*1.45, y+.1, z+a), (x+side*1.45, y+1.0, z+a+4)
                beam(label+'.lattice-%d-%03d' % (side, j), p, q, .075, 'brass')
    elif lm['kind'] == 'rock':
        # Fine alternating mineral beds follow each exact faceted collision wall.
        for i, (a, top) in enumerate(zip(lm['base'], lm['top'])):
            b = lm['base'][(i+1) % len(lm['base'])]
            top_b = lm['top'][(i+1) % len(lm['top'])]
            for j in range(1, 7):
                t = j/8
                va, vb = Vector(a).lerp(Vector(top), t), Vector(b).lerp(Vector(top_b), t)
                beam(label+'.sediment-%d-%d' % (i, j), va, vb, .025 if j % 2 else .05, 'chalk' if j % 3 else 'ore')
    elif lm['kind'] == 'hopper':
        for side in (-1, 1):
            for j in range(6):
                xx = x-4+j*1.6
                beam(label+'.side-rib-%d-%d' % (side, j), (xx, .1, z+.14*(xx-x)+side*3.99), (xx, 3.4, z+.14*(xx-x)+side*3.99), .1, 'copper')
        box(label+'.ore-bed', x, 3.505, z, 8.7, .015, 7.7, 'ore')
        for j in range(16):
            xx, zz = x+random.uniform(-4, 4), z+random.uniform(-3.5, 3.5)
            box(label+'.embedded-ore-%02d' % j, xx, 3.515, zz, .3, .025, .3, 'brass')
    elif lm['kind'] == 'static-lift':
        # Flush platform skin and engraved cable seats, no moving machinery.
        box(label+'.stopped-platform', x, y+.012, z, lm['w'], .024, lm['d'], 'soot')
        for j in range(9):
            box(label+'.flush-slats-%d' % j, x-4+j, y+.029, z, .1, .012, 7.7, 'brass')

# Cooling barrel-vault ribs trace the actual roof panels; apertures remain open.
for hall in data['structures']:
    cx, z = hall['x'], hall['z']
    for j in range(9):
        xx = cx-hall['w']/2+j*hall['w']/8
        for k in range(10):
            a, b = k*math.pi/10, (k+1)*math.pi/10
            beam(hall['id']+'.vault-rib-%02d-%02d' % (j, k), (xx, 19+5*math.sin(a)-.10, z+.14*(xx-cx)+10*math.cos(a)), (xx, 19+5*math.sin(b)-.10, z+.14*(xx-cx)+10*math.cos(b)), .13, 'brass')
    # Inset floor pipes emphasize deep perspective without blocking movement.
    for side in (-1, 1):
        beam(hall['id']+'.floor-conduit-%d' % side, (cx-25, 12.015, z-25*.14+side*8), (cx+25, 12.015, z+25*.14+side*8), .025, 'copper')
    for j in range(8):
        xx = cx-23+j*6.5
        box(hall['id']+'.roof-inspection-light-%d' % j, xx, 23.5, z+.14*(xx-cx), .8, .10, 1.2, 'orange')
        for side in (-1, 1):
            box(hall['id']+'.floor-grate-%d-%d' % (side, j), xx, 12.04, z+.14*(xx-cx)+side*6.5, 2.4, .02, .6, 'brass')

# Rail gantry sleepers and mineral ramp chevrons are flush render markings.
for j in range(113):
    x = -112+j*2
    box('crown-sleeper-%03d' % j, x, 24.014, 109+.14*x, .28, .025, 8, 'copper')
for x in (-112, -34, 34, 112):
    for q in range(-20, 99, 4):
        y = 12*(q+25)/50 if q < 25 else 12 if q < 55 else 12+12*(q-55)/44
        box('incline-chalk-%d-%d' % (x, q), x, y+.02, q+.14*x, 3.6, .015, .09, 'chalk')

# Fractured exterior escarpment. Every vertex lies outside the playable bounds;
# it gives geological skyline depth without concealing playable collision.
for side in (-1, 1):
    for j in range(18):
        x = -204+j*24
        z = side*(150+random.uniform(0, 9))
        peak = random.uniform(26, 49) if side > 0 else random.uniform(9, 22)
        v = [(x-13, -3, z), (x+13, -3, z), (x+18, -3, z+side*30), (x-18, -3, z+side*30), (x-9, peak*.75, z+side*3), (x+8, peak, z+side*8), (x+4, peak*.8, z+side*29), (x-15, peak*.65, z+side*24)]
        emit('outside-stratified-spur-%d-%02d' % (side, j), v, [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6), (4, 6, 7)], 'mineral')

# Batched export keeps draw calls bounded while named editable parts survive.
for i, (vertices, material) in enumerate(ground_parts):
    emit('inlaid-source-terrain-%05d' % i, vertices, [(0,j,j+1) for j in range(1,len(vertices)-1)], material, source)
for material, (vertices, faces) in groups.items():
    mesh = bpy.data.meshes.new('batch-' + material)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Gravemill / ' + material, mesh)
    export.objects.link(obj)
    obj.data.materials.append(materials[material])
    obj['geometryHash'] = derived['geometryHash']
    obj['recipeHash'] = derived['recipeHash']
    obj['generatorSeed'] = data['seed']
source.hide_render = True
source.hide_viewport = True
detail.hide_render = True
detail.hide_viewport = True

scene = bpy.context.scene
scene['geometryHash'] = derived['geometryHash']
scene['recipeHash'] = derived['recipeHash']
scene['generatorSeed'] = data['seed']
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 1440
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world.color = (.12, .15, .17)
scene.view_settings.view_transform = 'AgX'
light_data = bpy.data.lights.new('pale-mineral-sun', 'SUN')
light_data.energy = 3
light = bpy.data.objects.new('pale-mineral-sun', light_data)
review.objects.link(light)
light.rotation_euler = (.55, -.5, -.45)

def camera(label, position, target, lens=32):
    cd = bpy.data.cameras.new(label)
    obj = bpy.data.objects.new(label, cd)
    review.objects.link(obj)
    obj.location = (position[0], -position[2], position[1])
    aim = Vector((target[0], -target[2], target[1]))
    obj.rotation_euler = (aim-obj.location).to_track_quat('-Z', 'Y').to_euler()
    cd.lens = lens
    cd.clip_end = 1500
    return obj

views = [
    ('01-overview', (300, 255, -295), (0, 12, 0), 37),
    ('02-reverse-geology', (-295, 190, 240), (0, 16, 15), 35),
    ('03-crusher-throat-eye', (-117, 1.65, -60), (-59, 14, -10), 25),
    ('04-cooling-nave-eye', (-95, 13.65, 22.7), (-45, 17, 29.7), 24),
    ('05-assay-vault-eye', (37, 13.65, 41.18), (86, 17, 48.04), 24),
    ('06-crown-counterflank-eye', (-101, 25.65, 94.86), (55, 25, 116.7), 28),
    ('07-furnace-apron-eye', (113, 1.65, -22.18), (65, 20, 1.1), 24),
    ('08-under-conveyor-eye', (-24, 1.65, -71.36), (-24, 11, -46), 26),
]
cameras = [camera(*view) for view in views]
scene.camera = cameras[0]
art = ROOT / 'godot/multiplayer_worlds/art/worlds'
art.mkdir(parents=True, exist_ok=True)
master = pathlib.Path(__file__).parent / (ID + '.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(master))
bpy.ops.object.select_all(action='DESELECT')
for obj in export.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(iter(export.objects))
bpy.ops.export_scene.gltf(filepath=str(art / (ID + '.glb')), export_format='GLB', use_selection=True, export_yup=True, export_extras=True, export_materials='EXPORT')
triangles = sum(sum(len(face)-2 for face in faces) for _, faces in groups.values())
budget = {'id': ID, 'geometryHash': derived['geometryHash'], 'recipeHash': derived['recipeHash'], 'seed': data['seed'], 'materials': len(groups), 'exportNodes': len(export.objects), 'editableObjects': len(source.objects)+len(detail.objects), 'triangles': triangles, 'glbBytes': (art / (ID + '.glb')).stat().st_size, 'masterBytes': master.stat().st_size, 'generationSeconds': time.monotonic()-START, 'renders': []}
assert len(groups) <= 8 and triangles < 180000 and len(export.objects) <= 8
if '--render' in ARGS:
    # CPU-only review: do not require a GPU or claim interactive frame timing.
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 16
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 1
    chosen = next((arg.split('=', 1)[1].split(',') for arg in ARGS if arg.startswith('--views=')), None)
    for cam in cameras:
        if chosen and cam.name not in chosen:
            continue
        before = time.monotonic()
        scene.camera = cam
        scene.render.filepath = str(EVIDENCE / (cam.name + '.png'))
        bpy.ops.render.render(write_still=True)
        budget['renders'].append({'camera': cam.name, 'seconds': time.monotonic()-before})
budget['totalSeconds'] = time.monotonic()-START
(EVIDENCE / 'blender-budget.json').write_text(json.dumps(budget, indent=2)+'\n')
print(json.dumps(budget, indent=2))

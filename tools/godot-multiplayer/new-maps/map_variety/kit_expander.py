"""Pure-Python expansion of authority `art.kit` directives into builder ops.

No bpy import. Deterministic and importable by the source tests, so the exact
part list, sectors, material batches and triangle budget can be validated before
any Blender process is granted. Each op maps 1:1 to a `blender_kit.Kit` call.
"""
import json
import math
from collections import Counter
from triangle_policy import triangle_advisory


def _empty():
    return {'vertices': [], 'faces': []}


def _add(target, vertices, faces):
    base = len(target['vertices'])
    target['vertices'].extend(vertices)
    target['faces'].extend([tuple(base + i for i in face) for face in faces])


def _box(center, size):
    x, y, z = center
    w, d, h = size
    vertices = [(x + sx * w / 2, y + sy * d / 2, z + sz * h / 2)
                for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return vertices, faces


def _triangles(vertices, faces):
    return sum(max(0, len(face) - 2) for face in faces)


def signed_volume(vertices, faces):
    total = 0
    for face in faces:
        a = vertices[face[0]]
        for i in range(1,len(face)-1):
            b,c = vertices[face[i]],vertices[face[i+1]]
            total += sum(a[k]*(b[(k+1)%3]*c[(k+2)%3]-b[(k+2)%3]*c[(k+1)%3]) for k in range(3))/6
    return total


def outward_faces(vertices, faces):
    """Consumer-side orientation guard; no edits to the Sol-owned shared Kit.

    Only closed indexed shells are normalized. Open authored sheets retain
    their authored orientation, so this cannot flip floors or glazing by guess.
    """
    edges = Counter(tuple(sorted((a,face[(i+1)%len(face)]))) for face in faces for i,a in enumerate(face))
    if edges and all(n == 2 for n in edges.values()) and signed_volume(vertices,faces) < -1e-8:
        return [tuple(reversed(face)) for face in faces]
    return faces


def _op(op, name, material, sector, at, rot, **params):
    entry = {'op': op, 'name': name, 'material': material, 'sector': sector,
             'at': [float(v) for v in at], 'rot': float(rot)}
    entry.update(params)
    return entry


def _prism(name, material, sector, at, rot, size, bevel=0.035):
    return _op('prism', name, material, sector, at, rot, size=[float(v) for v in size], bevel=bevel)


def _curved_rib(name, material, sector, at, rot, inner, outer, depth, start=0.0, stop=math.pi, segments=24):
    return _op('curved_rib', name, material, sector, at, rot, inner=float(inner), outer=float(outer),
               depth=float(depth), start=float(start), stop=float(stop), segments=int(segments))


def _pipe(name, material, sector, at, rot, radius, sides, points):
    return _op('pipe', name, material, sector, at, rot, radius=float(radius), sides=int(sides),
               points=[[float(c) for c in p] for p in points])


def _framed(name, material, sector, at, rot, width, height, depth, arch, trim):
    return _op('framed_bay', name, material, sector, at, rot, width=float(width), height=float(height),
               depth=float(depth), arch=bool(arch), trimMaterial=trim)


def _mesh(name, material, sector, at, rot, vertices, faces, bevel=0.0, smooth=True):
    return _op('mesh', name, material, sector, at, rot, vertices=vertices, faces=faces,
               bevel=float(bevel), smooth=bool(smooth))


# ---- class handlers -------------------------------------------------------

def _grotto_arch(d, material):
    span = d['params'].get('span', 4.6)
    rise = d['params'].get('rise', 3.4)
    thickness = d['params'].get('thickness', .9)
    depth = d['params'].get('depth', 3.4)
    at, rot = d['at'], d.get('rot', 0)
    spring = rise - (span / 2 - thickness)
    out = [
        _curved_rib(d['id'] + '.band', material, d['sector'], [at[0],at[1]+spring,at[2]], rot, span / 2 - thickness, span / 2, depth, 0, math.pi, 22),
        _curved_rib(d['id'] + '.reveal', material, d['sector'], [at[0], at[1]+spring, at[2] - depth * .18], rot,
                    span / 2 - thickness * 1.4, span / 2 - thickness * .9, depth * .32, 0, math.pi, 22),
    ]
    for side in (-1,1):
        out.append(_prism(d['id']+f'.springer{side}',material,d['sector'],[at[0]+side*(span-thickness)/2,at[1]+spring/2,at[2]],rot,[thickness,depth,spring],.05))
    return out


def _stepped_terrace(d, material):
    p = d['params']
    tiers = int(p.get('tiers', 2))
    run = float(p.get('run', 2.2))
    rise = float(p.get('rise', .35))
    width = float(p.get('width', 2.2))
    depth = float(p.get('depth', 5.0))
    cap = p.get('capMaterial', material)
    out = []
    for tier in range(tiers):
        out.append(_prism(f"{d['id']}.tier{tier}", material, d['sector'],
                          [d['at'][0], d['at'][1] + tier * rise, d['at'][2]], d.get('rot', 0),
                          [width, depth - tier * run * .4, rise * (tier + 1)], .03))
    out.append(_prism(d['id'] + '.cap', cap, d['sector'],
                      [d['at'][0], d['at'][1] + tiers * rise, d['at'][2]], d.get('rot', 0),
                      [width + .18, depth + .16, .12], .02))
    return out


def _facade_bays(d, material):
    p = d['params']
    height = float(p.get('height', 4.2))
    depth = float(p.get('depth', .8))
    arch = bool(p.get('arch', False))
    trim = p.get('trimMaterial', material)
    bays = p.get('bays') or [2.4, 2.8, 2.0]
    total = sum(bays)
    out, offset = [], -total / 2
    for index, width in enumerate(bays):
        center = offset + width / 2
        out.append(_framed(f"{d['id']}.bay{index}", material, d['sector'],
                           [d['at'][0] + center, d['at'][1], d['at'][2]], d.get('rot', 0),
                           max(1.2, width * .72), height, depth, arch, trim))
        out.append(_prism(f"{d['id']}.pier{index}", material, d['sector'],
                          [d['at'][0] + offset, d['at'][1] + height / 2, d['at'][2]], d.get('rot', 0),
                          [.4, depth, height], .03))
        offset += width
    out.append(_prism(d['id'] + '.pier-end', material, d['sector'],
                      [d['at'][0] + offset, d['at'][1] + height / 2, d['at'][2]], d.get('rot', 0),
                      [.4, depth, height], .03))
    out.append(_prism(d['id'] + '.cornice', trim, d['sector'],
                      [d['at'][0], d['at'][1] + height - .25, d['at'][2]], d.get('rot', 0),
                      [total + .8, depth + .35, .5], .04))
    return out


def _root_form(d, material):
    p = d['params']
    height = float(p.get('height', 12))
    radius = float(p.get('radius', .34))
    branches = int(p.get('branches', 3))
    lean = float(p.get('lean', .15))
    at, rot = d['at'], d.get('rot', 0)
    trunk = [[0, 0, 0], [lean * height * .35, 0, height * .5], [lean * height, 0, height]]
    out = [_pipe(d['id'] + '.trunk', material, d['sector'], at, rot, radius, 10, trunk)]
    for index in range(branches):
        angle = (index - (branches - 1) / 2) * .7
        base_z = height * (.55 + .1 * index)
        tip = [lean * height + math.sin(angle) * height * .32, math.cos(angle) * height * .18, base_z + height * .42]
        out.append(_pipe(f"{d['id']}.branch{index}", material, d['sector'], at, rot, radius * .62, 8,
                         [[lean * height, 0, base_z], tip]))
    return out


def _fern_card(d, material):
    p = d['params']
    scale = float(p.get('scale', 1.4))
    fronds = int(p.get('fronds', 7))
    vertices, faces = [], []
    for frond in range(fronds):
        angle = frond * 2.399963
        for segment in range(3):
            t0, t1 = segment / 3, (segment + 1) / 3
            w0 = scale * .28 * math.sin(t0 * math.pi)
            w1 = scale * .28 * math.sin(t1 * math.pi)
            r0, r1 = scale * t0, scale * t1
            z0 = scale * .55 * math.sin(t0 * math.pi * .8)
            z1 = scale * .55 * math.sin(t1 * math.pi * .8)
            cx0, cy0 = math.cos(angle) * r0, math.sin(angle) * r0
            cx1, cy1 = math.cos(angle) * r1, math.sin(angle) * r1
            a = (cx0 - math.sin(angle) * w0, cy0 + math.cos(angle) * w0, z0)
            b = (cx1 - math.sin(angle) * w1, cy1 + math.cos(angle) * w1, z1)
            c = (cx1 + math.sin(angle) * w1, cy1 - math.cos(angle) * w1, z1)
            e = (cx0 + math.sin(angle) * w0, cy0 - math.cos(angle) * w0, z0)
            base = len(vertices)
            vertices.extend([a, b, c, e])
            faces.append((base, base+1, base+2) if segment == 0 else
                         (base, base+1, base+3) if segment == 2 else
                         (base, base+1, base+2, base+3))
    return [_mesh(d['id'], material, d['sector'], d['at'], d.get('rot', 0), vertices, [tuple(reversed(f)) for f in faces], 0.0, False)]


def _pool(d, material):
    p = d['params']
    w, dpt = float(p.get('width', 6)), float(p.get('depth', 6))
    z = float(p.get('surface', .06))
    vertices = [(-w / 2, -dpt / 2, z), (w / 2, -dpt / 2, z), (w / 2, dpt / 2, z), (-w / 2, dpt / 2, z)]
    return [_mesh(d['id'], material, d['sector'], d['at'], d.get('rot', 0), vertices, [(0, 1, 2, 3)], 0.0, False)]


def _tower(d, material):
    p = d['params']
    radius = float(p.get('radius', 4))
    height = float(p.get('height', 24))
    drums = int(p.get('drums', 3))
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    out = [_prism(d['id'] + '.plinth', material, d['sector'], [at[0], at[1] + 1.2, at[2]], rot, [radius * 2.4, radius * 2.4, 2.4], .06),
           _prism(d['id'] + '.shaft', material, d['sector'], [at[0], at[1] + height * .5, at[2]], rot, [radius * 1.4, radius * 1.4, height], .08),
           _curved_rib(d['id'] + '.crown', trim, d['sector'], [at[0], at[1] + height, at[2]], rot, radius * .55, radius * 1.15, radius * 2.0, 0, math.pi, 20),
           _pipe(d['id'] + '.mast', trim, d['sector'], at, rot, radius * .16, 8,
                 [[0, 0, height + radius * .5], [0, 0, height + radius * 2.6]])]
    for drum in range(drums):
        out.append(_prism(f"{d['id']}.drum{drum}", trim, d['sector'],
                          [at[0], at[1] + 3 + drum * (height - 6) / max(1, drums), at[2]], rot,
                          [radius * 1.6, radius * 1.6, .5], .03))
    return out


def _lightwell(d, material):
    p = d['params']
    radius = float(p.get('radius', 5))
    ribs = int(p.get('ribs', 12))
    glazing = p.get('glazingMaterial', material)
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    out = [_curved_rib(d['id'] + '.oculus', trim, d['sector'], at, rot, radius - .5, radius, .8, 0, math.tau, ribs * 2),
           _curved_rib(d['id'] + '.inner-ring', trim, d['sector'], [at[0], at[1] + .6, at[2]], rot, radius - 1.1, radius - .7, .5, 0, math.tau, ribs * 2)]
    for op in out:
        op['tilt'] = math.pi/2
    vertices, faces = [], []
    for index in range(ribs):
        angle = index * math.tau / ribs
        a = (radius * .2, 0, 0)
        b = (radius * math.cos(angle) * .7, radius * math.sin(angle) * .7, .9)
        c = (radius * math.cos(angle + math.tau / ribs) * .7, radius * math.sin(angle + math.tau / ribs) * .7, .9)
        base = len(vertices)
        vertices.extend([a, b, c])
        faces.append((base, base + 1, base + 2))
    out.append(_mesh(d['id'] + '.glazing', glazing, d['sector'], at, rot, vertices, faces, 0.0, False))
    return out


def _instrument_dish(d, material):
    p = d['params']
    radius = float(p.get('radius', 6))
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    return [
        _prism(d['id'] + '.mount', trim, d['sector'], [at[0], at[1] + 1, at[2]], rot, [radius * .5, radius * .5, 2], .05),
        _curved_rib(d['id'] + '.dish-outer', material, d['sector'], [at[0], at[1] + 3, at[2]], rot, radius - .45, radius, radius * .5, 0, math.pi, 24),
        _curved_rib(d['id'] + '.dish-mid', material, d['sector'], [at[0], at[1] + 3.2, at[2]], rot, radius * .45, radius * .6, radius * .42, 0, math.pi, 20),
        _curved_rib(d['id'] + '.dish-inner', trim, d['sector'], [at[0], at[1] + 3.4, at[2]], rot, radius * .18, radius * .28, radius * .3, 0, math.pi, 16),
        _pipe(d['id'] + '.feed', trim, d['sector'], at, rot, radius * .08, 8, [[0, 0, 2], [0, 0, 6]]),
    ]


def _scientific_room(d, material):
    p = d['params']
    count = int(p.get('racks', 4))
    spacing = float(p.get('spacing', 3))
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    out = []
    for index in range(count):
        offset = (index - (count - 1) / 2) * spacing
        out.append(_prism(f"{d['id']}.rack{index}", material, d['sector'],
                          [at[0] + offset, at[1] + .9, at[2]], rot, [1.6, 1.0, 1.8], .04))
        out.append(_prism(f"{d['id']}.console{index}", trim, d['sector'],
                          [at[0] + offset, at[1] + 1.85, at[2] + .2], rot, [1.4, .6, .2], .02))
    return out


def _stall_row(d, material):
    p = d['params']
    count = int(p.get('count', 4))
    spacing = float(p.get('spacing', 3))
    width = float(p.get('width', 2.4))
    depth = float(p.get('depth', 1.6))
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    out = []
    for index in range(count):
        offset = (index - (count - 1) / 2) * spacing
        out.append(_prism(f"{d['id']}.counter{index}", material, d['sector'],
                          [at[0] + offset, at[1] + .55, at[2]], rot, [width, depth, 1.1], .04))
        out.append(_prism(f"{d['id']}.awning{index}", trim, d['sector'],
                          [at[0] + offset, at[1] + 2.5, at[2]], rot, [width + .5, depth + .9, .18], .03))
        for side in (-1, 1):
            out.append(_pipe(f"{d['id']}.post{index}.{side}", trim, d['sector'], at, rot, .06, 8,
                              [[offset + side * (width / 2 - .1), -depth / 2 - .2, 0], [offset + side * (width / 2 - .1), -depth / 2 - .2, 2.4]]))
    return out


def _roof_run(d, material):
    p = d['params']
    length = float(p.get('length', 8))
    width = float(p.get('width', 4))
    rise = float(p.get('rise', 2))
    style = p.get('style', 'pitched')
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    if style == 'parapet':
        out = []
        for side in (-1, 1):
            out.append(_prism(f"{d['id']}.parapet{side}", material, d['sector'],
                              [at[0], at[1] + .45, at[2] + side * width / 2], rot, [length, .35, .9], .03))
        return out
    l, w = length / 2, width / 2
    vertices = [(-l, -w, 0), (l, -w, 0), (l, w, 0), (-l, w, 0), (-l, 0, rise), (l, 0, rise)]
    faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    return [_mesh(d['id'], material, d['sector'], at, rot, vertices, faces, .04, False)]


def _arch_bridge(d, material):
    p = d['params']
    span = float(p.get('span', 12))
    width = float(p.get('width', 6))
    thickness = float(p.get('thickness', 1.2))
    pier = float(p.get('pier', 3))
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    out = []
    for side in (-1, 1):
        out.append(_prism(f"{d['id']}.pier{side}", material, d['sector'],
                          [at[0] + side * (span / 2), at[1] + pier / 2, at[2]], rot, [1.6, width, pier], .05))
    out.append(_curved_rib(d['id'] + '.arch', material, d['sector'], [at[0], at[1] + pier-span/2-.5, at[2]], rot,
                           span / 2 - thickness, span / 2, width, 0, math.pi, 24))
    out.append(_prism(d['id'] + '.deck', trim, d['sector'],
                       [at[0], at[1] + pier - .25, at[2]], rot, [span + 2, width, .5], .05))
    return out


def _retaining_wall(d, material):
    p = d['params']
    length = float(p.get('length', 10))
    height = float(p.get('height', 2))
    thickness = float(p.get('thickness', .8))
    trim = p.get('trimMaterial', material)
    at, rot = d['at'], d.get('rot', 0)
    return [
        _prism(d['id'] + '.wall', material, d['sector'], [at[0], at[1] + height / 2, at[2]], rot, [length, thickness, height], .05),
        _prism(d['id'] + '.coping', trim, d['sector'], [at[0], at[1] + height + .12, at[2]], rot, [length + .2, thickness + .35, .24], .03),
    ]


def _landmark(d, material):
    p = d['params']
    if p.get('acceptedCraft'):
        return [] # Exact accepted petals/domes/armillary come from base_craft.py.
    kind = p.get('kind', 'dome')
    radius = float(p.get('radius', 8))
    at, rot = d['at'], d.get('rot', 0)
    if kind == 'dome':
        return [_curved_rib(d['id'] + '.dome', material, d['sector'], at, rot, radius * .9, radius, radius * .9, 0, math.pi, 24),
                _prism(d['id'] + '.base', material, d['sector'], [at[0], at[1] + .4, at[2]], rot, [radius * 2, radius * 2, .8], .05)]
    if kind == 'armillary':
        return [_curved_rib(d['id'] + '.ring-a', material, d['sector'], at, rot, radius - .35, radius, radius * 1.6, 0, math.tau, 32),
                _curved_rib(d['id'] + '.ring-b', material, d['sector'], at, rot + math.pi / 2, radius - .35, radius, radius * 1.6, 0, math.tau, 32),
                _pipe(d['id'] + '.axis', material, d['sector'], at, rot, .35, 8, [[-radius * 1.2, 0, 0], [radius * 1.2, 0, 0]])]
    return [_prism(d['id'] + '.mount', material, d['sector'], [at[0], at[1] + 1, at[2]], rot, [radius * .6, radius * .6, 2], .05),
            _curved_rib(d['id'] + '.dish-outer', material, d['sector'], [at[0], at[1] + 3, at[2]], rot, radius - .4, radius, radius * .6, 0, math.pi, 28),
            _curved_rib(d['id'] + '.dish-inner', material, d['sector'], [at[0], at[1] + 3.3, at[2]], rot, radius * .2, radius * .4, radius * .35, 0, math.pi, 20),
            _pipe(d['id'] + '.mast', material, d['sector'], at, rot, .25, 8, [[0, 0, 3], [0, 0, 9]])]


HANDLERS = {
    'prism': lambda d, m: [_prism(d['id'], m, d['sector'], d['at'], d.get('rot', 0), d['params']['size'], d['params'].get('bevel', .035))],
    'framed_bay': lambda d, m: [_framed(d['id'], m, d['sector'], d['at'], d.get('rot', 0), d['params']['width'], d['params']['height'], d['params']['depth'], d['params'].get('arch', False), d['params'].get('trimMaterial', m))],
    'curved_rib': lambda d, m: [_curved_rib(d['id'], m, d['sector'], d['at'], d.get('rot', 0), d['params']['inner'], d['params']['outer'], d['params']['depth'], d['params'].get('start', 0), d['params'].get('stop', math.pi), d['params'].get('segments', 24))],
    'pipe': lambda d, m: [_pipe(d['id'], m, d['sector'], d['at'], d.get('rot', 0), d['params']['radius'], d['params'].get('sides', 10), d['params']['path'])],
    'grotto_arch': _grotto_arch,
    'stepped_terrace': _stepped_terrace,
    'facade_bays': _facade_bays,
    'root_form': _root_form,
    'fern_card': _fern_card,
    'pool': _pool,
    'tower': _tower,
    'lightwell': _lightwell,
    'instrument_dish': _instrument_dish,
    'scientific_room': _scientific_room,
    'stall_row': _stall_row,
    'roof_run': _roof_run,
    'arch_bridge': _arch_bridge,
    'retaining_wall': _retaining_wall,
    'landmark': _landmark,
}


def expand_kit(kit, allowed_materials):
    """Expand directives; reject unknown classes or unbound materials.

    Directives are authored in the source authority frame (Y up, radians about
    Y). Ops are returned in Blender frame: X right, Y depth (source -Z), Z up,
    rotation about Blender Z. Local part geometry is already Blender Z-up.
    """
    ops = []
    for source in kit:
        klass = source.get('class')
        if klass not in HANDLERS:
            raise ValueError('Unknown kit class: ' + str(klass))
        if source['material'] not in allowed_materials:
            raise ValueError('Unbound kit material: ' + source['material'])
        # Handlers express assembly offsets in source Y-up, while primitive
        # vertices/sizes are local Blender Z-up. Expand around zero, convert
        # offsets exactly once, then rigidly rotate the ENTIRE assembly.
        local = dict(source, at=[0, 0, 0], rot=0)
        origin = to_blender(source['at'])
        heading = float(source.get('rot', 0))
        c, s = math.cos(heading), math.sin(heading)
        for entry in HANDLERS[klass](local, local['material']):
            x, y, z = to_blender(entry['at'])
            entry['at'] = [origin[0] + c*x-s*y, origin[1] + s*x+c*y, origin[2]+z]
            entry['rot'] += heading
            if source['params'].get('profiled') and entry['op'] in ('curved_rib','pipe'):
                # Rounded profiles already carry real silhouette geometry.
                # Avoid a second bevel on every longitudinal tessellation edge.
                entry['profiled'] = True
            if 'bevelSegments' in source['params']:
                segments = source['params']['bevelSegments']
                if segments not in (1,2):raise ValueError('Unreviewed bevel segment count')
                entry['bevelSegments'] = segments
            if entry['material'] not in allowed_materials:
                raise ValueError('Unbound op material: ' + entry['material'])
            if entry.get('trimMaterial',entry['material']) not in allowed_materials:
                raise ValueError('Unbound trim material')
            ops.append(entry)
    return ops


def op_triangles(entry):
    if entry['op'] == 'prism':
        return 12
    if entry['op'] == 'framed_bay':
        return 12 * 7 + 2*(20*8+4) if entry.get('arch') else 12*9
    if entry['op'] == 'curved_rib':
        return entry['segments'] * 8 + 4
    if entry['op'] == 'pipe':
        return entry['sides'] * 2 - 4 + max(0, len(entry['points']) - 1) * entry['sides'] * 2
    if entry['op'] == 'mesh':
        return _triangles(entry['vertices'], entry['faces'])
    raise ValueError('Unknown op: ' + entry['op'])


def plan(kit, allowed_materials, max_triangles=24000):
    ops = expand_kit(kit, allowed_materials)
    groups = {}
    total = 0
    for entry in ops:
        triangles = op_triangles(entry)
        total += triangles
        parts = [(entry['material'], triangles)]
        if entry['op'] == 'framed_bay':
            frame = 24+164 if entry['arch'] else 36
            parts = [(entry['material'],frame),(entry['trimMaterial'],triangles-frame)]
        for material,count in parts:
            key = (entry['sector'], material)
            groups[key] = groups.get(key, 0) + count
    batches = sum(-(-triangles // max_triangles) for triangles in groups.values())
    return {
        'ops': ops,
        'summary': {
            'ops': len(ops),
            'triangles': total,
            'sectors': sorted({e['sector'] for e in ops}),
            'materials': sorted({e['material'] for e in ops}),
            'batches': batches,
            'sourceMeshLimits': {'maxTrianglesPerBatch': max_triangles},
            'triangleAdvisory': triangle_advisory(total, 'source-estimate'),
            'measurement': 'unmodified source estimate; evaluated full-scene acceptance pending',
        },
    }


def scene_summary(arena, allowed, cap=24000):
    from pathlib import Path
    from base_craft import base_craft_plan
    craft = base_craft_plan(arena, Path(__file__).resolve().parents[4])
    summary = dict(plan(arena['art']['kit'],allowed,cap)['summary'])
    shell, structures, pieces, decorative = shell_plan(arena), structure_plan(arena), piece_plan(arena), decorative_plan(arena)
    infrastructure = sum(op_triangles(o) for o in infrastructure_plan(arena))
    summary.update(authorityShellTriangles=shell['authorityTriangles'], structureTriangles=structures['triangles'],
                   pieceTriangles=pieces['triangles'], decorativeTriangles=decorative['triangles'],
                   decorativeMeshes=len(decorative['lineage']), infrastructureTriangles=infrastructure,
                   baseCraftTriangles=craft['triangles'], baseCraftParts=len(craft['lineage']),
                   sourceSceneTriangles=summary['triangles']+shell['authorityTriangles']+structures['triangles']+pieces['triangles']+decorative['triangles']+infrastructure+craft['triangles']+(2 if arena.get('art',{}).get('water') else 0),
                   labelsPendingTessellation=len(arena.get('art',{}).get('labels',[]))+len(craft['labels']),
                   evaluatedAcceptance='pending Blender evaluation and GLB pixel/primitive audit')
    summary['triangleAdvisory'] = triangle_advisory(summary['sourceSceneTriangles'], 'source-estimate')
    return summary


def structure_plan(arena):
    """Solid `blocks` and `overhead` slabs as batched boxes (Blender frame)."""
    buckets = {}

    def add(material, x, z, w, d, min_y, max_y):
        bucket = buckets.setdefault(material, _empty())
        base = len(bucket['vertices'])
        vertices, faces = _box((0, 0, 0), (w, d, max_y - min_y))
        vertices = [(x + vx, -z + vy, (min_y + max_y) / 2 + vz) for vx, vy, vz in vertices]
        bucket['vertices'].extend(vertices)
        bucket['faces'].extend(tuple(base + i for i in face) for face in faces)

    for block in arena.get('blocks', []):
        add(block.get('material', 'metal'), block['x'], block['z'], block['w'], block['d'], block.get('baseY', 0), block['h'])
    for slab in arena.get('overhead', []):
        add(slab.get('material', 'metal'), slab['x'], slab['z'], slab['w'], slab['d'], slab['minY'], slab['maxY'])
    triangles = sum(_triangles(b['vertices'], b['faces']) for b in buckets.values())
    return {'buckets': buckets, 'triangles': triangles, 'boxes': len(arena.get('blocks', [])) + len(arena.get('overhead', []))}


def piece_plan(arena):
    """Decorative `art.pieces` boxes as batched meshes per material."""
    buckets = {}
    for piece in arena.get('art', {}).get('pieces', []):
        bucket = buckets.setdefault(piece.get('material', 'brick'), _empty())
        base = len(bucket['vertices'])
        vertices, faces = _box((0, 0, 0), (piece['w'], piece['d'], piece['h']))
        vertices = [(piece['x'] + vx, -piece['z'] + vy, piece['y'] + vz) for vx, vy, vz in vertices]
        bucket['vertices'].extend(vertices)
        bucket['faces'].extend(tuple(base + i for i in face) for face in faces)
    triangles = sum(_triangles(b['vertices'], b['faces']) for b in buckets.values())
    return {'buckets': buckets, 'triangles': triangles, 'pieces': len(arena.get('art', {}).get('pieces', []))}


def to_blender(vertex):
    x, y, z = vertex
    return (float(x), float(-z), float(y))


def mesh_chunks(bucket, cap=24000):
    """Bound individual editable source meshes, preserving every face once."""
    chunk, indices, count = _empty(), {}, 0
    for face in bucket['faces']:
        triangles = len(face) - 2
        if triangles > cap:
            raise ValueError('Single polygon exceeds source cap')
        if count + triangles > cap:
            yield chunk
            chunk, indices, count = _empty(), {}, 0
        mapped = []
        for old in face:
            if old not in indices:
                indices[old] = len(chunk['vertices'])
                chunk['vertices'].append(bucket['vertices'][old])
            mapped.append(indices[old])
        chunk['faces'].append(tuple(mapped))
        count += triangles
    if chunk['faces']:
        yield chunk


def decorative_plan(arena):
    """Keep all authored noncollision meshes; terrain-backed art is emitted once."""
    buckets, lineage = {}, []
    for mesh in arena.get('art', {}).get('meshes', []):
        collision = mesh.get('collision', 'none')
        if collision in ('surface', 'wall'):
            continue
        if collision != 'none':
            raise ValueError('Unknown art collision role: ' + collision)
        bucket = buckets.setdefault(mesh['material'], _empty())
        _add(bucket, [to_blender(v) for v in mesh['vertices']], mesh['triangles'])
        lineage.append(mesh['id'])
    return {'buckets': buckets, 'lineage': lineage,
            'triangles': sum(_triangles(b['vertices'], b['faces']) for b in buckets.values())}


def infrastructure_plan(arena):
    """Preserved Vesper rail and clock forms, editable through the same Kit."""
    art, ops = arena.get('art', {}), []
    for offset in (-1.1, 1.1) if art.get('tram') else ():
        points = []
        for x, _, source_z in art['tram']:
            z = source_z + offset
            y = 0 if z <= -65 else (z+65)*.3 if z < -25 else 12 if z <= 25 else 12+(z-25)*.3 if z < 65 else 24
            point = to_blender((x, y+.045, z))
            if not points or math.dist(points[-1], point) >= .01:
                points.append(point)
        ops.append(_pipe('tram-rail.'+str(offset), 'iron', 'infrastructure', [0,0,0], 0, .045, 8, points))
    clock = art.get('clock')
    if clock:
        r, n = clock['radius'], 48
        # Dial faces source -Z (Blender +Y); closed, outward-wound cylinder.
        vertices = [(r*math.cos(i*math.tau/n), y, r*math.sin(i*math.tau/n)) for y in (-.06,.06) for i in range(n)]
        faces = [tuple(range(n)), tuple(reversed(range(n,2*n)))]
        faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        ops.append(_mesh('civic-clock-dial','letter','infrastructure',to_blender((clock['x'],clock['y'],clock['z'])),0,vertices,faces,0,False))
        for name, x, y, z, size in [('minute',clock['x'],clock['y']+1,clock['z']-.15,(.15,.13,2.2)),('hour',clock['x']+.65,clock['y'],clock['z']-.17,(1.4,.14,.18))]:
            ops.append(_prism('clock-'+name,'iron','infrastructure',to_blender((x,y,z)),0,size,.01))
    return ops


def shell_plan(arena):
    """World-space authority surfaces/walls as one batched mesh per material."""
    surfaces, walls, miscount = {}, {}, 0
    for surface in arena['terrain']['surfaces']:
        if surface.get('renderSource') == 'kit':
            continue
        bucket = surfaces.setdefault(surface['material'], _empty())
        base = len(bucket['vertices'])
        bucket['vertices'].extend(to_blender(v) for v in surface['vertices'])
        bucket['faces'].extend(tuple(base + i for i in triangle) for triangle in surface['triangles'])
    for wall in arena['terrain']['walls']:
        if wall.get('renderSource') == 'kit':
            continue
        vertices = wall.get('vertices') or [wall['a'], wall['b']]
        if len(vertices) != 3:
            miscount += 1
            continue
        bucket = walls.setdefault(wall['material'], _empty())
        base = len(bucket['vertices'])
        bucket['vertices'].extend(to_blender(v) for v in vertices)
        bucket['faces'].append((base, base + 1, base + 2))
    surface_triangles = sum(_triangles(b['vertices'], b['faces']) for b in surfaces.values())
    wall_triangles = sum(_triangles(b['vertices'], b['faces']) for b in walls.values())
    return {
        'surfaces': surfaces, 'walls': walls, 'nonTriangleWalls': miscount,
        'surfaceTriangles': surface_triangles, 'wallTriangles': wall_triangles,
        'authorityTriangles': surface_triangles + wall_triangles,
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('authority', help='candidate authority.json with arena.art.kit')
    parser.add_argument('--bindings', required=True, help='variety_bindings.json for the material allow-list')
    parser.add_argument('--out', help='write the plan JSON here')
    parser.add_argument('--max-triangles', type=int, default=24000)
    args = parser.parse_args()
    authority = json.loads(open(args.authority).read())
    arena = authority.get('arena', authority)
    bindings = json.loads(open(args.bindings).read())
    result = plan(arena['art']['kit'], set(bindings['materials']), args.max_triangles)
    shell = shell_plan(arena)
    result['summary']['authorityShellTriangles'] = shell['authorityTriangles']
    result['summary']['nonTriangleWalls'] = shell['nonTriangleWalls']
    result['summary']['totalTriangles'] = shell['authorityTriangles'] + result['summary']['triangles']
    text = json.dumps(result['summary'], indent=2)
    if args.out:
        open(args.out, 'w').write(json.dumps(result, indent=2) + '\n')
    print(text)


if __name__ == '__main__':
    main()

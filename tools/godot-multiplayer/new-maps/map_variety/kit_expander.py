"""Pure-Python expansion of authority `art.kit` directives into builder ops.

No bpy import. Deterministic and importable by the source tests, so the exact
part list, sectors, material batches and triangle budget can be validated before
any Blender process is granted. Each op maps 1:1 to a `blender_kit.Kit` call.
"""
import json
import math


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
    rise = span / 2
    thickness = d['params'].get('thickness', .9)
    depth = d['params'].get('depth', 3.4)
    at, rot = d['at'], d.get('rot', 0)
    out = [
        _curved_rib(d['id'] + '.band', material, d['sector'], at, rot, span / 2 - thickness, span / 2, depth, 0, math.pi, 22),
        _curved_rib(d['id'] + '.reveal', material, d['sector'], [at[0], at[1], at[2] - depth * .18], rot,
                    span / 2 - thickness * 1.4, span / 2 - thickness * .9, depth * .32, 0, math.pi, 22),
        _prism(d['id'] + '.springer', material, d['sector'], at, rot, [span + thickness, depth * 1.2, thickness * .7], .05),
    ]
    del rise
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
            faces.append((base, base + 1, base + 2, base + 3))
    return [_mesh(d['id'], material, d['sector'], d['at'], d.get('rot', 0), vertices, faces, 0.0, False)]


def _pool(d, material):
    p = d['params']
    w, dpt = float(p.get('width', 6)), float(p.get('depth', 6))
    z = float(p.get('surface', .06))
    vertices = [(-w / 2, -dpt / 2, z), (w / 2, -dpt / 2, z), (w / 2, dpt / 2, z), (-w / 2, dpt / 2, z)]
    return [_mesh(d['id'], material, d['sector'], d['at'], d.get('rot', 0), vertices, [(0, 1, 2, 3)], 0.0, False)]


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
        x, y, z = source['at']
        converted = dict(source)
        converted['at'] = [float(x), float(-z), float(y)]
        converted['rot'] = float(-source.get('rot', 0))
        for entry in HANDLERS[klass](converted, converted['material']):
            if entry['material'] not in allowed_materials:
                raise ValueError('Unbound op material: ' + entry['material'])
            ops.append(entry)
    return ops


def op_triangles(entry):
    if entry['op'] == 'prism':
        return 12
    if entry['op'] == 'framed_bay':
        return 12 * 7 + (22 * 8 if entry.get('arch') else 0)
    if entry['op'] == 'curved_rib':
        return entry['segments'] * 8 + 4
    if entry['op'] == 'pipe':
        return entry['sides'] * 2 + max(0, len(entry['points']) - 1) * entry['sides'] * 2
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
        key = (entry['sector'], entry['material'])
        groups[key] = groups.get(key, 0) + triangles
    batches = sum(-(-triangles // max_triangles) for triangles in groups.values())
    return {
        'ops': ops,
        'summary': {
            'ops': len(ops),
            'triangles': total,
            'sectors': sorted({e['sector'] for e in ops}),
            'materials': sorted({e['material'] for e in ops}),
            'batches': batches,
            'budget': {'maxTrianglesPerBatch': max_triangles, 'triangleBudget': 160000},
            'withinBudget': total <= 160000,
        },
    }


def to_blender(vertex):
    x, y, z = vertex
    return (float(x), float(-z), float(y))


def shell_plan(arena):
    """World-space authority surfaces/walls as one batched mesh per material."""
    surfaces, walls, miscount = {}, {}, 0
    for surface in arena['terrain']['surfaces']:
        bucket = surfaces.setdefault(surface['material'], _empty())
        base = len(bucket['vertices'])
        bucket['vertices'].extend(to_blender(v) for v in surface['vertices'])
        bucket['faces'].extend(tuple(base + i for i in triangle) for triangle in surface['triangles'])
    for wall in arena['terrain']['walls']:
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

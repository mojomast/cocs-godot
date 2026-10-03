"""Source-frame geometry helpers shared by the map-variety revision builders.

Pure Python: no bpy, no engine. Everything is authored in the source Y-up frame
and converted once at the Blender boundary.

Coordinate contract (must round-trip exactly under Blender's ``export_yup``):

    source (x, y_up, z)   --source_to_blender-->   blender (x, -z, y_up)
    blender (x, y, z)     --blender_to_gltf----->  gltf   (x, z, -y)

so ``source -> blender -> glTF`` is the identity: source +Y (up) becomes Blender
+Z and glTF +Y, never Blender Y.

Face windings are set from an explicit outward reference per surface role (not a
heuristic), so closed forms have outward normals on every axis.
"""
import importlib.util
import math
import pathlib

_KIT = None


def _kit():
    global _KIT
    if _KIT is None:
        path = pathlib.Path(__file__).resolve().parents[1] / 'map-variety-pipeline' / 'blender_kit.py'
        spec = importlib.util.spec_from_file_location('blender_kit_pure', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _KIT = module
    return _KIT


def source_to_blender(point):
    return (point[0], -point[2], point[1])


def source_direction_to_blender(direction):
    return (direction[0], -direction[2], direction[1])


def blender_to_gltf(point):
    return (point[0], point[2], -point[1])


def roundtrip(point):
    return blender_to_gltf(source_to_blender(point))


def prism_size_to_blender(size):
    """Source (w_x, d_z, h_y) -> Blender (X, Y, Z) extents."""
    return (size[0], size[2], size[1])


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _length(v):
    return math.sqrt(sum(c * c for c in v))


def centroid(points):
    return tuple(sum(p[i] for p in points) / len(points) for i in range(3))


def polygon_normal(vertices):
    n = [0.0, 0.0, 0.0]
    for i, a in enumerate(vertices):
        b = vertices[(i + 1) % len(vertices)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])
    return tuple(n)


def polygon_area(vertices):
    return _length(polygon_normal(vertices)) / 2.0


def orient_faces(vertices, faces, reference):
    """Flip each face so its normal agrees with the explicit outward reference."""
    oriented = []
    for face in faces:
        points = [vertices[i] for i in face]
        normal = polygon_normal(points)
        if _dot(normal, reference(centroid(points))) < 0:
            oriented.append(list(reversed(face)))
        else:
            oriented.append(list(face))
    return oriented


def validate_mesh(vertices, faces, context='mesh'):
    if not vertices:
        raise ValueError(context + ': no vertices')
    for vertex in vertices:
        if len(vertex) != 3 or any(not math.isfinite(c) for c in vertex):
            raise ValueError(context + ': non-finite vertex')
    if not faces:
        raise ValueError(context + ': no faces')
    for face in faces:
        if not isinstance(face, (list, tuple)) or len(face) < 3:
            raise ValueError(context + ': face with fewer than three vertices')
        for index in face:
            if not isinstance(index, int) or isinstance(index, bool) or index < 0 or index >= len(vertices):
                raise ValueError(context + ': face index out of range: ' + repr(index))
        if len(set(face)) < 3:
            raise ValueError(context + ': degenerate repeated face index')
        points = [vertices[index] for index in face]
        if polygon_area(points) < 1e-9 or _length(polygon_normal(points)) < 1e-9:
            raise ValueError(context + ': zero-area face')
    return True


def validate_pipe(points, radius, sides, context='pipe'):
    rings = _kit()._pipe_rings([tuple(p) for p in points], radius, sides)
    if len(rings) != len(points) or any(len(ring) != sides for ring in rings):
        raise ValueError(context + ': pipe ring construction failed')
    return True


def validate_spec(spec):
    op = spec['op']
    if op == 'mesh':
        return validate_mesh(spec['vertices'], spec['faces'], spec['name'])
    if op == 'pipe':
        return validate_pipe(spec['points'], spec['radius'], spec.get('sides', 12), spec['name'])
    raise ValueError('Unreviewed layout op: ' + op)


def mesh_spec(name, vertices, faces, material, sector, bevel=0.04, smooth=True):
    validate_mesh(vertices, faces, name)
    return {'op': 'mesh', 'name': name, 'material': material, 'sector': sector,
            'vertices': [tuple(v) for v in vertices], 'faces': [list(f) for f in faces],
            'bevel': bevel, 'smooth': smooth}


def pipe_spec(name, points, radius, material, sector, sides=12):
    validate_pipe(points, radius, sides, name)
    return {'op': 'pipe', 'name': name, 'material': material, 'sector': sector,
            'points': [tuple(p) for p in points], 'radius': radius, 'sides': sides}


def box_mesh_src(name, center, size, heading, material, sector, bevel=0.05):
    """Axis-aligned box rotated about the vertical axis, matching the base map
    convention: heading = atan2(road_tangent.x, road_tangent.z), so the road
    tangent is ``u = (sin h, cos h)`` and across is ``a = (cos h, -sin h)``.

    ``size`` is source ``(across, along, height)`` and ``center`` is the centre.
    Faces are outward-wound index tuples.
    """
    cx, cy, cz = center
    across, along, height = size
    if min(size) <= 0 or any(not math.isfinite(c) for c in (*center, *size)):
        raise ValueError(name + ': invalid box dimensions')
    cos, sin = math.cos(heading), math.sin(heading)
    vertices = []
    for sa in (-1, 1):
        for sy in (-1, 1):
            for sl in (-1, 1):
                a = sa * across / 2
                l = sl * along / 2
                vertices.append((cx + a * cos + l * sin, cy + sy * height / 2, cz - a * sin + l * cos))

    def at(sa, sy, sl):
        return (0 if sa < 0 else 1) * 4 + (0 if sy < 0 else 1) * 2 + (0 if sl < 0 else 1)

    faces = orient_faces(vertices, [[at(-1, -1, -1), at(1, -1, -1), at(1, -1, 1), at(-1, -1, 1)],
                                    [at(-1, 1, -1), at(-1, 1, 1), at(1, 1, 1), at(1, 1, -1)],
                                    [at(-1, -1, -1), at(-1, 1, -1), at(1, 1, -1), at(1, -1, -1)],
                                    [at(-1, -1, 1), at(1, -1, 1), at(1, 1, 1), at(-1, 1, 1)],
                                    [at(-1, -1, -1), at(-1, -1, 1), at(-1, 1, 1), at(-1, 1, -1)],
                                    [at(1, -1, -1), at(1, 1, -1), at(1, 1, 1), at(1, -1, 1)]],
                           lambda c: _sub(c, (cx, cy, cz)))
    return mesh_spec(name, vertices, faces, material, sector, bevel=bevel, smooth=False)


def ring_mesh_src(name, center, inner, outer, thickness, material, sector, segments=24):
    """Horizontal annular band: ring in the source XZ plane, extruded along +Y."""
    cx, cy, cz = center
    if not (0 < inner < outer) or thickness <= 0 or segments < 6:
        raise ValueError(name + ': invalid ring')
    vertices = []
    for dy in (-thickness / 2, thickness / 2):
        for radius in (inner, outer):
            for k in range(segments):
                angle = math.tau * k / segments
                vertices.append((cx + radius * math.cos(angle), cy + dy, cz + radius * math.sin(angle)))
    faces, refs = [], []
    for k in range(segments):
        j = (k + 1) % segments
        i0, i1, o0, o1 = k, j, segments + k, segments + j
        t0, t1, to0, to1 = 2 * segments + k, 2 * segments + j, 3 * segments + k, 3 * segments + j
        faces += [[i0, o0, o1, i1], [t0, t1, to1, to0], [i0, i1, t1, t0], [o0, to0, to1, o1]]
        refs += [(lambda c: (0, -1, 0)), (lambda c: (0, 1, 0)),
                 (lambda c: (cx - c[0], 0.0, cz - c[2])), (lambda c: (c[0] - cx, 0.0, c[2] - cz))]
    oriented = []
    for face, reference in zip(faces, refs):
        normal = polygon_normal([vertices[i] for i in face])
        point = centroid([vertices[i] for i in face])
        oriented.append(face if _dot(normal, reference(point)) >= 0 else list(reversed(face)))
    return mesh_spec(name, vertices, oriented, material, sector, bevel=0.015, smooth=True)


def frustum_mesh_src(name, base, top, material, sector, bevel=0.05, cap=True):
    """Closed-ish frustum: base and top rings (CCW in XZ) with outward sides and
    an upward top cap. Used for vessel roofs and reef forms."""
    if len(base) != len(top) or len(base) < 3:
        raise ValueError(name + ': mismatched frustum rings')
    n = len(base)
    vertices = [tuple(p) for p in base] + [tuple(p) for p in top]
    cx = sum(p[0] for p in base) / n
    cz = sum(p[2] for p in base) / n
    faces = [[i, n + i, n + (i + 1) % n, (i + 1) % n] for i in range(n)]
    faces = orient_faces(vertices, faces, lambda c: (c[0] - cx, 0.0, c[2] - cz))
    cap_faces = orient_faces(vertices, [list(range(n, 2 * n))], lambda c: (0, 1, 0))
    return mesh_spec(name, vertices, faces + cap_faces if cap else faces, material, sector, bevel=bevel, smooth=False)


def arch_mesh_src(name, base, spring, radius, thickness, depth, heading, material, sector, segments=24):
    """Vertical arch band spanning across ``heading`` and rising in +Y."""
    bx, bz = base
    if radius <= 0 or thickness <= 0 or depth <= 0 or segments < 6:
        raise ValueError(name + ': invalid arch')
    ac = (math.cos(heading), -math.sin(heading))
    al = (math.sin(heading), math.cos(heading))
    mid = radius + thickness / 2
    vertices = []
    for along in (-depth / 2, depth / 2):
        for radial in (radius, radius + thickness):
            for k in range(segments + 1):
                angle = math.pi * k / segments
                across = radial * math.cos(angle)
                up = spring + radial * math.sin(angle)
                vertices.append((bx + al[0] * along + ac[0] * across, up, bz + al[1] * along + ac[1] * across))
    n = segments + 1
    faces, refs = [], []
    for k in range(segments):
        ia, ib = k, k + 1
        oa, ob = n + k, n + k + 1
        fia, fib = 2 * n + k, 2 * n + k + 1
        foa, fob = 3 * n + k, 3 * n + k + 1

        def centerline(c):
            across = (c[0] - bx) * ac[0] + (c[2] - bz) * ac[1]
            up = c[1] - spring
            theta = max(0.0, min(math.pi, math.atan2(up, across)))
            return (bx + ac[0] * mid * math.cos(theta), spring + mid * math.sin(theta), bz + ac[1] * mid * math.cos(theta))

        faces += [[ia, oa, ob, ib],        # along -depth/2 cap
                  [fia, fib, fob, foa],    # along +depth/2 cap
                  [ia, ib, fib, fia],      # inner radial band
                  [oa, foa, fob, ob]]      # outer radial band
        refs += [(lambda c: (-al[0], 0.0, -al[1])), (lambda c: (al[0], 0.0, al[1])),
                 (lambda c: _sub(centerline(c), c)), (lambda c: _sub(c, centerline(c)))]
    oriented = []
    for face, reference in zip(faces, refs):
        normal = polygon_normal([vertices[i] for i in face])
        point = centroid([vertices[i] for i in face])
        oriented.append(face if _dot(normal, reference(point)) >= 0 else list(reversed(face)))
    return mesh_spec(name, vertices, oriented, material, sector, bevel=0.02, smooth=True)

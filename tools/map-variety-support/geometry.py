"""Source-frame geometry helpers shared by the map-variety revision builders.

Pure Python: no bpy, no engine. Everything is authored in the source Y-up frame
and converted once at the Blender boundary.

Coordinate contract (must round-trip exactly under Blender's ``export_yup``):

    source (x, y_up, z)          authoring frame
    blender (x, -z, y_up)        Blender Z-up
    glTF   (x, y_up, z)          export maps Blender (x, y, z) -> (x, z, -y)

so ``source -> blender -> glTF`` is the identity. The vertical (source +Y) axis
becomes Blender +Z and glTF +Y, never Blender Y.
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


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _length(v):
    return math.sqrt(sum(c * c for c in v))


def polygon_normal(vertices):
    """Newell normal of a planar-ish polygon (source frame)."""
    n = [0.0, 0.0, 0.0]
    for i, a in enumerate(vertices):
        b = vertices[(i + 1) % len(vertices)]
        n[0] += (a[1] - b[1]) * (a[2] + b[2])
        n[1] += (a[2] - b[2]) * (a[0] + b[0])
        n[2] += (a[0] - b[0]) * (a[1] + b[1])
    return tuple(n)


def polygon_area(vertices):
    return _length(polygon_normal(vertices)) / 2.0


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
    """Axis-aligned box in source frame rotated about the vertical axis.

    ``size`` is source (X extent, Z extent, Y height); ``center`` is the box
    centre. Faces are outward-wound index tuples.
    """
    cx, cy, cz = center
    w, d, h = size
    if min(size) <= 0 or any(not math.isfinite(c) for c in (*center, *size)):
        raise ValueError(name + ': invalid box dimensions')
    cos, sin = math.cos(heading), math.sin(heading)
    vertices = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                lx, lz = sx * w / 2, sz * d / 2
                vertices.append((cx + lx * cos - lz * sin, cy + sy * h / 2, cz + lx * sin + lz * cos))

    def at(sx, sy, sz):
        return (0 if sx < 0 else 1) * 4 + (0 if sy < 0 else 1) * 2 + (0 if sz < 0 else 1)

    faces = [[at(-1, -1, -1), at(1, -1, -1), at(1, -1, 1), at(-1, -1, 1)],
             [at(-1, 1, -1), at(-1, 1, 1), at(1, 1, 1), at(1, 1, -1)],
             [at(-1, -1, -1), at(-1, 1, -1), at(1, 1, -1), at(1, -1, -1)],
             [at(-1, -1, 1), at(1, -1, 1), at(1, 1, 1), at(-1, 1, 1)],
             [at(-1, -1, -1), at(-1, -1, 1), at(-1, 1, 1), at(-1, 1, -1)],
             [at(1, -1, -1), at(1, 1, -1), at(1, 1, 1), at(1, -1, 1)]]
    return mesh_spec(name, vertices, faces, material, sector, bevel=bevel, smooth=False)


def ring_mesh_src(name, center, inner, outer, thickness, material, sector, segments=24):
    """Horizontal annular band: ring in the source XZ plane, extruded along Y."""
    cx, cy, cz = center
    if not (0 < inner < outer) or thickness <= 0 or segments < 6:
        raise ValueError(name + ': invalid ring')
    vertices = []
    for dy in (-thickness / 2, thickness / 2):
        for radius in (inner, outer):
            for k in range(segments):
                angle = math.tau * k / segments
                vertices.append((cx + radius * math.cos(angle), cy + dy, cz + radius * math.sin(angle)))
    faces = []
    for k in range(segments):
        j = (k + 1) % segments
        i0, i1, o0, o1 = k, j, segments + k, segments + j
        t0, t1, to0, to1 = 2 * segments + k, 2 * segments + j, 3 * segments + k, 3 * segments + j
        faces += [[i0, o0, o1, i1], [t0, t1, to1, to0], [i0, i1, t1, t0], [o0, to0, to1, o1]]
    return mesh_spec(name, vertices, faces, material, sector, bevel=0.015, smooth=True)


def arch_mesh_src(name, base, spring, radius, thickness, depth, heading, material, sector, segments=24):
    """Vertical arch band spanning across ``heading`` and rising in source +Y."""
    bx, bz = base
    if radius <= 0 or thickness <= 0 or depth <= 0 or segments < 6:
        raise ValueError(name + ': invalid arch')
    ac = (math.cos(heading + math.pi / 2), math.sin(heading + math.pi / 2))
    al = (math.sin(heading), math.cos(heading))
    vertices = []
    for along in (-depth / 2, depth / 2):
        for radial in (radius, radius + thickness):
            for k in range(segments + 1):
                angle = math.pi * k / segments
                across = radial * math.cos(angle)
                up = spring + radial * math.sin(angle)
                vertices.append((bx + al[0] * along + ac[0] * across, up, bz + al[1] * along + ac[1] * across))
    n = segments + 1
    faces = []
    for k in range(segments):
        inner_a, inner_b = k, k + 1
        outer_a, outer_b = n + k, n + k + 1
        far_inner_a, far_inner_b = 2 * n + k, 2 * n + k + 1
        far_outer_a, far_outer_b = 3 * n + k, 3 * n + k + 1
        faces += [[inner_a, outer_a, outer_b, inner_b],
                  [far_inner_a, far_inner_b, far_outer_b, far_outer_a],
                  [inner_a, inner_b, far_inner_b, far_inner_a],
                  [outer_a, far_outer_a, far_outer_b, outer_b]]
    return mesh_spec(name, vertices, faces, material, sector, bevel=0.02, smooth=True)
